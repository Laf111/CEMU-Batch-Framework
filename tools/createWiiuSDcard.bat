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
        echo ERROR^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
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

    set "ffat32="!BFW_RESOURCES_PATH:"=!\fat32format.exe""
    set "rarExe="!BFW_PATH:"=!\resources\rar.exe""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""    
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet
    cls

    echo =========================================================
    echo Prepare a SDcard for the Wii-U
    echo =========================================================
    echo.
    echo - format your device in FAT32 (32K clusters size)
    echo - install ^:
    echo       ^* HBL ^(HomeBrew Launcher^)
    echo       ^* appStore ^(HomeBrew AppStore^)
    echo       ^* DDD ^(WiiU Disk itle Dumper^)
    echo       ^* MOCHA ^(MOCHA CFW^)
    echo       ^* WiiU FTP Server
    echo       ^* loadiine_gx2_y_mod ^(to launch DDD dumps^)
    echo       ^* nanddumper ^(to dump your NAND and get online files^)
    echo       ^* dumpling ^(dump your games^)
    echo       ^* sigpatcher2sysmenu ^(DLC patch with non permanent CFW^)
    echo       ^* wup_installer_gx2 ^(installer for WUP format^)
    echo.
    echo Once plugged in your Wii-U^, open the internet browser
    echo and enter the following adress ^: http^:^/^/wiiuexploit^.xyz
    echo ^(you might add this URL to your favorites^)
    echo.
    echo if your wiiu is connected to internet^, you can use
    echo appStore to update^/install other apps.
    echo.
    echo =========================================================
    echo.
    echo Close ALL windows explorer instances^, before continue
    echo.
    pause

    :askDrive
    set "SDCARD="NONE""
    for /F %%b in ('cscript /nologo !browseFolder! "Select the drive of your SDCard"') do set "folder=%%b" && set "SDCARD=!folder:?= !"
    if [!SDCARD!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askDrive
    )

    for %%a in (!SDCARD!) do set "SDCARD=%%~da"
    :formatDrive
    REM : format %SDCARD% with fat32format.exe
    !ffat32! -c64 %SDCARD%
    if !ERRORLEVEL! NEQ 0 goto:formatDrive
    echo.
    echo ---------------------------------------------------------
    echo Installing content^.^.^.
    REM : install content
    set "sdCardContent="!BFW_RESOURCES_PATH:"=!\WiiuSDcard.rar""

    wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul -w!BFW_LOGS! !sdCardContent! !SDCARD! > NUL 2>&1
    echo done
    echo =========================================================

    pause

    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

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

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_OperatingSystem get Locale /value 2^>NUL ^| find "="') do set "L0CALE_CODE=%%f"

    goto:eof
    REM : ------------------------------------------------------------------
