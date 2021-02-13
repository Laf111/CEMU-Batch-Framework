@echo off
color f0
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
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    call:setCharSet

    REM : check if java is installed
    java -version > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: java is not installed^, exiting
        tiemout /T 10 > NUL 2>&1
        exit /b 50
    )

    REM : number of downloading attempts
    set dlLoopCount=15

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% LSS 3 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" JNUSTFolder titleId decryptMode titleKey^*
        echo given {%*}
        exit /b 99
    )
    if %nbArgs% GTR 4 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" JNUSTFolder titleId decryptMode titleKey^*
        echo given {%*}
        exit /b 99
    )

    REM : get args
    set "JNUSTFolder=!args[0]!"
    set "jarFile="!JNUSTFolder:"=!\JNUSTool.jar""

    if not exist !jarFile! (
        echo ERROR^: JNUSTool^.jar was not found^, exiting
        tiemout /T 10 > NUL 2>&1
        exit /b 51
    )
    pushd !JNUSTFolder!

    set "titleId=!args[1]!"
    set "titleId=!titleId:"=!"

    set "arg2=!args[2]!"
    set /A "decryptMode=!arg2:"=!"

    set "titleKey="
    if %nbArgs% EQU 4 (
        set "titleKey=!args[3]!"
        set "titleKey=!titleKey:"=!"
    )
    cls
    echo ===============================================================
    if !decryptMode! EQU 1 (
        title Downloading RPX version of !titleId!
        echo Downloading RPX version of !titleId!
    ) else (
        title Downloading WUP version of !titleId!
        echo Downloading WUP version of !titleId!
    )
    echo ===============================================================

    set "jnArgs=-dlEncrypted"

    if !decryptMode! EQU 1 (
        if ["!titleKey!"] == [""] (
            REM : get titleKeys
            for /F "delims=~	 tokens=1-4" %%a in ('type titleKeys.txt ^| find /I "!titleId!" 2^>NUL') do (
                set "titleKey=%%b"
            )
            if ["!titleKey!"] == [""] (
                echo ERROR^: Sorry^, can^t find a title Key for !titleId!
                goto:eof
            )
        )
        set "jnArgs=!titleKey! -file /.*"
    )

    for /l %%x in (1, 1, %dlLoopCount%) do (
        Title Downloading !titleId! - pass = %%x/%dlLoopCount%
        java -jar JNUSTool.jar !titleId! !jnArgs!
    )

    exit /b 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions


    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

