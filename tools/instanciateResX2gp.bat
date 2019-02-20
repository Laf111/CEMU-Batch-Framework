@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    REM : directory of this script
    pushd "%~dp0" >NUL && set "BFW_TOOLS_PATH="!CD!"" && popd >NUL

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    REM : set current char codeset
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

    if %nbArgs% GTR 7 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" nativeWidth nativeHeight gp width height halfw halfh description
        @echo given {%*}
        exit /b 99
    )

    if %nbArgs% LSS 6 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!"  nativeWidth nativeHeight gp width height halfw halfh description
        @echo given {%*}
        exit /b 99
    )

    REM : nativeHeight
    set "nativeHeight=!args[0]:"=!"
    REM : nativeWidth
    set "nativeWidth=!args[1]:"=!"
    REM : gpResX2gp
    set "gpResX2gp=!args[2]!"
    REM : gp
    set "gp=!args[3]!"
    REM : width
    set "width=!args[4]:"=!"
    REM : height
    set "height=!args[5]:"=!"

    REM : description
    set "description="
    if %nbArgs% EQU 7 set "description=!args[6]:"=!"

    set /A "resX2=%nativeHeight%*2"

    REM : analyse gpResX2gp folder name
    REM : width for ResX2gp in 16/9
    set /A "wToReplace=%nativeWidth%*2"
    for /F "delims=" %%j in ('echo !gpResX2gp! ^| find "p219"') do call:mulfloat "%nativeHeight%.000" "2.333" 3 wToReplace
    for /F "delims=" %%j in ('echo !gpResX2gp! ^| find "p489"') do call:mulfloat "%nativeHeight%.000" "5.333" 3 wToReplace

    REM : create graphic pack folder
    if not exist !gp! mkdir !gp! > NUL

    REM : copy ResX2gpp one content in
    robocopy !gpResX2gp! !gp! /S > NUL

    REM : rules.txt
    set "rulesFilegp="!gp:"=!\rules.txt""

    REM : get gp name
    for /F "delims=" %%i in (!gp!) do set "gpName=%%~nxi"

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr\%gpName%""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL

    REM : replacing %wToReplace%xResX2gp in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "%wToReplace%x%resX2%" --replace "!width!x!height! !description!" --logFile !fnrLogFile!

    REM : replacing overwriteHeight = ResX2gp in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-!height!.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "overwriteHeight = %resX2%" --replace "overwriteHeight = !height!" --logFile !fnrLogFile!

    REM : replacing overwriteWidth = ResX2gp in rules.txt (shadows)
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-!height!asWidth.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "overwriteWidth = %resX2%" --replace "overwriteWidth = !height!" --logFile !fnrLogFile!

    REM : replacing overwriteWidth = %wToReplace% in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-!width!.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "overwriteWidth = %wToReplace%" --replace "overwriteWidth = !width!" --logFile !fnrLogFile!


    REM compute half target resolution
    call:divfloat2int "!height!.0" "2.0" 1 halfHeight
    call:divfloat2int "!width!.0" "2.0" 1 halfWidth

    REM : replacing half res height in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-!halfHeight!.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "overwriteHeight = 720" --replace "overwriteHeight = !halfHeight!" --logFile !fnrLogFile!

    REM : replacing half res height in rules.txt  (shadows)
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-!halfHeight!asWidth.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "overwriteWidth = 720" --replace "overwriteWidth = !halfHeight!" --logFile !fnrLogFile!

    REM : replacing half res width in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-!halfWidth!.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask rules.txt --find "overwriteWidth = 1280" --replace "overwriteWidth = !halfWidth!" --logFile !fnrLogFile!

    REM : treating extra files (*_*.txt) if needed
    set "pat="!gp:"=!\*_*s.txt""
    for /F "delims=" %%d in ('dir !pat! 2^>NUL') do goto:treatExtraFiles
    goto:eof

    :treatExtraFiles
    REM compute scale factor
    call:divfloat !height! !nativeHeight! 4 yScale
    call:divfloat !width! !nativeWidth! 4 xScale

    REM : replacing float resXScale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-xScale.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resXScale = 2.0" --replace "float resXScale = !xScale!" --logFile !fnrLogFile!

    REM : replacing float resYScale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-yScale.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resYScale = 2.0" --replace "float resYScale = !yScale!" --logFile !fnrLogFile!

    REM : replacing float resScale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_%wToReplace%xResX2gp-scale.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resScale = 2.0" --replace "float resScale = !yScale!" --logFile !fnrLogFile!

    exit /b 0

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :strLen
        set /A "len=0"
        :strLen_Loop
           if not ["!%1:~%len%!"] == [""] set /A len+=1 & goto:strLen_Loop
            set %2=%len%
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function for dividing integers
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

        if %decimals% EQU 0 set /A "result=%intPart%"

        REM : output
        set "%4=%result%"

    goto:eof
    REM : ------------------------------------------------------------------

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

    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to get and set char set code for current host
    :setCharSet

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
