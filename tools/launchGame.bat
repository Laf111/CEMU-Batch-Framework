@echo off
setlocal EnableExtensions
title BatchFw Game Launcher
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

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenCmd="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenCmd.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    :getDate
    REM : get DATE
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
    set ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%
    set DATE=%ldt%

    REM : check if cemu if not already running
    for /F "delims=" %%j in ('tasklist /FI "STATUS eq RUNNING" ^| find /I "cemu.exe"') do (

        wscript /nologo !Start! "%windir%\System32\taskmgr.exe"

        cscript /nologo !MessageBox! "ERROR ^: Cemu is already running in the background ^!^, please kill it and relaunch" 16
        if !ERRORLEVEL! EQU 2 goto:eof
        goto:getDate
    )

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "batchFwLog="!BFW_PATH:"=!\logs\BatchFwLog.txt""
    @echo ========================================================= > !batchFwLog!
    REM : search in logFile, getting only the last occurence
    set "bfwVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "BFW_VERSION" 2^>NUL') do set "bfwVersion=%%i"
    @echo CEMU^'s Batch Framework %bfwVersion% >> !batchFwLog!
    @echo ========================================================= >> !batchFwLog!

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL

    REM : set current char codeset
    call:setCharSet

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr! >> !batchFwLog!
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        timeout /t 8 > NUL
        exit 1
    )
    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : Intel legacy options
    set "argLeg="

    REM : current user
    set "user=NOT_FOUND"

    REM : flag importing settings
    set /A "settingsImported=0"

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
        @echo ERROR ^: on arguments passed ^!>> !batchFwLog!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER PRX_FILE_PATH OUTPUT_FOLDER ICO_PATH MLC01_FOLDER_PATH user -noImport^* -ignorePrecomp^* -no^/Legacy^*>> !batchFwLog!
        @echo ^(^* for optionnal^ argument^)>> !batchFwLog!
        @echo given {%*} >> !batchFwLog!
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER PRX_FILE_PATH OUTPUT_FOLDER ICO_PATH MLC01_FOLDER_PATH user -noImport^* -ignorePrecomp^* -no^/Legacy^*
        @echo ^(^* for optionnal^ argument^)
        @echo given {%*}
        timeout /t 8 > NUL
        exit 99
    )

    if %nbArgs% LSS 6 (
        @echo ERROR ^: on arguments passed ^! >> !batchFwLog!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER PRX_FILE_PATH OUTPUT_FOLDER ICO_PATH MLC01_FOLDER_PATH user -noImport^* -ignorePrecomp^* -no^/Legacy^* >> !batchFwLog!
        @echo ^(^* for optionnal^ argument^) >> !batchFwLog!
        @echo given {%*} >> !batchFwLog!
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER PRX_FILE_PATH OUTPUT_FOLDER ICO_PATH MLC01_FOLDER_PATH user -noImport^* -ignorePrecomp^* -no^/Legacy^*
        @echo ^(^* for optionnal^ argument^)
        @echo given {%*}
        timeout /t 8 > NUL
        exit 99
    )
    REM : flag for nolegacy options
    set "IMPORT_MODE=ENABLED"
    set "IGNORE_PRECOMP=DISABLED"


    REM : args 6
    set "user=!args[5]!"
    set "user=!user:"=!"
    if %nbArgs% EQU 6 goto:getCemuFolder

    REM : args 7
    if [!args[6]!] == ["-noImport"] set "IMPORT_MODE=DISABLED"
    if [!args[6]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"
    if [!args[6]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[6]!] == ["-Legacy"] set "argLeg=-Legacy"

    if %nbArgs% EQU 7 goto:getCemuFolder

    REM : args 8
    if [!args[7]!] == ["-noImport"] set "IMPORT_MODE=DISABLED"
    if [!args[7]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"
    if [!args[7]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[7]!] == ["-Legacy"] set "argLeg=-Legacy"

    if %nbArgs% EQU 8 goto:getCemuFolder

    REM : args 9
    if [!args[8]!] == ["-noImport"] set "IMPORT_MODE=DISABLED"
    if [!args[8]!] == ["-ignorePrecomp"] set "IGNORE_PRECOMP=ENABLED"
    if [!args[8]!] == ["-noLegacy"] set "argLeg=-noLegacy"
    if [!args[8]!] == ["-Legacy"] set "argLeg=-Legacy"

    :getCemuFolder
    REM : get CEMU_FOLDER
    set "CEMU_FOLDER=!args[0]!"
    REM : get RPX_FILE_PATH
    set "RPX_FILE_PATH=!args[1]!"

    REM : get and check SHORTCUT_FOLDER
    set "OUTPUT_FOLDER=!args[2]!"
    if not exist !OUTPUT_FOLDER! (
        @echo ERROR ^: shortcut folder !OUTPUT_FOLDER! does not exist ^! >> !batchFwLog!
        @echo ERROR ^: shortcut folder !OUTPUT_FOLDER! does not exist ^!
        timeout /t 8 > NUL
        exit 3
    )

    REM : create shortcut to logFile
    call:createBatchFwLogShorcut

    REM : check RPX_FILE_PATH
    if not exist !RPX_FILE_PATH! (
        @echo ERROR ^: game's rpx file path !RPX_FILE_PATH! does not exist ^! please delete this shortcut^/executable >> !batchFwLog!
        @echo ERROR ^: game's rpx file path !RPX_FILE_PATH! does not exist ^! please delete this shortcut^/executable
        timeout /t 8 > NUL
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 2
    )

    REM : get codeFolder
    for /F "delims=" %%i in (!RPX_FILE_PATH!) do set "dirname="%%~dpi""
    set "codeFolder=!dirname:~0,-2!""

    for /F "delims=" %%i in (!codeFolder!) do set "strTmp="%%~dpi""
    set "GAME_FOLDER_PATH=!strTmp:~0,-2!""

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME="%%~nxa""
    set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME:"=!"

    title Launching !GAME_TITLE! with !CEMU_FOLDER_NAME!

    REM : log CEMU
    set "cemuLog="!CEMU_FOLDER:"=!\log.txt""

    REM : BatchFW graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""
    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""

    if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL

    REM : search if this script is not already running (nb of search results)
    set /A "nbI=0"

    for /F "delims==" %%f in ('wmic process get Commandline ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% NEQ 0 (
        if %nbI% GTR 2 (
            cscript /nologo !MessageBox! "ERROR ^: this script is already^/still running, aborting ^!" 16
            exit 20
        )
    )

    REM : start a script that will monitor the execution
    set "ml="!BFW_TOOLS_PATH:"=!\monitorBatchFw.bat""
    wscript /nologo !StartHidden! !ml!

    REM : check a graphic pack update
    set "script="!BFW_TOOLS_PATH:"=!\updateGraphicPacksFolder.bat""
    wscript /nologo !StartHiddenWait! !script! -silent

    REM : GFX type to provide
    set "gfxType=V3"

    if not exist !cemuLog! goto:getTitleId

    set "CemuVersionRead=NOT_FOUND"
    set "versionRead=NOT_FOUND"

    for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu"') do set "versionRead=%%e"

    if ["%versionRead%"] == ["NOT_FOUND"] goto:getTitleId

    set "str=%versionRead:.=%"
    set /A "CemuVersionRead=%str:~0,4%"
    if %CemuVersionRead% LSS 1140 set "gfxType=V2"

    :getTitleId
    REM : META.XML file
    set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""

    if not exist !META_FILE! goto:getScreenMode

    REM : get Title Id from meta.xml
    set "titleLine="NONE""
    for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
    if [!titleLine!] == ["NONE"] goto:getScreenMode
    for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

    set "wiiuLibFile="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=" %%i in ('type !wiiuLibFile! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

    if [!libFileLine!] == ["NONE"] goto:getScreenMode

    :updateGameGraphicPack

    REM : update Game's Graphic Packs (also done in wizard so call it here to avoid double call)
    set "ugp="!BFW_TOOLS_PATH:"=!\updateGamesGraphicPacks.bat""
    wscript /nologo !StartHidden! !ugp! true !GAME_FOLDER_PATH!

    :getScreenMode

    REM : if SCREEN_MODE is present in logHOSTNAME file : launch CEMU in windowed mode
    set "screenMode=-f"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode="

    REM : shortcut path
    set "gameShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\!user!\!GAME_TITLE! [!CEMU_FOLDER_NAME!!argLeg!] !user!.lnk""
    set "gameExe="!OUTPUT_FOLDER:"=!\Wii-U Games\!user!\!GAME_TITLE! [!CEMU_FOLDER_NAME!!argLeg!] !user!.exe""

    REM : shortcut to game's profile
    set "profileShortcuts="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles""

    REM : check CEMU_FOLDER
    if not exist !CEMU_FOLDER! (

        cscript /nologo !MessageBox! "CEMU folder !CEMU_FOLDER:"=! does not exist anymore^, you might have move or delete this version^. Removing shortcuts" 4160

        REM : delete shortcuts
        if exist !gameShortcut! del /F !gameShortcut! >NUL
        if exist !gameExe! del /F !gameExe! >NUL
        rmdir /Q /S !profileShortcuts! 2>NUL

        REM : Delete the shortcut
        set "delSettings="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\%CEMU_FOLDER_NAME%\Delete my %CEMU_FOLDER_NAME%'s settings""

        del /F !delSettings! >NUL

        REM : Delete the shortcut
        set "logShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\Logs\!CEMU_FOLDER_NAME!.lnk""

        del /F !logShortcut! >NUL
        timeout /t 8 > NUL
        exit 20
    )


    REM : get and check ICO_FILE_PATH
    set "ICO_PATH=!args[3]!"
    if not exist !ICO_PATH! (
        @echo ERROR ^: game's icon file path !ICO_PATH! does not exist ^! >> !batchFwLog!
        @echo ERROR ^: game's icon file path !ICO_PATH! does not exist ^!
        timeout /t 8 > NUL
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 4
    )

    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[4]!"
    if not exist !MLC01_FOLDER_PATH! (
        @echo ERROR ^: mlc01 folder !MLC01_FOLDER_PATH! does not exist ^! >> !batchFwLog!
        @echo ERROR ^: mlc01 folder !MLC01_FOLDER_PATH! does not exist ^!
        timeout /t 8 > NUL
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !batchFwLog!
        exit 5
    )


    @echo Don^'t close this windows^, it will stop CEMU ^!
    @echo It will be closed automatically after closing CEMU
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ >> !batchFwLog!
    @echo Automatic settings import ^: !IMPORT_MODE! >> !batchFwLog!
    @echo Don^'t close this windows^, it will stop CEMU ^!
    @echo It will be closed automatically after closing CEMU
    @echo =========================================================
    @echo Automatic settings import ^: !IMPORT_MODE!

    REM : handling GLCache backup
    REM : ----------------------------

    REM : CEMU's shaderCache subfolder
    set "cemuShaderCache="!CEMU_FOLDER:"=!\shaderCache""
    REM : saved GLCache folder
    set "GLCACHE_BACKUP="NOT_FOUND""

    REM : openGLCacheID
    set "oldOGLCacheId=NOT_FOUND"
    set "OPENGL_CACHE="NOT_FOUND""
    set "GlCache="NOT_FOUND""
    set "GlCacheSaved="NOT_FOUND""

    set /A "driversUpdateFlag=0"

    REM : get GPU_VENDOR and current display drivers version (end of list returned in case of type than one graphic card)
    for /F "tokens=2 delims==" %%i in ('wmic path Win32_VideoController get Name /value ^| find "="') do (
        set "string=%%i"
        goto:firstOccur
    )
    :firstOccur
    set "GPU_VENDOR=!string: =!"
    call:secureStringPathForDos !GPU_VENDOR! GPU_VENDOR

    set "gpuType=OTHER"
    echo !GPU_VENDOR! | find /I "NVIDIA" > NUL && set "gpuType=NVIDIA"
    echo !GPU_VENDOR! | find /I "AMD" > NUL && set "gpuType=AMD"
    echo !GPU_VENDOR! | find /I "INTEL" > NUL && set "gpuType=INTEL"

    for /F "tokens=2 delims==" %%i in ('wmic path Win32_VideoController get DriverVersion /value ^| find "="') do (
        set "string=%%i"
        goto:firstOccur
    )
    :firstOccur
    set "GPU_DRIVERS_VERSION=!string: =!"

    REM : search your current GLCache
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence

    set "OPENGL_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"

    REM : when updating drivers GLCache is deleted

    if not [!OPENGL_CACHE!] == ["NOT_FOUND"] if exist !OPENGL_CACHE! goto:handlingGame

    REM : else search it
    pushd "%LOCALAPPDATA%"
    set "cache="NOT_FOUND""
    for /F "delims=" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if [!cache!] == ["NOT_FOUND"] pushd "%APPDATA%" && for /F "delims=" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if not [!cache!] == ["NOT_FOUND"] set "OPENGL_CACHE=!cache!"

    pushd !BFW_TOOLS_PATH!

    if [!OPENGL_CACHE!] == ["NOT_FOUND"] goto:handlingGame

    REM : save path to log file
    set "msg="OPENGL_CACHE=!OPENGL_CACHE:"=!""
    call:log2HostFile !msg!

    REM : handling Game
    REM : ----------------------------

    :handlingGame

    set "OPENGL_CACHE_PATH=!OPENGL_CACHE!"

    REM : CEMU >= 1.15.1
    set "cemuGLcache="!CEMU_FOLDER:"=!\shaderCache\driver\nvidia""

    if ["%gpuType%"]==["NVIDIA"] if exist !cemuGLcache! (
        set "OPENGL_CACHE_PATH="!cemuGLcache:"=!\GLCache""
        REM : create the GLcache subfolder
        if not exist !OPENGL_CACHE_PATH! mkdir !OPENGL_CACHE_PATH!

    )

    REM also create default folder (not exist when you've just upadte your display drivers)
    set "folder="%LOCALAPPDATA%\%gpuType%\GLCache""
    if not exist !folder! mkdir !folder! > NUL
    REM : also in APPDATA
    set "folder="%APPDATA%\%gpuType%\GLCache""
    if not exist !folder! mkdir !folder! > NUL

    REM : Settings folder for CEMU_FOLDER_NAME
    set "SETTINGS_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\!CEMU_FOLDER_NAME!""

    REM : initialize a flag to know if wizard will be launched
    set /A "wizardLaunched=0"

    set "PROFILE_FILE="NOT_FOUND""

    :copyShaderCache
    REM : Batch Game info file
    set "gameInfoFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt""

    REM : check if a saved transferable cache file exist
    set "OLD_SHADER_CACHE_ID=NONE"

    REM : CEMU transShaderCache folder
    set "ctscf="!cemuShaderCache:"=!\transferable""

    REM : copy transferable shader cache, if exist in GAME_FOLDER_PATH
    set "gtscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
    if not exist !gtscf! goto:loadOptions

    set "cacheFile=NONE"
    set "pat="!gtscf:"=!\*.bin""
    REM : getting the last modified one including _j.bin (conventionnal shader cache)
    for /F "delims=" %%i in ('dir /B /O:D !pat! 2^>NUL') do set "cacheFile=%%i"

    REM : if not file found
    if ["!cacheFile!"] == ["NONE"] goto:loadOptions

    REM : backup transferable cache in case of CEMU corrupt it
    set "transF="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!cacheFile:"=!""
    set "backup="!transF:"=!-backupLaunchN.rar""

    REM : add a supplementary level of backup because the launch following the crash that have corrupt file
    REM : backup file will be lost and replace by a corrupt backup and you aknowledge that an issue occured only
    REM : on this run
    set "lastValid="!transF:"=!-backupLaunchN-1.rar""
    if exist !backup! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe"  /C copy /Y !backup! !lastValid! > NUL

    wscript /nologo !StartHidden! !rarExe! a -ep1 -inul !backup! !transF!

    REM : get backup files sizes
    if exist !backup! (
        for /F "tokens=*" %%a in (!backup!)  do set "newSize=%%~za"
    ) else (
        set "newSize=0"
    )
    if exist !lastValid! (
        for /F "tokens=*" %%a in (!lastValid!)  do set "oldSize=%%~za"
    ) else (
        set "oldSize=0"
    )

    REM : compare their size : size of N always > N-1
    if %newSize% LSS %oldSize% (
        cscript /nologo !MessageBox! "ERROR ^: old transferable cache backup is greater than new one, please check what happened ^!" 4112
        exit 30
    )

    REM : build OLD_SHADER_CACHE_ID without _j.bin
    set OLD_SHADER_CACHE_ID=!cacheFile:_j=!
    set OLD_SHADER_CACHE_ID=!cacheFile:.bin=!

    REM : first launch the transferable cache copy in background before
    @echo Copying transferable cache to !CEMU_FOLDER! ^.^.^. >> !batchFwLog!
    @echo Copying transferable cache to !CEMU_FOLDER! ^.^.^.
    REM : copy all *.bin file (2 files if separable and conventionnal)
    wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gtscf! !ctscf! /S /XF *.log /XF *.old /XF *emu* /XF *.rar

    :loadOptions

    REM : launching user's software
    set "launchThirdPartySoftware="!BFW_TOOLS_PATH:"=!\launchThirdPartySoftware.bat""
    wscript /nologo !StartHidden! !launchThirdPartySoftware!

    REM : GFX folders in CEMU
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""

    REM : load Cemu's options
    call:loadCemuOptions

    REM : check if another instance of CEMU is running
    :searchLockFile
    set "LOCK_FILE="NONE""
    set "pat="!CEMU_FOLDER:"=!\*.lock""
    for /F "delims=" %%i in ('dir /B !pat! 2^>NUL') do (
        set "LOCK_FILE="!CEMU_FOLDER:"=!\%%i""
    )

    REM : if a lock file was found
    if not [!LOCK_FILE!] == ["NONE"] (

        @echo ERROR when launching !GAME_TITLE! ^: A lock file was found under !CEMU_FOLDER:"=! ^! >> !batchFwLog!
        @echo Please close^/kill runing CEMU executable and remove !LOCK_FILE:"=! >> !batchFwLog!
        @echo --------------------------------------------------------- >> !batchFwLog!
        type !LOCK_FILE!
        @echo --------------------------------------------------------- >> !batchFwLog!
        @echo ERROR when launching !GAME_TITLE! ^: A lock file was found under !CEMU_FOLDER:"=! ^!
        @echo Please close^/kill runing CEMU executable and remove !LOCK_FILE:"=!
        @echo ---------------------------------------------------------
        type !LOCK_FILE!
        @echo ---------------------------------------------------------
        wscript /nologo !Start! "%windir%\explorer.exe" !CEMU_FOLDER!

        cscript /nologo !MessageBox! "A lock file was found under !CEMU_FOLDER:"=!^, if no other windows user ^(session left openned^) is running CEMU ^: delete-it then close this windows" 4112
        goto:searchLockFile
    )

    REM : transShaderCache log
    if not exist !gtscf! mkdir !gtscf! > NUL
    set "tscl="!gtscf:"=!\transShaderCache.log""
    @echo GAME_CONFIGURATION before launching !CEMU_FOLDER_NAME! : > !tscl!
    if exist !gameInfoFile! type !gameInfoFile! >> !tscl!

    REM :  -> add a check MLC01 = CEMU AND local mlc01 exist
    set "cml01="!CEMU_FOLDER:"=!\mlc01""

    REM : check mlc01 consistency
    if not [!MLC01_FOLDER_PATH!] == [!cml01!] goto:openGlCache
    REM : if arg MLC01_FOLDER_PATH is pointing to CEMU_FOLDER

    REM : and a local mlc01 folder exist
    set "gml01="!GAME_FOLDER_PATH:"=!\mlc01""

    if not exist !gml01! goto:openGlCache

    cscript /nologo !MessageBox! "ERROR ^: Please delete and recreate this shortcut ^(if !CEMU_FOLDER_NAME:"=! newer than 1^.11^) OR rename^/move !gml01:"=! ^(if !CEMU_FOLDER_NAME:"=! is an older than 1^.10 and so mlc01 is in CEMU folder^)" 4112
    exit 15

    :openGlCache

    REM : search GCLCache backup in _BatchFW_CemuGLCache folder
    set "GLCacheBackupFolder="NOT_FOUND""
    if [!OPENGL_CACHE_PATH!] == ["NOT_FOUND"] goto:launchCemu

    set "GLCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuGLCache!"

    if not exist !GLCacheSavesFolder! goto:launchCemu

    set "IdGpuFolder="NOT_FOUND""
    pushd !GLCacheSavesFolder!
    set "pat=!GPU_VENDOR!*"
    for /F "delims=" %%x in ('dir /A:D /O:D /B !pat! 2^>NUL') do set "IdGpuFolder="%%x""
    pushd !BFW_TOOLS_PATH!

    REM : if no backup found for your GPU VENDOR goto:launchCemu
    if [!IdGpuFolder!] == ["NOT_FOUND"] goto:launchCemu
    REM : get gpuVendor and gpuDriversVersion from folder's name
    for /F "tokens=1-2 delims=@" %%i in (!IdGpuFolder!) do (
        set "gpuVendorRead=%%i"
        set "gpuDriversVersionRead=%%j"
    )

    REM : if GPU_VENDOR not match goto:launchCemu ignore the file
    if not ["!gpuVendorRead!"] == ["!GPU_VENDOR!"] (
        @echo Found a GLCache backup !IdGpuFolder! that is not for your current GPU Vendor^, delete-it ^! >> !batchFwLog!
        @echo Found a GLCache backup !IdGpuFolder! that is not for your current GPU Vendor^, delete-it ^!
        REM : log to host log file
        set "msg="!DATE!-non matching GPU Vendor GLCache backup deleted=!IdGpuFolder!""
        call:log2HostFile !msg!

        rmdir /Q /S !IdGpuFolder! 2>NUL
        goto:launchCemu
    )
    REM : secure string for diff
    set "old=%gpuDriversVersionRead:.=%"
    set "old=%old:-=%"
    set "old=%old:_=%"

    REM : secure string for diff
    set "new=%GPU_DRIVERS_VERSION:.=%"
    set "new=%new:-=%"
    set "new=%new:_=%"

    REM : if GPU_DRIVERS_VERSION match goto:launchCemu use the file
    if not ["%old%"] == ["%new%"] (
        @echo Display drivers update detected ^! >> !batchFwLog!
        @echo from display drivers version    = [%gpuDriversVersionRead%] >> !batchFwLog!
        @echo current display drivers version = [%GPU_DRIVERS_VERSION%] >> !batchFwLog!
        @echo Display drivers update detected ^!
        @echo from display drivers version    = [%gpuDriversVersionRead%]
        @echo current display drivers version = [%GPU_DRIVERS_VERSION%]

        REM : log to host log file
        set "msg="Detected %GPU_VENDOR% drivers version upgrade from %gpuDriversVersionRead% to =%GPU_DRIVERS_VERSION%""
        call:log2HostFile !msg!
        set /A "driversUpdateFlag=1"
    )
    set "IdGpuFolder="!GLCacheSavesFolder:"=!\!IdGpuFolder:"=!""

    set "GLCacheBackupFolder="!IdGpuFolder:"=!\!GAME_TITLE!""

    REM : if no backup folder is found for this game goto:launchCemu
    if not exist %GLCacheBackupFolder% goto:launchCemu

    REM : openGLCacheID
    for /F "delims=" %%x in ('dir /A:D /O:D /B !GLCacheBackupFolder!') do set "oldOGLCacheId=%%x"
    if not ["%oldOGLCacheId%"] == ["NOT_FOUND"] goto:subfolderFound

    REM : search for shader files
    pushd !GLCacheBackupFolder!
    set "shaderCacheFileName=NOT_FOUND"
    for /F "delims=" %%f in ('dir /O:D /B *.bin 2^>NUL') do set "shaderCacheFileName=%%~nf"
    pushd !BFW_TOOLS_PATH!
    if ["%shaderCacheFileName%"] == ["NOT_FOUND"] goto:launchCemu

    pushd !GLCacheBackupFolder!
    REM OPENGL_CACHE_PATH already created before (if missing)
    for /F "delims=" %%f in ('dir /O:D /B %shaderCacheFileName%.* 2^>NUL') do (
        set "file="%%f""
        robocopy !GLCacheBackupFolder! !OPENGL_CACHE_PATH! !file! /MOV /IS /IT > NUL
    )
    pushd !BFW_TOOLS_PATH!

    REM : using backup
    @echo Using !shaderCacheFileName! >> !batchFwLog!
    @echo Using !shaderCacheFileName!
    goto:launchCemu

    :subfolderFound
    set "GlCache="!OPENGL_CACHE_PATH:"=!\%oldOGLCacheId%""

    if exist !GlCache! rmdir /Q /S !GlCache! 2>NUL

    set "GlCacheSaved="!GLCacheBackupFolder:"=!\%oldOGLCacheId%""

    REM : moving folder (NVIDIA specific)
    :moveGl
    call:moveFolder !GlCacheSaved! !GlCache! cr
    if !cr! NEQ 0 (
        cscript /nologo !MessageBox! "ERROR While moving openGL save^, close all explorer^.exe that might interfer ^!" 4117
        if !ERROLRLEVEL! EQU 4 goto:moveGl
    )

    REM : using backup
    @echo Using !GlCacheSaved! as OpenGL cache >> !batchFwLog!
    @echo Using !GlCacheSaved! as OpenGL cache
    REM : Launching CEMU (for old versions -mlc will be ignored)
    :launchCemu

    REM : create a lock file to protect this launch
    set "blf="!CEMU_FOLDER:"=!\BatchFW_!user!-!USERNAME!.lock""
    @echo !DATE! : !user! launched !GAME_TITLE! using !USERNAME! windows profile > !blf!
    if not exist !blf! (
        cscript /nologo !MessageBox! "ERROR when creating !blf:"=!^, need rights in !CEMU_FOLDER:"=!^, please contact your !USERDOMAIN:"=!'s administrator ^!" 4112
        exit 3
    )

    REM : waiting all pre requisities are ready
    call:waitProcessesEnd

    REM : if wiazrd was launched,  links are already created
    if %wizardLaunched% EQU 1 (
        REM : create links to mods
        if ["!gfxType!"] == ["V3"] (
            @echo Searching and load mods found for !GAME_TITLE! ^.^.^. >> !batchFwLog!
            @echo Searching and load mods found for !GAME_TITLE! ^.^.^.
            REM : import mods for the game as graphic packs
            call:importMods > NUL
        )
        goto:minimizeAll
    )

    REM : clean links in game's graphic pack folder
    if exist !GAME_GP_FOLDER! for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        rmdir /Q /S !gpLink! 2>NUL
    )

    REM : create links to mods
    if ["!gfxType!"] == ["V3"] (
        @echo Searching and load mods found for !GAME_TITLE! ^.^.^. >> !batchFwLog!
        @echo Searching and load mods found for !GAME_TITLE! ^.^.^.
        REM : import mods for the game as graphic packs
        call:importMods > NUL
    )

    REM : create links in game's graphic pack folder
    set "fnrLogLggp="!BFW_PATH:"=!\logs\fnr_launchGameGraphicPacks.log""
    if exist !fnrLogLggp! del /F !fnrLogLggp!
    REM : Re launching the search (to get the freshly created packs)
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask rules.txt --includeSubDirectories --find %titleId% --logFile !fnrLogLggp!

    @echo Loading graphic packs for !GAME_TITLE! ^.^.^. >> !batchFwLog!
    @echo Loading graphic packs for !GAME_TITLE! ^.^.^.
    REM : link all missing graphic packs
    REM : always import 16/9 graphic packs

    call:importGraphicPacks > NUL

    REM : get user defined ratios list
    set "ARLIST="
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do set "ARLIST=%%i !ARLIST!"
    if ["!ARLIST!"] == [""] goto:minimizeAll

    REM : import user defined ratios graphic packs
    for %%a in (!ARLIST!) do (
        if ["%%a"] == ["1610"] call:importOtherGraphicPacks 1610 > NUL
        if ["%%a"] == ["219"]  call:importOtherGraphicPacks 219 > NUL
        if ["%%a"] == ["43"]   call:importOtherGraphicPacks 43 > NUL
        if ["%%a"] == ["489"]  call:importOtherGraphicPacks 489 > NUL
    )

    if exist !graphicPacks! move /Y !graphicPacks! !graphicPacksBackup! > NUL
    REM : issue with CEMU 1.15.3 that does not compute cortrectly relative path to GFX folder
    REM : when using a simlink with a the target on another partition
    for %%a in (!GAME_GP_FOLDER!) do set "d1=%%~da"
    for %%a in (!graphicPacks!) do set "d2=%%~da"

    if not ["%d1%"] == ["%d2%"] if not ["%CemuVersionRead%"] == ["NOT_FOUND"] if %CemuVersionRead% GEQ 1153 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL & goto:minimizeAll
    mklink /D /J !graphicPacks! !GAME_GP_FOLDER! 2> NUL
    if !ERRORLEVEL! NEQ 0 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL

    :minimizeAll
    REM : minimize all windows befaore launching in full screen
    set "psCommand="(new-object -COM 'shell.Application')^.minimizeall()""
    powershell !psCommand!

    REM : launching CEMU on game and waiting
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ >> !batchFwLog!
    @echo Starting !CEMU_FOLDER_NAME! with the following command ^: >> !batchFwLog!
    @echo --------------------------------------------------------- >> !batchFwLog!
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Starting !CEMU_FOLDER_NAME! with the following command ^:
    @echo ---------------------------------------------------------
    REM : start a script that will modify cemu.exe priority when it was started
    set "fp="!BFW_TOOLS_PATH:"=!\forcePriority.bat""
    wscript /nologo !StartHidden! !fp!

    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""

    if [!MLC01_FOLDER_PATH!] == [!cml01!] (
        @echo start !cemu! %screenMode% -g !RPX_FILE_PATH! !noLeg! >> !batchFwLog!
        @echo start !cemu! %screenMode% -g !RPX_FILE_PATH! !noLeg!
        wscript /nologo !StartMaximizedWait! !cemu! %screenMode% -g !RPX_FILE_PATH! !noLeg!
        set /a cr_cemu=!ERRORLEVEL!
    ) else (
        @echo start !cemu! %screenMode% -g !RPX_FILE_PATH! -mlc !MLC01_FOLDER_PATH! !noLeg! >> !batchFwLog!
        @echo start !cemu! %screenMode% -g !RPX_FILE_PATH! -mlc !MLC01_FOLDER_PATH! !noLeg!
        wscript /nologo !StartMaximizedWait! !cemu! %screenMode% -g !RPX_FILE_PATH! -mlc !MLC01_FOLDER_PATH! !noLeg!
        set /a cr_cemu=!ERRORLEVEL!
    )
    pushd !BFW_TOOLS_PATH!
    REM : check if cemu if not still running
    :killCemu
    for /F "delims=" %%j in ('tasklist /FI "STATUS eq RUNNING" ^| find /I "cemu.exe"') do (

        wscript /nologo !Start! "%windir%\System32\taskmgr.exe"

        cscript /nologo !MessageBox! "Cemu is already^/still running in the background ^!^, please kill it and hit c to continue" 4112
        goto:killCemu
    )

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ >> !batchFwLog!
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    REM : remove lock file
    del /F /S !blf! > NUL

    REM : analyse CEMU's return code
    :analyseCemuStatus
    set "CEMU_STATUS=Loads"
    if %cr_cemu% NEQ 0 (
        @echo !CEMU_FOLDER_NAME! failed^, return code ^: %cr_cemu% >> !batchFwLog!
        @echo !CEMU_FOLDER_NAME! failed^, return code ^: %cr_cemu%

        REM : is settingsImported = 1, delete shortcut and msbBox
        if !settingsImported! EQU 1 (

            REM : basename of previousSettingsFolder to get version of CEMU used to import settings
            for /F "delims=" %%i in (!previousSettingsFolder!) do set "CEMU_IMPORTED=%%~nxi"
            cscript /nologo !MessageBox! "!CEMU_FOLDER_NAME! crashed with settings imported from !CEMU_IMPORTED! ^(last version used to run the game^)^. ^
                            Launch 'Wii-U Games\CEMU\%CEMU_FOLDER_NAME%\Delete my %CEMU_FOLDER_NAME%^'s settings' and recreate your shortcuts without ^
                            automatic import^, to be sure that is not related^." 4144
        ) else (
            REM : open log.txt
            cscript /nologo !MessageBox! "!CEMU_FOLDER_NAME! crashed, openning its log ^.^.^." 4144
            timeout /T 2 > NUL
            wscript /nologo !Start! "%windir%\System32\notepad.exe" !cemuLog!

        )
        REM : set status to unplayable
        set "CEMU_STATUS=Unplayable"

    ) else (
        @echo !CEMU_FOLDER_NAME! return code ^: %cr_cemu% >> !batchFwLog!
        @echo !CEMU_FOLDER_NAME! return code ^: %cr_cemu%
    )
    REM : saving game's saves for user
    set "bgs="!BFW_TOOLS_PATH:"=!\backupInGameSaves.bat""
    wscript /nologo !StartHidden! !bgs! !GAME_FOLDER_PATH! !MLC01_FOLDER_PATH! !user!

    REM : re-search your current GLCache (also here in case of first run after a drivers upgrade)
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence
    set "OPENGL_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"


    if not [!OPENGL_CACHE!] == ["NOT_FOUND"] if exist !OPENGL_CACHE! goto:searchCacheFolder

    REM : else search it
    REM : first in CEMU folder
    if ["%gpuType%"]==["NVIDIA"] if exist !cemuGLcache! goto:searchCacheFolder

    pushd "%LOCALAPPDATA%"
    set "cache="NOT_FOUND""
    for /F "delims=" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if [!cache!] == ["NOT_FOUND"] pushd "%APPDATA%" && for /F "delims=" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if not [!cache!] == ["NOT_FOUND"] set "OPENGL_CACHE=!cache!"

    pushd !BFW_TOOLS_PATH!
    if [!OPENGL_CACHE!] == ["NOT_FOUND"] (
        @echo Unable to find your GPU GLCache folder ^? backup will be disabled >> !batchFwLog!
        @echo Unable to find your GPU GLCache folder ^? backup will be disabled
        goto:analyseCemuLog
    )
    REM : save path to log file
    call:cleanHostLogFile OPENGL_CACHE
    set "msg="OPENGL_CACHE=!OPENGL_CACHE:"=!""
    call:log2HostFile !msg!

    REM set OPENGL_CACHE_PATH to OPENGL_CACHE
    set "OPENGL_CACHE_PATH=!OPENGL_CACHE!"


    :searchCacheFolder
    REM : backup of GLCache, get the last modified folder under GLCache
    pushd !OPENGL_CACHE_PATH!
    set "newOGLCacheId=NOT_FOUND"
    for /F "delims=" %%x in ('dir /A:D /O:D /B * 2^>NUL') do set "newOGLCacheId=%%x"
    pushd !BFW_TOOLS_PATH!

    if not ["%newOGLCacheId%"] == ["NOT_FOUND"] goto:whatToDo

    REM : if no shader cache folder is found
    REM : search for last modified bin file under OPENGL_CACHE (AMD GPU cache shaders without subfolders)
    pushd !OPENGL_CACHE!
    set "shaderCacheFileName=NOT_FOUND"
    for /F "delims=" %%f in ('dir /O:D /B *.bin 2^>NUL') do set "shaderCacheFileName=%%~nf"
    pushd !BFW_TOOLS_PATH!

    if ["%shaderCacheFileName%"] == ["NOT_FOUND"] goto:warning

    REM : create a new folder to save OGLCache
    set "targetFolder="!GLCacheSavesFolder:"=!\%GPU_VENDOR%@%GPU_DRIVERS_VERSION%\!GAME_TITLE!""
    if not exist !targetFolder! mkdir !targetFolder! > NUL

    pushd !OPENGL_CACHE!
    for /F "delims=" %%f in ('dir /O:D /B %shaderCacheFileName%.* 2^>NUL') do (
        set "file="%%f""
        robocopy !OPENGL_CACHE! !targetFolder! !file! /MOV /IS /IT > NUL
    )
    pushd !BFW_TOOLS_PATH!

    REM : BatchFW will not delete the files already presents under targetFolder
    REM : if the gpu renames the files (64Mo each for AMD)
    goto:whatToDo

    :warning
    REM : if no files were found:
    @echo WARNING ^: unable to find a last shaders cache under !OPENGL_CACHE_PATH!^, cancel GLCache backup ^! >> !batchFwLog!
    @echo WARNING ^: unable to find a last shaders cache under !OPENGL_CACHE_PATH!^, cancel GLCache backup ^!
    goto:moveBack

    :whatToDo
    if ["%newOGLCacheId%"] == ["NOT_FOUND"] goto:moveBack
    if ["%oldOGLCacheId%"] == ["NOT_FOUND"] goto:getGLCache
    if ["%oldOGLCacheId%"] == ["%newOGLCacheId%"] goto:moveBack

    REM : if OGLCacheId changed or oldOGLCacheId NOT_FOUND
    :getGLCache
    set "newOGLCache="!OPENGL_CACHE_PATH:"=!\%newOGLCacheId%""

    if not ["%oldOGLCacheId%"] == ["NOT_FOUND"] (
        @echo WARNING ^: Your display drivers have change OpenGL id for !CEMU_FOLDER_NAME! from %oldOGLCacheId% to %newOGLCacheId% ^! >> !batchFwLog!
        @echo WARNING ^: Your display drivers have change OpenGL id for !CEMU_FOLDER_NAME! from %oldOGLCacheId% to %newOGLCacheId% ^!

        REM : log to host log file
        set "msg="!DATE!-your display drivers have change !CEMU_FOLDER_NAME! GLCache Id from %oldOGLCacheId% to %newOGLCacheId%=%folderName%""
        call:log2HostFile !msg!

    ) else (

        REM : log to host log file : detected OGLCacheId
        set "msg="Detected GLCache Id for !CEMU_FOLDER_NAME! launching !GAME_TITLE!=%newOGLCacheId%""
        call:log2HostFile !msg!
    )

    REM : if a display drivers update was detected
    if %driversUpdateFlag% EQU 1 (
        if exist !IdGpuFolder! rmdir /Q /S !IdGpuFolder! 2>NUL
    )

    if not [!GlCacheSaved!] == ["NOT_FOUND"] (
        REM : remove old folder
        if exist !GlCacheSaved! rmdir /Q /S !GlCacheSaved! 2>NUL
    )
    if not [!GlCache!] == ["NOT_FOUND"] (
        REM : remove folder
        if exist !GlCache! rmdir /Q /S !GlCache! 2>NUL
    )

    REM : create a new folder to save OGLCache
    set "newFolder="!GLCacheSavesFolder:"=!\%GPU_VENDOR%@%GPU_DRIVERS_VERSION%\!GAME_TITLE!\%newOGLCacheId%""

    if not exist !newFolder! mkdir !newFolder! > NUL

    REM : robocopy
    call:moveFolder !newOGLCache! !newFolder! cr
    if !cr! NEQ 0 (
        @echo ERROR when moving !newOGLCache! !newFolder!^, cr=%cr% >> !batchFwLog!
        @echo ERROR when moving !newOGLCache! !newFolder!^, cr=%cr%
    ) else (
        @echo Update GLCache in !newFolder!>> !batchFwLog!
        @echo Update GLCache in !newFolder!
        goto:analyseCemuLog
    )

    REM : move back
    :moveBack

    if [!GlCache!] == ["NOT_FOUND"] goto:analyseCemuLog
    if exist !GlCache! call:moveFolder !GlCache! !GlCacheSaved! cr
    if !cr! NEQ 0 (
        cscript /nologo !MessageBox! "ERROR While moving back GLCache save^, please close all explorer^.exe open in openGL cache folder" 4117
        if !ERRORLEVEL! EQU 4 goto:moveBack
        cscript /nologo !MessageBox! "WARNING ^: relaunch the game until GLCache is backup sucessfully^, if it persists close your session and retry" 4144
    )

    :analyseCemuLog

    call:createLogShorcut

    REM : analyse CEMU's log
    if not exist !cemuLog! goto:titleIdChecked

    REM : get SHADER_MODE
    set "SHADER_MODE=SEPARABLE"
    for /F "delims=" %%i in ('type !cemuLog! ^| find /I "UseSeparableShaders: false"') do set "SHADER_MODE=CONVENTIONAL"

    @echo SHADER_MODE=%SHADER_MODE%>> !batchFwLog!
    @echo SHADER_MODE=%SHADER_MODE%
    set "NEW_SHADER_CACHE_ID=UNKNOWN"
    REM : saving shaderCache
    call:transShaderCache

    REM : let file name with SHADER_MODE suffix
    if not ["%OLD_TRANS_SHADER%"] == ["NONE"] @echo OLD_TRANS_SHADER=%OLD_TRANS_SHADER%>> !batchFwLog!
    @echo NEW_TRANS_SHADER=%NEW_TRANS_SHADER%>> !batchFwLog!
    if not ["%OLD_TRANS_SHADER%"] == ["NONE"] @echo OLD_TRANS_SHADER=%OLD_TRANS_SHADER%
    @echo NEW_TRANS_SHADER=%NEW_TRANS_SHADER%

    REM : Recreate "!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt"
    del /F /S !gameInfoFile! >NUL
    set "getTitleDataFromLibrary="!BFW_TOOLS_PATH:"=!\getTitleDataFromLibrary.bat""

    call !getTitleDataFromLibrary! "%titleId%" > !gameInfoFile!

    REM : get native FPS
    set "FPS=NOT_FOUND"
    for /F "tokens=2 delims=~=" %%i in ('type !gameInfoFile! ^| find /I "native FPS" 2^>NUL') do set "FPS=%%i"

    REM : report compatibility for CEMU_FOLDER_NAME and GAME on USERDOMAIN
    set "rc="!BFW_TOOLS_PATH:"=!\reportCompatibility.bat""
    wscript /nologo !StartHidden! !rc! !GAME_FOLDER_PATH! !CEMU_FOLDER! !user! %titleId% !MLC01_FOLDER_PATH! !CEMU_STATUS! !NEW_SHADER_CACHE_ID! !FPS!
    @echo Compatibility reports updated for !GAME_TITLE! with !CEMU_FOLDER_NAME!>> !batchFwLog!
    @echo Compatibility reports updated for !GAME_TITLE! with !CEMU_FOLDER_NAME!
    REM : check that CEMU recognize the game
    set "UNKNOW_GAME=00050000ffffffff"
    set "cemuTitleLine="NONE""

    for /F "delims=" %%i in ('type !cemuLog! ^| find /I "TitleId"') do (
        set "cemuTitleLine="%%i""
        goto:firstOcTitle
    )
    :firstOcTitle

    if not [!cemuTitleLine!] == ["NONE"] goto:cemuTitleIdExist

    if not [!PROFILE_FILE!] == ["NOT_FOUND"] (
        cscript /nologo !MessageBox! "WARNING ^: TitleId not found in Cemu^'s log ^! CEMU has crashed ^?^ Disabling saving options and exiting ^!" 4144
        goto:endMain
    )
    :cemuTitleIdExist

    for /F "tokens=1-4 delims=:" %%i in (!cemuTitleLine!) do set "str="%%l""
    set "str=!str: =!"
    set "str=!str:-=!"
    set "cemuTitleId=!str:"=!"

    @echo metaTitleId=%titleId%>> !batchFwLog!
    @echo cemuTitleId=%cemuTitleId%>> !batchFwLog!
    @echo metaTitleId=%titleId%
    @echo cemuTitleId=%cemuTitleId%
    if /I ["%cemuTitleId%"] == ["%UNKNOW_GAME%"] goto:unknownGame

    if /I [!PROFILE_FILE!] == ["NOT_FOUND"] (
        set "cemuProfile="!CEMU_FOLDER:"=!\gameProfiles\%cemuTitleId%.ini""
        if exist !cemuProfile! goto:useCemuTitleId
        REM : if no game's profile file is found, it will be created in wizardFirstSaving.bat
    )

    REM : no problems, goto titleIdChecked
    if /I ["%cemuTitleId%"] == ["%titleId%"] goto:titleIdChecked

    if ["%cemuTitleId%"] == [""] (
        cscript /nologo !MessageBox! "Warning ^: TitleId not found in Cemu^'s log ^! CEMU has crashed ^?^ Disabling saving options and exiting ^!" 4144
        goto:endMain
    )

    REM : if title id does not macth between CEMU and game's meta folder
    @echo --------------------------------------------------------->> !batchFwLog!
    @echo Warning ^: CEMU and GAME Title Id not matching  ^!^, disabling saving options ^!>> !batchFwLog!
    @echo meta file titleId = %titleId%>> !batchFwLog!
    @echo cemu titleId = %cemuTitleId%>> !batchFwLog!
    @echo Have you updated the game or installed a DLC for another version ^(US^/EUR^/JPN^) ^?>> !batchFwLog!
    @echo ---------------------------------------------------------
    @echo Warning ^: CEMU and GAME Title Id not matching  ^!^, disabling saving options ^!
    @echo meta file titleId = %titleId%
    @echo cemu titleId = %cemuTitleId%
    @echo Have you updated the game or installed a DLC for another version ^(US^/EUR^/JPN^) ^?
    if %wizardLaunched% EQU 1 (
        @echo CEMU log.txt    : %cemuTitleId%>> !batchFwLog!
        @echo meta/metax.xml  : %titleId%>> !batchFwLog!
        @echo CEMU log.txt    : %cemuTitleId%
        @echo meta/metax.xml  : %titleId%
        rmdir /Q /S !SETTINGS_FOLDER! 2>NUL
    )
    cscript /nologo !MessageBox! "ERROR ^: CEMU and GAME TitleId not matching ^!^, disable saving options" 4112
    goto:endMain

    :useCemuTitleId
    set titleId=%cemuTitleId%
    goto:titleIdChecked

    if /I not "%cemuTitleId%" == "%UNKNOW_GAME%" goto:titleIdChecked

    :unknownGame
    @echo --------------------------------------------------------->> !batchFwLog!
    @echo ERROR ^: UNKNOWN GAME TitleId detected in CEMU Log.txt ^!^, disabling saving options ^!>> !batchFwLog!
    @echo Have you updated the game or installed a DLC ^?>> !batchFwLog!
    @echo TOFIX ^: reinstall game^'s update over ^!>> !batchFwLog!
    @echo ---------------------------------------------------------
    @echo ERROR ^: UNKNOWN GAME TitleId detected in CEMU Log.txt ^!^, disabling saving options ^!
    @echo Have you updated the game or installed a DLC ^?
    @echo TOFIX ^: reinstall game^'s update over ^!
    if %wizardLaunched% EQU 1 (
        @echo CEMU log.txt    ^: %cemuTitleId%>> !batchFwLog!
        @echo meta/metax.xml  ^: %titleId%>> !batchFwLog!
        @echo CEMU log.txt    ^: %cemuTitleId%
        @echo meta/metax.xml  ^: %titleId%
        rmdir /Q /S !SETTINGS_FOLDER! 2>NUL
    )
    cscript /nologo !MessageBox! "ERROR ^: UNKNOWN GAME TitleId detected in CEMU Log^.txt ^!^, disable saving options" 4112
    goto:endMain

    :titleIdChecked

    REM : stoping user's software
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "TO_BE_CLOSED" 2^>NUL') do (
        set "stopThirdPartySoftware="!BFW_TOOLS_PATH:"=!\stopThirdPartySoftware.bat""
        wscript /nologo !StartHidden! !stopThirdPartySoftware!
    )

    REM : if exist, a problem happen with shaderCacheId, write new "!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt"
    if exist !tscl! (
        @echo --------------------------------------------------- >> !tscl!
        @echo GAME_CONFIGURATION after launching !CEMU_FOLDER_NAME! ^: >> !tscl!
        if exist !gameInfoFile! type !gameInfoFile! >> !tscl!
    )

    call:saveCemuOptions

    REM : echo compress game's saves
    set "userGameSave="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!user!.rar""

    if exist !userGameSave! (
        @echo Compress game^'s saves for !user! in inGameSaves^\!GAME_TITLE!_!user!^.rar>> !batchFwLog!
        @echo Compress game^'s saves for !user! in inGameSaves^\!GAME_TITLE!_!user!^.rar
    )

    :endMain

    REM : restore CEMU's graphicPacks subfolder
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    rmdir /Q /S !graphicPacks! 2>NUL
    if exist !graphicPacksBackup! move /Y !graphicPacksBackup! !graphicPacks! > NUL
    if not exist !graphicPacks! mkdir !graphicPacks! > NUL

    REM @echo =========================================================>> !batchFwLog!
    REM @echo This windows will close automatically in 8s>> !batchFwLog!
    REM @echo     ^(n^) ^: don^'t close^, i want to read history log first>> !batchFwLog!
    REM @echo     ^(q^) ^: close it now and quit>> !batchFwLog!
    REM @echo --------------------------------------------------------->> !batchFwLog!
    REM @echo =========================================================
    REM @echo This windows will close automatically in 8s
    REM @echo     ^(n^) ^: don^'t close^, i want to read history log first
    REM @echo     ^(q^) ^: close it now and quit
    REM @echo ---------------------------------------------------------
    REM call:getUserInput "Enter your choice? : " "q,n" ANSWER 8
    REM if [!ANSWER!] == ["n"] (
        REM REM : Waiting before exiting
        REM pause
    REM )

    REM : del log folder for fnr.exe
    if exist !fnrLogFolder! rmdir /Q /S !fnrLogFolder! 2>NUL

    @echo =========================================================>> !batchFwLog!
    @echo Waiting the end of all child processes before ending ^.^.^.>> !batchFwLog!
    @echo =========================================================
    @echo Waiting the end of all child processes before ending ^.^.^.

    exit !ERRORLEVEL!

    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :cleanHostLogFile

        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.tmp""

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL
        move /Y !logFileTmp! !logFile! > NUL

    goto:eof
    REM : ------------------------------------------------------------------

    :waitProcessesEnd

        set "disp=0"
        :waitingLoopProcesses
        timeout /T 1 > NUL
        for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "robocopy" ^| find /I "transferable" ^| find /I /V "find"') do (
            goto:waitingLoopProcesses
        )
        for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "updateGamesGraphicPacks" ^| find /I /V "find"') do (
            if !disp! EQU 0 (
                set "disp=1"
                @echo Creating ^/ completing graphic packs if needed^, please wait ^.^.^. >> !batchFwLog!
                cscript /nologo !MessageBox! "Create or complete graphic packs if needed^, please wait ^.^.^." 4160
            )
            goto:waitingLoopProcesses
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :importMods
        REM : search user's mods under %GAME_FOLDER_PATH%\Cemu\mods
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\mods""
        if not exist !pat! mkdir !pat! > NUL
        for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do (
            set "modName="%%a""
            set "mod="!GAME_FOLDER_PATH:"=!\Cemu\mods\!modName:"=!""
            set "tName="MOD_!modName:"=!""

            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL
            mklink /J /D !linkPath! !mod!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :importOtherGraphicPacks

        set "filter=%~1"
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:"') do (

            set "str=%%i"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" | find /V "_graphicPacksV2" && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_FOLDER:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )

            set "tName=!gp:_graphicPacksV2=!"
            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL
            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            if not ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V2"] mklink /J /D !linkPath! !targetPath! > NUL
            if ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V3"] mklink /J /D !linkPath! !targetPath! > NUL
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :importGraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:"') do (

            set "str=%%i"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" | find /V "_graphicPacksV2" && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_FOLDER:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )

            set "tName=!gp:_graphicPacksV2=!"
            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL
            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            if not ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V2"] mklink /J /D !linkPath! !targetPath! > NUL
            if ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V3"] mklink /J /D !linkPath! !targetPath! > NUL

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

        REM : source drive
        for %%a in (!source!) do set "sourceDrive=%%~da"

        REM : target drive
        for %%a in (!target!) do set "targetDrive=%%~da"

        REM : if folders are on the same drive
        if ["!sourceDrive!"] == ["!targetDrive!"] (

            for %%a in (!target!) do set "parentFolder="%%~dpa""
            set "parentFolder=!parentFolder:~0,-2!""
            if exist !target! rmdir /Q /S !target! 2>NUL

            REM : use move command (much type faster)
            move /Y !source! !parentFolder! > NUL
            set /A "cr=!ERRORLEVEL!"
            if !cr! EQU 1 (
                set /A "%3=1"
            ) else (
                set /A "%3=0"
            )

           goto:eof
        )

        REM : else robocopy
        robocopy !source! !target! /S /MOVE /IS /IT  > NUL
        set /A "cr=!ERRORLEVEL!"

        if !cr! GTR 7 set /A "%3=1"
        if !cr! GEQ 0 set /A "%3=0"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureStringPathForDos

        set "str=%~1"
        set "str=!str:&=!"
        set "str=!str:£=!"
        set "str=!str:(=!"
        set "str=!str:)=!"
        set "str=!str:%%=!"
        set "str=!str:^=!"
        set "str=!str:"=!"
        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------

    :loadCemuOptions

        set "cemuProfile="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""
        if exist !cemuProfile! set "PROFILE_FILE=!cemuProfile!"

        REM : check if it is already a link (case of crash) : delete-it
        set "pat="!CEMU_FOLDER:"=!\*graphicPacks*""
        for /F %%a in ('dir /A:L /B !pat! 2^>NUL') do rmdir /Q !graphicPacks! 2>NUL

        if exist !graphicPacksBackup! rmdir /Q !graphicPacks! && move /Y !graphicPacksBackup! !graphicPacks! > NUL

        set "endTitleId=%titleId:~8,8%"

        REM : remove saves but not before BatchFw first run
        if exist !gameInfoFile! for /F %%i in ('type !gameInfoFile! ^| find "Last launch with"') do (

            REM : delete current saves in mlc01
            set "saveFolder="!MLC01_FOLDER_PATH:"=!\usr\save""
            for /F "delims=" %%i in ('dir /b /o:n /a:d !saveFolder! 2^>NUL') do call:removeSaves "%%i"
        )

        REM : importing game's saves for !user!
        set "rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!user!.rar""
        if not exist !rarFile! goto:savesLoaded

        REM : make a backup of saves fo rarFile
        set "backup=!rarFile:.rar=-backupLaunchN.rar!"

        REM : add a supplementary level of backup because the launch following the crash that have corrupt file
        REM : backup file will be lost and replace by a corrupt backup and you aknowledge that an issue occured only
        REM : on this run
        set "lastValid=!rarFile:.rar=-backupLaunchN-1.rar!"

        if exist !backup! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe"  /C copy /Y !backup! !lastValid! > NUL
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe"  /C copy /Y !rarFile! !backup! > NUL

        set "PREVIOUS_SHADER_CACHE_ID=NONE"

        set "oldSavePath="!MLC01_FOLDER_PATH:"=!\emulatorSave""
        if not exist !oldSavePath! goto:LoadingSaves
        pushd !oldSavePath!

        REM : delete old saves path in MLC01_FOLDER_PATH
        for /F "delims=" %%i in ('dir /b /o:d /a:d * 2^>NUL') do set "PREVIOUS_SHADER_CACHE_ID=%%i"

        if not ["!PREVIOUS_SHADER_CACHE_ID!"] == ["NONE"] (
            set "folder="!oldSavePath:"=!\!PREVIOUS_SHADER_CACHE_ID!""
            if exist !folder! rmdir /Q /S !folder! > NUL
        )

        :LoadingSaves
        for %%a in (!MLC01_FOLDER_PATH!) do set "parentFolder="%%~dpa""
        set "EXTRACT_PATH=!parentFolder:~0,-2!""

        pushd !BFW_TOOLS_PATH!
        @echo Loading saves for !user!^.^.^.>> !batchFwLog!
        @echo Loading saves for !user!^.^.^.
        wscript /nologo !StartHidden! !rarExe! x -o+ -inul !rarFile! !EXTRACT_PATH!

        :savesLoaded
        if not [!PROFILE_FILE!] == ["NOT_FOUND"] goto:isSettingsExist

        REM : if game profile exist, create a shortcut to edit it with notepad
        set "MISSING_PROFILES_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Missing_Games_Profiles""

        REM : create folder !GAMES_FOLDER:"=!\_BatchFW_Missing_Games_Profiles (if need)
        if not exist !MISSING_PROFILES_FOLDER! goto:isSettingsExist

        REM : its path if already saved under _BatchFW_Missing_Games_Profiles
        set "missingProfile="!MISSING_PROFILES_FOLDER:"=!\%titleId%.ini""
        if not exist !missingProfile! goto:isSettingsExist

        REM : import from MISSING_PROFILES_FOLDER
        set "PROFILE_FOLDER="!CEMU_FOLDER:"=!\gameProfiles""

        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !MISSING_PROFILES_FOLDER! !PROFILE_FOLDER! "%titleId%.ini"
        set "PROFILE_FILE="!PROFILE_FOLDER:"=!\%titleId%.ini""

        :isSettingsExist

        if exist !SETTINGS_FOLDER! goto:loaded

        REM : search for the last modified settings folder
        set "previousSettingsFolder="NONE""

        REM : if no import goto:continueLoad
        if ["!IMPORT_MODE!"] == ["DISABLED"] goto:continueLoad

        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\*""
        for /F "delims=" %%i in ('dir /B /O:D /A:D !pat! 2^> NUL') do set "previousSettingsFolder="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\%%i""

        :continueLoad
        if [!previousSettingsFolder!] == ["NONE"] (
            :launchWizard
            set /A "wizardLaunched=1"
            REM : PROFILE_FILE for game that still not exist in CEMU folder = NOT_FOUND (first run on a given host)

            set "ws="!BFW_TOOLS_PATH:"=!\wizardFirstSaving.bat""
            wscript /nologo !StartMaximizedWait! !ws! !CEMU_FOLDER! "!GAME_TITLE!" !PROFILE_FILE! !SETTINGS_FOLDER! !user!
            goto:beforeLoad
        )

        REM : Compare the two game's profile with winmerge :
        REM : patching files for ignoring precompiled cache before diff
        if ["%IGNORE_PRECOMP%"] == ["DISABLED"] call:ignorePrecompiled false
        if ["%IGNORE_PRECOMP%"] == ["ENABLED"] call:ignorePrecompiled true

        REM : get path to CEMU installs folder
        for %%a in (!CEMU_FOLDER!) do set "parentFolder="%%~dpa""
        set "CEMU_INSTALLS_FOLDER=!parentFolder:~0,-2!""
        REM : get the version of CEMU for the imported settings
        for /F "delims=" %%i in (!previousSettingsFolder!) do set "settingFolder=%%~nxi"

        set "OLD_CEMU_VERSION=!settingFolder!"

        REM : search in logFile, getting only the last occurence
        set "pat="%OLD_CEMU_VERSION% install folder path""
        set "lastPath=NONE"
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I !pat! 2^>NUL') do set "lastPath=%%i"

        if ["!lastPath!"] == ["NONE"] goto:bypassComparison

        set "OLD_PROFILE_FILE="!lastPath!\gameProfiles\%titleId%.ini""
        if not exist !OLD_PROFILE_FILE! goto:bypassComparison

        REM : diff game's profiles, open winmerge on the two files
        set "WinMergeU="!BFW_PATH:"=!\resources\winmerge\WinMergeU.exe""
        call !WinMergeU! /xq !OLD_PROFILE_FILE! !PROFILE_FILE!
        cscript /nologo !MessageBox! "Importing !OLD_CEMU_VERSION! settings for !CEMU_FOLDER_NAME!^, check that all CEMU^'s settings are still OK ^(set^/modify if needed^)^." 4160
        goto:syncCP

        :bypassComparison
        cscript /nologo !MessageBox! "Importing !OLD_CEMU_VERSION! settings for !CEMU_FOLDER_NAME!^, check that all CEMU^'s settings are still OK ^(set^/modify if needed^)^." 4160

        :syncCP
        REM : synchronized controller profiles (import)
        call:syncControllerProfiles
        @echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!^\ControllerProfiles vs _BatchFW_Controller_Profiles^\!USERDOMAIN!^)>> !batchFwLog!
        @echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!^\ControllerProfiles vs _BatchFW_Controller_Profiles^\!USERDOMAIN!^)
        set "nsf="!GAME_FOLDER_PATH:"=!\Cemu\settings\!USERDOMAIN!\!CEMU_FOLDER_NAME!""
        @echo Import settings from !previousSettingsFolder:"=! >> !batchFwLog!
        @echo Import settings from !previousSettingsFolder:"=!

        set /A "settingsImported=1"
        robocopy !previousSettingsFolder! !nsf! /S > NUL

        REM : log to games library log file
        set "msg="!GAME_TITLE!:!DATE!-!user!@!USERDOMAIN! import settings in !nsf:"=! from=!previousSettingsFolder:"=!""
        call:log2GamesLibraryFile !msg!

        :beforeLoad

        REM : if wizard was launched set PROFILE_FILE because it was not found earlier
        set "cemuProfile="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""
        if exist !cemuProfile! set "PROFILE_FILE=!cemuProfile!"

        :loaded
        for /F "delims=" %%i in (!SETTINGS_FOLDER!) do set "settingsFolderName=%%~nxi"
        @echo Using settings from !settingsFolderName! for !user! ^!>> !batchFwLog!
        @echo Using settings from !settingsFolderName! for !user! ^!

        REM : looking for last modified *settings.bin to create !user!_settings.bin
        call:setSettingsForUser

        REM : loading CEMU an cemuHook settings
        robocopy !SETTINGS_FOLDER! !CEMU_FOLDER! !user!_settings.bin > NUL
        set "src="!CEMU_FOLDER:"=!\!user!_settings.bin""
        set "target="!CEMU_FOLDER:"=!\settings.bin""
        move /Y !src! !target!

        robocopy !SETTINGS_FOLDER! !CEMU_FOLDER! !user!_settings.xml > NUL
        set "src="!CEMU_FOLDER:"=!\!user!_settings.xml""
        set "target="!CEMU_FOLDER:"=!\settings.xml""
        move /Y !src! !target!

        robocopy !SETTINGS_FOLDER! !CEMU_FOLDER! !user!_cemuhook.ini > NUL
        set "src="!CEMU_FOLDER:"=!\!user!_cemuhook.ini""
        set "target="!CEMU_FOLDER:"=!\cemuhook.ini""
        move /Y !src! !target!

        set "controllersProfilesSaved="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
        set "controllersProfiles="!CEMU_FOLDER:"=!\controllerProfiles""
        robocopy !controllersProfilesSaved! !controllersProfiles! > NUL

        REM : patching files for ignoring precompiled cache
        if ["%IGNORE_PRECOMP%"] == ["DISABLED"] call:ignorePrecompiled false
        if ["%IGNORE_PRECOMP%"] == ["ENABLED"] call:ignorePrecompiled true

        REM : set onlines files for user
        call:setOnlineFiles

        REM : if needed, create a game profile shorcut
        call:createGameProfileShorcut

        REM : if needed, create a example.ini profile shorcut
        call:createExampleIniShorcut

    goto:eof
    REM : ------------------------------------------------------------------

    :setSettingsForUser

        set "target="!SETTINGS_FOLDER:"=!\!user!_settings.bin""
        if exist !target! goto:eof

        pushd !SETTINGS_FOLDER!

        for /F "delims=~" %%i in ('dir /O:D /B *settings.bin') do (
            set "f="%%i""
            copy /Y !f! !user!_settings.bin
            REM : remove old saved settings
            if [!f!] == ["settings.bin"] del /F !f! > NUL
        )
        for /F "delims=~" %%i in ('dir /O:D /B *settings.xml') do (
            set "f="%%i""
            copy /Y !f! !user!_settings.xml
            REM : remove old saved settings
            if [!f!] == ["settings.xml"] del /F !f! > NUL
        )
        set "target="!SETTINGS_FOLDER:"=!\!user!_cemuhook.ini""
        for /F "delims=~" %%i in ('dir /O:D /B *cemuhook.ini') do (
            set "f="%%i""
            copy /Y !f! !user!_cemuhook.ini
            REM : remove old saved settings
            if [!f!] == ["cemuhook.ini"] del /F !f! > NUL
        )

        pushd !BFW_TOOLS_PATH!

    goto:eof
    REM : ------------------------------------------------------------------


    :ignorePrecompiled

        set "value=%1"

        set "chs="!CEMU_FOLDER:"=!\cemuhook.ini""
        REM : check if cemuHook.ini exist
        if not exist !chs! goto:patchGp

        REM : else verifiy cemu hook install
        set dllFile="!CEMU_FOLDER:"=!\keystone.dll""

        REM : if not exit exit
        if not exist !dllFile! goto:patchGp

        REM : force ignorePrecompiledShaderCache = true in cemuHook.ini
        call:patchGraphicSection !chs! "ignorePrecompiledShaderCache" %value%

        :patchGp

        REM : force disablePrecompiledShaders = true in PROFILE_FILE
        call:patchGraphicSection !PROFILE_FILE! "disablePrecompiledShaders" %value%

        :display
        @echo Ignoring precompiled shader = %value%>> !batchFwLog!
        @echo Ignoring precompiled shader = %value%
    goto:eof
    REM : ------------------------------------------------------------------

    :getHostState
        set "ipaddr=%~1"

        set /A state=0
        for /f "tokens=5,6,7" %%a in ('ping -n 1 !ipaddr!') do (
            if "x%%a"=="xReceived" if "x%%c"=="x1,"  set /A "state=1"
        )
        
        set "~2=!state!"
    goto:eof
    REM : ------------------------------------------------------------------

    :setOnlineFiles

        set "BFW_ONLINE="!GAMES_FOLDER:"=!\_BatchFW_WiiU\onlineFiles""
        set "BFW_ONLINE_ACC="!BFW_ONLINE:"=!\usersAccounts""

        If not exist !BFW_ONLINE_ACC! goto:eof

        REM : get the account.dat file for the current user and the accId
        set "accId=NONE"

        set "pat="!BFW_ONLINE_ACC:"=!\!user!*.dat""

        for /F "delims=~" %%i in ('dir /B !pat!') do (
            set "af="!BFW_ONLINE_ACC:"=!\%%i""

            for /F "delims=~= tokens=2" %%j in ('type !af! ^| find /I "AccountId="') do set "accId=%%j"
        )

        if ["!accId!"] == ["NONE"] (
            @echo WARNING^: AccountId not found for !user!
            @echo WARNING^: AccountId not found for !user!  >> !batchFwLog!
            cscript /nologo !MessageBox! "AccountId not found for !user!, cancel online files installation" 4160
            goto:eof
        )

        REM : check if the Wii-U is not power on
        set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
        if not exist !winScpIni! goto:installAccount
        
        REM : get the hostname
        for /F "delims== tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
        REM : check its state
        set /A "state=NONE"
        call:getHostState !ipRead! state

        if !state! EQU 1 (
            cscript /nologo !MessageBox! "A host with your last Wii-U adress was found on the network. Be sure that no one is using your account ^(!accId!^) to play online right now^. Cancel to abort using online feature" 4112
            if !ERRORLEVEL! EQU 2 goto:eof
        )

        :installAccount
        REM : copy !af! to "!MLC01_FOLDER_PATH:"=!\usr\save\system\act\80000001\account.dat"
        set "target="!MLC01_FOLDER_PATH:"=!\usr\save\system\act\80000001\account.dat""
        copy /Y !af! !target!

        REM : patch settings.xml
        set "cs="!CEMU_FOLDER:"=!\settings.xml""
        set "csTmp="!CEMU_FOLDER:"=!\settings.tmp""
              
        type !cs! | find /V "AccountId" | find /V "/Online" | find /V "/content" > !csTmp!
        
        echo         ^<AccountId^>!accId!^<^/AccountId^> >> !csTmp!
        echo     ^<^/Online^> >> !csTmp!
        echo ^<^/content^> >> !csTmp!

        del /F !cs! > NUL
        move /Y !csTmp! !cs! > NUL

        @echo Online account enabled for !user! ^: !accId! >> !batchFwLog!
        @echo Online account enabled for !user! ^: !accId!

    goto:eof
    REM : ------------------------------------------------------------------


    :patchGraphicSection
        REM : arg1 : file
        set "file="%~1""

        REM : arg2 : label
        set "label=%~2"

        REM : boolean value to set
        set "value=%3"

        if ["%value%"] == ["true"]  set "valueB=false"
        if ["%value%"] == ["false"] set "valueB=true"

        set "str=%label% = %valueB%"
        set "strWithoutSpace=!str: =!"
        set "strTarget=%label% = %value%"
        set "strTargetWithoutSpace=!strTarget: =!"

        REM : if strTarget found in file : exit
        for /F "delims=" %%i in ('type !file! ^| find /I "!strTarget!"') do goto:eof
        REM : if strTargetWithoutSpace found in file : exit
        for /F "delims=" %%i in ('type !file! ^| find /I "!strTargetWithoutSpace!"') do goto:eof

        REM : if [Graphics] is found in file and is commented : goto patchGraphic
        for /F "delims=" %%i in ('type !file! ^| find /I "[Graphics]"') do for /F "delims=" %%j in ('type !file! ^| find /I "#[Graphics]"') do goto:patchGraphic

        REM : if disablePrecompiledShaders=false found in !file!, replace in file
        for /F "delims=" %%i in ('type !file! ^| find /I "[Graphics]"') do (
            call:replaceInFile
            goto:eof
        )

        :patchGraphic
        REM : if [Graphics] not found
        echo. >> !file!
        echo # add by batchFw>> !file!
        echo [Graphics]>> !file!
        echo !strTarget!>> !file!

    goto:eof
    REM : ------------------------------------------------------------------

    :replaceInFile

        REM get file name to create file filter for fnr.exe
        for /F "delims=" %%a in (!file!) do set "filter=%%~nxa"
        for %%a in (!file!) do set "tmp="%%~dpa""
        set "parentFolder=!tmp:~0,-2!""

        REM : log file
        set "fnrLogFile="!fnrLogFolder:"=!\%filter:"=%.log""

        REM : if str found in file : replace it with strTarget
        for /F "delims=" %%i in ('type !file! ^| find /I "!str!" 2^>NUL') do (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !parentFolder! --fileMask %filter% --find "!str!" --replace "!strTarget!" --logFile !fnrLogFile!

            goto:eof
        )

        REM : if strWithoutSpace found in file : strTargetWithoutSpace
        if exist !fnrLogFile! del /F !fnrLogFile!
        for /F "delims=" %%i in ('type !file! ^| find /I "!strWithoutSpace!" 2^>NUL') do (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !parentFolder! --fileMask %filter% --find "!strWithoutSpace!" --replace "!strTargetWithoutSpace!" --logFile !fnrLogFile!

            goto:eof
        )

        REM : if [Graphics] found in file :
        if exist !fnrLogFile! del /F !fnrLogFile!
        for /F "delims=" %%i in ('type !file! ^| find /I "[Graphics]" 2^>NUL') do (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !parentFolder! --fileMask %filter% --find "[Graphics]" --replace "[Graphics]\n!strTarget!" --logFile !fnrLogFile!

            goto:eof
        )


        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !parentFolder! --fileMask %filter% --find "[Graphics]" --replace "[Graphics]\n!strTarget!" --logFile !fnrLogFile!


    goto:eof
    REM : ------------------------------------------------------------------

    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Controller_Profiles\!USERDOMAIN!""
        if not exist !CONTROLLER_PROFILE_FOLDER! mkdir !CONTROLLER_PROFILE_FOLDER! > NUL

        set "ccp="!CEMU_FOLDER:"=!\ControllerProfiles""
        if not exist !ccp! goto:eof

        set "gcp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles\!USERDOMAIN!""
        if not exist !gcp! goto:syncWithBatchFW

        pushd !gcp!
        REM : import from GAME_FOLDER_PATH to CEMU_FOLDER
        for /F "delims=" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!gcp:"=!\%%x"
            if not exist !ccpf!  wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !gcp! !ccp! "%%x"
        )

        pushd !ccp!
        REM : import from CEMU_FOLDER to CONTROLLER_PROFILE_FOLDER
        for /F "delims=" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !bcpf! wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ccp! !CONTROLLER_PROFILE_FOLDER! "%%x" /XF "controller*.*"
        )

        :syncWithBatchFW
        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            set "bcpf="!CONTROLLER_PROFILE_FOLDER:"=!\%%x"
            if not exist !ccpf! robocopy  !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" > NUL
        )
        pushd !BFW_TOOLS_PATH!

    goto:eof


    :createGameProfileShorcut

        REM : add a shortcut in Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles to edit game's profile
        REM : shortcut to game's profile
        set "profileShortcut="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles\!GAME_TITLE!.lnk""
        if exist !profileShortcut! goto:eof

        REM : if game profile exist, create a shortcut to edit it with notepad
        set "MISSING_PROFILES_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Missing_Games_Profiles""

        REM : create folder !GAMES_FOLDER:"=!\_BatchFW_Missing_Games_Profiles (if need)
        if not exist !MISSING_PROFILES_FOLDER! mkdir !MISSING_PROFILES_FOLDER! > NUL
        REM : in wizardFirstSaving.bat profile file is first created in _BatchFW_Missing_Games_Profiles subfolder, then copied to cemu one

        REM : its path if already saved under _BatchFW_Missing_Games_Profiles
        set "ugp="!MISSING_PROFILES_FOLDER:"=!\%titleId%.ini""

        REM : not using !PROFILE_FILE! could be always at NOT_FOUND, search for freshly created profile in cemu folder
        set "cgp="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""

        REM : if game profile does not exist in CEMU subfolder
        if not exist !cgp! (
            REM : if exist in_BatchFW_Missing_Games_Profiles copy it to cemu folder
            if exist !ugp! copy /Y !ugp! !cgp! > NUL
        )

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\CEMU_!DATE!.vbs""

        set "ARGS=!cgp:"=!"

        REM : create a shortcut to game's profile
        set "gpsf="!OUTPUT_FOLDER:"=!\Wii-U Games\CEMU\!CEMU_FOLDER_NAME!\Games Profiles""
        if not exist !gpsf! mkdir !gpsf! > NUL

        set "LINK_DESCRIPTION="Edit !GAME_TITLE!'s profile for !CEMU_FOLDER_NAME!""

        REM : create object
        echo Set oWS = WScript.CreateObject("WScript.Shell") > !TMP_VBS_FILE!
        echo sLinkFile = !profileShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS.createShortCut(sLinkFile) >> !TMP_VBS_FILE!
        echo oLink.TargetPath = "!ARGS!" >> !TMP_VBS_FILE!

        echo oLink.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        echo oLink.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof

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
        if not exist !gpsf! mkdir !gpsf! > NUL

        set "LINK_DESCRIPTION="Edit example.ini profile for !CEMU_FOLDER_NAME!""

        REM : create object
        echo Set oWS = WScript.CreateObject("WScript.Shell") > !TMP_VBS_FILE!
        echo sLinkFile = !profileShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS.createShortCut(sLinkFile) >> !TMP_VBS_FILE!
        echo oLink.TargetPath = "!ARGS!" >> !TMP_VBS_FILE!

        echo oLink.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof

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
        if not exist !gpsf! mkdir !gpsf! > NUL

        set "LINK_DESCRIPTION="!CEMU_FOLDER_NAME!'s Log""

        REM : create object
        echo Set oWS = WScript.CreateObject("WScript.Shell") > !TMP_VBS_FILE!
        echo sLinkFile = !logShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS.createShortCut(sLinkFile) >> !TMP_VBS_FILE!
        echo oLink.TargetPath = !ARGS! >> !TMP_VBS_FILE!
        echo oLink.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof


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
        echo Set oWS = WScript.CreateObject("WScript.Shell") > !TMP_VBS_FILE!
        echo sLinkFile = !logShortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS.createShortCut(sLinkFile) >> !TMP_VBS_FILE!
        echo oLink.TargetPath = !ARGS! >> !TMP_VBS_FILE!
        echo oLink.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink.WorkingDirectory = !CEMU_FOLDER! >> !TMP_VBS_FILE!
        echo oLink.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE!

    goto:eof


    :saveCemuOptions

        if exist !SETTINGS_FOLDER! (

            REM : saving CEMU an cemuHook settings
            robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.bin > NUL
            set "src="!SETTINGS_FOLDER:"=!\settings.bin""
            set "target="!SETTINGS_FOLDER:"=!\!user!_settings.bin""
            move /Y !src! !target!

            robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.xml > NUL
            set "src="!SETTINGS_FOLDER:"=!\settings.xml""
            set "target="!SETTINGS_FOLDER:"=!\!user!_settings.xml""
            move /Y !src! !target!

            robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! cemuhook.ini > NUL
            set "src="!SETTINGS_FOLDER:"=!\cemuhook.ini""
            set "target="!SETTINGS_FOLDER:"=!\!user!_cemuhook.ini""
            move /Y !src! !target!

            @echo CEMU options saved to !SETTINGS_FOLDER:"=! for !user! ^!>> !batchFwLog!
            @echo CEMU options saved to !SETTINGS_FOLDER:"=! for !user! ^!
        )

        set "gcp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
        set "ccp="!CEMU_FOLDER:"=!\controllerProfiles""
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ccp! !gcp!

    goto:eof
    REM : ------------------------------------------------------------------

    :removeSaves
        set "sf="!saveFolder:"=!\%~1\%endTitleId%""
        if exist !sf! rmdir /Q /S !sf! 2>NUL

    goto:eof
    REM : ------------------------------------------------------------------
    :transShaderCache

        REM : get NEW_TRANS_SHADER id from log.txt
        set "strTmp=NONE"
        for /F "tokens=1-4 delims=:~" %%i in ('type !cemuLog! ^| find /I "shaderCache" 2^>NUL') do (
            set "strTmp=%%l"
            goto:firstOcShaderCache
        )


        :firstOcShaderCache

        if ["!strTmp!"] == ["NONE"] (
            @echo Unable to get shaderCacheId line in !cemuLog!^, skip saving shader cache ^!>> !batchFwLog!
            @echo Unable to get shaderCacheId line in !cemuLog!^, skip saving shader cache ^!
            goto:eof
        )
        set "NEW_SHADER_CACHE_ID=%strTmp: =%"
        set "NEW_TRANS_SHADER=%NEW_SHADER_CACHE_ID%.bin"

        set "OLD_TRANS_SHADER=%OLD_SHADER_CACHE_ID%.bin"

        if ["!SHADER_MODE!"] == ["CONVENTIONAL"] (
            set "OLD_TRANS_SHADER=%OLD_SHADER_CACHE_ID%_j.bin"
            set "NEW_TRANS_SHADER=%NEW_SHADER_CACHE_ID%_j.bin"
        )

        if not exist !ctscf! goto:eof

        if exist !gtscf! goto:handleShaderFiles

        mkdir !gtscf! > NUL
        REM :  move CEMU transferable shader cache file to GAME_FOLDER_PATH
        echo move !ctscf! to !gtscf!>> !batchFwLog!
        echo move !ctscf! to !gtscf!
        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf!  !gtscf! "!NEW_TRANS_SHADER!" /MOV /IS /IT
        goto:eof

        :handleShaderFiles
        REM : not transShaderCache found in game's subfolder goto:copyBackShaderCache

        if ["!OLD_SHADER_CACHE_ID!"] == ["NONE"] goto:copyBackShaderCache

        REM : get the 2 files sizes
        set "otscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!OLD_TRANS_SHADER!""
        set "ntscf="!cemuShaderCache:"=!\transferable\!NEW_TRANS_SHADER!""

        if exist !ntscf! (
            for /F "tokens=*" %%a in (!ntscf!)  do set "newSize=%%~za"
        ) else (
            set "newSize=0"
        )
        if exist !otscf! (
            for /F "tokens=*" %%a in (!otscf!)  do set "oldSize=%%~za"
        ) else (
            set "oldSize=0"
        )

        @echo CEMU transferable cache file !NEW_TRANS_SHADER! have a size of  ^:  %newSize%
        @echo Saved transferable cache file !OLD_TRANS_SHADER! have a size of ^:  %oldSize%

        REM : prepare log to edit it
        @echo --------------------------------------------------- >> !tscl!
        @echo - [!DATE!] !user!@!USERDOMAIN! >> !tscl!
        @echo - >> !tscl!
        @echo - CEMU install = !CEMU_FOLDER! >> !tscl!
        @echo - >> !tscl!
        @echo - CEMU transferable cache file size  !NEW_TRANS_SHADER! = %newSize% >> !tscl!
        @echo - Saved transferable cache file size !OLD_TRANS_SHADER! = %oldSize% >> !tscl!
        @echo - >> !tscl!

        REM : OLD_TRANS_SHADER cache file renamed
        set "otscr="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!OLD_SHADER_CACHE_ID!.old""
        REM : NEW_TRANS_SHADER cache file saving path
        set "gntscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!NEW_TRANS_SHADER!""

        REM : if the two file have the same name goto:savingShaderCache
        if ["!NEW_TRANS_SHADER!"] == ["!OLD_TRANS_SHADER!"] goto:savingShaderCache

        REM : switching CONVENTIONNAL <-> SEPARABLE
        set "checkToConv=!OLD_SHADER_CACHE_ID!_j"
        if ["!checkToConv!"] == ["%NEW_SHADER_CACHE_ID%"] goto:savingShaderCache
        set "checkToSep=!OLD_SHADER_CACHE_ID:_j=!"
        if ["!checkToSep!"] == ["%NEW_SHADER_CACHE_ID%"] goto:savingShaderCache

        REM : SHADERCACHEID ARE DIFFERENTS : throw a user notification with notepad in the 2 following case

        @echo - !GAME_TITLE! ShaderCacheId has changed from !OLD_TRANS_SHADER! to !NEW_TRANS_SHADER! >> !tscl!

        REM : compare their size
        if %newSize% GTR %oldSize% (

            REM : CEMU file bigger than saved one (degraded case)  : rename the saved old one, move CEMU file for saving, update log, add date ?
            @echo - CEMU transferable cache file size is greater than saved one >> !tscl!
            @echo - >> !tscl!
            @echo - Is !CEMU_FOLDER_NAME! change the shaderCacheId ^? >> !tscl!
            @echo - >> !tscl!
            @echo - Renaming saved cache to !OLD_SHADER_CACHE_ID!.old >> !tscl!

            move /Y !otscf! !otscr! > NUL
            @echo - >> !tscl!
            @echo - Moving CEMU^'s transferable shader cache to game^'s folder >> !tscl!
            wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf! !gtscf! "!NEW_TRANS_SHADER!" /MOV /IS /IT
            @echo - >> !tscl!

            set "tscrl="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!CEMU_FOLDER_NAME!_replace_!OLD_SHADER_CACHE_ID!_with_!NEW_SHADER_CACHE_ID!""

            @echo - [!DATE!] !user!@!USERDOMAIN! with !CEMU_FOLDER_NAME! > !tscrl!
            @echo - >> !tscrl!
            @echo - !CEMU_FOLDER_NAME! change !GAME_TITLE!^'s ShaderCacheId from !OLD_SHADER_CACHE_ID! to !NEW_SHADER_CACHE_ID! >> !tscrl!

        ) else (

            REM : saved file bigger than CEMU's one (nominal case) : import an external transferable shader cache -> use CEMU shaderCacheId to rename the imported file, delete CEMU file
            @echo - Saved transferable cache file size is greater than CEMU one >> !tscl!
            @echo - >> !tscl!

            @echo - You certainly about import an external transferable shader cache with a wrong name >> !tscl!
            @echo - Renaming saved cache with CEMU^'s one name^.^.^. >> !tscl!
            @echo - >> !tscl!

            move /Y !otscf! !gntscf! > NUL

            @echo - >> !tscl!
        )

        @echo - >> !tscl!
        @echo ^(close notepad to continue^) >> !tscl!
        @echo ^(close notepad to continue^)>> !batchFwLog!
        @echo ^(close notepad to continue^)
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tscl!

        goto:eof

        :savingShaderCache
        REM : SHADERCACHEID IDENTICALS : no need to check size, treatment is the same. Do it only for log

        REM : compare their size
        if %newSize% GEQ %oldSize%  (

            REM : CEMU file bigger than saved one (nominal case)  : overwrite saved by moving CEMU file
            echo move !ntscf! to !otscf!>> !batchFwLog!
            echo move !ntscf! to !otscf!
            goto:copyBackShaderCache
        )

        REM : saved file bigger than CEMU's one : case of upgrading a transferable shader file with the right name
        @echo - Saved transferable cache file size is greater than CEMU one >> !tscl!
        @echo - As the saved one was copied before launching the game in cemu FOLDER >> !tscl!
        @echo - there^'s no doubts that !CEMU_FOLDER_NAME! broke shaderCache compatibility >> !tscl!
        @echo - >> !tscl!
        @echo - If you are in case 2^, backup if justified or delete !OLD_SHADER_CACHE_ID!^.old >> !tscl!
        @echo - >> !tscl!

        set "btscl="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable\!CEMU_FOLDER_NAME!_broke_!OLD_SHADER_CACHE_ID!""

        @echo - [!DATE!] !user!@!USERDOMAIN! with !CEMU_FOLDER_NAME! > !btscl!
        @echo - >> !btscl!
        @echo - !CEMU_FOLDER_NAME! refuse to use !OLD_SHADER_CACHE_ID!^.old >> !btscl!

        REM : rename saved file
        move /Y !otscf! !otscr! > NUL
        move /Y !gntscf! !ntscf! > NUL

        @echo - >> !tscl!
        @echo ^(close notepad to continue^) >> !tscl!
        @echo ^(close notepad to continue^)>> !batchFwLog!
        @echo ^(close notepad to continue^)
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tscl!

        :copyBackShaderCache
        REM : move CEMU transferable shader cache file to GAME_FOLDER_PATH

        if ["!SHADER_MODE!"] == ["SEPARABLE"] (
            set "NEW_TRANS_SHADER=!NEW_TRANS_SHADER:_j.bin=.bin!"
        ) else (
            set "NEW_TRANS_SHADER=!NEW_TRANS_SHADER:.bin=_j.bin!"
        )

        wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C robocopy !ctscf! !gtscf! !NEW_TRANS_SHADER! /MOV /IS /IT  > NUL

        :delLog
        REM : delete transShaderCache.log (useless)
        if exist !tscl! del /F /S !tscl!  > NUL

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

    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13>> !batchFwLog!
            @echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11>> !batchFwLog!
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12>> !batchFwLog!
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1>> !batchFwLog!
            @echo Host char codeSet not found ^?^, exiting 1
            timeout /t 8 > NUL
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic path Win32_OperatingSystem get Locale /value ^| find "="') do set "L0CALE_CODE=%%f"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\GamesLibrary.log""
        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL
        move /Y !gLogFileTmp! !glogFile! > NUL

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"


        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------