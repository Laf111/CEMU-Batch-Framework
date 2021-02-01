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

    for %%a in (!BFW_TOOLS_PATH!) do set "basename="%%~dpa""
    set "BFW_PATH=!basename:~0,-2!""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

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

    REM : cd to BFW_TOOLS_PATH
    pushd !BFW_TOOLS_PATH!

    echo =========================================================
    echo Wipe all traces on !USERDOMAIN!
    echo =========================================================
    pause
    echo ---------------------------------------------------------
    echo Removing Cemu installs^.^.^.
    REM : delete all cemu installs on !USERDOMAIN!

    REM : search in logFile, getting only the last occurence
    set "previousPath=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "install folder path" 2^>NUL') do (
        set "previousPath="%%i""
        if exist !previousPath! (
            echo ^> remove !previousPath!
            rmdir /S /Q !previousPath! > NUL 2>&1
            REM : flush logFile
            call:cleanHostLogFile !previousPath!
        )
    )

    echo ---------------------------------------------------------
    echo Removing shortcuts created^.^.^.
    echo.

    REM : get the last location from logFile
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do (
        set "WIIU_GAMES_FOLDER="%%i""
        if exist !WIIU_GAMES_FOLDER! (

            rmdir /Q /S !WIIU_GAMES_FOLDER! > NUL 2>&1
            echo ^> !WIIU_GAMES_FOLDER! deleted ^!

            REM : flush logFile
            call:cleanHostLogFile !WIIU_GAMES_FOLDER!
        )
    )

    REM : search your current GLCache
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence

    set "OPENGL_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"

    if [!OPENGL_CACHE!] == ["NOT_FOUND"] goto:ending

    echo ---------------------------------------------------------
    echo BatchFw saves all your GPU Caches in !OPENGL_CACHE:"=!
    echo.
    choice /C yn /N /M "Do you want to also remove your GPU caches ? (y, n)"
    if !ERRORLEVEL! EQU 2 goto:ending

    set "GLCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuGLCache!\"

    if not exist !GLCacheSavesFolder! goto:cleanBfwVkCache
    rmdir /Q /S !GLCacheSavesFolder! > NUL 2>&1
    echo.
    echo ^> OpenGL caches were removed ^!

    :cleanBfwVkCache
    set "VkCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuVkCache!"

    if exist !VkCacheSavesFolder! (
        rmdir /Q /S !VkCacheSavesFolder! > NUL 2>&1
        echo.
        echo ^> Vulkan caches were removed ^!
    )
    REM : flush logFile
    call:cleanHostLogFile !OPENGL_CACHE!
    
    :ending
    echo =========================================================
    echo done
    timeout /T 3 > NUL 2>&1

    endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

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
