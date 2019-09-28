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
        goto:eof
    )

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

    set "createV2GraphicPacks="!BFW_TOOLS_PATH:"=!\createV2GraphicPacks.bat""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

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
    @echo Please select a reference graphicPacks folder

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
        @echo Path to !BFW_GP_FOLDER! is not DOS compatible^!^, please choose another location
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
        @echo Bad titleId ^^! must have at least 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )
    REM : check too long
    set "checkLenght=!titleId:~16,1!"

    if not ["x!checkLenght!x"] == ["xx"] (
        @echo Bad titleId ^^! must have 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )
    set "titleId=%titleId%"

    goto:inputsAvailables

    REM : titleID and BFW_GP_FOLDER
    :getArgsValue

    if %nbArgs% NEQ 2 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID
        @echo given {%*}
        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"

    if not exist !BFW_GP_FOLDER! (
        @echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!
        exit /b 1
    )
    REM : get titleId
    set "titleId=!args[1]!"

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"
    set "titleId=%titleId:"=%"

    REM : check if game is recognized
    call:checkValidity %titleId%

    :createGP
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine


    if !QUIET_MODE! EQU 1 (
        cscript /nologo !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
        exit /b 3
    )
    @echo createGameGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^?
    @echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase!

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
    set "GAME_TITLE=%title: =%"

    REM get all title Id for this game
    set "titleIdList="
    call:getAllTitleIds

    if !QUIET_MODE! EQU 1 goto:begin
    @echo =========================================================
    @echo Create graphic packs for !GAME_TITLE!
    @echo =========================================================

    @echo Launching in 30s
    @echo     ^(y^) ^: launch now
    @echo     ^(n^) ^: cancel
    @echo ---------------------------------------------------------
    choice /C yn /T 6 /D y /N /M "Enter your choice ? : "
    if !ERRORLEVEL! EQU 2 (
        @echo Cancelled by user ^!
        goto:eof
    )
    cls
    :begin

    REM compute native width (16/9 = 1.7777777)
    call:mulfloat "%nativeHeight%.000" "1.777" 3 nativeWidth

    REM : get the SCREEN_MODE from logHOSTNAME file
    set "screenMode=fullscreen"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%i"

    REM : create resolution graphic packs
    call:createResGP

    REM : waiting all children processes ending
    call:waitChildrenProcessesEnd

    if %nbArgs% EQU 0 endlocal && pause
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    exit /b 0
    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :waitChildrenProcessesEnd

        REM : waiting all children processes ending
        :waitingLoop
        for /F "delims=~" %%j in ('wmic process get Commandline ^| find /I "_BatchFW_Install" ^| find /I /V "wmic" ^| find /I "fnr.exe" ^| find /I "_BatchFW_Graphic_Packs" ^| find /I /V "find"') do (
            timeout /T 1 > NUL 2>&1
            goto:waitingLoop
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :initV3ResGraphicPack

        @echo [Definition] > !rulesFileV3!
        @echo titleIds = !titleIdList! >> !rulesFileV3!

        @echo name = Resolution >> !rulesFileV3!
        @echo path = "!GAME_TITLE!/Graphics/Resolution" >> !rulesFileV3!
        @echo description = Created by BatchFW. Changes the resolution of the game >> !rulesFileV3!
        @echo version = 3 >> !rulesFileV3!
        @echo # >> !rulesFileV3!
        @echo [Preset] >> !rulesFileV3!
        @echo name = %nativeWidth%x%nativeHeight% ^(Default^) >> !rulesFileV3!
        @echo $width = %nativeWidth% >> !rulesFileV3!
        @echo $height = %nativeHeight% >> !rulesFileV3!
        @echo $gameWidth = %nativeWidth% >> !rulesFileV3!
        @echo $gameHeight = %nativeHeight% >> !rulesFileV3!
        @echo # >> !rulesFileV3!

    goto:eof
    REM : ------------------------------------------------------------------

    :fillResV3GP
        set "overwriteWidth=%~1"
        set "overwriteHeight=%~2"
        set "desc=%~3"

        @echo [Preset] >> !rulesFileV3!
        @echo name = %overwriteWidth%x%overwriteHeight% %desc% >> !rulesFileV3!
        @echo $width = %overwriteWidth% >> !rulesFileV3!
        @echo $height = %overwriteHeight% >> !rulesFileV3!
        @echo $gameWidth = %nativeWidth% >> !rulesFileV3!
        @echo $gameHeight = %nativeHeight% >> !rulesFileV3!
        @echo # >> !rulesFileV3!

    goto:eof
    REM : ------------------------------------------------------------------

    :finalizeResV3GP


        REM : res ratios instructions ------------------------------------------------------
        set /A "resRatio=1"

        :beginLoopRes
        set /A "result=0"
        call:divfloat %nativeHeight% !resRatio! 1 result

        REM : check if targetHeight is an integer
        for /F "tokens=1-2 delims=." %%a in ("!result!") do if not ["%%b"] == ["0"] set /A "resRatio+=1" && goto:beginLoopRes

        set "targetHeight=!result:.0=!"
        REM compute targetWidth (16/9 = 1.7777777)
        call:mulfloat "!targetHeight!.000" "1.777" 3 targetWidth

        REM 1^/%resRatio% res : %targetWidth%x%targetHeight%
        call:writeRoundedV3Filters >> !rulesFileV3!

        if !targetHeight! LEQ 8 goto:formatUtf8
        if !resRatio! GEQ 8 goto:formatUtf8
        set /A "resRatio+=1"
        goto:beginLoopRes

        :formatUtf8

        REM : add commonly used 16/9 res filters
        @echo # add commonly used 16/9 res filters >> !rulesFileV3!
        @echo #  >> !rulesFileV3!
        @echo #  >> !rulesFileV3!

        if %nativeHeight% EQU 720 (
            REM : (1080/2 = 540, for 1080 treated when resRatio = 2)

            @echo # 960 x 540 Res >> !rulesFileV3!
            @echo [TextureRedefine] >> !rulesFileV3!
            @echo width = 960 >> !rulesFileV3!
            @echo height = 540 >> !rulesFileV3!
            @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
            @echo formatsExcluded = 0x431 >> !rulesFileV3!
            @echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !rulesFileV3!
            @echo overwriteHeight = ^($height^/$gameHeight^) ^* 540 >> !rulesFileV3!
            @echo #  >> !rulesFileV3!

            @echo # 960 x 544 Res >> !rulesFileV3!
            @echo [TextureRedefine] >> !rulesFileV3!
            @echo width = 960 >> !rulesFileV3!
            @echo height = 544 >> !rulesFileV3!
            @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
            @echo formatsExcluded = 0x431 >> !rulesFileV3!
            @echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !rulesFileV3!
            @echo overwriteHeight = ^($height^/$gameHeight^) ^* 544 >> !rulesFileV3!
            @echo #  >> !rulesFileV3!
        )

        @echo # 1137 x 640 Res >> !rulesFileV3!
        @echo [TextureRedefine] >> !rulesFileV3!
        @echo width = 1137 >> !rulesFileV3!
        @echo height = 640 >> !rulesFileV3!
        @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
        @echo formatsExcluded = 0x431 >> !rulesFileV3!
        @echo overwriteWidth = ^($width^/$gameWidth^) ^* 1137 >> !rulesFileV3!
        @echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !rulesFileV3!
        @echo #  >> !rulesFileV3!

        @echo # 1152 x 640 Res >> !rulesFileV3!
        @echo [TextureRedefine] >> !rulesFileV3!
        @echo width = 1152 >> !rulesFileV3!
        @echo height = 640 >> !rulesFileV3!
        @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
        @echo formatsExcluded = 0x431 >> !rulesFileV3!
        @echo overwriteWidth = ^($width^/$gameWidth^) ^* 1152 >> !rulesFileV3!
        @echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !rulesFileV3!
        @echo #  >> !rulesFileV3!

        @echo # 896 x 504 Res >> !rulesFileV3!
        @echo [TextureRedefine] >> !rulesFileV3!
        @echo width = 896 >> !rulesFileV3!
        @echo height = 504 >> !rulesFileV3!
        @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
        @echo formatsExcluded = 0x431 >> !rulesFileV3!
        @echo overwriteWidth = ^($width^/$gameWidth^) ^* 896 >> !rulesFileV3!
        @echo overwriteHeight = ^($height^/$gameHeight^) ^* 504 >> !rulesFileV3!
        @echo #  >> !rulesFileV3!

        @echo # 768 x 432 Res >> !rulesFileV3!
        @echo [TextureRedefine] >> !rulesFileV3!
        @echo width = 768 >> !rulesFileV3!
        @echo height = 432 >> !rulesFileV3!
        @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
        @echo formatsExcluded = 0x431 >> !rulesFileV3!
        @echo overwriteWidth = ^($width^/$gameWidth^) ^* 768 >> !rulesFileV3!
        @echo overwriteHeight = ^($height^/$gameHeight^) ^* 432 >> !rulesFileV3!
        @echo #  >> !rulesFileV3!

        @echo # 512 x 288 Res >> !rulesFileV3!
        @echo [TextureRedefine] >> !rulesFileV3!
        @echo width = 512 >> !rulesFileV3!
        @echo height = 288 >> !rulesFileV3!
        @echo tileModesExcluded = 0x001 # For Video Playback >> !rulesFileV3!
        @echo formatsExcluded = 0x431 >> !rulesFileV3!
        @echo overwriteWidth = ^($width^/$gameWidth^) ^* 512 >> !rulesFileV3!
        @echo overwriteHeight = ^($height^/$gameHeight^) ^* 288 >> !rulesFileV3!

        REM : force UTF8 format
        set "utf8=!rulesFileV3:rules.txt=rules.bfw_tmp!"
        copy /Y !rulesFileV3! !utf8! > NUL 2>&1
        type !utf8! > !rulesFileV3!
        del /F !utf8! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :writeRoundedV3Filters

        REM : loop on -8,-4,0,4,12 (rounded values)
        set /A "rh=0"
        for /L %%i in (-8,4,12) do (

            @echo # 1/!resRatio! Res rounded at %%i
            @echo [TextureRedefine]
            @echo width = !targetWidth!

            set /A "rh=!targetHeight!+%%i"
            @echo height = !rh!
            @echo tileModesExcluded = 0x001 # For Video Playback
            @echo formatsExcluded = 0x431
            @echo overwriteWidth = ^($width^/$gameWidth^) ^* !targetWidth!
            @echo overwriteHeight = ^($height^/$gameHeight^) ^* !rh!
            @echo #
        )
        @echo #

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
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
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


    :create1610
        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:1610_windowed

        REM : 16/10 full screen graphic packs
        set /A "h=360"
        set /A "w=576"
        set /A "dw=288"

        for /L %%p in (1,1,31) do (
            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p1610" !GAME_TITLE! "(16:10)"
            call:fillResV3GP !w! !h! "^(16^:10^)"

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )

        @echo 16^/10 fullscreen graphic packs created ^!

        goto:eof

        :1610_windowed
        REM : 16/10 windowed graphic packs
        set /A "h=360"
        set /A "w=620"
        set /A "dw=310"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p1610_windowed" !GAME_TITLE! "(16:10) windowed"
            call:fillResV3GP !w! !h! "^(16^:10^) windowed"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )
        @echo 16^/10 windowed graphic packs created ^!
    goto:eof
    REM : ------------------------------------------------------------------

    :create219
        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:219_windowed

        REM : 21/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=840"
        set /A "dw=420"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p219" !GAME_TITLE! "(21:9)"
            call:fillResV3GP !w! !h! "^(21^:9^)"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )

        @echo 21^/9 graphic packs created ^!

        goto:eof

        :219_windowed
        REM : 21/9 windowed graphic packs
        set /A "h=360"
        set /A "w=908"
        set /A "dw=452"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p219_windowed" !GAME_TITLE! "(21:9) windowed"
            call:fillResV3GP !w! !h! "^(21^:9^) windowed"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )
        @echo 21^/9 windowed graphic packs created ^!

    goto:eof
    REM : ------------------------------------------------------------------

    :create169

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:169_windowed

        echo !ARLIST! | find /I /V "169" > NUL 2>&1 && goto:eof

        REM : 16/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=640"
        set /A "dw=320"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p" !GAME_TITLE!
            call:fillResV3GP !w! !h! ""
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )

        @echo 16^/9 graphic packs created ^!
        goto:eof

        :169_windowed

        REM : create windowed packs only if user chosen it during setup
        echo !ARLIST! | find /I /V "169" > NUL 2>&1 && goto:eof

        REM : 16/9 windowed graphic packs
        set /A "h=360"
        set /A "w=694"
        set /A "dw=344"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p169_windowed" !GAME_TITLE! "(16:9) windowed"
            call:fillResV3GP !w! !h! "^(16^:9^) windowed"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )
        @echo 16^/9 windowed graphic packs created ^!

    goto:eof
    REM : ------------------------------------------------------------------

    :create43

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:43_windowed
        REM : 4/3 fullscreen graphic packs
        set /A "h=360"
        set /A "w=480"
        set /A "dw=540"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p43" !GAME_TITLE! "(4:3)"
            call:fillResV3GP !w! !h! "^(4^:3^)"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )

        @echo 4^/3 graphic packs created ^!
        goto:eof

        :43_windowed
        REM : 4/3 windowed graphic packs
        set /A "h=360"
        set /A "w=526"
        set /A "dw=580"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p43_windowed" !GAME_TITLE! "(4:3) windowed"
            call:fillResV3GP !w! !h! "^(4^:3^) windowed"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )
        @echo 4^/3 windowed graphic packs created ^!

    goto:eof
    REM : ------------------------------------------------------------------

    :create489

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:489_windowed

        REM : 48/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=1920"
        set /A "dw=960"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p489" !GAME_TITLE! "(48:9)"
            call:fillResV3GP !w! !h! "^(48^:9^)"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )

        @echo 48^/9 graphic packs created ^!

        goto:eof

        :489_windowed
        REM : 48/9 windowed graphic packs
        set /A "h=360"
        set /A "w=2074"
        set /A "dw=1034"

        for /L %%p in (1,1,31) do (

            wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeHeight! !w! !h! "!GAME_TITLE!_!h!p489_windowed" !GAME_TITLE! "(48:9) windowed"
            call:fillResV3GP !w! !h! "^(48^:9^) windowed"
            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )
        @echo 48^/9 windowed graphic packs created ^!

    goto:eof
    REM : ------------------------------------------------------------------

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

    :createResGP

        REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
        set "ARLIST="
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do set "ARLIST=%%i !ARLIST!"
        REM : if not defined, here fix it to 16/9
        if ["!ARLIST!"] == [""] set "ARLIST=169"

        REM : initialize V3 graphic pack
        set "gpv3="!BFW_GP_FOLDER:"=!\!GAME_TITLE!_Resolution""
        if exist !gpv3! (
            @echo ^^! !GAME_TITLE! already exists, skipped ^^!
            goto:eof
        )
        if not exist !gpv3! mkdir !gpv3! > NUL 2>&1
        set "rulesFileV3="!gpv3:"=!\rules.txt""

        call:initV3ResGraphicPack %nativeHeight% %nativeWidth% !GAME_TITLE!

        REM : create 16/9 fullscreen graphic packs
        call:create169

        REM : waiting all children processes ending
        call:waitChildrenProcessesEnd

        for %%a in (!ARLIST!) do (
            if ["%%a"] == ["1610"] call:create1610
            REM : waiting all children processes ending
            call:waitChildrenProcessesEnd
            if ["%%a"] == ["219"]  call:create219
            REM : waiting all children processes ending
            call:waitChildrenProcessesEnd
            if ["%%a"] == ["43"]   call:create43
            REM : waiting all children processes ending
            call:waitChildrenProcessesEnd
            if ["%%a"] == ["489"]  call:create489
            REM : waiting all children processes ending
            call:waitChildrenProcessesEnd
        )

        call:finalizeResV3GP

    goto:eof
    REM : ------------------------------------------------------------------

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

        @echo Ooops it look like your game have a problem ^:
        @echo - if no meta^\meta^.xml file exist^, CEMU give an id BEGINNING with ffffffff
        @echo   using the BATCH framework ^(wizardFirstSaving.bat^) on the game
        @echo   will help you to create one^.
        @echo - if CEMU not recognized the game^, it give an id ENDING with ffffffff
        @echo   you might have made a mistake when applying a DLC over game^'s files
        @echo   to fix^, overwrite game^'s file with its last update or if no update
        @echo   are available^, re-dump the game ^!
        exit /b 2
    goto:eof
    REM : ------------------------------------------------------------------

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
        dir !toCheck! > NUL 2>&1
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
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
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


