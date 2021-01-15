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

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "cgpLogFile="!BFW_PATH:"=!\logs\createExtraGraphicPacks.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "instanciateResX2gp="!BFW_TOOLS_PATH:"=!\instanciateResX2gp.bat""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

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
    set "startingDate=%ldt%"
    REM : starting DATE

    echo starting date = %startingDate% >> !cgpLogFile!
    echo starting date = %startingDate%

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if exist !BFW_GP_FOLDER! (
        goto:getTitleId
    )
    echo Please select a reference graphicPacks folder

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
    set "titleId=%titleId%"

    REM : get gfxType version to create
    echo.
    echo Which version of pack to you wish to create ^?
    echo.
    echo     - 2 ^: CEMU ^< 1^.14
    echo     - 4 ^: 1^.14 ^< CEMU ^< 1^.21
    echo     - 6 ^: 1^.21 ^< CEMU
    echo.
    choice /C 246 /T 15 /D 6 /N /M "Enter your choice ? : "
    set "gfxType=V!ERRORLEVEL!"

    goto:inputsAvailables

    REM : titleID and BFW_GP_FOLDER
    :getArgsValue

    echo. > !cgpLogFile!
    if %nbArgs% GTR 5 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER gfxType TITLE_ID RULES_FILE NAME^* >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER gfxType TITLE_ID RULES_FILE NAME^*
        echo given {%*}

        exit /b 99
    )
    if %nbArgs% LSS 4 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER gfxType TITLE_ID RULES_FILE NAME^* >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER gfxType TITLE_ID RULES_FILE NAME^*
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
    REM : get gfxType
    set "gfxType=!args[1]!"
    set "gfxType=!gfxType:"=!"

    REM : get titleId
    set "titleId=!args[2]!"

    set "rulesFile=!args[3]!"

    if %nbArgs% EQU 5 (
        set "str=!args[4]!"
        set "gameName=!str:"=!"
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"
    REM : BatchFw V2 gfx pack folder
    set "BFW_GPV2_FOLDER="!BFW_GP_FOLDER:"=!\_graphicPacksV2""

    REM : GFX version to set if creating/completing own GFX packs
    set "setup="!BFW_PATH:"=!\setup.bat""
    set "lastVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION" 2^>NUL') do set "lastVersion=%%i"
    set "lastVersion=!lastVersion:"=!"

    set "titleId=!titleId:"=!"

    REM : fix for incomplete titleId
    call:strLength !titleId! length
    if !length! EQU 13 set "titleId=000!titleId!"

    REM : check if game is recognized
    call:checkValidity !titleId!

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine

    if !QUIET_MODE! EQU 1 (
        cscript /nologo !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
        exit /b 3
    )
    echo createExtraGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^? >> !cgpLogFile!
    echo createExtraGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^?
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

    if !nativeHeight! EQU 720 set /A "nativeWidth=1280"
    if !nativeHeight! EQU 1080 set /A "nativeWidth=1920"

    if not ["%gameName%"] == ["NONE"] set "GAME_TITLE=%gameName%"

    echo ========================================================= >> !cgpLogFile!
    echo =========================================================
    echo Create !gfxType! extra graphic packs ^(missing resolutions^) for !GAME_TITLE! >> !cgpLogFile!
    echo Create !gfxType! extra graphic packs ^(missing resolutions^) for !GAME_TITLE!
    echo ========================================================= >> !cgpLogFile!
    echo =========================================================
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv  >> !cgpLogFile!
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv

    REM get all title Id for this game (in case of a new res gp creation)
    set "titleIdList=%titleId%"
    call:getAllTitleIds

    REM : SCREEN_MODE
    set "screenMode=fullscreen"
    set "aspectRatiosList="
    set "aspectRatiosArray="
    set "descArray="
    set /A "nbAr=0"

    REM : search in all Host_*.log
    set "pat="!BFW_PATH:"=!\logs\Host_*.log""

    for /F "delims=~" %%i in ('dir /S /B !pat! 2^>NUL') do (
        set "currentLogFile="%%i""

        REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
        for /F "tokens=2-3 delims=~=" %%j in ('type !currentLogFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (

            echo !aspectRatiosList! | find /I /V "%%j" > NUL 2>&1 && (
                set "aspectRatiosArray[!nbAr!]=%%j"
                set "descArray[!nbAr!]=%%k"
                set /A "nbAr+=1"
                set "aspectRatiosList=!aspectRatiosList! %%j"
            )
        )
        REM : get the SCREEN_MODE
        for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%j"
    )


    if !nbAr! EQU 0 (
        echo Unable to get desired aspect ratio ^(choosen during setup^) ^? >> !cgpLogFile!
        echo Unable to get desired aspect ratio ^(choosen during setup^) ^?
        echo Delete batchFW outputs and relaunch >> !cgpLogFile!
        echo Delete batchFW outputs and relaunch
        if !QUIET_MODE! EQU 0 pause
        exit /b 2
    ) else (
        set /A "nbAr-=1"
    )

    REM : double of the native height of the game
    set /A "resX2=!nativeHeight!*2"

    REM : flag for graphic packs existence
    set /A "newGpExist=0"

    REM : updateGameGraphicPacks.bat send rulesFile for GFX packs version > 2 if found
    REM : v2 only if no latest found
    REM : If no gfx pack were found updateGameGraphicPacks.bat call createGameGraphicPacks.bat instead
    REM : of this script

    set "rulesFolder=!rulesFile:\rules.txt=!"

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!rulesFolder!) do set "gpNameFolder=%%~nxi"

    REM : Get the version of the GFX pack
    set "vGfxPackStr=NOT_FOUND"
    for /F "delims=~= tokens=2" %%i in ('type !rulesFile! ^| find /I "Version"') do set "vGfxPackStr=%%i"
    set "vGfxPackStr=%vGfxPackStr: =%"
    if ["!vGfxPackStr!"] == ["NOT_FOUND"] (
        echo ERROR : version was not found in !rulesFile! >> !cgpLogFile!
        echo ERROR : version was not found in !rulesFile!
        goto:eof
    )
    set /A "vGfxPack=!vGfxPackStr!"

    set "gpNativeHeight=NOT_FOUND"

    REM : is NO new gfx pack was found => rulesFile contain _graphicPackV2
    if !vGfxPack! EQU 2 (

        REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
        type !rulesFile! | find /I "height = !resX2!" > NUL 2>&1 && (
            set "gpNativeHeight=!nativeHeight!"
        )

        echo !rulesFile! | find /I /V "!resX2!p" > NUL 2>&1 && (
            echo WARNING : graphic pack folder name does not match 2 x native Height >> !cgpLogFile!
            echo WARNING : graphic pack folder name does not match 2 x native Height
        )

        goto:treatGfxPacks
    )

    REM : a new GFX pack was found
    set /A "newGpExist=1"

    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    set "gpNativeHeight=NOT_FOUND"

    if !vGfxPack! LSS 6 (
        for /F "tokens=4 delims=x " %%s in ('type !rulesFile! ^| find /I "name" ^| find /I "Default" 2^>NUL') do set "gpNativeHeight=%%s"
    ) else (
        for /F "tokens=2 delims=~=" %%s in ('type !rulesFile! ^| findstr /R "^$gameHeight.*=" 2^>NUL') do set "gpNativeHeight=%%s"
    )
    set "gpNativeHeight=!gpNativeHeight: =!"

    if ["!gpNativeHeight!"] == ["NOT_FOUND"] for /F "tokens=4 delims=x " %%s in ('type !rulesFile! ^| find /I "name" ^| find /I "Native" 2^>NUL') do set "gpNativeHeight=%%s"

    :treatGfxPacks
    if !newGpExist! EQU 0 goto:createNew

    if ["!gpNativeHeight!"] == ["NOT_FOUND"] (
        echo WARNING : native height was not found in !rulesFile! >> !cgpLogFile!
        echo WARNING : native height was not found in !rulesFile!
    )

    echo Native height set to !gpNativeHeight! in rules.txt >> !cgpLogFile!
    echo Native height set to !gpNativeHeight! in rules.txt
    echo. >> !cgpLogFile!
    echo.
    REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
    if not ["!gpNativeHeight!"] == ["NOT_FOUND"] if !gpNativeHeight! NEQ !nativeHeight! (
        echo WARNING : native height in rules.txt does not match >> !cgpLogFile!
        echo WARNING : native height in rules.txt does not match
    )

    call:completeGfxPacks !gpNameFolder!

    if !newGpExist! EQU 1 goto:ending

    :createNew
    REM : create res graphic pack : when a V4 version is missing and a V2 pack was found => instanciate resx2 pack

    REM : get the path of an old existing packs
    set "newGpNameFolder=!gpNameFolder:_graphicPacksV2\=!"
    set "newGpNameFolder=!gpNameFolder:_graphicPacksV4\=!"

    REM : get the folder name from a V2 pack
    set "newGpName=!gpNameFolder:_%resX2%p=!"

    set "newGpLastVersion="!BFW_GP_FOLDER:"=!\!newGpName:"=!\Graphics""

    REM : V4 packs are created in _graphicPacksV4
    if ["!gfxType!"] == ["V4"] set "newGpLastVersion="!BFW_GP_FOLDER:"=!\_graphicPacksV4\!newGpName:"=!_Resolution""

    if not exist !newGpLastVersion! mkdir !newGpLastVersion! > NUL 2>&1

    set "bfwRulesFile="!newGpLastVersion:"=!\\rules.txt""

    echo Creating V!lastVersion! pack for !newGpName! ^: !bfwRulesFile!

    call:initResGraphicPack
    call:completeGfxPacks !newGpNameFolder!
    call:finalizeResGraphicPack

    set "gpResX2=!rulesFolder!"
    REM : for resX2p no patches.txt file, init to NOT_FOUND
    set "patchValue=NOT_FOUND"

    REM : search for ResX2p489
    set "gpResX2p="!gpResX2:"=!489""
    if exist !gpResX2p! set "patchValue=5.333"

    if not exist !gpResX2p! (
        REM : try ResX2p219
        set "gpResX2p="!gpResX2:"=!219""
        set "patchValue=2.370"
    )

    if exist !gpResX2p! (
        set "gpResX2=!gpResX2p!"
    )

    REM : copy files near the rules.txt files
    robocopy !gpResX2! !newGpLastVersion! /S /XF rules.txt

    REM : replacing float Scale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_newGp-resXScale.log""
    echo !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)"  >> !cgpLogFile!
    echo !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)"
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)" --logFile !fnrLogFile!

    set "fnrLogFile="!fnrLogFolder:"=!\fnr_newGp-resYScale.log""
    echo !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)" >> !cgpLogFile!
    echo !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)"
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)" --logFile !fnrLogFile

    set "fnrLogFile="!fnrLogFolder:"=!\fnr_newGp-resScale.log""
    echo !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)" >> !cgpLogFile!
    echo !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)"
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !newGpLastVersion! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)" --logFile !fnrLogFile!


    set "patchFile="!newGpLastVersion:"=!\patches.txt""

    if not exist !patchFile! goto:ending

    REM : replace scale factor in patchFile
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !newGpLastVersion! --fileMask patches.txt --find !patchValue! --replace "$width/$height" --logFile !fnrLogFile!

    :ending

    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    REM : force UTF8 format
    set "utf8="!rulesFolder:"=!\rules.bfw_tmp""
    copy /Y !rulesFile! !utf8! > NUL 2>&1
    type !utf8! > !rulesFile!
    del /F !utf8! > NUL 2>&1


    echo =========================================================  >> !cgpLogFile!
    echo =========================================================

    if exist !BFW_GPV2_FOLDER! call:waitChildrenProcessesEnd
    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "endingDate=%ldt%"
    REM : starting DATE

    echo starting date = %startingDate% >> !cgpLogFile!
    echo starting date = %startingDate%
    echo ending date = %endingDate% >> !cgpLogFile!
    echo ending date = %endingDate%


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

    :getAllTitleIds

        REM now searching using icoId
        for /F "delims=~; tokens=1" %%i in ('type !wiiTitlesDataBase! ^| find /I ";%icoId%;"') do (
            set "titleIdRead=%%i"
            set "titleIdRead=!titleIdRead:'=!"
            echo !titleIdList! | find /V "!titleIdRead!" > NUL 2>&1 && (
                set "titleIdList=!titleIdList!^,!titleIdRead!"
            )
        )

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


    REM : function to create extra graphic packs for a game
    :completeGfxPacks

        set "gpFolderName="%~1""
        set "gpResX2="
        set /A "showEdFlag=0"

        REM : add a flag for aspect ratios presets (BOTW)
        set /A "existAspectRatioPreset=0"

        if !vGfxPack! NEQ 2 (
            if !vGfxPack! LSS 6 (
                set "extraDirectives="!fnrLogFolder:"=!\extraDirectives.log""
                if exist !extraDirectives! del /F !extraDirectives! > NUL 2>&1
                set "extraDirectives169="!fnrLogFolder:"=!\extraDirectives169.log""

                REM : here the rules.txt is stock (extraDirectives are 16/9 ones)
                call:getExtraDirectives > !extraDirectives!
                copy /Y !extraDirectives! !extraDirectives169! > NUL 2>&1

                REM : replacing directives in extraDirectives.log
                set "logFileED="!fnrLogFolder:"=!\fnr_extraDirectives.log""
                if exist !logFileED! del /F !logFileED! > NUL 2>&1
            ) else (
                REM : check if aspect ratio presets exist
                type !rulesFile! | find "$aspectRatioWidth" > NUL 2>&1 && (
                    set /A "existAspectRatioPreset=1"
                )
            )
        )
        REM : reset extra directives file
        if !vGfxPack! NEQ 2 if !vGfxPack! LSS 6 if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1

        REM : create missing resolution graphic packs
        for /L %%a in (0,1,!nbAr!) do (

            call:createMissingRes "!aspectRatiosArray[%%a]!" "!descArray[%%a]!"
            if not ["!screenMode!"] == ["fullscreen"] (
                REM : add windowed ratio for 16-9
                if ["!aspectRatiosArray[%%a]!"] == ["16-9"] call:createMissingRes "401-210" "16/9 windowed"
                REM : add windowed ratio for 16-10
                if ["!aspectRatiosArray[%%a]!"] == ["16-10"] call:createMissingRes "361-210" "16/10 windowed"
                REM : add windowed ratio for 683-384
                if ["!aspectRatiosArray[%%a]!"] == ["683-384"] call:createMissingRes "377-192" "16/9 laptop windowed"
            )
            REM : reset extra directives file
            if !vGfxPack! NEQ 2 if !vGfxPack! LSS 6 if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1
        )

        if !vGfxPack! NEQ 2 if !vGfxPack! LSS 6 del /F !extraDirectives! > NUL 2>&1

        REM : remove extra directives left alone in the file (in case of multiple default preset defined)
        if not ["!ed!"] == [""] (
            set "fnrLogFile="!fnrLogFolder:"=!\fnr_secureRulesFile.log""
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "#.*\n\n\n!ed:$=\$!" --replace "\n" --logFile !fnrLogFile!
        )

        if !vGfxPack! NEQ 2 if !vGfxPack! LSS 6 del /F !extraDirectives169! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix_extra.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

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

    REM : The for next method are only used in case of a not supported game in Shlashiee repo (if %newGpExist% EQU 0)

    :initResGraphicPack

        echo [Definition] > !bfwRulesFile!
        echo titleIds = !titleIdList! >> !bfwRulesFile!

        echo name = Resolution >> !bfwRulesFile!
        echo path = "!GAME_TITLE!/Graphics/Resolution" >> !bfwRulesFile!
        if !nativeHeight! EQU 720 (
            echo description = Created by BatchFw considering that the native resolution is 720p^. Check Debug^/View texture cache info in CEMU ^: 1280x720 must be overrided ^. If it is not^, change the native resolution to 1080p in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        ) else (
            echo description = Created by BatchFw considering that the native resolution is 1080p. Check Debug^/View texture cache info in CEMU ^: 1920x1080 must be overrided ^. If it is not^, change the native resolution to 720p in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        )
        REM if !nativeHeight! EQU 720 (
            REM echo description = Created by BatchFw considering that the native resolution is 720p^. ^
REM Check Debug^/View texture cache info in CEMU ^: 1280x720 must be overrided ^. ^
REM If it is not^, change the native resolution to 1080p in ^
REM _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        REM ) else (
            REM echo description = Created by BatchFw considering that the native resolution is 1080p. ^
REM Check Debug^/View texture cache info in CEMU ^: 1920x1080 must be overrided ^. ^
REM If it is not^, change the native resolution to 720p in ^
REM _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        REM )
        set /A "gfxVersion=!gfxType:V=!"
        echo version = !gfxVersion! >> !bfwRulesFile!
        echo. >> !bfwRulesFile!

        if !gfxVersion! GEQ 6 (
            echo. >> !bfwRulesFile!
            echo [Default] >> !bfwRulesFile!
            echo $width = !nativeWidth! >> !bfwRulesFile!
            echo $height = !nativeHeight! >> !bfwRulesFile!
            echo $gameWidth = !nativeWidth! >> !bfwRulesFile!
            echo $gameHeight = !nativeHeight! >> !bfwRulesFile!
            echo. >> !bfwRulesFile!
        )
        echo. >> !bfwRulesFile!
        echo # TV Resolution >> !bfwRulesFile!
        echo. >> !bfwRulesFile!
    goto:eof
    REM : ------------------------------------------------------------------

    :fillResGraphicPack
        set "overwriteWidth=%~1"
        set "overwriteHeight=%~2"

        echo [Preset] >> !bfwRulesFile!
        echo name = %overwriteWidth%x%overwriteHeight% %~3 >> !bfwRulesFile!

        set /A "gfxVersion=!gfxType:V=!"
        if !gfxVersion! GEQ 6 (
            echo category = TV Resolution >> !bfwRulesFile!
        )

        echo $width = %overwriteWidth% >> !bfwRulesFile!
        echo $height = %overwriteHeight% >> !bfwRulesFile!

        if !gfxVersion! LEQ 4 (
            echo $gameWidth = !nativeWidth! >> !bfwRulesFile!
            echo $gameHeight = !nativeHeight! >> !bfwRulesFile!
        )
        echo. >> !bfwRulesFile!

    goto:eof
    REM : ------------------------------------------------------------------

    :finalizeResGraphicPack


        REM : res ratios instructions ------------------------------------------------------
        set /A "resRatio=1"

        REM : loop to create res res/2 res/3 .... res/8
        :beginLoopRes

        set /A "r=!nativeHeight!%%!resRatio!"
        REM : check if result is an integer
        if !r! NEQ 0 set /A "resRatio+=1" & goto:beginLoopRes

        REM : compute targetHeight
        set /A "targetHeight=!nativeHeight!/!resRatio!"

        REM : compute targetWidth
        set /A "targetWidth=!nativeWidth!/!resRatio!"

        REM 1^/%resRatio% res : %targetWidth%x%targetHeight%
        call:writeRoundedFilters >> !bfwRulesFile!

        if !targetHeight! LEQ 8 goto:addFilters
        if !resRatio! GEQ 12 goto:addFilters
        set /A "resRatio+=1"
        goto:beginLoopRes

        :addFilters

        REM : add commonly used 16/9 res filters
        echo # add commonly used 16^/9 res filters >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        if !nativeHeight! EQU 720 (
            REM : (1080/2 = 540, for 1080 treated when resRatio = 2)

            echo # 960 x 540 Res >> !bfwRulesFile!
            echo [TextureRedefine] >> !bfwRulesFile!
            echo width = 960 >> !bfwRulesFile!
            echo height = 540 >> !bfwRulesFile!
            echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
            echo formatsExcluded = 0x431 >> !bfwRulesFile!
            echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !bfwRulesFile!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* 540 >> !bfwRulesFile!
            echo #  >> !bfwRulesFile!

            echo # 960 x 544 Res >> !bfwRulesFile!
            echo [TextureRedefine] >> !bfwRulesFile!
            echo width = 960 >> !bfwRulesFile!
            echo height = 544 >> !bfwRulesFile!
            echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
            echo formatsExcluded = 0x431 >> !bfwRulesFile!
            echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !bfwRulesFile!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* 544 >> !bfwRulesFile!
            echo #  >> !bfwRulesFile!
        )

        echo # 1137 x 640 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 1137 >> !bfwRulesFile!
        echo height = 640 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 1137 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 1152 x 640 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 1152 >> !bfwRulesFile!
        echo height = 640 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 1152 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 896 x 504 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 896 >> !bfwRulesFile!
        echo height = 504 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 896 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 504 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 768 x 432 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 768 >> !bfwRulesFile!
        echo height = 432 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 768 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 432 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 512 x 288 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 512 >> !bfwRulesFile!
        echo height = 288 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 512 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 288 >> !bfwRulesFile!

        REM : force UTF8 format
        set "utf8=!bfwRulesFile:rules.txt=rules.bfw_tmp!"
        copy /Y !bfwRulesFile! !utf8! > NUL 2>&1
        type !utf8! > !bfwRulesFile!
        del /F !utf8! > NUL 2>&1

        REM : Linux formating (CRLF -> LF)
        call:dosToUnix

    goto:eof
    REM : ------------------------------------------------------------------

    :writeRoundedFilters

        REM : loop on -8,-4,0,4,12 (rounded values)
        set /A "rh=0"
        for /L %%i in (-8,4,12) do (

            echo # 1/!resRatio! Res rounded at %%i
            echo [TextureRedefine]
            echo width = !targetWidth!

            set /A "rh=!targetHeight!+%%i"
            echo height = !rh!
            echo tileModesExcluded = 0x001 # For Video Playback
            echo formatsExcluded = 0x431
            echo overwriteWidth = ^($width^/$gameWidth^) ^* !targetWidth!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* !rh!
            echo.
        )
        echo.

    goto:eof
    REM : ------------------------------------------------------------------

    :waitChildrenProcessesEnd

        REM : waiting all children processes ending
        :waitingLoop
        wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "instanciateResX2gp" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
            timeout /T 1 > NUL 2>&1
            goto:waitingLoop
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :addResolution

        set "hc=!hi!"
        set "wc=!wi!"

        REM : fullscreen resolutions
        if !hi! EQU !nativeHeight! if !wi! EQU !nativeWidth! goto:eof
        if !n5Found! EQU 1 call:addPresets & goto:eof

        call:addCustomPresets

    goto:eof
    REM : ------------------------------------------------------------------


    :setPresets

        set "ratio= (!wr!/!hr!)"
        set "desc= !ratio:"=!"

        REM : define resolution range with height, length=25
        set "hList=480 540 720 840 900 1080 1200 1320 1440 1560 1680 1800 2040 2160 2400 2640 2880 3240 3600 3960 4320 4440 4920 5400 5880"
        REM : customize for */10 ratios, length=25
        if ["!hr!"] == ["10"] set "hList=400 600 800 900 950 1050 1200 1350 1500 1600 1800 1950 2250 2400 2550 2700 3000 3200 3600 3900 4200 4500 4950 5400 5850"

        set /A "nbH=0"
        for %%i in (%hList%) do set "hArray[!nbH!]=%%i" && set /A "nbH+=1"

        set /A "hMin=%hArray[0]%"
        REM : compute wMin
        set /A "wMin=!hMin!*!wr!"
        set /A "wMin=!wMin!/!hr!"

        set /A "isOdd=!wMin!%%2"
        if !isOdd! EQU 1 set /A "wMin+=1"

        set /A "hMax=%hArray[24]%"
        REM : compute wMax
        set /A "wMax=!hMax!*!wr!"
        set /A "wMax=!wMax!/!hr!"

        set /A "isOdd=!wMax!%%2"
        if !isOdd! EQU 1 set /A "wMax+=1"

        REM : in order to inser the preset sorted in the rules.txt file
        REM : first check if the 1080 or (1050 for aspect ratio */10) preset already exist
        REM : this prest if at the rank 6 (5 starting from 0) in the array

        set /A "h5=!hArray[5]!"
        REM : compute w5
        set /A "w5=!h5!*!wr!"
        set /A "w5=!w5!/!hr!"

        set /A "isOdd=!w5!%%2"
        if !isOdd! EQU 1 set /A "w5+=1"

        set /A "n5Found=0"

        set "logFileFindPreset="!fnrLogFolder:"=!\!gpFolderName:"=!-Find_!h5!x!w5!.log""
        del /F !logFileFindPreset! > NUL 2>&1

        if !vGfxPack! LSS 6 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ 0-9A-Z-:/\(\)]*\n\$width[ ]*=[ ]*!w5!.*\n\$height[ ]*=[ ]*!h5!.*\n\$gameWidth[ ]*=[ ]*!nativeWidth!.*\n\$gameHeight[ ]*=[ ]*!nativeHeight!\n" --logFile !logFileFindPreset!
        ) else (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt"  --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!w5!x!h5!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\n" --logFile !logFileFindPreset!
        )
        for /F "tokens=2-3 delims=." %%i in ('type !logFileFindPreset! ^| find /I /V "^!" ^| find "File:" 2^>NUL') do set /A "n5Found=1"

        if !n5Found! EQU 1 (

            REM :   - loop from (4,-1,0)
            set /A "previousH=!h5!"
            set /A "previousW=!w5!"

            for /L %%i in (4,-1,0) do (
                set /A "hi=!hArray[%%i]!"

                REM : compute wi
                set /A "wi=!hi!*!wr!"
                set /A "wi=!wi!/!hr!"

                set /A "isOdd=!wi!%%2"
                if !isOdd! EQU 1 set /A "wi+=1"

                call:addResolution
                set /A "previousH=!hi!"
                set /A "previousW=!wi!"
            )

            set /A "previousH=!h5!"
            set /A "previousW=!w5!"

            REM :   - loop from (6,1,24)
            for /L %%i in (6,1,24) do (
                set /A "hi=!hArray[%%i]!"

                REM : compute wi
                set /A "wi=!hi!*!wr!"
                set /A "wi=!wi!/!hr!"

                set /A "isOdd=!wi!%%2"
                if !isOdd! EQU 1 set /A "wi+=1"

                call:addResolution
                set /A "previousH=!hi!"
                set /A "previousW=!wi!"
            )
            goto:eof
        )

        set /A "previousH=!hMax!"
        set /A "previousW=!wMax!"

        REM :   - loop from (24,-1,0)
        for /L %%i in (24,-1,0) do (
            set /A "hi=!hArray[%%i]!"

            REM : compute wi
            set /A "wi=!hi!*!wr!"
            set /A "wi=!wi!/!hr!"

            set /A "isOdd=!wi!%%2"
            if !isOdd! EQU 1 set /A "wi+=1"

            call:addResolution
            set /A "previousH=!hi!"
            set /A "previousW=!wi!"
        )

      goto:eof
    REM : ------------------------------------------------------------------


    :createMissingRes

        REM : ratioPassed, ex 16-9
        set "ratioPassed=%~1"
        REM : description
        set "description="%~2""

        REM : if V2 packs call
        if !vGfxPack! EQU 2 set "comment= V2"

        echo ---------------------------------------------------------  >> !cgpLogFile!
        echo ---------------------------------------------------------
        echo Create !ratioPassed:-=/! missing!comment! resolution packs >> !cgpLogFile!
        echo Create !ratioPassed:-=/! missing!comment! resolution packs
        echo ---------------------------------------------------------  >> !cgpLogFile!
        echo ---------------------------------------------------------

        REM : compute Width and Height using ratioPassed
        for /F "delims=- tokens=1-2" %%a in ("!ratioPassed!") do set "wr=%%a" & set "hr=%%b"

        set "aspectRatioWidth=!wr!"
        set "aspectRatioHeight=!hr!"
        REM  : if a aspect ratio preset exists (push back one)
        if !existAspectRatioPreset! EQU 1 (
            if not ["!ratioPassed: =!"] == ["16-9"] (
                set "logFileAr="!fnrLogFolder:"=!\!gpFolderName:"=!-!ratioPassed!.log""
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "[[]Preset[]].*\nname[ ]*=[ ]*16:9.*\ncategory[ ]*=[ ]*Aspect[ ]*Ratio" --replace "[Preset]\nname = 16:9 (Default)\ncategory = Aspect Ratio\n\n[Preset]\nname = !aspectRatioWidth!:!aspectRatioHeight!\ncategory = Aspect Ratio\n$aspectRatioWidth = !aspectRatioWidth!\n$aspectRatioHeight = !aspectRatioHeight!" --logFile !logFileAr!
            )
        )

        if !vGfxPack! EQU 2 goto:setFsPresets
        if not exist !extraDirectives! goto:setFsPresets
        set "ed="
        for /F "delims=~" %%j in ('type !extraDirectives!') do set "ed=!ed!%%j\n"

        if !showEdFlag! EQU 0 if not ["!ed!"] == [""] echo extra directives detected ^:  >> !cgpLogFile! & echo !ed! >> !cgpLogFile!
        if !showEdFlag! EQU 0 if not ["!ed!"] == [""] echo extra directives detected ^: & echo !ed! & set /A "showEdFlag=1"

        REM : get extradirective
        set "edu=!ed!"
        if not ["!ed!"] == [""] (
            type !extraDirectives! | find "aspectRatio" > NUL 2>&1 && call:updateExtraDirectives "aspectRatio[ ]*=[ ]*\(16.0[ ]*\/[ ]*9.0[ ]*\)" "aspectRatio = (%wr%.0/%hr%.0)"
            REM Handle : ratioPassed > 16/9 -> $UIAspectX and < 16/9 -> $UIAspectY
            type !extraDirectives! | find "UIAspectY" > NUL 2>&1 && call:updateExtraDirectives "UIAspectY[ ]*=[ ]*1.0" "UIAspectY = (%wr%.0/%hr%.0)/(!nativeWidth!.0/!nativeHeight!.0)"

            type !extraDirectives! | find "GameAspect" > NUL 2>&1 && call:updateExtraDirectives "GameAspect[ ]*=[ ]*\(!nativeWidtht![ ]*\/[ ]*!nativeHeight![ ]*\)" "GameAspect = (%wr%.0/%hr%.0)"
        )

        :setFsPresets
        REM : complete full screen GFX presets (and packs for GFX packs V2)

        REM : reset extra directives file (V3 and up)
        if !vGfxPack! NEQ 2 if !vGfxPack! LSS 6 if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1

        call:setPresets

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
        REM : flag to update extraDirectives
        set "edu="
        for /F "delims=~" %%j in ('type !extraDirectives!') do set "edu=!edu!%%j\n"

    goto:eof
    REM : ------------------------------------------------------------------


    REM : add a resolution bloc BEFORE the native one in rules.txt
    :pushFront

        if !vGfxPack! LSS 6 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ 0-9A-Z-:/\(\)]*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n\$gameWidth[ ]*=[ ]*!nativeWidth!.*\n\$gameHeight[ ]*=[ ]*!nativeHeight!\n!edup!" --replace "[Preset]\nname = !wc!x!hc!!desc!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!\n\n[Preset]\nname = !previousW!x!previousH!!desc!\n$width = !previousW!\n$height = !previousH!\n\$gameWidth = !nativeWidth!\n\$gameHeight = !nativeHeight!\n!edu!" --logFile !logFileNewGp!
        ) else (
            if !existAspectRatioPreset! EQU 0 (
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\n$width = !wc!\n$height = !hc!\n\n[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\n$width = !previousW!\n$height = !previousH!\n" --logFile !logFileNewGp!
            ) else (
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\ncondition[ ]*=[ ]*\(\(\(\$aspectRatioWidth[ ]*-[ ]*!aspectRatioWidth!\)[ ]*==[ ]*0\)[ ]*\+[ ]*\(\(\$aspectRatioHeight[ ]*-[ ]*!aspectRatioHeight!\)[ ]*==[ ]*0\)\)[ ]*==[ ]*2.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !wc!\n$height = !hc!\n\n[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !previousW!\n$height = !previousH!\n" --logFile !logFileNewGp!
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------

    REM : add a resolution bloc AFTER the native one in rules.txt
    :pushBack

        if !vGfxPack! LSS 6 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ 0-9A-Z-:/\(\)]*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n\$gameWidth[ ]*=[ ]*!nativeWidth!.*\n\$gameHeight[ ]*=[ ]*!nativeHeight!\n!edup!" --replace "[Preset]\nname = !previousW!x!previousH!!desc!\n$width = !previousW!\n$height = !previousH!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!\n\n[Preset]\nname = !wc!x!hc!!desc!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!" --logFile !logFileNewGp!
        ) else (
            if !existAspectRatioPreset! EQU 0 (
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\n$width = !previousW!\n$height = !previousH!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
            ) else (
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\ncondition[ ]*=[ ]*\(\(\(\$aspectRatioWidth[ ]*-[ ]*!aspectRatioWidth!\)[ ]*==[ ]*0\)[ ]*\+[ ]*\(\(\$aspectRatioHeight[ ]*-[ ]*!aspectRatioHeight!\)[ ]*==[ ]*0\)\)[ ]*==[ ]*2.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !previousW!\n$height = !previousH!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to add an extra 16/9 preset in graphic pack of the game
    :addPresets

        REM : if BFW_GPV2_FOLDER exist
        if exist !BFW_GPV2_FOLDER! (

            set "str=!gpFolderName:_Resolution=!"
            set "str=!str:_Graphics=!"

            set "gpPath="!BFW_GPV2_FOLDER:"=!\!str:"=!""

            set "newGp="!gpPath:"=!_!hc!p""
            set "gpResX2="!gpPath:"=!_%resX2%p""

            REM : if V2 gfx version was detected in rules.txt
            if !vGfxPack! EQU 2 (
                set "gpPath=!rulesFolder:_%resX2%p=!"
                set "newGp="!gpPath:"=!_!hc!p!""
                set "gpResX2=!rulesFolder!"
            )

            if not exist !newGp! (
                wscript /nologo !StartHidden! !instanciateResX2gp! !nativeWidth! !nativeHeight! !gpResX2! !newGp! !wc! !hc! "!ratio!" > NUL 2>&1

                echo + !wc!x!hc!!ratio! V2 pack >> !cgpLogFile!
                echo + !wc!x!hc!!ratio! V2 pack
            ) else (
                echo - !wc!x!hc!!ratio! V2 pack already exists >> !cgpLogFile!
                echo - !wc!x!hc!!ratio! V2 pack already exists

            )
        )

        REM : V3 or up GP does not exist => continue to fill it and EXIT
        if !newGpExist! EQU 0 (
            call:fillResGraphicPack !wc! !hc! "!ratio!"
            goto:eof
        )

        REM : V3 or up GP exists
        type !rulesFile! | find "name = !wc!x!hc!" > NUL 2>&1 && (
            echo - !wc!x!hc!!ratio! preset already exists >> !cgpLogFile!
            echo - !wc!x!hc!!ratio! preset already exists
            goto:eof
        )

        echo + !wc!x!hc!!ratio! preset >> !cgpLogFile!
        echo + !wc!x!hc!!ratio! preset

        REM : replacing %wToReplace%xresX2 in rules.txt
        set "logFileNewGp="!fnrLogFolder:"=!\!gpFolderName:"=!-NewGp_!hc!x!wc!.log""
        if exist !logFileNewGp! del /F !logFileNewGp! > NUL 2>&1


        if !vGfxPack! LSS 6 if not ["!edu!"] == [""] (
            REM : replace $ by \$ for fnr.exe
            REM : replace integer by * (regexp)
            set "edup=!edu:$=\$!"
            set "edup=!edup:0=*.!"
            set "edup=!edup:1=*.!"
            set "edup=!edup:2=*.!"
            set "edup=!edup:3=*.!"
            set "edup=!edup:4=*.!"
            set "edup=!edup:5=*.!"
            set "edup=!edup:6=*.!"
            set "edup=!edup:7=*.!"
            set "edup=!edup:8=*.!"
            set "edup=!edup:9=*.!"
        )

        if !hc! GTR !h5! (
            call:pushBack
        ) else (
            call:pushFront
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :setParams

        REM : init
        set "wp=!wr!"
        set "suffixGp="

        set "sd=!desc!"
        set "sd=!sd: =!"
        set "sd=!sd:(=!"
        set "sd=!sd:)=!"
        set "sd=!sd:/=-!"

        set "hp=!hr!_!sd!"

        if ["!ratio!"] == [" (16/9)"] (
            set "desc= (16/9)"
            set "wp=16"
            set "hp=9"
            set "suffixGp="
            goto:eof
        )
        if ["!ratio!"] == [" (16/10)"] (
            set "desc= (16/10)"
            set "wp=16"
            set "hp=10"
            set "suffixGp="
            goto:eof
        )

        echo !ratio! | find /I " (361/210)" > NUL 2>&1 && (
            set "desc= (16/10) windowed"
            set "wp=16"
            set "hp=10"
            set "suffixGp=Win"
            goto:eof
        )
        echo !ratio! | find /I " (401/210)" > NUL 2>&1 && (
            set "desc= (16/9) windowed"
            set "wp=16"
            set "hp=9"
            set "suffixGp=Win"
            goto:eof
        )
        echo !ratio! | find /I " (377/192)" > NUL 2>&1 && (
            set "desc= (16/9 laptop) windowed"
            set "wp=16"
            set "hp=9_laptop"
            set "suffixGp=Win"
            goto:eof
        )
        echo !ratio! | find /I " (683/384)" > NUL 2>&1 && (
            set "desc= (16/9 laptop)"
            set "wp=16"
            set "hp=9_laptop"
            goto:eof
        )

        REM : others ratios already have a description up to date when using only GFX packs V3
        if not exist !BFW_GPV2_FOLDER! goto:eof

        echo !ratio! | find /I " (64/27)" > NUL 2>&1 && (
            set "wp=21"
            set "hp=9_uw237"
            goto:eof
        )

        echo !ratio! | find /I " (32/15)" > NUL 2>&1 && (
            set "wp=21"
            set "hp=9_uw24"
            goto:eof
        )

        echo !ratio! | find /I " (12/15)" > NUL 2>&1 && (
            set "wp=21"
            set "hp=9_uw213"
            goto:eof
        )

        echo !ratio! | find /I " (37/20)" > NUL 2>&1 && (
            set "wp=Tv"
            set "hp=Flat_r185"
            goto:eof
        )

        echo !ratio! | find /I " (1024/429)" > NUL 2>&1 && (
            set "wp=Tv"
            set "hp=Scope_r239"
            goto:eof
        )

        echo !ratio! | find /I " (256/135)" > NUL 2>&1 && (
            set "wp=Tv"
            set "hp=Dci_r189"
            goto:eof
        )
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to add an extra preset in graphic pack of the game
    :addCustomPresets

        set "wp=!wr!"
        set "hp=!hr!"
        set "suffixGp="
        set "desc= (!description:"=!)"

        call:setParams

        REM : if BFW_GPV2_FOLDER exist
        if exist !BFW_GPV2_FOLDER! (

            set "str=!gpFolderName:_Resolution=!"
            set "str=!str:_Graphics=!"

            set "gpPath="!BFW_GPV2_FOLDER:"=!\!str:"=!""
            set "newGp="!gpPath:"=!_!hc!p!wp!!hp!!suffixGp!""
            set "gpResX2="!gpPath:"=!_%resX2%p""

            REM : if V2 gfx version was detected in rules.txt
            if !vGfxPack! EQU 2 (
                set "gpPath=!rulesFolder:_%resX2%p=!"
                set "newGp="!gpPath:"=!_!hc!p!wp!!hp!!suffixGp!""
                set "gpResX2=!rulesFolder!"
            )

            if not exist !newGp! (

                REM : search for ResX2p489
                set "gpResX2p="!gpResX2:"=!489""

                if not exist !gpResX2p! (
                    REM : try ResX2p219
                    set "gpResX2p="!gpResX2:"=!219""
                )

                if exist !gpResX2p! (
                    set "gpResX2=!gpResX2p!"
                )

                wscript /nologo !StartHidden! !instanciateResX2gp! !nativeWidth! !nativeHeight! !gpResX2! !newGp! !wc! !hc! "!desc!" > NUL 2>&1

                echo + !wc!x!hc!!desc! V2 pack >> !cgpLogFile!
                echo + !wc!x!hc!!desc! V2 pack
            ) else (
                echo - !wc!x!hc!!desc! V2 pack already exists >> !cgpLogFile!
                echo - !wc!x!hc!!desc! V2 pack already exists
            )
        )

        REM : V3 or up GP does not exist => continue to fill it
        if !newGpExist! EQU 0 (
            REM : V3 and up
            set "descUpdated=!desc!"
            if !hc! EQU !nativeHeight! if !wc! EQU !nativeWidth! (
                set "descUpdated=!desc:)=! Default)"
            )
            call:fillResGraphicPack !wc! !hc! "!descUpdated!"
            goto:eof
        )
        REM : V3 or up GP exists
        type !rulesFile! | find "name = !wc!x!hc!" > NUL 2>&1 && (
            echo - !wc!x!hc!!desc! preset already exists >> !cgpLogFile!
            echo - !wc!x!hc!!desc! preset already exists
            goto:eof
        )

        echo + !wc!x!hc!!desc! preset >> !cgpLogFile!
        echo + !wc!x!hc!!desc! preset

        REM : replacing %wToReplace%xresX2 in rules.txt
        set "logFileNewGp="!fnrLogFolder:"=!\!gpFolderName:"=!-NewGp_!hc!x!wc!.log""
        if exist !logFileNewGp! del /F !logFileNewGp! > NUL 2>&1

        REM : add presets at the begining of rules.txt (after version =)
        REM : earlier than V6
        if !vGfxPack! LSS 6 (
            if not ["!edu!"] == [""] (

                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!" --logFile !logFileNewGp!
                goto:eof
            )
            REM : else
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!" --logFile !logFileNewGp!
            goto:eof
            )
        )
        REM : V6 and older
        if !existAspectRatioPreset! EQU 0 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
        ) else (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
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
