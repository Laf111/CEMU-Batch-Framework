@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main


    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
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
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "myLog="!BFW_PATH:"=!\logs\syncGamesFolder.log""
    set "fnrSearch="!BFW_PATH:"=!\logs\fnr_syncGamesFolder.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : intialize log
    echo ========================================================= > !myLog!

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
    set "DATE=%ldt%"

    if %nbArgs% NEQ 0 goto:getArgsValue
    title Sync BatchFw saves and transferable cache with another games^' folder

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"
    echo Please select the target games^' folder ^(where BatchFw is installed^)

    :askGamesFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a games^' folder where BatchFw is installed"') do set "folder=%%b" && set "TARGET_GAMES_FOLDER=!folder:?= !"
    if [!TARGET_GAMES_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askGamesFolder
    )

    REM : check if folder name contains forbiden character for !TARGET_GAMES_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !TARGET_GAMES_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !TARGET_GAMES_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askGamesFolder
    )

    REM : check if a _BatchFw_Install exist
    set bfwFolder="!TARGET_GAMES_FOLDER:"=!\_BatchFw_Install"
    if not exist !bfwFolder! (
        echo BatchFw not installed in !TARGET_GAMES_FOLDER! ^?
        goto:askGamesFolder
    )

    cls
    goto:inputsAvailables

    :getArgsValue
    if %nbArgs% NEQ 1 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" TARGET_GAMES_FOLDER
        echo ^(^* for optional^ argument^)
        echo given {%*}
        pause
        exit /b 99
    )
    REM : get and check TARGET_GAMES_FOLDER
    set "TARGET_GAMES_FOLDER=!args[0]!"
    if not exist !TARGET_GAMES_FOLDER! (
        echo ERROR ^: mlc01 folder !TARGET_GAMES_FOLDER! does not exist ^!
        pause
        exit /b 1
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    pushd !GAMES_FOLDER!

    title Sync with another BatchFw^'s installation
    echo =========================================================

    echo Sync saves^, transferable cache and games stats between >> !myLog!
    echo Sync saves^, transferable cache and games stats between
    echo  - ^: !GAMES_FOLDER! >> !myLog!
    echo  - ^: !GAMES_FOLDER!
    echo AND
    echo  - ^: !TARGET_GAMES_FOLDER! >> !myLog!
    echo  - ^: !TARGET_GAMES_FOLDER!
    echo.
    echo ========================================================= >> !myLog!
    echo =========================================================
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder

    echo Launching in 30s
    echo     ^(y^) ^: launch now
    echo     ^(n^) ^: cancel
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice ? : " "y,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Cancelling
        choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
        goto:eof
    )

    :scanGamesFolder
    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder_sgf.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        echo =========================================================
        echo ERROR ^: Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        echo List of game^'s folder^(s^) ^:
        echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        echo ---------------------------------------------------------
        echo Fix-it by removing characters here replaced in the folder^'s name by ^?
        echo Exiting until you rename or move those folders
        echo =========================================================
        if !QUIET_MODE! EQU 0 pause
    )

    call:searchGamesToSync

    echo #########################################################
    if !QUIET_MODE! EQU 1 goto:exiting
    echo ---------------------------------------------------------
    echo This windows will close automatically in 12s
    echo     ^(n^) ^: don^'t close^, i want to read history log first
    echo     ^(q^) ^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )
    :exiting

    set "pat="!BFW_PATH:"=!\logs\fnr*.log""
    del /F !pat! > NUL 2>&1

    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

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

    REM : get a node value in a xml file
    REM : !WARNING! current directory must be !BFW_RESOURCES_PATH!
    :getValueInXml

        set "xPath="%~1""
        set "xmlFile="%~2""
        set "%3=NOT_FOUND"

        REM : return the first match
        for /F "delims=~" %%x in ('xml.exe sel -t -c !xPath! !xmlFile! 2^>NUL') do (
            set "%3=%%x"

            goto:eof
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :getTimeStamp

        set "file="%~1""
        set "title=%~2"

        set "%3=NOT_FOUND"

        pushd !BFW_RESOURCES_PATH!

        REM : get the rpxFilePath used in source file
        set "rpxFilePath="NOT_FOUND""
        for /F "delims=~<> tokens=3" %%p in ('type !file! ^| find "<path>" ^| find "!title!" 2^>NUL') do set "rpxFilePath="%%p""
        if [!rpxFilePath!] == ["NOT_FOUND"] set "%3=NOT_FOUND" & goto:eof

        REM : get timestamp with RPX path
        call:getValueInXml "//GameCache/Entry[path='!rpxFilePath:"=!']/last_played/text()" !file! ts

        REM : get timestamp value in source
        set "%3=!ts!"

    goto:eof
    REM : ------------------------------------------------------------------

    :getTimePlayed

        set "file="%~1""
        set "title=%~2"

        set "%3=NOT_FOUND"

        pushd !BFW_RESOURCES_PATH!

        REM : get the rpxFilePath used in source file
        set "rpxFilePath="NOT_FOUND""
        for /F "delims=~<> tokens=3" %%p in ('type !file! ^| find "<path>" ^| find "!title!" 2^>NUL') do set "rpxFilePath="%%p""
        if [!rpxFilePath!] == ["NOT_FOUND"] set "%3=NOT_FOUND" & goto:eof

        REM : get timestamp with RPX path
        call:getValueInXml "//GameCache/Entry[path='!rpxFilePath:"=!']/time_played/text()" !file! tp

        REM : get time played value in source
        set "%3=!tp!"

    goto:eof
    REM : ------------------------------------------------------------------

    :syncGamesStats

        set "currentUser=%~1"

        REM : source file
        set "ssf="!GAME_FOLDER_PATH:"=!\Cemu\settings""
        if not exist !ssf! goto:eof
        set "slls="!ssf:"=!\!currentUser!_lastSettings.txt""
        if not exist !slls! goto:eof

        pushd !ssf!
        for /F "delims=~" %%i in ('type !slls! 2^>NUL') do set "sls=%%i"
        if not exist !sls! goto:eof
        REM : user source last settings file
        set "slst="!ssf:"=!\!sls:"=!""
        if not exist !slst! goto:eof


        REM : RPX_FILE_PATH check
        type !slst! | find /I "!RPX_FILE_PATH:~4,-1!" > NUL 2>&1 && (

            REM : target file
            set "tsf="!TARGET_GAME_FOLDER_PATH:"=!\Cemu\settings""
            if not exist !tsf! goto:eof
            set "tlls="!tsf:"=!\!currentUser!_lastSettings.txt""
            if not exist !tlls! goto:eof

            pushd !tsf!
            for /F "delims=~" %%i in ('type !tlls! 2^>NUL') do set "tls=%%i"
            if not exist !tls! goto:eof

            REM : user source last settings file
            set "tlst="!tsf:"=!\!tls:"=!""
            if not exist !tlst! goto:eof

            REM : get source timestamp
            call:getTimeStamp !slst! "!GAME_TITLE!" sts
            if ["!sts!"] == ["NOT_FOUND"] goto:eof

            REM : get target timestamp
            call:getTimeStamp !tlst! "!TARGET_GAME_TITLE!" tts
            if ["!tts!"] == ["NOT_FOUND"] goto:eof

            REM : get source time played
            call:getTimePlayed !slst! "!GAME_TITLE!" stp
            if ["!stp!"] == ["NOT_FOUND"] goto:eof

            REM : get target time played
            call:getTimePlayed !tlst! "!TARGET_GAME_TITLE!" ttp
            if ["!ttp!"] == ["NOT_FOUND"] goto:eof


            REM : initialize local variables
            set "srcTsValue=!sts!"
            set "tgtTsValue=!tts!"
            set "srcTpValue=!stp!"
            set "tgtTpValue=!ttp!"

            for %%a in (!tlst!) do set "parentFolder="%%~dpa""
            set "folder=!parentFolder:~0,-2!""

            set "source=!sls!"
            set "target=!tls!"
            set "prefix=> Exporting"

            REM : divide by 10 to avoid int32 limits (2147483647 => 19/01/2038 03:14:07)	
            set /A "ttsdt=sts/10"
            set /A "stsdt=tts/10"
            REM : compare stsdt and ttsdt
            if !ttsdt! LSS !stsdt! (
                REM : switch source and target
                set "source=!target!"
                set "target=!sls!"
                set "srcTsValue=!tgtTsValue!"
                set "tgtTsValue=!sts!"
                set "srcTpValue=!tgtTpValue!"
                set "tgtTpValue=!stp!"

                for %%a in (!slst!) do set "parentFolder="%%~dpa""
                set "folder=!parentFolder:~0,-2!""
                
                set "prefix=< Importing"
            )

            echo Source !currentUser! game stats of !GAME_TITLE! ^: >> !myLog!
            echo - time played = !srcTpValue! >> !myLog!
            echo - last played = !srcTsValue! >> !myLog!
            echo - origin      = !source! >> !myLog!
            echo.  >> !myLog!
            echo Target !currentUser! game stats of !GAME_TITLE! ^: >> !myLog!
            echo - time played = !tgtTpValue! >> !myLog!
            echo - last played = !tgtTsValue! >> !myLog!
            echo - origin      = !target! >> !myLog!
            echo.  >> !myLog!
            echo Target folder location = !folder! >> !myLog!
            echo.  >> !myLog!

            REM : use fnr.exe to update
            set "BfwSyncGsLog="!BFW_PATH:"=!\logs\fnr_BfwSyncGsLog.log""

            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !folder! --fileMask "!currentUser!_settings.xml" --find "last_played>!tgtTsValue!" --replace "last_played>!srcTsValue!" --logFile !BfwSyncGsLog!
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !folder! --fileMask "!currentUser!_settings.xml" --find "time_played>!tgtTpValue!" --replace "time_played>!srcTpValue!" --logFile !BfwSyncGsLog!

            echo !prefix! !title! !currentUser!^'s playtime stats >> !myLog!
            echo !prefix! !title! !currentUser!^'s playtime stats
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :searchGamesToSync

        REM : log to games library log file
        set "msg="Sync:!DATE!@!USERDOMAIN! !GAMES_FOLDER:"=!=!TARGET_GAMES_FOLDER:"=!""
        call:log2GamesLibraryFile !msg!

        cls
        REM : loop on game's code folders found
        for /F "delims=~" %%g in ('dir /b /o:n /a:d /s code 2^>NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

            set "codeFullPath="%%g""
            set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

            REM : check path
            call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"

            if !cr! EQU 0 (
                REM : check if folder name contains forbiden character for batch file
                set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
                call !tobeLaunch! !GAME_FOLDER_PATH!
                set /A "cr=!ERRORLEVEL!"

                if !cr! GTR 1 echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
                if !cr! EQU 1 goto:eof
                call:syncGame

            ) else (

                echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
                echo !folderName! ^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
                for %%a in (!GAME_FOLDER_PATH!) do set "basename=%%~dpa"

                REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!% are also a problem with dos expansion
                set "str="!folderName!""
                set "str=!str:&=!"
                set "str=!str:\!=!"
                set "str=!str:%%=!"
                set "str=!str:.=!"
                set "str=!str:?=!"
                set "str=!str:\"=!"
                set "str=!str:^=!"
                set "newFolderName=!str:"=!"
                set "newName="!basename!!newFolderName:"=!""

                set /A "attempt=1"
                :tryToMove
                call:getUserInput "Renaming folder for you? (y, n) : " "y,n" ANSWER

                if [!ANSWER!] == ["y"] (
                    move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
                    if !ERRORLEVEL! NEQ 0 (

                        if !attempt! EQU 1 (
                            !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=!^, close any program that could use this location" 4112
                            set /A "attempt+=1"
                            goto:tryToMove
                        )
                        REM : basename of GAME FOLDER PATH to get GAME_TITLE
                        for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxg"
                        call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                        !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                        if !ERRORLEVEL! EQU 6 goto:tryToMove
                    )
                )

                if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:eof
                if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^' ^?^), please do it by yourself otherwise game will be ignored ^!
                echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :syncGame

        REM : avoiding a mlc01 folder under !GAME_FOLDER_PATH!
        if /I [!GAME_FOLDER_PATH!] == ["!GAMES_FOLDER:"=!\mlc01"] goto:eof

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
        set "RPX_FILE_PATH="!codeFolder:"=!\!RPX_FILE:"=!""


        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=~" %%j in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxj"

        REM : path to meta.xml file
        set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
        if not exist !META_FILE! (

            echo "ERROR^: no meta^.xml found in !GAME_FOLDER_PATH!^, skip this game >> !myLog!
            echo "ERROR^: no meta^.xml found in !GAME_FOLDER_PATH!^, skip this game
            goto:eof
        )
        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%k""
        if [!titleLine!] == ["NONE"] (
            echo "ERROR^: no titleId found in meta^.xml from !GAME_FOLDER_PATH!^, skip this game >> !myLog!
            echo "ERROR^: no titleId found in meta^.xml from !GAME_FOLDER_PATH!^, skip this game
            goto:eof
        )

        for /F "delims=<" %%j in (!titleLine!) do set "titleId=%%j"

        REM : check if the game exist in !TARGET_GAMES_FOLDER! (not dependant of the game folder's name)
        if exist !fnrSearch! del /F !fnrSearch! > NUL 2>&1
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !TARGET_GAMES_FOLDER! --fileMask "meta.xml" --ExcludeDir "content, code, mlc01, Cemu" --includeSubDirectories --find !titleId!  --logFile !fnrSearch!

        for /F "tokens=2-3 delims=." %%j in ('type !fnrSearch! ^| find /I /V "^!" ^| find "File:"') do (

            set "metaFile="!TARGET_GAMES_FOLDER:"=!%%j.%%k""
            call:syncGameForUsers !metaFile!
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :syncSaveForUser

        set "currentUser=%~1"

        set "sourceRarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!.rar""

        REM : if sourceRarFile not exists, skip this game
        if not exist !sourceRarFile! goto:eof

        call:getUserInput "Sync saves for !currentUser!? : (n, y = default in 15sec)" "y,n" ANSWER 10
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip user !currentUser!
            goto:eof
        )

        REM : targetRarFile
        set "targetRarFile="!TARGET_GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!TARGET_GAME_TITLE!_!currentUser!.rar""

        REM : if target file does not exist, copy
        if not exist !targetRarFile! echo ^> Copying new saves of !currentUser! for !TARGET_GAME_TITLE! >> !myLog! & echo ^> Copying new saves of !currentUser! for !TARGET_GAME_TITLE! & copy /Y !sourceRarFile! !targetRarFile! > NUL 2>&1 & goto:eof

        for %%a in (!sourceRarFile!) do set dateRead=%%~ta
        set /A "srcDate=%dateRead:~8,2%%dateRead:~3,2%%dateRead:~0,2%%dateRead:~11,2%%dateRead:~14,2%"

        for %%a in (!targetRarFile!) do set dateRead=%%~ta
        set /A "tgtDate=%dateRead:~8,2%%dateRead:~3,2%%dateRead:~0,2%%dateRead:~11,2%%dateRead:~14,2%"

        REM : if files have the sames dates, exit
        if !srcDate! EQU !tgtDate! (
            echo ^= !currentUser! saves files dates are identicals >> !myLog!
            echo ^= !currentUser! saves files dates are identicals
            goto:eof
        )

        if !srcDate! GTR !tgtDate! (

            REM : backupRarFile in target folder
            set "backupRarFile="!TARGET_GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\SyncBackup_!DATE!_!TARGET_GAME_TITLE!_!currentUser!.rar""
            copy /Y !targetRarFile! !backupRarFile! > NUL 2>&1

            echo ^> Backup !currentUser! old save to !backupRarFile! >> !myLog!
            echo ^> Backup !currentUser! old save to !backupRarFile!
            echo ^> Exporting newest saves of !currentUser! for !TARGET_GAME_TITLE! >> !myLog!
            echo ^> Exporting newest saves of !currentUser! for !TARGET_GAME_TITLE!

            copy /Y !sourceRarFile! !targetRarFile! > NUL 2>&1

        ) else (
            REM : identical date handle above

            REM : backupRarFile in source folder
            set "backupRarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\SyncBackup_!DATE!_!GAME_TITLE!_!currentUser!.rar""
            copy /Y !sourceRarFile! !backupRarFile! > NUL 2>&1

            echo ^< Backup !currentUser! old save to !backupRarFile! >> !myLog!
            echo ^< Backup !currentUser! old save to !backupRarFile!
            echo ^< Importing newest saves of !currentUser! for !GAME_TITLE! >> !myLog!
            echo ^< Importing newest saves of !currentUser! for !GAME_TITLE!

            copy /Y !targetRarFile! !sourceRarFile! > NUL 2>&1
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :syncTsc

        REM : loop on bin file found under !GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\*.bin""
        dir /B /S !pat! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo ^? No transferable shader cache found >> !myLog!
            echo ^? No transferable shader cache found
            goto:eof
        )

        for /F "delims=~" %%l in ('dir /B /S !pat! 2^>NUL') do (
            set "sourceTscFile="%%l""

            for /F "delims=~" %%m in (!sourceTscFile!) do set "fileName=%%~nxm"

            set "targetTscFile="!TARGET_GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!fileName!""
            if not exist !targetTscFile! (

                echo ^> Copying new !fileName! for !TARGET_GAME_TITLE! >> !myLog!
                echo ^> Copying new !fileName! for !TARGET_GAME_TITLE!
                copy /Y !sourceTscFile! !targetTscFile! > NUL 2>&1

            ) else (
                REM : the 2 files exists
                set /A "srcSize=0"
                for /F "tokens=*" %%s in (!sourceTscFile!)  do set "srcSize=%%~zs"
                set /A "tgtSize=0"
                for /F "tokens=*" %%s in (!targetTscFile!)  do set "tgtSize=%%~zs"

                set "sourceFolder="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
                set "targetFolder="!TARGET_GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""

                REM : compare their size : copy only if greater
                if !srcSize! GTR !tgtSize! robocopy !sourceFolder! !targetFolder! !fileName! /MT:32 /IS /IT > NUL 2>&1 & echo ^> Exporting !fileName! for !TARGET_GAME_TITLE! >> !myLog! & echo ^> Exporting !fileName! for !TARGET_GAME_TITLE!
                if !srcSize! LSS !tgtSize! robocopy !targetFolder! !sourceFolder! !fileName! /MT:32 /IS /IT > NUL 2>&1 & echo ^< Importing !fileName! for!GAME_TITLE! >> !myLog! & echo ^< Importing !fileName! for !GAME_TITLE!

                if !srcSize! EQU !tgtSize! echo ^= !fileName! size are identicals >> !myLog! & echo ^= !fileName! size are identicals
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------    

    :syncGameForUsers

        REM : here the game exist in the 2 games'folders
        set "mfn="%~1""

        for %%a in (!mfn!) do set "parentFolder="%%~dpa""
        set "metaF=!parentFolder:~0,-2!""
        set "TARGET_GAME_FOLDER_PATH=!metaF:\meta=!"

        REM : basename of TARGET_GAME_FOLDER_PATH (to get TARGET_GAME_TITLE)
        for /F "delims=~" %%l in (!TARGET_GAME_FOLDER_PATH!) do set "TARGET_GAME_TITLE=%%~nxl"

        echo ========================================================= >> !myLog!
        echo =========================================================

        if !QUIET_MODE! EQU 1 goto:loopOnUsers
        echo - Sync !TARGET_GAME_TITLE! ^?
        echo   ^(n^) ^: no^, skip
        echo   ^(y^) ^: yes ^(default value after 15s timeout^)
        echo.
        echo --------------------------------------------------------- >> !myLog!
        echo ---------------------------------------------------------

        call:getUserInput "Enter your choice? : " "y,n" ANSWER 15
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip this GAME
            goto:eof
        )
        echo --------------------------------------------------------- >> !myLog!
        echo ---------------------------------------------------------

        :loopOnUsers

        REM : For all users : sync saves
        for /F "tokens=2 delims=~=" %%a in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%a""
            call:syncSaveForUser !user!
        )

        REM : sync transferable shader cache
        call:syncTsc


        REM : For all users : sync saves
        for /F "tokens=2 delims=~=" %%a in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%a""
            call:syncGamesStats !user!
        )
        timeout /T 3 > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
        if not exist !glogFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !glogFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.bfw_tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL 2>&1
        move /Y !gLogFileTmp! !glogFile! > NUL 2>&1

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

    REM : function to get user input in allowed valuesList (beginning with default timeout value) from question and return the choice
    :getUserInput

        REM : arg1 = question
        set "question="%~1""
        REM : arg2 = valuesList
        set "valuesList=%~2"
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional : if given set 1st value as default value after timeOutValue seconds)
        set "timeOutValue=%~4"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if ["%timeOutValue%"] == [""] (
            set choiceCmd=choice /C %choiceValues% /CS /N /M !question!
        ) else (
            set choiceCmd=choice /C %choiceValues% /CS /N /T %timeOutValue% /D %defaultTimeOutValue% /M !question!
        )

        REM : launching and get return code
        !choiceCmd!
        set /A "cr=!ERRORLEVEL!"

        set j=1
        for %%i in ("%valuesList:,=" "%") do (

            if [%cr%] == [!j!] (
                REM : value found , return function value

                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
        )

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
