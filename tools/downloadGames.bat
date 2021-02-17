@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    title Search and download games for CEMU or the Wii-U
    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "duLogFile="!BFW_LOGS:"=!\du.log""

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "du="!BFW_RESOURCES_PATH:"=!\du.exe""
    set "JNUSTFolder="!BFW_RESOURCES_PATH:"=!\JNUST""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "download="!BFW_TOOLS_PATH:"=!\downloadTitleId.bat""
    set "multiply="!BFW_TOOLS_PATH:"=!\multiply.bat""

    set "notePad="%windir%\System32\notepad.exe""
    set "explorer="%windir%\explorer.exe""

    
    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit /b 100
    )
    
    REM : output folder
    set "targetFolder=!GAMES_FOLDER!"

    REM : search if this script is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "downloadGames.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GEQ 2 (
            echo "ERROR^: This script is already running ^!"
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "downloadGames.bat" | find /I /V "find"
            pause
            exit 20
        )
    )

    REM : check if java is installed
    java -version > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: java is not installed^, exiting
        pause
        exit 50
    )

    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo ERROR^: no active network connection found^, exiting
        pause
        exit 51
    )

    REM : set current char codeset
    call:setCharSet

    set "config="!JNUSTFolder:"=!\config""
    type !config! | find "[COMMONKEY]" > NUL 2>&1 && (
        echo To use this feature^, obviously you^'ll have to setup JNUSTool
        echo and get the files requiered by yourself^.
        echo.
        echo First you need to find the ^'Wii U common key^' with google
        echo.

        echo Then replace ^'[COMMONKEY]^' with the ^'Wii U common key^' in JNUST^\config
        echo and save^.
        echo.
        timeout /T 3 > NUL 2>&1
        wscript /nologo !StartWait! !notePad! !config!
    )

    set "titleKeysDataBase="!JNUSTFolder:"=!\titleKeys.txt""

    if not exist !titleKeysDataBase! call:createKeysFile

    if not exist !titleKeysDataBase! (
        echo ERROR^: no keys file found^, exiting
        pause
        exit 52
    )

    
    set /A "decryptMode=0"

    echo You can download a WUP package for the game to be installed on
    echo your Wii-U using WUP Installer GX2^. You^'ll have to browse to the
    echo target location in this case ^(for example^: %%SD_CARD%%\install^)
    echo.
    echo If you choose to extract the game ^(for CEMU^)^, game will be
    echo extracted and prepared for emulation^.
    echo.
    choice /C yn /N /M "Extract games (= RPX format for CEMU)? :"
    if !ERRORLEVEL! EQU 1 set /A "decryptMode=1" && goto:selectGames

    :askOutputFolder
    set "targetFolder="NONE""
    for /F %%b in ('cscript /nologo !browseFolder! "Please, browse to the output folder"') do set "folder=%%b" && set "targetFolder=!folder:?= !"
    if [!targetFolder!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 1 > NUL 2>&1 && exit 75
        goto:askOutputFolder
    )

    REM : copy JNUSTFolder content in !targetFolder!
    robocopy !JNUSTFolder! !targetFolder! /MT:32 /S /IS /IT  > NUL 2>&1

    REM : override JNUSTFolder path
    set "JNUSTFolder=!targetFolder!"
    
    :selectGames

    REM : pattern used to evaluate size of games : set always extracted size since size of some cryted titles are wrong
    set "str="Total Size of Decrypted Files""
