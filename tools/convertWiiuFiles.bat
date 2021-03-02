@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    set "THIS_SCRIPT=%~0"

    title Convert Wii-U File formats

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit /b 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""

    set "browseFile="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFileDialog.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\browseFolderDialog.vbs""

    set "notePad="%windir%\System32\notepad.exe""
    set "du="!BFW_RESOURCES_PATH:"=!\du.exe""
    set "multiply="!BFW_TOOLS_PATH:"=!\multiply.bat""

    set "JNUSTFolder="!BFW_RESOURCES_PATH:"=!\JNUST""
    set "wud2app="!JNUSTFolder:"=!\wud2app.exe""
    set "wudComp="!JNUSTFolder:"=!\WudCompress.exe""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "duLogFile="!BFW_PATH:"=!\logs\du.log""

    REM : set current char codeset
    call:setCharSet

    REM : cd to JNUSTFolder
    pushd !JNUSTFolder!

    REM : search if the script convertWiiuFiles is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "convertWiiuFiles.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GEQ 2 (
            echo "ERROR^: The script convertWiiuFiles is already running ^!"
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "convertWiiuFiles.bat" | find /I /V "find"
            pause
            exit /b 100
        )
    )
    REM : search if downloadGames.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "downloadGames.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: downloadGames^.bat is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "downloadGames.bat" | find /I /V "find"
        pause
        exit /b 101
    )
    REM : search if updateGames.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "updateGames.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: updateGames^.bat is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "updateGames.bat" | find /I /V "find"
        pause
        exit /b 102
    )
    REM : check JNUST install
    call:checkJnust

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "startingDate=%ldt%"
    REM : starting DATE

    echo starting date = %startingDate%

    if %nbArgs% NEQ 1 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" CONVERT_ENUM
        echo CONVERT_ENUM=1 ^: convert WUX to WUD
        echo CONVERT_ENUM=2 ^: convert WUD to WUX
        echo CONVERT_ENUM=3 ^: convert WUX to WUP
        echo CONVERT_ENUM=4 ^: convert WUD to WUP
        echo CONVERT_ENUM=5 ^: convert WUX to RPX
        echo CONVERT_ENUM=6 ^: convert WUD to RPX
        echo CONVERT_ENUM=7 ^: convert WUP to RPX
        echo.
        echo given {%*}
        pause
        exit /b 99
    )

    cls

    REM : get and check inputFile
    set "arg1=!args[0]!"
    set "arg1=!arg1:"=!"
    set "arg1=!arg1: =!"
    echo !arg1! | findStr /R /V "[1-7]" > NUL 2>&1 && (
        echo ERROR^: !arg1! is not in [1,7] ^!
        pause
        exit /b 101
    )
    set /A "CONVERT_ENUM=!arg1!"

    if !CONVERT_ENUM! EQU 1 set "goal=Convert WUX to WUD"
    if !CONVERT_ENUM! EQU 2 set "goal=Convert WUX to WUP"
    if !CONVERT_ENUM! EQU 3 set "goal=Convert WUX to RPX"
    if !CONVERT_ENUM! EQU 4 set "goal=Convert WUD to WUX"
    if !CONVERT_ENUM! EQU 5 set "goal=Convert WUD to WUP"
    if !CONVERT_ENUM! EQU 6 set "goal=Convert WUD to RPX"
    if !CONVERT_ENUM! EQU 7 set "goal=Convert WUP to RPX"

    REM : WUP to RPX ?


    title !goal!
    echo =========================================================
    echo !goal!
    echo =========================================================
    echo.

    set /A "shutdownFlag=0"
    if !CONVERT_ENUM! EQU 1 goto:getAFile
    if !CONVERT_ENUM! EQU 4 goto:getAFile

    choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
    if !ERRORLEVEL! EQU 1 (
        echo Please^, save all your opened documents before continue^.^.^.
        pause
        set /A "shutdownFlag=1"
    )
    echo.

    echo Hit any key to launch the conversion
    echo.
    pause
    if !CONVERT_ENUM! EQU 7 goto:wupAsked

    :getAFile
    cls
    echo.
    echo Please browse to the WUX or WUD file ^(game_part1^.wud for a multi part wud game^)^.^.^.

    for /F %%b in ('cscript /nologo !browseFile! "Select a WUX or WUD file (game_part1.wud for a multi part wud game)"') do set "file=%%b" && set "inputFile=!file:?= !"
    if [!inputFile!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 20
        goto:getAFile
    )

    call:secureFilePath !inputFile! newPath

    if not [!inputFile!] == [!newPath!] (

        move /Y !inputFile! !newPath! > NUL 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo !inputFile! contains non supported characters
            echo moving !inputFile! to !newPath!
        )
        if !isWud! EQU 1 (
            set "oldTitleKey=!inputFile:.wud=.key!"
            set "newTitleKey=!newPath:.wud=.key!"
        ) else (
            set "oldTitleKey=!inputFile:.wux=.key!"
            set "newTitleKey=!newPath:.wux=.key!"
        )
        move /Y !oldTitleKey! !newTitleKey! > NUL 2>&1
    )

    REM : flag WUX / WUD ?
    set /A "isWud=0"

    echo !inputFile! | find /I ".wud" > NUL 2>&1 && (
        set /A "isWud=1"

        REM : chek multi Wud
        echo !inputFile! | find /I ".wud" | find /I "_part" > NUL 2>&1 && (
            echo !inputFile! | find /I /V "_part1.wud" > NUL 2>&1 &&  (
                echo !inputFile! is not the part 1 of the multi parts WUD
                pause
                goto:getAFile
            )
        )
    )

    REM : check title.key presence
    if !isWud! EQU 1 (
        echo !inputFile! | find /I /V "_part1.wud" > NUL 2>&1 && set "titleKey=!inputFile:_part1.wud=.key!"
        set "titleKey=!inputFile:.wud=.key!"
    ) else (
        set "titleKey=!inputFile:.wux=.key!"
    )

    if !CONVERT_ENUM! NEQ 7 if !CONVERT_ENUM! NEQ 4 if !CONVERT_ENUM! NEQ 1 if not exist !titleKey! (
        echo !titleKey! not found close to wud file^, please fix
        echo If you don^'t have key^, maybe there^'s no need ^: try to download
        echo the game using ^'Wii-U Games\Download Games^.lnk^'
        pause
        exit /b 15
    )

    set /A "keepWup=0"

    if !CONVERT_ENUM! EQU 1 goto:compressor
    if !CONVERT_ENUM! EQU 4 goto:compressor

    if !CONVERT_ENUM! EQU 2 goto:wupAsked
    if !CONVERT_ENUM! EQU 5 goto:wupAsked

    REM : here CONVERT_ENUM=3,6 or 7
    choice /C yn /N /M "Do you wish to keep the WUP package generated (y, n)? : "
    if !ERRORLEVEL! EQU 2 goto:wud2app

    :wupAsked
    set "msg=Please browse to the folder where to put the WUP package..."

    if !CONVERT_ENUM! EQU 7 (
        set "msg=Please browse to the WUP..."
    ) else (
        set /A "mod3=CONVERT_ENUM%%3"
        if !mod3! EQU 0 (
            set "msg=Please browse to the folder where to keep the WUP package..."
            set /A "keepWup=1"
        )
    )
    echo.
    echo !msg!

    :getWupFolder
    set "wupFolder="NOT_FOUND""

    for /F %%b in ('cscript /nologo !browseFolder! !msg!') do set "folder=%%b" && set "wupFolder=!folder:?= !"
    if [!wupFolder!] == ["NOT_FOUND"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && goto:EndMain
        goto:getWupFolder
    )

    REM : check if folder name contains forbiden character for !CEMU_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !wupFolder!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !wupFolder! is not DOS compatible^!^, please choose another location
        pause
        goto:getWupFolder
    )
    if !CONVERT_ENUM! NEQ 7 (
        echo.
        echo ^> WUP package will be copied to !wupFolder! when done
    )
    if !CONVERT_ENUM! GEQ 4 goto:wud2app

    :compressor
    echo.
    set "msg=^> Uncompressing !inputFile!^.^.^."
    if !CONVERT_ENUM! EQU 4 set "msg=^> Compressing !inputFile!^.^.^."
    echo ---------------------------------------------------------
    REM : check size Needed

    REM : a WUD file is 23866 MB (~24000)
    set /A "sizeNeeded=24000"

    REM : even WUD -> WUX, check that 24000 MB are free

    call:checkSizeAvailable !drive! !sizeNeeded!
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

    echo !msg!
    REM : WUX to WUD conversion
    call !wudComp! !inputFile!
    if !ERRORLEVEL! NEQ 0 (
        echo "ERROR^: wudCompressor error
        pause
        exit /b 51
    )

    echo.

    if !CONVERT_ENUM! EQU 1 goto:endMain
    if !CONVERT_ENUM! EQU 4 goto:endMain
    echo ---------------------------------------------------------

    :wud2app
    if !CONVERT_ENUM! EQU 7 goto:wup2rpx

    set "commonKey="!JNUSTFolder:"=!\common.key""
    if not exist !commonKey! call:createCommonKey

    echo.
    echo ^> Converting WUD to WUP package^.^.^."
    echo ---------------------------------------------------------
    REM : a WUD file is 23866 MB (~24000)
    set /A "sizeNeeded=24000"

    REM : even for WUP, check that 24000 MB are free
    call:checkSizeAvailable !drive! !sizeNeeded!
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

    REM : convert using wud2app
    call !wud2app! !commonKey! !titleKey! !inputFile!
    if !ERRORLEVEL! NEQ 0 (
        echo "ERROR^: wud2app error
        pause
        exit /b 61
    )

    REM : get the last folder created under !JNUSTFolder:"=!\
    set "lastWupFolder="NOT_FOUND""
    set "pat="!JNUSTFolder:"=!\WUP*""
    for /F "delims=~" %%g in ('dir /S /B /O:-D /T:W !pat! 2^>NUL') do set "lastWupFolder="%%g""

    if [!lastWupFolder!] == ["NOT_FOUND"] (
        echo "ERROR^: wud2app output not found ^!
        pause
        exit /b 62
    )
    echo !lastWupFolder! created sucessfully
    echo ---------------------------------------------------------

    if !CONVERT_ENUM! EQU 2 set "srcJtf=!lastWupFolder!" & goto:moveWup
    if !CONVERT_ENUM! EQU 5 set "srcJtf=!lastWupFolder!" & goto:moveWup

    :wup2rpx
    if !CONVERT_ENUM! EQU 7 set "lastWupFolder=!wupFolder!"

    call:getTitleData titleId GAME_TITLE productCode
    if !ERRORLEVEL! NEQ 0 (
        echo "ERROR^: WUP game not found in internal database ^!
        pause
        exit /b 70
    )

    REM : get the size of the WUP package
    call:getSizeInMb !lastWupFolder! sizeWup
