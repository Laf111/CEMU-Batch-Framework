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

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    REM : BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

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
        exit /b 100
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!
    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : checking arguments
    set /A "nbArgs=0"
   :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
   :end

    REM : flag to move DATA instead of copy them (default = move)
    set /A "moveFlag=1"

    if %nbArgs% EQU 0 (

        echo =========================================================
        echo Import new games in your library and prepare them for
        echo emulation with CEMU using BatchFw^.
        echo.
        echo If folders ^(DLC^) and ^(UPDATE^) are found^, batchFw will
        echo install them in each game^'s folder^.
        echo.
        echo If DLC or UPDATE folders are found without the game in the
        echo folder^, they will be skipped^.
        echo In this case BatchFw has already built the mlc01 folder
        echo structure^, just move their content to the right place^:
        echo.
        echo - update in mlc01^/usr^/title^/0005000e/titleId[8^:15]
        echo - dlc    in mlc01^/usr^/title^/0005000c/titleId[8^:15]
        echo.
        echo =========================================================

        echo Launching in 40s
        echo     ^(y^) ^: launch now
        echo     ^(n^) ^: cancel
        echo ---------------------------------------------------------
        call:getUserInput "Enter your choice ? : " "y,n" ANSWER 40
        if [!ANSWER!] == ["n"] (
            REM : Cancelling
            choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
            goto:eof
        )

        goto:begin
    )

    if %nbArgs% NEQ 1 (
        echo ERROR on arguments passed^(%nbArgs%^)
        echo SYNTAXE^: "!THIS_SCRIPT!" INPUT_FOLDER
        echo given {%*}
        pause
        exit /b 9
    )

    REM : get and check INPUT_FOLDER
    set "INPUT_FOLDER=!args[0]!"
    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    goto:inputsAvailable

    :begin
    cls
    :askInputFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a source folder"') do set "folder=%%b" && set "INPUT_FOLDER=!folder:?= !"
    if [!INPUT_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askInputFolder
    )

    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !INPUT_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !INPUT_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askInputFolder
    )
    title Move Games with updates and DLC from !INPUT_FOLDER:"=! and prepare them to emulation
    echo.
    choice /C yn /N /M "Do you want to copy instead of moving files (y, n)? : "
    if !ERRORLEVEL! EQU 1 (
        title Copy Games with updates and DLC from !INPUT_FOLDER:"=! and prepare them to emulation
        set /A "moveFlag=0"
    )
    :inputsAvailable
    set "INPUT_FOLDER=!INPUT_FOLDER:\\=\!"

    if !QUIET_MODE! EQU 0 (


        REM : compute size needed only if source and target partitions are differents
        for %%a in (!INPUT_FOLDER!) do set "driveInput=%%~da"
        if ["!driveInput!"] == ["!drive!"] goto:beginTreatment

        echo.
        echo Computing the size needed^.^.^.
        echo.
        REM : compute the size needed
        call:getFolderSizeInMb !INPUT_FOLDER! sizeNeeded

        choice /C yn /N /M "A maximum of !sizeNeeded! Mb are needed ^(size of !INPUT_FOLDER:"=!^) on the target partition^, continue ^(y^, n^)^? ^: "
        if !ERRORLEVEL! EQU 2 (
            REM : Cancelling
            echo Cancelled by user^, exiting in 2s
            exit /b 49
        )
    )
    :beginTreatment
    pushd !INPUT_FOLDER!

    REM : rename folders that contains forbiden characters : & ! .
    if %nbArgs% EQU 0 wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!INPUT_FOLDER! /REPLACECI^:^^!^: /REPLACECI^:^^^&^: /REPLACECI^:^^.^:  /EXECUTE

    :scanGamesFolder
    cls
    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder_ig.log""
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
        pause
        goto:eof
    )

    REM : check if an internet connection is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    
    set /A "NB_GAMES_TREATED=0"
    set /A "gfxPackFoundForAllGames=1"

    REM using the sort /V, first come the game, then update and DLC (if availables)

    REM initialize a endTitleId variable here so it will be visible in all functions (installDlc, installUpdate)
    set "endTitleId=NONE"

    REM : loop on game's code folders found
    for /F "delims=~" %%g in ('dir /b /o:n /a:d /s code 2^>NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install" ^| sort /R') do (

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

            if !cr! GTR 1 echo Please rename !GAME_FOLDER_PATH! to be DOS compatible ^,otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder

            REM : basename of GAME FOLDER PATH (to get GAME_FOLDER_NAME)
            for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_FOLDER_NAME=%%~nxg"

            call:treatGameFolders
            
        ) else (
            pushd !GAMES_FOLDER!

            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            echo !folderName! ^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
            for %%a in (!GAME_FOLDER_PATH!) do set "basename=%%~dpa"

            REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!% are also a problem with dos expansion
            set "str="!folderName!""
            set "str=!str:&=!"
            set "str=!str:\!=!"
            set "str=!str:%%=!"
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
                    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                    call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                    !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:tryToMove
                )
            )
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^' ^?^), please do it by yourself otherwise game will be ignored ^!
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] goto:launchSetup

    if !gfxPackFoundForAllGames! EQU 0 (
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo No GFX pack were found for at least one game^.
        echo.
        choice /C yn /N /M "Do you want to update GFX packs folder ? (y,n):"
        if !ERRORLEVEL! EQU 1 (
            set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
            call !ugp!
        )

    )

    :launchSetup

    echo.
    if !NB_GAMES_TREATED! NEQ 0 if %nbArgs% EQU 0 (
        echo =========================================================
        echo New Games were added to your library^, launching setup^.bat^.^.^.
        set "setup="!BFW_PATH:"=!\setup.bat""
        timeout /T 8 > NUL 2>&1

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
        exit /b 15
    )

    if %nbArgs% EQU 1 goto:exiting

    echo =========================================================
    echo Treated !NB_GAMES_TREATED! games
    echo #########################################################


    echo This windows will close automatically in 15s
    echo     ^(n^) ^: don^'t close^, i want to read history log first
    echo     ^(q^) ^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    :exiting
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

    :treatGameFolders

        echo !GAME_FOLDER_PATH! | find "(UPDATE DATA)" > NUL 2>&1 && (
            call:installUpdate
            goto:eof
        )
        echo !GAME_FOLDER_PATH! | find "(DLC)" > NUL 2>&1 && (
            call:installDlc
            goto:eof
        )

        set "GAME_TITLE=!GAME_FOLDER_NAME!"
        REM : if USB Helper output : NAME[Id], get only the name
        echo "!GAME_FOLDER_PATH!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    if [!INPUT_FOLDER!] == [!GAMES_FOLDER!] (        
        set "pat="!GAME_TITLE:"=!*(*)*""
        dir /B !pat! > NUL 2>&1 && call:prepareGame
    ) else (
        call:prepareGame
    )
    goto:eof
    REM : ------------------------------------------------------------------

    :getSmb
        set "sr=%~1"
        set /A "d=%~2"

        set /A "%3=!sr:~0,%d%!+1"
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

    :getFolderSizeInMb

        set "folder="%~1""
        REM : prevent path to be stripped if contain '
        set "folder=!folder:'=`'!"
        set "folder=!folder:[=`[!"
        set "folder=!folder:]=`]!"
        set "folder=!folder:)=`)!"
        set "folder=!folder:(=`(!"

        set "psCommand=-noprofile -command "ls -r -force '!folder:"=!' | measure -s Length""

        set "line=NONE"
        for /F "usebackq tokens=2 delims=:" %%a in (`powershell !psCommand! ^| find /I "Sum"`) do set "line=%%a"
        REM : powershell call always return %ERRORLEVEL%=0

        if ["!line!"] == ["NONE"] (
            set "%2=0"
            goto:eof
        )

        set "sizeRead=%line: =%"

        if ["!sizeRead!"] == [" ="] (
            set "%2=0"
            goto:eof
        )

        set /A "im=0"
        if not ["!sizeRead!"] == ["0"] (

            REM : compute length before switching to 32bits integers
            call:strLength !sizeRead! len
            REM : forcing Mb unit
            if !len! GTR 6 (
                set /A "dif=!len!-6"
                call:getSmb %sizeRead% !dif! smb
                set "%2=!smb!"
                goto:eof
            ) else (
                set "%2=1"
                goto:eof
            )
        )
        set "%2=0.0"

    goto:eof
    REM : ------------------------------------------------------------------

    :checkGfxPacksAvailability
        set "fnrLogIg="!BFW_PATH:"=!\logs\fnr_import!GAME_TITLE!.log""
        if exist !fnrLogIg! del /F !fnrLogIg! > NUL 2>&1


        REM : launching the search in all gfx pack folder (V2 and up)
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogIg!

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogIg! ^| find /I /V "^!" ^| find "File:" 2^>NUL') do del /F !fnrLogIg! > NUL 2>&1 & goto:eof

        set /A "gfxPackFoundForAllGames=0"
        del /F !fnrLogIg! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    :prepareGame

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

        set "GAME_TITLE=!GAME_FOLDER_NAME!"
        REM : if USB Helper output : NAME[Id], get only the name
        echo "!GAME_FOLDER_PATH!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        set "target="!GAMES_FOLDER:"=!\!GAME_TITLE!""

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            echo No meta folder not found under game folder !GAME_TITLE! ^?^, skipping ^!
            echo ---------------------------------------------------------
            goto:eof
        )

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:eof
        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"
        set "endTitleId=%titleId:~8,8%"

        if exist !target! (
            echo =========================================================
            echo - !GAME_TITLE!
            echo ---------------------------------------------------------
            echo.
            echo Game already installed in !target!^, skipping^.^.^.
            goto:eof
        )

        echo =========================================================
        echo - !GAME_TITLE!
        echo ---------------------------------------------------------
        echo.        

        REM : moving game's folder
        set "source="!INPUT_FOLDER:"=!\!GAME_TITLE!""

        set /A "attemptSrc=1"
        set /A "attemptTgt=1"
        :treatGame
        if !moveFlag! EQU 1 (
            echo Moving game^'s files^.^.^.

            if not exist !source! (
                move /Y !GAME_FOLDER_PATH! !source! > NUL 2>&1
                if !ERRORLEVEL! NEQ 0 (

                    if !attemptSrc! EQU 1 (
                        !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for moving game to !source:"=!^, close any program that could use this location" 4112
                        set /A "attemptSrc+=1"
                        goto:treatGame
                    )

                    REM : basename of GAME FOLDER PATH to get GAME_TITLE
                    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                    call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                    !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:treatGame

                    !MessageBox! "ERROR While moving !GAME_TITLE!^'s files ^!" 4112
                    goto:eof
                )
            )
            call:moveFolder !source! !target! cr
            if !cr! NEQ 0 (
                if !attemptTgt! EQU 1 (
                    !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for moving game to !target:"=!^, close any program that could use this location" 4112
                    set /A "attemptTgt+=1"
                    goto:treatGame
                )
            
                REM : basename of GAME FOLDER PATH to get GAME_TITLE
                for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:treatGame

                !MessageBox! "ERROR While moving !GAME_TITLE!^'s files ^!" 4112
                goto:eof
            )
        ) else (
            echo Copying game^'s files^.^.^.

            robocopy !source! !target! /MT:32 /S > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"
            if !cr! GTR 7 (
                if !attemptTgt! EQU 1 (
                    !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for copying game to !target:"=!^, close any program that could use this location" 4112
                    set /A "attemptSrc+=1"
                    goto:treatGame
                )

                REM : basename of GAME FOLDER PATH to get GAME_TITLE
                for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:treatGame

                !MessageBox! "ERROR While copying !GAME_TITLE!^'s files ^!" 4112
                goto:eof
            )
        )
        REM : creating mlc01 folder structure
        set "sysFolder="!target:"=!\mlc01\sys\title\0005001b\10056000\content""

        if not exist !sysFolder! (
            echo Creating system save^'s folder
            mkdir !sysFolder! > NUL 2>&1
        )
        set "saveFolder="!target:"=!\mlc01\usr\save\00050000\%endTitleId%""

        if not exist !saveFolder! (
            echo Creating saves folder
            mkdir !saveFolder! > NUL 2>&1
        )
        REM : check if a GFX pack exist (V2 or up)
        if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] if exist !BFW_GP_FOLDER! call:checkGfxPacksAvailability

        set /A "NB_GAMES_TREATED+=1"

    goto:eof
    REM : ------------------------------------------------------------------

    :installUpdate

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            echo No meta folder not found under update folder !GAME_FOLDER_NAME! ^?^, skipping ^!
            echo ---------------------------------------------------------
            pause
            goto:eof
        )

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:eof
        for /F "delims=<" %%i in (!titleLine!) do set "titleIdU=%%i"

        set "endTitleIdU=%titleIdU:~8,8%"

        if not ["!endTitleIdU!"] == ["!endTitleId!"] (
            echo endTitleIdU=!endTitleIdU!
            echo endTitleId=!endTitleId!

            echo !GAME_FOLDER_PATH! is not related to a game
            echo that exists in !INPUT_FOLDER!^, skipping ^!
            echo ---------------------------------------------------------
            pause
            goto:eof
        )

        REM : moving to game's folder
        set "target="!GAMES_FOLDER:"=!\!GAME_TITLE!\mlc01\usr\title\0005000e\%endTitleId%""

        if not exist !target! (
            mkdir !target! > NUL 2>&1
        )
        echo Installing update^.^.^.

        set /A "attemptSrc=1"
        set /A "attemptTgt=1"
        :treatUpdate
        if !moveFlag! EQU 1 (
            set "source="!INPUT_FOLDER:"=!\%endTitleId%""

            if not exist !source! (
                move /Y !GAME_FOLDER_PATH! !source! > NUL 2>&1
                if !ERRORLEVEL! NEQ 0 (

                    if !attemptSrc! EQU 1 (
                        !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for moving update to !source:"=!^, close any program that could use this location" 4112
                        set /A "attemptSrc+=1"
                        goto:treatUpdate
                    )

                    REM : basename of GAME FOLDER PATH to get GAME_TITLE
                    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                    call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                    !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:treatUpdate

                    !MessageBox! "ERROR While moving !GAME_TITLE!^'s update files ^!" 4112
                    goto:eof
                )
            )
            call:moveFolder !source! !target! cr
            if !cr! NEQ 0 (

                if !attemptTgt! EQU 1 (
                    !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for moving update to !target:"=!^, close any program that could use this location" 4112
                    set /A "attemptTgt+=1"
                    goto:treatUpdate
                )

                REM : basename of GAME FOLDER PATH to get GAME_TITLE
                for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:treatUpdate

                !MessageBox! "ERROR While moving !GAME_TITLE!^'s update files ^!" 4112
                goto:eof
            )
        ) else (
            robocopy !GAME_FOLDER_PATH! !target! /MT:32 /S > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"
            if !cr! GTR 7 (

                if !attemptTgt! EQU 1 (
                    !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for copying to !target:"=!^, close any program that could use this location" 4112
                    set /A "attemptTgt+=1"
                    goto:treatUpdate
                )

                REM : basename of GAME FOLDER PATH to get GAME_TITLE
                for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:treatUpdate

                !MessageBox! "ERROR While copying !GAME_TITLE!^'s update files ^!" 4112
                goto:eof
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :installDlc

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            echo No meta folder not found under DLC folder !GAME_FOLDER_NAME! ^?^, skipping ^!
            echo ---------------------------------------------------------
            goto:eof
        )

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:eof
        for /F "delims=<" %%i in (!titleLine!) do set "titleIdDlc=%%i"

        set "endTitleIdDlc=!titleIdDlc:~8,8!"

        if not ["!endTitleIdDlc!"] == ["!endTitleId!"] (
            echo this DLC is not related to a game that exists in !INPUT_FOLDER!^, skipping ^!
            echo ---------------------------------------------------------
            goto:eof
        )

        REM : moving to game's folder
        set "target="!GAMES_FOLDER:"=!\!GAME_TITLE!\mlc01\usr\title\0005000c\%endTitleId%""
        if not exist !target! (
            mkdir !target! > NUL 2>&1
        )

        echo Installing DLC^.^.^.
        set /A "attemptSrc=1"
        set /A "attemptTgt=1"

        :treatDlc
        if !moveFlag! EQU 1 (
            set "source="!INPUT_FOLDER:"=!\%endTitleId%_aoc""
            if not exist !source! (
                move /Y !GAME_FOLDER_PATH! !source! > NUL 2>&1
                if !ERRORLEVEL! NEQ 0 (

                    if !attemptSrc! EQU 1 (
                        !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for moving Dlc to !source:"=!^, close any program that could use this location" 4112
                        set /A "attemptSrc+=1"
                        goto:treatDlc
                    )

                    REM : basename of GAME FOLDER PATH to get GAME_TITLE
                    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                    call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                    !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:treatDlc

                    !MessageBox! "ERROR While moving !GAME_TITLE!^'s DLC files ^!" 4112
                    goto:eof
                )
            )
            call:moveFolder !source! !target! cr
            if !cr! NEQ 0 (

                if !attemptTgt! EQU 1 (
                    !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for moving Dlc to !target:"=!^, close any program that could use this location" 4112
                    set /A "attemptTgt+=1"
                    goto:treatDlc
                )

                REM : basename of GAME FOLDER PATH to get GAME_TITLE
                for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:treatDlc

                !MessageBox! "ERROR While moving !GAME_TITLE!^'s DLC files !" 4112
                goto:eof
            )
            move /Y !target! !target:%endTitleId%_=! > NUL 2>&1

        ) else (
            robocopy !GAME_FOLDER_PATH! !target! /MT:32 /S > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"
            if !cr! GTR 7 (
                if !attemptTgt! EQU 1 (
                    !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=! for copying Dlc to !target:"=!^, close any program that could use this location" 4112
                    set /A "attemptTgt+=1"
                    goto:treatDlc
                )

                REM : basename of GAME FOLDER PATH to get GAME_TITLE
                for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
                call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:treatDlc

                !MessageBox! "ERROR While copying !GAME_TITLE!^'s DLC files ^!" 4112
                goto:eof
            )
        )

    goto:eof


    REM : ------------------------------------------------------------------
    REM : function to optimize a folder move (move if same drive letter much type faster)
    :moveFolder

        REM arg1 source
        set "source="%~1""
        REM arg2 target
        set "target="%~2""
        REM arg3 = return code

        set "source=!source:\\=\!"
        set "target=!target:\\=\!"

        if not exist !source! goto:eof
        if [!source!] == [!target!] if exist !target! goto:eof
        if not exist !target! mkdir !target!

        REM : source drive
        for %%a in (!source!) do set "sourceDrive=%%~da"

        REM : target drive
        for %%a in (!target!) do set "targetDrive=%%~da"

        REM : if folders are on the same drive
        if ["!sourceDrive!"] == ["!targetDrive!"] (

            if exist !target! rmdir /Q /S !target!
            move /Y !source! !target! > NUL 2>&1
            set /A "cr=%ERRORLEVEL%"
            if !cr! EQU 1 (
                set /A "%3=1"
            ) else (
                set /A "%3=0"
            )
            goto:eof
        )

        REM : else robocopy
        robocopy !source! !target! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! GTR 7 set /A "%3=1"
        if !cr! GEQ 0 set /A "%3=0"

    goto:eof
    REM : ------------------------------------------------------------------


    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
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
