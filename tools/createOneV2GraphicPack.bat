@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color F0

    set "THIS_SCRIPT=%~0"

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
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

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

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    if %nbArgs% NEQ 7 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" nativeWidth nativeHeight overwriteWidth overwriteHeight gameName desc titleIdsList
        echo given {%*}
        exit /b 99
    )
    REM : get and check BFW_GP_FOLDER
    set "arg1=!args[0]!"
    set /A "nativeWidth=!arg1:"=!"

    set "arg2=!args[1]!"
    set /A "nativeHeight=!arg2:"=!"
    
    set "arg3=!args[2]!"
    set /A "overwriteWidth=!arg3:"=!"

    set "arg4=!args[3]!"
    set /A "overwriteHeight=!arg4:"=!"

    set "gameName=!args[4]!"
    set "gameName=!gameName:"=!"

    set "desc=!args[5]!"
    set "titleIdsList=!args[6]!"

    set "gfxPacksV2Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
    if not exist !gfxPacksV2Folder! mkdir !gfxPacksV2Folder! > NUL 2>&1

    REM : init
    set "sd=!desc!"
    set "sd=!sd: =!"
    set "sd=!sd:(=!"
    set "sd=!sd:)=!"
    set "sd=!sd:/=-!"

    REM : override
    echo !desc! | find /I " (16/9)" > NUL 2>&1 && set "sd=169"

    echo !desc! | find /I " (16/9) windowed" > NUL 2>&1 && set "sd=169_Win"

    echo !desc! | find /I " (16/10)" > NUL 2>&1 && set "sd=1610"

    echo !desc! | find /I " (16/10) windowed" > NUL 2>&1 && set "sd=1610_Win"

    echo !desc! | find /I " (16/9 laptop) windowed" > NUL 2>&1 && set "sd=169_laptopWin"

    echo !desc! | find /I " (16/9 laptop)" > NUL 2>&1 && set "sd=169_laptop"

    echo !desc! | find /I " (21/9 UltraWide 2.37:1)" > NUL 2>&1 && set "sd=219_uw237"

    echo !desc! | find /I " (21/9 UltraWide 2.4:1)" > NUL 2>&1 && set "sd=219_uw24"

    echo !desc! | find /I " (21/9 UltraWide 2.13:1)" > NUL 2>&1 && set "sd=219_uw213"

    echo !desc! | find /I " (TV Flat 1.85:1)" > NUL 2>&1 && set "sd=TvFlat_r185"

    echo !desc! | find /I " (TV Scope 2.39:1)" > NUL 2>&1 && set "sd=TvScope_r239"

    echo !desc! | find /I " (TV DCI 1.89:1)" > NUL 2>&1 && set "sd=TvDci_r189"

    set "gp="!gfxPacksV2Folder:"=!\!gameName!_!overwriteHeight!p!sd!""

    echo Creating !gp!

    if exist !gp! (
        echo ^^! !gp! already exists, skipped ^^!
        exit /b 1
    )
    if not exist !gp! mkdir !gp! > NUL 2>&1

    set "rulesFile="!gp:"=!\rules.txt""
    set "rulesFolder=!rulesFile:\rules.txt=!"

    echo [Definition] > !rulesFile!
    set "list=!titleIdsList:"=!"
    echo titleIds = !list! >> !rulesFile!

    set "name="!gameName! !overwriteWidth!x!overwriteHeight! !desc! created by BatchFw""
    if !overwriteWidth! EQU !nativeWidth! if !overwriteHeight! EQU !nativeHeight! (
        set "name="!gameName! !overwriteWidth!x!overwriteHeight! !desc! ^(native resolution^) created by BatchFw"
    )
    echo name = !name! >> !rulesFile!

    echo version = 2 >> !rulesFile!
    echo. >> !rulesFile!


    REM : res ratios instructions ------------------------------------------------------
    set /A "resRatio=1"

    REM : loop on multiples of !nativeHeight!
    :beginLoopRes

    set /A "r=!nativeHeight!%%!resRatio!"
    if !r! NEQ 0 set /A "resRatio+=1" & goto:beginLoopRes

    REM : compute targetHeight
    set /A "targetHeight=!nativeHeight!/!resRatio!"

    REM : compute targetWidth
    set /A "targetWidth=!nativeWidth!/!resRatio!"

    REM : compute half targetHeight
    set /A "halfOverwriteHeight=!overwriteHeight!/!resRatio!"

    REM : compute half targetWidth
    set /A "halfOverwriteWidth=!overwriteWidth!/!resRatio!"

REM :   echo Creating Res/!resRatio! filter for !targetWidth!x!targetHeight! !desc!

    REM 1^/%resRatio% res : %targetWidth%x%targetHeight%
    call:writeFilters >> !rulesFile!

    if !targetHeight! LEQ 8 goto:formatUtf8
    if !resRatio! GEQ 12 goto:formatUtf8
    set /A "resRatio+=1"
    goto:beginLoopRes

    :formatUtf8
    REM : force UTF8 format
    set "utf8="!gp:"=!\rules.bfw_tmp""
    copy /Y !rulesFile! !utf8! > NUL 2>&1
    type !utf8! > !rulesFile!
    del /F !utf8! > NUL 2>&1

    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    exit /b 0
    goto:eof

REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :dosToUnix
        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        REM : starting DATE
        set "date=%ldt%"

        REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix_!gameName!_!overwriteWidth!_!date!.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------

    :writeFilters

        echo # 1/!resRatio! Res
        echo [TextureRedefine]
        echo width = !targetWidth!
        echo height = !targetHeight!
        echo tileModesExcluded = 0x001 # For Video Playback
        echo formatsExcluded = 0x431
        echo overwriteWidth = !halfOverwriteWidth!
        echo overwriteHeight = !halfOverwriteHeight!
        echo #
        echo #

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            pause
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


