@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

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

    if %nbArgs% NEQ 8 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" nativeWidth nativeHeight gpResX2gp gp width height description ratio
        echo given {%*}
        exit /b 99
    )


    REM : nativeWidth
    set /A "nativeWidth=!args[0]:"=!"
    REM : nativeHeight
    set /A "nativeHeight=!args[1]:"=!"

    set /A "hToReplace=!nativeHeight!*2"

    REM : gpResX2gp
    set "gpResX2gp=!args[2]!"
    REM : gp
    set "gp=!args[3]!"
    REM : width
    set /A "width=!args[4]:"=!"
    REM : height
    set /A "height=!args[5]:"=!"

    REM : description
    set /A "windowed=0"
    set "desc=!args[6]!"
    set "desc=!desc:"=!"

    set "ratio=!args[7]!"
    set "ratio=!ratio:"=!"


    REM : for others ratios (including windowed ones)
    pushd !BFW_TOOLS_PATH!

    set "intRatio=!ratio:.=!"
    for /F %%r in ('multiplyLongInteger.bat !hToReplace! !intRatio!') do set "result=%%r"

    call:removeDecimals !result! wToReplace

    REM : force even integer
    set /A "isEven=!wToReplace!%%2"
    if !isEven! NEQ 0 set /A "wToReplace=!wToReplace!+1"

    echo "!desc!" | find "(16/9)" > NUL 2>&1 && goto:beginTreatments

    REM : patch factor has only 3 decimals
    call:formatPatchValue !ratio! ratioValue

    set "descValue=!wToReplace!x!hToReplace!"
    set "desc=!width!x!height!!desc!"
    
    REM : 21/9 in GFX V2 is faulty 2.37037... instead of 2.333333333... => wToReplace=5120
    echo !gpResX2gp! | find /I "p219" > NUL 2>&1 && (
        if !nativeHeight! EQU 720 set /A "wToReplace=3440"
        if !nativeHeight! EQU 1080 set /A "wToReplace=5120"
        set "patchValue=2.370"
        set "descValue=!wToReplace!x!hToReplace! (21:9)"
    )

    echo !gpResX2gp! | find /I "p489" > NUL 2>&1 && (
        if !nativeHeight! EQU 720 set /A "wToReplace=7680"
        if !nativeHeight! EQU 1080 set /A "wToReplace=11520"
        set "patchValue=5.333"
        set "descValue=!wToReplace!x!hToReplace! (16:3)"
    )

    :beginTreatments

