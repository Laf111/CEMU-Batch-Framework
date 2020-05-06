@echo off
setlocal EnableExtensions
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

    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""

    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"
        
    set "myLog="!BFW_PATH:"=!\logs\ftpSyncFolders.log""

    REM : set current char codeset
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

    if %nbArgs% GTR 5 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" WII-U_IP SYNC_TYPE LOCAL_FOLDER REMOTE_FOLDER SITENAME
        echo given {%*}
        pause
        exit /b 9
    )
    if %nbArgs% LSS 4 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" WII-U_IP SYNC_TYPE LOCAL_FOLDER REMOTE_FOLDER SITENAME
        echo given {%*}
        pause
        exit /b 9
    )

    REM : get and check wiiuIp
    set "wiiuIp=!args[0]!"
    ping -n 1 !wiiuIp! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: !wiiuIp! was not found on your network ^!
        pause
        exit /b 1
    )
    set "wiiuIp=!wiiuIp:"=!"

    set "SYNC_TYPE=!args[1]!"
    if not [!SYNC_TYPE!] == ["local"] if not [!SYNC_TYPE!] == ["remote"] (
        echo ERROR ^: !SYNC_TYPE! not equal to ^'local^' neither ^'remote^'"
        pause
        exit /b 2
    )
    set "SYNC_TYPE=!SYNC_TYPE:"=!"
    set "LOCAL_FOLDER=!args[2]!"
    set "REMOTE_FOLDER=!args[3]!"

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if %nbArgs% EQU 5 (
        set "SITENAME=!args[4]!"
        set "SITENAME=!SITENAME:"=!"

        echo FTP transfert !USERDOMAIN! ^<-^> !wiiuIp!
        echo !SITENAME!
        set "myLog="!BFW_PATH:"=!\logs\ftpSyncFolders_!SITENAME!.log""
    ) else (
        echo FTP transfert !USERDOMAIN! ^<-^> !wiiuIp! ^:
    )
    echo ----------------------------------------------------------

    REM : create localFolder if needed
    set /A "nbRetry=0"

    if ["!SYNC_TYPE!"] == ["local"] (
        if not exist !LOCAL_FOLDER! mkdir !LOCAL_FOLDER! > NUL 2>&1
    ) else (
        set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheckBeforeSync_!DATE!.log""

        !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "mkdir "!REMOTE_FOLDER!"" "option batch off" "exit" > !ftplogFile!
        !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls "!REMOTE_FOLDER!"" "option batch off" "exit" > !ftplogFile!
        type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
            echo ERROR ^: unable to create !REMOTE_FOLDER!
            pause
            exit /b 50
        )
    )
    del /F !ftplogFile! > NUL 2>&1
    echo.
    echo ^> Sync !SYNC_TYPE! !LOCAL_FOLDER! !REMOTE_FOLDER!

    REM : run ftp transferts :
    !winScp! /log=!myLog! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "option batch continue" "synchronize !SYNC_TYPE! "!LOCAL_FOLDER!" "!REMOTE_FOLDER!"" "option batch off" "exit"
    set "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 echo ERROR detected when transferring ^!
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if !cr! NEQ 0 exit /b !cr!
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