REM    set "str="Total Size of Content Files""
REM    if !decryptMode! EQU 1 set "str="Total Size of Decrypted Files""
    
    set "mode=sequential"
    for /F "delims=~= tokens=2" %%c in ('wmic CPU Get NumberOfLogicalProcessors /value ^| find "="') do set /A "nbCpuThreads=%%c"

    echo ---------------------------------------------------------------
    echo nbCpuThreads detected ^: !nbCpuThreads!

    REM : parallelized only if more than 2 CPU thread are available (JNUSTool is already mutli-threaded)
    if !nbCpuThreads! GTR 2 set "mode=parallelized"
    echo Transfert mode ^: !mode!
    echo.
    
    pushd !JNUSTFolder!
    
    REM : compute sizes on disk JNUSTFolder

    set "psc="Get-CimInstance -ClassName Win32_Volume ^| Select-Object Name^, FreeSpace^, BlockSize ^| Format-Table -AutoSize""
    for /F "tokens=2-3" %%i in ('powershell !psc! ^| find "!drive!" 2^>NUL') do (
        set "fsbStr=%%i"
        set /A "clusterSizeInB=%%j"
    )

    REM : free space in Kb
    set /A "fskb=!fsbStr:~0,-3!"
    set /A "totalFreeSpaceLeft=fskb/1024"

    REM cls
    echo Free Space left on !drive! ^: !totalFreeSpaceLeft! Mb
    echo Cluster size on !drive! is !clusterSizeInB! Bytes
    
    REM : number of games selected
    set /A "nbGames=0"
    set /A "freeSpaceLeft=totalFreeSpaceLeft"
    set /A "totalSpaceNeeded=0"
    
    if !decryptMode! EQU 1  (
    
        set "mf="NOT_FOUND""
        REM : get the last modified folder in JNUSTFolder
        for /F "delims=~" %%x in ('dir /A:D /O:D /T:W /B * 2^>NUL') do (
            if [!mf!] == ["NOT_FOUND"] echo ---------------------------------------------------------------
            echo Uncomplete download detected : "%%x"

            choice /C yn /T 15 /D n /N /M "Remove it (y/n = default in 15 sec)? :"
            if !ERRORLEVEL! EQU 1 rmdir /Q /S "%%x" > NUL 2>&1
            REM : at least delete meta.xml to for last modified folder detection
            set "mf="%%x\meta\meta.xml""
            del /F !mf! > NUL 2>&1
            echo.
        )
        if not [!mf!] == ["NOT_FOUND"] (
            echo.
            echo Relaunch these downloads to complete them
        )
    )
    timeout /T 4 > NUL 2>&1
    set "gamesList="!BFW_LOGS:"=!\jnust_gamesList.log""
    
    :askKeyWord
    cls
    echo ---------------------------------------------------------------
    set /P  "pat=Enter a key word to search for the game (part of the title, titleId...): "
    echo.
    echo =========================== Matches ===========================
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    
    REM : number of resuts returned
    set /A "nbRes=0"

    for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!pat!" ^| find /I "00050000" ^| find /I /V "Demo" 2^>NUL') do (
        if not ["%%c"] == ["EUR"] if not ["%%c"] == ["USA"] if not ["%%c"] == ["JPN"] (
            set "titleIds[!nbRes!]=%%a"
            set "titleKeys[!nbRes!]=%%b"
            
            REM : for the name displayed use Wii-U title database (and so check that the game is listed in)
            set "titleRead="%%c""
            for /F "delims=~; tokens=2" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%%a';" 2^>NUL') do set "titleRead="%%i""
            if [!titleRead!] == ["%%c"] (
                set "titles[!nbRes!]="%%c""
            ) else (
                set "titles[!nbRes!]=!titleRead!"
            )
            
            set "regions[!nbRes!]=%%d"
            set /A "nbRes+=1"
            echo !nbRes! ^: !titleRead! [%%d] %%a
        )
    )

    echo ===============================================================
    echo s ^: to relaunch your search
    echo c ^: to cancel
    echo ---------------------------------------------------------------
    if !nbGames! EQU 0 (
        echo.
        echo If your search failed^, check the format of
        echo !titleKeysDataBase!
        echo.
        echo The text file must use the following format ^:
        echo.
        echo [TitleID]^\t[TitleKey]^\t[Name]^\t[Region]^\t[Type]^\t[Ticket]
        echo ^(use TAB as separator^)
        echo.
        echo.
        echo If your search failed on a ^"recent game^"^, try to update
        echo !titleKeysDataBase!
        echo with a newer database^.
    )
    echo.
    echo.

    :askChoice
    set /p "answer=Enter your choice : "

    if ["!answer!"] == ["s"] goto:askKeyWord
    if ["!answer!"] == ["c"] (
        echo.
        echo Cancelled by user
        pause
        goto:launchDownload
    )

    echo !answer! | findStr /R "^[0-9]*.$" > NUL 2>&1 && goto:checkInteger
    goto:askChoice

    :checkInteger
    set /A "index=!answer!-1"
    if !index! GEQ !nbRes! goto:askChoice

    echo ===============================================================
    REM : download meta/meta.xml to get the title name
    
    REM : compute update and DLC titleId
    set "titleId=!titleIds[%index%]!"
    set "endTitleId=%titleId:~8,8%"

    set "utid=0005000e!endTitleId!"
    set "dtid=0005000c!endTitleId!"

    set /A "totalSizeInMb=0"
    call:getSize !titleId! !str! "Game  " gSize
    if !totalSizeInMb! EQU 0 (
        echo ERROR^: Java call failed^, check system^'s security policies
        pause
        exit /b 65
    )
    
    REM : get the last modified folder in
    set "mf="NOT_FOUND""
    for /F "delims=~" %%x in ('dir /O:D /T:W /B /S meta.xml 2^>NUL ^| find /V /I "aoc" ^| find /V /I "update"') do set "mf="%%x""
    if [!mf!] == ["NOT_FOUND"] (
        echo ERROR^: failed to download meta^.xlm
        echo Check security policy
        pause
        exit 60
    )
    
    set "initialGameFolderName="NOT_FOUND""
    
    for %%a in (!mf!) do set "parentFolder="%%~dpa""
    set "dirname=!parentFolder:~0,-2!""
    for %%a in (!dirname!) do set "parentFolder="%%~dpa""
    set "fullPath=!parentFolder:~0,-2!""
    set "initialGameFolderName=!fullPath:%JNUSTFolder:"=%\=!"

    set "tmpFolderName=!initialGameFolderName:?=!"
    REM : secureGameTitle
    call:secureGameTitle !tmpFolderName! gameFolderName
    
    echo "!gameFolderName!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!gameFolderName!) do set "gameFolderName="%%~nxi""

    type !titleKeysDataBase! | find /I "!utid!" > NUL 2>&1 && (
        call:getSize !utid! !str! Update uSize
    )

    type !titleKeysDataBase! | find /I "!dtid!" > NUL 2>&1 && (
        call:getSize !dtid! !str! "DLC   " dSize
    )

    REM : compute size need on drive
    call:getSizeOnDisk !totalSizeInMb! sizeNeededOnDiskInMb
    set /A "totalSpaceNeeded+=sizeNeededOnDiskInMb"
    echo.
    if !sizeNeededOnDiskInMb! LSS !freeSpaceLeft! (
        echo At least !sizeNeededOnDiskInMb! Mb are requiered on disk !drive! ^(!freeSpaceLeft! Mb estimate left^)

    ) else (
        echo ERROR ^: not enought space left on !drive!
        echo Needed !sizeNeededOnDiskInMb! ^/ still available !freeSpaceLeft! Mb
        echo Ignoring this game
        goto:askKeyWord
    )

    echo ---------------------------------------------------------------
    echo.
    if !nbGames! GEQ 1 (
        set /A "nbg=nbGames-1"
        echo Your current downloads list ^:
        echo.
        echo. > !gamesList!
        for /L %%l in (0,1,!nbg!) do (
            echo !titlesArray[%%l]! [!regionsArray[%%l]!]
            echo !titlesArray[%%l]! [!regionsArray[%%l]!] >> !gamesList!
        )    
        echo.
    ) else (
        del /F !gamesList! > NUL 2>&1
    )
    echo.
    
    if exist !gamesList! type !gamesList! | find /I !gameFolderName! && (
        echo This game is already in the list ^!
        pause
        goto:askKeyWord
    )
    
    choice /C yn /N /M "Add !gameFolderName:"=! to the list (y/n)? : "
    if !ERRORLEVEL! EQU 2 (
        rmdir /Q /S !initialGameFolderName! > NUL 2>&1
        goto:askKeyWord
    )
    REM : delete meta file because dir on date accuracy is minute !
    del /F !mf! > NUL 2>&1

    REM : fill arrays
    set "titleIdsArray[!nbGames!]=!titleIds[%index%]!"
    set "titleKeysArray[!nbGames!]=!titleKeys[%index%]!"
    set "titlesArray[!nbGames!]=!titles[%index%]!"
    set "regionsArray[!nbGames!]=!regions[%index%]!"
    
    set /A "nbGames+=1"
    set /A "freeSpaceLeft-=sizeNeededOnDiskInMb"
    
    :launchDownload
    echo ===============================================================
    choice /C yn /N /M "Download your games now (y/n = add another game)? : "
    if !ERRORLEVEL! EQU 2 goto:askKeyWord

    set /A "nbGames-=1"
    
    cls
    echo If you want to pause the current tranfert or if you get errors during the transfert^, 
    echo close this windows then all opened cmd consoles in your task bar
    echo and relaunch this script to complete the download^.
    echo.
    echo.
    echo Your downloads list ^:
    echo.
    for /L %%l in (0,1,!nbGames!) do echo !titlesArray[%%l]! [!regionsArray[%%l]!]
    echo.
    echo.
    echo !totalSpaceNeeded! Mb to download
    echo !freeSpaceLeft! Mb left on !drive! at the end of all transferts
    echo.
    echo.
    
    set /A "shutdownFlag=0"
    choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
    if !ERRORLEVEL! EQU 1 (
        echo Please^, save all your opened documents before continue^.^.^.
        pause
        set /A "shutdownFlag=1"
    )
    echo.
    
    echo Hit any key to launch your downloads
    echo.
    
    pause
    
    set "initialGameFolderName="NOT_FOUND""
    
    REM : loop on game selected
    for /L %%l in (0,1,!nbGames!) do (
    
        title Download !titlesArray[%%l]! [!regionsArray[%%l]!]
        
        REM : download the game
        call:downloadGame !titlesArray[%%l]! !titleIdsArray[%%l]! !titleKeysArray[%%l]! !regionsArray[%%l]!
    )

    if [!initialGameFolderName!] == ["NOT_FOUND"] goto:endDg
    
    if !decryptMode! EQU 1 if !nbGames! GEQ 0 (
        echo.
        echo.

        echo New Games were added to your library^, launching setup^.bat^.^.^.
        set "setup="!BFW_PATH:"=!\setup.bat""
        timeout /T 3 > NUL 2>&1

        REM : last loaction used for batchFw outputs

        REM : get the last location from logFile
        set "OUTPUT_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set "OUTPUT_FOLDER="%%i""
        if not [!OUTPUT_FOLDER!] == ["NONE"] (
            set "pf=!OUTPUT_FOLDER:\Wii-U Games=!"
            wscript /nologo !Start! !setup! !pf!
        ) else (
            wscript /nologo !Start! !setup!
        )
    )
    rmdir /Q /S !initialGameFolderName! > NUL 2>&1
    
    REM : if shutdwon is asked
    if !shutdownFlag! EQU 1 echo shutdown in 5min^.^.^. & timeout /T 300 /NOBREAK & shutdown -s -f -t 00
    
    :endDg
    endlocal
    exit 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    :downloadGame

        set "currentTitle="%~1""
        set "currentTitleId=%~2"
        set "currentTitleKey=%~3"
        set "currentTitleRegion=%~4"
        
        title Download !currentTitle! [!currentTitleRegion!]
        cls
        echo ===============================================================
        echo !currentTitle! [!currentTitleRegion!] ^(!currentTitleId!^)

        REM : compute update and DLC titleId
        set "titleId=!currentTitleId!"
        set "endTitleId=%titleId:~8,8%"

        set "utid=0005000e!endTitleId!"
        set "dtid=0005000c!endTitleId!"

        set /A "totalSizeInMb=0"
        call:getSize !titleId! !str! "Game  " gSize > NUL 2>&1
        if !totalSizeInMb! EQU 0 (
            echo ERROR^: Java call failed^, check system^'s security policies
            pause
            exit /b 65
        )

        REM : get the last modified folder in
        set "mf="NOT_FOUND""
        for /F "delims=~" %%x in ('dir /O:D /T:W /B /S meta.xml 2^>NUL ^| find /V /I "aoc" ^| find /V /I "update"') do set "mf="%%x""
        if [!mf!] == ["NOT_FOUND"] (
            echo ERROR^: failed to download meta^.xlm
            echo Check security policy
            pause
            exit 60
        )
        
        for %%a in (!mf!) do set "parentFolder="%%~dpa""
        set "dirname=!parentFolder:~0,-2!""
        for %%a in (!dirname!) do set "parentFolder="%%~dpa""
        set "fullPath=!parentFolder:~0,-2!""
        set "initialGameFolderName=!fullPath:%JNUSTFolder:"=%\=!"
        set "gameFolderName=!initialGameFolderName:?=!"

        REM : secure Game Title
        
        REM : if game exists in internal database
        type !wiiTitlesDataBase! | findStr /R /I "^'!titleId!';" > NUL 2>&1 && (
        
            REM : get game's title for wii-u database file
            set "libFileLine="NONE""
            for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!titleId!';" 2^>NUL') do set "libFileLine="%%i""

            if [!libFileLine!] == ["NONE"] goto:setGameLogFile
            
            REM : strip line to get data
            for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
               set "titleIdRead=%%a"
               set "DescRead="%%b""
               set "productCode=%%c"
               set "companyCode=%%d"
               set "notes=%%e"
               set "versions=%%f"
               set "region=%%g"
               set "acdn=%%h"
               set "icoId=%%i"
               set "nativeHeight=%%j"
               set "nativeFps=%%k"
            )    
            
            REM : set Game title for packs (folder name)
            set "gameFolderName=!DescRead!"

            goto:setGameLogFile
        )

        REM : else
        
        set "tmpName=!gameFolderName!"
        call:secureGameTitle !tmpName! gameFolderName
        echo "!gameFolderName!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!gameFolderName!) do set "gameFolderName="%%~nxi""

        :setGameLogFile
        set "gamelogFile="!BFW_LOGS:"=!\jnust_!gameFolderName:"=!.log""

        echo Temporary folder ^: !JNUSTFolder:"=!\!initialGameFolderName:"=!
        echo ---------------------------------------------------------------
        echo Temporary folder ^: !JNUSTFolder:"=!\!initialGameFolderName:"=! > !gamelogFile!
        echo --------------------------------------------------------------->> !gamelogFile!
                
        set /A "totalSizeInMb=0"
        
        call:getSize !titleId! !str! "Game  " gSize
        
        if !totalSizeInMb! EQU 0 (
            echo ERROR^: Java call failed^, check system^'s security policies
            pause
            exit /b 65
        )
        echo Game   size = !gSize! Mb >> !gamelogFile!

        type !titleKeysDataBase! | find /I "!utid!" > NUL 2>&1 && (
        
        
            call:getSize !utid! !str! Update uSize
            echo Update size = !uSize! Mb >> !gamelogFile!
        )

        type !titleKeysDataBase! | find /I "!dtid!" > NUL 2>&1 && (
            call:getSize !dtid! !str! "DLC   " dSize
            echo DLC    size = !dSize! Mb >> !gamelogFile!
        )

        REM : remove 10Mb to totalSizeInMb (threshold)       
        set /A "threshold=!totalSizeInMb!"
        if !threshold! GEQ 10 set /A "threshold=!totalSizeInMb!-9"
        
        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "date=%ldt%"
        REM : starting DATE

        echo.
        echo ===============================================================
        echo Starting at !date! >> !gamelogFile!
        echo Starting at !date!
        echo.

        if !decryptMode! EQU 0 (
            echo ^> Downloading WUP of !currentTitle! [!currentTitleRegion!]^.^.^.
            echo ^> Downloading WUP of !currentTitle! [!currentTitleRegion!]^.^.^. >> !gamelogFile!
            title Downloading WUP of !currentTitle! [!currentTitleRegion!]
        ) else (
        
            set "finalPath="!GAMES_FOLDER:"=!\!gameFolderName:"=!"

            if exist !finalPath! (
                echo ERROR^: Game already exist in !finalPath!^, skip this game
                rmdir /Q /S !initialGameFolderName! > NUL 2>&1
                pause
                goto:eof
            )

            echo ^> Downloading RPX package of !currentTitle! [!currentTitleRegion!]^.^.^.
            echo ^> Downloading RPX package of !currentTitle! [!currentTitleRegion!]^.^.^. >> !gamelogFile!
            title Downloading RPX package of !currentTitle! [!currentTitleRegion!]
        )
        set /A "progression=0"
        
        :initDownload        

        REM : download the game
        call:download

        REM : get the JNUSTools folder size