echo WUP size = !sizeWup! MB

    REM : check size available on drive (counting Wup size for RPX files)
    call:checkSizeAvailable !drive! !sizeWup!
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

    REM : JNUST WUP temporary folder
    set "srcJtf="!JNUSTFolder:"=!\tmp_!titleId!""
    set /A "moved=0"

    if !CONVERT_ENUM! EQU 7 (
        REM : robocopy
        robocopy !lastWupFolder! !srcJtf! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 7 (
            echo ERROR^: when Copying !lastWupFolder! to !srcJtf!^, aborting^.^.^.
            pause
            exit /b 72
        )
        set /A "moved=0"
        set /A "keepWup=0"
    ) else (

        REM : source drive
        for %%a in (!lastWupFolder!) do set "sourceDrive=%%~da"
        REM : target drive
        for %%a in (!JNUSTFolder!) do set "targetDrive=%%~da"


        REM : if folders are on the same drive
        if ["!sourceDrive!"] == ["!targetDrive!"] (
            REM : no need to check size

            move /Y !lastWupFolder! !srcJtf! > NUL 2>&1
            set /A "cr=%ERRORLEVEL%"
            if !cr! NEQ 0 (
                echo ERROR^: when moving !lastWupFolder! to !srcJtf!^, aborting^.^.^.
                pause
                exit /b 71
            )
            set /A "moved=1"
        ) else (
            REM : check size available on target drive
            call:checkSizeAvailable !drive! !sizeWup!
            if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

            REM : robocopy
            robocopy !lastWupFolder! !srcJtf! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"
            if !cr! GTR 7 (
                echo ERROR^: when Copying !lastWupFolder! to !srcJtf!^, aborting^.^.^.
                pause
                exit /b 72
            )
        )
    )
