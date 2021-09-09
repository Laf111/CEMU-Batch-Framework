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
        echo ERROR Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_PATH=!SCRIPT_FOLDER:\"="!"
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""
    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    if %nbArgs% EQU 0 !cmdOw! @ /MAX > NUL 2>&1

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    if not exist !BFW_LOGS! mkdir !BFW_LOGS! > NUL 2>&1

    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    set "imgConverter="!BFW_RESOURCES_PATH:"=!\convert.exe""
    set "quick_Any2Ico="!BFW_RESOURCES_PATH:"=!\quick_Any2Ico.exe""
    set "xmlS="!BFW_RESOURCES_PATH:"=!\xml.exe""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

REM    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""

    REM : check if folder name contains forbiden character for batch file
    call:securePathForDos !GAMES_FOLDER! SAFE_PATH

    if not [!GAMES_FOLDER!] == [!SAFE_PATH!] (
        echo ERROR ^: please rename your folders to have this compatible path
        echo !SAFE_PATH!
        pause
        exit 95
    )

    REM : set current char codeset
    call:setCharSet

    if not exist !logFile! (
        echo You have to launch the setup before this script ^^! launching setup^.bat
        set "setup="!BFW_PATH:"=!\setup.bat""
        wscript /nologo !Start! !setup!
        timeout /t 4 > NUL 2>&1
        exit 51
    )

    set "USERSLIST="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSLIST=%%i !USERSLIST!"
        set /A "nbUsers+=1"
    )
    if ["!USERSLIST!"] == [""] (
        echo You have to launch the setup before this script ^^! launching setup^.bat
        set "setup="!BFW_PATH:"=!\setup.bat""
        wscript /nologo !Start! !setup!
        timeout /t 4 > NUL 2>&1
        exit 51
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : Intel legacy options
    set "argLeg="

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    if %nbArgs% NEQ 0 goto:getArgsValue

    title Create CEMU^'s shortcuts for selected games

    REM : rename folders that contains forbiden characters : & ! . ( )
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!GAMES_FOLDER! /REPLACECI^:^^!^: /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /REPLACECI^:^^(^:[ /REPLACECI^:^^)^:] /EXECUTE

    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    REM : rename GFX folders that contains forbiden characters : & ! . ( )
    wscript /nologo !StartHidden! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /REPLACECI^:^^(^:[ /REPLACECI^:^^)^:] /EXECUTE

    REM : check if DLC and update folders are presents (some games need to be prepared)
    call:checkGamesToBePrepared

    echo Checking for update ^.^.^.
    REM : update BatchFw
    set "ubw="!BFW_TOOLS_PATH:"=!\updateBatchFw.bat""
    call !ubw!
    set /A "cr=!ERRORLEVEL!"
    if !cr! EQU 0 (
        echo BatchFw updated^, please relaunch
        set "ChangeLog="!BFW_PATH:"=!\Change.log""
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !ChangeLog!
        timeout /t 4 > NUL 2>&1
        exit 75
    )
    timeout /t 1 > NUL 2>&1
    cls
    echo Please select CEMU install folder

    :askCemuFolder
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

    set "folder=NOT_FOUND"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create " 2^>NUL') do set "folder=%%i"
    if ["!folder!"] == ["NOT_FOUND"] goto:askOutputFolder
    set "OUTPUT_FOLDER="!folder:\Wii-U Games=!""

    REM : if called with shortcut, OUTPUT_FOLDER already set, goto:inputsAvailables
    if not [!OUTPUT_FOLDER!] == [!BFW_PATH!] goto:inputsAvailables

    :askOutputFolder
    echo Please define where to create shortcuts ^(a Wii-U Games subfolder will be created^)
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
    goto:inputsAvailables

    :getArgsValue

    if %nbArgs% GTR 5 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" CEMU_FOLDER OUTPUT_FOLDER -noImport^* -ignorePrecomp^* -no^/Legacy^*
        echo ^(^* for optional^ argument^)
        echo given {%*}
        pause
        exit /b 9
    )

    if %nbArgs% LSS 2 (
        echo ERROR on arguments passed ^^!
        echo SYNTAX^: "!THIS_SCRIPT!" CEMU_FOLDER OUTPUT_FOLDER -noImport^* -ignorePrecomp^* -no^/Legacy^*
        echo ^(^* for optional^ argument^)
        echo given {%*}
        pause
        exit /b 99
    )

    if %nbArgs% EQU 2 goto:getCemuFolder

    REM : flag for ignoring precompiled cache
    set "IGNORE_PRECOMP=DISABLED"
    REM : flag for automatic import
    set "IMPORT_MODE=ENABLED"

    if [!args[2]!] == ["-noImport"] set "IMPORT_MODE=DISABLED"
    if [!args[2]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"

    if [!args[2]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[2]!] == ["-Legacy"] set "argLeg=-Legacy"

    if %nbArgs% EQU 3 goto:getCemuFolder

    if [!args[3]!] == ["-noImport"] set "IMPORT_MODE=DISABLED"
    if [!args[3]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"

    if [!args[3]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[3]!] == ["-Legacy"] set "argLeg=-Legacy"

    if %nbArgs% EQU 4 goto:getCemuFolder

    if [!args[4]!] == ["-noImport"] set "IMPORT_MODE=DISABLED"
    if [!args[4]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"

    if [!args[4]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[4]!] == ["-Legacy"] set "argLeg=-Legacy"


    :getCemuFolder
    REM : get and check CEMU_FOLDER
    set CEMU_FOLDER=!args[0]!
    if not exist !CEMU_FOLDER! (
        echo ERROR CEMU folder !CEMU_FOLDER! does not exist ^^!
        pause
        exit /b 1
    )

    REM : get OUTPUT_FOLDER
    set OUTPUT_FOLDER=!args[1]!
    if not exist !OUTPUT_FOLDER! (
        echo ERROR Shortcuts folder !OUTPUT_FOLDER! does not exist ^^!
        pause
        exit /b 2
    )
    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    REM : clean log files specific to a launch
    set "tobeDeleted="!BFW_PATH:"=!\logs\fnr_*.*""
    del /F /S !tobeDeleted!  > NUL 2>&1
    set "tobeDeleted="!BFW_PATH:"=!\logs\jnust_*.*""
    del /F /S !tobeDeleted!  > NUL 2>&1
    set "tobeDeleted="!BFW_PATH:"=!\logs\fnr""
    rmdir /Q /S !tobeDeleted!  > NUL 2>&1

    cls
    REM : check if folder name contains forbidden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !BFW_PATH!
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo Please rename !BFW_PATH:"=! to be DOS compatible ^^!^, exiting
        pause
        exit /b 3
    )

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"

    REM : CEMU's log file
    set "clog="!CEMU_FOLDER:"=!\log.txt""

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
        echo exiting
        pause
        exit /b 77
    )

    echo !versionRead! | findStr /R "^[0-9]*\.[0-9]*\.[0-9]*[a-z]*.$" > NUL 2>&1 && goto:versionOK

    echo versionRead=!versionRead!
    echo ERROR^: BatchFw can^'t get CEMU^'s version^.
    echo This version seems to be not supported.
    echo exiting
    pause
    exit /b 78

    :versionOK

    set /A "treatAllGames=0"

    if !QUIET_MODE! EQU 1 goto:bfwShortcuts
    REM : when launched with shortcut = no args = QUIET_MODE=0

    choice /C yn /N /M "Do you want to create shortcuts for ALL your games (y, n = select games)? : "
    if !ERRORLEVEL! EQU 1 (
        set /A "QUIET_MODE=1"
        set /A "treatAllGames=1"
    )

    cls
    REM : update graphic packs
    set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
    call !ugp! -silent
    set /A "cr=!ERRORLEVEL!"
    echo ---------------------------------------------------------

    if !cr! NEQ 0 (
        echo ERROR Graphics packs folder update failed^!
    )
    cls
    echo =========================================================
    echo Creating CEMU !versionRead! shortcuts
    echo =========================================================


    REM : if not exist logFile goto:bfwShortcuts
    if not exist !logFile! goto:bfwShortcuts

    REM : check if this version, was already installed
    REM : if already installed but its path is invalid : clear logFile

    REM : search in logFile, getting only the last occurence
    set "previousPath=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find !CEMU_FOLDER! 2^>NUL') do (
        set "previousPath=%%i"
    )
    if ["!previousPath!"] == ["NONE"] (

        goto:bfwShortcuts
    )
    REM : a path was found, if not exist : flush logHostFile for CEMU_FOLDER_NAME
    if not exist "!previousPath!" call:cleanHostLogFile !CEMU_FOLDER_NAME!

    :bfwShortcuts

    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if !QUIET_MODE! EQU 0 (
        echo Creating own shortcuts
    )

    call:fwShortcuts

    REM : importing CEMU VERSION controller profiles under !GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles
    call:syncControllerProfiles
    echo ---------------------------------------------------------
    echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!\ControllerProfiles vs _BatchFW_Controller_Profiles^)
    if !QUIET_MODE! EQU 1 goto:openCemuAFirstTime

    echo ---------------------------------------------------------
    REM : flush logFile of SCREEN_MODE
    call:cleanHostLogFile SCREEN_MODE

    choice /C yn /N /M "Do you want to launch CEMU in fullscreen (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:openCemuAFirstTime

    set "msg="SCREEN_MODE=windowed""
    call:log2HostFile !msg!

    :openCemuAFirstTime
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
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
    set /A "v1151=1"
    set /A "v114=1"
    set /A "v1116=1"

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

    REM : version < 1.14
    call:compareVersions !versionRead! "1.11.6" v1116 > NUL 2>&1
    if ["!v1116!"] == [""] echo Error when comparing versions
    if !v1116! EQU 50 echo Error when comparing versions
    if !v1116! EQU 2 (
        echo ERROR this version is not supported by BatchFw
        echo ^(only versions ^>= 1^.11^.6^)
        pause
        exit /b 99
    )
    REM : 1.14 > version >= 1.11.6

    set "gfxv2="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""
    if exist !gfxv2! goto:checkCemuHook

    mkdir !gfxv2! > NUL 2>&1
    set "rarFile="!BFW_RESOURCES_PATH:"=!\V2_GFX_Packs.rar""

    echo ---------------------------------------------------------
    echo graphic pack V2 are needed for this version^, extracting^.^.^.

    wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !gfxv2! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo ERROR while extracting V2_GFX_Packs^, exit 21
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
    if !v1251! LEQ 1 goto:autoImportMode

    REM : check if sharedFonts were downloaded
    set "sharedFonts="!CEMU_FOLDER:"=!\sharedFonts""
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
    if exist !sharedFonts! goto:autoImportMode
    echo Installing sharedFonts^.^.^.
    set "rarFile="!BFW_RESOURCES_PATH:"=!\sharedFonts.rar""
    wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !CEMU_FOLDER! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo WARNING ^: while extracting sharedFonts
        pause
    )
    timeout /T 3 > NUL 2>&1

    :autoImportMode

    echo ---------------------------------------------------------
    REM : importMode
    set "IMPORT_MODE=ENABLED"
