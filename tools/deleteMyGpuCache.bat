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

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

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

    if [!OPENGL_CACHE!] == ["NOT_FOUND"] (
        echo Unable to find your GPU GLCache folder ^? cancelling
        goto:eof
    )

    REM : save path to log file
    set "msg="OPENGL_CACHE=!OPENGL_CACHE:"=!""
    call:log2HostFile !msg!

    REM : openGL cache location
    :glCacheFound
    choice /C yn /T 4 /D y /N /M "Flush !OPENGL_CACHE:"=! (y/n : yes by default in 4s) ?:"
    if %ERRORLEVEL% EQU 2 (
        choice /C y /T 2 /D y /N /M "> Cancelled by user"
        goto:cemuInstalls
    )
    rmdir /Q /S !OPENGL_CACHE! > NUL 2>&1
    mkdir !OPENGL_CACHE! > NUL 2>&1

    echo ^> !OPENGL_CACHE:"=! was cleared ^!

    :cemuInstalls


    choice /C yn /T 4 /D y /N /M "Clear all shader caches of ALL your CEMU installs (y/n : yes by default in 4s) ?:"
    if %ERRORLEVEL% EQU 2 (
        choice /C y /T 2 /D y /N /M "> Cancelled by user"
        goto:log
    )

    REM : search in logFile, getting only the last occurence
    set "installPath=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "install folder path" 2^>NUL') do (

        set "installPath="%%i""
        set "GLCache="!installPath:"=!\shaderCache\driver""
        if exist !GLCache! echo ^> Clearing !GLCache! && rmdir /S /Q  !GLCache! > NUL 2>&1
        set "pcCache="!installPath:"=!\shaderCache\precompiled""
        echo ^> Clearing !pcCache!
        for /F "delims=~" %%i in ('dir /B /S !pcCache! 2^>NUL') do del /F "%%i" > NUL 2>&1
    )

    :log
    set "msg="!DATE! Shader Caches deleted by !USERNAME!""
    call:log2HostFile !msg!

    timeout /T 3 > NUL 2>&1

    endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

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