echo Using temporary folder !srcJtf!

    echo ---------------------------------------------------------
    echo ^> Converting WUP to RPX package^.^.^."

    set "wupBatFile="!JNUSTFolder:"=!\wup.bat""
    del /F "jnust.log" > NUL 2>&1
    echo java -jar JNUSTool^.jar %titleId% ^> jnust^.log > !wupBatFile!
    wscript /nologo !StartHidden! !wupBatFile!

    timeout /T 2 > NUL 2>&1
    REM : kill
    wmic path Win32_Process where "CommandLine like '%%JNUSTool.jar %titleId%%%'" call terminate > NUL 2>&1
    del /F !wupBatFile! > NUL 2>&1

    REM : get the decrypted key
    for /F "tokens=2 delims=~:" %%d in ('type jnust^.log 2^>NUL ^| find "Encrypted Key"') do set "keyRead=%%d"
    set "encKey=%keyRead: =%"

echo Encrypted Key=%encKey%

    REM : decrypth and uncompress
    java -jar JNUSTool.jar !titleId! %encKey%  -file /.*

echo JNUST return code = !ERRORLEVEL!

    REM : get the last folder created under !JNUSTFolder:"=!\
    set "rpxFolder="NOT_FOUND""
    set "pat="!JNUSTFolder:"=!\*[*]""
    for /F "delims=~" %%g in ('dir /S /B /O:-D /T:W !pat! 2^>NUL') do set "rpxFolder="%%g""

    if [!rpxFolder!] == ["NOT_FOUND"] (
        echo "ERROR^: RPX output folder not found ^!
        pause
        exit /b 73
    )
    set "metaFile="!rpxFolder:"=!\meta\meta.xml""
    if not exist !metaFile! (
        echo "ERROR^: empty output RPX folder ^^?
        echo "        !metaFile! not found
        pause
        exit /b 74
    )

    REM REM : copy title.* files in ./code folder
    REM set "pat="!srcJtf:"=!\title.*""
    REM for /F "delims=~" %%g in ('dir /S /B /A:F !pat! 2^>NUL') do (
        REM set "srcTitleFile="%%g""
        REM for /F "delims=~" %%i in (!srcTitleFile!) do set "name=%%~nxi"

        REM set "tgtTitleFile="!rpxFolder:"=!\code\!name!""
        REM move /Y !srcTitleFile! !tgtTitleFile! > NUL 2>&1
    REM )

    REM : rename RPX package
    set "finalFolder="!JNUSTFolder:"=!\!GAME_TITLE!""
    if not exist !finalFolder! (
        move /Y !rpxFolder! !finalFolder! > NUL 2>&1

        set "gamePath="!GAMES_FOLDER:"=!\!GAME_TITLE!""
        if not exist !gamePath! (
            move /Y !finalFolder! ..\..\.. > NUL 2>&1
        ) else (
            rmdir/Q /S !rpxFolder! > NUL 2>&1
        )
    )
    echo ^> RPX package moved to !GAMES_FOLDER:"=!
    echo   Launch setup or create script to take it into account

    echo ---------------------------------------------------------

    :moveWup
    REM : init for a WUP output (CONVERT_ENUM=3,4)

    set "targetFolder="!wupFolder:"=!\!productCode:"=!_!GAME_TITLE: =!""
    set /A "wupIsFinal=0"

    if !CONVERT_ENUM! EQU 2 set /A "wupIsFinal=1"
    if !CONVERT_ENUM! EQU 5 set /A "wupIsFinal=1"

    if !wupIsFinal! EQU 1 (

        for /F "delims=~" %%i in (!lastWupFolder!) do set "wupName=%%~nxi"
        set "targetFolder="!wupFolder:"=!\!wupName!""
        if exist !targetFolder! goto:endMain

        REM : target drive
        for %%a in (!wupFolder!) do set "targetDrive=%%~da"
        if ["!sourceDrive!"] == ["!targetDrive!"] (
            REM : move back user WUP package
            move /Y !srcJtf! !targetFolder! > NUL 2>&1
        ) else (

            REM : check size available on target drive
            call:checkSizeAvailable !targetDrive! !sizeWup!
            if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

            REM : robocopy
            robocopy !srcJtf! !targetFolder! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
        )
        echo ^> WUP package copied under !targetFolder!

    ) else (

        if !keepWup! EQU 1 (

            set "targetFolder="!wupFolder:"=!\!productCode:"=!_!GAME_TITLE: =!""
            if exist !targetFolder! goto:endMain
            REM : target drive
            for %%a in (!wupFolder!) do set "targetDrive=%%~da"

            if ["!sourceDrive!"] == ["!targetDrive!"] (
                REM : move back user WUP package
                move /Y !srcJtf! !targetFolder! > NUL 2>&1
            ) else (
                REM : check size available on target drive
                call:checkSizeAvailable !targetDrive! !sizeWup!
                if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

                REM : robocopy
                robocopy !srcJtf! !targetFolder! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
            )
            echo ^> WUP package copied under !targetFolder!
        ) else (
            if !moved! EQU 1 (
                REM : move back user WUP package
                move /Y !srcJtf! !targetFolder! > NUL 2>&1
            ) else (
                REM : was copied, clean JNUST folder
                rmdir /Q /S !srcJtf! > NUL 2>&1
            )
        )
    )
    :endMain
    echo =========================================================
    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "endingDate=%ldt%"

    echo starting date = %startingDate%
    echo ending date = %endingDate%

    REM : if shutdwon is asked
    if !shutdownFlag! EQU 1 echo shutdown in 5min^.^.^. & timeout /T 300 /NOBREAK & shutdown -s -f -t 00
    pause
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : check JNUST pre-requisites and installation
    :checkJnust

        REM : exit in case of no JNUSTFolder folder exists
        if not exist !JNUSTFolder! (
            echo ERROR^: !JNUSTFolder! not found
            pause
            exit /b 50
        )
        REM : check if java is installed
        java -version > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo ERROR^: java is not installed^, exiting
            pause
            exit /b 51
        )

        REM : check if an active network connexion is available
        set "ACTIVE_ADAPTER=NOT_FOUND"
        for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
        if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
            echo ERROR^: no active network connection found^, exiting
            pause
            exit 52
        )

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
            exit /b 53
        )
    goto:eof
    REM : ------------------------------------------------------------------


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

        exit /b 55
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

    :hex2str
        set "NotDelayed=!"
        setlocal enableDelayedExpansion
        set "tempFile=!temp!\hex2str%random%"
        if "%~2" equ "" (
          >"!tempFile!.hex" echo %~1
          >NUL 2>&1 certutil -f -decodehex "!tempFile!.hex" "!tempFile!.txt"
          type "!tempFile!.txt"
          2>NUL del "!tempFile!.hex" "!tempFile!.txt"
          goto:eof
        )
        set "hex=%~1"
        set "hex=!hex:25=25 35!"
        set "hex=!hex:22=25 7e 36!"
        set "hex=!hex:0A=25 7e 33!"
        set "hex=!hex:0D=25 34!"
        if not defined NotDelayed (
          set "hex=!hex:5e=5e 5e!"
          set "hex=!hex:21=5e 21!"
        )
        >"!tempFile!.hex" echo !hex!
        >NUL 2>&1 certutil -f -decodehex "!tempFile!.hex" "!tempFile!.txt"
        setlocal disableDelayedExpansion
        for /f usebackq^ delims^=^ eol^= %%a in ("%tempFile%.txt") do set "rtn=%%a"
        setlocal enableDelayedExpansion
        set LF=^


        set "replace=%% """"
        for %%3 in ("!LF!") do for /f %%4 in ('copy /Z "%~dpf0" NUL') do (
          for /f "tokens=1,2" %%5 in ("!replace!") do (
            endlocal
            endlocal
            endlocal
            endlocal
            set "%~2=%rtn%" !
            2>NUL del "%tempFile%.hex" "%tempFile%.txt"
          )
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :readLine
        set "file=%1"
        set /A "lineNumber=%~2"

        set /A "currentLine=1"
        For /F "delims=~" %%l in ('type !file! 2^>NUL') do (
            if !currentLine! EQU !lineNumber! set "%3="%%l"" & exit /b 0
            set /A "currentLine+=1"
        )
        set /A "currentLine-=1"
        echo WARNING^: End of file reached ^(!currentLine! lines read^)^!

        exit /b 50
    goto:eof
    REM : ------------------------------------------------------------------

    REM : create common.key for wud2app.exe using JNUST\config file
    :createCommonKey

        set "cf="!JNUSTFolder:"=!\config""
        set /A "lineNumber=2"

        call:readLine !cf! %lineNumber% line
        if !ERRORLEVEL! NEQ 0 (
            echo ERROR^: in readLine function
            exit /b 50
        )

        REM : get line length
        call:strLength !line! length

        set /A "range=length-1"
        set /A "nbChar=2"

        REM : check consistency
        set /A "mod=range%nbChar"
        if !mod! NEQ 0 (
            echo "ERROR^: modulo range%nbChar is not odd
            exit /b 50
        )
        set "bytes="
        for /L %%l in (0,%nbChar%,%range%) do (
            set "str=!line:"=!"
            set "subStr=!str:~%%l,%nbChar%!"

            if ["!bytes!"] == [""] (
                set "bytes=!bytes!!subStr!"
            ) else (
                set "bytes=!bytes! !subStr!"
            )
        )
        call:hex2str "!bytes!" strBytes
        set "ck="!JNUSTFolder:"=!\common.key""

        REM : create the common key
        set /p=!strBytes!>!ck!
        exit /b 0
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


    :checkSizeAvailable
        REM : get drive
        set "localDrive=%~1"

        set /A "sizeNeeded=%~2"

        REM : Compute space left on localDrive
        REM : a WUD file is 24 000 MB, the WUP will be less but let's use 24000 for the check

        set "psc="Get-CimInstance -ClassName Win32_Volume ^| Select-Object Name^, FreeSpace^, BlockSize ^| Format-Table -AutoSize""
        for /F "tokens=2-3" %%i in ('powershell !psc! ^| find "!localDrive!" 2^>NUL') do set "fsbStr=%%i"

        REM : free space in Kb
        set /A "fskb=!fsbStr:~0,-3!"
        REM : free space in Mb
        set /A "spaceLeftInMb=fskb/1024"

        REM : check available space
        if !sizeNeeded! GEQ !spaceLeftInMb! (
            echo Not enought space left on !localDrive! to process ^(!spaceLeftInMb!Mb and !sizeNeeded!Mb are requiered^) ^, aborting^.^.^.
            pause
            exit /b 40
        )
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------


    :getTitleData

        for /F "delims=~" %%i in (!lastWupFolder!) do set "wupName=%%~nxi"

        REM : get the game code
        set "gameCode=%wupName:~6,4%"
echo gameCode=!gameCode!
        REM : get game's title from wii-u database file
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "!gameCode!;"') do set "libFileLine="%%i""

        if [!libFileLine!] == ["NONE"] (
            echo ERROR^: gameCode !gameCode! computed with the 4 last character of WUP name !wupName!
            echo         not found in !wiiTitlesDataBase!^, aborting^.^.^.
            pause
            exit /B 70

        )

        REM : strip line to get data
        for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
           set "titleId=%%a"
           set "Desc=%%b"
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
echo titleId=!titleId:'=!
echo Desc=!Desc!
echo productCode=!productCode!

        set "%1=!titleId:'=!"
        set "%2=!Desc!"
        set "%3=!productCode!"


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
    :secureFilePath

        REM : str is expected protected with double quotes
        set "string=%1"

        call:checkStr !string! status
        if ["!status!"] == ["KO"] (
            echo string is not valid
            pause
            goto:eof
        )

        set "string=!string:&=!"
        set "string=!string:?=!"
        set "string=!string:\!=!"
        set "string=!string:%%=!"
        set "string=!string:^=!"
        set "string=!string:/=!"
        set "string=!string:>=!"
        set "string=!string:<=!"
        set "string=!string:)=]!"
        set "string=!string:(=[!"
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

    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
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


        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg! >> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
