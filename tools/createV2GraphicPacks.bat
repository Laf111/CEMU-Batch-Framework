@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"
    
    REM : directory of this script
    pushd "%~dp0" >NUL && set "BFW_TOOLS_PATH="!CD!"" && popd >NUL

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSetAndLocale

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]=%~1"
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""

    if %nbArgs% GTR 6 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" overwriteWidth overwriteHeight description gameName ratio*
        @echo given {%*}
        exit /b 99
    )
    if %nbArgs% LSS 5 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" overwriteWidth overwriteHeight description gameName ratio*
        @echo given {%*}
        exit /b 98
    )
    REM : get and check BFW_GP_FOLDER
    set "nativeHeight=!args[0]!"
    set "overwriteWidth=!args[1]!"
    set "overwriteHeight=!args[2]!"
    set "description=!args[3]!"
    set "gameName=!args[4]!"
    if %nbArgs% EQU 6 set "ratio=!args[5]!"

    set "bfwgpv2="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
    if not exist !bfwgpv2! exit 10
    
    set "gp="!bfwgpv2:"=!\_BatchFW %description%""
    if exist !gp! (
        @echo ^^! _BatchFW %description% already exist, skipped ^^!
        exit 1
    )
    if not exist !gp! mkdir !gp! > NUL

    set "rulesFileV2="!gp:"=!\rules.txt""

    @echo [Definition] > !rulesFileV2!
    @echo titleIds = !titleIdList! >> !rulesFileV2!

    @echo name = "BatchFW %overwriteWidth%x%overwriteHeight% %ratio%" >> !rulesFileV2!
    @echo version = 2 >> !rulesFileV2!
    @echo # >> !rulesFileV2!

    
    REM : res ratios instructions ------------------------------------------------------
    set /A "resRatioV2=1"
    
    :beginLoopResV2
    
    set /A "resultV2=0"
    call:divfloat %nativeHeight% !resRatioV2! 1 resultV2

    REM : check if targetHeight is an integer
    for /F "tokens=1-2 delims=." %%a in ("!resultV2!") do if not ["%%b"] == ["0"] set /A "resRatioV2+=1" && goto:beginLoopResV2
    set "targetHeightV2=!resultV2:.0=!"

    
    REM compute targetWidth (16/9 = 1.7777777)
    call:mulfloat "!targetHeightV2!.000" "1.777" 3 targetWidthV2
   

    call:divfloat2int "%overwriteWidth%.0" "!resRatioV2!.0" 1 widthV2
    call:divfloat2int "%overwriteHeight%.0" "!resRatioV2!.0" 1 heightV2
    

    REM 1^/%resRatioV2% res : %targetWidth%x%targetHeight%
    call:writeV2Filters >> !rulesFileV2!
   
    
    if !heightV2! LEQ 8 goto:formatrV2Utf8
    if !resRatioV2! GEQ 9 goto:formatrV2Utf8         
    set /A "resRatioV2+=1"
    goto:beginLoopResV2

    :formatrV2Utf8
    REM : force UTF8 format
    set "utf8v2="!gp:"=!\rules.tmp""
    copy /Y !rulesFileV2! !utf8v2! > NUL
    type !utf8v2! > !rulesFileV2!
    del /F !utf8v2! > NUL
  
    if %ERRORLEVEL% NEQ 0 exit %ERRORLEVEL%
    exit 0
    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions
    
    :writeV2Filters
        
        @echo # 1/!resRatioV2! Res
        @echo [TextureRedefine]
        @echo width = !targetWidthV2!
        @echo height = !targetHeightV2!
        @echo tileModesExcluded = 0x001 # For Video Playback
        @echo formatsExcluded = 0x431
        @echo overwriteWidth = !widthV2!                
        @echo overwriteHeight = !heightV2!
        @echo #
        @echo #
        
    goto:eof    
    
    REM : function for multiplying integers
    :mulfloat

        REM : get a
        set "numA=%~1"
        REM : get b
        set "numB=%~2"
        REM : get nbDecimals
        set /A "decimals=%~3"

        set /A "one=1"
        set /A "decimalsP1=decimals+1"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        if not ["!numA:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numA% does not have %decimals% decimals
            pause
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals
            pause
            exit /b 2
        )

        set "fpA=%numA:.=%"
        set "fpB=%numB:.=%"

        REM : a * b
        if %fpB% GEQ %fpA% set /A "mul=fpA*fpB/one"
        if %fpA% GEQ %fpB% set /A "mul=fpB*fpA/one"

        set /A "result=!mul:~0,-%decimals%!"
        REM : floor
        set /A "result=%result%+1"

        REM : output
        set "%4=%result%"

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    :strLen
        set /A "len=0"
        :strLen_Loop
           if not ["!%1:~%len%!"] == [""] set /A len+=1 & goto:strLen_Loop
            set %2=%len%
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function for dividing integers
    :divfloat
    
        REM : get a
        set "numA=%~1"
        REM : get b
        set "numB=%~2"
        
        set "fpA=%numA:.=%"
        set "fpB=%numB:.=%"
        
        REM : get nbDecimals
        set /A "decimals=%~3"
        set /A "scale=%decimals%"
        
        set /A "one=1"
        if %decimals% EQU 1 (
            set /A "one=10"
            goto:treatment
        )
        call:strLen fpA strLenA
        call:strLen fpB strLenB
      
        set /A "nlA=!strLenA!"
        set /A "nlB=!strLenB!" 
        
        set /A "max=%nlA%"
        if %nlB% GTR %nlA% set /A "max=%nlB%"
        set /A "decimals=9-%max%"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        :treatment
        REM : a / b
        set /A div=fpA*one/fpB

        set "intPart="!div:~0,-%decimals%!""
        if [%intPart%] == [""] set "intPart=0"
        set "intPart=%intPart:"=%"
        
        set "decPart=!div:~-%decimals%!"      
        
        set "result=%intPart%.%decPart%"
   
        if %scale% EQU 0 set /A "result=%intPart%"

        REM : output
        set "%4=%result%"

    goto:eof
    REM : ------------------------------------------------------------------

    
    REM : function for dividing integers returning an int
    :divfloat2int

        REM : get a
        set "numA=%~1"
        REM : get b
        set "numB=%~2"
        REM : get nbDecimals
        set /A "decimals=%~3"

        set /A "one=1"
        set /A "decimalsP1=decimals+1"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        if not ["!numA:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numA% does not have %decimals% decimals
            pause
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals
            pause
            exit /b 2
        )

        set "fpA=%numA:.=%"
        set "fpB=%numB:.=%"

        REM : a / b
        set /A div=fpA*one/fpB

        set /A "result=!div:~0,-%decimals%!"

        REM : output
        set "%4=%result%"

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get char set code for current host
    :setCharSetAndLocale

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL
        call:log2HostFile "charCodeSet=%CHARSET%"

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic path Win32_OperatingSystem get Locale /value ^| find "="') do set "L0CALE_CODE=%%f"

        REM : set YES/NO according to locale (used to protect cmd windows when closing then with mouse)
        REM : default = ENG
        set "yes=y"
        set "no=n"

        if ["%L0CALE_CODE%"] == ["0407"] (
            REM : locale = GER
            set "yes=j"
            set "no=n"
        )
        if ["%L0CALE_CODE%"] == ["0C0a"] (
            REM : locale = SPA
            set "yes=s"
            set "no=n"
        )
        if ["%L0CALE_CODE%"] == ["040c"] (
            REM : locale = FRA
            set "yes=o"
            set "no=n"
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------


