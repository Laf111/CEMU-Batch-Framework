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
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""

    REM : set current char codeset
    call:setCharSet

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]=%~1"
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% NEQ 7 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" nativeWidth nativeHeight gpResX2gp gp width height description
        echo given {%*}
        exit /b 99
    )


    REM : nativeWidth
    set /A "nativeWidth=!args[0]:"=!"
    REM : nativeHeight
    set /A "nativeHeight=!args[1]:"=!"

    set /A "hResX2GpUsed=!nativeHeight!*2"

    REM : gpResX2gp
    set "gpResX2gp="!args[2]!""

    if not exist !gpResX2gp! (
        echo ERROR ^: !gpResX2gp! does not exist
        exit /b 3
    )
    REM : gp
    set "gp="!args[3]!""
    REM : width
    set /A "width=!args[4]!"
    REM : height
    set /A "height=!args[5]!"

    REM : description
    set "desc=!args[6]!"

    pushd !BFW_TOOLS_PATH!

    REM : init with 16/9 values
    REM : tmplRatioValue will not be used for 16-9 (no patches.txt file)
    set "tmplRatioValue=1.777"
    set "tmplResXScale=2.0"
    set "tmplResYScale=2.0"
    if !nativeHeight! EQU 720 set /A "wResX2GpUsed=2560"
    if !nativeHeight! EQU 1080 set /A "wResX2GpUsed=3840"
    set "descValue=!wResX2GpUsed!x!hResX2GpUsed!"
    set "desc=!width!x!height!!desc!"
    
    REM : 21/9 in GFX V2 is faulty 2.37037... instead of 2.333333333... => wResX2GpUsed=5120
    echo !gpResX2gp! | find /I "p219" > NUL 2>&1 && (
        if !nativeHeight! EQU 720 set /A "wResX2GpUsed=3440"
        if !nativeHeight! EQU 1080 set /A "wResX2GpUsed=5120"

        set "tmplRatioValue=2.389"
        set "tmplResXScale=2.6875"
        set "descValue=!wResX2GpUsed!x!hResX2GpUsed! (21:9)"
    )

    echo !gpResX2gp! | find /I "p489" > NUL 2>&1 && (
        if !nativeHeight! EQU 720 set /A "wResX2GpUsed=7680"
        if !nativeHeight! EQU 1080 set /A "wResX2GpUsed=11520"

        set "tmplRatioValue=5.333"
        set "tmplResXScale=6.0"
        set "descValue=!wResX2GpUsed!x!hResX2GpUsed! (16:3)"
    )

echo nativeWidth=!nativeWidth!
echo nativeHeight=!nativeHeight!
echo gpResX2gp=!gpResX2gp!
echo gp=!gp!
echo width=!width!
echo height=!height!
echo desc=!desc!

