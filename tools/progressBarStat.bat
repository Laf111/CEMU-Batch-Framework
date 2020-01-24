@echo off
color f
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"
    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM if %nbArgs% NEQ 2 (
        REM @echo ERROR ^: on arguments passed ^!
        REM @echo SYNTAXE ^: "!THIS_SCRIPT!" step p1
        REM @echo given {%*}
        REM pause
        REM exit 99
    REM )

    REM : get the step
    set "step=!args[2]!"
    set "step=!step:"=!"

    set "p=!args[1]!"
    set /A "p=!p:"=!"

    REM : check args range
    if %p% GTR 100 (
        pause
        exit 1
    )
    if %p% LSS 0 (
        pause
        exit 11
    )
    pushd !BFW_RESOURCES_PATH!

    for /f "tokens=2,10-11" %%a in ('cmdOw.exe /p') do (
      if "%%a"=="0" set "WIDTH=%%b" & set "HEIGHT=%%c"
    )

    set /A "w=%WIDTH%/3"
    set /A "h=%HEIGHT%/3"
    set /A "l=%WIDTH%/26"
    set /A "lm3=!l!-2"

    REM : l=100
    REM : lp1=p
    set /A "lp=%l%*%p%/100"

    mode %l%,4 > NUL 2>&1
    !cmdOw! @ /mov %w% %h% > NUL 2>&1
    title BatchFw !p!%% ^: !step!^.^.^.

    set "valuecore="
    set "upb=É"
    set "dpb=È"
    for /L %%i in (1,1,%lm3%) do (
        set /A "n=%%i"
        if %%i LEQ %lp% set "valuecore=!valuecore!Û"
        set "upb=!upb!Ä"
        set "dpb=!dpb!Ä"
    )
    set "upb=!upb!»"
    set "dpb=!dpb!¼"

    REM : write in progressbar
    call:refreshProgressBar

    REM : show the window
    !cmdOw! @ /res /top > NUL 2>&1

    REM : close other instances
    set "psCommand="Get-Process ^|where {$_.mainwindowtitle} ^| Sort-Object mainwindowtitle ^| format-table id,mainwindowtitle""
    for /F "tokens=1" %%i in ('powershell !psCommand! ^| find "BatchFw" ^| find /V "BatchFw !p!" 2^>NUL') do taskkill /F /pid %%i > NUL 2>&1

    if !p! NEQ 100 pause> NUL
    REM : close all instances
    set "psCommand="Get-Process ^|where {$_.mainwindowtitle} ^| Sort-Object mainwindowtitle ^| format-table id,mainwindowtitle""
    :killingLoop
    for /F "tokens=1" %%i in ('powershell %psCommand% ^| find "BatchFw" ^| find "%" ^| find /V "100%" 2^>NUL') do wscript !StartHiddenCmd! "%windir%\system32\cmd.exe" /C taskkill /F /pid %%i > NUL 2>&1 && goto:killingLoop

    exit 0
goto:eof


REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

:strLength
    Set "s=#%~1"
    Set "len=0"
    For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
      if "!s:~%%N,1!" neq "" (
        set /a "len+=%%N"
        set "s=!s:~%%N!"
      )
    )
    set /A "%2=%len%"
goto:eof

:refreshProgressBar
    cls
    echo.!upb!
    echo. !valuecore!
    echo.!dpb!
goto:eof

