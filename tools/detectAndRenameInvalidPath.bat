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
        exit /b 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"
    for %%a in (!BFW_TOOLS_PATH!) do set "basename="%%~dpa""
    set "BFW_PATH=!basename:~0,-2!""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : initialize return code to 0 (no problemn encountered)
    set cr=0
    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]=%1"
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% GTR 1 (
        echo ERROR ^: 1 arguments are required
        echo SYNTAXE ^: !THIS_SCRIPT! FOLDER_PATH
        echo given {%*}
        goto:eof
    )

    REM : get and check FOLDER_PATH
    set "FOLDER_PATH=!args[0]!"
    if ["!FOLDER_PATH!"] == [""] (
        echo FOLDER_PATH empty ^?^, exit 6
        exit /b 6
    )

    if not exist !FOLDER_PATH! (
        echo This folder !FOLDER_PATH! does not exist.^^!
        exit /b 2
    )

    dir !FOLDER_PATH! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo This folder !FOLDER_PATH! is not compatible with DOS^. Remove ^^! from this path.
        exit /b 3
    )

    for %%a in (!FOLDER_PATH!) do set "drive=%%~da"

    set "_path=!FOLDER_PATH!"
    call:checkPath !_path!

    for %%a in (!_path!) do set "basename=%%~dpa"

    :cdDotDot
    set "_path="!basename:~0,-1!""

    if [!_path!] == ["!drive!"] goto:pathSecured
    call:checkPath !_path!
    for %%a in (!_path!) do set "basename=%%~dpa"

    if ["!basename:~0,-1!"] == ["%drive%"] goto:pathSecured
    goto:cdDotDot

    :pathSecured
    exit /b %cr%
    goto:eof


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

    :checkPath

        set FOLDER_PATH="%~1"

        for %%a in (!FOLDER_PATH!) do set "folderName=%%~nxa"
        for %%a in (!FOLDER_PATH!) do set "basename=%%~dpa"

        REM : analysing a root path, nothing to be done exit
        if ["!folderName!"] == [""] goto:eof

        REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!%() are also a problem with dos expansion
        set "str="!folderName!""
        set "str=!str:&=!"
        set "str=!str:\!=!"
        echo !str! | find /I /V "(UPDATE DATA)" > NUL 2>&1 && goto:next
        echo !str! | find /I /V "(DLC)" > NUL 2>&1 && goto:next
        
        set "str=!str:)=!"
        set "str=!str:(=!"
        
        :next
        set "str=!str:%%=!"
        
        REM : WUP restrictions
        set "str=!str:™=!"
        set "str=!str:®=!"
        set "str=!str:©=!"
        set "str=!str:É=E!"
        
        set "newFolderName=!str:"=!"
        set "newName="!basename!!newFolderName:"=!""

        if [!newName!] == [!FOLDER_PATH!] goto:eof

        echo !folderName! ^: Unsupported characters found ^!
        call:getUserInput "Renaming folder for you ? (y, n) : " "y,n" ANSWER
        if [!ANSWER!] == ["n"] (

            set cr=3
            goto:eof
        )

        pushd !basename!
        :tryToMove
        move /Y !FOLDER_PATH! !newName!
        if %ERRORLEVEL% NEQ 0 (
            !MessageBox! "Fail to move !GAME_FOLDER_PATH:"=!^, close any program that could use this location and check that you have the ownership on !FOLDER_PATH:"=!^. Do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMove

            echo Failed to rename !FOLDER_PATH! to !newName!^, please do it by yourself ^!

            set cr=4
            goto:eof
        )

        REM : return code for renaming action
        set cr=1

    goto:eof



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
        call !choiceCmd!
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

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------
