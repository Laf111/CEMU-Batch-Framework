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

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    REM : timeout value in seconds
    set /A "timeOut=130"

    REM : duration value in seconds
    set /A "duration=0"

    REM : monitor LaunchGame.bat until cemu.exe is launched 
        
    :waitingLoopProcesses
    timeout /T 1 > NUL
    for /F "delims=" %%i in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "LaunchGame" ^| find /I /V "find"') do (

        REM : set BatchFw processes to priority to high
        wmic process where "Name like '%%cmd.exe%%' and CommandLine like '%%_BatchFW_Install%%'" call setpriority 128 > NUL
    
        REM : if wizrad is running, don't count
        wmic process where "Name like '%%cmd.exe%%' and CommandLine like '%%wizardFirstSaving.bat%%'" goto:waitingLoopProcesses
    
        REM : monitor Cemu.exe launch and exit 
        for /F "delims=" %%j in ('tasklist /FI "STATUS eq RUNNING" ^| find /I "cemu.exe"') do exit 0
        set /A "duration+=1" 
        if !duration! GTR !timeOut! (
            REM : warn user with a retry/cancel msgBox
            cscript /nologo !MessageBox! "Hum... BatchFw is taken too much time. Killing it ? (Cancel) or wait a little longer (Retry) ? (you might, if batchFw is building graphic packs, mostly if V2 ones are needed)" 4117
            if !ERRORLEVEL! EQU 4 set /A "duration-=10" && goto:waitingLoopProcesses

            wmic process where "Name like '%%cmd.exe%%' and CommandLine like '%%launchGame.bat%%'" call terminate
            exit 1
        )
        goto:waitingLoopProcesses
    )

exit 0