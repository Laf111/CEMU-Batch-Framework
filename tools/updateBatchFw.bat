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
        exit 100
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""


    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS_PATH:"=!\Host_!USERDOMAIN!.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

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

    if %nbArgs% EQU 1 (
        set "BFW_VERSION=!args[0]!"
        set "BFW_VERSION=!BFW_VERSION:"=!"
        set "BFW_VERSION=!BFW_VERSION: =!"
        goto:begin
    )

    REM : get the current version from the log file
    set "BFW_VERSION=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "BFW_VERSION" 2^>NUL') do set "BFW_VERSION=%%i"
    set "BFW_VERSION=!BFW_VERSION: =!"
    
    :begin
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims==" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    REM : if a network connection was not found, exit 10
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        @echo No active connection was found, cancel updating
        exit /b 10
    )

    REM : powerShell script in _BatchFW_Graphic_Packs
    set "pwsGetVersion="!BFW_PATH:"=!\resources\ps1\getLatestBFW.ps1""

    set "bfwVR=NONE"
    for /F "usebackq delims=" %%i in (`Powershell.exe -executionpolicy remotesigned -File !pwsGetVersion!`) do set "bfwVR=%%i"
    if !ERRORLEVEL! EQU 1 (
        @echo Failed to get the last BatchFw version available
        exit /b 11
    )
    if ["!bfwVR!"] == ["NONE"] (
        @echo Failed to get the last BatchFw version available
        exit /b 12
    )
    set "bfwVR=!bfwVR: =!"

    if ["!BFW_VERSION!"] == ["!bfwVR!"] (
        @echo No new BatchFw update^(s^) available^, last version is still !bfwVR!
        exit /b 13
    )

    @echo New version available, do you want to update BatchFW to !bfwVR!^?
    call:getUserInput "Enter your choice ? : (n by default in 12sec)" "n,y" ANSWER 12
    if [!ANSWER!] == ["n"] (
        @echo Cancelled by user
        timeout /T 4 > NUL
        exit /b 14
    )

    REM : launch graphic pack update
    @echo =========================================================
    @echo Updating BatchFW to !bfwVR!^.^.^.
    @echo ---------------------------------------------------------

    REM : copy powerShell script in _BatchFW_Graphic_Packs
    set "pws_src="!BFW_RESOURCES_PATH:"=!\ps1\updateBFW.ps1""

    set "pws_target="!GAMES_FOLDER:"=!\updateBFW.ps1""

    copy /Y !pws_src! !pws_target! > NUL
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo Error when copying !pws_src!
        exit /b 6
    )

    pushd !GAMES_FOLDER!

    REM : launching powerShell script to downaload and extract GFX archive
    Powershell -executionpolicy remotesigned -File updateBFW.ps1 *> updateBFW.log
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo ERROR While getting and extracting batchFw !bfwVR! ^!
        if exist !pws_target! del /F !pws_target! > NUL
        if exist updateBFW.log del /F updateBFW.log > NUL
        exit /b 7
    )


    if not ["!BFW_VERSION!"] == ["NONE"] call:cleanHostLogFile BFW_VERSION
    echo BFW_VERSION=!bfwVR! >> !logFile!

    if exist !pws_target! del /F !pws_target! > NUL
    if exist updateBFW.log del /F updateBFW.log > NUL
    exit /b 0
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

    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

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
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
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
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL
        call:log2HostFile "charCodeSet=%CHARSET%"

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
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
