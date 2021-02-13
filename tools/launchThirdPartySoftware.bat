@echo off
setlocal EnableExtensions
title BatchFw third party software launcher
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set /A "nbIs=0"
    for /F "tokens=2 delims=~@" %%i in ('type !logFile! ^| find /I "TO_BE_LAUNCHED" 2^>NUL') do (

        set "command=%%i"
        for /F "tokens=* delims=~" %%j in ("!command!") do call:resolveVenv "%%j" command
        echo command=!command!

        set "program="NONE""
        set "firstArg="NONE""

        REM : resolve venv for search
        for /F "tokens=1 delims=~'" %%j in ("!command!") do set "program="%%j""
        for /F "tokens=3 delims=~'" %%j in ("!command!") do set "firstArg="%%j""

        echo program=!program!
        echo firstArg=!firstArg!

        if not [!program!] == ["NONE"]  if not exist !program! (

                !MessageBox! "WARNING !program! does not exist anymore^, deleting this entry^!" 4144
                call:cleanHostLogFile !program:"='!
                set /A "nbIs=99"
            )
        if !nbIs! NEQ 99 (
            REM : count number of running instances
            if [!firstArg!] == ["NONE"] for /F "delims=~=" %%n in ('wmic process get Commandline 2^>NUL ^| find /I !program! ^| find /I /V "find" /C') do set /A "nbIs=%%n"
            if not [!firstArg!] == ["NONE"] for /F "delims=~=" %%n in ('wmic process get Commandline 2^>NUL ^| find /I !program! ^| find /I !firstArg! ^| find /I /V "find" /C') do set /A "nbIs=%%n"

            set cmd=!command:"=!

            REM : start the program if it is not already running
            if !nbIs! EQU 0 wscript /nologo !Start! !cmd:'="!
        )
    )
    exit !ERRORLEVEL!

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

    :resolveVenv
        set "value="%~1""
        set "resolved=%value:"=%"

        REM : check if value is a path
        echo %resolved% | find ":" > NUL && (
            REM : check if it is only a device letter issue (in case of portable library)
            set "tmpStr='!drive!%resolved:~3%"
            set "newLocation=!tmpStr:'="!"
            if exist !newLocation! set "resolved=!tmpStr!"
        )

        set "%2=!resolved!"
    goto:eof
    REM : ------------------------------------------------------------------



