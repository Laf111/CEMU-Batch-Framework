@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathforDos "!THIS_SCRIPT!" > NUL 2>&1
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

    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    set "imgConverter="!BFW_RESOURCES_PATH:"=!\convert.exe""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharset

    set "USERSLIST="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSLIST=%%i !USERSLIST!"
        set /A "nbUsers+=1"
    )
    if ["!USERSLIST!"] == [""] (
        @echo You have to use the setup before this script ^^! launching setup^.bat
        set "setup="!BFW_PATH:"=!\setup.bat""
        wscript /nologo !Start! !setup!
        timeout /t 4 > NUL 2>&1
        exit 51
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

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
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : Intel legacy options
    set "argLeg="

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    if %nbArgs% NEQ 0 goto:getArgsValue

    title Create CEMU executables for selected games

    REM : rename folders that contains forbiden characters : & ! .
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!GAMES_FOLDER! /REPLACECI^:^^!^: /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE

    REM : check if DLC and update folders are presents (some games need to be prepared)
    call:checkGamesToBePrepared

    @echo Checking for update ^.^.^.
    REM : update BatchFw
    set "ubw="!BFW_TOOLS_PATH:"=!\updateBatchFw.bat""
    call !ubw!
    set /A "cr=!ERRORLEVEL!"
    if !cr! EQU 0 (
        @echo BatchFw updated^, please relaunch
        set "ChangeLog="!BFW_PATH:"=!\Change.log""
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !ChangeLog!
        timeout /t 4 > NUL 2>&1
        exit 75
    )

    cls
    @echo Please select CEMU install folder

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
        @echo Path to !CEMU_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askCemuFolder
    )

    REM : check that cemu.exe exist in
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe" "
    if /I not exist !cemuExe! (
        @echo ERROR^, No Cemu^.exe file found under !CEMU_FOLDER! ^^!
        goto:askCemuFolder
    )


    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set "OUTPUT_FOLDER="%%i""
    set "OUTPUT_FOLDER=!OUTPUT_FOLDER:\Wii-U Games=!"

    REM : if called with shortcut, OUTPUT_FOLDER already set, goto:inputsAvailables
    if not [!OUTPUT_FOLDER!] == [!BFW_PATH!] goto:inputsAvailables

    @echo Please define where to create shortcuts ^(a Wii-U Games subfolder will be created^)
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
        @echo Path to !OUTPUT_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askOutputFolder
    )

    goto:inputsAvailables

    :getArgsValue
    if %nbArgs% GTR 5 (
        @echo ERROR on arguments passed ^(%nbArgs%^)
        @echo SYNTAX^: "!THIS_SCRIPT!" CEMU_FOLDER OUTPUT_FOLDER -noImport^* -ignorePrecomp^* -no^/Legacy^*
        @echo ^(^* for optional^ argument^)
        @echo given {%*}
        pause
        exit /b 9
    )

    if %nbArgs% LSS 2 (
        @echo ERROR on arguments passed ^^!
        @echo SYNTAX^: "!THIS_SCRIPT!" CEMU_FOLDER OUTPUT_FOLDER -noImport^* -ignorePrecomp^* -no^/Legacy^*
        @echo ^(^* for optional^ argument^)
        @echo given {%*}
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
        @echo ERROR CEMU folder !CEMU_FOLDER! does not exist ^^!
        pause
        exit /b 1
    )

    REM : get OUTPUT_FOLDER
    set OUTPUT_FOLDER=!args[1]!
    if not exist !OUTPUT_FOLDER! (
        @echo ERROR Executables folder !OUTPUT_FOLDER! does not exist ^^!
        pause
        exit /b 2
    )
    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

    cls
    REM : check if folder name contains forbidden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !BFW_PATH!
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo Please rename !BFW_PATH:"=! to be DOS compatible ^^!^, exiting
        pause
        exit /b 3
    )

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"

    if !QUIET_MODE! EQU 1 goto:bfwShortcuts
    REM : when launched with shortcut = no args = QUIET_MODE=0
    cls
    REM : update graphic packs
    set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
    call !ugp! -silent
    set /A "cr=!ERRORLEVEL!"
    @echo ---------------------------------------------------------

    if !cr! NEQ 0 (
        @echo ERROR Graphics packs folder update failed^!
    )
    cls
    @echo =========================================================
    @echo Creating CEMU executables
    @echo =========================================================


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
    set "defaultBrowser="NOT_FOUND""
    for /F "tokens=1 delims==" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        for /f "delims=Z tokens=2" %%a in ('reg query "HKEY_CURRENT_USER\Software\Clients\StartMenuInternet" /s 2^>NUL ^| findStr /ri ".exe""$"') do set "defaultBrowser=%%a"
        if [!defaultBrowser!] == ["NOT_FOUND"] for /f "delims=Z tokens=2" %%a in ('reg query "HKEY_LOCAL_MACHINE\Software\Clients\StartMenuInternet" /s 2^>NUL ^| findStr /ri ".exe""$"') do set "defaultBrowser=%%a"
    )

    if !QUIET_MODE! EQU 0 (
        @echo Creating own shortcuts
    )

    call:fwShortcuts

    REM : importing CEMU VERSION controller profiles under !GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles\!USERDOMAIN!
    call:syncControllerProfiles
    @echo ---------------------------------------------------------
    @echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!\ControllerProfiles vs _BatchFW_Controller_Profiles\!USERDOMAIN!^)
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder

    @echo ---------------------------------------------------------
    REM : flush logFile of SCREEN_MODE
    call:cleanHostLogFile SCREEN_MODE

    choice /C yn /N /M "Do you want to launch CEMU in fullscreen (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:checkInstall

    set "msg="SCREEN_MODE=windowed""
    call:log2HostFile !msg!

    :checkInstall

    REM : check if CemuHook is installed
    set "dllFile="!CEMU_FOLDER:"=!\keystone.dll""

    :checkCemuHook
    if exist !dllFile! goto:checkSharedFonts
    @echo ---------------------------------------------------------
    @echo CemuHook was not found^. It is required to
    @echo - play videos
    @echo - enable FPS^+^+ packs
    @echo - enable controller motion sensors
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        @echo No active connection was found^, unable to open "https://cemuhook.sshnuke.net/#Downloads"
        goto:openCemuAFirstTime
    )
    if [!defaultBrowser!] == ["NOT_FOUND"] goto:openCemuAFirstTime

    @echo Opening CemuHook download page^.^.^.
    @echo Download and extract CemuHook in !CEMU_FOLDER!

    wscript /nologo !Start! !defaultBrowser! "https://cemuhook.sshnuke.net/#Downloads"

    timeout /T 2 > NUL 2>&1
    wscript /nologo !Start! "%windir%\explorer.exe" !CEMU_FOLDER!

    choice /C y /N /M "If CemuHook is installed, continue? (y) : "
    goto:checkCemuHook

    :checkSharedFonts

    REM : check if sharedFonts were downloaded
    set "sharedFonts="!CEMU_FOLDER:"=!\sharedFonts""
    if exist !sharedFonts! goto:getCemuVersion

    :openCemuAFirstTime

    @echo ---------------------------------------------------------
    @echo Opening CEMU^.^.^.
    @echo set your REGION^,language
    @echo Download sharedFonts using Cemuhook button^, if they are missing
    @echo Then close CEMU to continue

    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
    wscript /nologo !StartWait! !cemu!

    :getCemuVersion
    set "clog="!CEMU_FOLDER:"=!\log.txt""
    set /A "post1151=1"
    if not exist !clog! goto:openCemuAFirstTime

    set "version=NOT_FOUND"
    for /f "tokens=1-6" %%a in ('type !clog! ^| find "Init Cemu"') do set "version=%%e"

    if ["%version%"] == ["NOT_FOUND"] goto:extractV2Packs

    call:compareVersions %version% "1.15.1" result
    if !result! EQU 50 echo Error when comparing versions
    if !result! EQU 2 set /A "post1151=0"

    call:compareVersions %version% "1.14.0" result
    if !result! EQU 50 echo Error when comparing versions
    if !result! EQU 1 goto:autoImportMode
    if !result! EQU 0 goto:autoImportMode

    :extractV2Packs
    set "gfxv2="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""
    if exist !gfxv2! goto:autoImportMode

    mkdir !gfxv2! > NUL 2>&1
    set "rarFile="!BFW_RESOURCES_PATH:"=!\V2_GFX_Packs.rar""

    @echo ---------------------------------------------------------
    @echo graphic pack V2 are needed for this version^, extracting^.^.^.

    wscript /nologo !StartHidden! !rarExe! x -o+ -inul !rarFile! !gfxv2! > NUL 2>&1
    set /A cr=!ERRORLEVEL!
    if !cr! GTR 1 (
        @echo ERROR while extracting V2_GFX_Packs, exiting 1
        pause
        exit /b 21
    )
    timeout /T 3 > NUL 2>&1
   :autoImportMode
    @echo ---------------------------------------------------------
    REM : importMode
    set "IMPORT_MODE=ENABLED"
    call:getUserInput "Disable automatic settings import? (y,n : default in 5sec): " "n,y" ANSWER 5
    if [!ANSWER!] == ["y"] set "IMPORT_MODE=DISABLED"

    set "msg="!CEMU_FOLDER_NAME! installed with automatic import=!IMPORT_MODE:"=!""
    call:log2HostFile !msg!

    REM : get GPU_VENDOR
    set "GPU_VENDOR=NOT_FOUND"
    set "gpuType=OTHER"
    for /F "tokens=2 delims==" %%i in ('wmic path Win32_VideoController get Name /value ^| find "="') do (
        set "string=%%i"
        echo "!string!" | find /I "NVIDIA" > NUL 2>&1 (
            set "gpuType=NVIDIA"
            set "GPU_VENDOR=!string: =!"
        )
        echo "!string!" | find /I "AMD" > NUL 2>&1 (
            set "gpuType=AMD"
            set "GPU_VENDOR=!string: =!"
        )
    )
    if ["!GPU_VENDOR!"] == ["NOT_FOUND"] set "GPU_VENDOR=!string: =!"

    call:secureStringPathForDos !GPU_VENDOR! GPU_VENDOR

    set "IGNORE_PRECOMP=DISABLED"
    REM : GPU is NVIDIA => ignoring precompiled shaders cache
    if ["!gpuType!"] == ["NVIDIA"] set "IGNORE_PRECOMP=ENABLED"

    set "msg="!CEMU_FOLDER_NAME:"=! install with ignoring precompiled shader cache=!IGNORE_PRECOMP:"=!""
    call:log2HostFile !msg!

    REM : check if main GPU is iGPU. Ask for -nolegacy if it is the case
    set "noIntel=!GPU_VENDOR:Intel=!"
    if ["!gpuType!"] == ["OTHER"] if not ["!noIntel!"] == ["!GPU_VENDOR!"] (

        @echo ---------------------------------------------------------
        REM : CEMU < 1.15.1
        if %post1151% EQU 0 (
            call:getUserInput "Disable all Intel GPU workarounds (add -NoLegacy)? (y, n) : " "n,y" ANSWER
            if [!ANSWER!] == ["n"] goto:scanGamesFolder
            set "argLeg=-noLegacy"
            goto:scanGamesFolder
        )
        REM : CEMU >= 1.15.1
        if %post1151% EQU 1 (
            call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y, n) : " "n,y" ANSWER
            if [!ANSWER!] == ["n"] goto:scanGamesFolder
            set "argLeg=-Legacy"
            goto:scanGamesFolder
        )
    )

    :scanGamesFolder

    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        @echo =========================================================
        @echo ERROR Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        @echo List of game^'s folder^(s^)^:
        @echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        @echo ---------------------------------------------------------
        @echo Fix-it by removing characters here replaced in the folder^'s name by^?
        @echo Exiting until you rename or move those folders
        @echo =========================================================
        pause
    )
    cls
    REM : temporary batch files folder
    set "launchersFolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\ExeLaunchers""
    call:createFolder !launchersFolder!

    @echo =========================================================
    @echo Creating !CEMU_FOLDER_NAME! executables for your games ^:
    @echo =========================================================

    set /A NB_GAMES_TREATED=0

    REM : loop on game's code folders found
    for /F "delims=~" %%i in ('dir /b /o:n /a:d /s code ^| findStr /R "\\code$" ^| find /I /V "\aoc" ^| find /I /V "\mlc01" 2^>NUL') do (

        set "codeFullPath="%%i""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : check path
        call:checkPathforDos !GAME_FOLDER_PATH! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 0 (
            REM : check if folder name contains forbiden character for batch file
            set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
            call !tobeLaunch! !GAME_FOLDER_PATH!
            set /A "cr=!ERRORLEVEL!"
            if !cr! GTR 1 @echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:gameExecutable

        ) else (

            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            @echo !folderName!^: Unsupported characters found^, rename it otherwise it will be ignored by BatchFW ^^!
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

            call:getUserInput "Renaming folder for you? (y, n) : " "y,n" ANSWER

            if [!ANSWER!] == ["y"] move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise the game will be ignored^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )
    rmdir /S /Q  !launchersFolder! > NUL 2>&1


    if !QUIET_MODE! EQU 1 goto:log
    @echo =========================================================

    if !NB_GAMES_TREATED! NEQ 0 call:divfloat2int "!NB_GAMES_TREATED!.0" "!nbUsers!.0" 1 result && set /A "NB_GAMES_TREATED=!result!"

    @echo Treated !NB_GAMES_TREATED! games

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo If you want to change global CEMU^'s settings you^'ve just
    @echo entered here^:
    @echo ---------------------------------------------------------
    @echo ^> simply delete the shortcuts and recreate them using
    @echo Wii-U Games^\Create CEMU^'s shortcuts for selected games^.lnk
    @echo to register a SINGLE version of CEMU
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo If you encounter any issues or have made a mistake when
    @echo collecting settings for a game^:
    @echo ---------------------------------------------------------
    @echo ^> delete the settings saved for !CEMU_FOLDER_NAME! using
    @echo the shortcut in Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!
    @echo Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo This windows will close automatically in 15s
    @echo     ^(n^)^: don^'t close^, i want to read history log first
    @echo     ^(q^)^: close it now and quit
    @echo ---------------------------------------------------------
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
        set "msg="Create executables for !CEMU_FOLDER_NAME! with import mode !IMPORT_MODE! in =!OUTPUT_FOLDER:"=!\Wii-U Games""
        call:log2HostFile !msg!
    )
    @echo =========================================================
    if !QUIET_MODE! EQU 0 @echo Waiting the end of all child processes before ending^.^.^.

    if %nbArgs% EQU 0 endlocal
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : check if (DLC) or (UPDATE DATA) folders exist
   :checkGamesToBePrepared

        REM : already pushed to GAMES_FOLDER
        set /A "needImport=0"

        set "pat=*(DLC)*"
        for /F %%i in ('dir /A:d /B !pat! 2^>NUL') do set /A "needImport=1"
        set "pat=*(UPDATE DATA)*"
        for /F %%i in ('dir /A:d /B !pat! 2^>NUL') do set /A "needImport=1"

        REM : if need call import script and wait
        if !needImport! EQU 0 goto:eof

        @echo Hum^.^.^. some DLC and UPDATE DATA folders were found
        @echo Preparing those games for emulation^.^.^.
        timeout /T 5 > NUL 2>&1

        REM : calling createShortcuts.bat
        set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importGames.bat""
        call !tobeLaunch! !GAMES_FOLDER!
        set /A "cr=!ERRORLEVEL!"

        @echo ^> Games ready for emulation
        timeout /T 5 > NUL 2>&1
        cls

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureStringPathforDos

        set "str=%~1"
        set "str=!str:&=!"
        set "str=!str:?=!"
        set "str=!str:(=!"
        set "str=!str:)=!"
        set "str=!str:%%=!"
        set "str=!str:^=!"
        set "str=!str:"=!"
        set "%2=!str!"

    goto:eof

    :cleanHostLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.tmp""

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL 2>&1
        move /Y !logFileTmp! !logFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles\!USERDOMAIN!""
        if not exist !CONTROLLER_PROFILE_FOLDER! mkdir !CONTROLLER_PROFILE_FOLDER! > NUL 2>&1

        set "ccp="!CEMU_FOLDER:"=!\ControllerProfiles""
        if not exist !ccp! goto:eof

        pushd !ccp!
        REM : import from CEMU_FOLDER to CONTROLLER_PROFILE_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !bcpf! robocopy !ccp! !CONTROLLER_PROFILE_FOLDER! "%%x" /XF "controller*.*" > NUL 2>&1
        )

        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !ccpf! robocopy !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" > NUL 2>&1
        )
        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------

    :createFolder
        set "folder="%~1""
        if not exist !folder! mkdir !folder! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to create a executable for these CEMU version
    :shortcut

        set "TARGET_PATH="%~1""
        set "LINK_PATH="%~2""
        set "LINK_DESCRIPTION="%~3""
        set "ICO_PATH="%~4""
        set "WD_PATH="%~5""

        set "TMP_VBS_FILE="!TEMP!\RACC_!DATE!.vbs""

        REM : create object
        echo set oWS = WScript.CreateObject("WScript.Shell") >> !TMP_VBS_FILE!
        echo sLinkFile = !LINK_PATH! >> !TMP_VBS_FILE!
        echo set oLink = oWS.createShortCut(sLinkFile) >> !TMP_VBS_FILE!
        echo oLink.TargetPath = !TARGET_PATH! >> !TMP_VBS_FILE!
        echo oLink.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        if not [!ICO_PATH!] == ["NONE"] echo oLink.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        if not [!ARGS!] == ["NONE"] echo oLink.Arguments = "!ARGS!" >> !TMP_VBS_FILE!
        echo oLink.WorkingDirectory = !WD_PATH! >> !TMP_VBS_FILE!
        echo oLink.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!
        if !ERRORLEVEL! EQU 0 del /F !TMP_VBS_FILE!

    goto:eof
    REM : ------------------------------------------------------------------

    :resolveVenv
        set "value="%~1""
        set "%2=%value%"
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
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's icons""
        call:createFolder !subfolder!
        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Games Compatibility Reports""
        call:createFolder !subfolder!

        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME:"=!""
        call:createFolder !subfolder!

        set "subfolder="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!""
        call:createFolder !subfolder!

        set "subfolder="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U""
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
            for /F "tokens=1 delims=~'" %%j in (!command!) do set "program="%%j""
            for /F "delims=~" %%i in (!program!) do set "name=%%~nxi"

            for %%a in (!program!) do set "parentFolder="%%~dpa""
            set "WD_FOLDER=!parentFolder:~0,-2!""

            REM : create a shortcut (if needed)
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\3rdParty\!name:.exe=.lnk!""
            set "LINK_DESCRIPTION="!name:.exe=!""
            set "TARGET_PATH=!program!"
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\!name:.exe=.ico!""
            if not exist !LINK_PATH! (
                    if !QUIET_MODE! EQU 0 @echo Creating a shortcut to !name:.exe=!
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !WD_FOLDER!
            )
        )

        REM : create a shortcut to scanWiiU.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Scan my Wii-U.lnk""
        set "LINK_DESCRIPTION="Take snapshot of your Wii-U content ^(list games^, saves^, updates and DLC^)""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\scanWiiU.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\wii-u.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to scanWiiU^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "scansFolder="!GAMES_FOLDER:"=!\_BatchFw_WiiU\Scans""
        if exist !scansFolder! (
            REM : create a shortcut to explore scans saved
            set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Scans results.lnk""
            set "LINK_DESCRIPTION="Explore existing Wii-U scan results""
            set "TARGET_PATH=!scansFolder!"
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\scanResults.ico""

            if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to access to Wii-I scans results
                call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
            )
        )

        REM : create a shortcut to getWiiuOnlineFiles.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Get online files.lnk""
        set "LINK_DESCRIPTION="Download all necessary files to play online with CEMU""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\getWiiuOnlineFiles.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\online.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to getWiiuOnlineFiles^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to setWiiuAccountToUsers.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Associate users to wii-u accounts.lnk""
        set "LINK_DESCRIPTION="Associate BatchFw^'s user to your Wii-U accounts""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\setWiiuAccountToUsers.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\WiiU-user.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to setWiiuAccountToUsers^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to dumpGamesFromWiiu.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Dump games from my Wii-U.lnk""
        set "LINK_DESCRIPTION="Dump games installed on your Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\dumpGamesFromWiiu.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\ftp.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to dumpGamesFromWiiu^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to createWiiuSDcard.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Create a SDCard for Wii-U.lnk""
        set "LINK_DESCRIPTION="format and prepare a SDCard for your Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\createWiiuSDcard.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\sdcard.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to createWiiuSDcard^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to exportSavesToWiiu.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Export CEMU saves to my Wii-U.lnk""
        set "LINK_DESCRIPTION="Export CEMU saves to your Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\exportSavesToWiiu.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exportSave.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to exportSavesToWiiu^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importWiiuSaves.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Wii-U\Import saves from my Wii-U.lnk""
        set "LINK_DESCRIPTION="Import saves from my Wii-U""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importWiiuSaves.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importSave.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to importWiiuSaves^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
        	
        REM : create a shortcut to convertIconsforAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's icons\Convert all jpg files to centered icons.lnk""
        set "LINK_DESCRIPTION="Convert all jpg files near rpx ones to centered icon in order to be used by createExecutables.bat""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\convertIconsforAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\convertIconsforAllGames.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to convertIconsforAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to copyMlc01DataforAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\mlc01 folder handling\Copy mlc01 data for each games.lnk""
        set "LINK_DESCRIPTION="Copy mlc01 data ^(saves+updates+DLC^) in each game^'s folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\copyMlc01DataforAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\copyMlc01DataforAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to copyMlc01DataforAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to moveMlc01DataforAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\mlc01 folder handling\Move mlc01 data for each games.lnk""
        set "LINK_DESCRIPTION="Move mlc01 data ^(saves+updates+DLC^) in each game^'s folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\moveMlc01DataforAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\moveMlc01DataforAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to moveMlc01DataforAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to restoreMlc01DataforAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\mlc01 folder handling\Restore mlc01 data for each games.lnk""
        set "LINK_DESCRIPTION="Restore mlc01 data ^(saves+updates+DLC^) of each game^'s folder in a mlc01 target folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreMlc01DataforAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreMlc01DataforAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to restoreMlc01DataforAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to backupAllInGameSaves.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Backup my games's saves.lnk""
        set "LINK_DESCRIPTION="Compress all my games^'s saves""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\backupAllInGameSaves.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\backupAllInGameSaves.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to backupAllInGameSaves^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to deleteAllInGameSavesBackup.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Delete all my games's saves backup.lnk""
        set "LINK_DESCRIPTION="Delete my games^'s saves backup for all my games""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteAllInGameSavesBackup.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteAllInGameSavesBackup.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to deleteAllInGameSavesBackup^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importSaves.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's saves\Import saves.lnk""
        set "LINK_DESCRIPTION="Import saves from a mlc01 folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importSaves.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importSaves.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to importSaves^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to getTitleDataFromLibrary.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Games's data\Get GAME data with titleId.lnk""
        set "LINK_DESCRIPTION="Get GAME data with titleId from WiiU-Titles-Library^.csv""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\getTitleDataFromLibrary.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\getTitleDataFromLibrary.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to getTitleDataFromLibrary^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importTransferableCache.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Import transferable cache.lnk""
        set "LINK_DESCRIPTION="Import transferable cache for a game""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importTransferableCache.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importTransferableCache.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to importTransferableCache^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to deleteMyGpuCache.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Flush my GPU OpenGL cache.lnk""
        set "LINK_DESCRIPTION="Empty my GPU OpenGL cache""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteMyGpuCache.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteMyGpuCache.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to deleteMyGpuCache^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to getMyShaderCachesSize.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Get my shaders caches size.lnk""
        set "LINK_DESCRIPTION="Get my shaders caches size for all CEMU versions""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\getMyShaderCachesSize.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\getMyShaderCachesSize.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to getMyShaderCachesSize^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to restoreTransShadersforAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Restore transferable cache for each games.lnk""
        set "LINK_DESCRIPTION="Restore transferable cache of each game^'s folder in CEMU target folder""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreTransShadersforAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreTransShadersforAllGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to restoreTransShadersforAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to createGameGraphicPacks.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\Create Graphic Pack for a game using its titleId.lnk""
        set "LINK_DESCRIPTION="Create Graphic Pack for a game using its titleId""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\createGameGraphicPacks.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\createGameGraphicPacks.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to createGameGraphicPacks^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to forceGraphicPackUpdate.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Graphic packs\force Graphic Pack folder update.lnk""
        set "LINK_DESCRIPTION="force Graphic Pack folder update and BatchFw GFX rebuild""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\forceGraphicPackUpdate.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\forceGraphicPackUpdate.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to forceGraphicPackUpdate^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to reports folder
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Games Compatibility Reports\!USERDOMAIN! reports.lnk""
        set "LINK_DESCRIPTION="Games^'s compatibility reports generated on !USERDOMAIN!""
        set "TARGET_PATH="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!""
        set "ICO_PATH="NONE""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to !USERDOMAIN! compatibility reports folder
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_PATH!
        )

        REM : create a shortcut to BatchFW_readme.txt (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\BatchFw_readme.lnk""
        set "LINK_DESCRIPTION="BatchFW_readme.txt""
        set "TARGET_PATH="!BFW_PATH:"=!\BatchFw_readme.txt""
        set "ICO_PATH="NONE""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to BatchFW_readme^.txt
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_PATH!
        )

        REM : create a shortcut to this script (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Create CEMU's executables for selected games.lnk""
        set "LINK_DESCRIPTION="Create missing CEMU^'s executables for selected games given a version of CEMU""
        set "TARGET_PATH="!THIS_SCRIPT!""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\createExecutables.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to this script
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to importGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Import Games with updates and DLC.lnk""
        set "LINK_DESCRIPTION="Import Games with updates and DLC and prepare them to emulation""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importGames.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to importGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to restoreBfwDefaultsettings.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Reset BatchFw.lnk""
        set "LINK_DESCRIPTION="Restore BatchFw factory settings""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\restoreBfwDefaultsettings.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\restoreBfwDefaultsettings.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to restoreBfwDefaultsettings^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to killBatchFw.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Kill BatchFw Processes.lnk""
        set "LINK_DESCRIPTION="Kill all BatchFw processes""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\killBatchFw.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\kill.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to killBatchFw^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to this script (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Create CEMU's shortcuts for selected games.lnk""
        set "LINK_DESCRIPTION="Create missing CEMU^'s shortcuts for selected games given a version of CEMU""
        set "TARGET_PATH="!BFW_PATH:"=!\createShortcuts.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\createShortcuts.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to this script
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !OUTPUT_FOLDER!
        )

        REM : create a shortcut to updateGraphicPacksFolder.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Update my graphic packs to latest.lnk""
        set "LINK_DESCRIPTION="Update _BatchFW_Graphic_Packs folder to latest release""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\updateGraphicPacksFolder.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to updateGraphicPacksFolder^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        REM : create a shortcut to importModsforAllGames.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\Import Mods for my games.lnk""
        set "LINK_DESCRIPTION="Search and import mods folder into game^'s one""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\importModsforAllGames.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\importModsforAllGames.ico""
        if not exist !LINK_PATH! (
                if !QUIET_MODE! EQU 0 @echo Creating a shortcut to importModsforAllGames^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "ARGS="!OUTPUT_FOLDER!""

        REM : create a shortcut to setup.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\set BatchFw settings and register CEMU installs.lnk""
        set "LINK_DESCRIPTION="Create missing CEMU^'s shortcuts for ALL my games and many versions of CEMU^, set BatchFw settings""
        set "TARGET_PATH="!BFW_PATH:"=!\setup.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\setup.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to setup^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS=""!OUTPUT_FOLDER:"=!\Wii-U Games"""

        REM : create a shortcut to uninstall.bat
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Uninstall BatchFW.lnk""
        set "LINK_DESCRIPTION="Uninstall BatchFW""
        set "TARGET_PATH="!BFW_PATH:"=!\uninstall.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\uninstall.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to uninstall^.bat
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !GAMES_FOLDER!
        )

        set "ARGS=""!USERDOMAIN!"""

        REM : create a shortcut to deleteAllMysettings.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Delete all my CEMU's settings.lnk""
        set "LINK_DESCRIPTION="Delete all my CEMU^'s settings saved""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteAllMysettings.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteAllMysettings.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to deleteAllMysettings^.bat for all CEMU^'s versions
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )

        set "ARGS=""!USERDOMAIN!"" ""!CEMU_FOLDER_NAME!"""

        REM : create a shortcut to deleteAllMysettings.bat (if needed)
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Delete all my !CEMU_FOLDER_NAME!'s settings.lnk""
        set "LINK_DESCRIPTION="Delete my settings saved for !CEMU_FOLDER_NAME!""
        set "TARGET_PATH="!BFW_PATH:"=!\tools\deleteAllMysettings.bat""
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\deleteAllMysettings.ico""
        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to deleteAllMysettings^.bat for !CEMU_FOLDER_NAME!^'s versions
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
        set "LINK_PATH="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shaders Caches\Explore OpenGL caches saved.lnk""
        set "LINK_DESCRIPTION="Explore OpenGL caches saved""
        set "TARGET_PATH=!GLCacheSavesFolder!"
        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\exploreOpenGLCacheSaves.ico""

        if not exist !LINK_PATH! (
            if !QUIET_MODE! EQU 0 @echo Creating a shortcut to access to OpenGL caches saves
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !BFW_TOOLS_PATH!
        )
    goto:eof

    REM : function to create a executable for a game
    :gameExecutable


        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\code\*.rpx""
        for /F "delims=~" %%i in ('dir /B /O:S !pat! 2^>NUL') do (
            set "RPX_FILE="%%i""
        )

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

        :searchIco

        REM : icon dl flag
        set "icoUpdate=false"

        REM : looking for ico file close to rpx file
        set "ICO_PATH="NONE""
        set "ICO_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\code\*.ico""
        for /F "delims=~" %%i in ('dir /B /O:D !pat! 2^>NUL' ) do set "ICO_FILE="%%i""

        REM : if no ico not file found, using cemu.exe icon
        if [!ICO_FILE!] == ["NONE"] (
            REM : search if exists in !BFW_PATH!\resources\gamesIcon using WiiU-Titles-Library.csv Ico file Id
            call:getIcon

            if not [!ICO_PATH!] == ["NONE"] goto:icoset

            REM : else using cemu.exe icon
            set "ICO_PATH="!BFW_PATH:"=!\resources\icons\noIconFound.ico""
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            @echo No icons found for !GAME_TITLE!

            if [!defaultBrowser!] == ["NOT_FOUND"] (
                @echo Download a jpg box-art in !GAME_FOLDER_PATH:"=!\code
                @echo ^(no need to rename it^) then use the shortcut
                @echo Wii-U Games^\_BatchFw^\Tools^\Games^'s icons^\Convert all jpg files to centered icons^.lnk
                goto:icoset
            )
            @echo.
            @echo. Opening up a google search^.^.^.
            REM : open a google search
            wscript /nologo !StartWait! !defaultBrowser! "https://www.google.com/search?q=!GAME_TITLE!+Wii-U+jpg+box+art&source=lnms&tbm=isch&sa=X"
            @echo Save a jpg box-art in !GAME_FOLDER_PATH:"=!\code
            @echo ^(no need to rename it^)
            pause

            REM : create icon for this game
            set "tobeLaunch="!BFW_PATH:"=!\tools\convertIconsforAllGames.bat""
            wscript /nologo !StartHiddenWait! !tobeLaunch! !GAME_FOLDER_PATH!

            set "icoUpdate=true"

            call:getIcon
        ) else (
            set "ICO_PATH="!GAME_FOLDER_PATH:"=!\code\!ICO_FILE:"=!""
        )


        :icoset
        set /A "gameDisplayed=0"

        REM : create shortcuts for all users
        for /F "tokens=2 delims=~=" %%a in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%a""
            set "userFolder="!OUTPUT_FOLDER:"=!\wii-U Games\!user:"=!""
            set "EXE_FILE="!userFolder:"=!\!GAME_TITLE:"=! [!CEMU_FOLDER_NAME!!argLeg!] !user:"=!.exe""

            if ["%icoUpdate%"] == ["true"] if exist !EXE_FILE! del /F !EXE_FILE! > NUL 2>&1

            REM : if exe exist and import mode enabled : if shortcut exist skip this game
            if exist !EXE_FILE! (
                if !QUIET_MODE! EQU 0 @echo ---------------------------------------------------------
                if !QUIET_MODE! EQU 0 @echo !GAME_TITLE! ^: executable for !user:"=! already exist^, skipped
            ) else (
                call:userGameExe !user!
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function for dividing integers returning an int
    :divfloat2int

        REM : get a
        set "numA=%~1"
        REM : get b
        set "numB=%~2"
        REM : get nbDecimals
        set /A "decimals=%~3"

        set /A "one=1"
        set /A "decimalsP1=decimals+1"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        if not ["!numA:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR the number %numA% does not have %decimals% decimals
            pause
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR the number %numB% does not have %decimals% decimals
            pause
            exit /b 2
        )

        set "fpA=%numA:.=%"
        set "fpB=%numB:.=%"

        REM : a / b
        set /A div=fpA*one/fpB

        set /A "result=!div:~0,-%decimals%!"

        REM : output
        set "%4=%result%"

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


    :userGameExe
        set "user="%~1""

        REM : Creating shortcut to launch game
        if !QUIET_MODE! EQU 0 if !gameDisplayed! EQU 0 (

            REM : asking for associating the current game with this CEMU VERSION
            @echo =========================================================
            @echo - !GAME_TITLE!
            @echo ---------------------------------------------------------
            @echo.
            @echo Creating a Executable for !GAME_TITLE! using !CEMU_FOLDER! ^?
            @echo   ^(n^)^: skip^, not associating this game with !CEMU_FOLDER_NAME!
            @echo   ^(y^)^: default value after 15s timeout
            @echo.

            call:getUserInput "Enter your choice? : " "y,n" ANSWER 15
            if [!ANSWER!] == ["n"] (
                REM : skip this game
                echo Skip this GAME
                set /A "gameDisplayed=2"
                goto:eof
            )
            set /A "gameDisplayed=1"
        )
        REM : first user already skipped the game
        if !gameDisplayed! EQU 2 goto:eof

        call:createFolder !userFolder!

        REM paths to batch and executable files
        set "BATCH_FILE="!launchersFolder:"=!\!GAME_TITLE:"=! [!CEMU_FOLDER_NAME!!argLeg!].bat""

        REM : set mlc01 path
        set "MLC01_FOLDER_PATH="!GAME_FOLDER_PATH:"=!\mlc01""
        if not exist !MLC01_FOLDER_PATH! (

            REM : create mlc01 in game's folder
            REM : TODO : check if cemu version does not support the -mlc options, what happen?
            REM : if stops -> limit the versions for BatchFW
            set "sysFolder="!GAME_FOLDER_PATH:"=!\mlc01\sys\title\0005001b\10056000\content""
            call:createFolder !sysFolder!
            set "saveFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\save\00050000\%titleId:00050000=%""
            call:createFolder !saveFolder!
            set "dlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000\%titleId:00050000=%\aoc""
            call:createFolder !dlcFolder!
REM            set "dlcFolder2="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000\%titleId:00050000=%\aoc_%titleId%""
REM            if not exist !dlcFolder2! mklink /J /D !dlcFolder2! !dlcFolder! > NUL 2>&1

            REM : first game's registration : create mods folder
            set "subfolder="!GAME_FOLDER_PATH:"=!\Cemu\mods""
            call:createFolder !subfolder!
        )

        REM : arguments for LaunchGame.bat
        set "ARGS=!CEMU_FOLDER! !GAME_FILE_PATH! !OUTPUT_FOLDER! !ICO_PATH! !MLC01_FOLDER_PATH! !user!"

        if ["!IMPORT_MODE!"] == ["DISABLED"] set "ARGS=!ARGS! -noImport"
        if ["!IGNORE_PRECOMP!"] == ["ENABLED"] set "ARGS=!ARGS! -ignorePrecomp"
        set "ARGS=!ARGS! %argLeg%"

REM        set "sg="!BFW_RESOURCES_PATH:"=!\signalsHandler\_BatchFwSignalsHandler.exe""
        set "lg="!BFW_TOOLS_PATH:"=!\launchGame.bat""
REM        set "batchLogFile="!OUTPUT_FOLDER:"=!\Wii-U Games\Logs\_BatchFw.log""
REM        set "BatchFwCall=!sg! !lg! %ARGS% !batchLogFile!"
        set "BatchFwCall=!lg! !ARGS!"

        REM : create the batch file to launch LaunchGame.bat
        @echo @echo off> !BATCH_FILE!
        @echo powershell ^(new-object -COM ^'shell.Application^'^)^.minimizeall^(^)>> !BATCH_FILE!
        @echo setlocal EnableExtensions>> !BATCH_FILE!
        @echo chcp %CHARSET% ^> NUL 2>&1>> !BATCH_FILE!
        @echo pushd !TOOLS_PATH!>> !BATCH_FILE!
        @echo wscript !StartHidden! !BatchFwCall!>> !BATCH_FILE!
        @echo exit %%ERRORLEVEL%%>> !BATCH_FILE!

        REM : search in logFile, getting only the last occurence
        set "bfwVersion=NONE"
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "BFW_VERSION" 2^>NUL') do set "bfwVersion=%%i"

        REM : arguments to Bat_To_Exe_Converter
        set "ARGS=/bat !BATCH_FILE! /exe !EXE_FILE! /icon !ICO_PATH! /x64 /overwrite /productName BatchFW /productVersion %bfwVersion%"
        set "bec="!BFW_RESOURCES_PATH:"=!\Bat_To_Exe_Converter.exe""
        wscript /nologo !StartHiddenWait! !bec! !ARGS! > NUL 2>&1

        pushd !GAMES_FOLDER!
        if !QUIET_MODE! EQU 0 @echo - Executable for !user:"=! created ^!

        set /A NB_GAMES_TREATED+=1
    goto:eof
    REM : ------------------------------------------------------------------

    :getIcon

        REM : check if !BFW_PATH!\resources\gamesIcon\%titleId%.ico exist
        set "icoBase="!BFW_PATH:"=!\resources\gamesIcons""
        set "icoBaseFile="!icoBase:"=!\%titleId%.ico""
        if exist !icoBaseFile! (
            set "titleIdIco=%titleId%"
            goto:copyIcoFile
        )

        set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

        REM : get information on game using WiiU Library File
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

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
        robocopy !icoBase! !codeFullPath! "%titleIdIco%.ico" > NUL 2>&1

        set "oldIcoGameFile="!codeFullPath:"=!\%titleIdIco%.ico""
        set "newIcoGameFile="!codeFullPath:"=!\!titleId!.ico""
        move /Y !oldIcoGameFile! !newIcoGameFile! > NUL 2>&1
        set "ICO_PATH=!newIcoGameFile!"
    goto:eof


    REM : functions to compare Cemu Versions
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

    :compareDigits

            set /A "num=%~1"

            set /A "dr=99"
            set /A "dt=99"
            for /F "tokens=%num% delims=~%sep%" %%r in ("%vir%") do set "dr=%%r"
            for /F "tokens=%num% delims=~%sep%" %%t in ("%vit%") do set "dt=%%t"

            if !dt! LSS !dr! exit /b 2
            if !dt! GTR !dr! exit /b 1

    goto:eof

    REM : if vit < vir return 1
    REM : if vit = vir return 0
    REM : if vit > vir return 2
    :compareVersions
        set "vit=%~1"
        set "vir=%~2"

        REM : versioning separator
        set "sep=."

        call:countSeparators !vit! nbst
        call:countSeparators !vir! nbsr

        REM : get the number minimum of sperators found
        set /A "minNbSep=!nbst!"
        if !nbsr! LSS !nbst! set /A "minNbSep=!nbsr!"
        set /A "minNbSep+=1"

        REM : Loop on the minNbSep and comparing each number
        REM : note that the shell can compare 1c with 1d for example
        for /L %%l in (1,1,!minNbSep!) do (
            call:compareDigits %%l !vir! !vit!
            if !ERRORLEVEL! NEQ 0 set "%2=!ERRORLEVEL!" goto:eof
        )

    goto:eof

    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathforDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
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
    :setCharset

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeset not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeset=%CHARSET%"

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
