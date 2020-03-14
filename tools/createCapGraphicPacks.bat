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
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "cgpLogFile="!BFW_PATH:"=!\logs\createCapGraphicPacks.log""


    REM : set current char codeset
    call:setCharSet

    REM : game's name
    set "gameName=NONE"

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if exist !BFW_GP_FOLDER! (
        goto:getTitleId
    )

    echo Please select a reference graphics packs folder
    :askGpFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a graphic packs folder"') do set "folder=%%b" && set "BFW_GP_FOLDER=!folder:?= !"
    if [!BFW_GP_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askGpFolder
    )
    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !BFW_GP_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !BFW_GP_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askGpFolder
    )

    :getTitleId
    set "checkLenght="
    set "titleId="

    set /P "input=Enter title Id : "
    set "titleId=%input: =%"

    REM : check too short
    set "checkLenght=!titleId:~15,1!"

    if ["x!checkLenght!x"] == ["xx"] (
        echo Bad titleId ^^! must have at least 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )
    REM : check too long
    set "checkLenght=!titleId:~16,1!"

    if not ["x!checkLenght!x"] == ["xx"] (
        echo Bad titleId ^^! must have 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )

    goto:inputsAvailables

    REM : titleID and BFW_GP_FOLDER
    :getArgsValue
    echo. > !cgpLogFile!
    if %nbArgs% GTR 3 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID GP_NAME^* >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID GP_NAME^*
        echo given {%*}
        exit /b 99
    )
    if %nbArgs% LSS 2 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID GP_NAME^* >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID GP_NAME^*
        echo given {%*}
        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"

    if not exist !BFW_GP_FOLDER! (
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^! >> !cgpLogFile!
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!
        exit /b 1
    )
    REM : get titleId
    set "titleId=!args[1]!"
    set "titleId=%titleId: =%"

    if %nbArgs% EQU 3 (
        set "gameName=!args[2]!"
        set "gameName=!gameName:"=!"
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"
    set "titleId=%titleId: =%"

    set titleId=%titleId:"=%
    set "ftid=%titleId:~0,16%"

    REM : check if game is recognized
    call:checkValidity %ftid%

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%ftid%';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine

    if !QUIET_MODE! EQU 1 (
        cscript /nologo !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
        exit /b 3
    )
    echo createCapGraphicPacks ^: unable to get informations on the game for titleId %ftid% ^? >> !cgpLogFile!
    echo createCapGraphicPacks ^: unable to get informations on the game for titleId %ftid% ^?
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase! >> !cgpLogFile!
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase!

    goto:getTitleId

    :stripLine
    REM : strip line to get data
    for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
       set "titleIdRead=%%a"
       set "Desc=%%b"
       set "productCode=%%c"
       set "companyCode=%%d"
       set "notes=%%e"
       set "versions=%%f"
       set "region=%%g"
       set "acdn=%%h"
       set "icoId=%%i"
       set "nativeHeight=%%j"
       set "nativeFps=%%k"
       )

    set "title=%Desc:"=%"
    set "GAME_TITLE=%title: =_%"

    REM get all title Id for this game (in case of a new res gp creation)
    set "titleIdList="
    call:getAllTitleIds


    REM : create FPS CAP graphic packs
    if not ["!gameName!"] == ["NONE"] set "GAME_TITLE=!gameName!"

    echo ========================================================= >> !cgpLogFile!
    echo =========================================================
    echo Create FPS cap graphic packs for !GAME_TITLE! >> !cgpLogFile!
    echo Create FPS cap graphic packs for !GAME_TITLE!
    echo ========================================================= >> !cgpLogFile!
    echo =========================================================
    if !QUIET_MODE! EQU 1 goto:begin

    echo Launching in 30s
    echo     ^(y^) ^: launch now
    echo     ^(n^) ^: cancel
    echo ---------------------------------------------------------
    choice /C yn /T 6 /D y /N /M "Enter your choice ? : "
    if !ERRORLEVEL! EQU 2 (
        echo Cancelled by user ^!
        goto:eof
    )

    :begin
    REM : FPS++ found flag
    set /A "fpsPpOld=0"
    set /A "fpsPP=0"

    REM : initialize graphic pack
    set "gpLastVersion="!BFW_GP_FOLDER:"=!\!GAME_TITLE!_Speed""

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    set "bfwRulesFile="!gpLastVersion:"=!\rules.txt""
    set "LastVersionExistFlag=1"

    echo Native FPS set in WiiU-Titles-Library.csv to = %nativeFps%
    echo.

    set /A "g30=0"
    REM : for 30FPS games
    if ["%nativeFps%"] == ["30"] (

        set /A "g30=1"

        set "fnrLogLggp="!BFW_PATH:"=!\logs\fnr_createCapGraphicPacks.log""
        if exist !fnrLogLggp! del /F !fnrLogLggp!
        REM : Search FPS++ or 60FPS patch
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogLggp!  > NUL

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find "FPS++" 2^>NUL') do set /A "fpsPP=1"
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find "60FPS" 2^>NUL') do set /A "fpsPP=1"
    )

    REM : search V2 FPS++ graphic pack or patch for this game
    set "bfwgpv2="!BFW_GP_FOLDER:"=!\_graphicPacksV2""

    set "pat="!bfwgpv2:"=!\!GAME_TITLE!*FPS++*""
    for /F "delims=~" %%d in ('dir /B !pat! 2^>NUL') do (
        set /A "fpsPpOld=1"

    )

    REM : when a FPS++ or a 60FPS GFX is found on rules.txt, vsync is defined in => exit
    if !fpsPP! EQU 1 echo FPS^+^+ or 60FPS GFX pack was found >> !cgpLogFile! & echo FPS^+^+ or 60FPS GFX pack was found & goto:computeFactor
    if !fpsPpOld! EQU 1 echo Old FPS^+^+ GFX pack was found >> !cgpLogFile! & echo Old FPS^+^+ GFX pack was found & goto:computeFactor
    echo no FPS^+^+ or 60FPS GFX pack found >> !cgpLogFile!
    echo no FPS^+^+ or 60FPS GFX pack found

    :computeFactor
    REM : initialized for 60FPS games running @60FPS on WiiU
    set /A "factor=1"
    set /A "factorOldGp=1"

    REM : for 30FPS games running @60FPS on WiiU
    if !g30! EQU 1 (

        REM : graphic pack created by BatchFw : gameName=NONE no FPS++
        if [!gameName!] == ["NONE"] goto:create

        REM : else = 30 FPS native games without FPS++ : double vsyncValue to cap at target FPS

        if !fpsPP! EQU 0 set /A "factor=2"
        if !fpsPpOld! EQU 0 set /A "factorOldGp=2"

    )

    :create

    REM : computing fps references
    REM : for games running at 30FPS without FPS++ => 2x!nativeFps! else !nativeFps!
    set /A "newNativeFpsOldGp=!nativeFps!*!factorOldGp!"
    set /A "newNativeFps=!nativeFps!*!factor!"


    echo nativeFps=!nativeFps! >> !cgpLogFile!
    echo nativeFps=!nativeFps!
    echo newNativeFps=!newNativeFps! >> !cgpLogFile!
    echo newNativeFps=!newNativeFps!
    echo newNativeFpsOldGp=!newNativeFpsOldGp! >> !cgpLogFile!
    echo newNativeFpsOldGp=!newNativeFpsOldGp!
    
    if not exist !gpLastVersion! if !fpsPP! EQU 0 (
        set "LastVersionExistFlag=0"
        mkdir !gpLastVersion! > NUL 2>&1
        call:initLastVersionCapGP
    )

    REM : create FPS cap graphic packs
    call:createCapGP

    REM : finalize graphic packs if a FPS++ pack was not found
    if !fpsPP! EQU 1 rmdir /Q /S !gpLastVersion! > NUL 2>&1 && set "LastVersionExistFlag=1"
    if %LastVersionExistFlag% EQU 0 if !fpsPP! EQU 0 call:finalizeLastVersionCapGP

    if %nbArgs% EQU 0 endlocal && pause

    exit /b 0
