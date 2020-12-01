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

    REM : fix for incomplete titleId
    call:strLength !titleId! length
    if !length! EQU 13 set "titleId=000!titleId!"

    set "ftid=%titleId:~0,16%"

    REM : check if game is recognized
    call:checkValidity %ftid%

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%ftid%';"') do set "libFileLine="%%i""

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
       )

    set "title=%DescRead:"=%"
    set "GAME_TITLE=%title: =%"

    REM get all title Id for this game (in case of a new res gp creation)
    set "titleIdList=%titleId%"
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
    REM : FPS++ found flag
    set /A "fpsPpOld=0"
    set /A "fpsPP=0"
    REM : 60FPS++ found flag
    set /A "fps60=0"
    REM : 30FPS game flag
    set /A "g30=0"

    REM : initialize graphic pack
    set "gpLastVersion="!BFW_GP_FOLDER:"=!\!GAME_TITLE!_Speed""

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    set "bfwRulesFile="!gpLastVersion:"=!\rules.txt""
    set "LastVersionExistFlag=1"

    echo Native FPS in WiiU-Titles-Library^.csv = %nativeFps%
    echo.

    set "fnrLogLggp="!BFW_PATH:"=!\logs\fnr_createCapGraphicPacks.log""
    if exist !fnrLogLggp! del /F !fnrLogLggp! > NUL 2>&1

    REM : Search FPS++ patch
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --ExcludeDir _graphicPacksV2 --find %titleId:~3% --logFile !fnrLogLggp!  > NUL

    for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find "FPS++" 2^>NUL') do set /A "fpsPP=1"
    for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLggp! ^| find "60FPS" ^| find /V /I "player" 2^>NUL') do set /A "fps60=1"

    REM : 30FPS games
    if ["%nativeFps%"] == ["30"] set /A "g30=1"

    REM : if no 60FPS pack is found
    if !fps60! EQU 0 goto:searchForFpsPp

    echo 60FPS was found >> !cgpLogFile!
    echo 60FPS pack was found

    REM : that means that the nativeFPS of the game should be 30
    if %nativeFps% EQU 60 (
        REM : value in WiiU-Titles-Library.csv is wrong, patching the file
        call:patchInternalDataBase
        set "nativeFps=30"
    )

    :searchForFpsPp
    if !g30! EQU 1 (
        REM : when a FPS++ GFX is found on rules.txt, vsync is defined in => exit
        if !fpsPP! EQU 1 echo FPS^+^+ was found >> !cgpLogFile! & echo FPS^+^+ pack was found & goto:computeFactor
        if !fpsPpOld! EQU 1 echo Old FPS^+^+ GFX pack was found >> !cgpLogFile! & echo Old FPS^+^+ GFX pack was found & goto:computeFactor
        echo no FPS^+^+ GFX pack found >> !cgpLogFile!
        echo no FPS^+^+ GFX pack found

        REM : search V2 FPS++ graphic pack or patch for this game
        set "bfwgpv2="!BFW_GP_FOLDER:"=!\_graphicPacksV2""

        set "pat="!bfwgpv2:"=!\!GAME_TITLE!*FPS++*""
        for /F "delims=~" %%d in ('dir /B !pat! 2^>NUL') do set /A "fpsPpOld=1"
    )
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

    REM : create a shorcut to delete packs created for this games (as FPS CAP is called everytime
    REM : it makes sense to do it here
    call:createDeletePacksShorcut

    if %nbArgs% EQU 0 endlocal && pause

    exit /b 0
goto:eof


REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    REM : function to compute string length
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

    :patchInternalDataBase

        REM : wait that "createGameGraphicPacks.bat" or "createExtraGraphicPacks.bat" end
        set "capLogFileTmp="!TMP:"=!\BatchFw_createCapGfx_process.list""

        REM : wait the create*.bat end before continue
        echo Waiting create^/complete GFX processes end >> !cgpLogFile!
        echo Waiting create^/complete GFX processes end

        :waitLoop
        wmic process get Commandline 2>NUL | find /I ".exe" | find /I /V "wmic" | find /I /V "find" > !capLogFileTmp!
        type !capLogFileTmp! | find /I "create" | find /V "Cap" | find /I "GraphicPacks" > NUL 2>&1 && goto:waitLoop
        type !capLogFileTmp! | find /I "fnr.exe" > NUL 2>&1 && goto:waitLoop

        del /F !capLogFileTmp! > NUL 2>&1

        REM : get the lines for the game
        set "capLinesTmp="!TMP:"=!\BatchFw_createCapGfx_newLines.list""
        type !wiiTitlesDataBase! | find /I "%icoId%" > !capLinesTmp!

        set "fnrPacthDb="!BFW_PATH:"=!\logs\fnr_patchWiiUtitlesDataBase.log""
        if exist !fnrPacthDb! del /F !fnrPacthDb! > NUL 2>&1

        REM : Replace 60 by 30 in capLinesTmp
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !TMP! --fileMask "BatchFw_createCapGfx_newLines.list" --find ";60" --replace ";30" --logFile !fnrPacthDb!  > NUL

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


    :createDeletePacksShorcut

        REM : main shortcut folder
        set "WIIU_GAMES_FOLDER="NONE""

        REM : get the last location from logFile
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
        if [!WIIU_GAMES_FOLDER!] == ["NONE"] goto:eof

        REM : add a shortcut for deleting all packs created by BatchFw for thsi game
        set "shortcutFolder="!WIIU_GAMES_FOLDER:"=!\BatchFw\Tools\Graphic packs\BatchFw^'s packs""
        if not exist !shortcutFolder! mkdir !shortcutFolder! > NUL 2>&1

        set "shortcut="!shortcutFolder:"=!\Force rebuilding !GAME_TITLE! packs.lnk""
        if exist !shortcut! goto:eof

        REM : get GAME_FOLDER_PATH
        set "fnrSearch="!BFW_PATH:"=!\logs\fnr_createCapGraphicPacksShortcut.log""

        REM : check if the game exist in !TARGET_GAMES_FOLDER! (not dependant of the game folder's name)
        if exist !fnrSearch! del /F !fnrSearch!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !GAMES_FOLDER! --fileMask "meta.xml" --ExcludeDir "content, code, mlc01, Cemu" --includeSubDirectories --find !titleId!  --logFile !fnrSearch!

        REM : main shortcut folder
        set "GAME_FOLDER_PATH="NONE""
        for /F "tokens=2-3 delims=." %%j in ('type !fnrSearch! ^| find /I /V "^!" ^| find "File:"') do (
            set "metaFile="!GAMES_FOLDER:"=!%%j.%%k""
            set "GAME_FOLDER_PATH=!metaFile:\meta\meta.xml=!"
        )
        if [!GAME_FOLDER_PATH!] == ["NONE"] goto:eof

        set "ICO_PATH="!BFW_PATH:"=!\resources\icons\delete.ico""

        pushd !GAMES_FOLDER!
        for /F "delims=~" %%i in ('dir /A:D /S /B Cemu 2^>NUL') do (
            set "ico="%%i\!titleId!.ico""
            if exist !ico! (
                set "ICO_PATH=!ico!"
                set "ICO_PATH=!ICO_PATH:_BatchFw_Install\logs\=!"
            )
        )

        REM : temporary vbs file for creating a windows shortcut
        set "TMP_VBS_FILE="!TEMP!\delete_!GAME_TITLE!_GfxPacks_!DATE!.vbs""

        set "ARGS=!titleId!"

        set "LINK_DESCRIPTION="Delete !GAME_TITLE!'s packs created by BatchFw""

        REM : create object
        echo Set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo sLinkFile = !shortcut! >> !TMP_VBS_FILE!
        echo Set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!

        set "TARGET_PATH="!BFW_TOOLS_PATH:"=!\deleteBatchFwGraphicPacks.bat""

        echo oLink^.TargetPath = !TARGET_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Arguments = "!ARGS!" >> !TMP_VBS_FILE!
        echo oLink^.WorkingDirectory = !BFW_TOOLS_PATH! >> !TMP_VBS_FILE!

        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        del /F  !TMP_VBS_FILE! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    :getAllTitleIds

        REM now searching using icoId
        for /F "delims=~; tokens=1" %%i in ('type !wiiTitlesDataBase! ^| find /I ";'%icoId%';"') do (
            set "titleIdRead=%%i"
            set "titleIdRead=!titleIdRead:'=!"
            echo !titleIdList! | find /V "!titleIdRead!" > NUL 2>&1 && (
                set "titleIdList=!titleIdList!^,!titleIdRead!"
            )
        )
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
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix_cap.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpLastVersion! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :initLastVersionCapGP

        echo [Definition] > !bfwRulesFile!
        echo titleIds = !titleIdList! >> !bfwRulesFile!

        echo name = Speed Adjustment >> !bfwRulesFile!
        echo path = "!GAME_TITLE!/Modifications/Speed Adjustment" >> !bfwRulesFile!

        set "description=Adjust the emulation speed of static FPS games when engine model is FPS based. If it is not the case only menus will be affected. To work, you need to disable vsync AND ANY 60FPS GFX pack."
        if !nativeFps! EQU 30 (
            echo description = !description! BatchFw assume that the native FPS is 30^. If it is not^, change the native FPS to 60 in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        ) else (
            echo description = !description! BatchFw assume that the native FPS is 60^. If it is not^, change the native FPS to 30 in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
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
        set "description="!GAME_TITLE!_%displayedValue%FPS_cap by BatchFw"

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

echo g30=!g30!
echo fpsPP=!fpsPP!
echo g30=!g30! >> !cgpLogFile!
echo fpsPP=!fpsPP! >> !cgpLogFile!


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

        if !g30! EQU 1 goto:cap

        REM : 106% emulation speed preset
        call:createCapPreset 106

        :cap
        REM : emulation speed presets
        set /A "max=136"
        if !g30! EQU 0 set /A "max=118"
        for /L %%i in (109,3,!max!) do call:createCapPreset "%%i"

        :capMenu
        if !fpsPP! EQU 0 goto:done
        if !fpsPpOld! EQU 0 goto:done

        REM : 140-200% emulation speed presets
        for /L %%i in (140,20,240) do call:createCapPreset "%%i"

        REM : 250% emulation speed preset
        call:createCapPreset 250

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

    REM : function to create a FPS preset
    :createCapPreset

        set "targetPercent=%~1"

        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        echo cap to !targetPercent!%% >> !cgpLogFile!
        echo cap to !targetPercent!%%
        echo ---------------------------------- >> !cgpLogFile!
        echo ----------------------------------
        REM : cap to !targetPercent!%

        set /A "minusOne=targetPercent-1"
        set "floatFactor=!minusOne:~0,1!.!minusOne:~1,2!"

        call:mulfloat "!newNativeFpsOldGp!.00" "!floatFactor!" 2 fpsOldGp
        set /A "targetFpsOldGp=!fpsOldGp!/!factorOldGp!"

echo fpsOldGp=!fpsOldGp! >> !cgpLogFile!
echo fpsOldGp=!fpsOldGp!
echo targetFpsOldGp=!targetFpsOldGp! >> !cgpLogFile!
echo targetFpsOldGp=!targetFpsOldGp!

        call:createCapOldGP !fpsOldGp! !targetFpsOldGp!

        if !fpsPP! EQU 0 (
            call:mulfloat "!newNativeFps!.00" "!floatFactor!" 2 fps
            set /A "targetFps=!fps!/!factor!"
echo fps=!fps! >> !cgpLogFile!
echo fps=!fps!
echo targetFps=!targetFps! >> !cgpLogFile!
echo targetFps=!targetFps!

            call:fillCapLastVersion "!targetPercent!" "Speed (!targetFps!FPS)"
        )

    goto:eof
    REM : ------------------------------------------------------------------


