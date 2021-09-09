@echo off
setlocal EnableExtensions
title CEMU Game Launcher
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "initProgressBar="!BFW_TOOLS_PATH:"=!\initProgressBar.bat""
    set "progressBar="!BFW_RESOURCES_PATH:"=!\progressBar.lnk""
    set "getShaderCacheFolder="!BFW_RESOURCES_PATH:"=!\getShaderCacheName""
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenCmd="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenCmd.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : clean BFW_LOGS
    pushd !BFW_LOGS!
    for /F "delims=~" %%i in ('dir /B /S /A:D 2^>NUL') do rmdir /Q /S "%%i" > NUL 2>&1
    for /F "delims=~" %%i in ('dir /B /S /A:L 2^>NUL') do rmdir /Q /S "%%i" > NUL 2>&1
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    mkdir !fnrLogFolder! > NUL 2>&1

    set /A "usePbFlag=0"
    type !logFile! | find "USE_PROGRESSBAR=YES" > NUL 2>&1 && (
        REM : init progressBar
        wscript /nologo !StartHidden! !initProgressBar!
        set /A "usePbFlag=1"
    )

    REM : if choosen, check update availability
    type !logFile! | find /I "CHECK_UPDATE=YES" > NUL && (
        REM :  Checking for BatchFw update silently and in background
        set "ubw="!BFW_TOOLS_PATH:"=!\updateBatchFw.bat""
        wscript /nologo !StartHidden! !ubw! silent
    )

    set "BFW_ONLINE="!GAMES_FOLDER:"=!\_BatchFw_WiiU\onlineFiles""

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "xmlS="!BFW_RESOURCES_PATH:"=!\xml.exe""

    set "batchFwLog="!BFW_PATH:"=!\logs\BatchFwLog.txt""
    REM : initialize BatchFw report
    echo. > !batchFwLog!

    REM : check if cemu if not already running
    set /A "nbI=0"

    for /F "delims=~" %%j in ('tasklist ^| find /I "cemu.exe" ^| find /I /V "find" /C') do set /A "nbI=%%j"
    if %nbI% NEQ 0 (
        !MessageBox! "ERROR ^: Cemu is already running in the background ^! ^(nbi=%nbI%^)^. If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!" 4112
        echo "ERROR^: CEMU is already running ^!" >> !batchFwLog!
        echo "ERROR^: CEMU is already running ^!"
        tasklist | find /I "cemu.exe" | find /I /V "find" >> !batchFwLog!
        tasklist | find /I "cemu.exe" | find /I /V "find"
        exit 70
    )

    if !usePbFlag! EQU 0 goto:getDate
    set "logFileTmp="!TMP:"=!\BatchFw_process.list""

    :waitInitPb
    wmic process get Commandline 2>NUL | find ".exe" | find  /I "_BatchFW_Install" | find /I /V "wmic"  > !logFileTmp!
    type !logFileTmp! | find /I "initProgessBar.bat" | find /I /V "find"  > NUL 2>&1 && goto:waitInitPb

    REM : remove trace
    del /F !logFileTmp! > NUL 2>&1

    if !usePbFlag! EQU 1 call:setProgressBar 0 8 "pre processing" "initializing and checking"

    :getDate
    REM : get DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    set "setup="!BFW_PATH:"=!\setup.bat""
    echo ========================================================= >> !batchFwLog!
    REM : search in logFile, getting only the last occurence
    set "bfwVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_VERSION="  ^| find /V "msg" 2^>NUL') do (
        set "bfwVersion=%%i"
        set "bfwVersion=!bfwVersion:"=!"
        goto:displayVersion
    )
    :displayVersion
    echo CEMU^'s Batch Framework %bfwVersion% >> !batchFwLog!
    echo ========================================================= >> !batchFwLog!

    call:cleanHostLogFile BFW_VERSION

    set "msg="BFW_VERSION=%bfwVersion%""
    call:log2HostFile !msg!

    REM : Intel legacy options
    set "argLeg="

    REM : current user
    set "user="NOT_FOUND""

    REM : flag importing settings
    set /A "settingsImported=0"
    REM : flag for creating old update and DLC paths
    set /A "buildOldUpdatePaths=1"

    REM : cd to BFW_TOOLS_PATH
    pushd !BFW_TOOLS_PATH!

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% GTR 9 (
        echo ERROR ^: on arguments passed ^!>> !batchFwLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER PRX_FILE_PATH OUTPUT_FOLDER ICO_PATH MLC01_FOLDER_PATH user -noImport^* -ignorePrecomp^* -no^/Legacy^*>> !batchFwLog!
        echo ^(^* for optionnal^ argument^)>> !batchFwLog!
        echo given {%*} >> !batchFwLog!
        timeout /t 8 > NUL 2>&1
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 99
    )

    if %nbArgs% LSS 6 (
        echo ERROR ^: on arguments passed ^! >> !batchFwLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER PRX_FILE_PATH OUTPUT_FOLDER ICO_PATH MLC01_FOLDER_PATH user -noImport^* -ignorePrecomp^* -no^/Legacy^* >> !batchFwLog!
        echo ^(^* for optionnal^ argument^) >> !batchFwLog!
        echo given {%*} >> !batchFwLog!
        echo given {%*}
        timeout /t 8 > NUL 2>&1
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 99
    )
    REM : flag for nolegacy options
    set "AUTO_IMPORT_MODE=DISABLED"
    set "IGNORE_PRECOMP=DISABLED"


    REM : args 6
    set "user=!args[5]!"
    set "currentUser=!user:"=!"
    if %nbArgs% EQU 6 goto:getCemuFolder

    REM : args 7
    if [!args[6]!] == ["-noImport"] set "AUTO_IMPORT_MODE=DISABLED"
    if [!args[6]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"
    if [!args[6]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[6]!] == ["-Legacy"] set "argLeg=-Legacy"

    if %nbArgs% EQU 7 goto:getCemuFolder

    REM : args 8
    if [!args[7]!] == ["-noImport"] set "AUTO_IMPORT_MODE=DISABLED"
    if [!args[7]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"
    if [!args[7]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[7]!] == ["-Legacy"] set "argLeg=-Legacy"

    if %nbArgs% EQU 8 goto:getCemuFolder

    REM : args 9
    if [!args[8]!] == ["-noImport"] set "AUTO_IMPORT_MODE=DISABLED"
    if [!args[8]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"
    if [!args[8]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[8]!] == ["-Legacy"] set "argLeg=-Legacy"

    :getCemuFolder

    REM : get CEMU_FOLDER
    set "CEMU_FOLDER=!args[0]!"

    REM : lock file to protect this launch
    set "lockFile="!CEMU_FOLDER:"=!\BatchFw_!currentUser!-!USERNAME!.lock""

    REM : get RPX_FILE_PATH
    set "RPX_FILE_PATH=!args[1]!"

    REM : get and check SHORTCUT_FOLDER
    set "OUTPUT_FOLDER=!args[2]!"
    if not exist !OUTPUT_FOLDER! (
        echo ERROR ^: shortcut folder !OUTPUT_FOLDER! does not exist ^! >> !batchFwLog!
        timeout /t 8 > NUL 2>&1
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 3
    )

    REM : check RPX_FILE_PATH
    if not exist !RPX_FILE_PATH! (
        echo ERROR ^: game's rpx file path !RPX_FILE_PATH! does not exist ^! please delete this shortcut^/executable >> !batchFwLog!
        timeout /t 8 > NUL 2>&1
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 2
    )

    REM : get codeFolder
    for /F "delims=~" %%i in (!RPX_FILE_PATH!) do set "dirname="%%~dpi""
    set "codeFolder=!dirname:~0,-2!""

    for /F "delims=~" %%i in (!codeFolder!) do set "strTmp="%%~dpi""
    set "GAME_FOLDER_PATH=!strTmp:~0,-2!""

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    REM : that works also if CEMU_FOLDER does not exist !
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME="%%~nxa""
    set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME:"=!"

    title Launching !GAME_TITLE! with !CEMU_FOLDER_NAME!

    REM : search if this script is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GEQ 2 (
            !MessageBox! "ERROR ^: this script is already^/still running ^(nbI=%nbI%^)^. If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!" 16
            echo "ERROR^: This script is already running ^!" >> !batchFwLog!
            echo "ERROR^: This script is already running ^!"
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find" >> !batchFwLog!
            wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
            exit 20
        )
    )

    REM : CEMU's log
    set "cemuLog="!CEMU_FOLDER:"=!\log.txt""
    REM : settings files
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
    set "csb="!CEMU_FOLDER:"=!\settings.bin""
    set "chs="!CEMU_FOLDER:"=!\cemuHook.ini""

    REM : BatchFW graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""

    if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL 2>&1

    REM : start a script that will monitor the execution
    set "ml="!BFW_TOOLS_PATH:"=!\monitorBatchFw.bat""
    wscript /nologo !StartHidden! !ml!

    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if !usePbFlag! EQU 1 call:setProgressBar 8 12 "pre processing" "searching for a new GFX packs release"

    REM : check a graphic pack update
    set "script="!BFW_TOOLS_PATH:"=!\updateGraphicPacksFolder.bat""

    wscript /nologo !StartHidden! !script! -warn

    REM : GFX pack version of the last ones created/completed by BatchFw
    set "strBfwMaxVgfxp=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION=" 2^>NUL') do set "strBfwMaxVgfxp=%%i"
    set "strBfwMaxVgfxp=!strBfwMaxVgfxp:"=!"
    set /A "gfxPackVersion=!strBfwMaxVgfxp:V=!"


    REM : init to the last version of packs created by BatchFw
    set "gfxPackVersionNeeded=!strBfwMaxVgfxp!"
    set "gfxv2="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""
    set "gfxv4="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV4""

    set "versionRead=NOT_FOUND"
    if not exist !cemuLog! (
        REM : get it from the executable
        set "cemuExe="!CEMU_FOLDER:"=!\Cemu.exe""

        set "here="%CD:"=%""
        pushd !BFW_TOOLS_PATH!
        for /F %%a in ('getDllOrExeVersion.bat !cemuExe!') do set "versionRead=%%a"
        set "versionRead=%versionRead:~0,-2%"
        pushd !here!
    ) else (
        for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu" 2^> NUL') do set "versionRead=%%e"
    )
    echo Version read in log ^: !versionRead! >> !batchFwLog!
    REM : init global var
    set "versionReadFormated=NONE"

    REM : Get version of GFX packs requiered for this version of CEMU (extract packs if needed)

    REM : suppose that version > 1.25.0 > 1.21.0 > 1.18.2 > 1.15.19 > 1.15.15 > 1.15.6 > 1.14
    set /A "v125=1"
    set /A "v121=1"
    set /A "v1182=1"
    set /A "v11519=1"
    set /A "v11515=1"
    set /A "v1156=1"
    set /A "v1158=1"
    set /A "v114=1"

    REM : comparing version to V1.25.0 (new shaders & vulkan pipeline cache)
    call:compareVersions !versionRead! "1.25.0" v125 > NUL 2>&1
    if ["!v125!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v125! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version >= 1.25.0 => > v1.21.0 > ....
    if !v125! LEQ 1 goto:getTitleId

    REM : comparing version to V1.21.0 (GFX packs V4 -> 7 and up)
    call:compareVersions !versionRead! "1.21.0" v121 > NUL 2>&1
    if ["!v121!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v121! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version > 1.21.0 => > v1.18.2 > ....
    if !v121! LEQ 1 goto:getTitleId


    REM : V4 packs support
    set "gfxPackVersionNeeded=V4"

    REM : TODO : uncomment when V4 packs will not be mixed with V6 ones in GFX repo
    if exist !gfxv4! goto:checkV1182

    mkdir !gfxv4! > NUL 2>&1
    set "rarFile="!BFW_RESOURCES_PATH:"=!\V4_GFX_Packs.rar""

    echo --------------------------------------------------------- >> !batchFwLog!
    echo graphic pack V4 are needed for this version^, extracting^.^.^. >> !batchFwLog!

    wscript /nologo !Start! !MessageBox! "Need to extract V4 GFX packs, please wait..."

    if !usePbFlag! EQU 1 call:setProgressBar 12 12 "pre processing" "installing V4 GFX packs"

    wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !gfxv4! > NUL 2>&1
    set /A cr=!ERRORLEVEL!
    if !cr! GTR 1 (
        echo ERROR while extracting V4_GFX_Packs, exiting 1
        echo ERROR while extracting V4_GFX_Packs, exiting 1 >> !batchFwLog!
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 21
    )
    goto:forceGfxPacksUpdate

    :checkV1182
    REM : comparing version to V1.18.2
    call:compareVersions !versionRead! "1.18.2" v1182 > NUL 2>&1
    if ["!v1182!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v1182! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version > 1.18.2 => > v1.15.19 > ....
    if !v1182! LEQ 1 goto:getTitleId

    call:compareVersions !versionRead! "1.15.19" v11519 > NUL 2>&1
    if ["!v11519!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v11519! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version > 1.15.19 => > v1.15.15 > ....
    if !v11519! LEQ 1 goto:getTitleId

    call:compareVersions !versionRead! "1.15.15" v11515 > NUL 2>&1
    if ["!v11515!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v11515! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version > 1.15.15 => > v1.15.8 > ....
    if !v11515! LEQ 1 goto:getTitleId

    call:compareVersions !versionRead! "1.15.8" v1158 > NUL 2>&1
    if ["!v1158!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v1158! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version > 1.15.8 => > v1.15.6 > ....
    if !v1158! LEQ 1 goto:getTitleId

    call:compareVersions !versionRead! "1.15.6" v1156 > NUL 2>&1
    if ["!v1156!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v1156! EQU 50 echo Error when comparing versions >> !batchFwLog!

    REM : version > 1.15.6 => > v1.14 > ....
    if !v1156! LEQ 1 goto:getTitleId

    call:compareVersions !versionRead! "1.14.0" v114 > NUL 2>&1
    if ["!v114!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v114! EQU 50 echo Error when comparing versions >> !batchFwLog!

    if !v114! LEQ 1 (
        REM : do build old update/dlc paths in mlc
        set /A "buildOldUpdatePaths=0"
        goto:getTitleId
    )

    set "gfxPackVersionNeeded=V2"
    if exist !gfxv2! goto:getTitleId

    mkdir !gfxv2! > NUL 2>&1
    set "rarFile="!BFW_RESOURCES_PATH:"=!\V2_GFX_Packs.rar""

    echo --------------------------------------------------------- >> !batchFwLog!
    echo graphic pack V2 are needed for this version^, extracting^.^.^. >> !batchFwLog!

    wscript /nologo !Start! !MessageBox! "Need to extract V2 GFX packs, please wait..."

    if !usePbFlag! EQU 1 call:setProgressBar 12 12 "pre processing" "installing V2 GFX packs"

    wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !gfxv2! > NUL 2>&1
    set /A cr=!ERRORLEVEL!
    if !cr! GTR 1 (
        echo ERROR while extracting V2_GFX_Packs, exiting 1
        echo ERROR while extracting V2_GFX_Packs, exiting 1 >> !batchFwLog!
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 21
    )
    :forceGfxPacksUpdate
    if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] type !logFile! | find /I "COMPLETE_GP" > NUL && (
        REM : force a graphic pack update
        echo Forcing a GFX pack update to eventually take new ratios into account^.^.^. >> !batchFwLog!
        echo. >> !batchFwLog!
        echo Forcing a GFX pack update to eventually take new ratios into account^.^.^.
        echo.
        wscript /nologo !Start! !MessageBox! "Forcing a GFX pack update to take new ratios into account..."

        REM : forcing a GFX pack update to add GFX packs for new games
        set "gfxUpdate="!BFW_TOOLS_PATH:"=!\forceGraphicPackUpdate.bat""
        wscript /nologo !StartWait! !gfxUpdate! -silent
    )

    :getTitleId
    REM : META.XML file
    set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""

    if not exist !META_FILE! goto:getScreenMode

    REM : get Title Id from meta.xml
    set "titleLine="NONE""
    for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
    if [!titleLine!] == ["NONE"] goto:getScreenMode
    for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

    set "endTitleId=%titleId:~8,8%"

    REM : link game's packs
    echo Checking !GAME_TITLE! graphic packs availability ^.^.^. >> !batchFwLog!
    if !usePbFlag! EQU 1 call:setProgressBar 12 16 "pre processing" "checking game graphic packs availability"

    REM : update Game's Graphic Packs
    REM : gfxPackVersionNeeded is the version of GFX packs needed by this version of CEMU
    REM : V2 : V0-2
    REM : V4 : V3-5
    REM : V6 : V6-*
    set "uggp="!BFW_TOOLS_PATH:"=!\updateGamesGraphicPacks.bat""
    wscript /nologo !StartHidden! !uggp! !gfxPackVersionNeeded! !GAME_FOLDER_PATH! !titleId! !buildOldUpdatePaths! !lockFile!
    echo !uggp! !gfxPackVersionNeeded! !GAME_FOLDER_PATH! !titleId! !buildOldUpdatePaths! !lockFile! >> !batchFwLog!

    REM : check if a Game's update is available
    set "ugp="!BFW_TOOLS_PATH:"=!\checkGameContentAvailability.bat""
    echo !ugp! !GAME_FOLDER_PATH! 0005000e !endTitleId! >> !batchFwLog!
    wscript /nologo !StartHidden! !ugp! !GAME_FOLDER_PATH! 0005000e !endTitleId!

    REM : create shortcut to logFile
    call:createBatchFwLogShorcut

    REM : handle transferable shader cache comptability since 1.16
    set "sci=NOT_FOUND"
    REM : old shader cache id (rpx hash)
    set "osci=NOT_FOUND"
    call:getShaderCacheName
    if ["!sci!"] == ["NOT_FOUND"] (
        echo WARNING ^: !GAME_TITLE! shader cache name computation failed ^! >> !batchFwLog!
        echo WARNING ^: !GAME_TITLE! shader cache name computation failed ^!
    )
    set "osci=!sci!"

    echo osci=!osci! sci=!sci! >> !batchFwLog!

    REM : is CEMU >= 1.16 ?
    set /A "v116=2

    if !v11515! EQU 2 goto:getScreenMode
    call:compareVersions !versionRead! "1.16.0" v116 > NUL 2>&1
    if ["!v116!"] == [""] echo Error when comparing versions >> !batchFwLog!
    if !v116! EQU 50 echo Error when comparing versions >> !batchFwLog!
    if !v116! EQU 2 goto:getScreenMode

    REM : if v > 1.16 update sci value with titleId (sci=titleId for CEMU > 1.16)
    call:lowerCase !titleId! sci

    REM : if v >= 1.25
    if !v125! LEQ 1 set "sci=!sci:"=!_shaders"

    :getScreenMode
    echo Expected shaderCacheName ^: !sci:_shaders=! >> !batchFwLog!
    echo Expected shaderCacheName ^: !sci:_shaders=!

    REM : if SCREEN_MODE is present in logHOSTNAME file : launch CEMU in windowed mode
    set "screenMode=-f"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode="

    REM : check CEMU_FOLDER
    if not exist !CEMU_FOLDER! (
        REM : shortcut path
        set "gameShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\!currentUser!\!GAME_TITLE! [!CEMU_FOLDER_NAME!!argLeg!] !currentUser!.lnk""
        set "gameExe="!OUTPUT_FOLDER:"=!\Wii-U Games\!currentUser!\!GAME_TITLE! [!CEMU_FOLDER_NAME!!argLeg!] !currentUser!.exe""

        REM : shortcut to game's profile
        set "versionShortcuts="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!""

        wscript /nologo !Start! !MessageBox! "CEMU folder !CEMU_FOLDER:"=! does not exist anymore^, you might have move or delete this version^. Removing shortcuts"

        REM : delete shortcuts
        if exist !gameShortcut! del /F !gameShortcut! >NUL
        if exist !gameExe! del /F !gameExe! >NUL
        rmdir /Q /S !versionShortcuts! > NUL 2>&1

        REM : Delete the shortcut
        set "logShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\Logs\!CEMU_FOLDER_NAME!.lnk""

        if exist !logShortcut! del /F !logShortcut! 2>NUL
        timeout /t 8 > NUL 2>&1
        exit 20
    )

    REM : get and check ICO_FILE_PATH
    set "ICO_PATH=!args[3]!"
    if not exist !ICO_PATH! (
        echo WARNING ^: game's icon file path !ICO_PATH! does not exist ^! >> !batchFwLog!
        timeout /t 8 > NUL 2>&1
    )
    echo ICO_PATH=!ICO_PATH! >> !batchFwLog!

    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[4]!"
    if not exist !MLC01_FOLDER_PATH! (
        echo ERROR ^: mlc01 folder !MLC01_FOLDER_PATH! does not exist ^! >> !batchFwLog!
        timeout /t 8 > NUL 2>&1
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 5
    )

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ >> !batchFwLog!

    if !usePbFlag! EQU 1 call:setProgressBar 16 30 "pre processing" "install !currentUser!^'s saves"


    REM : search the last modified save file for other user
    set "igsvf="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""

    if not exist !igsvf! mkdir !igsvf! > NUL 2>&1 & goto:savesLoaded

    REM : cd to inGameSaves folder
    pushd !igsvf!
    
    REM : CEMU default save for currentUser
    set "userGameSaveName="!GAME_TITLE!_!currentUser!.rar""
    set "defaultUserGameSaveName=!userGameSaveName!"

    REM : default (no extra slots)
    set /A "slotNumber=0"
    set "slotLabel="

    REM : get the active slot from gLogFile
    call:getUserSave userGameSaveName

    if not exist !userGameSaveName! (
        REM : try to use another slots
        set "otherSlot="NONE""

        REM : loop on all file found (reverse sorted by date => exit loop whith the last modified one)
        for /F "delims=~" %%i in ('dir /B /O:-D /T:W !GAME_TITLE!_!currentUser!_slot*.rar  2^>NUL') do set "otherSlot="%%i""
        pushd !BFW_TOOLS_PATH!

        if not [!otherSlot!] == ["NONE"] (

            !MessageBox! "Saves of slot !slotNumber! does not exist, use !otherSlot:"=! ?" 4132
            if !ERRORLEVEL! EQU 7 goto:savesLoaded

            copy /Y !otherSlot! !userGameSaveName! > NUL 2>&1
            goto:saveFound
        )

        set "saveFromOtherUser="NONE""

        pushd !igsvf!
        REM : loop on all file found (reverse sorted by date => exit loop whith the last modified one)
        for /F "delims=~" %%i in ('dir /B /O:-D /T:W !GAME_TITLE!_*.rar  2^>NUL') do (
            set "saveFromOtherUser="%%i""
        )
        if [!saveFromOtherUser!] == ["NONE"] goto:savesLoaded

        !MessageBox! "No saves found for this user, do you want to use the last modifed one (from another user) ?" 4132
        if !ERRORLEVEL! EQU 7 goto:savesLoaded
        copy /Y !saveFromOtherUser! !userGameSaveName! > NUL 2>&1
    )
    :saveFound
    pushd !BFW_TOOLS_PATH!
    echo Using !userGameSaveName! as save file
    echo Using !userGameSaveName! as save file>> !batchFwLog!
    set "userGameSave="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!userGameSaveName:"=!""

    REM : make a backup of saves with defaultUserGameSaveName name
    set "saveBackup=!defaultUserGameSaveName:.rar=-backupLaunchN.rar!"

    REM : add a supplementary level of backup because the launch following the crash that have corrupt file
    REM : backup file will be lost and replace by a corrupt backup and you aknowledge that an issue occured only
    REM : on this run
    set "lastValid=!saveBackup:LaunchN=LaunchN-1!"

    if exist !saveBackup! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe"  /C copy /Y !saveBackup! !lastValid! > NUL 2>&1
    wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe"  /C copy /Y !userGameSave! !saveBackup! > NUL 2>&1

    for %%a in (!MLC01_FOLDER_PATH!) do set "parentFolder="%%~dpa""
    set "EXTRACT_PATH=!parentFolder:~0,-2!""

    pushd !BFW_TOOLS_PATH!
    echo Loading saves for !currentUser!^.^.^.
    echo Loading saves for !currentUser!^.^.^.>> !batchFwLog!
    wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !userGameSave! !EXTRACT_PATH!

    :savesLoaded
    pushd !BFW_TOOLS_PATH!

    REM : Batch Game info file
    set "gameInfoFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt""

    REM : CEMU's shaderCache subfolder
    set "cemuShaderCache="!CEMU_FOLDER:"=!\shaderCache""

    REM : check if a saved transferable cache file exist
    set "OLD_SHADER_CACHE_ID=NONE"

    REM : CEMU transShaderCache folder
    set "ctscf="!cemuShaderCache:"=!\transferable""

    REM : check graphic API set
    set "graphicApi=OpenGL"
    if exist !cs! (
        pushd !BFW_RESOURCES_PATH!
        call:getValueInXml "//Graphic/api/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] if ["!value!"] == ["1"] (
            set "graphicApi=Vulkan"
        )
        pushd !BFW_TOOLS_PATH!
    )

    echo Grapic API used by default ^: !graphicApi!
    echo Grapic API used by default ^: !graphicApi! >> !batchFwLog!

    REM : copy transferable shader cache, if exist in GAME_FOLDER_PATH
    set "gtscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
    if not exist !gtscf! (
        mkdir !gtscf! > NUL 2>&1

        if ["!graphicApi!"] == ["OpenGL"] (
            call:searchInternetForTransferableCache
            if !ERRORLEVEL! NEQ 0 (
                if !usePbFlag! EQU 1 call:setProgressBar 30 50 "pre processing" "launching third party software"
                goto:launch3rdPartySoftware
            )
        ) else (
            REM : async compile introduced in v1.19
            if !v1182! EQU 2  (
                call:searchInternetForTransferableCache
                if !ERRORLEVEL! NEQ 0 (
                    if !usePbFlag! EQU 1 call:setProgressBar 30 50 "pre processing" "launching third party software"
                    goto:launch3rdPartySoftware
                )
            )
        )
    )

    set "cacheFile=NONE"
    pushd !gtscf!

    REM : getting the last modified one including _j.bin (conventionnal shader cache)
    if !v125! EQU 2 (
        for /F "delims=~" %%i in ('dir /B /O:D /T:W !sci!*.bin 2^>NUL ^| find /V "_" ^| find /V "backup"') do set "cacheFile=%%i"
    ) else (
        for /F "delims=~" %%i in ('dir /B /O:D /T:W !sci!_*.bin 2^>NUL ^| find /V "_vkpipeline" ^| find /V "backup"') do set "cacheFile=%%i"
    )

    REM : if new cache sci=titleId is not found AND if exist an old one => use it
    if ["!cacheFile!"] == ["NONE"] (
        REM : sci=osci for CEMU < 1.16
        if ["!osci!"] == ["!sci!"] (
            set "newCache=!titleId!.bin"

            if exist !newCache!  (
                set "cacheFile=!sci!.bin"

                copy /Y !newCache! !cacheFile! > NUL 2>&1
                echo Importing new transferable cache !newCache! as old cache !cacheFile! ^(fit CEMU earlier than 1^.16^) >> !batchFwLog!
                wscript /nologo !Start! !MessageBox! "Importing new transferable cache !newCache! as old cache !cacheFile! ^(fit CEMU earlier than 1^.16^)"
            )
        ) else (
            if !v125! EQU 2 (
                set "oldCache=!osci!.bin"
                if exist !oldCache!  (
                    set "cacheFile=!sci!.bin"
                    copy /Y !oldCache! !cacheFile! > NUL 2>&1
                    echo Importing old transferable cache !oldCache! as new cache !cacheFile!  ^(fit CEMU after 1^.16^) >> !batchFwLog!
                    wscript /nologo !Start! !MessageBox! "Importing old transferable cache !oldCache! as new cache !cacheFile! ^(fit CEMU after 1^.16^)"
                )
            )
        )
    )

    pushd !BFW_TOOLS_PATH!

    REM : check if cacheFile was found
    if ["!cacheFile!"] == ["NONE"] (

        if ["!graphicApi!"] == ["OpenGL"] (
            call:searchInternetForTransferableCache
            if !ERRORLEVEL! NEQ 0 (
                if !usePbFlag! EQU 1 call:setProgressBar 30 50 "pre processing" "launching third party software"
                goto:launch3rdPartySoftware
            )
        ) else (
            REM : async compile introduced in v1.19
            if !v1182! EQU 2  (
                call:searchInternetForTransferableCache
                if !ERRORLEVEL! NEQ 0 (
                    if !usePbFlag! EQU 1 call:setProgressBar 30 50 "pre processing" "launching third party software"
                    goto:launch3rdPartySoftware
                )
            )
        )
    )

    if !usePbFlag! EQU 1 call:setProgressBar 30 50 "pre processing" "backup and provide transferable cache"

    REM : backup transferable cache in case of CEMU corrupt it
    set "transF="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!cacheFile:"=!""
    set "tcBackup="!transF:"=!-backupLaunchN""

    REM : add a supplementary level of backup because the launch following the crash that have corrupt file
    REM : backup file will be lost and replace by a corrupt backup and you aknowledge that an issue occured only
    REM : on this run
    set "lastValid="!transF:"=!-backupLaunchN-1""

    if exist !tcBackup! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C copy /Y !tcBackup! !lastValid!

    wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C copy /Y !transF! !tcBackup!

    REM : get backup files sizes
    if exist !tcBackup! (
        for /F "tokens=*" %%a in (!tcBackup!)  do set /A "newSize=%%~za"
    ) else (
        set /A "newSize=0"
    )
    if exist !lastValid! (
        for /F "tokens=*" %%a in (!lastValid!)  do set /A "oldSize=%%~za"
    ) else (
        set /A "oldSize=0"
    )

    REM : compare their size : size of N always > N-1
    if %newSize% LSS %oldSize% (
        !MessageBox! "ERROR : old transferable cache backup is greater than new one, please check what happened !" 4112
        exit 30
    )

    REM : build OLD_SHADER_CACHE_ID without _j.bin
    set OLD_SHADER_CACHE_ID=!cacheFile:_j=!
    set OLD_SHADER_CACHE_ID=!OLD_SHADER_CACHE_ID:_shaders=!
    set OLD_SHADER_CACHE_ID=!OLD_SHADER_CACHE_ID:.bin=!

    REM : first launch the transferable cache copy in background before
    if not ["!OLD_SHADER_CACHE_ID!"] == ["NONE"] (
        echo Copying transferable cache !OLD_SHADER_CACHE_ID! to !CEMU_FOLDER! ^.^.^. >> !batchFwLog!
    )

    if !v125! EQU 2 (
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gtscf! !ctscf! "!sci!*.bin" /MT:32 /IS /IT /XF !sci!_*.bin > NUL 2>&1
    ) else (
         wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gtscf! !ctscf! "!sci!.bin" /MT:32 /IS /IT > NUL 2>&1
         wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gtscf! !ctscf! "!sci:_shaders=_vkpipeline!.bin" /MT:32 /IS /IT > NUL 2>&1
    )

    :launch3rdPartySoftware

    REM : launching third party software if defined
    set /A "useThirdPartySoft=0"
    type !logFile! | find /I "TO_BE_LAUNCHED" > NUL 2>&1 && set /A "useThirdPartySoft=1"
    if !useThirdPartySoft! EQU 1 (
        echo Launching third party software >> !batchFwLog!

        if !usePbFlag! EQU 1 call:setProgressBar 50 52 "pre processing" "launching third party software"

        REM : launching user's software
        set "launchThirdPartySoftware="!BFW_TOOLS_PATH:"=!\launchThirdPartySoftware.bat""
        wscript /nologo !StartHidden! !launchThirdPartySoftware! >> !batchFwLog!

        if !usePbFlag! EQU 1 call:setProgressBar 52 54 "pre processing" "getting CEMU options saved for !currentUser!"

    ) else (
        if !usePbFlag! EQU 1 call:setProgressBar 50 54 "pre processing" "getting CEMU options saved for !currentUser!"
    )

    REM : Settings folder for CEMU_FOLDER_NAME
    set "SETTINGS_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\!CEMU_FOLDER_NAME!""

    REM : initialize a flag to know if wizard will be launched
    set /A "wizardLaunched=0"

    set "PROFILE_FILE="NOT_FOUND""

    REM : GFX folders in CEMU
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""

    REM : get GPU_VENDOR
    set "gpuString=NOT_FOUND"
    set "GPU_VENDOR=NOT_FOUND"
    set "gpuType=NO_NVIDIA"
    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get Name /value 2^>NUL ^| find "="') do (
        set "gpuString=%%i"
        echo "!gpuString!" | find /I "NVIDIA" > NUL 2>&1 && (
            set "gpuType=NVIDIA"
            set "GPU_VENDOR=!gpuString: =!"
        )
    )

    REM : load Cemu's options
    call:loadCemuOptions

    REM : re check graphic API set in settings used
    set "graphicApi=OpenGL"
    pushd !BFW_RESOURCES_PATH!
    call:getValueInXml "//Graphic/api/text()" !cs! value
    if not ["!value!"] == ["NOT_FOUND"] if ["!value!"] == ["1"] (
        set "graphicApi=Vulkan"
    )
    pushd !BFW_TOOLS_PATH!

    REM : handling GPU shader cache backup
    REM : ----------------------------

    REM : saved GpuCache folder
    set "GLCACHE_BACKUP="NOT_FOUND""

    REM : openGpuCacheID
    set "oldGpuCacheId=NOT_FOUND"
    set "GPU_CACHE="NOT_FOUND""
    set "GpuCache="NOT_FOUND""
    set "gpuCacheSaved="NOT_FOUND""

    set "driversUpdateFlag=0"

    if ["!GPU_VENDOR!"] == ["NOT_FOUND"] set "GPU_VENDOR=!gpuString: =!"
    echo gpuType ^: !GPU_VENDOR! >> !batchFwLog!
    echo gpuType ^: !GPU_VENDOR!

    call:secureStringForDos !GPU_VENDOR! GPU_VENDOR > NUL 2>&1
    set "GPU_VENDOR=!GPU_VENDOR:"=!"

    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get DriverVersion /value 2^>NUL ^| find "="') do (
        set "string=%%i"
    )

    set "GPU_DRIVERS_VERSION=!string: =!"

    REM : search your current GpuCache
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence
    set "GPU_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "GPU_CACHE=%%i"

    REM : when updating drivers GpuCache is deleted
    if not [!GPU_CACHE!] == ["NOT_FOUND"] (
        if not exist !GPU_CACHE! mkdir !GPU_CACHE! > NUL 2>&1
        goto:handlingGame
    )

    REM : else search it
    pushd "%LOCALAPPDATA%"
    set "cache="NOT_FOUND""
    for /F "delims=~" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if [!cache!] == ["NOT_FOUND"] pushd "%APPDATA%" && for /F "delims=~" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if not [!cache!] == ["NOT_FOUND"] set "GPU_CACHE=!cache!"

    pushd !BFW_TOOLS_PATH!

    if [!GPU_CACHE!] == ["NOT_FOUND"] goto:handlingGame

    REM : save path to log file
    set "msg="OPENGL_CACHE=!GPU_CACHE:"=!""
    call:log2HostFile !msg!

    REM : handling Game
    REM : ----------------------------
    :handlingGame
    echo Grapic API used for this game^: !graphicApi!
    echo Grapic API used for this game^: !graphicApi! >> !batchFwLog!
    set "GPU_CACHE_PATH=!GPU_CACHE!"

    REM : CEMU >= 1.15.1
    set "cemuGLcache="!CEMU_FOLDER:"=!\shaderCache\driver\nvidia""

    if ["%gpuType%"]==["NVIDIA"] if exist !cemuGLcache! set "GPU_CACHE_PATH="!cemuGLcache:"=!\GLCache""

    REM : Vulkan cache (CEMU >= 1.16)
    if ["!graphicApi!"] == ["Vulkan"] set "GPU_CACHE_PATH="!CEMU_FOLDER:"=!\shaderCache\driver\vk""

    echo GPU_CACHE_PATH=!GPU_CACHE_PATH!
    echo GPU_CACHE_PATH=!GPU_CACHE_PATH! >> !batchFwLog!

    REM : create the default GLcache subfolder if GPU_CACHE <> NOT_FOUND
    if not exist !GPU_CACHE_PATH! if not [!GPU_CACHE!] == ["NOT_FOUND"] mkdir !GPU_CACHE_PATH! > NUL 2>&1

    REM : check if another instance of CEMU is running
    :searchLockFile
    set "LOCK_FILE="NONE""
    set "pat="!CEMU_FOLDER:"=!\*.lock""
    for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL') do (
        set "LOCK_FILE="!CEMU_FOLDER:"=!\%%i""
    )

    REM : if a lock file was found
    if not [!LOCK_FILE!] == ["NONE"] (

        echo ERROR when launching !GAME_TITLE! ^: A lock file was found under !CEMU_FOLDER:"=! ^! >> !batchFwLog!
        echo Please close^/kill runing CEMU executable and remove !LOCK_FILE:"=! >> !batchFwLog!
        echo --------------------------------------------------------- >> !batchFwLog!
        type !LOCK_FILE!>> !batchFwLog!
        echo --------------------------------------------------------- >> !batchFwLog!
        wscript /nologo !Start! "%windir%\explorer.exe" !CEMU_FOLDER!

        !MessageBox! "A lock file was found under !CEMU_FOLDER:"=!^, if no other windows user ^(session left openned^) is running CEMU ^: delete-it then close this windows" 4112
        goto:searchLockFile
    )

    REM : transShaderCache log
    if not exist !gtscf! mkdir !gtscf! > NUL 2>&1
    set "tscl="!gtscf:"=!\transShaderCache.log""
    echo GAME_CONFIGURATION before launching !CEMU_FOLDER_NAME! : > !tscl!
    if exist !gameInfoFile! type !gameInfoFile! >> !tscl!

    REM :  -> add a check MLC01 = CEMU AND local mlc01 exist
    set "cml01="!CEMU_FOLDER:"=!\mlc01""

    REM : check mlc01 consistency
    if not [!MLC01_FOLDER_PATH!] == [!cml01!] goto:openGpuCache
    REM : if arg MLC01_FOLDER_PATH is pointing to CEMU_FOLDER

    REM : and a local mlc01 folder exist
    set "gml01="!GAME_FOLDER_PATH:"=!\mlc01""

    if not exist !gml01! goto:openGpuCache

    !MessageBox! "ERROR ^: Please delete and recreate this shortcut ^(if !CEMU_FOLDER_NAME:"=! newer than 1^.11^) OR rename^/move !gml01:"=! ^(if !CEMU_FOLDER_NAME:"=! is an older than 1^.10 and so mlc01 is in CEMU folder^)" 4112
    exit 15

    :openGpuCache
    if !usePbFlag! EQU 1 call:setProgressBar 82 84 "pre processing" "installing GPU cache"
    set "precompFolder="!CEMU_FOLDER:"=!\shaderCache\precompiled""

    REM : search GCLCache backup in _BatchFW_CemuGLCache folder
    set "gpuCacheBackupFolder="NOT_FOUND""
    if [!GPU_CACHE_PATH!] == ["NOT_FOUND"] goto:lockCemu

    set "gpuCacheSavesFolder=!GPU_CACHE:GLCache=_BatchFW_CemuGLCache!"

    if ["!graphicApi!"] == ["Vulkan"] (
        set "gpuCacheSavesFolder=!GPU_CACHE:GLCache=_BatchFW_CemuVkCache!"
        set "GPU_CACHE=!GPU_CACHE_PATH!"
    )

    if not exist !gpuCacheSavesFolder! goto:lockCemu

    set "idGpuFolder="NOT_FOUND""
    pushd !gpuCacheSavesFolder!
    set "pat="!GPU_VENDOR!*""
    for /F "delims=~" %%x in ('dir /A:D /O:D /T:W /B !pat! 2^>NUL') do set "idGpuFolder="%%x""
    pushd !BFW_TOOLS_PATH!

    REM : if no backup found for your GPU VENDOR goto:lockCemu
    if [!idGpuFolder!] == ["NOT_FOUND"] goto:lockCemu
    REM : get gpuVendor and gpuDriversVersion from folder's name
    for /F "tokens=1-2 delims=@" %%i in (!idGpuFolder!) do (
        set "gpuVendorRead=%%i"
        set "gpuDriversVersionRead=%%j"
    )

    REM : if GPU_VENDOR not match goto:lockCemu ignore the file
    if not ["!gpuVendorRead!"] == ["!GPU_VENDOR!"] (
        echo Found a GLCache backup !idGpuFolder! that is not for your current GPU Vendor^, delete-it ^! >> !batchFwLog!
        REM : log to host log file
        set "msg="!DATE!-non matching GPU Vendor GLCache backup deleted=!idGpuFolder!""
        call:log2HostFile !msg!

        rmdir /Q /S !idGpuFolder! > NUL 2>&1
        goto:lockCemu
    )
    REM : secure string for diff
    set "old=%gpuDriversVersionRead:.=%"
    set "old=%old:-=%"
    set "old=%old:_=%"

    REM : secure string for diff
    set "new=%GPU_DRIVERS_VERSION:.=%"
    set "new=%new:-=%"
    set "new=%new:_=%"

    REM : if GPU_DRIVERS_VERSION match goto:lockCemu use the file
    if not ["%old%"] == ["%new%"] (
        echo Display drivers update detected ^! >> !batchFwLog!
        echo from display drivers version    ^: [%gpuDriversVersionRead%] >> !batchFwLog!
        echo current display drivers version ^: [%GPU_DRIVERS_VERSION%] >> !batchFwLog!

        REM : log to host log file
        set "msg="Detected %GPU_VENDOR% drivers version upgrade from %gpuDriversVersionRead% to %GPU_DRIVERS_VERSION%""
        call:log2HostFile !msg!
        set "driversUpdateFlag=1"
    )
    set "idGpuFolder="!gpuCacheSavesFolder:"=!\!idGpuFolder:"=!""

    set "gpuCacheBackupFolder="!idGpuFolder:"=!\!GAME_TITLE!""

    REM : if no backup folder is found for this game goto:lockCemu
    if not exist %gpuCacheBackupFolder% goto:lockCemu

    REM : openGpuCacheID
    for /F "delims=~" %%x in ('dir /A:D /O:D /T:W /B !gpuCacheBackupFolder! 2^>NUL') do set "oldGpuCacheId=%%x"
    if not ["%oldGpuCacheId%"] == ["NOT_FOUND"] goto:subfolderFound

    REM : search for shader files
    pushd !gpuCacheBackupFolder!
    set "shaderCacheFileName=NOT_FOUND"
    for /F "delims=~" %%f in ('dir /O:D /T:W /B !sci:_shaders=!.bin 2^>NUL') do set "shaderCacheFileName=%%~nf"
    pushd !BFW_TOOLS_PATH!
    if ["%shaderCacheFileName%"] == ["NOT_FOUND"] goto:lockCemu

    pushd !gpuCacheBackupFolder!
    REM GPU_CACHE_PATH already created before (if missing)
    for /F "delims=~" %%f in ('dir /O:D /T:W /B %shaderCacheFileName%*.* 2^>NUL') do (
        set "file="%%f""
        if !v1182! LEQ 1 echo !file! | find "_spirv" > NUL 2>&1 && wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gpuCacheBackupFolder! !precompFolder! !file! /MT:32 /MOV /IS /IT> NUL 2>&1
        echo !file! | find /V "_spirv" > NUL 2>&1 && wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gpuCacheBackupFolder! !GPU_CACHE_PATH! !file! /MT:32 /MOV /IS /IT > NUL 2>&1
    )
    pushd !BFW_TOOLS_PATH!

    REM : using backup
    echo Using !shaderCacheFileName! as GPU cache ^(!graphicApi!^)>> !batchFwLog!
    goto:lockCemu

    :subfolderFound
    set "gpuCache="!GPU_CACHE_PATH:"=!\%oldGpuCacheId%""

    if exist !gpuCache! rmdir /Q /S !gpuCache! > NUL 2>&1

    set "gpuCacheSaved="!gpuCacheBackupFolder:"=!\%oldGpuCacheId%""

    REM : moving folder (NVIDIA specific)
    :moveGl
    call:moveFolder !gpuCacheSaved! !gpuCache! cr
    if !cr! NEQ 0 (
        !MessageBox! "ERROR While moving openGL save, close all explorer.exe that might interfer !" 4113
        if !ERROLRLEVEL! EQU 1 goto:moveGl
        if !ERROLRLEVEL! EQU 2 wscript /nologo !Start! !MessageBox! "ERROR While moving openGL save !"
    )

    REM : using backup
    echo Using !gpuCacheSaved! as GPU cache ^(!graphicApi!^)>> !batchFwLog!

    REM : Launching CEMU (for old versions -mlc will be ignored)
    :lockCemu

    REM : create a lock file to protect this launch
    echo !DATE! : %user:"=% launched !GAME_TITLE! using !USERNAME! windows profile > !lockFile!
    if not exist !lockFile! (
        !MessageBox! "ERROR when creating !lockFile:"=!^, need rights in !CEMU_FOLDER:"=!^, please contact your !USERDOMAIN:"=!^'s administrator^!" 4112
        exit 3
    )
    echo --------------------------------------------------------- >> !batchFwLog!

    if !usePbFlag! EQU 1 if !wizardLaunched! EQU 0 (
        call:setProgressBar 84 90 "pre processing" "waiting all child processes end"
    ) else (
        if !usePbFlag! EQU 1 call:setProgressBar 84 94 "pre processing" "waiting all child processes end"
        goto:launchCemu
    )

    REM : waiting all pre requisities are ready
    call:waitProcessesEnd

    REM : if v >= 1.16 delete old update/dlc tree links and folder
    if !v116! LEQ 1 (
        set "linksFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000\!endTitleId!""
        for /F "delims=~" %%a in ('dir /A:L /B !linksFolder! 2^>NUL') do (
            rmdir /Q /S !linksFolder! > NUL 2>&1
            goto:ifWizardWasLaunched
        )
    )
    :ifWizardWasLaunched
    REM : if wizard was launched, packs links is already created
    if !wizardLaunched! EQU 1 goto:launchCemu

    if !usePbFlag! EQU 1 call:setProgressBar 90 96 "pre processing" "providing GFX and mods packs to Cemu !versionRead!"

    echo Linking GFX packs folder for !GAME_TITLE! in !CEMU_FOLDER! ^.^.^. >> !batchFwLog!

    set /A "attempt=1"
    :tryToBackupGp
    if exist !graphicPacks! (
        move /Y !graphicPacks! !graphicPacksBackup! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                !MessageBox! "Moving !graphicPacks:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToBackupGp
            )

            call:fillOwnerShipPatch !CEMU_FOLDER! !CEMU_FOLDER_NAME! patch

            !MessageBox! "Check still failed^, take the ownership on !CEMU_FOLDER:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToBackupGp

            !MessageBox! "ERROR While moving graphic pack^'s folder, they won't be installed !" 4112
        )
    )

    REM : issue with CEMU 1.15.3 that does not compute cortrectly relative path to GFX folder
    REM : when using a simlink with a the target on another partition
    for %%a in (!GAME_GP_FOLDER!) do set "d1=%%~da"
    for %%a in (!graphicPacks!) do set "d2=%%~da"

    REM : suppose that version > 1.15.3b
    set /A "v1153b=1"
    REM : if on the same partition
    if not ["%d1%"] == ["%d2%"] (
        REM : if version > 1.14
        if !v114! EQU 1 (
            REM : compare to 1.15.3b
            call:compareVersions !versionRead! "1.15.3b" v1153b > NUL 2>&1

            if ["!v1153b!"] == [""] echo Error when comparing versions >> !batchFwLog!
            if !v1153b! EQU 50 echo Error when comparing versions >> !batchFwLog!


            if !v1153b! LEQ 1 wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !GAME_GP_FOLDER! !graphicPacks! /MT:32 /mir > NUL 2>&1 && goto:launchCemu
        ) else (
            REM : version < 1.14 => version < 1.15.3b
            set /A "v1153b=2"
        )
    )

    mklink /D /J !graphicPacks! !GAME_GP_FOLDER! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !GAME_GP_FOLDER! !graphicPacks! /MT:32 /mir > NUL 2>&1

    :launchCemu

    REM : check if a new DLC is available
    wscript /nologo !StartHidden! !ugp! !GAME_FOLDER_PATH! 0005000c !endTitleId!

    if !usePbFlag! EQU 1 call:setProgressBar 96 100 "pre processing" "launching Cemu !versionRead!"

    REM : minimize all windows befaore launching in full screen
    set "psCommand="(new-object -COM 'shell.Application')^.minimizeall()""
    powershell !psCommand!

    REM : launching CEMU on game and waiting
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ >> !batchFwLog!
    echo Starting !CEMU_FOLDER_NAME! with the following command ^: >> !batchFwLog!
    echo --------------------------------------------------------- >> !batchFwLog!

    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""

    set /a cr_cemu=0
    if [!MLC01_FOLDER_PATH!] == [!cml01!] (
        echo start !cemu! %screenMode% -g !RPX_FILE_PATH! !noLeg! >> !batchFwLog!
        wscript /nologo !StartMaximizedWait! !cemu! %screenMode% -g !RPX_FILE_PATH! !noLeg!
        set /a cr_cemu=!ERRORLEVEL!
    ) else (
        echo start !cemu! %screenMode% -g !RPX_FILE_PATH! -mlc !MLC01_FOLDER_PATH! !noLeg! >> !batchFwLog!
        wscript /nologo !StartMaximizedWait! !cemu! %screenMode% -g !RPX_FILE_PATH! -mlc !MLC01_FOLDER_PATH! !noLeg!
        set /a cr_cemu=!ERRORLEVEL!
    )
    pushd !BFW_TOOLS_PATH!

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ >> !batchFwLog!
    REM : remove lock file
    del /F /S !lockFile! > NUL 2>&1

    if !usePbFlag! EQU 1 call:setProgressBar 0 6 "post processing" "analysing Cemu return code"

    REM : analyse CEMU's return code
    set "CEMU_STATUS=Loads"
    if %cr_cemu% NEQ 0 (
        echo !CEMU_FOLDER_NAME! failed^, return code ^: %cr_cemu% >> !batchFwLog!

        REM : is settingsImported = 1, delete shortcut and msbBox
        if !settingsImported! EQU 1 (

            REM : basename of previousSettingsFolder to get version of CEMU used to import settings
            for /F "delims=~" %%i in (!previousSettingsFolder!) do set "CEMU_IMPORTED=%%~nxi"
            !MessageBox! "!CEMU_FOLDER_NAME! crashed with settings imported from !CEMU_IMPORTED! ^(last version used to run the game^)^. Launch ^'Wii-U Games^\CEMU^\%CEMU_FOLDER_NAME%^\Delete my %CEMU_FOLDER_NAME%^'s settings^' and recreate your shortcuts without automatic import^, to be sure that is not related^." 4144
        ) else (
            REM : open log.txt
            wscript /nologo !Start! !MessageBox! "!CEMU_FOLDER_NAME! crashed^, openning its log ^.^.^."
            timeout /T 1 > NUL 2>&1
            wscript /nologo !Start! "%windir%\System32\notepad.exe" !cemuLog!
            timeout /T 1 > NUL 2>&1
            !cmdOw! log* /top

        )
        REM : set status to unplayable
        set "CEMU_STATUS=Unplayable"

    ) else (
        echo !CEMU_FOLDER_NAME! return code ^: %cr_cemu% >> !batchFwLog!

        REM : analyse log file
        type !cemuLog! | find /I "Exception" > NUL 2>&1 && (
            wscript /nologo !Start! !MessageBox! "!CEMU_FOLDER_NAME! return 0 but an exception was raised^, openning its log ^.^.^."
            timeout /T 1 > NUL 2>&1
            wscript /nologo !Start! "%windir%\System32\notepad.exe" !cemuLog!
            timeout /T 1 > NUL 2>&1
            !cmdOw! log* /top
            set /A "cr_cemu=99"
        )

    )

    if %cr_cemu% NEQ 0 goto:getTransCacheBack

    if !usePbFlag! EQU 1 call:setProgressBar 6 10 "post processing" "Compress save for !currentUser!"

    REM : saving game's saves for user
    set "bgs="!BFW_TOOLS_PATH:"=!\backupInGameSaves.bat""
    echo !bgs! !GAME_FOLDER_PATH! !MLC01_FOLDER_PATH! !user! !endTitleId! !slotNumber! >> !batchFwLog!
    wscript /nologo !StartHidden! !bgs! !GAME_FOLDER_PATH! !MLC01_FOLDER_PATH! !user! !endTitleId! !slotNumber!

    :getTransCacheBack
    REM : get SHADER_MODE
    set "SHADER_MODE=SEPARABLE"
    for /F "delims=~" %%i in ('type !cemuLog! ^| find /I "UseSeparableShaders: false"') do set "SHADER_MODE=CONVENTIONAL"

    if !usePbFlag! EQU 1 if %cr_cemu% NEQ 0 (
        call:setProgressBar 6 48 "post processing" "Save transferable shader cache"
    ) else (
        if !usePbFlag! EQU 1 call:setProgressBar 10 48 "post processing" "Save transferable shader cache"
    )

    echo SHADER_MODE=%SHADER_MODE%>> !batchFwLog!
    set "NEW_SHADER_CACHE_ID=UNKNOWN"
    REM : saving shaderCache
    call:transShaderCache

    REM : let file name with SHADER_MODE suffix
    if not ["%OLD_SHADER_CACHE_ID%"] == ["NONE"] echo OLD_TRANS_SHADER=%OLD_TRANS_SHADER%>> !batchFwLog!
    echo NEW_TRANS_SHADER=%NEW_TRANS_SHADER%>> !batchFwLog!

    REM : Recreate "!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt"
    del /F /S !gameInfoFile! > NUL 2>&1
    set "getTitleDataFromLibrary="!BFW_TOOLS_PATH:"=!\getTitleDataFromLibrary.bat""

    wscript /nologo !StartHiddenWait! !getTitleDataFromLibrary! "%titleId%" > !gameInfoFile!

    REM : get native FPS
    set "FPS=NOT_FOUND"
    for /F "tokens=2 delims=~=" %%i in ('type !gameInfoFile! ^| find /I "native FPS" 2^>NUL') do set "FPS=%%i"

    if !usePbFlag! EQU 1 call:setProgressBar 48 52 "post processing" "fill in compatibility reports"

    REM : report compatibility for CEMU_FOLDER_NAME and GAME on USERDOMAIN
    set "rc="!BFW_TOOLS_PATH:"=!\reportCompatibility.bat""

    wscript /nologo !StartHidden! !rc! !GAME_FOLDER_PATH! !CEMU_FOLDER! !user! %titleId% !MLC01_FOLDER_PATH! !CEMU_STATUS! !NEW_SHADER_CACHE_ID! !FPS!
    echo Compatibility reports updated for !GAME_TITLE! with !CEMU_FOLDER_NAME!>> !batchFwLog!

    echo !rc! !GAME_FOLDER_PATH! !CEMU_FOLDER! !user! %titleId% !MLC01_FOLDER_PATH! !CEMU_STATUS! !NEW_SHADER_CACHE_ID! !FPS! >> !batchFwLog!

    if !usePbFlag! EQU 1 call:setProgressBar 52 75 "post processing" "backup and remove !currentUser! save"

    REM : re-search your current GLCache (also here in case of first run after a drivers upgrade)
    REM : check last path saved in log file

    REM : Vulkan cache (CEMU >= 1.16)
    if ["!graphicApi!"] == ["Vulkan"] goto:searchCacheFolder

    REM : search in logFile, getting only the last occurence
    set "GPU_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "GPU_CACHE=%%i"

    if not [!GPU_CACHE!] == ["NOT_FOUND"] if exist !GPU_CACHE! goto:searchCacheFolder
    if not exist !GPU_CACHE! set "GPU_CACHE="NOT_FOUND""

    REM : else search it
    REM : first in CEMU folder
    if ["%gpuType%"]==["NVIDIA"] if exist !cemuGLcache! goto:searchCacheFolder

    pushd "%LOCALAPPDATA%"
    set "cache="NOT_FOUND""
    for /F "delims=~" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if [!cache!] == ["NOT_FOUND"] pushd "%APPDATA%" && for /F "delims=~" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if not [!cache!] == ["NOT_FOUND"] set "GPU_CACHE=!cache!"

    pushd !BFW_TOOLS_PATH!
    if [!GPU_CACHE!] == ["NOT_FOUND"] (
        echo Unable to find your GPU GLCache folder ^? backup will be disabled >> !batchFwLog!
        goto:analyseCemuLog
    )
    REM : save path to log file
    call:cleanHostLogFile OPENGL_CACHE
    set "msg="OPENGL_CACHE=!GPU_CACHE:"=!""
    call:log2HostFile !msg!

    REM set GPU_CACHE_PATH to GPU_CACHE
    set "GPU_CACHE_PATH=!GPU_CACHE!"

    :searchCacheFolder

    if !usePbFlag! EQU 1 if %cr_cemu% NEQ 0 call:setProgressBar 75 80 "post processing" "backup GPU cache"
    )

    REM : backup of GpuCache, get the last modified folder under GpuCache
    pushd !GPU_CACHE_PATH!
    set "newGpuCacheId=NOT_FOUND"
    for /F "delims=~" %%x in ('dir /A:D /O:D /T:W /B * 2^>NUL') do set "newGpuCacheId=%%x"
    pushd !BFW_TOOLS_PATH!

    if not ["%newGpuCacheId%"] == ["NOT_FOUND"] goto:whatToDo

    REM : if no shader cache folder is found
    REM : search for last modified bin file under GPU_CACHE (AMD GPU cache shaders without subfolders)
    pushd !GPU_CACHE!

    set "shaderCacheFileName=NOT_FOUND"
    for /F "delims=~" %%f in ('dir /O:D /T:W /B !sci:_shaders=!*.bin 2^>NUL ^| find /V "backup"') do set "shaderCacheFileName=%%~nf"
    pushd !BFW_TOOLS_PATH!

    if ["%shaderCacheFileName%"] == ["NOT_FOUND"] goto:warning

    REM : create a new folder to save GpuCache
    set "targetFolder="!gpuCacheSavesFolder:"=!\%GPU_VENDOR%@%GPU_DRIVERS_VERSION%\!GAME_TITLE!""
    if not exist !targetFolder! mkdir !targetFolder! > NUL 2>&1

    pushd !GPU_CACHE!
    for /F "delims=~" %%f in ('dir /O:D /T:W /B %shaderCacheFileName%.* 2^>NUL') do (
        set "file="%%f""
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !GPU_CACHE! !targetFolder! !file! /MT:32 /MOV /IS /IT > NUL 2>&1
    )
    if !v1182! LEQ 1 (
        pushd !precompFolder!
        for /F "delims=~" %%f in ('dir /O:D /T:W /B %shaderCacheFileName%_spirv.* 2^>NUL') do (
            set "file="%%f""
            wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !precompFolder! !targetFolder! !file! /MT:32 /MOV /IS /IT > NUL 2>&1
        )
    )
    pushd !BFW_TOOLS_PATH!

    REM : BatchFW will not delete the files already presents under targetFolder
    REM : if the gpu renames the files (64Mo each for AMD)
    goto:whatToDo

    :warning
    REM : if no files were found:
    echo WARNING ^: unable to find a last shaders cache under !GPU_CACHE_PATH!^, cancel GpuCache backup ^! >> !batchFwLog!
    goto:moveBack

    :whatToDo
    if ["%newGpuCacheId%"] == ["NOT_FOUND"] goto:moveBack
    if ["%oldGpuCacheId%"] == ["NOT_FOUND"] goto:getGpuCache
    if ["%oldGpuCacheId%"] == ["%newGpuCacheId%"] goto:moveBack

    REM : if GpuCacheId changed or oldGpuCacheId NOT_FOUND
    :getGpuCache
    set "newGpuCache="!GPU_CACHE_PATH:"=!\%newGpuCacheId%""

    if not ["%oldGpuCacheId%"] == ["NOT_FOUND"] (
        echo WARNING ^: Your display drivers have change OpenGL id for !CEMU_FOLDER_NAME! from %oldGpuCacheId% to %newGpuCacheId% ^! >> !batchFwLog!

        REM : log to host log file
        set "msg="!DATE!-your display drivers have change !CEMU_FOLDER_NAME! GLCache Id from %oldGpuCacheId% to %newGpuCacheId%=%folderName%""
        call:log2HostFile !msg!

    )

    REM : if a display drivers update was detected
    if %driversUpdateFlag% EQU 1 (
        if exist !idGpuFolder! rmdir /Q /S !idGpuFolder! > NUL 2>&1
    )

    if not [!gpuCacheSaved!] == ["NOT_FOUND"] (
        REM : remove old folder
        if exist !gpuCacheSaved! rmdir /Q /S !gpuCacheSaved! > NUL 2>&1
    )
    if not [!GpuCache!] == ["NOT_FOUND"] (
        REM : remove folder
        if exist !GpuCache! rmdir /Q /S !GpuCache! > NUL 2>&1
    )

    REM : create a new folder to save GpuCache
    set "newFolder="!gpuCacheSavesFolder:"=!\%GPU_VENDOR%@%GPU_DRIVERS_VERSION%\!GAME_TITLE!\%newGpuCacheId%""

    if not exist !newFolder! mkdir !newFolder! > NUL 2>&1

    REM : robocopy
    call:moveFolder !newGpuCache! !newFolder! cr
    if !cr! NEQ 0 (
        echo ERROR when moving !newGpuCache! !newFolder!^, cr=%cr% >> !batchFwLog!
    ) else (
        echo Update GPU Cache in !newFolder!>> !batchFwLog!
        goto:analyseCemuLog
    )

    REM : move back
    :moveBack

    if [!GpuCache!] == ["NOT_FOUND"] goto:analyseCemuLog
    if exist !GpuCache! call:moveFolder !GpuCache! !gpuCacheSaved! cr
    if !cr! NEQ 0 (
        !MessageBox! "ERROR While moving back GPU Cache save, please close all explorer.exe open in GPU cache folder" 4113
        if !ERROLRLEVEL! EQU 1 goto:moveBack
        wscript /nologo !Start! !MessageBox! "WARNING : relaunch the game until GPU Cache is backup sucessfully, if it persists close your session and retry"
    )

    :analyseCemuLog

    call:createLogShorcut

    if %cr_cemu% NEQ 0 goto:analyseCemuTitleId
    if !usePbFlag! EQU 1 call:setProgressBar 80 92 "post processing" "analyse and move back transferable cache"

    REM : analyse CEMU's log
    if not exist !cemuLog! goto:titleIdChecked

    REM : if BatchFw complete GFX packs, check if CEMU log contains 'contains inconsistent preset variables'
    type !logFile! | find /I "COMPLETE_GP" > NUL && (
        type !cemuLog! | find /I "contains inconsistent preset variables" > NUL && !MessageBox! "WARNING : some presets built by BatchFw are not valid, disable GFX packs completion in BatchFw and force a GFX pack update" 4144
    )

    :analyseCemuTitleId
    REM : check that CEMU recognize the game
    set "UNKNOW_GAME=00050000ffffffff"
    set "cemuTitleLine="NONE""

    for /F "delims=~" %%i in ('type !cemuLog! ^| find /I "TitleId"') do (
        set "cemuTitleLine="%%i""
        goto:firstOcTitle
    )
    :firstOcTitle
    if !usePbFlag! EQU 1 call:setProgressBar 92 96 "post processing" "analysing Cemu titleId"

    if not [!cemuTitleLine!] == ["NONE"] goto:cemuTitleIdExist

    if not [!PROFILE_FILE!] == ["NOT_FOUND"] (
        !MessageBox! "WARNING : TitleId not found in Cemu's log! CEMU has crashed ? Disabling saving options and exiting!" 4144
        goto:endMain
    )
    :cemuTitleIdExist

    for /F "tokens=1-4 delims=:" %%i in (!cemuTitleLine!) do set "str="%%l""
    set "str=!str: =!"
    set "str=!str:-=!"
    set "cemuTitleId=!str:"=!"

    echo metaTitleId=%titleId%>> !batchFwLog!
    echo cemuTitleId=%cemuTitleId%>> !batchFwLog!
    if /I ["%cemuTitleId%"] == ["%UNKNOW_GAME%"] goto:unknownGame

    if /I [!PROFILE_FILE!] == ["NOT_FOUND"] (
        set "cemuProfile="!CEMU_FOLDER:"=!\gameProfiles\%cemuTitleId%.ini""
        if exist !cemuProfile! goto:useCemuTitleId
        REM : if no game's profile file is found, it will be created in wizardFirstSaving.bat
    )

    REM : no problems, goto titleIdChecked
    if /I ["%cemuTitleId%"] == ["%titleId%"] goto:titleIdChecked

    if ["%cemuTitleId%"] == [""] (
        !MessageBox! "Warning : TitleId not found in Cemu's log! CEMU has crashed? Disabling saving options and exiting!" 4144
        goto:endMain
    )

    REM : if title id does not macth between CEMU and game's meta folder
    echo --------------------------------------------------------->> !batchFwLog!
    echo Warning ^: CEMU and GAME Title Id not matching  ^!^, disabling saving options ^!>> !batchFwLog!
    echo meta file titleId ^: %titleId%>> !batchFwLog!
    echo cemu titleId      ^: %cemuTitleId%>> !batchFwLog!
    echo Have you updated the game or installed a DLC for another version ^(US^/EUR^/JPN^) ^?>> !batchFwLog!
    if %wizardLaunched% EQU 1 (
        echo CEMU log.txt    : %cemuTitleId%>> !batchFwLog!
        echo meta/metax.xml  : %titleId%>> !batchFwLog!
        rmdir /Q /S !SETTINGS_FOLDER! > NUL 2>&1
    )
    !MessageBox! "ERROR : CEMU and GAME TitleId not matching !, disable saving options" 4112
    goto:endMain

    :useCemuTitleId
    set titleId=%cemuTitleId%
    goto:titleIdChecked

    if /I not "%cemuTitleId%" == "%UNKNOW_GAME%" goto:titleIdChecked

    :unknownGame
    echo --------------------------------------------------------->> !batchFwLog!
    echo ERROR ^: UNKNOWN GAME TitleId detected in CEMU Log.txt ^!^, disabling saving options ^!>> !batchFwLog!
    echo Have you updated the game or installed a DLC ^?>> !batchFwLog!
    echo TOFIX ^: reinstall game^'s update over ^!>> !batchFwLog!
    if %wizardLaunched% EQU 1 (
        echo CEMU log.txt    ^: %cemuTitleId%>> !batchFwLog!
        echo meta/metax.xml  ^: %titleId%>> !batchFwLog!
        rmdir /Q /S !SETTINGS_FOLDER! > NUL 2>&1
    )
    !MessageBox! "ERROR : UNKNOWN GAME TitleId detected in CEMU Log.txt !, disable saving options" 4112
    goto:endMain

    :titleIdChecked

    REM : stoping user's software
    type !logFile! | find /I "TO_BE_LAUNCHED" | find /I "@Y"> NUL 2>&1 && (
        echo Stoping third party software >> !batchFwLog!

        set "stopThirdPartySoftware="!BFW_TOOLS_PATH:"=!\stopThirdPartySoftware.bat""
        wscript /nologo !StartHidden! !stopThirdPartySoftware! >> !batchFwLog!
    )

    if %cr_cemu% NEQ 0 goto:endMain

    if exist !userGameSave! (
        echo Compressing game^'s saves for !currentUser! in !userGameSave! >> !batchFwLog!
    )

    REM : if exist a problem happen with shaderCacheId, write new "!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt"
    if exist !tscl! (
        echo --------------------------------------------------- >> !tscl!
        echo GAME_CONFIGURATION after launching !CEMU_FOLDER_NAME! ^: >> !tscl!
        if exist !gameInfoFile! type !gameInfoFile! >> !tscl!
    )
    if !usePbFlag! EQU 1 call:setProgressBar 96 98 "post processing" "saving settings for !currentUser!"

    call:saveCemuOptions

    :endMain


    REM : copy otp.bin and seeprom.bin if needed
    set "t1="!CEMU_FOLDER:"=!\otp.bin""
    set "t2="!CEMU_FOLDER:"=!\seeprom.bin""
    set "t1o="!CEMU_FOLDER:"=!\otp.bfw_old""
    set "t2o="!CEMU_FOLDER:"=!\seeprom.bfw_old""

    if not exist !t1! goto:restoreGp
    if not exist !t2! goto:restoreGp

    set "s1="!BFW_ONLINE:"=!\otp.bin""
    set "s2="!BFW_ONLINE:"=!\seeprom.bin""

    if exist !s1! (
        del /F !t1! > NUL 2>&1
        if exist !t1o! (
            move /Y !t1o! !t1! > NUL 2>&1
        )
    )
    if exist !s2! (
        del /F !t2! > NUL 2>&1
        if exist !t2o! (
            move /Y !t2o! !t2! > NUL 2>&1
        )
    )

    :restoreGp
    REM : restore CEMU's graphicPacks subfolder
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    rmdir /Q /S !graphicPacks! > NUL 2>&1
    if exist !graphicPacksBackup! move /Y !graphicPacksBackup! !graphicPacks! > NUL 2>&1
    if not exist !graphicPacks! mkdir !graphicPacks! > NUL 2>&1

    if !usePbFlag! EQU 1 if %cr_cemu% NEQ 0 (
        call:setProgressBar 96 100 "post processing" "waiting child processes end before exiting"
    ) else (
        if !usePbFlag! EQU 1 call:setProgressBar 98 100 "post processing" "waiting child processes end before exiting"
    )

    REM : clean GFX packs links in game's folder
    for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        rmdir /Q !gpLink! > NUL 2>&1
    )

    REM : clean old update folder (this folder in created by links to 00050000e and 00050000c in updateGameGraphicPacks)
    REM : to avoid red hightlining in CEMU
    set "oldUpdateLocation="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000""
    rmdir /Q /S !oldUpdateLocation! > NUL 2>&1

    REM : restoreBackups
    if exist !cs! call:restoreFile !cs!
    if exist !csb! call:restoreFile !csb!
    if exist !chs! call:restoreFile !chs!

    REM : del log folder for fnr.exe
    if exist !fnrLogFolder! rmdir /Q /S !fnrLogFolder! > NUL 2>&1

    echo =========================================================>> !batchFwLog!
    echo Waiting the end of all child processes before ending ^.^.^.>> !batchFwLog!

    if %cr_cemu% EQU 0 if exist !userGameSave! (
        set "logFileTmp="!TMP:"=!\BatchFw_process.list""

        :waitRar
        wmic process get Commandline 2>NUL | find  ".exe" | find /I /V "wmic" | find /I /V "find" > !logFileTmp!

        type !logFileTmp! | find /I !GAMES_FOLDER! | find /I "rar.exe" | find /V "Winrar.exe" > NUL 2>&1 && goto:waitRar

        call:checkUserSave

        REM : remove trace
        del /F !logFileTmp! > NUL 2>&1

    )

    exit 0

    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

