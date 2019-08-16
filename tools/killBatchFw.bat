@echo off
setlocal EnableExtensions
title KIll BatchFw processes
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    
    title Kill all BatchFw^'s process
    @echo ---------------------------------------------------------
    @echo killing BatchFw^'s process^.^.^.
    @echo ---------------------------------------------------------
    
    REM : kill choice process that could be openned in wizardFirstLaunch
    wmic process where "Name like '%%choice.exe%%' and CommandLine like '%%game profile%%'" call terminate
    REM : kill cscript process that could be openned
    wmic process where "Name like '%%cscript.exe%%' and CommandLine like '%%_BatchFW_Install%%'" call terminate
    REM : kill wscript process that could be openned
    wmic process where "Name like '%%wscript.exe%%' and CommandLine like '%%_BatchFW_Install%%'" call terminate

    REM : kill CEMU's running process
    wmic process where "Name like '%%cemu.exe%%'" call terminate
    
    REM : kill BatchFw's running process
    wmic process where "Name like '%%cmd.exe%%' and CommandLine like '%%_BatchFW_Install%%'" call terminate
    timeout /T 4 > NUL

exit 0