goto:eof


REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :getAllTitleIds

        REM now searching using icoId
        set "line="NONE""

        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I ";%icoId%;"') do (
            for /F "tokens=1-11 delims=;" %%a in ("%%i") do (
               set "titleIdRead=%%a"
               set "titleIdList=!titleIdList!^,!titleIdRead:'=!"
             )
        )
        set "titleIdList=!titleIdList:~1!"
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
            echo ERROR ^: the number %numA% does not have %decimals% decimals >> !cgpLogFile!
            echo ERROR ^: the number %numA% does not have %decimals% decimals
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals >> !cgpLogFile!
            echo ERROR ^: the number %numB% does not have %decimals% decimals
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

    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpLastVersion! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :initLastVersionCapGP

        echo [Definition] > !bfwRulesFile!
        echo titleIds = !titleIdList! >> !bfwRulesFile!

        echo name = Speed Adjustment >> !bfwRulesFile!
        echo path = "!GAME_TITLE!/Modifications/Speed Adjustment" >> !bfwRulesFile!

        if !nativeFps! EQU 30 (
            echo description = Adjust the speed in game when engine model is FPS based^. ^
You need to disable vsync^. BatchFw assume that the native FPS is 30^. ^
If it is not^,change the native FPS to 60 in ^
_BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        ) else (
            echo description = Adjust the speed in game when engine model is FPS based^. ^
You need to disable vsync^. BatchFw assume that the native FPS is 60^. ^
If it is not^,change the native FPS to 30 in ^
_BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        )

        echo version = 3 >> !bfwRulesFile!
        echo. >> !bfwRulesFile!
        echo [Preset] >> !bfwRulesFile!
        echo name = 100%% Speed ^(Default^) >> !bfwRulesFile!
        echo $FPS = !newNativeFps! >> !bfwRulesFile!
        echo. >> !bfwRulesFile!

    goto:eof
    REM : ------------------------------------------------------------------

    :fillCapLastVersion

        set "desc1=%~1"
        set "desc2=%~2"

        set "desc=!desc1!%% !desc2!"
        if %LastVersionExistFlag% EQU 0 (

            echo [Preset] >> !bfwRulesFile!
            echo name = !desc! >> !bfwRulesFile!
            echo $FPS = !fps! >> !bfwRulesFile!
            echo. >> !bfwRulesFile!
            goto:eof
        )

        REM : search for "!desc1!" in rulesFile: if found exit
        for /F "delims=~" %%i in ('type !bfwRulesFile! ^| find /I /V "#" ^| find /I "!desc1!"') do goto:eof

        REM : not found add it by replacing a [Preset] bloc

        REM : Adding !fps! preset in rules.txt
        set "logFileLastVersion="!fnrLogFolder:"=!\!gameName:"=!-LastVersion_!fps!cap.log""
        if exist !logFileLastVersion! del /F !logFileLastVersion!

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpLastVersion! --fileMask "rules.txt" --find "[Preset]\nname = 100" --replace "[Preset]\nname = !desc!\n$FPS = !fps!\n\n[Preset]\nname = 100" --logFile !logFileLastVersion! > NUL

    goto:eof
    REM : ------------------------------------------------------------------

    :finalizeLastVersionCapGP

        echo [Control] >> !bfwRulesFile!
        echo vsyncFrequency = $FPS >> !bfwRulesFile!

        REM : Linux formating (CRLF -> LF)
        call:dosToUnix

        REM : force UTF8 format
        set "utf8=!bfwRulesFile:rules.txt=rules.bfw_tmp!"
        copy /Y !bfwRulesFile! !utf8! > NUL 2>&1
        type !utf8! > !bfwRulesFile!
        del /F !utf8! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :createCapOldGP

        set "syncValue=%~1"
        set "displayedValue=%~2"
        set "description="!GAME_TITLE!_%displayedValue%FPS_cap"

        set "bfwgpv2="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
        if not exist !bfwgpv2! goto:eof
        set "gp="!bfwgpv2:"=!\_BatchFw_%description: =_%""

        if exist !gp! (
            echo !gp! already exists, skipped ^^^! >> !cgpLogFile!
            echo !gp! already exists, skipped ^^^!
            goto:eof
        )
        if not exist !gp! mkdir !gp! > NUL 2>&1

        set "rulesFileV2="!gp:"=!\rules.txt""

        echo [Definition] > !rulesFileV2!
        echo titleIds = !titleIdList! >> !rulesFileV2!

        echo name = "%description:"=%" >> !rulesFileV2!
        echo version = 2 >> !rulesFileV2!
        echo. >> !rulesFileV2!

        echo # Cap FPS to %displayedValue% Allows you to adjust the game speed in game where engine is FPS dependant ^(need vsync to be disabled^)^. >> !rulesFileV2!
        echo [Control] >> !rulesFileV2!

        echo vsyncFrequency = %syncValue% >> !rulesFileV2!

        REM : force UTF8 format
        set "utf8=!rulesFileV2:rules.txt=rules.bfw_tmp!"
        copy /Y !rulesFileV2! !utf8! > NUL 2>&1
        type !utf8! > !rulesFileV2!
        del /F !utf8! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :createCapGP

        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 99%% ^(online compibility issue^) >> !cgpLogFile!
        echo cap to 99%% ^(online compibility issue^)
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 100%-1FPS (online compatibility)
        set /A "fpsOldGp=!newNativeFpsOldGp!-1"
        set /A "targetFpsOldGp=!fpsOldGp!/!factorOldGp!"

        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOldGp=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOldGp=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!

        set /A "fps=!newNativeFps!-1"
        set /A "targetFps=!fps!/!factor!"
        echo fps=!fps! >> !cgpLogFile!
        echo fps=!fps!
        echo targetFps=!targetFps! >> !cgpLogFile!
        echo targetFps=!targetFps!

        if !fpsPP! EQU 0 type !bfwRulesFile! | find /I /V "FPS = !fps!" > NUL 2>&1 && call:fillCapLastVersion "99" "Speed (!targetFps!FPS)"

        if !fpsPpOld! EQU 1 goto:capMenu

        if !g30! EQU 1 goto:cap110

        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 105%% >> !cgpLogFile!
        echo cap to 105%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 105%
        call:mulfloat "!newNativeFpsOldGp!.00" "1.04" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!/!factorOldGp!"
        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOldGp=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOldGp=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!

        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "1.04" 2 fps
            set /A "targetFps=!fps!/!factor!"
        echo fps=!fps! >> !cgpLogFile!
        echo fps=!fps!
        echo targetFps=!targetFps! >> !cgpLogFile!
        echo targetFps=!targetFps!

            call:fillCapLastVersion "105" "Speed (!targetFps!FPS)"
        )

        :cap110
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 110%% >> !cgpLogFile!
        echo cap to 110%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 110%
        call:mulfloat "!newNativeFpsOldGp!.00" "1.09" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!/!factorOldGp!"
        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOld=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOld=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!

        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "1.09" 2 fps
            set /A "targetFps=!fps!/!factor!"
            echo fps=!fps! >> !cgpLogFile!
            echo fps=!fps!

            echo targetFps=!targetFps! >> !cgpLogFile!
            echo targetFps=!targetFps!


            call:fillCapLastVersion "110" "Speed (!targetFps!FPS)"
        )
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 120%% >> !cgpLogFile!
        echo cap to 120%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 120%
        call:mulfloat "!newNativeFpsOldGp!.00" "1.19" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!/!factorOldGp!"
        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOld=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOld=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!

        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "1.19" 2 fps
            set /A "targetFps=!fps!/!factor!"
            echo fps=!fps! >> !cgpLogFile!
            echo fps=!fps!
            echo targetFps=!targetFps! >> !cgpLogFile!
            echo targetFps=!targetFps!


            call:fillCapLastVersion "120" "Speed (!targetFps!FPS)"
        )
        :capMenu
        if !g30! EQU 0 if !fpsPP! EQU 0 goto:done

        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 150%% >> !cgpLogFile!
        echo cap to 150%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 150%
        call:mulfloat "!newNativeFpsOldGp!.00" "1.49" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!/!factorOldGp!"
        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOld=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOld=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!

        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "1.49" 2 fps
            set /A "targetFps=!fps!/!factor!"
            echo fps=!fps! >> !cgpLogFile!
            echo fps=!fps!
            echo targetFps=!targetFps! >> !cgpLogFile!
            echo targetFps=!targetFps!

            call:fillCapLastVersion "150" "Speed (!targetFps!FPS)"
        )
        if !fpsPpOld! EQU 0 goto:done
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 200%% >> !cgpLogFile!
        echo cap to 200%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 200%
        call:mulfloat "!newNativeFpsOldGp!.00" "1.99" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!*2"
        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOld=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOld=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!
        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "1.99" 2 fps
            set /A "targetFps=!fps!*2"
            echo fps=!fps! >> !cgpLogFile!
            echo fps=!fps!
            echo targetFps=!targetFps! >> !cgpLogFile!
            echo targetFps=!targetFps!

            call:fillCapLastVersion "200" "Speed (!targetFps!FPS)"
        )
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to 250%% >> !cgpLogFile!
        echo cap to 250%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to 250%
        call:mulfloat "!newNativeFpsOldGp!.00" "2.49" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!*2"
        echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
        echo fpsOldGp=!fpsOldGp!
        echo targetFpsOld=!targetFpsOldGp! >> !cgpLogFile!
        echo targetFpsOld=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!
        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "2.49" 2 fps
            set /A "targetFps=!fps!*2"
            echo fps=!fps! >> !cgpLogFile!
            echo fps=!fps!
            echo targetFps=!targetFps! >> !cgpLogFile!
            echo targetFps=!targetFps!

            call:fillCapLastVersion "200" "Speed (!targetFps!FPS)"
        )
        :done
        echo ========================================================= >> !cgpLogFile!
        echo =========================================================
        echo FPS cap graphic packs created ^! >> !cgpLogFile!
        echo FPS cap graphic packs created ^!
    goto:eof
    REM : ------------------------------------------------------------------

    :create

    REM : function to check unrecognized game
    :checkValidity
        set "id=%~1"

        REM : check if titleId correspond to a game wihtout meta\meta.xml file
        set "begin=%id:~0,8%"
        call:check8hexValue %begin%
        set "end=%id:~8,8%"
        call:check8hexValue %end%

    goto:eof

    :check8hexValue
        set "halfId=%~1"

        if ["%halfId:ffffffff=%"] == ["%halfId%"] goto:eof
        if ["%halfId:FFFFFFFF=%"] == ["%halfId%"] goto:eof

        echo Ooops it look like your game have a problem ^:
        echo - if no meta^\meta^.xml file exist^, CEMU give an id BEGINNING with ffffffff
        echo   using the BATCH framework ^(wizardFirstSaving.bat^) on the game
        echo   will help you to create one^.
        echo - if CEMU not recognized the game^, it give an id ENDING with ffffffff
        echo   you might have made a mistake when applying a DLC over game^'s files
        echo   to fix^, overwrite game^'s file with its last update or if no update
        echo   are available^, re-dump the game ^!
        exit /b 2
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


