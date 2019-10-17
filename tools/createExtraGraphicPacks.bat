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

        exit /b 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""


    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "instanciateResX2gp="!BFW_TOOLS_PATH:"=!\instanciateResX2gp.bat""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : game's name
    set "gameName=NONE"

    REM : flag to create leagcy packs
    set "createLegacyPacks=true"

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
    REM : ask for legacy packs creation
    choice /C yn /N /M "Do you want to create legacy graphic packs ? (y, n) : "
    if !ERRORLEVEL!=2 set "createLegacyPacks=false"

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

    if %nbArgs% GTR 4 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID CREATE_LEGACY NAME^*
        @echo given {%*}

        exit /b 99
    )
    if %nbArgs% LSS 3 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID CREATE_LEGACY NAME^*
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

    set "createLegacyPacks=!args[2]!"

    if %nbArgs% EQU 4 (
        set "str=!args[3]!"
        set "gameName=!str:"=!"
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"
    set "titleId=%titleId:"=%"
    set "createLegacyPacks=%createLegacyPacks:"=%"

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
    @echo createExtraGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^?
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

    REM compute native width (16/9 = 1.7777777)
    call:mulfloat "%nativeHeight%.000" "1.777" 3 nativeWidth

    if not ["%gameName%"] == ["NONE"] set "GAME_TITLE=%gameName%"

    @echo =========================================================
    @echo Create extra graphic packs ^(missing resolutions^) for !GAME_TITLE!
    @echo =========================================================
    @echo Native height set to !nativeHeight! in WiiU-Titles-Library.csv

    REM get all title Id for this game (in case of a new V3 res gp creation)
    set "titleIdList="
    call:getAllTitleIds

    set "ARLIST="

    REM : search in all Host_*.log
    set "pat="!BFW_PATH:"=!\logs\Host_*.log""
    for /F %%i in ('dir /S /B !pat! 2^>NUL') do (
        set "currentLogFile="%%i""

        REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
        set "ARLIST="
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (
            REM : add to the list if not already present
            echo !ARLIST! | find /V "%%i" > NUL 2>&1 && set "ARLIST=%%i !ARLIST!"
        )
    )

    if ["!ARLIST!"] == [""] (
        @echo Unable to get desired aspect ratio ^(choosen during setup^) ^?
        @echo Delete batchFW outputs and relaunch
        if !QUIET_MODE! EQU 0 pause
        exit /b 2
    )

    REM : get the SCREEN_MODE from logHOSTNAME file
    set "screenMode=fullscreen"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%i"

    pushd !BFW_GP_FOLDER!

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    set "fnrLogCegp="!BFW_PATH:"=!\logs\fnr_createExtraGraphicPacks.log""
    if exist !fnrLogCegp! del /F !fnrLogCegp!

    REM : flag for V3 graphic packs existence
    set "gpV3exist=0"
    set "v2Name="NOT_FOUND""
    REM : launching the search
    echo !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId% > !fnrLogCegp!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId% --logFile !fnrLogCegp!


    REM : creating V2 graphic packs by instanciating nativeHeightx2 graphic packs
    set /A "resX2=%nativeHeight%*2"

    for /F "tokens=2-3 delims=." %%i in ('type !fnrLogCegp! ^| find "File:" ^| find /I /V "^!" ^| find /I /V "_Gamepad" ^| find /I /V "_BatchFW" ^| find /I /V "_Performance_" ^| find /V "_Resolution_" 2^>NUL') do (

        set "rules="!BFW_GP_FOLDER:"=!%%i.%%j""

        set "gpName=%%i"
        set "gpName=!gpName:rules=!"
        set "gpName=!gpName:\=!"

        if ["%createLegacyPacks%"] == ["true"] if not ["!gpName!"] == ["NOT_FOUND"] echo !gpName! | find "_graphicPacksV2" > NUL 2>&1 && (
            set "gpName=!gpName:_graphicPacksV2=_graphicPacksV2\!"
            echo !gpName! | find "_%resX2%p" | find /I /V "_%resX2%p219" | find /I /V "_%resX2%p1610" | find /I /V "_%resX2%p169" | find /I /V "_%resX2%p43" | find /I /V "_%resX2%p489" > NUL 2>&1 && set "v2Name=!gpName:_%resX2%p=!" && call:createExtraV2Gp "!gpName!"
        )

        REM : creating V3 graphic packs
        if not ["!gpName!"] == ["NOT_FOUND"] echo !gpName! | find /I /V "_graphicPacksV2" > NUL 2>&1 && (type !rules! | find "$height" > NUL 2>&1 && set "gpV3exist=1" && call:createExtraV3Gp "!gpName!")

    )
    if %gpV3exist% EQU 1 goto:ending

    REM : create V3 res graphic pack (game support in slahiee repository but not present in gfx pack)

    REM : search a V2 2xres graphic pack if found v2Name

    if [!v2Name!] == ["NOT_FOUND"] set "v3name="!GAME_TITLE!"" && goto:createNewV3

    set "gpResX2="!BFW_GP_FOLDER:"=!\!v2Name!_%resX2%p""
    set "v3name=!v2Name:_graphicPacksV2\=!"

    :createNewV3

    set "gpV3="!BFW_GP_FOLDER:"=!\!v3name!_Resolution""

    if not exist !gpV3! mkdir !gpV3! > NUL 2>&1
    set "rulesFileV3="!gpV3:"=!\rules.txt""

    call:initV3ResGraphicPack
    call:createExtraV3Gp "!v3name!"
    call:finalizeResV3GP

    if not exist !gpResX2! goto:ending

    REM : copy files near the rules.txt files
    robocopy !gpResX2! !gpV3! /S /XF rules.txt

    REM : replacing float Scale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_gpV3-resXScale.log""
    echo !fnrPath! --cl --dir !gpV3! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)" > !fnrLogFile!
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !gpV3! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)" --logFile !fnrLogFile!

    set "fnrLogFile="!fnrLogFolder:"=!\fnr_gpV3-resYScale.log""
    echo !fnrPath! --cl --dir !gpV3! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)" > !fnrLogFile!
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !gpV3! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)" --logFile !fnrLogFile

    set "fnrLogFile="!fnrLogFolder:"=!\fnr_gpV3-resScale.log""
    echo !fnrPath! --cl --dir !gpV3! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)" > !fnrLogFile!
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !gpV3! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)" --logFile !fnrLogFile!


    :ending
    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"
    @echo ending date = %date%

    @echo =========================================================

    call:waitChildrenProcessesEnd

    if %nbArgs% EQU 0 endlocal && pause
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!

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


    REM : function to create extra V2 graphic packs for a game
    :createExtraV2Gp

        set "gpFolderName="%~1""
        set "gpResX2="!BFW_GP_FOLDER:"=!\!gpFolderName:"=!""

        REM create FPS cap GP
        set "rulesFile="!gpResX2:"=!\rules.txt""

        call:treatGP

        REM : create missing full screen 16/9 resolutions graphic packs
        call:createV2Gp169 !gpResX2!

        REM : create missing resolution graphic packs
        for %%a in (!ARLIST!) do (
            if ["%%a"] == ["1610"] call:createV2Gp1610 !gpResX2!
            if ["%%a"] == ["219"]  call:createV2Gp219 !gpResX2!
            if ["%%a"] == ["43"]   call:createV2Gp43 !gpResX2!
            if ["%%a"] == ["489"]  call:createV2Gp489 !gpResX2!
        )

        set "name=!gpFolderName:_%resX2%p=!"
        set "name=!name:_graphicPacksV2\=!"
        @echo ---------------------------------------------------------
        @echo ^> !name:"=!^'s V2 extra graphic packs created successfully

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to create extra graphic packs for a game
    :createExtraV3Gp

        set "gpFolderName="%~1""
        set "gpV3="!BFW_GP_FOLDER:"=!\!gpFolderName:"=!""

        echo !gpv3! | find /V "_Resolution" > NUL 2>&1 && goto:eof

        set "rulesFile="!gpV3:"=!\rules.txt""

        REM : Windows formating (LF -> CRLF)
        call:dosToUnix

        REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
        set "gpNativeHeight=NOT_FOUND"
        for /F "tokens=4 delims=x " %%s in ('type !rulesFile! ^| find /I "name" ^| find /I "Default" 2^>NUL') do set "gpNativeHeight=%%s"

        if ["!gpNativeHeight!"] == ["NOT_FOUND"] (
            echo WARNING : Native Height was not found in !rulesFile!
        )

        echo Native height set to !gpNativeHeight! in rules.txt
        echo.
        if not ["!gpNativeHeight!"] == ["NOT_FOUND"] if !gpNativeHeight! NEQ !nativeHeight! (
            echo WARNING : Native Height in rules.txt does not match
        )

        set "extraDirectives="!fnrLogFolder:"=!\extraDirectives.log""
        if exist !extraDirectives! del /F !extraDirectives! > NUL 2>&1
        set "extraDirectives169="!fnrLogFolder:"=!\extraDirectives169.log""

        call:getExtraDirectives > !extraDirectives!

        REM : replacing directives in extraDirectives.log
        set "logFileED="!fnrLogFolder:"=!\fnr_extraDirectives.log""
        if exist !logFileED! del /F !logFileED! > NUL 2>&1

        if exist !extraDirectives! (
            call:set169
            copy /Y !extraDirectives! !extraDirectives169! > NUL 2>&1
        )
        set "ed="
        for /F "delims=~" %%j in ('type !extraDirectives!') do set "ed=!ed!%%j\n"

        if not ["!ed!"] == [""] echo extra directives detected ^: && echo !ed! && echo.

        REM : complete 16/9 (if here => COMPLETE_GP=YES)
        call:createV3Gp169

        REM : reset extra directives file
        if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1
        
        REM : create missing resolution graphic packs
        for %%a in (!ARLIST!) do (

            if ["%%a"] == ["1610"] call:createV3Gp1610

            if ["%%a"] == ["219"]  call:createV3Gp219

            if ["%%a"] == ["43"]   call:createV3Gp43

            if ["%%a"] == ["489"]   call:createV3Gp489

            REM : reset extra directives file
            if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1
        )

        @echo ---------------------------------------------------------
        @echo ^> !gpFolderName:"=!^'s V3 extra presets created successfully

        del /F !extraDirectives! > NUL 2>&1
        del /F !extraDirectives169! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :getExtraDirectives
    REM : get extra directives in rules.txt
    set "first="
    set /A "firstSetFlag=0"

    for /F "delims=~" %%i in ('type !rulesFile! ^| findStr /R "^$[A-Za-z0-9]*" ^| find /I /V "height " ^| find /I /V "width "') do (

        if !firstSetFlag! EQU 0 for /F "tokens=1 delims=~=" %%j in ("%%i") do set "first=%%j"

        if !firstSetFlag! EQU 1 echo %%i | find "!first!" > NUL 2>&1 && goto:eof
        echo %%i
        set /A "firstSetFlag=1"

    )    
    goto:eof
    REM : ------------------------------------------------------------------

    :set169
    REM : force 169 values in case of BatchFw already treated the rules.txt for this game

        REM : 16/9 windowed
        call:updateExtraDirectives "aspectRatio = \(11016.0\/5760.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectY = \(11016.0\/5760.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectY = 1.0"
        call:updateExtraDirectives "GameAspect = \(11016.0\/5760.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 21/9
        call:updateExtraDirectives "aspectRatio = \(13760.0\/5760.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectX = \(13760.0\/5760.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectX = 1.0"
        call:updateExtraDirectives "GameAspect = \(13760.0\/5760.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 21/9 windowed
        call:updateExtraDirectives "aspectRatio = \(14812.0\/5760.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectX = \(14812.0\/5760.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectX = 1.0"
        call:updateExtraDirectives "GameAspect = \(14812.0\/5760.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 4/3
        call:updateExtraDirectives "aspectRatio = \(4.0\/3.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectY = \(4.0\/3.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectY = 1.0"
        call:updateExtraDirectives "GameAspect = \(4.0\/3.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 4/3 windowed
        call:updateExtraDirectives "aspectRatio = \(8266.0\/5760.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectY = \(8266.0\/5760.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectY = 1.0"
        call:updateExtraDirectives "GameAspect = \(8266.0\/5760.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 48/9
        call:updateExtraDirectives "aspectRatio = \(48.0\/9.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectX = \(48.0\/9.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectX = 1.0"
        call:updateExtraDirectives "GameAspect = \(48.0\/9.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 48/9 windowed
        call:updateExtraDirectives "aspectRatio = \(33066.0\/5760.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectX = \(33066.0\/5760.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectX = 1.0"
        call:updateExtraDirectives "GameAspect = \(33066.0\/5760.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 16/10
        call:updateExtraDirectives "aspectRatio = \(16.0\/10.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectX = \(16.0\/10.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectX = 1.0"
        call:updateExtraDirectives "GameAspect = \(16.0\/10.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

        REM : 16/10 windowed
        call:updateExtraDirectives "aspectRatio = \(9920.0\/5760.0\)" "aspectRatio = (16.0/9.0)"
        call:updateExtraDirectives "UIAspectX = \(9920.0\/5760.0\)\/\(!nativeWidth!.0\/!nativeHeight!.0\)" "UIAspectX = 1.0"
        call:updateExtraDirectives "GameAspect = \(9920.0\/5760.0\)" "GameAspect=(!nativeWidtht!/!nativeHeight!)"

    goto:eof
    REM : ------------------------------------------------------------------
    
    :treatGP

        set "gpFolderName=!gpFolderName:_%resX2%p=!"

        REM compute half native resolution
        call:divfloat2int "%nativeHeight%.0" "2.0" 1 halfNativeHeight
        call:divfloat2int "%nativeWidth%.0" "2.0" 1 halfNativeWidth

    goto:eof
    REM : ------------------------------------------------------------------

    REM : The for next method are only used in case of a not supported game in Shlashiee repo (if %gpV3exist% EQU 0)

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
        @echo # add commonly used 16^/9 res filters >> !rulesFileV3!
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

    :waitChildrenProcessesEnd

        REM : waiting all children processes ending
        :waitingLoop
        wmic process get Commandline | find /I "_BatchFW_Install" | find /I /V "wmic" | find /I "fnr.exe" | find /I "_BatchFW_Graphic_Packs" | find /I /V "find" > NUL 2>&1 && (
            timeout /T 1 > NUL 2>&1
            goto:waitingLoop
        )

    goto:eof
    REM : ------------------------------------------------------------------

   :createV2Gp169

        set "gp="%~1""
        set "gpName=!gp:_%resX2%p=!"

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:169_windowedV2
        @echo Create 16^/9 missing V2 resolution packs

        REM : 16/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=640"
        set /A "dw=320"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p""
            if !h! NEQ %nativeHeight% if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
        goto:eof

        :169_windowedV2
        echo !ARLIST! | find /I /V "169" > NUL 2>&1 && goto:eof
        @echo Create 16^/9 windowed missing V2 resolution packs

        REM : 16/9 windowed graphic packs
        set /A "h=360"
        set /A "w=694"
        set /A "dw=344"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p169_windowed""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! " (16:9) windowed" > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :updateExtraDirectives
        set "src="%~1""
        set "target="%~2""