REM    call:getUserInput "Disable automatic settings import? (y,n : default in 10sec): " "n,y" ANSWER 10
REM    if [!ANSWER!] == ["y"] set "IMPORT_MODE=DISABLED"
REM
REM    set "msg="!CEMU_FOLDER_NAME! installed with automatic import=!IMPORT_MODE:"=!""
REM    call:log2HostFile !msg!


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

    set "IGNORE_PRECOMP=DISABLED"
    REM : GPU is NVIDIA => ignoring precompiled shaders cache
    if ["!gpuType!"] == ["NVIDIA"] set "IGNORE_PRECOMP=ENABLED"

    set "msg="!CEMU_FOLDER_NAME:"=! install with ignoring precompiled shader cache=!IGNORE_PRECOMP:"=!""
    call:log2HostFile !msg!

    if !QUIET_MODE! EQU 1 goto:scanGamesFolder

    REM : check if main GPU is iGPU. Ask for -nolegacy if it is the case
    set "noIntel=!GPU_VENDOR:Intel=!"
    if ["!gpuType!"] == ["OTHER"] if not ["!noIntel!"] == ["!GPU_VENDOR!"] (

        REM : CEMU < 1.15.1
        if !v1151! LEQ 1 (
            call:getUserInput "Disable all Intel GPU workarounds (add -NoLegacy)? (y,n): " "n,y" ANSWER
            if [!ANSWER!] == ["n"] goto:scanGamesFolder
            set "argOpt=%argOpt% -noLegacy"
            goto:scanGamesFolder
        )
        REM : CEMU >= 1.15.1
        if !v1151! EQU 0 (
            call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y,n): " "n,y" ANSWER
            if [!ANSWER!] == ["n"] goto:scanGamesFolder
            set "argOpt=%argOpt% -Legacy"
            goto:scanGamesFolder
        )
        if !v1151! EQU 2 (
            call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y,n): " "n,y" ANSWER
            if [!ANSWER!] == ["n"] goto:scanGamesFolder
            set "argOpt=%argOpt% -Legacy"
            goto:scanGamesFolder
        )
    )

    :scanGamesFolder

    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder_cs.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        echo =========================================================
        echo ERROR Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        echo List of game^'s folder^(s^)^:
        echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        echo ---------------------------------------------------------
        echo Fix-it by removing characters here replaced in the folder^'s name by^?
        echo Exiting until you rename or move those folders
        echo =========================================================
        pause
    )
    if !QUIET_MODE! EQU 0 cls
    echo =========================================================
    echo Creating !CEMU_FOLDER_NAME! shortcuts for your games^.^.^.
    if !QUIET_MODE! EQU 0 echo =========================================================

    if !QUIET_MODE! EQU 0 (
        REM : clean BFW_LOGS
        pushd !BFW_LOGS!
        for /F "delims=~" %%i in ('dir /B /S /A:D 2^> NUL') do rmdir /Q /S "%%i" > NUL 2>&1
        for /F "delims=~" %%i in ('dir /B /S /A:L 2^> NUL') do rmdir /Q /S "%%i" > NUL 2>&1
    )
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : temporary game library log file (updated here to remove uninstalled games data)
    set "glogFileNew="!BFW_PATH:"=!\logs\gamesLibrary.new""
    del /F /S !glogFileNew! > NUL 2>&1

    set /A "NB_GAMES_TREATED=0"
    set /A "NB_OUTPUTS=0"

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
            if !cr! EQU 1 goto:scanGamesFolder

            call:gameShortcut

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
            set "str=!str:\.=!"
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
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise the game will be ignored^!
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    REM : if not called from the setup.bat
    if !QUIET_MODE! EQU 0 (
        type !glogFileNew! | sort > !glogFile!
        del /F /S !glogFileNew! > NUL 2>&1
    )

    if !QUIET_MODE! EQU 1 if !treatAllGames! EQU 0 goto:log
    echo =========================================================

    echo Treated !NB_GAMES_TREATED! games
    if !nbUsers! GTR 1 echo Created !NB_OUTPUTS! shortcuts

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo BatchFw share a common GFX packs folder with all versions
    echo of CEMU ^(installed in your game library as _BatchFw_Graphic_Packs^)
    echo do not use the update feature in CEMU but the provided scripts^.
    echo.
    echo Same remark concerning the auto update feature of CEMU UI^:
    echo The point of BatchFw is to install the both versions ^(previous and
    echo current^) before removing the previous one if the last one runs all
    echo your games without any issue.
    echo ---------------------------------------------------------
    if !treatAllGames! EQU 0 pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo If you want to change global CEMU^'s settings you^'ve just
    echo entered here^:
    echo ---------------------------------------------------------
    echo ^> simply delete the shortcuts and recreate them using
    echo Wii-U Games^\Create CEMU^'s shortcuts for selected games^.lnk
    echo to register a SINGLE version of CEMU
    echo ---------------------------------------------------------
    if !treatAllGames! EQU 0 pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo If you encounter any issues or have made a mistake when
    echo collecting settings for a game^:
    echo ---------------------------------------------------------
    echo ^> delete the settings saved for !CEMU_FOLDER_NAME! using
    echo the shortcut in Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!
    echo Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    echo ---------------------------------------------------------
    if !treatAllGames! EQU 0 pause
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo This windows will close automatically in 15s
    echo     ^(n^)^: don^'t close^, i want to read history log first
    echo     ^(q^)^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM Waiting before exiting
        pause
    )

    :log
    REM : log to host log file
    set "msg="!CEMU_FOLDER_NAME! install folder path=!CEMU_FOLDER:"=!""
    call:log2HostFile !msg!

    if !NB_GAMES_TREATED! NEQ 0 (
        set "msg="Create shortcuts for !CEMU_FOLDER_NAME! with import mode !IMPORT_MODE! in=!OUTPUT_FOLDER:"=!\Wii-U Games""
        call:log2HostFile !msg!
    )
    echo =========================================================
    if !QUIET_MODE! EQU 0 echo Waiting the end of all child processes before ending^.^.^.

    call:waitProcessesEnd

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

    :waitProcessesEnd

        set /A "disp=0"
        :waitingLoopProcesses
        wmic process get Commandline 2>NUL | find ".exe" | find  /I "_BatchFW_Install" | find /I /V "wmic" | find /I "rar.exe" | find /I /V "winRar" |find /I /V "find" > NUL 2>&1 && (
            if !disp! EQU 0 (
                set /A "disp=1"
                echo Still extracting V2 GFX packs^, please wait ^.^.^.
            )
            goto:waitingLoopProcesses
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

        REM : calling createShortcuts.bat
        set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importGames.bat""
        call !tobeLaunch! !GAMES_FOLDER!
        set /A "cr=!ERRORLEVEL!"

        echo ^> Games ready for emulation
        timeout /T 5 > NUL 2>&1
        cls

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

    :cleanHostLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.bfw_tmp""
        if exist !logFileTmp! (
            del /F !logFile! > NUL 2>&1
            move /Y !logFileTmp! !logFile! > NUL 2>&1
        )
        if exist !logFileTmp! (
            del /F !logFile! > NUL 2>&1
            move /Y !logFileTmp! !logFile! > NUL 2>&1
        )

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL 2>&1
        move /Y !logFileTmp! !logFile! > NUL 2>&1

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
            if not exist !bcpf! robocopy !ccp! !CONTROLLER_PROFILE_FOLDER! "%%x" /MT:32 /XF "controller*.*" > NUL 2>&1
        )

        :batchFwToCemu
        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !ccpf! robocopy !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" /MT:32 > NUL 2>&1
        )
        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------

    :createFolder
        set "folder="%~1""
        if not exist !folder! mkdir !folder! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to create a shortcut for this CEMU version
    :shortcut

        set "TARGET_PATH="%~1""
        set "LINK_PATH="%~2""
        set "LINK_DESCRIPTION="%~3""
        set "ICO_PATH="%~4""
        set "WD_PATH="%~5""

        if not exist !TARGET_PATH! goto:eof

        set "TMP_VBS_FILE="!TEMP!\RACC_!DATE!.vbs""

        REM : create object
        echo set oWS = WScript^.CreateObject^("WScript.Shell"^) >> !TMP_VBS_FILE!
        echo sLinkFile = !LINK_PATH! >> !TMP_VBS_FILE!
        echo set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = !TARGET_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        if not [!ICO_PATH!] == ["NONE"] echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        if not [!ARGS!] == ["NONE"] (
            set "secureArgs=!ARGS:|=^|!"
            echo oLink^.Arguments = "!secureArgs!" >> !TMP_VBS_FILE!
        )
        if not [!WD_PATH!] == ["NONE"] echo oLink^.WorkingDirectory = !WD_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        if !ERRORLEVEL! EQU 0 (
            del /F !TMP_VBS_FILE! > NUL 2>&1
        ) else (
            echo ERROR^: in !TMP_VBS_FILE!
            pause
            del /F !TMP_VBS_FILE! > NUL 2>&1
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :resolveVenv
        set "value="%~1""
        set "resolved=%value:"=%"

        REM : check if value is a path
        echo %resolved% | find ":" > NUL && (
            REM : check if it is only a device letter issue (in case of portable library)
            set "tmpStr='!drive!%resolved:~3%"
            set "newLocation=!tmpStr:'="!"
            if exist !newLocation! set "resolved=!tmpStr!"
        )

        set "%2=!resolved!"
    goto:eof
    REM : ------------------------------------------------------------------

    :fwShortcuts

        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's icons""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Mlc01 folder handling""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's data""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\BatchFw^'s packs""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's icons""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Games Compatibility Reports""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Games Compatibility""
        call:createFolder !subfolder!

        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME:"=!""
        call:createFolder !subfolder!

        set "subfolder="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!""
        call:createFolder !subfolder!

        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U""
        call:createFolder !subfolder!

        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files""
        call:createFolder !subfolder!
        
        set "ARGS="NONE""

        REM : create shortcut for 3rd party software
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\3rdParty""
        for /F "tokens=2 delims=~@" %%i in ('type !logFile! ^| find /I "TO_BE_LAUNCHED" 2^>NUL') do (

            if not exist !subfolder! call:createFolder !subfolder!

            set "command=%%i"
            for /F "tokens=* delims=~" %%j in ("!command!") do call:resolveVenv "%%j" command

            set "program="NONE""

            REM : resolve venv for search
            for /F "tokens=1 delims=~'" %%j in ("!command!") do set "program="%%j""
            for /F "delims=~" %%i in (!program!) do set "name=%%~nxi"

            for %%a in (!program!) do set "parentFolder="%%~dpa""
            set "WD_FOLDER=!parentFolder:~0,-2!""

            REM : create a shortcut (if needed)
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\3rdParty\!name:.exe=.lnk!""
            set "LINK_DESCRIPTION="!name:.exe=!""
            set "TARGET_PATH=!program!"
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\!name:.exe=.ico!""
            if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to !name:.exe=!
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !WD_FOLDER!
            )
        )

        REM : create a shortcut to WinSCP
        set "WD_FOLDER="!BFW_RESOURCES_PATH:"=!\winSCP""
        set "TARGET_PATH="!WD_FOLDER:"=!\WinSCP.exe""
        for /F "delims=~" %%i in (!TARGET_PATH!) do set "name=%%~nxi"

        set "icoFile=!name:.exe=.ico!"
        set "ICO_PATH="!BFW_RESOURCES_PATH:"=!\icons\!icoFile!""
        if not exist !ICO_PATH! call !quick_Any2Ico! "-res=!TARGET_PATH:"=!" "-icon=!ICO_PATH:"=!" -formats=512

        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\WinSCP^.lnk""
        set "LINK_DESCRIPTION="FTP to Wii-U using WinSCP""

        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to WinSCP
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !WD_FOLDER!
        )

        REM : create a shortcut to scanWiiU.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Scan my Wii-U^.lnk""
        set "LINK_DESCRIPTION="Take snapshot of your Wii-U content ^(list games^, saves^, updates and DLC^)""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\scanWiiU.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\wii-u.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to scanWiiU^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to Wii-U error codes (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Wii-U error codes^.lnk""
        set "LINK_DESCRIPTION="Wii-U errors code list""
        set "TARGET_PATH="!BFW_PATH:"=!\doc\Wii U Error Codes.rtf""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wii-U Error Codes.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to Wii-U error codes documentation
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "scansFolder="!GAMES_FOLDER:"=!\_BatchFw_WiiU\Scans""
        if exist !scansFolder! (
            REM : create a shortcut to explore scans saved
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Scans results^.lnk""
            set "LINK_DESCRIPTION="Explore existing Wii-U scan results""
            set "TARGET_PATH=!scansFolder!"
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\scanResults.ico""

            if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to access to Wii-U scans results
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
            )
        )

        REM : create a shortcut to getWiiuOnlineFiles.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Get online files^, update accounts from my Wii-U^.lnk""
        set "LINK_DESCRIPTION="Download all necessary files to play online with CEMU and update your accounts""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\getWiiuOnlineFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\online.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to getWiiuOnlineFiles^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to setWiiuAccountToUsers.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Associate users to wii-u accounts^.lnk""
        set "LINK_DESCRIPTION="Associate BatchFw^'s user to your Wii-U accounts""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\setWiiuAccountToUsers.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\WiiU-user.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to setWiiuAccountToUsers^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to dumpGamesFromWiiu.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Dump games from my Wii-U^.lnk""
        set "LINK_DESCRIPTION="Dump games installed on your Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\dumpGamesFromWiiu.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\download.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to dumpGamesFromWiiu^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to injectGamesToWiiu.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Inject games to my Wii-U^.lnk""
        set "LINK_DESCRIPTION="Inject eShop games to my Wii-U (you'll need to finish the installations using NUSspli)""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\injectGamesToWiiu.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\upload.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to injectGamesToWiiu^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to createWiiuSDcard.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Create a SDCard for Wii-U^.lnk""
        set "LINK_DESCRIPTION="Format and prepare a SDCard for your Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\createWiiuSDcard.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\sdcard.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to createWiiuSDcard^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to exportSavesToWiiu.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Export CEMU saves to my Wii-U^.lnk""
        set "LINK_DESCRIPTION="Export CEMU saves to your Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\exportSavesToWiiu.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exportSave.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to exportSavesToWiiu^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importWiiuSaves.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Import saves from my Wii-U^.lnk""
        set "LINK_DESCRIPTION="Import saves from my Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importWiiuSaves.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importSave.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to importWiiuSaves^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to compressAndUninstall.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Compress and uninstall games^.lnk""
        set "LINK_DESCRIPTION="Backup then uninstall games""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\compressAndUninstall.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\compress.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to compressAndUninstall^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS=ON"
        REM : create a shortcut to ftpSetWiiuFirmwareUpdateMode.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Enable firmware update on the Wii-U^.lnk""
        set "LINK_DESCRIPTION="Enable firmware update on the Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\ftpSetWiiuFirmwareUpdateMode.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\WiiUfwuOn.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to enabling firmware update on the Wii-U
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )
        REM : create a shortcut to displayProgressBar.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Enable BatchFw^'s progress bar^.lnk""
        set "LINK_DESCRIPTION="Enable BatchFw^'s progress bar""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\displayProgressBar.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\enableProgressBar.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to enable progress bar
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS=OFF"
        REM : create a shortcut to ftpSetWiiuFirmwareUpdateMode.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Disable firmware update on the Wii-U^.lnk""
        set "LINK_DESCRIPTION="Disable firmware update on the Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\ftpSetWiiuFirmwareUpdateMode.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\WiiUfwuOff.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to disabling firmware update on the Wii-U
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )
        REM : create a shortcut to displayProgressBar.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Disable BatchFw^'s progress bar^.lnk""
        set "LINK_DESCRIPTION="Disable BatchFw^'s progress bar""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\displayProgressBar.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\disableProgressBar.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to disable progress bar
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS="NONE""

        REM : create a shortcut to downloadGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Download games^.lnk""
        set "LINK_DESCRIPTION="Download Wii-U titles for CEMU or your Wii-U using JNUSTool""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\downloadGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\downloadGames.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to downloadGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to updateGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Update games^.lnk""
        set "LINK_DESCRIPTION="Update Games using JNUSTool""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\updateGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\updateGames.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to updateGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to progressBar.bat (if needed)
        set "LINK_PATH="!BFW_RESOURCES_PATH:"=!\progressBar^.lnk""
        set "LINK_DESCRIPTION="Link to progressBar""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\progressBar.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\BatchFw.ico""
        if not exist !LINK_PATH! (
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to syncGamesFolder.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Synchronize with another BatchFw^'s install^.lnk""
        set "LINK_DESCRIPTION="Synchronize with another BatchFw's install (saves, caches, games stats)""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\syncGamesFolder.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\syncGamesFolder.ico""
        if not exist !LINK_PATH! (
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to convertIconsForAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's icons\Convert all jpg files to centered icons^.lnk""
        set "LINK_DESCRIPTION="Convert all jpg files find in the Cemu subfolder of the game's folder, to centered icon in order to be used by createShortcuts.bat""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertIconsForAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\convertIconsForAllGames.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to convertIconsForAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to copyMlc01DataForAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\mlc01 folder handling\Copy mlc01 data for each games^.lnk""
        set "LINK_DESCRIPTION="Copy mlc01 data ^(saves+updates+DLC^) in each game^'s folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\copyMlc01DataForAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\copyMlc01DataForAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to copyMlc01DataForAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to moveMlc01DataForAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\mlc01 folder handling\Move mlc01 data for each games^.lnk""
        set "LINK_DESCRIPTION="Move mlc01 data ^(saves+updates+DLC^) in each game^'s folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\moveMlc01DataForAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\moveMlc01DataForAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to moveMlc01DataForAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to restoreMlc01DataForAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\mlc01 folder handling\Restore mlc01 data for each games^.lnk""
        set "LINK_DESCRIPTION="Restore mlc01 data ^(saves+updates+DLC^) of each game^'s folder in a mlc01 target folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreMlc01DataForAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreMlc01DataForAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to restoreMlc01DataForAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to restoreUserSavesOfAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Restore user's saves for selected games^.lnk""
        set "LINK_DESCRIPTION="Restore user^'s saves for selected games in a mlc01 target folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreUserSavesOfAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreUserSavesOfAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to restoreUserSavesOfAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to exportAllToCemu.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Export all games data to a CEMU folder^.lnk""
        set "LINK_DESCRIPTION="Move updates, DLC transferable cache and extract all saves to a CEMU target folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\exportAllToCemu.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exportAllToCemu.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to exportAllToCemu^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to backupAllInGameSaves.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Backup my games's saves^.lnk""
        set "LINK_DESCRIPTION="Compress all my games^'s saves""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\backupAllInGameSaves.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\backupAllInGameSaves.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to backupAllInGameSaves^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to deleteAllInGameSavesBackup.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Delete all my games's saves backup^.lnk""
        set "LINK_DESCRIPTION="Delete my games^'s saves backup for all my games""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteAllInGameSavesBackup.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteAllInGameSavesBackup.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to deleteAllInGameSavesBackup^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importSaves.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Import saves^.lnk""
        set "LINK_DESCRIPTION="Import saves from a mlc01 folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importSaves.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importSaves.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to importSaves^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to getTitleDataFromLibrary.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's data\Get game data with titleId^.lnk""
        set "LINK_DESCRIPTION="Get game data using its titleId from WiiU-Titles-Library^.csv""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\getTitleDataFromLibrary.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\getTitleDataFromLibrary.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to getTitleDataFromLibrary^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importTransferableCache.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Import transferable cache^.lnk""
        set "LINK_DESCRIPTION="Import transferable cache for a game""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importTransferableCache.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importTransferableCache.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to importTransferableCache^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to deleteMyGpuCache.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Flush my GPU shaders caches^.lnk""
        set "LINK_DESCRIPTION="Empty my GPU shaders caches""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteMyGpuCache.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteMyGpuCache.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to deleteMyGpuCache^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to wipeTracesOnHost.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wipe all traces on !USERDOMAIN!^.lnk""
        set "LINK_DESCRIPTION="Wipe all traces on host !USERDOMAIN!""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\wipeTracesOnHost.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\wipe.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to wipeTracesOnHost^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to getMyShaderCachesSize.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Get my shaders caches size^.lnk""
        set "LINK_DESCRIPTION="Get my shaders caches size for all CEMU versions""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\getMyShaderCachesSize.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\getMyShaderCachesSize.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to getMyShaderCachesSize^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to restoreTransShadersForAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Restore transferable cache for each games^.lnk""
        set "LINK_DESCRIPTION="Restore transferable cache of each game^'s folder in CEMU target folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreTransShadersForAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreTransShadersForAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to restoreTransShadersForAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to createGameGraphicPacks.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\Create Graphic Packs for a game using its titleId^.lnk""
        set "LINK_DESCRIPTION="Create Graphic Packs for a game using its titleId""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\createGameGraphicPacks.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\createGameGraphicPacks.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to createGameGraphicPacks^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to forceGraphicPackUpdate.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\Force GFX packs folder update^.lnk""
        set "LINK_DESCRIPTION="Force a graphic packs folder update""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\forceGraphicPackUpdate.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\forceGraphicPackUpdate.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to forceGraphicPackUpdate^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to buildExtraGraphicPacks.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\Create GFX packs and complete presets for all my games^.lnk""
        set "LINK_DESCRIPTION="Create GFX packs and complete presets for games installed""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\buildExtraGraphicPacks.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\buildExtraGraphicPacks.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to buildExtraGraphicPacks^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to reports folder
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Games Compatibility Reports\!USERDOMAIN! reports^.lnk""
        set "LINK_DESCRIPTION="Games^'s compatibility reports generated on !USERDOMAIN!""
        set "TARGET_PATH="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!""
        set "ICO_PATH="NONE""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to !USERDOMAIN! compatibility reports folder
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_PATH!
        )

        REM : create a shortcut to BatchFW_readme.txt (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\BatchFw_readme^.lnk""
        set "LINK_DESCRIPTION="BatchFW_readme.txt""
        set "TARGET_PATH="!BFW_PATH:"=!\BatchFw_readme.txt""
        set "ICO_PATH="NONE""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to BatchFW_readme^.txt
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_PATH!
        )

        REM : create a shortcut to fixBrokenShortcuts
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Fix broken shortcuts^.lnk""
        set "LINK_DESCRIPTION="Fix broken shortcuts after the drive letter changed or moving your games^'library""
        set "TARGET_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shortcuts\fixBrokenShortcuts.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\fixBrokenShortcuts.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to fixBrokenShortcuts.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! "!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shortcuts"
        )

        REM : create a shortcut to this script (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Create CEMU's shortcuts for selected games^.lnk""
        set "LINK_DESCRIPTION="Create missing CEMU^'s shortcuts for selected games given a version of CEMU""
        set "TARGET_PATH="!THIS_SCRIPT!""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\createShortcuts.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to this script
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to importGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Import games with updates and DLC^.lnk""
        set "LINK_DESCRIPTION="Import games with updates and DLC and prepare them to emulation""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to importGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to restoreBfwDefaultSettings.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Reset BatchFw^.lnk""
        set "LINK_DESCRIPTION="Restore BatchFw factory settings""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreBfwDefaultSettings.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreBfwDefaultSettings.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to restoreBfwDefaultSettings^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to killBatchFw.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Kill BatchFw Processes^.lnk""
        set "LINK_DESCRIPTION="Kill all BatchFw processes""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\killBatchFw.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\kill.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to killBatchFw^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to createExecutables.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Create CEMU's executables for selected games^.lnk""
        set "LINK_DESCRIPTION="Create missing CEMU^'s executables for selected games given a version of CEMU""
        set "TARGET_PATH="!BFW_PATH:"=!\createExecutables.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\createExecutables.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to createExecutables^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to updateGraphicPacksFolder.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Update my graphic packs to latest^.lnk""
        set "LINK_DESCRIPTION="Update _BatchFW_Graphic_Packs folder to latest release""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\updateGraphicPacksFolder.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to updateGraphicPacksFolder^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importModsForAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Import mods for my games^.lnk""
        set "LINK_DESCRIPTION="Search and import mods folder into game^'s one""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importModsForAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importModsForAllGames.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to importModsForAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        for /F "tokens=2 delims=~=" %%a in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "ARGS=%%a"

            mkdir "!OUTPUT_FOLDER:"=!\Wii-U Games\!ARGS:"=!" > NUL 2>&1

            REM : create a shortcut to displayGamesStats.bat (if needed)
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\!ARGS:"=!\_BatchFw - display games stats^.lnk""
            set "LINK_DESCRIPTION="Display the golbal games^'stats for !ARGS:"=!""
            set "TARGET_PATH="!BFW_PATH:"=!\tools\displayGamesStats.bat""
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\displayGamesStats.ico""
            if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to displayGamesStats^.bat for !ARGS:"=!
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
            )

            REM : create a shortcut to exportUserGamesStatsToCemu.bat (if needed)
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\!ARGS:"=!\_BatchFw - export !ARGS:"=! games^'stats in a CEMU install^.lnk""
            set "LINK_DESCRIPTION="Export !ARGS:"=! games^'stats in a CEMU install""
            set "TARGET_PATH="!BFW_PATH:"=!\tools\exportUserGamesStatsToCemu.bat""
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exportUserGamesStatsToCemu.ico""
            if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to exportUserGamesStatsToCemu^.bat for !ARGS:"=!
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
            )

            REM : create a shortcut to setExtraSavesSlots.bat
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\!ARGS:"=!\_BatchFw - set extra slots saves^.lnk""
            set "LINK_DESCRIPTION="Manage !ARGS:"=!^'s extra saves slots""
            set "TARGET_PATH="!BFW_PATH:"=!\tools\setExtraSavesSlots.bat""
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\saveSlots.ico""
            if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 echo Creating a shortcut to setExtraSavesSlots^.bat
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
            )
        )
        set "ARGS=ALL"

        REM : create a shortcut to deleteBatchFwGraphicPacks.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\BatchFw^'s packs\Delete all GFX packs created by BatchFw^.lnk""
        set "LINK_DESCRIPTION="Delete all GFX packs created by BatchFw""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteBatchFwGraphicPacks.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\delete.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to deleteBatchFwGraphicPacks^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "ARGS="!OUTPUT_FOLDER!""

        REM : create a shortcut to setup.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Set BatchFw settings and register CEMU installs^.lnk""
        set "LINK_DESCRIPTION="Create missing CEMU^'s shortcuts for ALL my games and many versions of CEMU^, set BatchFw settings""
        set "TARGET_PATH="!BFW_PATH:"=!\setup.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\setup.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to setup^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS=""!OUTPUT_FOLDER:"=!\Wii-U Games"""

        REM : create a shortcut to uninstall.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Uninstall BatchFW^.lnk""
        set "LINK_DESCRIPTION="Uninstall BatchFW""
        set "TARGET_PATH="!BFW_PATH:"=!\uninstall.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\uninstall.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to uninstall^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS=""!USERDOMAIN!"""

        REM : create a shortcut to deleteAllMySettings.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Delete all my CEMU^'s settings^.lnk""
        set "LINK_DESCRIPTION="Delete all my CEMU^'s settings saved""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteAllMySettings.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteAllMySettings.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to deleteAllMySettings^.bat for all CEMU^'s versions
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "ARGS=""!USERDOMAIN!"" ""!CEMU_FOLDER_NAME!"""

        REM : create a shortcut to deleteAllMySettings.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Delete all my !CEMU_FOLDER_NAME!'s settings^.lnk""
        set "LINK_DESCRIPTION="Delete my settings saved for !CEMU_FOLDER_NAME!""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteAllMySettings.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteAllMySettings.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to deleteAllMySettings^.bat for !CEMU_FOLDER_NAME!^'s versions
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "ARGS=/C for /F ""delims=~"" %%i in ('dir /B /A:D ""!OUTPUT_FOLDER:"=!\Wii-U Games"" ^| find /V ""CEMU"" ^| find /V ""BatchFw"" ^| find /V ""Wii-U"" ^| find /V ""3rdParty""') do for /F ""delims=~"" %%j in ('dir /B ""!OUTPUT_FOLDER:"=!\Wii-U Games\%%i"" ^| find /I ""!CEMU_FOLDER_NAME!""') do del /F ""!OUTPUT_FOLDER:"=!\Wii-U Games\%%i\%%j"""

        REM : create a shortcut to delete games shortcuts for !CEMU_FOLDER_NAME!
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Delete all my !CEMU_FOLDER_NAME!'s games shortcuts^.lnk""
        set "LINK_DESCRIPTION="Delete all my games shortcuts created for !CEMU_FOLDER_NAME!""
        set "TARGET_PATH=c:\Windows\System32\cmd.exe"

        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteGamesShortcuts.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to delete !CEMU_FOLDER_NAME!^'s shortcuts
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! "c:\Windows\System32"
        )

        set "ARGS=1"
        REM : create a shortcut for Converting WUX to WUD
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUX to WUD^.lnk""
        set "LINK_DESCRIPTION="Convert WUX to WUD""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wux2Wud.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUX to WUD
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        set "ARGS=2"
        REM : create a shortcut for Converting WUX to WUP
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUX to WUP^.lnk""
        set "LINK_DESCRIPTION="Convert WUX to WUP""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wux2Wup.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUX to WUP
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        set "ARGS=3"
        REM : create a shortcut for Converting WUX to RPX
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUX to RPX^.lnk""
        set "LINK_DESCRIPTION="Convert WUX to RPX""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wux2Rpx.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUX to RPX
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        set "ARGS=4"
        REM : create a shortcut for Converting WUD to WUX
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUD to WUX^.lnk""
        set "LINK_DESCRIPTION="Convert WUD to WUX""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wud2Wux.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUD to WUX
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        set "ARGS=5"
        REM : create a shortcut for Converting WUD to WUP
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUD to WUP^.lnk""
        set "LINK_DESCRIPTION="Convert WUD to WUP""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wud2Wup.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUD to WUP
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        set "ARGS=6"
        REM : create a shortcut for Converting WUD to RPX
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUD to RPX^.lnk""
        set "LINK_DESCRIPTION="Convert WUD to RPX""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wud2Rpx.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUD to RPX
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        set "ARGS=7"
        REM : create a shortcut for Converting WUP to RPX
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Convert Wii-U files\Convert WUP to RPX^.lnk""
        set "LINK_DESCRIPTION="Convert WUP to RPX""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertWiiuFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\Wup2Rpx.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut for converting WUP to RPX
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        
        set "ARGS="NONE""

        REM : search your current GLCache
        REM : check last path saved in log file
        REM : search in logFile, getting only the last occurence

        set "OPENGL_CACHE="NOT_FOUND""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"

        if not [!OPENGL_CACHE!] == ["NOT_FOUND"] if exist !OPENGL_CACHE! goto:glCacheFound

        REM : else search it
        pushd "%LOCALAPPDATA%"
        set "cache="NOT_FOUND""
        for /F "delims=~" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
        if [!cache!] == ["NOT_FOUND"] pushd "%APPDATA%" && for /F "delims=~" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
        if not [!cache!] == ["NOT_FOUND"] set "OPENGL_CACHE=!cache!"
        pushd !BFW_TOOLS_PATH!

        if [!OPENGL_CACHE!] == ["NOT_FOUND"] goto:eof

        REM : save path to log file
        set "msg="OPENGL_CACHE=!OPENGL_CACHE:"=!""
        call:log2HostFile !msg!

        REM : openGL cache location
        :glCacheFound
        set "GLCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuGLCache!"

        REM : create a shortcut to explore OpenGL Cache saved
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Explore OpenGL caches saved^.lnk""
        set "LINK_DESCRIPTION="Explore OpenGL shader caches backup""
        set "TARGET_PATH=!GLCacheSavesFolder!"
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exploreOpenGLCacheSaves.ico""

        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to access to OpenGL caches saves
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "VkCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuVkCache!"
        if not exist !VkCacheSavesFolder! mkdir !VkCacheSavesFolder! > NUL 2>&1

        REM : create a shortcut to explore Vulkan Cache saved
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Explore Vulkan caches saved^.lnk""
        set "LINK_DESCRIPTION="Explore Vulkan shader caches saved""
        set "TARGET_PATH=!VkCacheSavesFolder!"
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exploreOpenGLCacheSaves.ico""

        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 echo Creating a shortcut to access to Vulkan caches saves
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
    goto:eof

    REM : fucntion to created shortcut to delete BatchFw's packs for this game
    :createDeletePacksShorcut

        REM : add a shortcut for deleting all packs created by BatchFw for thsi game
        set "shortcutFolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\BatchFw^'s packs""
        if not exist !shortcutFolder! mkdir !shortcutFolder! > NUL 2>&1

        set "shortcut="!shortcutFolder:"=!\Force rebuilding !GAME_TITLE! packs.lnk""
        if exist !shortcut! goto:eof

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\delete_!GAME_TITLE!_GfxPacks_!DATE!.vbs""

        set "ARGS=!titleId!"

        set "LINK_DESCRIPTION="Delete !GAME_TITLE!'s packs created by BatchFw""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !shortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!

        set "TARGET_PATH="!BFW_TOOLS_PATH:"=!\deleteBatchFwGraphicPacks.bat""

        echo oLink^.TargetPath = !TARGET_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Arguments = "!ARGS!" >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !BFW_TOOLS_PATH! >> !TMP_VBS_FILE!

        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to create a shortcut for a game
    :gameShortcut

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

        REM : path to meta.xml file
        set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
        if not exist !META_FILE! goto:searchIco

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:searchIco

        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

        REM : get game's title from wii-u database file
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!titleId!';"') do set "libFileLine="%%i""

        REM : strip line to get data
        for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
           set "titleIdRead=%%a"
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
        REM : this string is the one used to name BatchFw gfx packs
        set "gfxPackGameTitle=%Desc: =%"

        REM : extract gfxPackGameTitle data and fill to the updated file
        if !QUIET_MODE! EQU 0 type !gLogFile! | find "!gfxPackGameTitle!" >> !gLogFileNew!

        :searchIco

        REM : icon dl flag
        set "icoUpdate=false"

        REM : looking for ico file close to rpx file
        set "ICO_PATH="NONE""
        set "ICO_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\00050000*.ico""
        for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL' ) do set "ICO_FILE="%%i""

        REM : if no icon file found, using cemu.exe icon
        if [!ICO_FILE!] == ["NONE"] (
            REM : search if exists in !BFW_PATH!\resources\gamesIcon using WiiU-Titles-Library.csv Ico file Id
            call:getIcon

            if not [!ICO_PATH!] == ["NONE"] goto:icoSet

            REM : else using cemu.exe icon
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\noIconFound.ico""
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            echo No icons found for !GAME_TITLE!

            if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
                echo Download a jpg box-art in !GAME_FOLDER_PATH:"=!\Cemu
                echo ^(no need to rename it^) then use the shortcut
                echo Wii-U Games^\_BatchFw^\Tools^\Games^'s icons^\Convert all jpg files to centered icons^.lnk
                goto:icoSet
            )
            echo.
            echo Opening up a google search^.^.^.
            REM : open a google search
            wscript /nologo !StartWait! "%windir%\explorer.exe" "https://www.google.com/search?q=!GAME_TITLE!+Wii-U+jpg+box+art&source=lnms&tbm=isch&sa=X"
            echo Save a jpg box-art in !GAME_FOLDER_PATH:"=!\Cemu
            echo ^(no need to rename it^)
            pause

            REM : create icon for this game
            set "tobeLaunch="!BFW_PATH:"=!\tools\convertIconsForAllGames.bat""
            wscript /nologo !StartHiddenWait! !tobeLaunch! !GAME_FOLDER_PATH!

            set "icoUpdate=true"

            call:getIcon
        ) else (
            set "ICO_PATH="!GAME_FOLDER_PATH:"=!\Cemu\!ICO_FILE:"=!""
        )

        :icoSet
        set /A "gameDisplayed=0"

        set /A "previousNumber=!NB_OUTPUTS!"
        REM : create shortcuts for all users
        for /F "tokens=2 delims=~=" %%a in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%a""
            set "userFolder="!OUTPUT_FOLDER:"=!\wii-U Games\!user:"=!""
            set "SHORCTUT_PATH="!userFolder:"=!\!GAME_TITLE:"=! [!CEMU_FOLDER_NAME!!argLeg!]^.lnk""

            if ["%icoUpdate%"] == ["true"] if exist !SHORCTUT_PATH! del /F !SHORCTUT_PATH! > NUL 2>&1

            REM : if shortcut exist and import mode enabled : if shortcut exist skip this game
            if exist !SHORCTUT_PATH! (
                if !QUIET_MODE! EQU 0 echo ---------------------------------------------------------
                if !QUIET_MODE! EQU 0 echo !GAME_TITLE! ^: shortcut for !user:"=! already exists^, skipped
            ) else (
                call:userGameShortcut !user!
            )
        )

        if !NB_OUTPUTS! NEQ !previousNumber! set /A "NB_GAMES_TREATED+=1"

    goto:eof
    REM : ------------------------------------------------------------------

    :userGameShortcut
        set "user="%~1""

        REM : Creating shortcut to launch game
        if !QUIET_MODE! EQU 0 if !gameDisplayed! EQU 0 (

            REM : asking for associating the current game with this CEMU VERSION
            echo =========================================================
            echo - !GAME_TITLE! ^(%nativeHeight%p @ %nativeFps%FPS^)
            echo ---------------------------------------------------------
            echo.
            echo Create a shortcut for !GAME_TITLE! using !CEMU_FOLDER!^?
            echo   ^(n^)^: skip^, not associating this game with !CEMU_FOLDER_NAME!
            echo   ^(y^)^: default value after 15s timeout
            echo.

            call:getUserInput "Enter your choice? : " "y,n" ANSWER 15
            if [!ANSWER!] == ["n"] (
                REM : skip this game
                echo Skip this GAME
                set /A "gameDisplayed=2"
                goto:eof
            )
        )
        if !gameDisplayed! EQU 0 set /A "gameDisplayed=1"

        REM : first user already skipped the game
        if !gameDisplayed! EQU 2 goto:eof

        call:createFolder !userFolder!

        REM : set mlc01 path
        set "MLC01_FOLDER_PATH="!GAME_FOLDER_PATH:"=!\mlc01""
        if not exist !MLC01_FOLDER_PATH! (

            REM : create mlc01 in game's folder
            set "sysFolder="!GAME_FOLDER_PATH:"=!\mlc01\sys\title\0005001b\10056000\content""
            call:createFolder !sysFolder!
            set "saveFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\save\00050000\%titleId:00050000=%""
            call:createFolder !saveFolder!
            set "dlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c\%titleId:00050000=%""
            call:createFolder !dlcFolder!
            set "updateFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000e\%titleId:00050000=%""
            call:createFolder !updateFolder!

            REM : first game's registration : create mods folder
            set "subfolder="!GAME_FOLDER_PATH:"=!\Cemu\mods""
            call:createFolder !subfolder!
        )

        REM : arguments for LaunchGame.bat
        set "launchGame="!BFW_TOOLS_PATH:"=!\launchGame.bat""
        set "ARGS="!launchGame!" "!CEMU_FOLDER!" "!GAME_FILE_PATH!" "!OUTPUT_FOLDER!" "!ICO_PATH!" "!MLC01_FOLDER_PATH!" !user:"=!"

        if ["!IMPORT_MODE!"] == ["ENABLED"] goto:ignorePrecomp
        set "ARGS=!ARGS! -noImport"

        :ignorePrecomp
        if ["!IGNORE_PRECOMP!"] == ["DISABLED"] goto:noLegacyFlag
        set "ARGS=!ARGS! -ignorePrecomp"

        :noLegacyFlag
        set "ARGS=!ARGS! %argLeg%"

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_!DATE!.vbs""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !SHORCTUT_PATH! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
REM        echo oLink^.TargetPath = !StartMaximizedWait! >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = !StartHiddenWait! >> !TMP_VBS_FILE!
        echo oLink^.WindowStyle = 7 >> !TMP_VBS_FILE!
        echo oLink^.Arguments = "!ARGS!" >> !TMP_VBS_FILE!
        echo oLink^.Description = "Launch !GAME_TITLE! with !CEMU_FOLDER_NAME!" >> !TMP_VBS_FILE!
        echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !OUTPUT_FOLDER! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        if !ERRORLEVEL! EQU 0 del /F  !TMP_VBS_FILE!

        if !QUIET_MODE! EQU 0 echo - Shortcut for !user:"=! created ^!

        REM : create a shorcut to delete packs created for this games
        call:createDeletePacksShorcut

        set /A "NB_OUTPUTS+=1"
    goto:eof
    REM : ------------------------------------------------------------------

    :getIcon

        set "TGA_FILE="!GAME_FOLDER_PATH:"=!\meta\iconTex.tga""
        if not exist !TGA_FILE! goto:searchIconDataBase

        set "CemuSubFolder="!GAME_FOLDER_PATH:"=!\Cemu""
        if not exist !CemuSubFolder! mkdir !CemuSubFolder! > NUL 2>&1
        set "ICO_PATH="!CemuSubFolder:"=!\%titleId%.ico""
        REM : convert-it in ICO centered format
        call !imgConverter! !TGA_FILE! -resize 256x256 !ICO_PATH!

        goto:eof

        :searchIconDataBase
        REM : check if !BFW_PATH!\resources\gamesIcon\%titleId%.ico exist
        set "icoBase="!BFW_PATH:"=!\resources\gamesIcons""
        set "icoBaseFile="!icoBase:"=!\%titleId%.ico""
        if exist !icoBaseFile! (
            set "titleIdIco=%titleId%"
            goto:copyIcoFile
        )

        REM : get information on game using WiiU Library File
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';"') do set "libFileLine="%%i""

        REM : add-it to the library
        if [!libFileLine!] == ["NONE"] goto:eof

        REM : strip line to get data
        for /F "tokens=1-10 delims=;" %%a in (!libFileLine!) do (
           set "titleId=%%a"
           set "desc=%%b"
           set "productCode=%%c"
           set "companyCode=%%d"
           set "notes=%%e"
           set "versions=%%f"
           set "region=%%g"
           set "acdn=%%h"
           set "icoId=%%i"
        )
        set "titleId=%titleId:'=%"
        set "titleIdIco=%icoId:'=%"

        REM : check if !BFW_PATH!\resources\gamesIcons\%titleIdIco%.ico exist

        set "icoBaseFile="!BFW_PATH:"=!\resources\gamesIcons\%titleIdIco%.ico""
        if not exist !icoBaseFile! goto:eof

        :copyIcoFile
        REM : copy and renaming the ico file
        set "newLocation="!GAME_FOLDER_PATH:"=!\Cemu""
        robocopy !icoBase! !newLocation! "%titleIdIco%.ico" > NUL 2>&1

        set "oldIcoGameFile="!newLocation:"=!\%titleIdIco%.ico""
        set "newIcoGameFile="!newLocation:"=!\!titleId!.ico""
        move /Y !oldIcoGameFile! !newIcoGameFile! > NUL 2>&1
        set "ICO_PATH=!newIcoGameFile!"
    goto:eof

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
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
