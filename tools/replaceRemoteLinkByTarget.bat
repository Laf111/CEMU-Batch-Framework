@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color F0

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    pushd !BFW_PATH!

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""

    pushd !BFW_TOOLS_PATH!
    call:setCharSet

        REM : checking arguments
    set /A "nbArgs=0"
   :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
   :end

    if %nbArgs% NEQ 3 (
        echo ERROR on arguments passed^(%nbArgs%^)
        echo SYNTAXE^: "!THIS_SCRIPT!" WiiuIp targetPath linkPath
        echo given {%*}
        pause
        exit 9
    )

    REM : get wiiu IP
    set "wiiuIp=!args[0]!"
    set "wiiuIp=!wiiuIp:"=!"

    REM : get target
    set "targetPath=!args[1]!"
    REM : get link
    set "linkPath=!args[2]!"

    echo =========================================================
    echo cp !targetPath! !linkPath!
    echo =========================================================
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "cp !targetPath! !linkPath!" "exit"

    exit /b !ERRORLEVEL!

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