REM echo src=!src!
REM echo target=!target!
REM echo !fnrPath! --cl --dir !fnrLogFolder! --fileMask "extraDirectives.log" --useRegEx --useEscapeChars --find !src! --replace !target!
REM echo.
REM !fnrPath! --cl --dir !fnrLogFolder! --fileMask "extraDirectives.log" --useRegEx --useEscapeChars --find !src!
REM pause
REM echo replacing      
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !fnrLogFolder! --fileMask "extraDirectives.log" --useRegEx --useEscapeChars --find !src! --replace !target! --logFile !logFileED!
REM more !logFileED!
REM pause
        set "edu="
        for /F "delims=~" %%j in ('type !extraDirectives!') do set "edu=!edu!%%j\n"

    goto:eof
    REM : ------------------------------------------------------------------


    :createV3Gp169

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:169_windowed

        @echo Complete 16^/9 presets in V3 GFX resolution pack
        set "edu=!ed!"

        REM : 16/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=640"
        set /A "dw=320"

        for /L %%p in (1,1,31) do (

            if !h! NEQ %nativeHeight% if %gpV3exist% EQU 0 call:fillResV3GP !w! !h! " (16:9)"

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )
        if %gpV3exist% EQU 0 goto:eof

        REM : complete existing 16/9 resolution
        set /A "h=360"
        set /A "w=640"
        set /A "dw=320"

        set /A "downIter=%nativeHeight%/%dh%-2"
        set /A "supIter=%nativeHeight%/%dh%"

        for /L %%p in (1,1,%downIter%) do (

            if %gpV3exist% EQU 1 call:addResoV3GP169 " (16:9)"

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"
        )

        REM : reverse loop
        set /A "h=5760"
        set /A "w=10240"
        set /A "dw=320"
        for /L %%p in (%supIter%,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP169 " (16:9)"

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )

        goto:eof

        REM : create windowed presets only if user chosen it during setup

        :169_windowed
        @echo Create 16^/9 windowed presets in V3 GFX resolution pack

        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (11016.0/5760.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectY[ ]*=[ ]*1.0" "UIAspectY = (11016.0/5760.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (11016.0/5760.0)"
        )

        REM : 16/9 windowed graphic packs
        set /A "h=5760"
        set /A "w=11016"
        set /A "dw=344"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (16:9) windowed"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*344-!w!"
                call:fillResV3GP !iw! !ih! "^(16^:9^) windowed"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :createV2Gp219

        set "gp="%~1""
        set "gpName=!gp:_%resX2%p=!"
        set "description= (21:9)"

        REM : search for resX2p219
        set "gpResX2p_219="!gp:"=!219""
        if exist !gpResX2p_219! (
            set "gp=!gpResX2p_219!"
            set "description="
        )

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:219_windowedV2
        @echo Create 21^/9 missing V2 resolution packs

        REM : 21/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=840"
        set /A "dw=420"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p219""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! %description% > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
        goto:eof

        :219_windowedV2
        REM : 21/9 windowed graphic packs
        @echo Create 21^/9 windowed V2 resolution packs

        set /A "h=360"
        set /A "w=904"
        set /A "dw=452"

        set "description=%description% windowed"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p219_windowed""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! %description% > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :createV3Gp219

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:219_windowed
        @echo Complete 21^/9 presets in V3 GFX resolution pack

        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (13760.0/5760.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectX[ ]*=[ ]*1.0" "UIAspectX = (13760.0/5760.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (13760.0/5760.0)"
        )

        REM : 21/9 fullscreen graphic packs
        set /A "h=5760"
        set /A "w=13760"
        set /A "dw=420"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (21:9)"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*420-!w!"
                call:fillResV3GP !iw! !ih! "^(21^:9^)"
        )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
        goto:eof

        :219_windowed
        @echo Create 21^/9 windowed presets in V3 GFX resolution pack
        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (14812.0/5760.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectX[ ]*=[ ]*1.0" "UIAspectX = (14812.0/5760.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (14812.0/5760.0)"
        )

        REM : 21/9 windowed graphic packs
        set /A "h=5760"
        set /A "w=14812"
        set /A "dw=452"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (21:9) windowed"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*452-!w!"
                call:fillResV3GP !iw! !ih! "^(21^:9^) windowed"
        )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :createV2Gp43

        set "gp="%~1""
        set "gpName=!gp:_%resX2%p=!"
        set "description= (4:3)"

        REM : search for resX2p43
        set "gpResX2p_43="!gp:"=!43""

        if exist !gpResX2p_43! set "gp=!gpResX2p_43!" && set "description=" goto:setdHeight

        REM : if found 219, duplicate 1440p219
        set "gpResX2p_219="!gp:"=!219""
        if exist !gpResX2p_219! (
            robocopy !gpResX2p_219! !gpResX2p_43! /S > NUL 2>&1

            REM : patch patches.txt
            set "fnrLogFile="!fnrLogFolder:"=!\fnr_create43.log""

            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpResX2p_43! --fileMask "rules.txt" --find "21:9" --replace "4:3" --logFile !fnrLogFile!
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpResX2p_43! --fileMask *_*s.txt --find "resXScale = 2.6875" --replace "float resXScale = 2.0" --logFile !fnrLogFile!

            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpResX2p_43! --fileMask patches.txt --find ".float 2.389" --replace ".float 1.333" --logFile !fnrLogFile!

            set "gp=!gpResX2p_43!"
            set "description="
        )

        :setdHeight
        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:43_windowedV2
        @echo Create 4^/3 missing V2 resolution packs

        REM : 4/3 fullscreen graphic packs
        set /A "h=360"
        set /A "w=480"
        set /A "dw=240"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p43""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! %description% > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
        goto:eof

        :43_windowedV2
        REM : 4/3 windowed graphic packs
        @echo Create 4^/3 windowed missing V2 resolution packs
        set /A "h=360"
        set /A "w=516"
        set /A "dw=258"

        set "description=%description% windowed"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p43_windowed""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! %description% > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :createV3Gp43

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:43_windowed
        @echo Complete 4^/3 presets in V3 GFX resolution pack

        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (4.0/3.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectY[ ]*=[ ]*1.0" "UIAspectY = (4.0/3.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (4.0/3.0)"
        )
        REM : 4/3 fullscreen graphic packs
        set /A "h=5760"
        set /A "w=7680"
        set /A "dw=240"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (4:3)"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*540-!w!"
                call:fillResV3GP !iw! !ih! "^(4^:3^)"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
        goto:eof

        :43_windowed
        REM : 4/3 windowed graphic packs
        @echo Create 4^/3 windowed presets in V3 GFX resolution pack
        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (8266.0/5760.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectY[ ]*=[ ]*1.0" "UIAspectY = (8266.0/5760.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (8266.0/5760.0)"
        )

        set /A "h=5760"
        set /A "w=8266"
        set /A "dw=258"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (4:3) windowed"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*582-!w!"
                call:fillResV3GP !iw! !ih! "^(4^:3^) windowed"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :createV2Gp489

        set "gp="%~1""
        set "gpName=!gp:_%resX2%p=!"
        set "description= (48:9)"

        REM : search for resX2p489
        set "gpResX2p_489="!gp:"=!489""
        if exist !gpResX2p_489! (
            set "gp=!gpResX2p_489!"
            set "description="
        )

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:489_windowedV2
        @echo Create 48^/9 missing V2 resolution packs

        REM : 48/9 fullscreen graphic packs
        set /A "h=360"
        set /A "w=1920"
        set /A "dw=960"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p489""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! %description% > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
        goto:eof

        :489_windowedV2
        REM : 48/9 windowed graphic packs
        @echo Create 48^/9 windowed missing V2 resolution packs
        set /A "h=360"
        set /A "w=2066"
        set /A "dw=1032"

        set "description=%description% windowed"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p489_windowed""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! %description% > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :createV3Gp489

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:489_windowed
        @echo Complete 48^/9 presets in V3 GFX resolution pack

        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (48.0/9.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectX[ ]*=[ ]*1.0" "UIAspectX = (48.0/9.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (48.0/9.0)"
        )

        REM : 48/9 fullscreen graphic packs
        set /A "h=5760"
        set /A "w=30720"
        set /A "dw=960"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (48:9)"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*960-!w!"
                call:fillResV3GP !iw! !ih! "^(48^:9^)"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
        goto:eof

        :489_windowed
        REM : 49/9 windowed graphic packs
        @echo Create 48^/9 windowed presets in V3 GFX resolution pack
        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (33066.0/5760.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectX[ ]*=[ ]*1.0" "UIAspectX = (33066.0/5760.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (33066.0/5760.0)"
        )

        set /A "h=5760"
        set /A "w=33066"
        set /A "dw=1032"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " 48:9) windowed"
                      if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*1034-!w!"
                call:fillResV3GP !iw! !ih! "^(48^:9^) windowed"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
    goto:eof
    REM : ------------------------------------------------------------------


    :createV2Gp1610

        set "gp="%~1""
        set "gpName=!gp:_%resX2%p=!"

        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:1610_windowedV2
        @echo Create 16^/10 missing V2 resolution packs

        REM : 16/10 full screen graphic packs
        set /A "h=360"
        set /A "w=576"
        set /A "dw=288"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p1610""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! " (16:10)" > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )
        goto:eof

        :1610_windowedV2
        REM : 16/10 windowed graphic packs
        @echo Create 16^/10 windowed missing V2 resolution packs
        set /A "h=360"
        set /A "w=620"
        set /A "dw=310"

        for /L %%p in (1,1,31) do (

            set "newGp="!gpName:"=!_!h!p1610_windowed""
            if not exist !newGp! wscript /nologo !StartHidden! !instanciateResX2gp! %nativeWidth% %nativeHeight% !gp! !newGp! !w! !h! " (16:10) windowed" > NUL 2>&1

            set /A "h=!h!+%dh%"
            set /A "w=!w!+%dw%"

            set /A "mod4=%%p%%4"
            if !mod4! EQU 0 call:waitChildrenProcessesEnd
        )


    goto:eof
    REM : ------------------------------------------------------------------

    :createV3Gp1610


        REM : height step
        set /A "dh=180"

        if not ["%screenMode%"] == ["fullscreen"] goto:1610_windowed
        @echo Create 16^/10 presets in V3 GFX resolution pack
        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (16.0/10.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectY[ ]*=[ ]*1.0" "UIAspectY = (16.0/10.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (16.0/10.0)"
        )

        REM : 16/10 full screen graphic packs
        set /A "h=5760"
        set /A "w=9216"
        set /A "dw=288"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (16:10)"
                      if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*288-!w!"
                call:fillResV3GP !iw! !ih! "^(16^:10^)"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )
        goto:eof

        :1610_windowed
        REM : 16/10 windowed graphic packs
        @echo Create 16^/10 windowed presets in V3 GFX resolution pack
        set "edu=!ed!"
        if not ["!ed!"] == [""] (

            call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (9920.0/5760.0)"

            REM Handle : ratio > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            call:updateExtraDirectives "UIAspectY[ ]*=[ ]*1.0" "UIAspectY = (9920.0/5760.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (9920.0/5760.0)"
        )

        set /A "h=5760"
        set /A "w=9920"
        set /A "dw=310"

        for /L %%p in (1,1,31) do (

            if %gpV3exist% EQU 1 call:addResoV3GP " (16:10) windowed"
            if %gpV3exist% EQU 0 (
                set /A "ih=34*180-!h!"
                set /A "iw=34*310-!w!"
                call:fillResV3GP !iw! !ih! "^(16^:10^) windowed"
            )

            set /A "h=!h!-%dh%"
            set /A "w=!w!-%dw%"
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : add a resolution bloc BEFORE the native one in rules.txt
    :pushFront

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*.*\n\$width[ ]*=[ ]*!nativeWidth![ ]*\n\$height[ ]*=[ ]*!nativeHeight!" --replace "[Preset]\nname = !w!x!h!!desc:"=!\n$width = !w!\n$height = !h!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%\n\n[Preset]\nname = !nativeWidth!x!nativeHeight! (16:9 Default)\n$width = !nativeWidth!\n$height = !nativeHeight!" --logFile !logFileV3!

        if not ["!edu!"] == [""] wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^\$width = !w!\n\$height = !h!\n\$gameWidth = %nativeWidth%\n\$gameHeight = %nativeHeight%" --replace "$width = !w!\n$height = !h!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%\n!edu!" --logFile !logFileV3!
    goto:eof
    REM : ------------------------------------------------------------------


    REM : add a resolution bloc AFTER the native one in rules.txt
    :pushBack

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*.*\n\$width[ ]*=[ ]*!nativeWidth![ ]*\n\$height[ ]*=[ ]*!nativeHeight![ ]*\n\$gameWidth[ ]*=[ ]*%nativeWidth%[ ]*\n\$gameHeight[ ]*=[ ]*%nativeHeight%" --replace "[Preset]\nname = !nativeWidth!x!nativeHeight!  (16:9 Default)\n$width = !nativeWidth!\n$height = !nativeHeight!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%\n\n[Preset]\nname = !w!x!h!!desc:"=!\n$width = !w!\n$height = !h!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%" --logFile !logFileV3!

        if not ["!edu!"] == [""] wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^\$width = !nativeWidth!\n\$height = !nativeHeight!\n\$gameWidth = %nativeWidth%\n\$gameHeight = %nativeHeight%" --replace "$width = !nativeWidth!\n$height = !nativeHeight!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%\n!edu!" --logFile !logFileV3!

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to add an extra 16/9 preset in V3 graphic pack of the game
    :addResoV3GP169

        set "desc="%~1""

        REM : search for "$width = !w!\n$height = !h!" in rulesFile: if found exit
        set "fnrLogAddResoV3GP169="!fnrLogFolder:"=!\addResoV3GP169_!w!x!h!.log""
        if exist !fnrLogAddResoV3GP169! del /F !fnrLogAddResoV3GP169! > NUL 2>&1
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^\$width[ ]*=[ ]*!w![ ]*\n\$height[ ]*=[ ]*!h![ ]*" --logFile !fnrLogAddResoV3GP169!
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogAddResoV3GP169! ^| find /I /V "^!" ^| find "File:"') do (
            @echo Preset !w!x!h! already exists
            goto:eof
        )
REM @echo Adding !w!x!h!!desc:"=! preset

        REM : replacing %wToReplace%xresX2 in rules.txt
        set "logFileV3="!fnrLogFolder:"=!\!gpFolderName:"=!-V3_!h!x!w!.log""
        if exist !logFileV3! del /F !logFileV3! > NUL 2>&1

        if !h! GTR !nativeHeight! call:pushBack
        if !h! LSS !nativeHeight! call:pushFront

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to add an extra preset in V3 graphic pack of the game
    :addResoV3GP
        set "desc="%~1""

        REM : search for "$width = !w!\n$height = !h!" in rulesFile: if found exit

        set "fnrLogAddResoV3GP="!fnrLogFolder:"=!\addResoV3GP_!w!x!h!.log""
        if exist !fnrLogAddResoV3GP! del /F !fnrLogAddResoV3GP! > NUL 2>&1
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^\$width[ ]*=[ ]*!w![ ]*\n\$height[ ]*=[ ]*!h![ ]*" --logFile !fnrLogAddResoV3GP!

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogAddResoV3GP! ^| find /I /V "^!" ^| find "File:"') do (
            @echo Preset !w!x!h!!desc:"=! already exists
            goto:eof
        )

REM @echo Adding !w!x!h!!desc:"=! preset

        REM : Adding !h!x!w! in rules.txt
        set "logFileV3="!fnrLogFolder:"=!\!gpFolderName:"=!-V3_!h!x!w!.log""
        if exist !logFileV3! del /F !logFileV3! > NUL 2>&1

        if not ["!edu!"] == [""] (

            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = 3[ ]*" --replace "version = 3\n\n[Preset]\nname = !w!x!h!!desc:"=!\n$width = !w!\n$height = !h!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%\n!edu!" --logFile !logFileV3!
            goto:eof
        )

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = 3[ ]*" --replace "version = 3\n\n[Preset]\nname = !w!x!h!!desc:"=!\n$width = !w!\n$height = !h!\n$gameWidth = %nativeWidth%\n$gameHeight = %nativeHeight%" --logFile !logFileV3!

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
            if %QUIET_MODE% EQU 0 pause
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals
            if %QUIET_MODE% EQU 0 pause
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

    goto:eof
    REM : ------------------------------------------------------------------

    :strLen
        set /A "len=0"
        :strLen_Loop
           if not ["!%1:~%len%!"] == [""] set /A len+=1 & goto:strLen_Loop
            set %2=%len%
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function for multiplying integers
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

            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals

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