REM : must run in !igsvf! !
    :getUserSave

        REM : contains the active slot (relative path to the rar file)
        set "userActiveSlotFile="!GAME_TITLE!_!currentUser!_activeSlot.txt""

        REM : if not exist slotNumber=0
        if not exist !userActiveSlotFile! goto:eof

        for /F "delims=~" %%i in ('type !userActiveSlotFile! 2^>NUL') do set "activeSave="%%i""

        if not exist !activeSave! goto:eof
        
        REM : activeSave = !GAME_TITLE!_!currentUser!_slot%slotNumber%.rar""
        set "activeTextFile=!activeSave:.rar=.txt!"

        set "str=!activeSave:"=!"
        set "str=!str:~-5!"
        set /A "slotNumber=!str:.rar=!"

        for /F "delims=~" %%i in ('type !activeTextFile! 2^>NUL') do set "slotLabel="%%i""
        echo !currentUser! use the slot!slotNumber! [!slotLabel:"=!]>> !batchFwLog!

        set "%1=!activeSave!"

        
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

    :checkUserSave

        REM : get the size of the new save file
        set /A "newSaveSize=0"
        for /F "tokens=*" %%a in (!userGameSave!)  do set /A "newSaveSize=%%~za"

        if not exist !saveBackup! goto:eof

        REM : get backup N save file size
        set /A "oldSaveSize=0"
        for /F "tokens=*" %%a in (!saveBackup!)  do set /A "oldSaveSize=%%~za"
        echo --------------------------------------------------- >> !batchFwLog!
        echo ---------------------------------------------------
        echo Save archive file size ^: !newSaveSize!>> !batchFwLog!
        echo Save archive file size ^: !newSaveSize!
        echo Save backup file size  ^: !oldSaveSize!>> !batchFwLog!
        echo Save backup file size  ^: !oldSaveSize!
        echo --------------------------------------------------- >> !batchFwLog!
        echo ---------------------------------------------------
        REM : set a threshold at 90
        set /A "half=oldSaveSize/2"

        set /A "saveSizeThreshold=oldSaveSize-half"

        REM : compare sizes : > ~90% => OK
        if !newSaveSize! GEQ !saveSizeThreshold! goto:eof

        REM : KO => warn user and propose to restore backup N
        !MessageBox! "Save file size ^(!newSaveSize! bytes^) is at least half smaller than the backuped one ^(!oldSaveSize! bytes^)^! If you have modify^/reset your save or delete slots while in game ^: ignore this message [NO] else your save might be corrupted ^: revert last backup file [YES]^?" 4148
        if !ERRORLEVEL! EQU 7 goto:eof

        REM : revert save file backup
        copy /Y !saveBackup! !userGameSave! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :getShaderCacheName

        pushd !getShaderCacheFolder!

        for /F %%l in ('getShaderCacheName.exe !RPX_FILE_PATH!') do set "sci=%%l"

        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------

    :setProgressBar
        set /A "p1=%~1"
        set /A "p2=%~2"
        set "phase="%~3""
        set "step="%~4""

        if !p2! NEQ 100 (
            wscript /nologo !StartHidden! !progressBar! !p1! !p2! !phase! !step!
        ) else (
            if [!phase!] == ["pre processing"] (
                wscript /nologo !StartHiddenWait! !progressBar! !p1! 100 !phase! !step!
            ) else (
                wscript /nologo !StartHidden! !progressBar! !p1! 100 !phase! !step!
            )
        )

        goto:eof

    REM : function to backup an EXISTANT file
    :backupFile
        set "file="%~1%""
        set "fileBackup="!file:"=!_bfw_old""

        if exist !fileBackup! (
            REM : last execution failed : restore backup before continue
            del /F !file! > NUL 2>&1
            move /Y !fileBackup! !file! > NUL 2>&1
        )

        copy /Y !file! !fileBackup! > NUL 2>&1

    goto:eof

    REM : function to restore an EXISTANT file
    :restoreFile
        set "file="%~1%""
        set "tmpFile="!file:"=!_bfw_tmp""
        if exist !tmpFile! del /F !tmpFile! > NUL 2>&1

        set "fileBackup="!file:"=!_bfw_old""

        if not exist !fileBackup! goto:eof

        del /F !file! > NUL 2>&1
        move /Y !fileBackup! !file! > NUL 2>&1

    goto:eof

    :cleanHostLogFile

        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.bfw_tmp""

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL 2>&1
        move /Y !logFileTmp! !logFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------
    set /A "disp=0"
    :waitProcessesEnd

        REM : debug trace
rem        set "launchGameLogFileTmp="!TMP:"=!\BatchFw_process.beforeWaiting""
rem        wmic process get Commandline | find  ".exe" | find /I /V "wmic" | find /I /V "find" > !launchGameLogFileTmp!

        set "launchGameLogFileTmp="!TMP:"=!\BatchFw_launchGame_process.list""

        :waitingLoopProcesses
        wmic process get Commandline 2>NUL | find  ".exe" | find /I /V "wmic" > !launchGameLogFileTmp!

        type !launchGameLogFileTmp! | find /I "_BatchFW_Install" | find /I "updateGameStats.bat" | find /I /V "find" > NUL 2>&1 && (
            echo waitProcessesEnd : updateGameStats still running >> !batchFwLog!
            goto:waitingLoopProcesses
        )
        type !launchGameLogFileTmp! | find /I "copy" | find /I "!CEMU_FOLDER_NAME!" | find /I /V "find" > NUL 2>&1 && (
            echo waitProcessesEnd : a copy is still running >> !batchFwLog!
            goto:waitingLoopProcesses
        )
        type !launchGameLogFileTmp! | find /I "rar.exe" | find /I /V "winRar" | find /I !GAMES_FOLDER! | find /I /V "find" > NUL 2>&1 && (
            echo waitProcessesEnd : rar^.exe still running >> !batchFwLog!
            goto:waitingLoopProcesses
        )
        type !launchGameLogFileTmp! | find /I "_BatchFW_Install" | find /I "updateGraphicPacksFolder.bat"  | find /I /V "find" > NUL 2>&1 && (
            echo waitProcessesEnd : updateGraphicPacksFolder still running >> !batchFwLog!
            goto:waitingLoopProcesses
        )

        type !launchGameLogFileTmp! | find /I "_BatchFW_Install" | find /I "GraphicPacks.bat" | find /I /V "find" > NUL 2>&1 && (

            echo waitProcessesEnd : graphic packs scripts still running >> !batchFwLog!
            if !disp! EQU 0 (
                type !launchGameLogFileTmp! | find /I "_BatchFW_Install" | find /I "GraphicPacks.bat" | find /I /V "updateGame" | find /I /V "find" > NUL 2>&1 && (
                    echo Creating ^/ completing graphic packs^, please wait ^.^.^. >> !batchFwLog!
                    if !usePbFlag! EQU 1 call:setProgressBar 90 94 "pre processing" "GFX packs creation^/completion^, please wait"
                    set /A "disp=1"
                )
            )
            goto:waitingLoopProcesses
        )
        if !usePbFlag! EQU 1 if !wizardLaunched! EQU 0 (
            call:setProgressBar 94 96 "pre processing" "waiting all child processes end^.^.^."
        )

        REM : remove trace
        del /F !launchGameLogFileTmp! > NUL 2>&1

        if !slotNumber! NEQ 0 wscript /nologo !Start! !MessageBox! "You are using the slot !slotNumber! [!slotLabel:"=!]. To change use '!currentUser!\_BatchFw - set extra slots saves.lnk'" pop8sec


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

        REM : source drive
        for %%a in (!source!) do set "sourceDrive=%%~da"

        REM : target drive
        for %%a in (!target!) do set "targetDrive=%%~da"

        REM : if folders are on the same drive
        if ["!sourceDrive!"] == ["!targetDrive!"] (

            for %%a in (!target!) do set "parentFolder="%%~dpa""
            set "parentFolder=!parentFolder:~0,-2!""
            if exist !target! rmdir /Q /S !target! > NUL 2>&1

            REM : use move command (much more faster)
            move /Y !source! !parentFolder! > NUL 2>&1
            set /A "cr=%ERRORLEVEL%"
            if !cr! EQU 1 (
                set /A "%3=1"
            ) else (
                set /A "%3=0"
            )

           goto:eof
        )

        REM : else robocopy
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !source! !target! /S /MT:32 /MOVE /IS /IT > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! GTR 7 set /A "%3=1"
        if !cr! GEQ 0 set /A "%3=0"

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

            REM : WUP restrictions
            set "string=!string:?=!"
            set "string=!string:?=!"
            set "string=!string:?=!"
            set "string=!string:?=E!"

        )
        set "%2="!string!""

    goto:eof
    REM : ------------------------------------------------------------------

    :getModifiedFile
        set "folder="%~1""
        set "pattern="%~2""
        set "way=-First"

        if ["%~3"] == ["first"] set "way=-Last"

        set "psCommand="Get-ChildItem -recurse -Path !folder:"='! -Filter !pattern:"='! ^| Sort-Object LastAccessTime -Descending ^| Select-Object !way! 1 ^| Select -ExpandProperty FullName""
        for /F "delims=~" %%a in ('powershell !psCommand! 2^>NUL') do set "%4="%%a"" && goto:eof
        set "%4="NOT_FOUND""
    goto:eof
    REM : ------------------------------------------------------------------

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


    :loadCemuOptions


        REM : backup all settings file under CEMU_FOLDER
        if exist !cs! call:backupFile !cs!
        if exist !csb! call:backupFile !csb!
        if exist !chs! call:backupFile !chs!

        set "cemuProfile="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""
        REM : do not consult default subfolder
        if exist !cemuProfile! set "PROFILE_FILE=!cemuProfile!"
        REM : else leave at NOT_FOUND, it will be created in wizardFirstLaunch.bat

        REM : check if it is already a link (case of crash) : delete-it
        set "pat="!CEMU_FOLDER:"=!\*graphicPacks*""
        for /F "delims=~" %%a in ('dir /A:L /B !pat! 2^>NUL') do rmdir /Q !graphicPacks! > NUL 2>&1

        if exist !graphicPacksBackup! (
            rmdir /Q /S !graphicPacks!  > NUL 2>&1
            move /Y !graphicPacksBackup! !graphicPacks! > NUL 2>&1
        )

        REM : remove saves but not before BatchFw first run
        if exist !gameInfoFile! for /F %%i in ('type !gameInfoFile! ^| find "Last launch with" 2^>NUL') do (

            REM : delete current saves in mlc01
            set "saveFolder="!MLC01_FOLDER_PATH:"=!\usr\save""
            for /F "delims=~" %%i in ('dir /b /o:n /a:d !saveFolder! 2^>NUL') do call:removeSaves "%%i"
        )

        if !usePbFlag! EQU 1 call:setProgressBar 54 60 "pre processing" "installing settings for !currentUser!"

        if exist !SETTINGS_FOLDER! goto:loaded

        REM : else search for a suitable settings

        set "CEMU_PF="%CEMU_FOLDER:"=%\gameProfiles""
        REM : search for the last modified settings folder
        set "previousSettingsFolder="NONE""

        REM : get path to CEMU installs folder
        for %%a in (!CEMU_FOLDER!) do set "parentFolder="%%~dpa""
        set "CEMU_INSTALLS_FOLDER=!parentFolder:~0,-2!""

        REM : if no import goto:continueLoad