REM echo gp=!gp!
REM echo gpResX2gp=!gpResX2gp!
REM echo desc=!desc!
REM echo descValue=!descValue!
REM echo ratio=!ratio!
REM echo intRatio=!intRatio!
REM echo result=!result!
REM echo wToReplace=!wToReplace!
REM echo hToReplace=!hToReplace!
REM pause

    REM : create graphic pack folder
    if not exist !gp! mkdir !gp! > NUL 2>&1

    REM : copy ResX2gpp one content in
    robocopy !gpResX2gp! !gp! /S > NUL 2>&1

    REM : rules.txt
    set "rulesFilegp="!gp:"=!\rules.txt""

    REM : get gp name
    for /F "delims=~" %%i in (!gp!) do set "gpName=%%~nxi"

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr\%gpName%""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    set "fnrLogFile="!fnrLogFolder:"=!\!wToReplace!xResX2gp.log""
    echo "GFX !wToReplace!x!hToReplace! !desc!" > !fnrLogFile!
    echo "%*" >> !fnrLogFile!

    REM : replacing !wToReplace!xResX2gp in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp.log""
    if not ["!descValue!"] == [""] (

        echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!descValue!" --replace "!desc!" > !fnrLogFile!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!descValue!" --replace "!desc!" --logFile !fnrLogFile!

        echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wToReplace!x!hToReplace!" --replace "!width!x!height!" > !fnrLogFile!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wToReplace!x!hToReplace!" --replace "!width!x!height!!desc!" --logFile !fnrLogFile!
    ) else (
        echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wToReplace!x!hToReplace!" --replace "!width!x!height!!desc!" > !fnrLogFile!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wToReplace!x!hToReplace!" --replace "!width!x!height!!desc!" --logFile !fnrLogFile!
    )
    REM : replacing overwriteHeight = ResX2gp in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-!height!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteHeight = !hToReplace!" --replace "overwriteHeight = !height!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteHeight = !hToReplace!" --replace "overwriteHeight = !height!" --logFile !fnrLogFile!

    REM : replacing overwriteWidth = ResX2gp in rules.txt (shadows)
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-!height!asWidth.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !hToReplace!" --replace "overwriteWidth = !height!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !hToReplace!" --replace "overwriteWidth = !height!" --logFile !fnrLogFile!

    REM : replacing overwriteWidth = !wToReplace! in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-!width!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !wToReplace!" --replace "overwriteWidth = !width!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !wToReplace!" --replace "overwriteWidth = !width!" --logFile !fnrLogFile!

    REM compute half target resolution
    set /A "halfHeight=!height!/2"
    set /A "halfWidth=!width!/2"

    REM : replacing half res height in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-!halfHeight!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteHeight = !nativeHeight!" --replace "overwriteHeight = !halfHeight!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteHeight = !nativeHeight!" --replace "overwriteHeight = !halfHeight!" --logFile !fnrLogFile!

    REM : replacing half res height in rules.txt  (shadows)
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-!halfHeight!asWidth.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !nativeHeight!" --replace "overwriteWidth = !halfHeight!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !nativeHeight!" --replace "overwriteWidth = !halfHeight!" --logFile !fnrLogFile!

    REM : replacing half res width in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-!halfWidth!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !nativeWidth!" --replace "overwriteWidth = !halfWidth!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "overwriteWidth = !nativeWidth!" --replace "overwriteWidth = !halfWidth!" --logFile !fnrLogFile!

    echo "!desc!" | find "(16/9)" > NUL 2>&1 && goto:endMain

    REM : treating extra files (*_*.txt) if needed
    set "pat="!gp:"=!\*_*s.txt""
    for /F "delims=~" %%d in ('dir !pat! 2^>NUL') do goto:treatExtraFiles

    goto:endMain

    :treatExtraFiles

    REM compute scale factor
    call:divIntegers !height! !nativeHeight! 8 yScale
    call:divIntegers !width! !nativeWidth! 8 xScale

    REM : replacing float resXScale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-xScale.log""
    echo !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resXScale = 2.0" --replace "float resXScale = !xScale!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resXScale = 2.0" --replace "float resXScale = !xScale!" --logFile !fnrLogFile!

    REM : replacing float resYScale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-yScale.log""
    echo !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resYScale = 2.0" --replace "float resYScale = !yScale!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resYScale = 2.0" --replace "float resYScale = !yScale!" --logFile !fnrLogFile!

    REM : replacing float resScale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wToReplace!xResX2gp-scale.log""
    echo !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resScale = 2.0" --replace "float resScale = !yScale!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --find "float resScale = 2.0" --replace "float resScale = !yScale!" --logFile !fnrLogFile!

    set "patchFile="!gp:"=!\patches.txt""

    if not exist !patchFile! goto:endMain

    REM : replace scale factor in patchFile
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask patches.txt --find !patchValue! --replace !ratioValue! --logFile !fnrLogFile!

    :endMain
    rmdir /S /Q !fnrLogFolder! > NUL 2>&1
    exit /b 0
    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :formatPatchValue

        set "r=%~1"
        set "del=%r:~-3%"
        set "%2=!r:%del%=!"

    goto:eof
    REM : ------------------------------------------------------------------

    :removeDecimals

        set "r=%~1"
        set "del=%r:~-6%"
        set "%2=!r:%del%=!"

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
    :divIntegers

        REM : get a
        set /A "fpA=%~1"
        REM : get b
        set /A "fpB=%~2"
        REM : get number of decimals asked
        set /A "nbDec=%~3"

        call:strLen fpA strLenA
        call:strLen fpB strLenB

        set /A "nlA=!strLenA!"
        set /A "nlB=!strLenB!"

        set /A "max=%nlA%"
        if %nlB% GTR %nlA% set /A "max=%nlB%"
        set /A "decimals=9-%max%"

        set /A "one=1"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        REM : a / b
        set /A div=fpA*one/fpB

        set "intPart="!div:~0,-%decimals%!""
        if [!intPart!] == [""] set "intPart=0"
        set "intPart=%intPart:"=%"

        if %nbDec% LSS %decimals% (
            set "decPart=!div:~-%nbDec%!"
        ) else (
            set "decPart=!div:~-%decimals%!"
        )
        set "result=!intPart!.!decPart!"
        if %nbDec% EQU 0 set /A "result=!intPart!"


        REM : output
        set "%4=!result!"

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