echo descValue=!descValue!
echo wResX2GpUsed=!wResX2GpUsed!
echo hResX2GpUsed=!hResX2GpUsed!
echo tmplRatioValue=!tmplRatioValue!
echo tmplResXScale=!tmplResXScale!

    REM : create graphic pack folder
    if not exist !gp! mkdir !gp! > NUL 2>&1

    REM : copy ResX2gpp one content in
    robocopy !gpResX2gp! !gp! /MT:32 /S > NUL 2>&1

    REM : rules.txt
    set "rulesFile="!gp:"=!\rules.txt""
    set "rulesFolder=!gp!"

    REM : force UTF8 format
    set "utf8="!gp:"=!\rules.bfw_tmp""
    copy /Y !rulesFile! !utf8! > NUL 2>&1
    type !utf8! > !rulesFile!
    del /F !utf8! > NUL 2>&1

    REM : get gp name
    for /F "delims=~" %%i in (!gp!) do set "gpName=%%~nxi"
    set "uTdLog="!fnrLogFolder:"=!\dosToUnix_instanciate_!gpName!.log""
    
    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1
    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr\%gpName%""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    set "fnrLogFile="!fnrLogFolder:"=!\!wResX2GpUsed!xResX2gp.log""
    echo "GFX !wResX2GpUsed!x!hResX2GpUsed! !desc!" > !fnrLogFile!
    echo "%*" >> !fnrLogFile!

    REM : replacing !wResX2GpUsed!xResX2gp in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp.log""
    if not ["!descValue!"] == [""] (

        echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!descValue!" --replace "!desc!" > !fnrLogFile!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!descValue!" --replace "!desc!" --logFile !fnrLogFile!

        echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wResX2GpUsed!x!hResX2GpUsed!" --replace "!width!x!height!" > !fnrLogFile!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wResX2GpUsed!x!hResX2GpUsed!" --replace "!width!x!height!!desc!" --logFile !fnrLogFile!
    ) else (
        echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wResX2GpUsed!x!hResX2GpUsed!" --replace "!width!x!height!!desc!" > !fnrLogFile!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --find "!wResX2GpUsed!x!hResX2GpUsed!" --replace "!width!x!height!!desc!" --logFile !fnrLogFile!
    )
    REM : replacing overwriteHeight = ResX2gp in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-!height!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteHeight[ ]*=[ ]*!hResX2GpUsed!" --replace "overwriteHeight = !height!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteHeight[ ]*=[ ]*!hResX2GpUsed!" --replace "overwriteHeight = !height!" --logFile !fnrLogFile!

    REM : replacing overwriteWidth = ResX2gp in rules.txt (shadows)
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-!height!asWidth.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth[ ]*=[ ]*!hResX2GpUsed!" --replace "overwriteWidth = !height!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth = !hResX2GpUsed!" --replace "overwriteWidth = !height!" --logFile !fnrLogFile!

    REM : replacing overwriteWidth = !wResX2GpUsed! in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-!width!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth[ ]*=[ ]*!wResX2GpUsed!" --replace "overwriteWidth = !width!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth = !wResX2GpUsed!" --replace "overwriteWidth = !width!" --logFile !fnrLogFile!

    REM compute half target resolution
    set /A "halfHeight=!height!/2"
    set /A "halfWidth=!width!/2"

    REM : replacing half res height in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-!halfHeight!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteHeight[ ]*=[ ]*!nativeHeight!" --replace "overwriteHeight = !halfHeight!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteHeight = !nativeHeight!" --replace "overwriteHeight = !halfHeight!" --logFile !fnrLogFile!

    REM : replacing half res height in rules.txt  (shadows)
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-!halfHeight!asWidth.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth[ ]*=[ ]*!nativeHeight!" --replace "overwriteWidth = !halfHeight!" > !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth = !nativeHeight!" --replace "overwriteWidth = !halfHeight!" --logFile !fnrLogFile!

    REM : replacing half res width in rules.txt
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-!halfWidth!.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth[ ]*=[ ]*!nativeWidth!" --replace "overwriteWidth = !halfWidth!" > !fnrLogFile!
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !gp! --fileMask "rules.txt" --useRegEx --find "overwriteWidth[ ]*=[ ]*!nativeWidth!" --replace "overwriteWidth = !halfWidth!" --logFile !fnrLogFile!

    echo "!desc!" | find "(16/9)" | find /I /V "win" > NUL 2>&1 && goto:endMain

    REM : treating extra files (*_*.txt) if needed
    set "pat="!gp:"=!\*_*s.txt""

    for /F "delims=~" %%d in ('dir !pat! 2^>NUL') do goto:treatExtraFiles

    goto:endMain

    :treatExtraFiles

    REM compute scale factor
    call:divIntegers !height! !nativeHeight! yScale
    call:divIntegers !width! !nativeWidth! xScale