REM        if ["!AUTO_IMPORT_MODE!"] == ["DISABLED"] goto:continueLoad

        REM : search for valid settings
        call:getSettingsFolder

        :continueLoad
        if [!previousSettingsFolder!] == ["NONE"] (
            set /A "wizardLaunched=1"
            REM : PROFILE_FILE for game that still not exist in CEMU folder = NOT_FOUND (first run on a given host)

            set "wfs="!BFW_TOOLS_PATH:"=!\wizardFirstSaving.bat""
            echo !wfs! !CEMU_FOLDER! "!GAME_TITLE!" !PROFILE_FILE! !SETTINGS_FOLDER! !user! !RPX_FILE_PATH! !IGNORE_PRECOMP!>> !batchFwLog!

            !cmdOw! BatchFw* /MIN > NUL 2>&1
            cls
            wscript /nologo !StartWait! !wfs! !CEMU_FOLDER! "!GAME_TITLE!" !PROFILE_FILE! !SETTINGS_FOLDER! !user! !RPX_FILE_PATH! !IGNORE_PRECOMP!
            !cmdOw! @ /MIN > NUL 2>&1
            !cmdOw! @ /HID > NUL 2>&1
            if !usePbFlag! EQU 1 call:setProgressBar 60 70 "pre processing" "installing settings for !currentUser!"

            goto:beforeLoad
        )
        if !usePbFlag! EQU 1 call:setProgressBar 60 70 "pre processing" "installing settings for !currentUser!"

        set "PROFILE_FILE="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""
        if not exist !OLD_PROFILE_FILE! goto:createGameProfile

        REM : import OLD_PROFILE_FILE
        copy /Y !OLD_PROFILE_FILE! !PROFILE_FILE!  > NUL 2>&1 && goto:patchGameProfile

        :createGameProfile

        REM : Now BatchFw ignores the default game profile given by CEMU when importing
        REM : CEMU is not affected by unused (newer) instructions in the game's profile
        REM : only enums and integers have to be eventually changed in function of the
        REM : version of CEMU launched.

        echo # !GAME_TITLE!>!PROFILE_FILE!
        echo [Graphics]>>!PROFILE_FILE!

        REM : try to use the default value of GPUBufferCacheAccuracy
        set "dp="!CEMU_FOLDER:"=!\gameProfiles\default\%titleId%.ini""
        set "dgbc=NONE"
        if exist !dp! (
            type !dp! | find "GPUBufferCacheAccuracy" > NUL 2>&1 && (
                for /F "tokens=2 delims=~=" %%g in ('type !dp! ^| find "GPUBufferCacheAccuracy" 2^>NUL') do set "dgbc=%%g"
            )
        )
        set "gbc=low"
        if not ["!dgbc!"] == ["NONE"] set "gbc=!dgbc: =!"
        echo GPUBufferCacheAccuracy = !gbc!>>!PROFILE_FILE!

        echo disableGPUFence = false>>!PROFILE_FILE!
        echo accurateShaderMul = min>>!PROFILE_FILE!

        if !v1158! LEQ 1 (
            set "precompShaderState=enable"
            if ["!gpuType!"] == ["NVIDIA"] (
                set "precompShaderState=disable"
            )
            echo precompiledShaders = !precompShaderState!>>!PROFILE_FILE!
        ) else (
            set "precomShaderFlag=true"
            if ["!gpuType!"] == ["NVIDIA"] (
                set "precomShaderFlag=false"
            )
            echo disablePrecompiledShaders = !precomShaderFlag!>>!PROFILE_FILE!
        )

        echo [CPU]>>!PROFILE_FILE!
        echo cpuTimer = hostBased>>!PROFILE_FILE!
        echo cpuMode = Auto>>!PROFILE_FILE!
        echo threadQuantum = 100000>>!PROFILE_FILE!

        set "pat="!GAMES_FOLDER:"=!\_BatchFW_Controller_Profiles\*.txt""
        REM : loop on all file found (reverse sorted by date => exit loop whith the last modified one)
        for /F "delims=~" %%i in ('dir /B /O:-D /T:W !pat!  2^>NUL') do set "lastController="%%i""

        REM : basename of GAME FOLDER PATH (used to name shorcut)
        for /F "delims=~" %%i in (!lastController!) do set "controllerName=%%~nxi"

        echo [Controller]>>!PROFILE_FILE!
        echo controller1 = !controllerName:.txt=!>>!PROFILE_FILE!

        :patchGameProfile
        REM : PROFILE FILE Mapping (CEMU's version of PROFILE_FILE is undefined here)
        REM : --------------------
        REM : (profile file are not saved by BatchFw and remain with CEMU installations)

        REM : log file
        set "fnrLogFile="!fnrLogFolder:"=!\gameProfile.log""

        REM : v1.15.6 replace integer values by enums for gpuBufferCacheAccuracy

        REM : versionRead >= v1.15.6 goto:supOrEqualv1156
        if !v1156! LEQ 1 goto:supOrEqualv1156

        REM : versionRead < 1.15.6 replace enums by integers (if found/need)
        type !PROFILE_FILE! | find /I "gpuBufferCacheAccuracy" | find /I "low" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "gpuBufferCacheAccuracy[ ]*=[ ]*low" --replace "gpuBufferCacheAccuracy = 2" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "gpuBufferCacheAccuracy" | find /I "medium" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "gpuBufferCacheAccuracy[ ]*=[ ]*medium" --replace "gpuBufferCacheAccuracy = 1" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "gpuBufferCacheAccuracy" | find /I "high" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "gpuBufferCacheAccuracy[ ]*=[ ]*high" --replace "gpuBufferCacheAccuracy = 0" --logFile !fnrLogFile!

        REM : all treatments below are for versionRead >= 1.15.6
        goto:checkCpuMode

        :supOrEqualv1156
        REM : versionRead >= 1.15.6

        REM : if needed (found) replace integers by enums
        type !PROFILE_FILE! | find /I "gpuBufferCacheAccuracy" | find /I "2" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "gpuBufferCacheAccuracy[ ]*=[ ]*2" --replace "gpuBufferCacheAccuracy = low" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "gpuBufferCacheAccuracy" | find /I "1" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "gpuBufferCacheAccuracy[ ]*=[ ]*1" --replace "gpuBufferCacheAccuracy = medium" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "gpuBufferCacheAccuracy" | find /I "0" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "gpuBufferCacheAccuracy[ ]*=[ ]*0" --replace "gpuBufferCacheAccuracy = high" --logFile !fnrLogFile!

        REM : versionRead >= v1.15.8 goto:supOrEqualv1158
        if !v1158! LEQ 1 goto:supOrEqualv1158
        REM : use disablePrecompiledShaders
        type !PROFILE_FILE! | find /I "precompiledShaders" | find /I "true" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "precompiledShaders[ ]*=[ ]*true" --replace "disablePrecompiledShaders = true" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "precompiledShaders" | find /I "false" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "precompiledShaders[ ]*=[ ]*false" --replace "disablePrecompiledShaders = false" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "precompiledShaders" | find /I "auto" > NUL 2>&1 && (
            if ["!gpuType!"] == ["NVIDIA"] (
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "precompiledShaders[ ]*=[ ]*auto" --replace "disablePrecompiledShaders = true" --logFile !fnrLogFile!
            ) else (
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "precompiledShaders[ ]*=[ ]*auto" --replace "disablePrecompiledShaders = false" --logFile !fnrLogFile!
            )
        )

        :supOrEqualv1158
        REM : use precompiledShaders
        type !PROFILE_FILE! | find /I "disablePrecompiledShaders" | find /I "true" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "disablePrecompiledShaders[ ]*=[ ]*true" --replace "precompiledShaders = true" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "disablePrecompiledShaders" | find /I "false" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "disablePrecompiledShaders[ ]*=[ ]*false" --replace "precompiledShaders = false" --logFile !fnrLogFile!

        REM : v1.21.0+ introduce Single-core/Multi-core enums instead of Single/Dual/TripleCore-recompiler

        REM : versionRead >= v1.21.0 goto:supOrEqualv121
        if !v121! LEQ 1 goto:supOrEqualv121

        :checkCpuMode
        REM : versionRead < 1.21.0 replace enums by integers (if found/need)

        REM : compute recommended mode (including for 1.21.5)
        REM : get CPU threads number
        for /F "delims=~= tokens=2" %%c in ('wmic CPU Get NumberOfLogicalProcessors /value ^| find "="') do set /A "nbCpuThreads=%%c"
        set "recommendedMode=SingleCore-recompiler"

        REM : CEMU singleCore (1) GPU (1) Audio+misc (1)
        set /A "cpuNeeded=3"

        if ["!gpuType!"] == ["NVIDIA"] (
            set /A "cpuNeeded+=1"
        )
        if !nbCpuThreads! GTR !cpuNeeded! (
            set "recommendedMode=DualCore-recompiler"
            set /A "cpuNeeded+=1"
            if !nbCpuThreads! GEQ !cpuNeeded! set "recommendedMode=TripleCore-recompiler"
        )

        REM : replace Single/Multi-core with recommendedMode
        type !PROFILE_FILE! | find /I "cpuMode" | find /I "Single-core recompiler" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "cpuMode[ ]*=[ ]*Single-core recompiler" --replace "cpuMode = SingleCore-recompiler" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "cpuMode" | find /I "Multi-core recompiler" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "cpuMode[ ]*=[ ]*Multi-core recompiler" --replace "cpuMode = !recommendedMode!" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "cpuMode" | find /I "Auto" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "cpuMode[ ]*=[ ]*Auto" --replace "cpuMode = !recommendedMode!" --logFile !fnrLogFile!

        REM : all treatments below are for versionRead >= 1.21.0
        goto:syncCP

        :supOrEqualv121
        REM : versionRead >= 1.21.0

        REM : if needed (found) replace Single/Dual/TripleCore-recompiler with Single/Multi-core
        type !PROFILE_FILE! | find /I "cpuMode" | find /I "SingleCore-recompiler" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "cpuMode[ ]*=[ ]*SingleCore-recompiler" --replace "cpuMode = Single-core recompiler" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "cpuMode" | find /I "DualCore-recompiler" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "cpuMode[ ]*=[ ]*DualCore-recompiler" --replace "cpuMode = Multi-core recompiler" --logFile !fnrLogFile!
        type !PROFILE_FILE! | find /I "cpuMode" | find /I "TripleCore-recompiler" > NUL 2>&1 && wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !CEMU_PF! --useRegEx --fileMask !titleId!.ini --find "cpuMode[ ]*=[ ]*TripleCore-recompiler" --replace "cpuMode = Multi-core recompiler" --logFile !fnrLogFile!

        :syncCP

        REM : synchronized controller profiles (import)
        call:syncControllerProfiles
        echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!^\ControllerProfiles vs _BatchFW_Controller_Profiles^\!USERDOMAIN!^)>> !batchFwLog!

        if ["!AUTO_IMPORT_MODE!"] == ["DISABLED"] (
            !MessageBox! "Adapt !OLD_CEMU_VERSION! settings for !CEMU_FOLDER_NAME!?" 4145
            if !ERRORLEVEL! EQU 2 (
                set "previousSettingsFolder="NONE""
                goto:continueLoad
            )
            if !v11515! LEQ 1 (
                wscript /nologo !Start! !MessageBox! "Check all settings ^(set^/modify if needed^)^. Use ^'Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!^\Games Profiles^\!GAME_TITLE!^.lnk^' to edit the game^'s profile^. Online mode may not work only on the first run ^(due to CEMU that might reformat the settings^.xml^)^, relaunch if you want to play online^. To cancel the import^, delete the settings using ^'Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!^\Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk^'^,relaunch and refuse the import^."
            ) else (
                wscript /nologo !Start! !MessageBox! "Check all settings ^(set^/modify if needed^)^. Use ^'Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!^\Games Profiles^\!GAME_TITLE!^.lnk^' to edit the game^'s profile^. To cancel the import^, delete the settings using ^'Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!^\Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk^'^,relaunch and refuse the import^."
            )
        ) else (
            wscript /nologo !Start! !MessageBox! "Check all settings (set/modify if needed). Use 'Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles\!GAME_TITLE!.lnk' to edit the game's profile. To cancel the import, delete the settings using 'Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Delete all my !CEMU_FOLDER_NAME!'s settings.lnk',relaunch and refuse the import."
        )

        set "nsf="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\!CEMU_FOLDER_NAME!""
        echo Import settings from !previousSettingsFolder:"=! >> !batchFwLog!

        set /A "settingsImported=1"
        robocopy !previousSettingsFolder! !nsf! /MT:32 /S > NUL 2>&1

        set "csi="!nsf:"=!\!currentUser!_settings.xml""
        if exist !csi! (
            set "csTmp0=!csi:.xml=.bfw_tmp0!"

            REM : if versionRead < 1.16 force Graphic api to 0
            if !v116! EQU 2 (

                echo Forcing API to OpenGL if needed >> !batchFwLog!

                !xmlS! ed -u "//Graphic/api/text()" -v 0  !csi! > !csTmp0! 2>NUL
                if exist !csTmp0! (
                    del /F !csi! > NUL 2>&1
                    move /Y !csTmp0! !csi! > NUL 2>&1
                )
            )
        )
        
        REM : log to games library log file
        set "msg="!GAME_TITLE!:!DATE!-!currentUser!@!USERDOMAIN! import settings in !nsf:"=! from=!previousSettingsFolder:"=!""
        call:log2GamesLibraryFile !msg!

        :beforeLoad

        REM : if wizard was launched set PROFILE_FILE because it was not found earlier
        set "cemuProfile="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""
        if exist !cemuProfile! set "PROFILE_FILE=!cemuProfile!"

        :loaded
        for /F "delims=~" %%i in (!SETTINGS_FOLDER!) do set "settingsFolderName=%%~nxi"

        echo Using settings from !settingsFolderName! for !currentUser! ^!>> !batchFwLog!

        REM : looking for last modified *settings to create !user!_settings
        call:setSettingsForUser

        REM : loading CEMU settings
        set "binUser="!SETTINGS_FOLDER:"=!\!currentUser!_settings.bin""
        if exist !binUser! (
            robocopy !SETTINGS_FOLDER! !CEMU_FOLDER! "!currentUser!_settings.bin" /MT:32 > NUL 2>&1
            set "src="!CEMU_FOLDER:"=!\!currentUser!_settings.bin""
            if exist !src! (
                if exist !csb! del /F !csb! > NUL 2>&1
                move /Y !src! !csb! > NUL 2>&1
            )
        )
        set "xmlUser="!SETTINGS_FOLDER:"=!\!currentUser!_settings.xml""
        if exist !xmlUser! (
            robocopy !SETTINGS_FOLDER! !CEMU_FOLDER! "!currentUser!_settings.xml" /MT:32 > NUL 2>&1
            set "src="!CEMU_FOLDER:"=!\!currentUser!_settings.xml""
            if exist !src! (
                if exist !cs! del /F !cs! > NUL 2>&1
                move /Y !src! !cs! > NUL 2>&1
            )
        )
        if !wizardLaunched! EQU 1 goto:cemuHookSettings

        REM : if current version >=1.15.15
        if !v11515! GEQ 1 (
            REM : compare with 1.15.18
            call:compareVersions !versionRead! "1.15.18" result > NUL 2>&1
            if ["!result!"] == [""] echo Error when comparing versions >> !batchFwLog!
            if !result! EQU 50 echo Error when comparing versions >> !batchFwLog!
            REM : if version of CEMU < 1.15.18, CEMU do not track playtime when launching a game via command line (bug#206) => goto:cemuHookSettings
            if !result! EQU 2 goto:cemuHookSettings
        ) else (
            goto:cemuHookSettings
        )
        set "rpxFilePath=!RPX_FILE_PATH!"

        if !usePbFlag! EQU 1 call:setProgressBar 70 78 "pre processing" "updating games stats"

        REM : update !cs! games stats for !GAME_TITLE!
        set "sf="!GAME_FOLDER_PATH:"=!\Cemu\settings""
        set "lls="!sf:"=!\!currentUser!_lastSettings.txt"

        if not exist !lls! (
            echo Warning ^: no last settings file found >> !batchFwLog!
            goto:cemuHookSettings
        )
        pushd !sf!
        :getLastModifiedSettings
        for /F "delims=~" %%i in ('type !lls!') do set "ls=%%i"

        if not exist !ls!  (
            echo Warning ^: last settings folder was not found^, !ls! does not exist  >> !batchFwLog!

            REM : rebuild it
            call:getModifiedFile !sf! "!currentUser!_settings.xml" last css
            if not exist !css! del /F !lls! > NUL 2>&1 && goto:cemuHookSettings
            call:resolveSettingsPath ltarget
            echo !ltarget!> !lls!

            goto:getLastModifiedSettings
        )
        set "lst="!sf:"=!\!ls:"=!""

        REM : if the file is the same
        if [!xmlUser!] == [!lst!] goto:cemuHookSettings

        REM : get the rpxFilePath used
        set "rpxFilePath="NOT_FOUND""
        for /F "delims=~<> tokens=3" %%p in ('type !lst! ^| find "<path>" ^| find "!GAME_TITLE!" 2^>NUL') do set "rpxFilePath="%%p""

        if [!rpxFilePath!] == ["NOT_FOUND"] goto:cemuHookSettings

        call:getValueInXml "//GameCache/Entry[path='!rpxFilePath:"=!']/title_id/text()" !lst! gid
        if ["!gid!"] == ["NOT_FOUND"] goto:cemuHookSettings

        REM : update !cs! games stats for !GAME_TITLE! using !ls! ones
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\updateGameStats.bat""
        echo !toBeLaunch! !lst! !cs! !gid! >> !batchFwLog!

        wscript /nologo !StartHidden! !toBeLaunch! !lst! !cs! !gid!

        :cemuHookSettings
        pushd !BFW_TOOLS_PATH!

        set "BFW_ONLINE_ACC="!BFW_ONLINE:"=!\usersAccounts""
        if !usePbFlag! EQU 1 If not exist !BFW_ONLINE_ACC! call:setProgressBar 78 82 "pre processing" "installing online files"

        pushd !BFW_TOOLS_PATH!
        set "chIniUser="!SETTINGS_FOLDER:"=!\!currentUser!_cemuhook.ini""
        if exist !chIniUser! robocopy !SETTINGS_FOLDER! !CEMU_FOLDER! "!currentUser!_cemuhook.ini" /MT:32
        set "src="!CEMU_FOLDER:"=!\!currentUser!_cemuhook.ini""
        if exist !src! (
            if exist !chs! del /F !chs! > NUL 2>&1
            move /Y !src! !chs! > NUL 2>&1
        )

        set "controllersProfilesSaved="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
        set "controllersProfiles="!CEMU_FOLDER:"=!\controllerProfiles""
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !controllersProfilesSaved! !controllersProfiles! /MT:32 > NUL 2>&1

        REM : set onlines files for user if an active connection was found
        if !wizardLaunched! EQU 0 if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] call:setOnlineFiles

        REM : if needed, create a game compatibility shorcut
        call:createGameCompatibilityShorcut

        REM : if needed, create a game profile shorcut
        call:createGameProfileShorcut

        REM : if needed, create a example.ini profile shorcut
        call:createExampleIniShorcut

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to valid a settings.xml for automatic import
    :isValid

        REM : set validity to false
        set /A "%1=0"

        REM : get the version of CEMU for the imported settings
        for /F "delims=~" %%i in (!candidateFolder!) do set "settingFolder=%%~nxi"

        set "OLD_CEMU_VERSION=!settingFolder!"

        REM : search in logFile, getting only the last occurence
        set "pat="%OLD_CEMU_VERSION% install folder path""
        set "lastPath="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I !pat! 2^>NUL') do set "lastPath="%%i""

        REM : if this version was moved/deleted => exit with false (validity init)
        if [!lastPath!] == ["NONE"] goto:eof
        set "OLD_PROFILE_FILE="!lastPath:"=!\gameProfiles\%titleId%.ini""

        REM : no need to check CEMU's version : if the gameProfile do not exist => exit with false (validity init)
        if not exist !OLD_PROFILE_FILE! goto:eof

        REM : here : for version > 1.15.15 : it exists a user game profile => no need to launch the wizard, validity = true, exit (auto updater will update the source settings.xml)
        if !v11515! LEQ 1 (
            REM : set validity to true
            set /A "%1=1"
            goto:eof
        )

        echo IMPORT SETTINGS ^: checking candidate !settingFolder!   >> !batchFwLog!
        
        set "fileTmp="!BFW_PATH:"=!\logs\settings_target.bfw_tmp""

        REM : delete ignored nodes
        set "file0=!fileTmp:.bfw_tmp=.bfw_tmp0!"
        !xmlS! ed -d "//GamePaths" !cs! > !file0! 2>NUL

        set "file1=!fileTmp:.bfw_tmp=.bfw_tmp1!"
        !xmlS! ed -d "//GameCache" !file0! > !file1! 2>NUL

        set "file2=!fileTmp:.bfw_tmp=.bfw_tmp2!"

        if !v11519! EQU 2 (
            !xmlS! ed -d "//Online" !file1! > !file2! 2>NUL
        ) else (
            !xmlS! ed -d "//Account" !file1! > !file2! 2>NUL
        )

        !xmlS! ed -d "//GraphicPack" !file2! > !fileTmp! 2>NUL
        set "pat="!BFW_PATH:"=!\logs\settings_target.bfw_tmp*""

        REM : for each nodes in the filtered target xml file
        for /F "delims=~" %%i in ('type !fileTmp! ^| find /V "?" ^| find /V "!"') do (
            set "line=%%i"
            REM : get the node from the line
            for /F "tokens=2 delims=~<>" %%a in ("!line!") do (
                set "read=%%a"
                set "node=!read:/=!"
                set /A "nb=0"
                REM : check if the target node exist in the source file
                for /F "delims=~" %%b in ('type !sSetXml! ^| find "!node!" 2^>NUL') do set /A "nb=1"
                REM : if not found, %1 is still =0, del temporary files and exit
                if !nb! EQU 0 (
                    echo !settingFolder! not valid because !node! not found  >> !batchFwLog!
                    del /F !pat! > NUL 2>&1
                    goto:eof
                )
            )
        )

        del /F !pat! > NUL 2>&1
        REM : set validity to true
        set /A "%1=1"
    goto:eof
    REM : ------------------------------------------------------------------


    :getSettingsFolder

        REM : get the size of the settings.bin of the launched version
        set /A "csbSize=0"
        if exist !csb! (
            for /F "tokens=*" %%a in (!csb!)  do set /A "csbSize=%%~za"
        )

        set "sf="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!""
        if not exist !sf! goto:eof
        pushd !sf!
        for /F "delims=~" %%j in ('dir /B /A:D /O:-N * 2^> NUL') do (
            call:checkSettingsFolder "%%j" result
            if !result! EQU 1 (
                set "previousSettingsFolder=!candidateFolder!"
                echo Importing settings from %%j>> !batchFwLog!
                pushd !BFW_TOOLS_PATH!
                goto:eof
            ) else (
                echo Failed to import settings from %%j>> !batchFwLog!
            )
        )

        pushd !BFW_TOOLS_PATH!
    goto:eof
    REM : ------------------------------------------------------------------

    :checkSettingsFolder
        set "folderName=%~1"

        REM : setting folder found
        set "candidateFolder="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\%folderName%""

        REM : settings.bin
        pushd !candidateFolder!

        REM : initialize to user settings
        set "sSetBin="!candidateFolder:"=!\!currentUser!_settings.bin""
        if not exist !sSetBin! for /F "delims=~" %%i in ('dir /O:D /T:W /B *settings.bin 2^> NUL') do set "sSetBin="!candidateFolder:"=!\%%i""

        REM : initialize to user settings
        set "sSetXml="!candidateFolder:"=!\!currentUser!_settings.xml""
        if not exist !sSetXml! for /F "delims=~" %%i in ('dir /O:D /T:W /B *settings.xml 2^> NUL') do set "sSetXml="!candidateFolder:"=!\%%i""

        pushd !BFW_TOOLS_PATH!

        set /A "sSetBinSize=0"
        if exist !sSetBin! (

            if exist !csb! (
                for /F "tokens=*" %%a in (!sSetBin!)  do set /A "sSetBinSize=%%~za"

                REM : invalidate the import if size of source^'s file lower than target one
                if not exist !sSetXml! if !sSetBinSize! LSS !csbSize! (
                    echo Import cancelled bin size of source^'s file lower than target one>> !batchFwLog!
                    echo source !sSetBinSize! bytes>> !batchFwLog!
                    echo target !csbSize! bytes>> !batchFwLog!
                    set /A "%2=0" && goto:eof
                )
            )

        ) else (
            REM : it exists !csb! but no !sSetBin! = > exit and cancel import
            if exist !csb! set /A "%2=0" && goto:eof
        )

        if exist !sSetXml! (
            set /A "result=0"
            call:isValid result
            if !result! NEQ 1 (
                echo Import cancelled because non macthing nodes in xml file>> !batchFwLog!
                set /A "%2=0" && goto:eof
            )
        )
        set "%2=1"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to set settings for a given user
    :setSettingsForUser

        set "target="!SETTINGS_FOLDER:"=!\!currentUser!_settings.bin""
        if exist !target! goto:eof
        set "target="!SETTINGS_FOLDER:"=!\!currentUser!_settings.xml""
        if exist !target! goto:eof

        pushd !SETTINGS_FOLDER!

        for /F "delims=~" %%i in ('dir /O:D /T:W /B *settings.bin 2^> NUL') do (
            set "f="%%i""
            copy /Y !f! "!currentUser!_settings.bin" > NUL 2>&1
            REM : remove old saved settings
            if [!f!] == ["settings.bin"] del /F !f! > NUL 2>&1
        )
        for /F "delims=~" %%i in ('dir /O:D /T:W /B *settings.xml 2^> NUL') do (
            set "f="%%i""
            copy /Y !f! "!currentUser!_settings.xml" > NUL 2>&1
            REM : remove old saved settings
            if [!f!] == ["settings.xml"] del /F !f! > NUL 2>&1
        )
        set "target="!SETTINGS_FOLDER:"=!\!currentUser!_cemuhook.ini""
        for /F "delims=~" %%i in ('dir /O:D /T:W /B *cemuhook.ini 2^> NUL') do (
            set "f="%%i""
            copy /Y !f! "!currentUser!_cemuhook.ini" > NUL 2>&1
            REM : remove old saved settings
            if [!f!] == ["cemuhook.ini"] del /F !f! > NUL 2>&1
        )

        pushd !BFW_TOOLS_PATH!

    goto:eof
    REM : ------------------------------------------------------------------

    :getHostState
        set "ipaddr=%~1"
        set /A "state=0"
        ping -n 1 !ipaddr! > NUL 2>&1
        if !ERRORLEVEL! EQU 0 set /A "state=1"

        set "%2=%state%"
    goto:eof
    REM : ------------------------------------------------------------------

    :setOnlineFiles

        If not exist !BFW_ONLINE_ACC! goto:eof

        REM : get the account.dat file for the current user and the accId
        set "accId=NONE"

        set "pat="!BFW_ONLINE_ACC:"=!\!currentUser!*.dat""

        for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL') do (
            set "af="!BFW_ONLINE_ACC:"=!\%%i""
            if !v11519! EQU 2 (
                for /F "delims=~= tokens=2" %%j in ('type !af! ^| find /I "AccountId=" 2^>NUL') do set "accId=%%j"
            ) else (
                for /F "delims=~= tokens=2" %%j in ('type !af! ^| find /I "PersistentId=" 2^>NUL') do set "accId=%%j"
            )
        )

        if ["!accId!"] == ["NONE"] (
            echo WARNING^: AccountId not found for !currentUser! >> !batchFwLog!
            !MessageBox! "AccountId not found for !currentUser!^, cancel online files installation" 4160
            goto:eof
        )
        echo Found !accId! associated with !currentUser! >> !batchFwLog!

        REM : check if the Wii-U is not power on
        set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
        if not exist !winScpIni! goto:installAccount

        REM : get the hostname
        set "ipRead="
        for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName=" 2^>NUL') do set "ipRead=%%i"
        REM : check its state

        if not ["!ipRead!"] == [""] (
            call:getHostState !ipRead! state
            if !state! EQU 1 (
                !MessageBox! "A host with your last Wii-U adress was found on the network^. Be sure that no one is using your account ^(!accId!^) to play online right now before continue^." 4112
            )
        )
        :installAccount
        REM : copy !af! to "!MLC01_FOLDER_PATH:"=!\usr\save\system\act\80000001\account.dat"
        set "cemuUserFolder="!MLC01_FOLDER_PATH:"=!\usr\save\system\act\80000001""
        if not exist !cemuUserFolder! mkdir !cemuUserFolder! > NUL 2>&1
        set "target="!cemuUserFolder:"=!\account.dat""
        copy /Y !af! !target! > NUL 2>&1

        REM : patch settings.xml

        REM if not nul
        for /F "tokens=*" %%a in (!cs!) do (
            set /A "css=%%~za"

            if !css! EQU 0 (
                echo WARNING ^: No Setting^.xml found^, cancelling online files installation ^! >> !batchFwLog!
                goto:eof
           )
        )

        set "csTmp="!CEMU_FOLDER:"=!\settings.bfw_tmp""
        REM : settings.xml evolved after 1.15.19 included
        if !v11519! EQU 2 (
            REM : CEMU < 1.15.19 (Online/AccountId)

            REM : Check if exist AccountId node
            type !cs! | find "<AccountId" > NUL 2>&1 && (
                REM : YES  : update the AccountId node
                !xmlS! ed -u "//AccountId" -v !accId! !cs! > !csTmp! 2>NUL
                goto:restoreCs
            )

            REM : NO : rename Account node to Online
            set "csTmp0="!CEMU_FOLDER:"=!\settings.bfw_tmp0""
            !xmlS! ed -r "//Account" -v Online !cs! > !csTmp0! 2>NUL
            REM : rename PersistentId to AccountId
            set "csTmp1="!CEMU_FOLDER:"=!\settings.bfw_tmp1""
            !xmlS! ed -r "//PersistentId" -v AccountId !csTmp0! > !csTmp1! 2>NUL
            REM : delete OnlineEnabled node
            set "csTmp2="!CEMU_FOLDER:"=!\settings.bfw_tmp2""
            !xmlS! ed -d "//OnlineEnabled" !csTmp1! > !csTmp2! 2>NUL

            REM : set AccountId
            !xmlS! ed -u "//AccountId" -v !accId! !csTmp2! > !csTmp! 2>NUL

        ) else (
            REM : CEMU >= 1.15.19 (Account/PersistentId+OnlineEnabled)

            REM : Check if exist PersistentId node
            type !cs! | find "<PersistentId" > NUL 2>&1 && (

                REM : YES  : update PersistentId and OnlineEnabled nodes
                set "csTmp0="!CEMU_FOLDER:"=!\settings.bfw_tmp0""
                !xmlS! ed -u "//PersistentId" -v !accId! !cs! > !csTmp0! 2>NUL
                !xmlS! ed -u "//OnlineEnabled" -v true !csTmp0! > !csTmp! 2>NUL
                goto:restoreCs
            )

            REM : NO : rename Online node to Account
            set "csTmp0="!CEMU_FOLDER:"=!\settings.bfw_tmp0""
            !xmlS! ed -r "//Online" -v Account !cs! > !csTmp0! 2>NUL
            REM : rename AccountId to PersistentId
            set "csTmp1="!CEMU_FOLDER:"=!\settings.bfw_tmp1""
            !xmlS! ed -r "//AccountId" -v PersistentId !csTmp0! > !csTmp1! 2>NUL
            REM : add OnlineEnabled node
            set "csTmp2="!CEMU_FOLDER:"=!\settings.bfw_tmp2""
            !xmlS! ed -s "//Online" -t elem -n OnlineEnabled -v true !csTmp1! > !csTmp2! 2>NUL

            REM : set persistentId
            !xmlS! ed -u "//persistentId" -v !accId! !csTmp2! > !csTmp! 2>NUL
        )

        :restoreCs
        if exist !csTmp! (
            del /F !cs! > NUL 2>&1
            move /Y !csTmp! !cs! > NUL 2>&1
            set "pat="!csTmp:"=!*""
            del /F !pat! > NUL 2>&1
        )

        REM : extract systematically (in case of sync friends list with the wii-u)
        set "mlc01OnlineFiles="!BFW_ONLINE:"=!\mlc01OnlineFiles.rar""

        if exist !mlc01OnlineFiles! wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w!BFW_LOGS! !mlc01OnlineFiles! !GAME_FOLDER_PATH!

        REM : copy otp.bin and seeprom.bin if needed
        set "t1="!CEMU_FOLDER:"=!\otp.bin""
        set "t2="!CEMU_FOLDER:"=!\seeprom.bin""
        set "t1o="!CEMU_FOLDER:"=!\otp.bfw_old""
        set "t2o="!CEMU_FOLDER:"=!\seeprom.bfw_old""

        set "s1="!BFW_ONLINE:"=!\otp.bin""
        set "s2="!BFW_ONLINE:"=!\seeprom.bin""

        if exist !s1! if exist !t1! move /Y !t1! !t1o! > NUL 2>&1
        if exist !s2! if exist !t2! move /Y !t2! !t2o! > NUL 2>&1

        if exist !s1! robocopy !BFW_ONLINE! !CEMU_FOLDER! "otp.bin" /MT:32 > NUL 2>&1
        if exist !s2! robocopy !BFW_ONLINE! !CEMU_FOLDER! "seeprom.bin" /MT:32 > NUL 2>&1

        echo Online account for !currentUser! enabled ^: !accId! >> !batchFwLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles""
        if not exist !CONTROLLER_PROFILE_FOLDER! mkdir !CONTROLLER_PROFILE_FOLDER! > NUL 2>&1

        set "ccp="!CEMU_FOLDER:"=!\ControllerProfiles""
        if not exist !ccp! goto:eof

        set "gcp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles\!USERDOMAIN!""
        if not exist !gcp! goto:syncWithBatchFW

        pushd !gcp!
        REM : import from GAME_FOLDER_PATH to CEMU_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!gcp:"=!\%%x"
            if not exist !ccpf!  wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gcp! !ccp! "%%x" /MT:32
        )

        pushd !ccp!
        REM : import from CEMU_FOLDER to CONTROLLER_PROFILE_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !bcpf! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ccp! !CONTROLLER_PROFILE_FOLDER! "%%x" /MT:32 /XF "controller*.*"
        )

        :syncWithBatchFW
        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=~" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !ccpf! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy  !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" /MT:32 > NUL 2>&1
        )
        pushd !BFW_TOOLS_PATH!

    goto:eof
    REM : ------------------------------------------------------------------

    :createGameCompatibilityShorcut

        REM : add a shortcut in Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Compatibility to edit game's compatibility
        REM : shortcut to game's compatibility
        set "compatShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\Games Compatibility\!GAME_TITLE!.lnk""
        if exist !compatShortcut! goto:eof

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_Compatibility_!DATE!.vbs""

        REM : create a shortcut to game's compatibility
        set "gcsf="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Compatibility""
        if not exist !gcsf! mkdir !gcsf! > NUL 2>&1

        set "strSearched=!GAME_TITLE:TLOZ=!"
        set "strSearched=!GAME_TITLE:DKC=!"
        set "ARGS=https://wiki.cemu.info/index.php?search=!strSearched: =+!&title=Special%%3ASearch&go=Go"

        set "LINK_DESCRIPTION="Get CEMU's compatibility for !GAME_TITLE!""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !compatShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = "!ARGS!" >> !TMP_VBS_FILE!

        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        REM del /F  !TMP_VBS_FILE!

    goto:eof
    REM : ------------------------------------------------------------------

    :createGameProfileShorcut

        REM : add a shortcut in Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles to edit game's profile
        REM : shortcut to game's profile
        set "profileShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles\!GAME_TITLE!.lnk""
        REM : COMMENT to rebuild the game profile in case of a user modification after the first creation
        REM : if exist !profileShortcut! goto:eof
        if not exist !PROFILE_FILE! goto:eof

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_!DATE!.vbs""

        REM : create a shortcut to game's profile
        set "gpsf="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles""
        if not exist !gpsf! mkdir !gpsf! > NUL 2>&1

        if [!PROFILE_FILE!] == ["NOT_FOUND"] goto:eof
        set "ARGS=!PROFILE_FILE:"=!"

        set "LINK_DESCRIPTION="Edit !GAME_TITLE!'s profile for !CEMU_FOLDER_NAME!""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !profileShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = "!ARGS!" >> !TMP_VBS_FILE!

        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof
    REM : ------------------------------------------------------------------

    :createExampleIniShorcut

        set "exampleIni="!CEMU_FOLDER:"=!\gameProfiles\example.ini""
        if not exist !exampleIni! goto:eof

        REM : add a shortcut in Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles to edit game's profile
        set "profileShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles\Edit !CEMU_FOLDER_NAME! example.ini.lnk""

        if exist !profileShortcut! goto:eof

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_!DATE!.vbs""

        set "ARGS=!exampleIni:"=!"

        REM : create a folder (if needed)
        set "gpsf="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles""
        if not exist !gpsf! mkdir !gpsf! > NUL 2>&1

        set "LINK_DESCRIPTION="Edit example.ini profile for !CEMU_FOLDER_NAME!""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !profileShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = "!ARGS!" >> !TMP_VBS_FILE!

        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof
    REM : ------------------------------------------------------------------

    :createLogShorcut

        REM : add a shortcut in Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles to edit game's profile
        REM : shortcut to game's profile
        set "logShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\log.txt.lnk""
        if exist !logShortcut! goto:eof

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_!DATE!.vbs""

        set "ARGS=!cemuLog!"

        REM : create a folder (if needed)
        set "gpsf="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!""
        if not exist !gpsf! mkdir !gpsf! > NUL 2>&1

        set "LINK_DESCRIPTION="!CEMU_FOLDER_NAME!'s Log""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !logShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = !ARGS! >> !TMP_VBS_FILE!
        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof
    REM : ------------------------------------------------------------------

    :createBatchFwLogShorcut

        REM : add a shortcut in Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles to edit game's profile
        REM : shortcut to game's profile
        set "logShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\log.txt.lnk""
        if exist !logShortcut! goto:eof
        if not exist !batchFwLog! goto:eof

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_!DATE!.vbs""

        set "ARGS=!batchFwLog!"

        set "LINK_DESCRIPTION="BatchFw %bfwVersion%'s Log""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !logShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = !ARGS! >> !TMP_VBS_FILE!
        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof

    :resolveSettingsPath
        set "prefix=%GAME_FOLDER_PATH:"=%\Cemu\settings\"
        set "%1=!css:%prefix%=!"
    goto:eof
    REM : ------------------------------------------------------------------

    :saveCemuOptions

        if exist !SETTINGS_FOLDER! (

            REM : saving CEMU an cemuHook settings
            robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.bin /MT:32 > NUL 2>&1
            set "src="!SETTINGS_FOLDER:"=!\settings.bin""
            set "st="!SETTINGS_FOLDER:"=!\!currentUser!_settings.bin""
            move /Y !src! !st! > NUL 2>&1

            robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.xml /MT:32 > NUL 2>&1
            set "src="!SETTINGS_FOLDER:"=!\settings.xml""
            set "css="!SETTINGS_FOLDER:"=!\!currentUser!_settings.xml""
            move /Y !src! !css! > NUL 2>&1

            REM : update the last modified setting file used for game stats and in wizardFirstSaving to get the last version used
            REM : => !css! need to be created with all versions even if game stats are not filled

            set "lls="!GAME_FOLDER_PATH:"=!\Cemu\settings\!currentUser!_lastSettings.txt""
            call:resolveSettingsPath ltarget
            echo !ltarget!> !lls!

            robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! cemuhook.ini /MT:32 > NUL 2>&1
            set "src="!SETTINGS_FOLDER:"=!\cemuhook.ini""
            set "target="!SETTINGS_FOLDER:"=!\!currentUser!_cemuhook.ini""
            move /Y !src! !target! > NUL 2>&1

            echo CEMU options saved to !SETTINGS_FOLDER:"=! for !currentUser! ^!>> !batchFwLog!
        )

        set "gcp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
        set "ccp="!CEMU_FOLDER:"=!\controllerProfiles""
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ccp! !gcp! /MT:32

    goto:eof
    REM : ------------------------------------------------------------------

    :removeSaves
        set "sf="!saveFolder:"=!\%~1\%endTitleId%""
        if exist !sf! rmdir /Q /S !sf! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :searchInternetForTransferableCache

        if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
            !MessageBox! "No transferable shader cache was found, do you want to search one on internet ? If you don't, you can import a cache afterward using the shortcut 'BatchFw\Tools\Shaders Caches\Import transferable cache'. No need to rename-it" 4145
            if !ERRORLEVEL! EQU 2 exit /b 1

            REM : open a google search
            wscript /nologo !Start! "%windir%\explorer.exe" "https://www.google.com/search?q=CEMU+complete+shader+cache+collection+!GAME_TITLE!"
            timeout /T 25 > NUL 2>&1

            !MessageBox! "If you found a cache, import it now (no need to rename it)?" 4164
            if !ERRORLEVEL! EQU 7 exit /b 1

        ) else (
            !MessageBox! "No transferable shader cache was found, do want to import one now (no need to rename it)?" 4164
            if !ERRORLEVEL! EQU 7 exit /b 1
        )

        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\importTransferableCache.bat""

        REM : import the downloaded cache
        wscript /nologo !StartWait! !toBeLaunch! !GAME_FOLDER_PATH! !sci!
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------

    REM : lower case
    :lowerCase

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:A=a!"
        set "str=!str:B=b!"
        set "str=!str:C=c!"
        set "str=!str:D=d!"
        set "str=!str:E=e!"
        set "str=!str:F=f!"
        set "str=!str:G=g!"
        set "str=!str:H=h!"
        set "str=!str:I=i!"
        set "str=!str:J=j!"
        set "str=!str:K=k!"
        set "str=!str:L=l!"
        set "str=!str:M=m!"
        set "str=!str:N=n!"
        set "str=!str:O=o!"
        set "str=!str:P=p!"
        set "str=!str:Q=q!"
        set "str=!str:R=r!"
        set "str=!str:S=s!"
        set "str=!str:T=t!"
        set "str=!str:U=u!"
        set "str=!str:W=w!"
        set "str=!str:X=x!"
        set "str=!str:Y=y!"
        set "str=!str:Z=z!"

        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------


    :transShaderCache

        if !v116! EQU 2 (
            REM : get NEW_TRANS_SHADER id from log.txt
            set "strTmp=NONE"
            for /F "tokens=1-4 delims=:~" %%i in ('type !cemuLog! ^| find /I "shaderCache" 2^>NUL') do (
                set "strTmp=%%l"
                goto:firstOcShaderCache
            )
        ) else (
            set "endIdUp=!titleId!
            call:lowerCase !endIdUp! strTmp
        )

        :firstOcShaderCache

        if ["!strTmp!"] == ["NONE"] (
            echo Unable to get shaderCacheId line in !cemuLog!^, skip saving shader cache ^!>> !batchFwLog!
            goto:eof
        )
        set "NEW_SHADER_CACHE_ID=%strTmp: =%"
        if !v125! LEQ 1 set "NEW_SHADER_CACHE_ID=!NEW_SHADER_CACHE_ID:"=!_shaders"

        set "NEW_TRANS_SHADER=%NEW_SHADER_CACHE_ID%.bin"
        set "OLD_TRANS_SHADER=%OLD_SHADER_CACHE_ID%.bin"

        if ["!SHADER_MODE!"] == ["CONVENTIONAL"] (
            set "OLD_TRANS_SHADER=%OLD_SHADER_CACHE_ID%_j.bin"
            set "NEW_TRANS_SHADER=%NEW_SHADER_CACHE_ID%_j.bin"
        )

        if not exist !ctscf! goto:eof

        if exist !gtscf! goto:handleShaderFiles

        mkdir !gtscf! > NUL 2>&1
        REM :  move CEMU transferable shader cache file to GAME_FOLDER_PATH
        echo move !ctscf! to !gtscf!>> !batchFwLog!
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf!  !gtscf! "!NEW_TRANS_SHADER!" /MT:32 /MOV /IS /IT
        goto:eof

        :handleShaderFiles
        REM : not transShaderCache found in game's subfolder goto:copyBackShaderCache

        if ["!OLD_SHADER_CACHE_ID!"] == ["NONE"] goto:copyBackShaderCache

        REM : get the 2 files sizes
        set "otscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!OLD_TRANS_SHADER!""
        set "ntscf="!cemuShaderCache:"=!\transferable\!NEW_TRANS_SHADER!""

        if exist !ntscf! (
            for /F "tokens=*" %%a in (!ntscf!)  do set /A "newSize=%%~za"
        ) else (
            set /A "newSize=0"
        )
        if exist !otscf! (
            for /F "tokens=*" %%a in (!otscf!)  do set /A "oldSize=%%~za"
        ) else (
            set /A "oldSize=0"
        )

        echo CEMU transferable cache file !NEW_TRANS_SHADER! have a size of  ^:  %newSize%>> !batchFwLog!
        echo Saved transferable cache file !OLD_TRANS_SHADER! have a size of ^:  %oldSize%>> !batchFwLog!

        REM : prepare log to edit it
        echo --------------------------------------------------- >> !tscl!
        echo - [!DATE!] !currentUser!@!USERDOMAIN! >> !tscl!
        echo - >> !tscl!
        echo - CEMU install ^: !CEMU_FOLDER! >> !tscl!
        echo - >> !tscl!
        echo - CEMU transferable cache file size  !NEW_TRANS_SHADER! ^: %newSize% >> !tscl!
        echo - Saved transferable cache file size !OLD_TRANS_SHADER! ^: %oldSize% >> !tscl!
        echo - >> !tscl!

        REM : OLD_TRANS_SHADER cache file renamed
        set "otscr="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!OLD_SHADER_CACHE_ID!.bfw_old""
        REM : NEW_TRANS_SHADER cache file saving path
        set "gntscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!NEW_TRANS_SHADER!""

        REM : if the two file have the same name goto:savingShaderCache
        echo !OLD_TRANS_SHADER! | find /I !NEW_TRANS_SHADER! > NUL 2>&1 && goto:savingShaderCache

        REM : switching CONVENTIONNAL <-> SEPARABLE
        set "checkToConv=!OLD_SHADER_CACHE_ID!_j"
        if ["!checkToConv!"] == ["%NEW_SHADER_CACHE_ID%"] goto:savingShaderCache
        set "checkToSep=!OLD_SHADER_CACHE_ID:_j=!"
        if ["!checkToSep!"] == ["%NEW_SHADER_CACHE_ID%"] goto:savingShaderCache

        REM : SHADERCACHEID ARE DIFFERENTS : throw a user notification with notepad in the 2 following case

        echo - !GAME_TITLE! ShaderCacheId has changed from !OLD_TRANS_SHADER! to !NEW_TRANS_SHADER! >> !tscl!

        REM : compare their size
        if %newSize% GTR %oldSize% (

            REM : CEMU file bigger than saved one (degraded case)  : rename the saved old one, move CEMU file for saving, update log, add date ?
            echo - CEMU transferable cache file size is greater than saved one >> !tscl!
            echo - >> !tscl!
            echo - Is !CEMU_FOLDER_NAME! change the shaderCacheId ^? >> !tscl!
            echo - >> !tscl!
            echo - Renaming saved cache to !OLD_SHADER_CACHE_ID!.bfw_old >> !tscl!

            move /Y !otscf! !otscr! > NUL 2>&1
            echo - >> !tscl!
            echo - Moving CEMU^'s transferable shader cache to game^'s folder >> !tscl!
            wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf! !gtscf! "!NEW_TRANS_SHADER!" /MT:32 /MOV /IS /IT
            echo - >> !tscl!

            set "tscrl="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!CEMU_FOLDER_NAME!_replace_!OLD_SHADER_CACHE_ID!_with_!NEW_SHADER_CACHE_ID!""

            echo - [!DATE!] !currentUser!@!USERDOMAIN! with !CEMU_FOLDER_NAME! > !tscrl!
            echo - >> !tscrl!
            echo - !CEMU_FOLDER_NAME! change !GAME_TITLE!^'s ShaderCacheId from !OLD_SHADER_CACHE_ID! to !NEW_SHADER_CACHE_ID! >> !tscrl!

        ) else (

            REM : saved file bigger than CEMU's one (nominal case) : import an external transferable shader cache -> use CEMU shaderCacheId to rename the imported file, delete CEMU file
            echo - Saved transferable cache file size is greater than CEMU one >> !tscl!
            echo - >> !tscl!

            echo - You certainly about import an external transferable shader cache with a wrong name >> !tscl!
            echo - Renaming saved cache with CEMU^'s one name^.^.^. >> !tscl!
            echo - >> !tscl!

            move /Y !otscf! !gntscf! > NUL 2>&1

            echo - >> !tscl!
        )

        echo - >> !tscl!
        echo ^(close notepad to continue^) >> !tscl!
        echo ^(close notepad to continue^)

        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tscl!

        goto:eof

        :savingShaderCache
        REM : SHADERCACHEID IDENTICALS : no need to check size, treatment is the same. Do it only for log

        REM : compare their size
        if %newSize% GEQ %oldSize%  (

            REM : CEMU file bigger than saved one (nominal case)  : overwrite saved by moving CEMU file
            echo move !ntscf! to !otscf!>> !batchFwLog!
            goto:copyBackShaderCache
        )

        REM : saved file bigger than CEMU's one : case of upgrading a transferable shader file with the right name
        echo - Saved transferable cache file size is greater than CEMU one >> !tscl!
        echo - As the saved one was copied before launching the game in cemu FOLDER >> !tscl!
        echo - there^'s no doubts that !CEMU_FOLDER_NAME! broke the shaderCache compatibility >> !tscl!
        echo - >> !tscl!
        echo - Browse to !GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable >> !tscl!
        echo - Keep the !OLD_SHADER_CACHE_ID!^.bfw_old if necessary^, delete it otherwise>> !tscl!
        echo - >> !tscl!

        set "btscl="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!CEMU_FOLDER_NAME!_broke_!OLD_SHADER_CACHE_ID!""

        echo - [!DATE!] !currentUser!@!USERDOMAIN! with !CEMU_FOLDER_NAME! > !btscl!
        echo - >> !btscl!
        echo - !CEMU_FOLDER_NAME! refuse to use !OLD_SHADER_CACHE_ID!^.bfw_old >> !btscl!

        REM : rename saved file
        move /Y !otscf! !otscr! > NUL 2>&1
        move /Y !gntscf! !ntscf! > NUL 2>&1

        echo - >> !tscl!
        echo ^(close notepad to continue^) >> !tscl!
        echo ^(close notepad to continue^)

        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tscl!

        :copyBackShaderCache
        REM : move CEMU transferable shader cache file to GAME_FOLDER_PATH

        if ["!SHADER_MODE!"] == ["SEPARABLE"] (
            set "NEW_TRANS_SHADER=!NEW_TRANS_SHADER:_j.bin=.bin!"
        ) else (
            set "NEW_TRANS_SHADER=!NEW_TRANS_SHADER:.bin=_j.bin!"
        )

        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf! !gtscf! "!NEW_TRANS_SHADER!" /MT:32 /MOV /IS /IT > NUL 2>&1

        if !v125! LEQ 1  (
            wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf! !gtscf! "!NEW_TRANS_SHADER:_shaders=_vkpipeline!" /MT:32 /MOV /IS /IT > NUL 2>&1
        )

        REM : delete transShaderCache.log (useless)
        if exist !tscl! del /F /S !tscl! > NUL 2>&1

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

        if ["!versionReadFormated!"] == ["NONE"] (
            echo %vit% | findstr /V /R [a-zA-Z] > NUL 2>&1 && set "vit=!vit!00"
            echo !vit! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vit! vit
            set "versionReadFormated=!vit!"
        ) else (
            set "vit=!versionReadFormated!
        )

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

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"

        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "charCodeSet" 2^>NUL') do set "CHARSET=%%i"
        if not ["%CHARSET%"] == ["NOT_FOUND"] goto:chcp

        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?>> !batchFwLog!
            echo Host char codeSet not found in %0 ^?
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        call:log2HostFile "charCodeSet=%CHARSET%"

        REM : set char code set, output to host log file
        :chcp
        chcp %CHARSET% > NUL 2>&1


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
        for /F %%i in ('type !logFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------