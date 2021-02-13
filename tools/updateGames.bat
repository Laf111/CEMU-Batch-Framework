@echo off
endlocal
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    title Search^, download and install games^' updates
    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    REM : BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "fnrLogUg="!BFW_PATH:"=!\logs\fnr_updateGames.log""

    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "duLogFile="!BFW_LOGS:"=!\du.log""

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "du="!BFW_RESOURCES_PATH:"=!\du.exe""
    set "JNUSTFolder="!BFW_RESOURCES_PATH:"=!\JNUST""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "downloadTid="!BFW_TOOLS_PATH:"=!\downloadTitleId.bat""
    set "multiply="!BFW_TOOLS_PATH:"=!\multiply.bat""
    set "checkGameContentAvailability="!BFW_TOOLS_PATH:"=!\checkGameContentAvailability.bat""

    set "notePad="%windir%\System32\notepad.exe""
    set "explorer="%windir%\explorer.exe""

    REM : output folder
    set "targetFolder=!GAMES_FOLDER!"

    REM : set current char codeset
    call:setCharSet

    REM : search if this script is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "updateGames.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GEQ 2 (
            echo "ERROR^: This script is already running ^!"
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "updateGames.bat" | find /I /V "find"
            pause
            exit 50
        )
    )

    REM : search if the script downloadGames is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "downloadGames.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GEQ 2 (
            echo "ERROR^: The script downloadGames is already running ^!"
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "downloadGames.bat" | find /I /V "find"
            timeout /t 2 > NUL 2>&1
            exit /b 50
        )
    )

    REM : exit in case of no JNUSTFolder folder exists
    if not exist !JNUSTFolder! (
        echo ERROR^: !JNUSTFolder! not found
        exit /b 80
    )

    REM : check if cemu if not already running
    set /A "nbI=0"

    for /F "delims=~" %%j in ('tasklist ^| find /I "cemu.exe" ^| find /I /V "find" /C') do set /A "nbI=%%j"
    if %nbI% NEQ 0 (
        !MessageBox! "ERROR ^: Cemu is already running in the background ^! ^(nbi=%nbI%^)^. If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!" 4112
        echo "ERROR^: CEMU is already running ^!"
        tasklist | find /I "cemu.exe" | find /I /V "find"
        timeout /t 4 > NUL 2>&1
        exit 50
    )

    REM : search if the script downloadGames is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "downloadGames.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GEQ 2 (
            echo "ERROR^: The script downloadGames is already running ^!"
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "downloadGames.bat" | find /I /V "find"
            timeout /t 4 > NUL 2>&1
            exit /b 50
        )
    )

    REM : check if java is installed
    java -version > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: java is not installed^, exiting
        pause
        exit 50
    )

    REM : check if an active network connexion is available
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo ERROR^: no active network connection found^, exiting
        pause
        exit 51
    )

    set "config="!JNUSTFolder:"=!\config""
    type !config! | find "[COMMONKEY]" > NUL 2>&1 && (
        echo To use this feature^, obviously you^'ll have to setup JNUSTool
        echo and get the files requiered by yourself^.
        echo.
        echo First you need to find the ^'Wii U common key^' with google
        echo It should be 32 chars long and start with ^'D7^'^.
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

    REM : pattern used to evaluate size of games : set always extracted size since size of some cryted titles are wrong
    set "str="Total Size of Decrypted Files""

    REM : compute sizes on disk JNUSTFolder
    for %%a in (!JNUSTFolder!) do set "targetDrive=%%~da"

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    echo =========================================================
    echo Update my games ^(get and install last updates and DLC^)
    echo =========================================================
    echo.

    set /A "askUser=1"
    choice /C yn /N /M "Download all contents WIHTOUT any space left checks between each download (y/n)? : "
    if !ERRORLEVEL! EQU 1 set /A "askUser=0"
    echo.

    set /A "shutdownFlag=0"
    choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
    if !ERRORLEVEL! EQU 1 (
        echo Please^, save all your opened documents before continue^.^.^.
        pause
        set /A "shutdownFlag=1"
    )
    
    set /A "NB_UPDATE_TREATED=0"
    set /A "NB_DLC_TREATED=0"

    REM : loop on game's code folders found
    for /F "delims=~" %%g in ('dir /b /o:n /a:d /s code 2^>NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        set "codeFullPath="%%g""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        call:treatUpdate
        call:treatDlc
    )

    echo Updated !NB_UPDATE_TREATED! games
    echo Installed !NB_DLC_TREATED! DLC
    echo.

    REM : if shutdwon is asked
    if !shutdownFlag! EQU 1 echo shutdown in 30s^.^.^. & timeout /T 30 /NOBREAK & shutdown -s -f -t 00
    pause

    endlocal
    exit 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    :treatUpdate

        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        REM : cd to codeFolder
        pushd !codeFolder!
        set "RPX_FILE="project.rpx""
	    REM : get bigger rpx file present under game folder
        if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : GAME_FILE_PATH path (rpx file)
        set "GAME_FILE_PATH="!GAME_FOLDER_PATH:"=!\code\!RPX_FILE:"=!""

        REM : basename of GAME FOLDER PATH (used to name shorcut)
        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        echo treating "!GAME_TITLE!"^.^.^.

        set "updatePath="NOT_FOUND""
        set "endTitleId=NOT_FOUND"
        set "updateVersion=NOT_FOUND"
        set /A "updateSize=0"

        REM : check if game need to be updated
        set "logUpdateGames="!BFW_LOGS:"=!\updateGames.log""
        del /F !logUpdateGames! > NUL 2>&1

        call !checkGameContentAvailability! !GAME_FOLDER_PATH! 0005000e > !logUpdateGames!
        set /A "cr=%ERRORLEVEL%"

        if %cr% NEQ 1 goto:eof

        for /F "delims=~? tokens=1-3" %%i in ('type !logUpdateGames! 2^>NUL') do (
            set "updatePath=%%i"
            set "endTitleId=%%j"
            set /A "updateSize=%%k"
        )
        REM : no new update found, exit function
        if %updateSize% EQU 0 goto:eof

        REM : Get the version of the update
        for /F "delims=~" %%i in (!updatePath!) do set "folder=%%~nxi"
        set "updateVersion=!folder:v=!"

        echo =========================================================
        echo - Update !GAME_TITLE! with v%updateVersion% ^(%updateSize% MB^)
        echo ---------------------------------------------------------

        for %%a in (!updatePath!) do set "parentFolder="%%~dpa""
        set "updatesFolder=!parentFolder:~0,-2!""
        for %%a in (!updatesFolder!) do set "parentFolder="%%~dpa""
        set "gamesFolder=!parentFolder:~0,-2!""
        set "initialGameFolderName=!gamesFolder:%JNUSTFolder:"=%\=!"

        echo.
        echo Note that if 60FPS and^/or FPS^+^+ GFX packs for this game were not built
        echo for this version^, updating could break them^.
        echo.
        if !askUser! EQU 1 pause

        pushd !JNUSTFolder!
        set "psc="Get-CimInstance -ClassName Win32_Volume ^| Select-Object Name^, FreeSpace^, BlockSize ^| Format-Table -AutoSize""
        for /F "tokens=2-3" %%i in ('powershell !psc! ^| find "!targetDrive!" 2^>NUL') do (
            set "fsbStr=%%i"
            set /A "clusterSizeInB=%%j"
        )

        REM : free space in Kb
        set /A "fskb=!fsbStr:~0,-3!"
        set /A "freeSpaceLeft=fskb/1024"

        REM : compute size need on targetDrive
        call:getSizeOnDisk !updateSize! sizeNeededOnDiskInMb
        set /A "totalSpaceNeeded=sizeNeededOnDiskInMb"

        echo.
        if !totalSpaceNeeded! LSS !freeSpaceLeft! (
            echo At least !totalSpaceNeeded! Mb are requiered on disk !targetDrive! ^(!freeSpaceLeft! Mb estimate left^)

        ) else (
            echo ERROR ^: not enought space left on !targetDrive!
            echo Needed !totalSpaceNeeded! ^/ still available !freeSpaceLeft! Mb
            echo Ignoring this game
            goto:eof
        )

        if !askUser! EQU 1 (
            choice /C yn /N /M "Download this update now (y/n)? : "
            if !ERRORLEVEL! EQU 2 goto:eof
        )

        echo.
        echo If you want to pause the current tranfert or if you get errors during the transfert^,
        echo close this windows then the child cmd console in your task bar
        echo and relaunch this script to complete the download^.
        echo.

        REM : download update
        call:downloadUpdate

    goto:eof
    REM : ------------------------------------------------------------------


    :renameFolder
        set "srcFolderPath=%~1"
        set "tgtFolderPath=%~2"

        REM : basename of tmpFolderPath
        for /F "delims=~" %%i in ("%srcFolderPath%") do set "folderName=%%~nxi"

        set "initialFolder="%tgtFolderPath%\%folderName%""
        set "finalFolder="%tgtFolderPath%\!endTitleId!""

        move /Y !initialFolder! !finalFolder! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    :downloadUpdate

        set /A "totalSizeInMb=%updateSize%"

        REM : remove 10Mb to totalSizeInMb (threshold)
        set /A "threshold=!totalSizeInMb!"
        if !threshold! GEQ 10 set /A "threshold=!totalSizeInMb!-9"

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "date=%ldt%"
        REM : starting DATE

        echo ---------------------------------------------------------------
        echo Starting at !date!
        echo.

        set /A "progression=0"

        :initUpdateDownload

        REM : download the game
        call:download 0005000e %updateVersion%

        REM : get the JNUSTools folder size
        call:getFolderSizeInMb !initialGameFolderName! sizeDl

        REM : do not continue if not complete (in case of user close downloading windows before this windows)
        set /A "progression=(!sizeDl!*100)/!totalSizeInMb!"

        if !progression! LSS 85 (
            echo ---------------------------------------------------------------
            echo Transfert seems to be incomplete^, relaunching^.^.^.
            echo.
            goto:initUpdateDownload
        )

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "date=%ldt%"

        REM : ending DATE
        echo.
        echo Ending at !date!
        echo ===============================================================

        REM : install the update
        set "targetUpdatePath="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000e""
        set "tmpUpdatePath=!updatePath!"

        set /A "attempt=1"
        if not exist !targetUpdatePath! (
            mkdir !targetUpdatePath! > NUL 2>&1
            goto:tryToMoveNewUpdate
        )
        set "tmpUpdatePath="!targetUpdatePath:"=!_tmp""

        :tryToMoveUpdate

        move /Y !updatePath! !tmpUpdatePath! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving !tmpUpdatePath:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMoveUpdate
            )
            REM : basename of tmpUpdatePath to get folder's name
            for /F "delims=~" %%i in (!tmpUpdatePath!) do set "folderName=%%~nxi"
            call:fillOwnerShipPatch !tmpUpdatePath! "!folderName!" patch

            !MessageBox! "Move still failed^, take the ownership on !tmpUpdatePath:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMoveUpdate

            REM : else skipping
            echo ERROR^: failed to move !updatePath! to !tmpUpdatePath!^, skipping
            goto:eof
        )
        call:renameFolder !updatePath! !tmpUpdatePath!

        REM : move old update
        set "oldUpdatePath="!targetUpdatePath:"=!_old""

        REM : move update folder (targetUpdatePath) to oldUpdatePath
        set /A "attempt=1"
        :tryToMoveOldUpdate

        move /Y !targetUpdatePath! !oldUpdatePath! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving to !targetUpdatePath:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMoveOldUpdate
            )
            REM : basename of targetUpdatePath
            for /F "delims=~" %%i in (!targetUpdatePath!) do set "folderName=%%~nxi"
            call:fillOwnerShipPatch !targetUpdatePath! "!folderName!" patch

            !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMoveOldUpdate

            REM : else skipping
            echo ERROR^: failed to move !targetUpdatePath! to !oldUpdatePath!^, skipping and leave !tmpUpdatePath!
            goto:eof

        )
        call:renameFolder !targetUpdatePath! !oldUpdatePath!

        REM : move update folder (tmpUpdatePath) to targetUpdatePath
        set /A "attempt=1"
        :tryToMoveNewUpdate

        move /Y !tmpUpdatePath! !targetUpdatePath! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving to !targetUpdatePath:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMoveNewUpdate
            )
            REM : basename of targetUpdatePath
            for /F "delims=~" %%i in (!targetUpdatePath!) do set "folderName=%%~nxi"
            call:fillOwnerShipPatch !targetUpdatePath! "!folderName!" patch

            !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMoveNewUpdate

            REM : else skipping
            echo ERROR^: failed to move !tmpUpdatePath! to !targetUpdatePath!^, skipping
            goto:eof
        )
        if exist !oldUpdatePath! rmdir /Q /S !oldUpdatePath!

        call:renameFolder !tmpUpdatePath! !targetUpdatePath!

        set /A "NB_UPDATE_TREATED+=1"
        timeout /T 3 > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :getInteger
        Set "str=%~1"

        Set "s=#%str%"
        Set "len=0"

        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )

        set /A "index=0"
        set /A "left=len"
        set /A "lm1=len-1"

        for /L %%l in (0,1,%lm1%) do (
            set "char=!str:~%%l,1!"
            if not ["!char!"] == ["0"] (
                set /A "left=%len%-%%l"
                set /A "index=%%l"
                goto:intFound
            )
        )
        :intFound

        set "%2=!str:~%index%,%left%!"

    goto:eof

    
    :treatDlc

        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        REM : cd to codeFolder
        pushd !codeFolder!
        set "RPX_FILE="project.rpx""
	    REM : get bigger rpx file present under game folder
        if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : GAME_FILE_PATH path (rpx file)
        set "GAME_FILE_PATH="!GAME_FOLDER_PATH:"=!\code\!RPX_FILE:"=!""

        REM : basename of GAME FOLDER PATH (used to name shorcut)
        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        set "dlcPath="NOT_FOUND""
        set "endTitleId=NOT_FOUND"
        set "dlcVersion=NOT_FOUND"
        set /A "dlcSize=0"

        REM : check if game need to be updated
        set "logDlcGames="!BFW_LOGS:"=!\dlcGames.log""
        del /F !logDlcGames! > NUL 2>&1

        call !checkGameContentAvailability! !GAME_FOLDER_PATH! 0005000c > !logDlcGames!
        set /A "cr=%ERRORLEVEL%"
        if %cr% NEQ 1 goto:eof

        for /F "delims=~? tokens=1-3" %%i in ('type !logDlcGames! 2^>NUL') do (
            set "dlcPath=%%i"
            set "endTitleId=%%j"
            set /A "dlcSize=%%k"
        )
        REM : no new update found, exit function
        if %dlcSize% EQU 0 goto:eof


        REM : get the version of the content (DLC)
        set "metaContentPath="!dlcPath:"=!\meta\meta.xml""
        set "newContentVersion="NONE""
        set "versionLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !metaContentPath! ^| find "<title_version"') do set "versionLine="%%j""
        if [!versionLine!] == ["NONE"] (
            if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: version of DLC not found in !metaContentPath!
            rmdir /Q /S !gamesFolder! > NUL 2>&1
            timeout /t 2 > NUL 2>&1
            exit /b 64
        )
        for /F "delims=<" %%i in (!versionLine!) do set "newContentVersion=%%i"
        if ["!newContentVersion!"] == ["NOT_FOUND"] (
            if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: failed to get verson of DLC in !metaContentPath!
            rmdir /Q /S !gamesFolder! > NUL 2>&1
            timeout /t 2 > NUL 2>&1
            exit /b 65
        )

        REM : str2int
        call:getInteger !newContentVersion! dlcVersion

        echo =========================================================
        echo - Dlc !GAME_TITLE! v%dlcVersion% ^(%dlcSize% MB^)
        echo ---------------------------------------------------------

        for %%a in (!dlcPath!) do set "parentFolder="%%~dpa""
        set "gamesFolder=!parentFolder:~0,-2!""
        set "initialGameFolderName=!gamesFolder:%JNUSTFolder:"=%\=!"

        pushd !JNUSTFolder!
        set "psc="Get-CimInstance -ClassName Win32_Volume ^| Select-Object Name^, FreeSpace^, BlockSize ^| Format-Table -AutoSize""
        for /F "tokens=2-3" %%i in ('powershell !psc! ^| find "!targetDrive!" 2^>NUL') do (
            set "fsbStr=%%i"
            set /A "clusterSizeInB=%%j"
        )

        REM : free space in Kb
        set /A "fskb=!fsbStr:~0,-3!"
        set /A "freeSpaceLeft=fskb/1024"

        REM : compute size need on targetDrive
        call:getSizeOnDisk !dlcSize! sizeNeededOnDiskInMb
        set /A "totalSpaceNeeded=sizeNeededOnDiskInMb"

        echo.
        if !totalSpaceNeeded! LSS !freeSpaceLeft! (
            echo At least !totalSpaceNeeded! Mb are requiered on disk !targetDrive! ^(!freeSpaceLeft! Mb estimate left^)

        ) else (
            echo ERROR ^: not enought space left on !targetDrive!
            echo Needed !totalSpaceNeeded! ^/ still available !freeSpaceLeft! Mb
            echo Ignoring this game
            goto:eof
        )

        if !askUser! EQU 1 (
            choice /C yn /N /M "Download this dlc now (y/n)? : "
            if !ERRORLEVEL! EQU 2 goto:eof
        )
        echo.
        echo If you want to pause the current tranfert or if you get errors during the transfert^,
        echo close this windows then the child cmd console in your task bar
        echo and relaunch this script to complete the download^.
        echo.

        REM : download dlc
        call:downloadDlc

    goto:eof
    REM : ------------------------------------------------------------------


    :downloadDlc

        set /A "totalSizeInMb=%dlcSize%"

        REM : remove 10Mb to totalSizeInMb (threshold)
        set /A "threshold=!totalSizeInMb!"
        if !threshold! GEQ 10 set /A "threshold=!totalSizeInMb!-9"

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "date=%ldt%"
        REM : starting DATE

        echo ---------------------------------------------------------------
        echo Starting at !date!
        echo.

        set /A "progression=0"

        :initDlcDownload

        REM : download the game
        call:download 0005000c %dlcVersion%

        REM : get the JNUSTools folder size
        call:getFolderSizeInMb !initialGameFolderName! sizeDl

        REM : do not continue if not complete (in case of user close downloading windows before this windows)
        set /A "progression=(!sizeDl!*100)/!totalSizeInMb!"

        if !progression! LSS 85 (
            echo ---------------------------------------------------------------
            echo Transfert seems to be incomplete^, relaunching^.^.^.
            echo.
            goto:initDlcDownload
        )

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "date=%ldt%"

        REM : ending DATE
        echo.
        echo Ending at !date!
        echo ===============================================================

        REM : install the dlc
        set "targetDlcPath="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c""
        set "tmpDlcPath=!dlcPath!"

        set /A "attempt=1"
        if not exist !targetDlcPath! (
            mkdir !targetDlcPath! > NUL 2>&1
            goto:tryToMoveNewDlc
        )

        set "tmpDlcPath="!targetDlcPath:"=!_tmp""

        :tryToMoveDlc

        move /Y !dlcPath! !tmpDlcPath! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving !tmpDlcPath:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMoveDlc
            )
            REM : basename of tmpDlcPath to get folder's name
            for /F "delims=~" %%i in (!tmpDlcPath!) do set "folderName=%%~nxi"
            call:fillOwnerShipPatch !tmpDlcPath! "!folderName!" patch

            !MessageBox! "Move still failed^, take the ownership on !tmpDlcPath:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMoveDlc

            REM : else skipping
            echo ERROR^: failed to move !dlcPath! to !tmpDlcPath!^, skipping
            goto:eof
        )
        call:renameFolder !dlcPath! !tmpDlcPath!

        REM : move old dlc
        set "oldDlcPath="!targetDlcPath:"=!_old""

        REM : move dlc folder (targetDlcPath) to oldDlcPath
        set /A "attempt=1"
        :tryToMoveOldDlc

        move /Y !targetDlcPath! !oldDlcPath! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving to !targetDlcPath:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMoveOldDlc
            )
            REM : basename of targetDlcPath
            for /F "delims=~" %%i in (!targetDlcPath!) do set "folderName=%%~nxi"
            call:fillOwnerShipPatch !targetDlcPath! "!folderName!" patch

            !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMoveOldDlc

            REM : else skipping
            echo ERROR^: failed to move !targetDlcPath! to !oldDlcPath!^, skipping and leave !tmpDlcPath!
            goto:eof

        )
        call:renameFolder !targetDlcPath! !oldDlcPath!

        REM : move dlc folder (tmpDlcPath) to targetDlcPath
        set /A "attempt=1"
        :tryToMoveNewDlc

        move /Y !tmpDlcPath! !targetDlcPath! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving to !targetDlcPath:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMoveNewDlc
            )
            REM : basename of targetDlcPath
            for /F "delims=~" %%i in (!targetDlcPath!) do set "folderName=%%~nxi"
            call:fillOwnerShipPatch !targetDlcPath! "!folderName!" patch

            !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMoveNewDlc

            REM : else skipping
            echo ERROR^: failed to move !tmpDlcPath! to !targetDlcPath!^, skipping
            goto:eof
        )
        call:renameFolder !tmpDlcPath! !targetDlcPath!

        if exist !oldDlcPath! rmdir /Q /S !oldDlcPath!
        set /A "NB_DLC_TREATED+=1"
        timeout /T 3 > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------



    :download

        set "startTitleId=%~1"
        set "version=%~2"

        set "label=update"
        if ["!startTitleId!"] ==["0005000c"] set "label=dlc"

        set "utid=!startTitleId!!endTitleId!"

        set "key=NOT_FOUND"
        for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!utid!" 2^>NUL') do set "key=%%b"

        if ["!key!"] == ["NOT_FOUND"] (
            echo ERROR^: why key is not found ^?
            pause
            goto:eof
        )
        wscript /nologo !StartMinimized! !downloadTid! !JNUSTFolder! !utid! 1 !key!
        call:monitorTransfert !threshold! !version!

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


    :fillOwnerShipPatch
        set "folder=%1"
        set "title=%2"

        set "patch="%USERPROFILE:"=%\Desktop\BFW_GetOwnerShip_!title:"=!.bat""
        set "WIIU_GAMES_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
        if not [!WIIU_GAMES_FOLDER!] == ["NONE"] (

            set "patchFolder="!WIIU_GAMES_FOLDER:"=!\OwnerShip Patchs""
            if not exist !patchFolder! mkdir !patchFolder! > NUL 2>&1
            set "patch="!patchFolder:"=!\!title:"=!.bat""
        )
        set "%3=!patch!"

        echo echo off > !patch!
        echo REM ^: RUN THIS SCRIPT AS ADMINISTRATOR >> !patch!

        type !patch! | find /I !folder! > NUL 2>&1 && goto:eof

        echo echo ------------------------------------------------------->> !patch!
        echo echo Get the ownership of !folder! >> !patch!
        echo echo ------------------------------------------------------->> !patch!
        echo takeown /F !folder! /R /SKIPSL >> !patch!
        echo icacls !folder! /grant %%username%%^:F /T /L >> !patch!
        echo pause >> !patch!
        echo del /F %%0 >> !patch!
    goto:eof
    REM : ------------------------------------------------------------------


    :monitorTransfert

        set /A "t=%~1"
        set "version=%~2"

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
                call:getFolderSizeInMb !initialGameFolderName! sizeDl

                REM : progression
                set /A "curentSize=!sizeDl!
                if !curentSize! LSS !t! (

                    if !curentSize! LEQ !totalSizeInMb! set /A "progression=(!curentSize!*100)/!totalSizeInMb!"

                    set /A "mod=nb5sec%%20"
                    if !mod! EQU 0 if !previous! EQU !curentSize! (
                        echo.
                        echo Inactivity detected^! ^, closing current transferts
                        echo.
                        REM : exit, stop transferts, they will be relaunched
                        call:endAllTransferts
                        goto:eof

                    )
                    set /A "previous=!curentSize!"

                ) else (

                    if !curentSize! LEQ !totalSizeInMb! set /A "progression=(!curentSize!*100)/!totalSizeInMb!"
                    title Downloading !label! v!version! of !GAME_TITLE! ^: !progression!%%

                    echo Finalizing^.^.^.
                    set /A "finalize=1"
                    goto:waitingLoop
                )

                title Downloading !label! v!version! of !GAME_TITLE! ^: !progression!%%

                goto:waitingLoop
            ) else (
                if !curentSize! LEQ !totalSizeInMb! set /A "progression=(!curentSize!*100)/!totalSizeInMb!"
                title Downloading !label! v!version! of !GAME_TITLE! ^: !progression!%%

                goto:waitingLoop
            )
        )
        title Downloading !label! v!version! of !GAME_TITLE! ^: 100%%

        REM : get the initialGameFolderName folder size
        call:getFolderSizeInMb !initialGameFolderName! sizeDl

        REM : progression
        set /A "curentSize=!sizeDl!

        echo Downloaded !GAME_TITLE!^'s !label! v!version! successfully
        echo.
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


    REM : ------------------------------------------------------------------
    :getFolderSizeInMb

        set "folder="%~1""
        set /A "sizeofAll=0"

        call:getSizeInMb !folder! sizeofAll

        set "%2=!sizeofAll!"
    goto:eof
    REM : ------------------------------------------------------------------


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

        set /A "intSize=0"
        for /F "delims=~. tokens=1" %%i in ("!strSize!") do set /A "intSize=%%i"

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