REM : duplicate getFolderSizeInMb function ctontent to avoid implicit resolution of initialGameFolderName (fail if folder use unsupported charcaters)
REM        call:getFolderSizeInMb !initialGameFolderName! sizeDl

        set /A "sizeDl=0"
        
        REM : when data kept crypted 
        if !decryptMode! EQU 0 (
            set /A "sg=0"
            set "tmpGf="!JNUSTFolder:"=!/tmp_!titleId!""
            call:getSizeInMb !tmpGf! sg            
            set /A "sd=0"
            set "tmpDf="!JNUSTFolder:"=!/tmp_!dtid!""
            call:getSizeInMb !tmpDf! sd
            set /A "su=0"
            set "tmpUf="!JNUSTFolder:"=!/tmp_!utid!""
            call:getSizeInMb !tmpUf! su
            
            set /A "sizeDl=sg+sd+su"
            
        ) else (
        
            set "sizeDl=-1"
            !du! /accepteula -nobanner -q -c !initialGameFolderName! > !duLogFile!

            set "sizeRead=-1"
            for /F "delims=~, tokens=6" %%a in ('type !duLogFile!') do set "sizeRead=%%a"

            if ["!sizeRead!"] == ["-1"] goto:endSizeInMb
            if ["!sizeRead!"] == ["0"] set "sizeDl=0" & goto:endSizeInMb

            REM : 1/(1024^2)=0.00000095367431640625
            for /F %%a in ('!multiply! !sizeRead! 95367431640625') do set "result=%%a"

            set /A "lr=0"
            call:strLength !result! lr
            REM : size in Mb
            if !lr! GTR 20 (
                set /A "sizeDl=!result:~0,-20!"
            ) else (
                set /A "sizeDl=1"
            )

            :endSizeInMb
            echo. > NUL 2>&1
  
REM            call:getSizeInMb !folder! sizeofAll
        )        
        
        
        
        REM : do not continue if not complete (in case of user close downloading windows before this windows)
        set /A "progression=(!sizeDl!*100)/!totalSizeInMb!"
        
        if !progression! LSS 85 (
            echo ---------------------------------------------------------------
            echo Transfert seems to be incomplete^, relaunching^.^.^.
            echo.
            echo Transfert seems to be incomplete^, relaunching^.^.^. >> !gamelogFile!
            echo. >> !gamelogFile!
            goto:initDownload
        )        
        
        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "date=%ldt%"
        
        REM : ending DATE
        echo.
        echo Ending at !date!
        echo Ending at !date! >> !gamelogFile!
        echo ===============================================================
        
        echo Downloaded !sizeDl! / !totalSizeInMb!
        echo Downloaded !sizeDl! / !totalSizeInMb! >> !gamelogFile!
        echo.
        
        REM : update and DLC target folder names
        set "uName="!gameFolderName:"=! (UPDATE DATA)""
        set "dName="!gameFolderName:"=! (DLC)""

        if !decryptMode! EQU 0 (
            REM : WUP format (saved in tmp_%titleId% folder)

            set "folder=tmp_!titleId!"
            if not exist !folder! (
                echo ERROR^: failed to download !titleId!^?
                echo ERROR^: tmp_!titleId! was not found
                pause
                exit 70
            )

            move /Y !folder! !gameFolderName! > NUL 2>&1

            set "folder=tmp_!utid!"
            if exist !folder! move /Y !folder! !uName! > NUL 2>&1

            set "folder=tmp_!dtid!"
            if exist !folder! move /Y !folder! !dName! > NUL 2>&1

            REM : clean targetFolder from JNUSTFolder files
            call:cleanTargetFolder

            echo WUP packages created in !JNUSTFolder:"=!
            echo.
            
        ) else (

            REM : moving GAME_TITLE, GAME_TITLE (UPDATE DATA), GAME_TITLE (DLC) to !GAMES_FOLDER!
            if not [!initialGameFolderName!] == [!gameFolderName!] move /Y !initialGameFolderName! !gameFolderName! > NUL 2>&1

            REM : if exist "GAME_TITLE [XXXXXX]\updates"
            set "folder="!gameFolderName:"=!\updates""

            REM : move "GAME_TITLE [XXXXXX]\updates" to "GAME_TITLE [XXXXXX] (UPDATE DATA)"
            if exist !folder! (
                for /F "delims=~" %%x in ('dir /b !folder! 2^>NUL') do set "version=%%x"
                set "updatePath="!gameFolderName:"=!\updates\!version!""

                move /Y !updatePath! !uName! > NUL 2>&1
                rmdir /Q /S !folder!
                move /Y !uName! ..\..\.. > NUL 2>&1
            )

            REM : if exist "GAME_TITLE [XXXXXX]\aoc0005000C101D6000"
            set "dlcPath="!gameFolderName:"=!\aoc!dtid!""
            REM : move "GAME_TITLE [XXXXXX]\updates" to "GAME_TITLE [XXXXXX] (DLC)" in !GAMES_FOLDER!
            if exist !dlcPath! (
                move /Y !dlcPath! !dName! > NUL 2>&1
                move /Y !dName! ..\..\.. > NUL 2>&1
            )

            move /Y !gameFolderName! ..\..\.. > NUL 2>&1
            
            echo RPX packages moved to !GAMES_FOLDER:"=!
            echo.
            
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :download
    
        wscript /nologo !StartMinimized! !download! !JNUSTFolder! !currentTitleId! !decryptMode! !currentTitleKey!

        if ["!mode!"] == ["sequential"] call:monitorTransfert !gSize!

        REM : if a update exist, download it
        type !titleKeysDataBase! | find /I "!utid!" > NUL 2>&1 && (
            echo ^> Downloading update found for !currentTitle! [!currentTitleRegion!]^.^.^.
            echo ^> Downloading update found for !currentTitle! [!currentTitleRegion!]^.^.^. >> !gamelogFile!
            wscript /nologo !StartMinimized! !download! !JNUSTFolder! !utid! !decryptMode!
            set /A "guSize=gSize+uSize"

            if ["!mode!"] == ["sequential"] call:monitorTransfert !guSize!
        )

        REM : if a DLC exist, download it
        type !titleKeysDataBase! | find /I "!dtid!" > NUL 2>&1 && (
            echo ^> Downloading DLC found !currentTitle! [!currentTitleRegion!]^.^.^.
            echo ^> Downloading DLC found !currentTitle! [!currentTitleRegion!]^.^.^. >> !gamelogFile!
            wscript /nologo !StartMinimized! !download! !JNUSTFolder! !dtid! !decryptMode!

            if ["!mode!"] == ["sequential"] call:monitorTransfert !threshold!
        )

        if ["!mode!"] == ["parallelized"] call:monitorTransfert !threshold!

    goto:eof
    REM : ------------------------------------------------------------------


    REM : compute size on disk
    REM : note that the estimatation here is lower than the real size
    REM : and will be used as thershold
    :getSizeOnDisk

        set "sizeInMb=%~1"

        for /f %%b in ('powershell !sizeInMb!*1024*1024') do set "sizeInB=%%b"

        for /f %%b in ('powershell !sizeInB!/!clusterSizeInB!') do set "nbClustersNeeded=%%b"

        for /f %%b in ('powershell ^(!nbClustersNeeded!+1^)*!clusterSizeInB!') do set "sizeOnDiskNeededinB=%%b"

        echo !sizeOnDiskNeededinB! | find "," > NUL 2>&1 && for /F "delims=, tokens=1" %%b in ("!sizeOnDiskNeededinB!") do set /A "sizeOnDiskNeededinB=%%b"
        echo !sizeOnDiskNeededinB! | find "." > NUL 2>&1 && for /F "delims=. tokens=1" %%b in ("!sizeOnDiskNeededinB!") do set /A "sizeOnDiskNeededinB=%%b"

        set "sizeOnDiskNeededinMb=!sizeOnDiskNeededinB:~0,-6!"

        set /A "%2=!sizeOnDiskNeededinMb!"

    goto:eof
    REM : ------------------------------------------------------------------

    :endAllTransferts

        for /F "delims=~" %%p in ('wmic path Win32_Process where ^"CommandLine like ^'%%downloadTitleId%%^'^" get ProcessID^,commandline') do (
            set "line=%%p"
            set "line2=!line:""="!"
            set "pid=NOT_FOUND"
            echo !line2! | find /V "wmic" | find /V "ProcessID"  > NUL 2>&1 && for %%d in (!line2!) do set "pid=%%d"
            if not ["!pid!"] == ["NOT_FOUND"] taskkill /F /pid !pid! /T > NUL 2>&1
        )
    goto:eof
    REM : ------------------------------------------------------------------
    :monitorTransfert

        set /A "t=%~1"

        echo threshold used ^: !t! >> !gamelogFile!
        set /A "previous=0"
        set /A "nb2sec=0"
        set /A "finalize=0"

        REM : wait until all transferts are done
        :waitingLoop
        timeout /T 5 > NUL 2>&1
        set /A "nb5sec+=1"

        wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "downloadTitleId.bat" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (

            if !finalize! EQU 0 (

            REM : get the JNUSTools folder size
REM : duplicate getFolderSizeInMb function ctontent to avoid implicit resolution of initialGameFolderName (fail if folder use unsupported charcaters)
REM                call:getFolderSizeInMb !initialGameFolderName! sizeDl
                set /A "sizeDl=0"
                
                REM : when data kept crypted 
                if !decryptMode! EQU 0 (
                    set /A "sg=0"
                    set "tmpGf="!JNUSTFolder:"=!/tmp_!titleId!""
                    call:getSizeInMb !tmpGf! sg            
                    set /A "sd=0"
                    set "tmpDf="!JNUSTFolder:"=!/tmp_!dtid!""
                    call:getSizeInMb !tmpDf! sd
                    set /A "su=0"
                    set "tmpUf="!JNUSTFolder:"=!/tmp_!utid!""
                    call:getSizeInMb !tmpUf! su
                    
                    set /A "sizeDl=sg+sd+su"
                    
                ) else (
                
                    set "sizeDl=-1"
                    !du! /accepteula -nobanner -q -c !initialGameFolderName! > !duLogFile!

                    set "sizeRead=-1"
                    for /F "delims=~, tokens=6" %%a in ('type !duLogFile!') do set "sizeRead=%%a"

                    if ["!sizeRead!"] == ["-1"] goto:endSizeInMb
                    if ["!sizeRead!"] == ["0"] set "sizeDl=0" & goto:endSizeInMb

                    REM : 1/(1024^2)=0.00000095367431640625
                    for /F %%a in ('!multiply! !sizeRead! 95367431640625') do set "result=%%a"

                    set /A "lr=0"
                    call:strLength !result! lr
                    REM : size in Mb
                    if !lr! GTR 20 (
                        set /A "sizeDl=!result:~0,-20!"
                    ) else (
                        set /A "sizeDl=1"
                    )

                    :endSizeInMb
                    echo. > NUL 2>&1
          
        REM            call:getSizeInMb !folder! sizeofAll
                )  

                REM : progression
                set /A "curentSize=!sizeDl!
                if !curentSize! LSS !t! (

                    if !curentSize! LEQ !totalSizeInMb! set /A "progression=(!curentSize!*100)/!totalSizeInMb!"
                    
                    set /A "mod=nb5sec%%20"                
                    if !mod! EQU 0 if !previous! EQU !curentSize! (
                        echo. >> !gamelogFile!
                        echo.
                        echo Inactivity detected^! ^, closing current transferts >> !gamelogFile!
                        echo Inactivity detected^! ^, closing current transferts
                        echo. >> !gamelogFile!
                        echo.
                        REM : exit, stop transferts, they will be relaunched
                        call:endAllTransferts
                        goto:eof

                    )
                    set /A "previous=!curentSize!"
                        
                ) else (

                    echo. >> !gamelogFile!
                    echo threshold !t! reached >> !gamelogFile!
                    echo data size downloaded when threshold reached ^: !curentSize! >> !gamelogFile!

                    if !curentSize! LEQ !totalSizeInMb! set /A "progression=(!curentSize!*100)/!totalSizeInMb!"
                    if !decryptMode! EQU 0 title Downloading WUP of !currentTitle! [!currentTitleRegion!] ^: !progression!%%
                    if !decryptMode! EQU 1 title Downloading RPX package of !currentTitle! [!currentTitleRegion!] ^: !progression!%%

                    echo. >> !gamelogFile!
                    echo.
                    echo ^> Finalizing^.^.^. >> !gamelogFile!
                    echo ^> Finalizing^.^.^.
                    set /A "finalize=1"
                    
                    goto:waitingLoop
                )

                if !decryptMode! EQU 0 title Downloading WUP of !currentTitle! [!currentTitleRegion!] ^: !progression!%%
                if !decryptMode! EQU 1 title Downloading RPX package of !currentTitle! [!currentTitleRegion!] ^: !progression!%%
        
                goto:waitingLoop
            ) else (
                if !curentSize! LEQ !totalSizeInMb! set /A "progression=(!curentSize!*100)/!totalSizeInMb!"
                if !decryptMode! EQU 0 title Downloading WUP of !currentTitle! [!currentTitleRegion!] ^: !progression!%%
                if !decryptMode! EQU 1 title Downloading RPX package of !currentTitle! [!currentTitleRegion!] ^: !progression!%%
            
                timeout /t 10 > NULL 
                call:endAllTransferts
            )
        )
        if !decryptMode! EQU 0 title Downloading WUP of !currentTitle! [!currentTitleRegion!] ^: 100%%
        if !decryptMode! EQU 1 title Downloading RPX package of !currentTitle! [!currentTitleRegion!] ^: 100%%

        REM : get the initialGameFolderName folder size
REM : duplicate getFolderSizeInMb function ctontent to avoid implicit resolution of initialGameFolderName (fail if folder use unsupported charcaters)
REM        call:getFolderSizeInMb !initialGameFolderName! sizeDl
        set /A "sizeDl=0"
        
        REM : when data kept crypted 
        if !decryptMode! EQU 0 (
            set /A "sg=0"
            set "tmpGf="!JNUSTFolder:"=!/tmp_!titleId!""
            call:getSizeInMb !tmpGf! sg            
            set /A "sd=0"
            set "tmpDf="!JNUSTFolder:"=!/tmp_!dtid!""
            call:getSizeInMb !tmpDf! sd
            set /A "su=0"
            set "tmpUf="!JNUSTFolder:"=!/tmp_!utid!""
            call:getSizeInMb !tmpUf! su
            
            set /A "sizeDl=sg+sd+su"
            
        ) else (
        
            set "sizeDl=-1"
            !du! /accepteula -nobanner -q -c !initialGameFolderName! > !duLogFile!

            set "sizeRead=-1"
            for /F "delims=~, tokens=6" %%a in ('type !duLogFile!') do set "sizeRead=%%a"

            if ["!sizeRead!"] == ["-1"] goto:endSizeInMb
            if ["!sizeRead!"] == ["0"] set "sizeDl=0" & goto:endSizeInMb

            REM : 1/(1024^2)=0.00000095367431640625
            for /F %%a in ('!multiply! !sizeRead! 95367431640625') do set "result=%%a"

            set /A "lr=0"
            call:strLength !result! lr
            REM : size in Mb
            if !lr! GTR 20 (
                set /A "sizeDl=!result:~0,-20!"
            ) else (
                set /A "sizeDl=1"
            )

            :endSizeInMb
            echo. > NUL 2>&1
  
REM            call:getSizeInMb !folder! sizeofAll

        )

        REM : progression
        set /A "curentSize=!sizeDl!
        

        echo downloaded successfully  >> !gamelogFile!
        echo.  >> !gamelogFile!
        echo.  >> !gamelogFile!
        echo data size expected ^(could be bigger than downloaded^): !totalSizeInMb! >> !gamelogFile!
        echo data size downloaded ^: !curentSize! >> !gamelogFile!
        echo.  >> !gamelogFile!

    goto:eof
    REM : ------------------------------------------------------------------

    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof

    REM : ------------------------------------------------------------------
    :getSizeInMb

        set "folder="%~1""
        set "smb=-1"

        !du! /accepteula -nobanner -q -c !folder! > !duLogFile!

        set "sizeRead=-1"
        for /F "delims=~, tokens=6" %%a in ('type !duLogFile!') do set "sizeRead=%%a"

        if ["!sizeRead!"] == ["-1"] goto:endFct
        if ["!sizeRead!"] == ["0"] set "smb=0" & goto:endFct

        REM : 1/(1024^2)=0.00000095367431640625
        for /F %%a in ('!multiply! !sizeRead! 95367431640625') do set "result=%%a"

        set /A "lr=0"
        call:strLength !result! lr
        REM : size in Mb
        if !lr! GTR 20 (
            set /A "smb=!result:~0,-20!"
        ) else (
            set /A "smb=1"
        )

        :endFct

        set "%2=!smb!"
    goto:eof
    REM : ------------------------------------------------------------------

    
    REM REM : ------------------------------------------------------------------
    REM :getFolderSizeInMb

        REM set "folder=%1"
        REM set /A "sizeofAll=0"
        
        REM REM : when data kept crypted 
        REM if !decryptMode! EQU 0 (
            REM set /A "sg=0"
            REM set "tmpGf="!JNUSTFolder:"=!/tmp_!titleId!""
            REM call:getSizeInMb !tmpGf! sg            
            REM set /A "sd=0"
            REM set "tmpDf="!JNUSTFolder:"=!/tmp_!dtid!""
            REM call:getSizeInMb !tmpDf! sd
            REM set /A "su=0"
            REM set "tmpUf="!JNUSTFolder:"=!/tmp_!utid!""
            REM call:getSizeInMb !tmpUf! su
            
            REM set /A "sizeofAll=sg+sd+su"
            
        REM ) else (
        
            REM call:getSizeInMb !folder! sizeofAll
        REM )
        
        REM set "%2=!sizeofAll!"
    REM goto:eof
    REM REM : ------------------------------------------------------------------
        
    
    REM : fetch size of download
    :getSize
        set "tid=%~1"
        set "pat=%~2"
        set "type=%~3"
        set "%4=0"

        set "key=NOT_FOUND"
        for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!tid!" 2^>NUL') do set "key=%%b"

        if ["!key!"] == ["NOT_FOUND"] (
            echo ERROR^: why key is not found ^?
            pause
            goto:eof
        )

        set "logMetaFile="!BFW_LOGS:"=!\jnust_Meta.log""
        del /F !logMetaFile! > NUL 2>&1
        java -jar JNUSTool.jar !tid! !key! -file /meta/meta.xml > !logMetaFile! 2>&1

        set "strRead="
        for /F "delims=~: tokens=2" %%i in ('type !logMetaFile! ^| find "!pat!" 2^>NUL') do set "strRead=%%i"

        set "strSize="
        for /F "tokens=1" %%i in ("!strRead!") do set "strSize=%%i"

        echo !strSize! | findStr /R "^0\.*.$" > NUL 2>&1 && (
            set "intSize=1"
            goto:endFctGetSize
        )
        
        set /A "intSize=0"
        for /F "delims=~. tokens=1" %%i in ("!strSize!") do set /A "intSize=%%i"

        :endFctGetSize
        set "%4=!intSize!"
        set /A "totalSizeInMb=!totalSizeInMb!+!intSize!"
        echo !type! size = !strSize! Mb

        del /F !logMetaFile! > NUL 2>&1
    goto:eof

    REM : create keys file
    :createKeysFile

        echo You need to create the title keys file^.
        echo.
        echo Use Chrome browser to have less hand work to do^.
        echo Google to find ^'Open Source WiiU Title Key^'
        echo Select and paste all in notepad
        echo.
        timeout /T 4 > NUL 2>&1
        wscript /nologo !StartWait! !notePad! "!JNUSTFolder:"=!\titleKeys.txt"
        echo.
        echo.
        echo Save and relaunch this script when done^.
        pause

        exit 80
    goto:eof
    REM : ------------------------------------------------------------------

    REM : JNUSTools file in targetFolder
    :cleanTargetFolder

        pushd !targetFolder!

        del /F config > NUL 2>&1
        del /F JNUSTool.* > NUL 2>&1
        del /F titleKeys.txt > NUL 2>&1 
        del /F updatetitles.csv > NUL 2>&1 

    goto:eof
    REM : ------------------------------------------------------------------

    REM : check if a string contain *
    :checkStr

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed

            set "%2=KO"
            goto:eof
        )
        set "%2=OK"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureGameTitle

        REM : str is expected protected with double quotes
        set "string=%1"

        call:checkStr !string! status
        if ["!status!"] == ["KO"] (
            echo string is not valid
            pause
        )

        set "string=!string:&=!"
        set "string=!string:?=!"
        set "string=!string:\!=!"
        set "string=!string:%%=!"
        set "string=!string:^=!"
        set "string=!string:\=!"
        set "string=!string:/=!"
        set "string=!string:>=!"
        set "string=!string:<=!"
        set "string=!string::=!"
        set "string=!string:|=!"
        
        REM : replace '_' by ' ' (if needed)
        set "string=!string:_= !"

        REM : WUP restrictions
        set "string=!string:™=!"
        set "string=!string:®=!"
        set "string=!string:©=!"
        set "string=!string:É=E!"

        set "%2=!string!"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        REM : build a relative path in case of software is installed also in games folders
        echo msg=!msg! | find %GAMES_FOLDER% > NUL 2>&1 && set "msg=!msg:%GAMES_FOLDER:"=%=%%GAMES_FOLDER:"=%%!"

        if not exist !logFile! (
            set "logFolder="!BFW_LOGS:"=!""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof

       :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------

