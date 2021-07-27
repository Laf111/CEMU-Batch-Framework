@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

REM    color 4F

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
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "ccgpLogFile="!BFW_LOGS:"=!\createCapGraphicPacks.log""


    REM : set current char codeset
    call:setCharSet

    REM : game's name
    set "gameName="

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    echo. > !ccgpLogFile!

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if exist !BFW_GP_FOLDER! (
        echo !BFW_GP_FOLDER! des not exist
        pause
        exit /b 200
    )

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

    REM : get gfxPackVersion version to create
    echo.
    echo Which version of pack to you wish to create ^^?
    echo.
    echo     - 1 ^: CEMU ^< 1^.14
    echo     - 2 ^: 1^.14 ^< CEMU ^< 1^.21
    echo     - 3 ^: CEMU ^> 1^.21
    echo.
    choice /C 123 /T 15 /D 3 /N /M "Enter your choice ? : "
    set /A "crx2=!ERRORLEVEL!*2"
    set "gfxPackVersion=V!crx2!"

    goto:inputsAvailables

    REM : getArgsValue
    :getArgsValue
    if %nbArgs% LEQ 3 (
        echo ERROR ^: on arguments passed ^^! >> !ccgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^* >> !ccgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^*
        echo where NAME is optional >> !ccgpLogFile!
        echo where NAME is optional
        echo given {%*} >> !ccgpLogFile!
        echo given {%*}
        exit /b 99
    )
    if %nbArgs% GTR 5 (
        echo ERROR ^: on arguments passed ^^! >> !ccgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^* >> !ccgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^*
        echo where NAME is optional >> !ccgpLogFile!
        echo where NAME is optional
        echo given {%*} >> !ccgpLogFile!
        echo given {%*}
        exit /b 99
    )
    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"

    REM : gfx pack folder of the game
    set "GAME_GP_FOLDER=!args[1]!"

    REM : get gfxPackVersion
    set "gfxPackVersion=!args[2]!"
    set "gfxPackVersion=!gfxPackVersion:"=!"

    REM : get titleId
    set "titleId=!args[3]!"

    if %nbArgs% EQU 5 (
        set "str=!args[4]!"
        set "gameName=!str:"=!"
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

     set "titleId=!titleId:"=!"

    REM : init with gameName
    set "GAME_TITLE=!gameName!"

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!titleId!';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine

    if !QUIET_MODE! EQU 1 (
        !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
        exit /b 65
    )
    echo createCapGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^^? >> !ccgpLogFile!
    echo createCapGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^^?
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase! >> !ccgpLogFile!
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase!

    :stripLine
    REM : strip line to get data
    for /F "tokens=1-12 delims=;" %%a in (!libFileLine!) do (
       set "titleIdRead=%%a"
       set "DescRead="%%b""
       set "productCode=%%c"
       set "companyCode=%%d"
       set "notes=%%e"
       set "versions=%%f"
       set "region=%%g"
       set "acdn=%%h"
       set "icoId=%%i"
       set "nativeHeight=%%j"
       set "nativeFps=%%k"
       set "typeCapFps=%%l"
    )

    REM get all title Id for this game
    set "titleIdsList=!titleId!"
    call:getAllTitleIds

    set "title=%DescRead:"=%"
    REM : if FPS CAP does not work on this game, skipping
    if ["!typeCapFps!"] == ["NOEF"] (
        echo !title! is not sensible to FPS GFX pack ^(NOEF in !wiiTitlesDataBase!^)^, skipping^.^.^. >> !ccgpLogFile!
        echo !title! is not sensible to FPS GFX pack ^(NOEF in !wiiTitlesDataBase!^)^, skipping^.^.^.
        exit /b 0
    )

    if ["!gameName!"] == [""] set "GAME_TITLE=%title: =%"

    echo ========================================================= >> !ccgpLogFile!
    echo =========================================================
    echo Create !gfxPackVersion! FPS cap graphic packs for !GAME_TITLE! >> !ccgpLogFile!
    echo Create !gfxPackVersion! FPS cap graphic packs for !GAME_TITLE!
    echo ========================================================= >> !ccgpLogFile!
    echo =========================================================
    if !QUIET_MODE! EQU 1 goto:begin

    echo Launching in 15s
    echo     ^(y^) ^: launch now
    echo     ^(n^) ^: cancel
    echo ---------------------------------------------------------
    choice /C yn /T 15 /D y /N /M "Enter your choice ? : "
    if !ERRORLEVEL! EQU 2 (
        echo Cancelled by user ^!
        goto:eof
    )

    :begin
    echo Creating FPS GFX packs^.^.^.  >> !ccgpLogFile!
    echo Creating FPS GFX packs^.^.^.

    REM : FPS++ found flag
    set /A "fpsPP=0"
    REM : 60FPS++ found flag
    set /A "fps60=0"
    REM : 30FPS game flag
    set /A "g30=0"

    REM : initialize graphic pack
    set "gfxp="!BFW_GP_FOLDER:"=!\!GAME_TITLE!\SetFps""

    REM : others BatchFW GFX packs folders for earlier version
    set "gfxPacksV2Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
    if ["!gfxPackVersion!"] == ["V2"] (
        if not exist !gfxPacksV2Folder!  mkdir !gfxPacksV2Folder! > NUL 2>&1
        REM : no check on gfxp
        goto:process
    )
    set "gfxPacksV4Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV4""
    if ["!gfxPackVersion!"] == ["V4"] (
        if not exist !gfxPacksV4Folder!  mkdir !gfxPacksV4Folder! > NUL 2>&1
        set "gfxp="!BFW_GP_FOLDER:"=!\_graphicPacksV4\!GAME_TITLE!_SetFps""
    )

    if not exist !gfxp! mkdir !gfxp! > NUL 2>&1
    set "gfxpPath="!gfxp:"=!\rules.txt""

    if exist !gfxpPath! (
        echo !gfxpPath! already exist^, skipping^.^.^.
        goto:linkPack
    )

    :process
    set "fnrLogFolder="!BFW_LOGS:"=!\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    echo Native FPS in WiiU-Titles-Library^.csv = %nativeFps%
    echo.

    set "fnrLogLggp="!BFW_LOGS:"=!\fnr_createCapGraphicPacks.log""
    if exist !fnrLogLggp! del /F !fnrLogLggp! > NUL 2>&1

    REM : Search FPS++ patch
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --ExcludeDir _graphicPacksV --find %titleId:~3% --logFile !fnrLogLggp!

    for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find "FPS++" 2^>NUL') do set /A "fpsPP=1"
    for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find "60FPS" ^| find /V /I "player" 2^>NUL') do set /A "fps60=1"

    REM : 30FPS games
    if ["%nativeFps%"] == ["30"] set /A "g30=1"

    REM : if no 60FPS pack is found
    if !fps60! EQU 0 goto:searchForFpsPp

    echo 60FPS was found >> !ccgpLogFile!
    echo 60FPS pack was found

    REM : that means that the nativeFPS of the game should be 30
    if ["%nativeFps%"] == ["60"]  (
        REM : value in WiiU-Titles-Library.csv is wrong, patching the file
        call:patchInternalDataBase
        set "nativeFps=30"
    )

    :searchForFpsPp
    if !g30! EQU 1 (
        REM : when a FPS++ GFX is found on rules.txt
        if !fpsPP! EQU 1 echo FPS^+^+ was found >> !ccgpLogFile! & echo FPS^+^+ pack was found & goto:computeFactor
        echo no FPS^+^+ GFX pack found >> !ccgpLogFile!
        echo no FPS^+^+ GFX pack found
    )
    :computeFactor
    REM : initialized for 60FPS games running @60FPS on WiiU
    set /A "factor=1"

    REM : for 30FPS games running @60FPS on WiiU
    if !g30! EQU 1 (

        REM : graphic pack created by BatchFw : gameName=NONE no FPS++
        if [!gameName!] == [""] goto:create

        REM : else = 30 FPS native games without FPS++ : double vsyncValue to cap at target FPS

        if !fpsPP! EQU 0 set /A "factor=2"

    )

    :create
    REM : computing fps references
    REM : for games running at 30FPS without FPS++ => 2x!nativeFps! else !nativeFps!
    set /A "newNativeFps=!nativeFps!*!factor!"


echo nativeFps=!nativeFps! >> !ccgpLogFile!
echo nativeFps=!nativeFps!
echo newNativeFps=!newNativeFps! >> !ccgpLogFile!
echo newNativeFps=!newNativeFps!


    if not ["!gfxPackVersion!"] == ["V2"] call:initLastVersionCapGP

    REM : create FPS cap graphic packs
    call:createCapGP

    if not ["!gfxPackVersion!"] == ["V2"] call:finalizeLastVersionCapGP

    :linkPack
    REM : if not V2 (packs linked at the end of updateGameGraphicPacks.bat)
    if not ["!gfxPackVersion!"] == ["V2"] (
        REM : create link to res pack in GAME_GP_FOLDER (not found in searchFor*Packs)
        set "relativePath=!gfxpPath:*_BatchFw_Graphic_Packs\=!"
        call:createGfxpLink !relativePath!
    )
    if %nbArgs% EQU 0 endlocal && pause

    goto:eof

REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions


    :getMainGfxpFolder

        set "folder=!targetPath!"
        set "lastFolder=!folder!"

        :rewindPath
        for /F "delims=~" %%i in (!folder!) do set "folderName=%%~nxi"

        echo !folderName! | find "_graphicPacksV" > NUL 2>&1 && goto:endFct
        echo !folderName! | find "_BatchFw_Graphic_Packs" > NUL 2>&1 && goto:endFct

        set "lastFolder=!folder!"
        for %%a in (!folder!) do set "parentFolder="%%~dpa""
        set "folder=!parentFolder:~0,-2!""
        goto:rewindPath

        :endFct
        set "targetPath=!lastFolder!"

        for /F "delims=~" %%i in (!lastFolder!) do set "folderName=%%~nxi"
        set "linkPath="!GAME_GP_FOLDER:"=!\!folderName:"=!""
        goto:eof
    REM : ------------------------------------------------------------------

    :createGfxpLink
        set "rules="%~1""

        set "gp=!rules:\rules.txt=!"
        set "relativePath=!gp:*_BatchFw_Graphic_Packs\=!"

        set "linkPath="!GAME_GP_FOLDER:"=!\!relativePath:"=!""
        set "linkPath=!linkPath:\_graphicPacksV4=!"

        REM : link already exist, exit
        if exist !linkPath! goto:eof

        set "targetPath="!BFW_GP_FOLDER:"=!\!relativePath:"=!""

        call:getMainGfxpFolder

        if exist !targetPath! if not exist !linkPath! mklink /J /D !linkPath! !targetPath! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :patchInternalDataBase

        REM : wait that "createGameGraphicPacks.bat" or "createExtraGraphicPacks.bat" end
        set "capLogFileTmp="!TMP:"=!\BatchFw_createCapGfx_process.list""

        REM : wait the create*.bat end before continue
        echo Waiting create^/complete GFX processes end >> !ccgpLogFile!
        echo Waiting create^/complete GFX processes end

        :waitLoop
        wmic process get Commandline 2>NUL | find /I ".exe" | find /I /V "wmic" | find /I /V "find" > !capLogFileTmp!
        type !capLogFileTmp! | find /I "create" | find /V "Cap" | find /I "GraphicPacks" > NUL 2>&1 && goto:waitLoop
        type !capLogFileTmp! | find /I "fnr.exe" > NUL 2>&1 && goto:waitLoop

        del /F !capLogFileTmp! > NUL 2>&1

        REM : get the lines for the game
        set "capLinesTmp="!TMP:"=!\BatchFw_createCapGfx_newLines.list""
        type !wiiTitlesDataBase! | find /I "%icoId%" > !capLinesTmp!

        set "fnrPacthDb="!BFW_LOGS:"=!\fnr_patchWiiUtitlesDataBase.log""
        if exist !fnrPacthDb! del /F !fnrPacthDb! > NUL 2>&1

        REM : Replace 60 by 30 in capLinesTmp
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !TMP! --fileMask "BatchFw_createCapGfx_newLines.list" --find ";60" --replace ";30" --logFile !fnrPacthDb!

        REM : remove the line and add the new one with 30FPS as nativeFps
        set "wiiTitlesDataBaseTmp="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.tmp""
        type !wiiTitlesDataBase! | find /I /V "%icoId%" > !wiiTitlesDataBaseTmp!

        type !capLinesTmp! >> !wiiTitlesDataBaseTmp!

        REM : remove readonly attribute
        attrib -R !wiiTitlesDataBase! > NUL 2>&1

        REM : create new file (sorted)
        type !wiiTitlesDataBaseTmp! | sort > !wiiTitlesDataBase!

        REM : set the readonly attribute
        attrib +R !wiiTitlesDataBase! > NUL 2>&1

        del /F !capLinesTmp! > NUL 2>&1
        del /F !wiiTitlesDataBaseTmp! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    :getAllTitleIds

        REM now searching using icoId
        for /F "delims=~; tokens=1" %%i in ('type !wiiTitlesDataBase! ^| find /I ";%icoId%;"') do (
            set "titleIdRead=%%i"
            set "titleIdRead=!titleIdRead:'=!"
            echo !titleIdsList! | find /V "!titleIdRead!" > NUL 2>&1 && (
                set "titleIdsList=!titleIdsList!,!titleIdRead!"
            )
        )
        set "titleIdsList="!titleIdsList!""
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
            echo ERROR ^: the number %numA% does not have %decimals% decimals >> !ccgpLogFile!
            echo ERROR ^: the number %numA% does not have %decimals% decimals
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals >> !ccgpLogFile!
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
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix_cap.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gfxp! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :initLastVersionCapGP

        echo [Definition] > !gfxpPath!
        set "list=!titleIdsList:"=!"
        echo titleIds = !list! >> !gfxpPath!

        if ["!typeCapFps!"] == ["SYNCSCR"] (
            echo name = FPS adjustment >> !gfxpPath!
            echo path = "!GAME_TITLE!/Modifications/FPS adjustment" >> !gfxpPath!
        ) else (
            echo name = Emulation speed adjustment >> !gfxpPath!
            echo path = "!GAME_TITLE!/Modifications/Emulation speed adjustment" >> !gfxpPath!
        )
        set "descSpeed=Adjust the emulation speed"
        set "descFPS=Increase the FPS"

        set "description=!descSpeed!"
        if ["!typeCapFps!"] == ["SYNCSCR"] set "description=!descFPS!"

        if ["%nativeFps%"] == ["30"] (
            echo description = !description!^. Vsync AND ANY 60FPS patch GFX pack need to be disbaled^.^. BatchFw assume that the native FPS is 30^. If it is not^, change the native FPS to 60 in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !gfxpPath!
        ) else (
            echo description = !description!^. Vsync AND ANY 60FPS patch GFX pack need to be disbaled^.^. BatchFw assume that the native FPS is 60^. If it is not^, change the native FPS to 30 in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !gfxpPath!
        )
        set /A "gfxVersion=!gfxPackVersion:V=!"
        echo version = !gfxVersion! >> !gfxpPath!
        echo. >> !gfxpPath!

        if !gfxVersion! EQU 4 (
            echo. >> !gfxpPath!
            echo [Preset] >> !gfxpPath!
            echo name = 100%% Speed ^(Default^) >> !gfxpPath!
            echo $FPS = !newNativeFps! >> !gfxpPath!
            echo. >> !gfxpPath!
        )
        if !gfxVersion! EQU 6 (
            echo. >> !gfxpPath!
            echo [Default] >> !gfxpPath!
            echo $FPS = !newNativeFps! >> !gfxpPath!
            echo. >> !gfxpPath!
        )
        echo. >> !gfxpPath!

    goto:eof
    REM : ------------------------------------------------------------------

    :fillCapLastVersion

        set "desc1=%~1"
        set "desc2=%~2"

        set "desc=!desc1!%% !desc2!"

        echo [Preset] >> !gfxpPath!
        echo name = !desc! >> !gfxpPath!
        echo $FPS = !fps! >> !gfxpPath!
        echo. >> !gfxpPath!
        goto:eof

        REM : search for "!desc1!" in rulesFile: if found exit
        for /F "delims=~" %%i in ('type !gfxpPath! ^| find /I /V "#" ^| find /I "!desc1!"') do goto:eof

        REM : not found add it by replacing a [Preset] bloc

        REM : Adding !fps! preset in rules.txt
        set "logFileLastVersion="!fnrLogFolder:"=!\!gameName:"=!-LastVersion_!fps!cap.log""
        if exist !logFileLastVersion! del /F !logFileLastVersion!

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gfxp! --fileMask "rules.txt" --find "[Preset]\nname = 100" --replace "[Preset]\nname = !desc!\n$FPS = !fps!\n\n[Preset]\nname = 100" --logFile !logFileLastVersion!

    goto:eof
    REM : ------------------------------------------------------------------

    :finalizeLastVersionCapGP

        echo [Control] >> !gfxpPath!
        echo vsyncFrequency = $FPS >> !gfxpPath!

        REM : Linux formating (CRLF -> LF)
        call:dosToUnix

        REM : force UTF8 format
        set "utf8=!gfxpPath:rules.txt=rules.bfw_tmp!"
        copy /Y !gfxpPath! !utf8! > NUL 2>&1
        type !utf8! > !gfxpPath!
        del /F !utf8! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :createCapOldGP

        set "syncValue=%~1"
        set "displayedValue=%~2"
        set "description="!GAME_TITLE!_%displayedValue%FPS_cap"

        if not exist !gfxPacksV2Folder! goto:eof
        set "gp="!gfxPacksV2Folder:"=!\%description: =_%""

        if exist !gp! (
            echo !gp! already exists, skipped ^^! >> !ccgpLogFile!
            echo !gp! already exists, skipped ^^!
            goto:eof
        )
        if not exist !gp! mkdir !gp! > NUL 2>&1

        set "rulesFileV2="!gp:"=!\rules.txt""

        echo [Definition] > !rulesFileV2!
        set "list=!titleIdsList:"=!"
        echo titleIds = !list! >> !rulesFileV2!

        echo name = "%description:"=%" >> !rulesFileV2!
        echo version = 2 >> !rulesFileV2!
        echo. >> !rulesFileV2!

        echo # Cap FPS to %displayedValue% Allows you to adjust the game speed or the FPS only ^(need vsync to be disabled^)^. >> !rulesFileV2!
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

    if ["!typeCapFps!"] == ["SYNCSCR"] goto:syncScr

echo g30=!g30!
echo fpsPP=!fpsPP!
echo g30=!g30! >> !ccgpLogFile!
echo fpsPP=!fpsPP! >> !ccgpLogFile!


        echo ---------------------------------- >> !ccgpLogFile!
        echo ----------------------------------
        echo cap to 99%% ^(online compibility issue^) >> !ccgpLogFile!
        echo cap to 99%% ^(online compibility issue^)
        echo ---------------------------------- >> !ccgpLogFile!
        echo ----------------------------------
        REM : cap to 100%-1FPS (online compatibility)

set /A "fps=!newNativeFps!-1"
set /A "targetFps=!fps!/!factor!"
echo fps=!fps! >> !ccgpLogFile!
echo fps=!fps!
echo targetFps=!targetFps! >> !ccgpLogFile!
echo targetFps=!targetFps!

        if ["!gfxPackVersion!"] == ["V2"] (
            REM : for V2 create FPS CAP even if a FPS++ exist
REM            if !fpsPP! EQU 0 call:createCapOldGP !fpsOldGp! !targetFpsOldGp!
            call:createCapOldGP !fps! !targetFps!
        ) else (
            type !gfxpPath! | find /I /V "FPS = !fps!" > NUL 2>&1 && call:fillCapLastVersion "99" "Speed (!targetFps!FPS)"
        )

        if !fpsPp! EQU 1 goto:capMenu

        if !g30! EQU 1 goto:cap

        REM : 106% emulation speed preset
        call:createCapPreset 104

        :cap
        REM : emulation speed presets
        set /A "max=135"
        set /A "dt=6"
        if !g30! EQU 0 (
            set /A "max=124"
            set /A "dt=3"
        )
        for /L %%i in (108,!dt!,!max!) do call:createCapPreset "%%i"

        :capMenu
        if !fpsPP! EQU 0 goto:syncScr

        REM : 140-200% emulation speed presets
        for /L %%i in (140,20,240) do call:createCapPreset "%%i"

        REM : 250% emulation speed preset
        call:createCapPreset 250

        :syncScr

        if ["!typeCapFps!"] == ["SYNCSCR"] call:createRefreshRatesGp


        echo ========================================================= >> !ccgpLogFile!
        echo =========================================================
        echo FPS cap graphic packs created ^^! >> !ccgpLogFile!
        echo FPS cap graphic packs created ^^!

    goto:eof
    REM : ------------------------------------------------------------------

    :createRfGp
        set /A "fps=%~1"
        set /A "fpsToDisplay=%fps%"
        set "h=%~2"

        if !g30! EQU 1 if !fpsPp! EQU 0 set /A "fps=%fps%*2"

        echo FPS CAP gfx pack ^: !gfxpPath! >> !ccgpLogFile!

        echo ---------------------------------- >> !ccgpLogFile!
        echo ----------------------------------
        echo !h! ^: %fpsToDisplay%Hz monitor ^(%fpsToDisplay% FPS^)>> !ccgpLogFile!
        echo !h! ^: %fpsToDisplay%Hz monitor ^(%fpsToDisplay% FPS^)
        echo ---------------------------------- >> !ccgpLogFile!
        echo ----------------------------------

        if ["!gfxPackVersion!"] == ["V2"] (
            call:createCapOldGP %fps% %fpsToDisplay%
        ) else (
            echo [Preset] >> !gfxpPath!
            echo name = !USERDOMAIN! %fpsToDisplay%Hz monitor ^(%fpsToDisplay% FPS^)>> !gfxpPath!
            echo $FPS = %fps% >> !gfxpPath!
            echo. >> !gfxpPath!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :createRefreshRatesGp


        set "refreshRatesArray="
        set "refreshRatesList="
        set "hostsArray="

        set /A "nbRf=0"

        REM : search in all Host_*.log
        set "pat="!BFW_LOGS:"=!\Host_*.log""

        for /F "delims=~" %%i in ('dir /S /B !pat! 2^>NUL') do (
            set "currentLogFile="%%i""

            REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
            for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "REFRESH_RATE" 2^>NUL') do (
                REM : if not already in the list
                echo !refreshRatesList! | find /I /V "%%j" > NUL 2>&1 && (

                    set "rf=%%j"

                    REM : if different than nativeFPS
                    if not ["%rf%"] == ["%nativeFps%"] (
                        REM : if preset does not already exist in the list the rules.txt
                        if exist !gfxpPath! type !gfxpPath! | find /I "$FPS = !rf!" > NUL 2>&1 && goto:skip

                        set "tmpStr=!currentLogFile:*Host_=!"
                        set "host=!tmpStr:.log=!"
                        set "host=!host:"=!"

                        set "hostsArray[!nbRf!]=!host!"
                        set "refreshRatesArray[!nbRf!]=!rf!"

                        set /A "nbRf+=1"
                        set "refreshRatesList=!refreshRatesList! !rf!"

                        :skip
                        set "rf=0"
                    )
                )
            )
        )

        set /A "nm1=nbRf-1"
        for /L %%i in (0,1,%nm1%) do (
            call:createRfGp !refreshRatesArray[%%i]! !hostsArray[%%i]!
        )
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
            set "logFolder="!BFW_LOGS:"=!""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to create a FPS preset
    :createCapPreset

        set "targetPercent=%~1"

        echo ---------------------------------- >> !ccgpLogFile!
        echo ----------------------------------
        echo cap to !targetPercent!%% >> !ccgpLogFile!
        echo cap to !targetPercent!%%
        echo ---------------------------------- >> !ccgpLogFile!
        echo ----------------------------------
        REM : cap to !targetPercent!%

        set /A "minusOne=targetPercent-1"
        set "floatFactor=!minusOne:~0,1!.!minusOne:~1,2!"

        call:mulfloat "!newNativeFps!.00" "!floatFactor!" 2 fps
        set /A "targetFps=!fps!/!factor!"

        if ["!gfxPackVersion!"] == ["V2"] (
            call:createCapOldGP !fps! !targetFps!
            goto:eof
        )

        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "!floatFactor!" 2 fps
            set /A "targetFps=!fps!/!factor!"
echo fps=!fps! >> !ccgpLogFile!
echo fps=!fps!
echo targetFps=!targetFps! >> !ccgpLogFile!
echo targetFps=!targetFps!

            call:fillCapLastVersion "!targetPercent!" "Speed (!targetFps!FPS)"
        )

    goto:eof
    REM : ------------------------------------------------------------------


