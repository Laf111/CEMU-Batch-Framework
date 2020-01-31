@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color F0

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

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

    if %nbArgs% NEQ 2 (
        echo ERROR on arguments passed^(%nbArgs%^)
        echo SYNTAXE^: "!THIS_SCRIPT!" GAME_FOLDER_PATH titleId
        echo given {%*}
        pause
        exit 9
    )

    REM : get and check GAME_FOLDER_PATH
    set "GAME_FOLDER_PATH=!args[0]!"

    REM : get titleId
    set "titleId=!args[1]!"
    set "titleId=%titleId:"=%"

    echo =========================================================
    echo Check !GAME_FOLDER_PATH! [!titleId!] dump
    echo =========================================================

    set "GAME_FOLDER=%GAME_FOLDER_PATH:"=%"
    set "endIdUp=%titleId:~8,8%"
    call:lowerCase %endIdUp% endIdLow

    REM : check if zero sized file exist in game's folder
    set /A "valid=1"

    REM : check DLC folder
    set "ldf=mlc01\usr\title\0005000c\!endIdLow!"
    set "dlcFolder="%GAME_FOLDER%\!ldf!""
    call:checkFolder !dlcFolder! !ldf!

    REM : ARGS
    set "luf=mlc01\usr\title\0005000e\!endIdLow!"
    set "updateFolder="%GAME_FOLDER%\!luf!""
    call:checkFolder !updateFolder! !luf!

    echo =========================================================

    if !valid! NEQ 1 (
        echo Some zero sized files don'^t exist in game^'s folder
        echo Dump is invalid
        exit 1
    )
    echo All zero sized files exist in game^'s folder
    echo Dump is valid
    exit 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

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

    :checkFolder
        set "folder="%~1""
        set "relativePath=%~2"

        for /F "delims=~" %%i in ('dir /S /B /A:-D !folder! 2^>NUL') do (

            set "file="%%i""
            set "size=%%~zi"

            if !size! EQU 0 (
                set "gameFile=!file:%relativePath%=!"
                set "rp=!file:%GAME_FOLDER%\mlc01\usr\title\=!"
                if not exist !gameFile! (
                    echo ^!!rp:"=! not found in game^'folder
                    set /A "valid=0"
                ) else (
                    echo ^>!rp:"=!
                    REM : delete the file
                    rm -rf !file!
                )
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------


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


