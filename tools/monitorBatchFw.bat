@echo off
setlocal EnableExtensions
title Monitor BatchFw Launch
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

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAMES_FOLDER!) do set "GAMES_FOLDER_NAME=%%~nxi"

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "killBatchFw="!BFW_TOOLS_PATH:"=!\killBatchFw.bat""

    REM : timeout value in seconds
    set /A "timeOut=180"

    REM : duration value in seconds
    set /A "duration=0"

    REM : monitor LaunchGame.bat until cemu is launched
    set "logFileTmp="!BFW_PATH:"=!\Logs\monitor_process.list""

    :waitingLoopProcesses
    timeout /T 1 > NUL 2>&1
    wmic process get Commandline | find ".exe" | find /I /V "wmic" | find /I /V "find" > !logFileTmp!
    type !logFileTmp! | find  /I "LaunchGame" > NUL 2>&1 && (

        REM : set BatchFw processes to priority to high
        wmic process where "CommandLine like '%%!GAMES_FOLDER_NAME!%%'" call setpriority 128 > NUL 2>&1

        REM : if wizard is running, don't count
        type !logFileTmp! | find /I "wizardFirstSaving.bat" > NUL 2>&1 && goto:waitingLoopProcesses

        REM : if rar is running, don't count
        type !logFileTmp! | find /I "rar.exe" | find /I "_BatchFw_Graphic_Packs" > NUL 2>&1 && goto:waitingLoopProcesses
        
        REM : monitor Cemu launch
        type !logFileTmp! | find /I "cemu.exe" > NUL 2>&1 && set /A "duration=-1"

        if !duration! GEQ 0 set /A "duration+=1"
        if !duration! GTR !timeOut! (
            REM : warn user with a retry/cancel msgBox
            cscript /nologo !MessageBox! "Hum... BatchFw is taken too much time. Killing it ? (Cancel) or wait a little longer (Retry) ? (you might, if batchFw is building graphic packs, mostly if V2 ones are needed)" 4117
            if !ERRORLEVEL! EQU 4 set /A "duration-=30" && goto:waitingLoopProcesses

            call !killBatchFw!
            exit 1
        )
        goto:waitingLoopProcesses
    )
    call !killBatchFw!
exit 0