echo xScale=!xScale!
echo yScale=!yScale!

    REM : replacing float resXScale = 2.0 (for every aspect ratios)
    set "fnrLogFileExtraFiles="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-xScale.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "*_*s.txt" --useRegEx --find "resXScale[ ]*=[ ]*!tmplResXScale!" --replace "resXScale = !xScale!" > !fnrLogFileExtraFiles!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "*_*s.txt" --useRegEx --find "resXScale[ ]*=[ ]*!tmplResXScale!" --replace "resXScale = !xScale!" --logFile !fnrLogFileExtraFiles!

    REM : replacing float resYScale = 2.0
    set "fnrLogFileExtraFiles="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-yScale.log""
    echo !fnrPath! --cl --dir !gp! --fileMask "*_*s.txt" --useRegEx --find "resYScale[ ]*=[ ]*!tmplResYScale!" --replace "resYScale = !yScale!" > !fnrLogFileExtraFiles!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gp! --fileMask "*_*s.txt" --useRegEx --find "resYScale[ ]*=[ ]*!tmplResYScale!" --replace "resYScale = !yScale!" --logFile !fnrLogFileExtraFiles!

    REM : replacing float resScale = 2.0
    set "fnrLogFileExtraFiles="!fnrLogFolder:"=!\fnr_!wResX2GpUsed!xResX2gp-scale.log""
    echo !fnrPath! --cl --dir !gp! --fileMask *_*s.txt --useRegEx --find "resScale[ ]*=[ ]*!tmplResXScale!" --replace "resScale = !xScale!" > !fnrLogFileExtraFiles!
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !gp! --fileMask "*_*s.txt" --useRegEx --find "resScale[ ]*=[ ]*!tmplResXScale!" --replace "resScale = !yScale!" --logFile !fnrLogFileExtraFiles!

    set "patchFile="!gp:"=!\patches.txt""

    if not exist !patchFile! goto:endMain

    call:divIntegers !width! !height! ratioValue
echo ratioValue=!ratioValue!


    REM : replace scale factor in patchFile
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !gp! --fileMask "patches.txt" --find !tmplRatioValue! --replace !ratioValue! --logFile !fnrLogFileExtraFiles!

    :endMain
        
    exit /b 0
    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :reduceFraction

        set /A "w=%~1"
        set /A "h=%~2"

        for /L %%l in (19,-1,2) do (

            set /A "multiplier=%%l"
            set /A "r=!w!%%!multiplier!"

            if !r! EQU 0 (
                set /A "r=!h!%%!multiplier!"
                if !r! EQU 0 (
                    set /A "w=w/!multiplier!"
                    set /A "h=h/!multiplier!"
                )
            )
        )
        REM : avoid 8/5 for 16/10
        if !w! EQU 8 if !h! EQU 5 set /A "w=16" & set /A "h=10"

        set /A "%3=!w!"
        set /A "%4=!h!"
    goto:eof
    REM : ------------------------------------------------------------------

    :strLen
        set /A "len=0"
        :strLen_Loop
           if not ["!%1:~%len%!"] == [""] set /A len+=1 & goto:strLen_Loop
            set /A "%2=%len%"
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function for dividing integers
    :divIntegers


        REM : reduce the fraction of possible
        call:reduceFraction %~1 %~2 sWr sHr

        REM : get a
        set /A "fpA=!sWr!"
        REM : get b
        set /A "fpB=!sHr!"

        REM : fix number of decimals to 7 (int 32 bits limitation)
        set /A "nbDec=7"

        call:strLen fpA nlA
        call:strLen fpB nlB

        set /A "max=!nlA!"
        if !nlB! GTR !nlA! set /A "max=!nlB!"
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
            goto:setResult
        )
        REM : %nbDec% GEQ %decimals%
        set "decPart=!div:~-%decimals%!"
        set /A "nbMis=nbDec-decimals"
        for /L %%l in (1,1,!nbMis!) do set "decPart=!decPart!0"

        :setResult
        set "result=!intPart!.!decPart!"
        if %nbDec% EQU 0 set /A "result=!intPart!"

        REM : output
        set "%3=!result!"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
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
