@echo off
setlocal EnableExtensions
title Stop BatchFw third party software
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
rem    color 4F
    color F0

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set /A "nbIs=0"
    for /F "tokens=* delims=~" %%i in ('type !logFile! ^| find /I "TO_BE_LAUNCHED" 2^>NUL') do (
        echo line read ^: %%i
        call:closeSoftware "%%i"
    )

    exit !ERRORLEVEL!

    goto:eof
    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions


    :closeSoftware

        set "line="%~1""

        for /F "tokens=3 delims=~@" %%j in (!line!) do set "whatTodo=%%j"

        echo Close = !whatTodo!
        if ["!whatTodo!"] == ["N"] goto:eof

        for /F "tokens=2 delims=~@" %%j in (!line!) do set "command="%%j""


        set "program="NONE""
        set "firstArg="NONE""

        REM : resolve venv for search
        for /F "tokens=1 delims=~'" %%j in (!command!) do set "program="%%j""
        for /F "tokens=3 delims=~'" %%j in (!command!) do set "firstArg="%%j""

        echo program = !program!
        echo firstArg = !firstArg!

        if not [!program!] == ["NONE"]  if not exist !program! (
                call:cleanHostLogFile !program!
                !MessageBox! "WARNING software to launch before CEMU !program! does not exist anymore in host log file^, deleting this entry^!" 4144
                set /A "nbIs=99"
        )
        if !nbIs! NEQ 99 (
            REM : count number of running instances
            if [!firstArg!] == ["NONE"] for /F "delims==" %%n in ('wmic process get Commandline 2^>NUL ^| find /I !program! ^| find /I /V "find" /C') do set /A "nbIs=%%n"
            if not [!firstArg!] == ["NONE"] for /F "delims==" %%n in ('wmic process get Commandline 2^>NUL ^| find /I !program! ^| find /I !firstArg! ^| find /I /V "find" /C') do set /A "nbIs=%%n"

            echo nbIs=!nbIs!

            REM : basename of GAME FOLDER PATH (used to name shorcut)
            for /F "delims=~" %%i in (!program!) do set "exe=%%~nxi"
            for /F "delims=~" %%i in (!firstArg!) do set "argPiece=%%~nxi"

            REM : stop the program if it is not already running
            if !nbIs! NEQ 0 if [!firstArg!] == ["NONE"] wmic process where "Name like '!exe!'" call terminate 2>NUL && exit 0
            if !nbIs! NEQ 0 if not [!firstArg!] == ["NONE"] wmic process where "Name like '!exe!' and CommandLine like '%%!argPiece!%%'" call terminate  2>NUL && exit 0

        )

    goto:eof
    REM : ------------------------------------------------------------------
