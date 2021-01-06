@echo off
color 08
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
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""

    set "killPid="!BFW_TOOLS_PATH:"=!\killPid.bat""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% NEQ 4 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" p1 p2 phase step
        echo given {%*}
        pause
        exit 99
    )

    set "p1=!args[0]!"
    set /A "p1=!p1:"=!"
    REM : check args range
    if %p1% GTR 100 (
        pause
        exit 1
    )
    if %p1% LSS 0 (
        pause
        exit 11
    )

    set "p2=!args[1]!"
    set /A "p2=!p2:"=!"
    if !p2! GTR 100 (
        pause
        exit 2
    )
    if !p2! LSS 0 (
        pause
        exit 12
    )

    REM : get the step
    set "phase=!args[2]!"
    set "phase=!phase:"=!"

    REM : get the phase
    set "step=!args[3]!"
    set "step=!step:"=!"

    REM : get screen resolution from log
    for /F "tokens=2,3 delims=~=x" %%i in ('type !logFile! ^| find /I "RESOLUTION" 2^>NUL') do set /A "WIDTH=%%i" & set /A "HEIGHT=%%j"

    REM : fix progressBar width to 60 (not pixels!)
    set /A "l=74"
    REM : compute width in pixels (8=Font width)
    set /A "pw=!l!*8"

    set /A "w=(%WIDTH%-!pw!)/2"
    set /A "w=!w!-8"
    set /A "h=(%HEIGHT%/3)"

    set /A "lm2=!l!-2"

    set /A "lp1=!p1!*!lm2!/100"
    set /A "dlp1=!p1!*!lm2!/10"
    set /A "dlp2=!p2!*!lm2!/10"

    REM : fill upb and dpb (upper and lower border bars)
    REM : fill valuecore to %lp1%
    set "valuecore="
    set "upb=É"
    set "dpb=È"
    for /L %%i in (1,1,!lm2!) do (
        if %%i LEQ !lp1! set "valuecore=!valuecore!Û"
        set "upb=!upb!Ä"
        set "dpb=!dpb!Ä"
    )
    set "upb=!upb!»"
    set "dpb=!dpb!¼"

    REM : add a step more to never progress back
    if !p2! NEQ 100 set "valuecore=!valuecore!Û"

    mode %l%,3 > NUL 2>&1
    !cmdOw! @ /mov !w! !h! > NUL 2>&1

    REM : first draw
    call:refreshProgressBar

    REM : show the window
    title BatchFw !phase! !p1!%% ^: !step!
    !cmdOw! @ /res > NUL 2>&1

    pushd !BFW_RESOURCES_PATH!
    set /A "first=!dlp1!+10"
    set /A "last=!dlp2!-10"

rem    set "logFileTmp="!BFW_PATH:"=!\Logs\BatchFw_process_!step!.list""
    set "logFileTmp="!TMP:"=!\BatchFw_process_!step!.list""
    !cmdOw! @ /top > NUL 2>&1

    for /L %%i in (!first!,10,!last!) do (

        set /A "p=%%i*10/!lm2!"

        if !p! GEQ !p1! if !p! LEQ !p2! title BatchFw !phase! !p!%% ^: !step!^.^.^.
        call:strLength !valuecore! length
        if !length! LEQ !lm2! set "valuecore=!valuecore!Û"
        call:refreshProgressBar

        if !p2! NEQ 100 (
            cmdOw.exe /T | find "cmd" | find "BatchFw" | find "%%" > !logFileTmp!

            REM : token=12 because of 2 word for phase "pre/post processing"
            for /F "tokens=12" %%j in ('type !logFileTmp!') do (

                set "pr=%%j"
                set /A "pr=!pr:%%=!"

                if !pr! GTR !p! del /F !logFileTmp! > NUL 2>&1 & exit 0
            )
        ) else (
            for /L %%j in (1,1,100) do set "counting=%%j"
        )
        for /L %%j in (1,1,1000) do set "counting=%%j"
    )
    title BatchFw !phase! !p2!%% ^: !step!^.^.^.

    if !p2! NEQ 100 goto:waitNextWindow

    :complete
    call:strLength !valuecore! length
    if !length! LSS !lm2! set "valuecore=!valuecore!Û"
    call:refreshProgressBar
    for /L %%j in (1,1,100) do set "counting=%%j"
    if !length! LSS !lm2! goto:complete
    
    REM : p2=100% close all instances, then exit

    :killingLoop
    REM : use () after do (wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe" /C taskkill /F /pid %%i > NUL 2>&1 & goto:killingLoop does nothing)
    cmdOw.exe /T | find "cmd" | find "BatchFw" | find "%%" | find /V "100" > !logFileTmp!
    for /F "tokens=3" %%i in ('type !logFileTmp!') do (
        taskkill /F /pid %%i > NUL 2>&1
        goto:killingLoop
    )
    del /F !logFileTmp! > NUL 2>&1
    exit 0

    :waitNextWindow

    :loop
    cmdOw.exe /T | find "cmd" | find "BatchFw" | find "%%" > !logFileTmp!
    for /F "tokens=12" %%j in ('type !logFileTmp!') do (
        set "pr=%%j"
        set /A "pr=!pr:%%=!"
        if !pr! GTR !p2! del /F !logFileTmp! > NUL 2>&1 & exit 0
    )
    goto:loop

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
    echo|set /p="!dpb!"
goto:eof

:closePrevious
    set "psCommand="Get-WmiObject win32_process -Filter """name like 'cmd.exe'""" ^| select processId, commandline ^| Sort-Object commandline ^| Out-String -Width 300""
    for /F "delims=~" %%i in ('powershell %psCommand% ^| find "progressBar" 2^>NUL') do (
        echo %%i ^| find "%step%" > NUL 2>&1 && goto:eof
        set "line=%%i"
        set "line=%line:"=%
        for /F "tokens=1" %%j in (%line%") do taskkill /F /pid %%j > NUL 2>&1
    )
goto:eof

