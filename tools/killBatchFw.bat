@echo off
setlocal EnableExtensions
title Kill all BatchFw^'s process
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : with no arguments to this script, activating user inputs
    set "ignore="

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% NEQ 0 (
        set "avoid=| find /V "
        set /A "na=nbArgs-1"
        for /L %%i in (0,1,!na!) do (
            set "item=!args[%%i]!"
            set "item=!item:"=!"
            set "ignore=!ignore! !avoid!!item!"
        )
    )
    
    REM : basename of GAME FOLDER PATH
    for /F "delims=~" %%i in (!GAMES_FOLDER!) do set "GAMES_FOLDER_NAME=%%~nxi"

    echo ---------------------------------------------------------
    echo killing BatchFw^'s process^.^.^.

    for /F "delims=~" %%p in ('wmic path Win32_Process where ^"CommandLine like ^'%%!GAMES_FOLDER_NAME!%%^'^" get ProcessID^,commandline') do (
        set "line=%%p"
        set "line2=!line:""="!"
        set "pid=NOT_FOUND"
        echo !line2! | find /V "wmic" | find /V "ProcessID" | find /V "killBatchFw" !ignore! > NUL 2>&1 && for %%d in (!line2!) do set "pid=%%d"
        if not ["!pid!"] == ["NOT_FOUND"] taskkill /F /pid !pid! /T > NUL 2>&1
    )

    echo ---------------------------------------------------------
    echo killing CEMU^.^.^.

    REM : kill CEMU's running process
    wmic process where "Name like '%%cemu.exe%%'" call terminate > NUL 2>&1

    taskkill /F /IM "Cemu.exe" /T > NUL 2>&1
    
    REM : stoping user's software
    type !logFile! | find /I "TO_BE_LAUNCHED" > NUL 2>&1 && (

        echo ---------------------------------------------------------
        echo killing 3rd party Software^.^.^.
        echo ---------------------------------------------------------

        set "stopThirdPartySoftware="!BFW_TOOLS_PATH:"=!\stopThirdPartySoftware.bat""
        wscript /nologo !StartHiddenWait! !stopThirdPartySoftware!
    )

    REM : a second time to kill processes that might have been missed
    for /F "delims=~" %%p in ('wmic path Win32_Process where ^"CommandLine like ^'%%!GAMES_FOLDER_NAME!%%^'^" get ProcessID^,commandline 2^>NUL') do (
        set "line=%%p"
        set "line2=!line:""="!"
        set "pid=NOT_FOUND"
        echo !line2! | find /V "wmic" | find /V "ProcessID" | find /V "killBatchFw" !ignore! > NUL 2>&1 && for %%d in (!line2!) do set "pid=%%d"
        if not ["!pid!"] == ["NOT_FOUND"] taskkill /F /pid !pid! /T > NUL 2>&1
    )
    timeout /T 3 > NUL 2>&1
exit 0