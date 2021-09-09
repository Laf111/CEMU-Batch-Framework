@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    REM : CEMU's Batch FrameWork Version
    set "BFW_VERSION=V23-1"

    REM : version of GFX packs created
    set "BFW_GFXP_VERSION=V6"

    set "THIS_SCRIPT=%~0"
    title -= BatchFw %BFW_VERSION% setup =-

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_PATH=!SCRIPT_FOLDER:\"="!"

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR Remove DOS reserved characters from the path "!THIS_SCRIPT!"^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"

    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    REM : paths and tools used
    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""

    set "createWiiuSDcard="!BFW_TOOLS_PATH:"=!\createWiiuSDcard.bat""
    set "dumpGames="!BFW_TOOLS_PATH:"=!\dumpGamesFromWiiu.bat""
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""

    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    set "quick_Any2Ico="!BFW_RESOURCES_PATH:"=!\quick_Any2Ico.exe""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "xmlS="!BFW_RESOURCES_PATH:"=!\xml.exe""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "browseFile="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFileDialog.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""

    REM : replace ref in glogFile
    set "msg="!BFW_VERSION! installed, version of graphic packs=!BFW_GFXP_VERSION!""
    call:log2GamesLibraryFile !msg!

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set "ACTIVE_ADAPTER=NONE"

    REM : check if folder name contains forbiden character for batch file
    call:securePathForDos !GAMES_FOLDER! SAFE_PATH

    if not [!GAMES_FOLDER!] == [!SAFE_PATH!] (
        echo ERROR ^: please rename your folders to have this compatible path
        echo !SAFE_PATH!
        pause
        exit 95
    )

    if exist !logFile! goto:setChcp

    REM ----------------------------------------------------------------------------------------------
    REM First run checks
    REM ----------------------------------------------------------------------------------------------
    echo =========================================================
    echo BatchFw pre-requisites check^.^.^.
    echo =========================================================

    REM : check if not Linux tools are defined in the environnement
    echo test | find /I "test" > NUL
    if !ERRORLEVEL! NEQ 0 (
        echo Found linux tools in your environnement
        echo Please define them add the end of your path if you
        echo want to launch BatchFw
        pause
        exit 2
    )
    echo DOS only environnement        ^: OK

    REM : check if file system is NTFS (BatchFw use Symlinks and need to be installed on a NTFS volume)
    for %%i in (!BFW_PATH!) do for /F "tokens=2 delims=~=" %%j in ('wmic path win32_volume where "Caption='%%~di\\'" get FileSystem /value 2^>NUL ^| find /I /V "NTFS"') do (

        echo This volume is not an NTFS one^!
        echo BatchFw use Symlinks and need to be installed on a NTFS volume
        pause
        exit 3
    )
    echo File system NTFS              ^: OK

    REM : check rights to create links
    pushd !GAMES_FOLDER!
    set "linkCheck="!BFW_PATH:"=!\linkCheck""
    if exist !linkCheck! rmdir /Q !linkCheck! > NUL 2>&1

    mklink /J !linkCheck! !TMP! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo This user is not allowed to create links^!
        echo BatchFw use Symlinks^, please contact !USERDOMAIN! administrator
        pause
        exit 4
    )
    echo Rights to create symlinks     ^: OK

    if exist !linkCheck! rmdir /Q !linkCheck! > NUL 2>&1

    REM : check rights to launch vbs scripts
    for /F "tokens=3" %%a in ('reg query "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows Script Host\Settings" /v Enabled 2^>NUL') do (
        set "value=%%a"
        set /A "value=!value: =!"

        if !value! EQU 0 (
            echo Launching VBS scripts is not allowed^!
            echo HKEY_LOCAL_MACHINE\Software\Microsoft\Windows Script Host\Settings\Enabled ^<^> 1
            echo value=[!value!]
            echo BatchFw use VBS scripts^, please contact !USERDOMAIN! administrator
            pause
            exit 5
        ) else (
            echo Rights to launch vbs scripts  ^: OK
        )
    )

    java -version > NUL 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo Java is installed ^(optional^)  ^: OK
    ) else (
        echo Java is installed ^(optional^)  ^: WARNING
    )
    echo ---------------------------------------------------------
    timeout /T 4 > NUL 2>&1
    cls

    REM ----------------------------------------------------------------------------------------------

    REM : initialize log file for current host (if needed)
    call:initLogForHost

    REM : create JNUSTool config file
    set "config="!BFW_RESOURCES_PATH:"=!\JNUST\config""
    if not exist !config! call:createJNUSToolConfigFile > !config!

    :setChcp
    REM : set current char codeset
    call:setCharSet

    REM : clean log files specific to a launch
    REM : clean log files specific to a launch
    set "tobeDelete="!BFW_PATH:"=!\logs\fnr_*.*""
    del /F /S !toBeDelete!  > NUL 2>&1
    set "tobeDelete="!BFW_PATH:"=!\logs\jnust_*.*""
    del /F /S !toBeDelete!  > NUL 2>&1
    set "tobeDelete="!BFW_PATH:"=!\logs\fnr""
    rmdir /Q /S !toBeDelete!  > NUL 2>&1

    REM : flush logFile of BFW_VERSION
    call:cleanHostLogFile BFW_VERSION

    set "msg="BFW_VERSION=%BFW_VERSION%""
    call:log2HostFile !msg!

    REM : get screen resolution
    pushd !BFW_RESOURCES_PATH!

    for /f "tokens=2,10-11" %%a in ('cmdOw.exe /p') do (
      if "%%a"=="0" set "scrWidth=%%b" & set "scrHeight=%%c"
    )
    REM : flush logFile of RESOLUTION
    call:cleanHostLogFile RESOLUTION

    set "msg="RESOLUTION=!scrWidth!x!scrHeight!""
    call:log2HostFile !msg!

    REM : flush logFile of REFRESH_RATE
    call:cleanHostLogFile REFRESH_RATE

    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get currentrefreshrate /value 2^>NUL ^| findStr /R "=[0-9]*.$"') do set /A "refreshRate=%%i"

    set "msg="REFRESH_RATE=!refreshRate!""
    call:log2HostFile !msg!

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : rename folders that contains forbiden characters : & ! . ( )
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!GAMES_FOLDER! /REPLACECI^:^^!^: /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE

    REM : check if DLC and update folders are presents (some games need to be prepared)
    call:checkGamesToBePrepared

    REM : rename folders that contains forbiden characters : ( )
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!GAMES_FOLDER! /REPLACECI^:^^(^:[ /REPLACECI^:^^)^:] /EXECUTE

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% EQU 0 (
        title -= Install BatchFw %BFW_VERSION% =-
        goto:beginSetup
    )

    if %nbArgs% NEQ 1 (
        echo ERROR on arguments passed^(%nbArgs%^)
        echo SYNTAXE^: "!THIS_SCRIPT!" OUTPUT_FOLDER
        echo given {%*}
        pause
        exit 9
    )

    REM : get and check OUTPUT_FOLDER
    set "OUTPUT_FOLDER=!args[0]!"
    for %%a in (!OUTPUT_FOLDER!) do set "drive=%%~da"
    if [!OUTPUT_FOLDER!] == ["!drive!\"] set "OUTPUT_FOLDER="!drive!""

    :beginSetup

    call:cleanHostLogFile BFW_VERSION

    set "msg="BFW_VERSION=%BFW_VERSION%""
    call:log2HostFile !msg!

    echo Checking for update ^.^.^.
    REM : update BatchFw
    set "ubw="!BFW_TOOLS_PATH:"=!\updateBatchFw.bat""
    call !ubw!
    set /A "cr=!ERRORLEVEL!"
    if !cr! EQU 0 (

        echo BatchFw updated^, please relaunch
        timeout /t 4 > NUL 2>&1
        set "ChangeLog="!BFW_PATH:"=!\Change.log""
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !ChangeLog!
        exit 75
    )
    timeout /t 2 > NUL 2>&1
    set "readme="!BFW_PATH:"=!\BatchFw_readme.txt""
    set /A "QUIET_MODE=0"
    if exist !readme! set /A "QUIET_MODE=1"

    :scanGamesFolder
    set "OUTPUT_FOLDER=!OUTPUT_FOLDER:\\=\!"
    cls
    if %nbArgs% EQU 0 (
        echo =========================================================
        echo            CEMU^'s Batch FrameWork !BFW_VERSION! installer
        echo =========================================================
        echo ^(in case of false input close this main window to cancel^)
        if %QUIET_MODE% EQU 0 (
            echo ---------------------------------------------------------
            echo BatchFw is a batch framework created to launch easily all
            echo your RPX games ^(loadiines format^) using many versions of
            echo CEMU^.
            echo.
            echo It is now limited only to CEMU's versions ^>=1^.11 that^:
            echo -support the -mlc argument
            echo -use the last saves format
            echo.
            echo It gathers all game^'s data in each game^'s folder and so
            echo ease the CEMU^'s update process and make your loadiine
            echo games library portable^.
        )
    ) else (
        echo =========================================================
        echo Set your BatchFw^'s settings and register many versions
        echo of CEMU
        echo =========================================================
        echo ^(in case of false input close this main window to cancel^)
    )

    echo ---------------------------------------------------------
    echo Scanning your games library^.^.^.
    echo ---------------------------------------------------------

    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_LOGS:"=!\detectInvalidGamesFolder.log""
    dir /B /A:D > !tmpFile! 2>&1
    type !tmpFile! | find "?" > NUL 2>&1 && (
        echo =========================================================
        echo ERROR Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        echo List of game^'s folder^(s^)^:
        echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        echo ---------------------------------------------------------
        echo Fix-it by removing characters here replaced in the folder^'s name by ^'^?^'
        echo Otherwise, they will be ignored by batchFW^!
        echo =========================================================
        pause
    )
    REM : clean BFW_LOGS
    pushd !BFW_LOGS!
    for /F "delims=~" %%i in ('dir /B /S /A:D 2^> NUL') do rmdir /Q /S "%%i" > NUL 2>&1
    for /F "delims=~" %%i in ('dir /B /S /A:L 2^> NUL') do rmdir /Q /S "%%i" > NUL 2>&1

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : scanning games folder (parent folder of _CEMU_Batch_Framework folder)
    set /A NB_GAMES_VALID=0
    REM : searching for code folder to find in only one rpx file (the bigger one)
    for /F "delims=~" %%g in ('dir /B /S /A:D code 2^> NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

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

            if !cr! GTR 1 echo Please rename the game^'s folder to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:searchGameIn

        ) else (

            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            echo !folderName!^: Unsupported characters found^, rename it otherwise it will be ignored by BatchFW ^^!
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

            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    echo =========================================================
    echo ^> !NB_GAMES_VALID! valid games found

    if !NB_GAMES_VALID! EQU 0 (

        echo No RPX games were found
        echo.

        call:getUserInput "Dumps games from your Wii-U (1), install games coming with update and/or DLC (2), download games (3) or cancel (c) ?" "1,2,3,c" ANSWER
        if [!ANSWER!] == ["c"] (
            echo So exiting^.^.^.
            echo _BatchFW_Install folder must be located in your loadiines ^(^*^.rpx^) games folder
            timeout /T 8 > NUL 2>&1
            exit 55
        )
        if [!ANSWER!] == ["1"] goto:useWiiU
        if [!ANSWER!] == ["2"] (
            REM : calling importGames.bat
            set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importGames.bat""
            call !tobeLaunch! !GAMES_FOLDER!
        )
        if [!ANSWER!] == ["3"] (
            REM : calling downloadGames.bat
            set "tobeLaunch="!BFW_TOOLS_PATH:"=!\downloadGames.bat""
            call !tobeLaunch! !GAMES_FOLDER!
        )

        timeout /T 3 > NUL 2>&1
        cls


    )
    if %QUIET_MODE% EQU 0 (

        echo ---------------------------------------------------------
        echo This is the very first time you install BatchFw ^:
        echo ---------------------------------------------------------
        call:getUserInput "Read the goals of BatchFW? (y,n = default in 6s) : " "n,y" ANSWER 6
        if [!ANSWER!] == ["n"] goto:goalsOK

        set "tmpFile="!BFW_PATH:"=!\doc\goal.txt""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :goalsOK
        call:getUserInput "Read informations on CEMU interfaces history? (y,n = default in 6s) : " "n,y" ANSWER 6
        if [!ANSWER!] == ["n"] goto:iFOK

        set "tmpFile="!BFW_PATH:"=!\doc\cemuInterfacesHistory.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :iFOK
        call:getUserInput "Read how graphic packs are handled? (y,n = default in 6s) : " "n,y" ANSWER 6
        if [!ANSWER!] == ["n"] goto:gfxPacksOK

        set "tmpFile="!BFW_PATH:"=!\doc\graphicPacksHandling.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :gfxPacksOK
        call:getUserInput "Read about users saves/extra slots feature? (y,n = default in 6s) : " "n,y" ANSWER 6
        if [!ANSWER!] == ["n"] goto:savesOK

        set "tmpFile="!BFW_PATH:"=!\doc\userSavesAndSlots.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :savesOK
        call:getUserInput "Read about Wii-U transferts feature? (y,n = default in 6s) : " "n,y" ANSWER 6
        if [!ANSWER!] == ["n"] goto:useProgressBar
        set "tmpFile="!BFW_PATH:"=!\doc\syncWii-U.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

    )

    :useProgressBar
    if %nbArgs% EQU 0 call:setProgressBar

    echo ---------------------------------------------------------
    echo You can import ^'ready to use^' mods for your games^.
    echo Note that if you use more than one mod you^'d better use BCML to create a
    echo resulting mod ^'ready to use^'^.
    echo.
    call:getUserInput "Have you got some mods for your games that you wish to import (y,n)? " "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:askGpCheckUpdate

    :askAnotherModFolder
    set "im="!BFW_TOOLS_PATH:"=!\importModsForAllGames.bat""
    wscript /nologo !StartWait! !im!

    call:getUserInput "Do you want to add another mod folder (y,n = default in 10s)?" "n,y" ANSWER 10
    if [!ANSWER!] == ["y"] goto:askAnotherModFolder
    echo Next time use the shortcut in
    echo Wii-U Games^\_BatchFw^\Tools^\Graphic packs^\Import Mods for my games^.lnk

    echo ^> Mods were imported in each game^'s folder

    :askGpCheckUpdate
    echo ---------------------------------------------------------
    REM : flush logFile of CHECK_UPDATE
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "CHECK_UPDATE" 2^>NUL') do call:cleanHostLogFile CHECK_UPDATE

    call:getUserInput "Do you want to check for BatchFW's update (y = default in 10s, n)? " "y,n" ANSWER 10
    if [!ANSWER!] == ["y"] (
        set "msg="CHECK_UPDATE=YES""
        call:log2HostFile !msg!
    )

    echo ---------------------------------------------------------
    REM : flush logFile of COMPLETE_GP
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "COMPLETE_GP" 2^>NUL') do call:cleanHostLogFile COMPLETE_GP

    choice /C yn /N /M "Do you want BatchFW to complete graphic packs? (y,n):"
    if !ERRORLEVEL! EQU 1 (
        set "msg="COMPLETE_GP=YES""
        call:log2HostFile !msg!
        goto:askRatios
    )
    REM : else
    goto:askScreenMode

    :askRatios
    set /A "changeArList=0"

    REM : compute current aspect ratio
    call:reduceFraction !scrWidth! !scrHeight! sWr sHr

    set "msg="DESIRED_ASPECT_RATIO=!sWr!-!sHr!=!sWr!/!sHr!""

    type !logFile! | find /I !msg! > NUL 2>&1 && goto:getArList
    REM : will force BatchFw to complete GFX packs/presets
    set /A "changeArList=1"
    call:log2HostFile !msg!

    :getArList
    REM : get the users list
    set "ARLIST=EMPTY"

    REM : search in all Host_*.log
    set "pat="!BFW_LOGS:"=!\Host_*.log""
    for /F "delims=~" %%i in ('dir /S /B !pat! 2^>NUL') do (
        set "currentLogFile="%%i""

        REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
        for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (
            REM : add to the list if not already present
            if not ["!ARLIST!"] == [""] echo !ARLIST! | find /V "%%j" > NUL 2>&1 && (
                set "ARLIST=%%j !ARLIST!"
                REM : will force BatchFw to complete GFX packs/presets
                set /A "changeArList=1"
            )
            if ["!ARLIST!"] == [""] set "ARLIST=%%j !ARLIST!"
        )
    )

    set "ARLIST=!ARLIST:EMPTY=!"
    echo.
    echo Aspect ratios already defined in BatchFW for all hosts you already used: !ARLIST!
    echo.
    call:getUserInput "Change this list? (y = add an aspect ratio or define a custom one, n = default in 20s)" "n,y" ANSWER 20
    if [!ANSWER!] == ["n"] goto:askScreenMode

    echo ---------------------------------------------------------
    echo Choose your display ratio ^(for extra graphic packs^) ^:
    echo.

    echo     ^(1^)^: custom one ^(define it^)
    echo     ^(2^)^: 4^/3
    echo     ^(3^)^: 16^/9 ^(missing resolutions^) standard HDTV
    echo     ^(4^)^: 21^/9
    echo     ^(5^)^: 21^/9 UltraWide 2^.37^:1 ^(2560x1080 = 64^/27^)
    echo     ^(6^)^: 21^/9 UltraWide 2^.4^:1 ^(1920x900 = 32^/15^)
    echo     ^(7^)^: 21^/9 UltraWide 2^.13^:1 ^(1920x800 = 12^/5^)
    echo     ^(8^)^: TV Flat 1^.85^:1 ^(1998x1080 = 37^/20^)
    echo     ^(9^)^: TV Scope 2^.39^:1 ^(2048x858 = 1024^/429^)
    echo     ^(10^)^: TV Full Container (DCI) 1^.89^:1 ^(2048x1080 = 256^/135^)

    echo     ^(c^)^: cancel
    echo ---------------------------------------------------------

    :askRatioAgain
    set /P  "ANSWER=Enter your choice: "
    if not ["!ANSWER!"] == ["c"] (

        if ["!ANSWER!"] == ["1"] (
            :getcustomAr
            echo.
            echo You can enter a directly a target resolution if you don^'t know
            echo the reduced ratio^.
            echo.
            set /P  "widthRead=Please enter width  : "
            set /P "heightRead=Please enter height : "
            echo.
            REM : compute current aspect ratio
            call:reduceFraction !widthRead! !heightRead! width height

            choice /C ny /N /M "Define !width!/!height! as aspect ratio ? (y,n): "
            if !ERRORLEVEL! EQU 1 goto:getcustomAr

            set /P "desc=Please enter a description for this setting : "
            call:secureStringForDos !desc! desc > NUL 2>&1
            set "desc=!desc:"=!"

            set "msg="DESIRED_ASPECT_RATIO=!width!-!height!=!desc!""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["2"] (
            set "msg="DESIRED_ASPECT_RATIO=4-3=4/3""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["3"] (
            set "msg="DESIRED_ASPECT_RATIO=16-9=16/9""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["4"] (
            set "msg="DESIRED_ASPECT_RATIO=21-9=21/9""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["5"] (
            set "msg="DESIRED_ASPECT_RATIO=64-27=21/9 UltraWide 2.37:1""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["6"] (
            set "msg="DESIRED_ASPECT_RATIO=32-15=21/9 UltraWide 2.4:1""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["7"] (
            set "msg="DESIRED_ASPECT_RATIO=12-15=21/9 UltraWide 2.13:1""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["8"] (
            set "msg="DESIRED_ASPECT_RATIO=37-20=TV Flat 1.85:1""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["9"] (
            set "msg="DESIRED_ASPECT_RATIO=1024-429=TV Scope 2.39:1""
            goto:anotherRatio
        )
        if ["!ANSWER!"] == ["10"] (
            set "msg="DESIRED_ASPECT_RATIO=256-135=TV DCI 1.89:1""
            goto:anotherRatio
        )
        goto:askRatioAgain
    ) else (
        goto:askScreenMode
    )
    :anotherRatio

    type !logFile! | find /I !msg! > NUL 2>&1 && goto:getAnotherRatio
    set /A "changeArList=1"
    call:log2HostFile !msg!

    :getAnotherRatio

    choice /C yn /N /M "Add another ratio? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askRatioAgain

    :askScreenMode
    echo ---------------------------------------------------------
    REM : flush logFile of SCREEN_MODE
    call:cleanHostLogFile SCREEN_MODE

    choice /C yn /N /M "Do you want to launch CEMU in fullscreen? (y,n):"
    if !ERRORLEVEL! EQU 1 goto:updateGfxPacksFolder

    set "msg="SCREEN_MODE=windowed""
    call:log2HostFile !msg!

    :updateGfxPacksFolder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    REM : check if GAMES_FOLDER\_BatchFw_Graphic_Packs exist
    if not exist !BFW_GP_FOLDER! mkdir !BFW_GP_FOLDER! > NUL 2>&1

    REM : check if an internet connection is active
    if ["!ACTIVE_ADAPTER!"] == ["NONE"] (
        set "ACTIVE_ADAPTER=NOT_FOUND"
        for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    )
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] goto:extractlgfxp

    echo ---------------------------------------------------------
    echo Checking latest graphics packs^'update

    REM : update graphic packs
    set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
    call !ugp!
    set /A "cr=!ERRORLEVEL!"

    REM : if user cancelled the update
    if !cr! EQU 2 if not exist !BFW_GP_FOLDER! goto:beginExtraction

    REM : here ["!ACTIVE_ADAPTER!"] != ["NOT_FOUND"]
    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""

    if exist !glogFile! if !changeArList! EQU 1 (
        REM : clean all entries in glogFile to force bathFw to complete
        REM : GFX packs on next launch
        call:cleanGameLibFile "version=graphicPacks"

    )
    if !cr! EQU 0 goto:getUserMode

    :extractlgfxp
    if !changeArList! EQU 1 goto:beginExtraction
    if %QUIET_MODE% EQU 1 goto:getUserMode

    :beginExtraction
    REM : first launch of setup.bat
    if exist !BFW_GP_FOLDER!  goto:getUserMode
    mkdir !BFW_GP_FOLDER! > NUL 2>&1

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo Extracting embeded graphics packs^.^.^.
    echo ---------------------------------------------------------
    REM : extract embeded packs
    set "rarFile="!BFW_RESOURCES_PATH:"=!\GFX_Packs.rar""

    wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !BFW_GP_FOLDER! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo ERROR while extracting GFX_Packs^.rar^, exiting 1
        pause
        exit /b 1
    )

    echo ^> Graphic packs installed from archive

    REM : get users
    :getUserMode

    REM : rename GFX folders that contains forbiden characters : & ! . ( )
    wscript /nologo !StartHidden! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /REPLACECI^:^^(^:[ /REPLACECI^:^^)^:] /EXECUTE

    REM : by default: create shortcuts
    echo ---------------------------------------------------------

    REM : get the users list
    set "usersList=EMPTY"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "USER_REGISTERED" 2^>NUL') do set "usersList=!usersList! [%%i]"

    if not ["!usersList!"] == ["EMPTY"] goto:handleUsers
    choice /C ny /N /M "Do you want to add more than one user? (y,n):"
    if !ERRORLEVEL! EQU 1 (

        set "msg="USER_REGISTERED=!USERNAME!""
        call:log2HostFile !msg!
        goto:getSoftware
    )
    :handleUsers

    if ["!usersList!"] == ["EMPTY"] goto:getUsers

    set "usersList=!usersList:EMPTY=!"
    echo Users already registered in BatchFW: !usersList!

    call:getUserInput "Change this list (y,n = default in 20s)? " "n,y" ANSWER 20
    if [!ANSWER!] == ["n"] goto:getSoftware

    REM : flush logFile of USER_REGISTERED
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "USER_REGISTERED" 2^>NUL') do call:cleanHostLogFile USER_REGISTERED

    REM : Get BatchFw's users registered
    set /A "alreadyAsked=0"
    :getUsers

    if !alreadyAsked! EQU 1 goto:batchFwUsers

    :useWiiU
    echo.
    call:getUserInput "Do you want to use your Wii-U to create BatchFw's users  (y,n = default in 20s)? " "n,y" ANSWER 20
    echo.
    if [!ANSWER!] == ["n"] set /A "alreadyAsked=1" && goto:batchFwUsers
    echo.
    echo You can use your Wii-U accounts to create BatchFw^'users
    echo list and get the files needed to play online^.
    echo For that^, you need to had dumped your NAND^.
    echo.

    if not exist !BFW_WIIU_FOLDER! (

        choice /C yn /N /M "Do you need to format a SDCard with homebrew apps on? (y,n):"
        if !ERRORLEVEL! EQU 1 wscript /nologo !StartWait! !createWiiuSDcard!
        echo.
    )
    if !NB_GAMES_VALID! NEQ 0 (
        choice /C yn /N /M "Continue and create users' list from your Wii-U? (y,n -> enter users manually):"
        echo.
        if !ERRORLEVEL! EQU 2 set /A "alreadyAsked=1" && goto:batchFwUsers
    )

    echo On your Wii-U^, you need to ^:
    echo - disable the sleeping^/shutdown features
    echo - launch WiiU FTP Server
    echo - get the IP adress displayed on Wii-U gamepad
    echo.

    REM : get online files and accounts
    pushd !BFW_TOOLS_PATH!
    set "tobeLaunch="!BFW_TOOLS_PATH:"=!\getWiiuOnlineFiles.bat""
    call !tobeLaunch! -wiiuAccounts
    set /A "cr=!ERRORLEVEL!"
    pushd !GAMES_FOLDER!
    if !cr! NEQ 0 (
        echo.
        echo Fail to get users from wiiU ^!
        goto:handleUsers
    )

    echo.

    if !NB_GAMES_VALID! EQU 0 (
        echo Launching dumping games^.^.^.
        REM : launch dumping games script
        wscript /nologo !Start! !dumpGames!
        echo When finished^, relaunch setup^.bat
        timeout /T 6 > NUL 2>&1
        exit 15
    ) else (
        choice /C yn /N /M "Do you want to import some saves from your WII-U now? (y,n):"
        if !ERRORLEVEL! EQU 2 goto:getSoftware
    )
    echo.
    echo BatchFw need to take a snapshot of your Wii-U to
    echo will list games^, saves^, updates and DLC
    echo precising where they are installed ^(mlc or usb^)
    echo.

    pushd !BFW_TOOLS_PATH!
    set "tobeLaunch="!BFW_TOOLS_PATH:"=!\scanWiiU.bat""
    wscript /nologo !StartWait! !tobeLaunch!

    echo.
    echo Now getting your wii-U saves^.^.^.
    echo.

    set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importWiiuSaves.bat""
    wscript /nologo !StartWait! !tobeLaunch!
    pushd !GAMES_FOLDER!
    goto:getSoftware

    :batchFwUsers
    set /P "input=Please enter BatchFw's user name : "
    call:secureUserNameForBfw "!input!" safeInput
    if !ERRORLEVEL! NEQ 0 (
        echo ^~^, ^* or ^= are not allowed characters ^!
        echo Please remove them
        goto:getUsers
    )

    if not ["!safeInput!"] == ["!input!"] (
        echo Some unhandled characters were found ^!
        echo ^^ ^| ^< ^> ^" ^: ^/ ^\ ^? ^. ^! ^& %%
        echo list = ^^ ^| ^< ^> ^" ^: ^/ ^\ ^? ^. ^! ^& %%
        choice /C yn /N /M "Use !safeInput! instead ? (y,n): "
        if !ERRORLEVEL! EQU 2 goto:getUsers
    )
    set "user="!safeInput!""

    set "msg="USER_REGISTERED=!user:"=!""
    call:log2HostFile !msg!

    choice /C yn /N /M "Add another user? (y,n): "
    if !ERRORLEVEL! EQU 1  goto:getUsers

    :getSoftware

    echo ---------------------------------------------------------

    REM : get the software list
    set "softwareList=EMPTY"
    for /F "tokens=2 delims=~@" %%i in ('type !logFile! ^| find "TO_BE_LAUNCHED" 2^>NUL') do (

        set "command=%%i"

        call:isSoftwareValid "!command!" program valid

        if !valid! EQU 1 (
            set "softwareList=!softwareList! !program!"
        ) else (
            call:cleanHostLogFile !program:"='!
        )
    )
    if not ["!softwareList!"] == ["EMPTY"] goto:handleSoftware

    echo Do you want BatchFw to launch a third party software before
    echo launching CEMU^?
    echo ^(E^.G^. DS4Windows^, wiimoteHook^, cemuGyro^, a speed hack^.^.^.^)
    echo.
    echo They will be launched in the order you will enter here^.
    echo.
    choice /C ny /N /M "Register a third party software? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    echo.
    :handleSoftware
    if ["!softwareList!"] == ["EMPTY"] goto:askS

    set "softwareList=!softwareList:EMPTY=!"
    echo Software already registered in BatchFW: !softwareList!
    choice /C ny /N /M "Change this list? (y,n) "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    REM : flush logFile of TO_BE_LAUNCHED
    call:cleanHostLogFile TO_BE_LAUNCHED

    echo ---------------------------------------------------------
    choice /C ny /N /M "Add a 3rd party software? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    :askS
    echo ---------------------------------------------------------
    choice /C ny /N /M "Do you need to enter arguments for the 3rd party software? (y,n): "
    if !ERRORLEVEL! EQU 2 goto:askSpath

    REM : browse to the file
    :browse3rdP
    for /F %%b in ('cscript /nologo !browseFile! "Please browse to 3rd party program"') do set "file=%%b" && set "spath=!file:?= !"
    if [!spath!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders
        goto:browse3rdP
    )
    goto:reg3rdPartySotware


    :askSpath
    echo Enter full paths for the software and its arguments
    echo ALL SURROUNDED by double quotes^.
    set /P "spath=Enter the full command line: "

    REM : resolve venv for search
    for /F "tokens=1 delims=~'" %%j in ("!spath!") do set "program="%%j""

    if not exist !program! (
        echo !spath! is not valid ^!
        goto:askSpath
    )

    :reg3rdPartySotware
    set "spath=!spath:"='!"
    set "msg=TO_BE_LAUNCHED@!spath!"

    choice /C ny /N /M "Do you want BatchFw to close it after Cemu stops? (y,n) "
    if !ERRORLEVEL! EQU 1  set "msg="!msg!@N""
    if !ERRORLEVEL! EQU 2  set "msg="!msg!@Y""

    call:log2HostFile !msg!

    set "name="NONE""
    set "program="NONE""
    set "firstArg="NONE""
    for /F "tokens=1 delims=~'" %%j in ("!spath!") do set "program="%%j""
    for /F "delims=~" %%i in (!program!) do set "name=%%~nxi"

    set "icoFile=!name:.exe=.ico!"
    set "icoPath="!BFW_RESOURCES_PATH:"=!\icons\!icoFile!""
    if not exist !icoPath! call !quick_Any2Ico! "-res=!program:"=!" "-icon=!icoPath:"=!" -formats=512

    choice /C yn /N /M "Add another third party software? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askSpath

    :askExtMlC01Folders
    set /A "useMlcFolderFlag=0"
    if %nbArgs% EQU 0 if !QUIET_MODE! EQU 0 (
        echo ---------------------------------------------------------
        choice /C ny /N /M "Do you use an/some external mlc01 folder(s) you wish to import? (y,n): "
        if !ERRORLEVEL! EQU 1 goto:getOuptutsType

        set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !tmpFile!

        echo.
        echo If you have defined more than one user^, you^'ll need to
        echo define which user^'s save is it.
        echo.

       :getExtMlc01
        set "script="!BFW_TOOLS_PATH:"=!\moveMlc01DataForAllGames.bat""
        choice /C mc /CS /N /M "Move (m) or copy (c) data?"
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 2 set "script="!BFW_TOOLS_PATH:"=!\copyMlc01DataForAllGames.bat""

        wscript /nologo !StartWait! !script!

        choice /C yn /N /M "Add another external mlc01 folder? (y,n): "
        if !ERRORLEVEL! EQU 1 goto:getExtMlc01

        echo ^> Externals mlc01 data was imported^!
        echo.
        echo Next time use the shortcuts in
        echo Wii-U Games^\_BatchFw^\Tools^\Mlc01 folder handling
        echo and^/or
        echo Wii-U Games^\_BatchFw^\Tools^\Games^'s saves to import
        echo only save for a user from a ml01 folder
        echo.
        pause
        set /A "useMlcFolderFlag=1"

    )

    :getOuptutsType
    if %QUIET_MODE% EQU 0 if !NB_GAMES_VALID! EQU 0 (
        echo No loadiines games^(^*^.rpx^) founds under !GAMES_FOLDER!^!
        echo Please extract BatchFw in your loadiines games^' folder
        REM : show doc
        set "tmpFile="!BFW_PATH:"=!\doc\updateInstallUse.txt""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
        pause
        echo Exiting 10
    )

    cls
    set "outputType=LNK"
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo What kind of outputs do you want to launch your games^?
    echo.
    echo 1^: Windows shortcuts
    echo 2^: Executables files ^(to define Steam shorcuts^)
    echo.
    REM : display only if shortcuts have already been created
    set /A "alreadyInstalled=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create " 2^>NUL') do set /A "alreadyInstalled=1"
    if %alreadyInstalled% EQU 1 (
        echo 3^: Cancel^, i just wanted to set BatchFw^'s settings
        echo.
        call:getUserInput "Enter your choice ?: " "1,2,3" OUTPUTS_TYPE
    ) else (
        call:getUserInput "Enter your choice ?: " "1,2" OUTPUTS_TYPE
    )
    if [!OUTPUTS_TYPE!] == ["3"] (
        echo Exiting^.^.^.
        timeout /T 3 > NUL 2>&1
        exit 25
    )
    if [!OUTPUTS_TYPE!] == ["1"] goto:getOuptutsFolder

    set "outputType=EXE"
    set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
    if %QUIET_MODE% EQU 0 (
        set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
    )

    :getOuptutsFolder
    cls
    REM : skip if one arg is given
    if %nbArgs% EQU 1 (
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo ^> Ouptuts will be created in !OUTPUT_FOLDER:"=!\Wii-U Games
        timeout /T 3 > NUL 2>&1
        goto:registerCemuInstalls
    )

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo Define target folder for shortcuts ^(a Wii-U Games subfolder will be created^)
    echo ---------------------------------------------------------
    :askOutputFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select an output folder (a Wii-U Games subfolder will be created)"') do set "folder=%%b" && set "OUTPUT_FOLDER=!folder:?= !"
    if [!OUTPUT_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askOutputFolder
    )
    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !OUTPUT_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !OUTPUT_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askOutputFolder
    )

    set "cemuFolderCheck=!OUTPUT_FOLDER:"=!\Cemu.exe""

    if exist !cemuFolderCheck! (
        echo Not a Cemu install folder^, please enter the output folder
        echo ^(where shortcuts or exe will be created^)
        pause
        goto:getOuptutsFolder
    )

    echo ^> Ouptuts will be created in !OUTPUT_FOLDER:"=!\Wii-U Games
    timeout /T 3 > NUL 2>&1

    :registerCemuInstalls

    if [!OUTPUTS_TYPE!] == ["1"] (
        REM : instanciate a fixBrokenShortcut.bat
        set "fbsf="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shortcuts""

        if not exist !fbsf! (
            mkdir !fbsf! > NUL 2>&1
            robocopy !BFW_TOOLS_PATH! !fbsf! "fixBrokenShortcuts.bat" > NUL 2>&1
        )
        set "target="!fbsf:"=!\fixBrokenShortcuts.bat""
        attrib -R !target!

        set "fnrLog="!BFW_LOGS:"=!\fnr_setup.log""
        !fnrPath! --cl --dir !fbsf! --fileMask "fixBrokenShortcuts.bat" --find "TO_BE_REPLACED" --replace !GAMES_FOLDER! --logFile !fnrLog!
        del /F !fnrLog! > NUL 2>&1
    )

    REM : get GPU_VENDOR
    set "GPU_VENDOR=NOT_FOUND"
    set "gpuType=OTHER"
    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get Name /value 2^>NUL ^| find "="') do (
        set "string=%%i"
        echo "!string!" | find /I "NVIDIA" > NUL 2>&1 && (
            set "gpuType=NVIDIA"
            set "GPU_VENDOR=!string: =!"
        )
        echo "!string!" | find /I "AMD" > NUL 2>&1 && (
            set "gpuType=AMD"
            set "GPU_VENDOR=!string: =!"
        )
    )

    if ["!GPU_VENDOR!"] == ["NOT_FOUND"] set "GPU_VENDOR=!string: =!"
    call:secureStringForDos !GPU_VENDOR! GPU_VENDOR > NUL 2>&1
    set "GPU_VENDOR=!GPU_VENDOR:"=!"

    cls

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo Please^, define your CEMU^'s installations paths
    echo ---------------------------------------------------------
    echo ^> If needed BatchFw will add the right version of CemuHook
    echo and install sharedFonts
    echo ^> If you install CEMU^>=1^.15^.1^, you^'d better have it
    echo installed on C^: to avoid a long copy of your GLCache into
    echo CEMU^'s install folder
    echo ---------------------------------------------------------

    REM : intialize Number of Cemu Version beginning from 0
    set /A "NBCV=0"

    :askCemuFolder
    set /A "NBCV+=1"

    for /F %%b in ('cscript /nologo !browseFolder! "Select a Cemu's install folder"') do set "folder=%%b" && set "CEMU_FOLDER=!folder:?= !"
    if [!CEMU_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askCemuFolder
    )

    REM : check if folder name contains forbiden character for !CEMU_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !CEMU_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !CEMU_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askCemuFolder
    )
    REM : check that cemu.exe exist in
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe" "
    if not exist !cemuExe! (
        echo ERROR^, No Cemu^.exe file found under !CEMU_FOLDER! ^^!
        goto:askCemuFolder
    )

    if !cr! EQU 1 (
        set /A "NBCV-=1"
        goto:askCemuFolder
    )

    REM : basename of CEMU_FOLDER
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"
    echo CEMU install %NBCV%^: !CEMU_FOLDER!
    call:regCemuInstall %NBCV% !CEMU_FOLDER!

    echo ---------------------------------------------------------
    call:getUserInput "Do you want to add another version? (y,n)" "y,n" ANSWER
    if [!ANSWER!] == ["y"] goto:askCemuFolder

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo ^> Done
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if %QUIET_MODE% EQU 1 goto:done

    call:getUserInput "Would you like to see how BatchFW works? (y,n = default in 6s)" "n,y" ANSWER 6
    if [!ANSWER!] == ["n"] goto:done

    set "tmpFile="!BFW_PATH:"=!\doc\howItWorks.txt""
    wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

    :done
    cls
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if not exist !readme! (
        echo BatchFW_readme^.txt created^, switch this script in ^'silent mode^'
        echo if needed open BatchFW_readme^.txt with its shortcut
        REM : building documentation
        call:buildDoc
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    )

    echo BatchFw share a common GFX packs folder with all versions
    echo of CEMU ^(installed in your game library as _BatchFw_Graphic_Packs^)
    echo do not use the update feature in CEMU but the provided scripts^.
    echo.
    echo Same remark concerning the auto update feature of CEMU UI^:
    echo The point of BatchFw is to install the both versions ^(previous and
    echo current^) before removing the previous one if the last one runs all
    echo your games without any issue.
    echo ---------------------------------------------------------
    if %nbArgs% EQU 0 pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo If you want to change global CEMU^'s settings you^'ve just
    echo entered here^:
    echo ---------------------------------------------------------
    echo ^> simply delete the shortcuts and recreate them using
    echo Wii-U Games^\Create CEMU^'s shortcuts for selected games^.lnk
    echo to register a SINGLE version of CEMU
    echo ---------------------------------------------------------
    if %nbArgs% EQU 0 pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo If you encounter any issues or have made a mistake when
    echo collecting settings for a game^:
    echo ---------------------------------------------------------
    echo ^> delete the settings saved for !CEMU_FOLDER_NAME! using
    echo the shortcut in Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!
    echo Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    echo ---------------------------------------------------------
    if %nbArgs% EQU 0 pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo If you want to change Batch^'s settings ^(such as graphic
    echo pack completion^, aspects ratios^) and^/or^ register more
    echo than one version of CEMU^:
    echo ---------------------------------------------------------
    echo ^> relaunch this script from its shortcut
    echo Wii-U Games^\Set BatchFw settings and register CEMU installs^.lnk
    echo ---------------------------------------------------------
    echo You can now only use the shortcuts created in
    echo !OUTPUT_FOLDER:"=!\Wii-U Games
    echo There^'s no need to launch scripts from _BatchFw_Install now^!
    pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if %nbArgs% EQU 1 goto:endMain

    echo opening !OUTPUT_FOLDER:"=!\Wii-U Games^.^.^.
    timeout /T 4 > NUL 2>&1

    set "folder="!OUTPUT_FOLDER:"=!\Wii-U Games""
    wscript /nologo !Start! "%windir%\explorer.exe" !folder!
    echo =========================================================
    echo This windows will close automatically in 15s
    echo     ^(n^)^: don^'t close^, i want to read history log first
    echo     ^(q^)^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice?: " "q,n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    :endMain
    if %nbArgs% EQU 0 (
        REM : readonly batchFw files
        pushd !BFW_PATH!
        attrib +r *.bat > NUL 2>&1
        pushd !BFW_TOOLS_PATH!
        attrib +r *.bat > NUL 2>&1
        attrib +r !wiiTitlesDataBase! > NUL 2>&1
    )

    endlocal
    if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
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

    :createJNUSToolConfigFile

        echo http^:^/^/ccs^.cdn^.wup^.shop^.nintendo^.net^/ccs^/download
        echo [COMMONKEY]
        echo updatetitles^.csv
        echo https^:^/^/tagaya^.wup^.shop^.nintendo^.net^/tagaya^/versionlist^/EUR^/EU/^latest_version
        echo https^:^/^/tagaya-wup^.cdn^.nintendo^.net^/tagaya^/versionlist^/EUR^/EU^/list^/%%d^.versionlist

    goto:eof

    :reduceFraction

        set /A "w=%~1"
        set /A "h=%~2"

        for /L %%l in (19,-1,2) do (

            set /A "multiplier=%%l"
            set /A "r=!w!%%!multiplier!"

            if !r! EQU 0 (
                set /A "r=!h!%%!multiplier!"
                if !r! EQU 0 (
                    set /A "w=w/!multiplier!"
                    set /A "h=h/!multiplier!"
                )
            )
        )
        REM : avoid 8/5 for 16/10
        if !w! EQU 8 if !h! EQU 5 set /A "w=16" & set /A "h=10"

        set /A "%3=!w!"
        set /A "%4=!h!"
    goto:eof

REM : ------------------------------------------------------------------

    REM : function to set or ask for using progressbar
    :setProgressBar
        REM : enable progress bar if installed on a removable device
        for /F "delims=~= tokens=2" %%i in ('wmic logicaldisk where "drivetype=2" get caption /value 2^>NUL ^| find "="') do (
            set "caption=%%i"
            set "usbDrive=!caption:~0,-1!"
            if ["!usbDrive!"] == ["!drive!"] (
                set "msg="USE_PROGRESSBAR=YES""
                call:log2HostFile !msg!
                goto:eof
            )
        )

        echo ---------------------------------------------------------
        echo BatchFw comes with a progress bar to monitor pre and post
        echo treatments^.
        echo.
        echo NOTE ^: Using the progressbar results in doubling launch times
        echo         You can en^/disable it using the shortcuts under ^'Wii-U Games^\BatchFw^'
        echo.

        call:getUserInput "Use a progress bar to monitor treatments? (y, n=default in 20sec): " "n,y" ANSWER 20
        if [!ANSWER!] == ["y"] (
            set "msg="USE_PROGRESSBAR=YES""
            call:log2HostFile !msg!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    REM : check if (DLC) or (UPDATE DATA) folders exist
    :checkGamesToBePrepared

        REM : already pushed to GAMES_FOLDER
        set /A "needImport=0"

        set "pat="*(DLC)*""
        for /F "delims=~" %%i in ('dir /A:d /B !pat! 2^>NUL') do set /A "needImport=1"
        set "pat="*(UPDATE DATA)*""
        for /F "delims=~" %%i in ('dir /A:d /B !pat! 2^>NUL') do set /A "needImport=1"

        REM : if need call import script and wait
        if !needImport! EQU 0 goto:eof

        echo Hum^.^.^. some DLC and UPDATE DATA folders were found
        echo Preparing those games for emulation^.^.^.
        timeout /T 5 > NUL 2>&1

        REM : calling importGames.bat
        set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importGames.bat""
        call !tobeLaunch! !GAMES_FOLDER!

        echo ---------------------------------------------------------
        echo ^> Games ready for emulation
        timeout /T 5 > NUL 2>&1
        cls

    goto:eof
    REM : ------------------------------------------------------------------


    REM : build doc
    :buildDoc
        set "tmpFile="!BFW_PATH:"=!\doc\goal.txt""
        type !tmpFile! > !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\updateInstallUse.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\howItWorks.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\cemuInterfacesHistory.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\contributors.txt""
        type !tmpFile! >> !readme!
    goto:eof
    REM : ------------------------------------------------------------------


    :installCemuHook

        REM : cemuHook for versions < 1.12.1
        set "rarFile="!BFW_RESOURCES_PATH:"=!\cemuhook_1116_0564.rar""
        if !v122! EQU 2 goto:extractCemuHook

        set "rarFile="!BFW_RESOURCES_PATH:"=!\cemuhook_1159_0573.rar""
        if !v1251! EQU 2 goto:extractCemuHook

        set "rarFile="!BFW_RESOURCES_PATH:"=!\cemuhook_1251_0574.rar""

        :extractCemuHook
        wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !CEMU_FOLDER! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 1 (
            echo WARNING ^: while extracting CemuHook
            pause
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles""
        if not exist !CONTROLLER_PROFILE_FOLDER! mkdir !CONTROLLER_PROFILE_FOLDER! > NUL 2>&1

        set "ccp="!CEMU_FOLDER:"=!\ControllerProfiles""
        if not exist !ccp! goto:batchFwToCemu

        pushd !ccp!
        REM : import from CEMU_FOLDER to CONTROLLER_PROFILE_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !bcpf! robocopy !ccp! !CONTROLLER_PROFILE_FOLDER! "%%x" /MT /XF "controller*.*" > NUL 2>&1
        )

        :batchFwToCemu
        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !ccpf! robocopy !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" /MT > NUL 2>&1
        )
        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------

    :regCemuInstall

        set "cemuNumber=%1"
        set "CEMU_FOLDER="%~2""

        for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"
        set "clog="!CEMU_FOLDER:"=!\log.txt""
        set "cs="!CEMU_FOLDER:"=!\settings.xml""

        REM : get the version from log file (CEMU < 1.25.3) or from the executable
        set "versionRead=NOT_FOUND"
        if exist !clog! (
            for /f "tokens=1-6" %%a in ('type !clog! ^| find "Init Cemu"') do set "versionRead=%%e"
        ) else (
            REM : get it from the executable
            set "cemuExe="!CEMU_FOLDER:"=!\Cemu.exe""

            set "here="%CD:"=%""
            pushd !BFW_TOOLS_PATH!
            set "versionReadFromExe=NOT_FOUND"
            for /F %%a in ('getDllOrExeVersion.bat !cemuExe!') do set "versionReadFromExe=%%a"

            if not ["!versionReadFromExe!"] == ["NOT_FOUND"] set "versionRead=!versionReadFromExe:~0,-2!"
            pushd !here!
        )

        if ["!versionRead!"] == ["NOT_FOUND"] (
            echo ERROR^: BatchFw supports only version of CEMU ^>= v1^.11^.6
            echo Install earlier versions per game and per user
            pause
            set /A "NBCV-=1"
            exit /b 77
        )

        echo !versionRead! | findStr /R "^[0-9]*\.[0-9]*\.[0-9]*[a-z]*.$" > NUL 2>&1 && goto:versionOK

        echo ERROR^: BatchFw can^'t get CEMU^'s version^.
        echo This version seems to be not supported.
        pause
        set /A "NBCV-=1"
        exit /b 78

        :versionOK

        if %nbArgs% EQU 1 goto:openCemuAFirstTime
        if !useMlcFolderFlag! EQU 1 goto:openCemuAFirstTime

        REM : first Cemu install
        if %cemuNumber% EQU 1 (

            set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
            if %QUIET_MODE% EQU 0  wscript /nologo !Start! "%windir%\System32\notepad.exe" !tmpFile!
        )

        if exist !cs! (
            choice /C yn /CS /N /M "Use !CEMU_FOLDER_NAME! to copy^/move mlc01 ^(updates^, dlc^, game saves^) to games^' folders^? (^y^,n^)^:"
            if !ERRORLEVEL! EQU 2 goto:openCemuAFirstTime

            choice /C mc /CS /N /M "Move (m) or copy (c)?"
            set /A "cr=!ERRORLEVEL!"

            set "mlc01="!CEMU_FOLDER:"=!\mlc01""

            if !cr! EQU 1 call:move
            if !cr! EQU 2 call:copy
        )

       :openCemuAFirstTime

        REM : importing !GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles
        call:syncControllerProfiles
        if exist !clog! if exist !cs! goto:compareCemuVersion
        echo ---------------------------------------------------------
        echo opening CEMU !versionRead!^.^.^.
        echo.
        echo - If a mlc01 folder creation message popup^, answer 'Yes'
        echo - Ignore graphic pack folder download notification^.
        echo - Ignore quick start assistant ^(next^).
        echo.
        echo Set your REGION^, language and all common settings for your
        echo games ^(default GFX API^, controllers^, sound^, overlay^.^.^.^)
        echo No need to set accounts for user^(s^)
        echo.
        echo Then close CEMU to continue
        echo.
        echo ^(if cemuHook and/or sharedFonts are missing^, BatchFw will
        echo install them for you^)
        echo.

        set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
        wscript /nologo !StartWait! !cemu!

        REM : set GAMES_FOLDER as Games Path (to avoid CEMU popup on first run)
        set "csTmp="!CEMU_FOLDER:"=!\settings.bfw_tmp""
        !xmlS! ed -s "//GamePaths" -t elem -n "Entry" -v !GAMES_FOLDER! !cs! > !csTmp! 2>NUL
        if exist !csTmp! (
            del /F !cs! > NUL 2>&1
            move /Y !csTmp! !cs! > NUL 2>&1
        )

        :compareCemuVersion
        REM : suppose : version > 1.25.1
        set /A "v1251=1"
        set /A "v122=1"
        set /A "v1151=1"

        call:compareVersions !versionRead! "1.25.1" v1251 > NUL 2>&1
        if ["!v1251!"] == [""] echo Error when comparing versions
        if !v1251! EQU 50 echo Error when comparing versions

        REM : version >= 1.25.1
        if !v1251! LEQ 1 goto:checkCemuHook
        
        call:compareVersions !versionRead! "1.22" v122 > NUL 2>&1
        if ["!v122!"] == [""] echo Error when comparing versions
        if !v122! EQU 50 echo Error when comparing versions

        REM : version >= 1.22 (V6+V4 packs)
        if !v122! LEQ 1 goto:checkCemuHook

        REM : version < 1.22

        REM : comparing to 1.15.1 (used later)
        call:compareVersions !versionRead! "1.15.1" v1151 > NUL 2>&1
        if ["!v1151!"] == [""] echo Error when comparing versions
        if !v1151! EQU 50 echo Error when comparing versions

        REM : version >= 1.15.1 (V4 packs)
        if !v1151! LEQ 1 goto:checkV4Packs

        REM : version < 1.15.1

        call:compareVersions !versionRead! "1.14.0" v114 > NUL 2>&1
        if ["!v114!"] == [""] echo Error when comparing versions
        if !v114! EQU 50 echo Error when comparing versions

        REM : version >= 1.14
        if !v114! LEQ 1 goto:checkV4Packs

        REM : version < 1.14 (V2 packs)
        set "gfxv2="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""
        if exist !gfxv2! goto:checkCemuHook

        mkdir !gfxv2! > NUL 2>&1
        set "rarFile="!BFW_RESOURCES_PATH:"=!\V2_GFX_Packs.rar""

        echo ---------------------------------------------------------
        echo graphic pack V2 are needed for this version^, extracting^.^.^.

        wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !gfxv2! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 1 (
            echo ERROR while extracting V2_GFX_Packs^, exiting 21
            pause
            exit /b 21
        )
        goto:checkCemuHook

       :checkV4Packs
        REM : 1.14 <= version < 1.22
        REM : TODO uncomment when V4 packs will not be mixed with V6 one in GFX repo
    REM    set "gfxv4="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV4""
    REM    if exist !gfxv4! goto:checkCemuHook
        REM : TODO comment when V4 packs will not be mixed with V6 one in GFX repo
        goto:checkCemuHook

        mkdir !gfxv4! > NUL 2>&1
        set "rarFile="!BFW_RESOURCES_PATH:"=!\V4_GFX_Packs.rar""

        echo ---------------------------------------------------------
        echo graphic pack V4 are needed for this version^, extracting^.^.^.

        wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !gfxv4! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 1 (
            echo ERROR while extracting V4_GFX_Packs^, exiting 22
            pause
            exit /b 22
        )

       :checkCemuHook
        REM : check if CemuHook is installed
        set "dllFile="!CEMU_FOLDER:"=!\keystone.dll""

        if exist !dllFile! goto:checkSharedFonts

        echo Installing CemuHook^.^.^.
        call:installCemuHook

       :checkSharedFonts

        REM : disable SharedFonts install for CEMU >= 1.25.1
        if !v1251! LEQ 1 goto:setOptArgs

        REM : check if sharedFonts were downloaded
        set "sharedFonts="!CEMU_FOLDER:"=!\sharedFonts""
        if exist !sharedFonts! goto:setOptArgs
        echo Installing sharedFonts^.^.^.
        set "rarFile="!BFW_RESOURCES_PATH:"=!\sharedFonts.rar""
        wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !CEMU_FOLDER! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 1 (
            echo WARNING ^: while extracting sharedFonts
            pause
        )

        :setOptArgs
        REM : importMode (keep for backward compatibility)
        set "argOpt="
        set "IMPORT_MODE=ENABLED"

REM        call:getUserInput "Disable automatic settings import? (y,n : default in 20sec): " "n,y" ANSWER 20
REM
REM        if [!ANSWER!] == ["y"] (
REM            set "argOpt=-noImport"
REM            set "IMPORT_MODE=DISABLED"
REM        )
REM
REM        set "msg="!CEMU_FOLDER_NAME! installed with automatic import=!IMPORT_MODE:"=!""
REM        call:log2HostFile !msg!

        set "IGNORE_PRECOMP=DISABLED"
        REM : GPU is NVIDIA => ignoring precompiled shaders cache
        if ["!gpuType!"] == ["NVIDIA"] (
            set "IGNORE_PRECOMP=ENABLED"
            set "argOpt=%argOpt% -ignorePrecomp"
        )

        set "msg="!CEMU_FOLDER_NAME! installed with ignoring precompiled shader cache=!IGNORE_PRECOMP:"=!""
        call:log2HostFile !msg!

        REM : check if main GPU is iGPU. Ask for -nolegacy if it is the case
        set "noIntel=!GPU_VENDOR:Intel=!"
        if ["!gpuType!"] == ["OTHER"] if not ["!noIntel!"] == ["!GPU_VENDOR!"] (

            echo ---------------------------------------------------------
            REM : CEMU < 1.15.1
            if !v1151! LEQ 1 (
                call:getUserInput "Disable all Intel GPU workarounds (add -NoLegacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -noLegacy"
                goto:launchCreate
            )
            REM : CEMU >= 1.15.1
            if !v1151! EQU 0 (
                call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -Legacy"
                goto:launchCreate
            )
            if !v1151! EQU 2 (
                call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -Legacy"
                goto:launchCreate
            )
        )

       :launchCreate
        if ["%outputType%"] == ["EXE"] goto:createExe

        REM : calling createShortcuts.bat
        set "tobeLaunch="!BFW_PATH:"=!\createShortcuts.bat""
        call !tobeLaunch! !CEMU_FOLDER! !OUTPUT_FOLDER! %argOpt%
        set /A "cr=!ERRORLEVEL!"

        if !cr! NEQ 0 (
            echo ERROR in createShortcuts^, cr=!cr!
            pause
            exit /b 5
        )
        echo ^> Shortcuts created for !CEMU_FOLDER_NAME!
        goto:eof

       :createExe
        REM : calling createExecutables.bat
        set "tobeLaunch="!BFW_PATH:"=!\createExecutables.bat""
        call !tobeLaunch! !CEMU_FOLDER! !OUTPUT_FOLDER! %argOpt%
        set /A "cr=!ERRORLEVEL!"

        if !cr! NEQ 0 (
            echo ERROR in createCemuLancherExecutables^, cr=!cr!
            pause
            exit /b 5
        )
        echo ^> Executables created for !CEMU_FOLDER_NAME!
    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a path
    :secureStringForDos
        REM : str is expected protected with double quotes
        set "string=%~1"

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed in path
            set "string=!string:*=!"
        )

        echo "%~1" | find "(" > NUL 2>&1 && (
            echo ^( is not allowed in path
            set "string=!string:(=!"
        )
        echo "%~1" | find ")" > NUL 2>&1 && (
            echo ^) is not allowed in path
            set "string=!string:)=!"
        )

        if ["!string!"] == ["%~1"] (

            set "string=!string:&=!"
            set "string=!string:?=!"
            set "string=!string:\!=!"
            set "string=!string:%%=!"
            set "string=!string:^=!"
            set "string=!string:/=!"
            set "string=!string:\=!"
            set "string=!string:>=!"
            set "string=!string:<=!"
            set "string=!string:|=!"

            REM : replace '_' by ' ' (if needed)
            set "string=!string:_= !"

            REM : WUP restrictions
            set "string=!string:?=!"
            set "string=!string:?=!"
            set "string=!string:?=!"
            set "string=!string:?=E!"

        )
        set "%2="!string!""

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a path
    :securePathForDos
        REM : str is expected protected with double quotes
        set "string=%~1"

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed in path
            set "string=!string:*=!"
        )

        echo "%~1" | find "(" > NUL 2>&1 && (
            echo ^( is not allowed in path
            set "string=!string:(=!"
        )
        echo "%~1" | find ")" > NUL 2>&1 && (
            echo ^) is not allowed in path
            set "string=!string:)=!"
        )
        if ["!string!"] == ["%~1"] (

            set "string=!string:&=!"
            set "string=!string:?=!"
            set "string=!string:\!=!"
            set "string=!string:%%=!"
            set "string=!string:^=!"
            set "string=!string:/=!"
            set "string=!string:>=!"
            set "string=!string:<=!"
            set "string=!string:|=!"

            REM : WUP restrictions
            set "string=!string:?=!"
            set "string=!string:?=!"
            set "string=!string:?=!"
            set "string=!string:?=E!"

        )
        set "%2="!string!""

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureUserNameForBfw
        set "str=%~1"

        REM : DOS reserved characters
        set "str=!str:&=!"
        set "str=!str:^!=!"
        set "str=!str:%%=!"

        REM : add . and ~
        set "str=!str:.=!"
        echo !str! | find "~" > NUL 2>&1 && (
            echo Please remove ^~ ^(unsupported charcater^) from !str!
            exit /b 50
        )

        REM : add . ? (%userName%_settings.*) ?
        REM : Forbidden characters for files in WINDOWS
        set "str=!str:?=!"
        set "str=!str:\=!"
        set "str=!str:/=!"
        set "str=!str::=!"
        set "str=!str:"=!"
        set "str=!str:>=!"
        set "str=!str:<=!"
        set "str=!str:|=!"
        set "str=!str:^=!"

        echo !str! | find "*" > NUL 2>&1 && (
            echo Please remove ^* ^(unsupported charcater^) from !str!
            exit /b 50
        )
        echo !str! | find "=" > NUL 2>&1 && (
            echo Please remove ^= ^(unsupported charcater^) from !str!
            exit /b 50
        )

        set "%2=!str!"
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------

    :cleanHostLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.bfw_tmp""
        if exist !logFileTmp! (
            del /F !logFile! > NUL 2>&1
            move /Y !logFileTmp! !logFile! > NUL 2>&1
        )

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL 2>&1
        move /Y !logFileTmp! !logFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :move
        set "ms="!BFW_TOOLS_PATH:"=!\moveMlc01DataForAllGames.bat""
        wscript /nologo !StartWait! !ms! !mlc01!

        echo ^> Game^'s data from !mlc01! moved
    goto:eof
    REM : ------------------------------------------------------------------

    :copy
        set "cs="!BFW_TOOLS_PATH:"=!\copyMlc01DataForAllGames.bat""
        wscript /nologo !StartWait! !cs! !mlc01!

        echo ^> Game^'s data from !mlc01! copied
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to search game in folder
    :searchGameIn

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

        for /F "delims=~" %%k in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxk"

        echo - !GAME_TITLE!

        REM : update existing BatchFw installs (only the first launch of setup.bat)
        if %QUIET_MODE% EQU 1 goto:gameTreated

        set "cemuFolder="!GAME_FOLDER_PATH:"=!\Cemu""
        REM : search for inGameSaves, shaderCache and GAME_TITLE.txt under game folder

        for /F "delims=~" %%k in ('dir /B /A:D !GAME_FOLDER_PATH! 2^>NUL') do (
            set "folder="!GAME_FOLDER_PATH:"=!\%%k""

            if ["%%k"] == ["inGameSaves"] (
                if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1

                echo   An inGameSaves subfolder was found directly under the game^'s path root
                echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exists^)
                echo   ^(if you haven't used a BatchFW V10 or later, choose to move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
                if !cr! EQU 2 rmdir /Q /S !folder! > NUL 2>&1
            )
            if ["%%k"] == ["shaderCache"] (

                if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1

                echo   A shaderCache subfolder was found directly under the game^'s path root
                echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exists^)
                echo   ^(if you haven't used a BatchFW V10 or later, choose to move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
                if !cr! EQU 2 rmdir /Q /S !folder! > NUL 2>&1
            )
            if ["%%k"] == ["graphicPacks"] (

                if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1

                echo   A graphicPacks subfolder was found directly under the game^'s path root
                echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exists^)
                echo   ^(if you haven't used a BatchFW V10 or later, choose move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
                if !cr! EQU 2 rmdir /Q /S !folder! > NUL 2>&1
            )

        )
        REM : game info file
        set "gif="!GAME_FOLDER_PATH:"=!\!GAME_TITLE!.txt""

        if exist !gif! (
            if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1
            move /Y !gif! !cemuFolder! > NUL 2>&1
        )

       :gameTreated
        set /A NB_GAMES_VALID+=1

    goto:eof
    REM : ------------------------------------------------------------------

    REM : COMPARE VERSIONS : function to count occurences of a separator
    :countSeparators
        set "string=%~1"
        set /A "count=0"

       :again
        set "oldstring=!string!"
        set "string=!string:*%sep%=!"
        set /A "count+=1"
        if not ["!string!"] == ["!oldstring!"] goto:again
        set /A "count-=1"
        set "%2=!count!"

    goto:eof

    REM : COMPARE VERSIONS :
    REM : if vit < vir return 1
    REM : if vit = vir return 0
    REM : if vit > vir return 2
    :compareVersions
        set "vit=%~1"
        set "vir=%~2"

        REM : format strings
        echo %vir% | findstr /V /R [a-zA-Z] > NUL 2>&1 && set "vir=!vir!00"
        echo !vir! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vir! vir
        echo %vit% | findstr /V /R [a-zA-Z] > NUL 2>&1 && set "vit=!vit!00"
        echo !vit! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vit! vit

        REM : versioning separator (init to .)
        set "sep=."
        echo !vit! | find "-" > NUL 2>&1 && set "sep=-"
        echo !vit! | find "_" > NUL 2>&1 && set "sep=_"

        call:countSeparators !vit! nbst
        call:countSeparators !vir! nbsr

        REM : get the number minimum of sperators found
        set /A "minNbSep=!nbst!"
        if !nbsr! LSS !nbst! set /A "minNbSep=!nbsr!"

        if !minNbSep! NEQ 0 goto:loopSep

        if !vit! EQU !vir! set "%3=0" && goto:eof
        if !vit! LSS !vir! set "%3=2" && goto:eof
        if !vit! GTR !vir! set "%3=1" && goto:eof

       :loopSep
        set /A "minNbSep+=1"
        REM : Loop on the minNbSep and comparing each number
        REM : note that the shell can compare 1c with 1d for example
        for /L %%l in (1,1,!minNbSep!) do (

            call:compareDigits %%l result

            if not ["!result!"] == [""] if !result! NEQ 0 set "%3=!result!" && goto:eof
        )
        REM : check the length of string
        call:strLength !vit! lt
        call:strLength !vir! lr

        if !lt! EQU !lr! set "%3=0" && goto:eof
        if !lt! LSS !lr! set "%3=2" && goto:eof
        if !lt! GTR !lr! set "%3=1" && goto:eof

        set "%3=50"

    goto:eof

    REM : COMPARE VERSION : function to compare digits of a rank
    :compareDigits
        set /A "num=%~1"

        set "dr=99"
        set "dt=99"
        for /F "tokens=%num% delims=~%sep%" %%r in ("!vir!") do set "dr=%%r"
        for /F "tokens=%num% delims=~%sep%" %%t in ("!vit!") do set "dt=%%t"

        set "%2=50"

        if !dt! LSS !dr! set "%2=2" && goto:eof
        if !dt! GTR !dr! set "%2=1" && goto:eof
        if !dt! EQU !dr! set "%2=0" && goto:eof
    goto:eof

    REM : COMPARE VERSION : function to compute string length
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

    :cleanGameLibFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.bfw_tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp! 2>&1

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    REM : COMPARE VERSION : function to format string version without alphabetic charcaters
    :formatStrVersion

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:V=!"
        set "str=!str:v=!"
        set "str=!str:RC=!"
        set "str=!str:rc=!"

        set "str=!str:A=01!"
        set "str=!str:B=02!"
        set "str=!str:C=03!"
        set "str=!str:D=04!"
        set "str=!str:E=05!"
        set "str=!str:F=06!"
        set "str=!str:G=07!"
        set "str=!str:H=08!"
        set "str=!str:I=09!"
        set "str=!str:J=10!"
        set "str=!str:K=11!"
        set "str=!str:L=12!"
        set "str=!str:M=13!"
        set "str=!str:N=14!"
        set "str=!str:O=15!"
        set "str=!str:P=16!"
        set "str=!str:Q=17!"
        set "str=!str:R=18!"
        set "str=!str:S=19!"
        set "str=!str:T=20!"
        set "str=!str:U=21!"

        set "str=!str:W=23!"
        set "str=!str:X=24!"
        set "str=!str:Y=25!"
        set "str=!str:Z=26!"

        set "str=!str:a=01!"
        set "str=!str:b=02!"
        set "str=!str:c=03!"
        set "str=!str:d=04!"
        set "str=!str:e=05!"
        set "str=!str:f=06!"
        set "str=!str:g=07!"
        set "str=!str:h=08!"
        set "str=!str:i=09!"
        set "str=!str:j=10!"
        set "str=!str:k=11!"
        set "str=!str:l=12!"
        set "str=!str:m=13!"
        set "str=!str:n=14!"
        set "str=!str:o=15!"
        set "str=!str:p=16!"
        set "str=!str:q=17!"
        set "str=!str:r=18!"
        set "str=!str:s=19!"
        set "str=!str:t=20!"
        set "str=!str:u=21!"

        set "str=!str:w=23!"
        set "str=!str:x=24!"
        set "str=!str:y=25!"
        set "str=!str:z=26!"

        set "%2=!str!"

    goto:eof

    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion: &, %, !
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
        set question=%1
        REM : arg2 = valuesList
        set valuesList=%~2
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional: if given set 1st value as default value after timeOutValue seconds)
        set timeOutValue=%~4

        REM : init return
        set "%3=?"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if [%timeOutValue%] == [] (
            set choiceCmd=choice /C %choiceValues% /CS /N /M !question!
        ) else (
            set choiceCmd=choice /C %choiceValues% /CS /N /T %timeOutValue% /D %defaultTimeOutValue% /M !question!
        )

        REM : launching and get return code
        !choiceCmd!
        set /A "cr=!ERRORLEVEL!"
        set j=1
        for %%i in ("%valuesList:,=" "%") do (

            if [!cr!] == [!j!] (
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
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

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

    REM : function to initialize log info for current host
    :initLogForHost

        set "logFolder="!BFW_LOGS:"=!""
        if not exist !logFolder! mkdir !logFolder! > NUL 2>&1

        REM : create install log file for current host (if needed)
        if exist !logFile! goto:eof

        REM : get last modified Host log (configuration)
        set "lastHostLog="NONE""
        set "patHostLog="!BFW_LOGS:"=!\Host_*.log""

        for /F "delims=~" %%i in ('dir /B /S /O:D /T:W !patHostLog! 2^>NUL') do set "lastHostLog="%%i""

        call:log2HostFile "================================================="
        call:log2HostFile "CEMU BATCH Framework history and settings for !USERDOMAIN!"
        call:log2HostFile "-------------------------------------------------"

        REM : check if _BatchFw_WiiU\OnlineFiles\usersAccounts exist and contains files
        if not exist !BFW_WIIU_FOLDER! goto:scanOtherHost
        echo =========================================================
        echo New installation on host !USERDOMAIN!
        echo -------------------------------------------------
        echo Found a _BatchFw_WiiU folder^, trying to get Wii-U user^'s profiles
        echo to define BatchFw^'s users^.^.^.
        echo.

        set "pat="!BFW_WIIU_FOLDER:"=!\OnlineFiles\usersAccounts\*.dat""
        for /F "delims=~" %%i in ('dir /B !pat! 2^> NUL') do (
            REM : get user name

            set "account="%%i""
            set "user=!account:~1,-13!"

            echo ^> Found user !user! with an online account
            echo USER_REGISTERED=!user!>>!logFile!
        )
        echo.
        echo. ^(you can modify users list later in the setup process^)
        pause
        goto:3rdPartySoftware

       :scanOtherHost

        REM : if no file found
        if [!lastHostLog!] == ["NONE"] goto:eof

        REM : get registered users list from the last modified Host log
        type !lastHostLog! | find /I "USER_REGISTERED" > NUL && (
            echo =========================================================
            echo New installation for host !USERDOMAIN!
            echo -------------------------------------------------
            echo Getting users defined for the last previous installation
            echo using !lastHostLog:"=!
            echo.
            type !lastHostLog! | find /I "USER_REGISTERED"
            type !lastHostLog! | find /I "USER_REGISTERED">>!logFile!
            echo.
            echo ^(you can modify users list later in the setup process^)
            pause
        )

       :3rdPartySoftware

        REM : if no file found
        if [!lastHostLog!] == ["NONE"] goto:eof

        echo -------------------------------------------------
        echo Try to keep 3rd party software defined in last installation
        echo using !lastHostLog:"=!
        echo.

        for /F "tokens=2 delims=~@" %%j in ('type !lastHostLog! ^| find "TO_BE_LAUNCHED" 2^> NUL') do (

            set "command=%%j"
            call:isSoftwareValid "!command!" program valid

            if !valid! EQU 1 (
                echo ^> !command:'=!

                type !lastHostLog! | find "TO_BE_LAUNCHED">>!logFile!
            )
        )
        echo.
        echo ^(you can modify this list later in the setup process^)
        echo -------------------------------------------------
        pause
    goto:eof

    REM : function that resolve environnemnt variable (such as %GAMES_FOLDER%)
    REM : and try to repaired paths where only the drive letter has changed
    :resolveVenv
        set "value="%~1""
        set "resolved=%value:"=%"

        REM : check if value is a path
        echo %resolved% | find ":" > NUL 2>&1 && (
            REM : check if it is only a device letter issue (in case of portable library)
            set "tmpStr='!drive!%resolved:~3%"

            set "newLocation=!tmpStr:'="!"
            if exist !newLocation! set "resolved=!tmpStr!"
        )

        set "%2=!resolved!"
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to check if a 3rd party software exist or can be patched (resolveEnv)
    :isSoftwareValid

        set "fc="%~1""

        for /F "delims=~" %%k in (!fc!) do call:resolveVenv "%%k" command

        set "program="NONE""
        set "firstArg="NONE""

        REM : resolve venv for search
        for /F "tokens=1 delims=~'" %%k in ("!command!") do set "program="%%k""
        for /F "tokens=3 delims=~'" %%k in ("!command!") do set "firstArg="%%k""

        set "%2=!program!"

        if exist !program! set /A "%3=1" & goto:eof

        set /A "%3=0"

    goto:eof

