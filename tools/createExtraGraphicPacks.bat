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

    goto:inputsAvailables

    REM : titleID and BFW_GP_FOLDER
    :getArgsValue

    echo. > !cgpLogFile!
    if %nbArgs% GTR 4 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID RULES_FILE NAME^* >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID RULES_FILE NAME^*
        echo given {%*}

        exit /b 99
    )
    if %nbArgs% LSS 3 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID RULES_FILE NAME^* >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID RULES_FILE NAME^*
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

    set "rulesFile=!args[2]!"

    if %nbArgs% EQU 4 (
        set "str=!args[3]!"
        set "gameName=!str:"=!"
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"
    REM : BatchFw V2 gfx pack folder
    set "BFW_GPV2_FOLDER="!BFW_GP_FOLDER:"=!\_graphicPacksV2""

    set "titleId=!titleId:"=!"


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
    echo Create extra graphic packs ^(missing resolutions^) for !GAME_TITLE! >> !cgpLogFile!
    echo Create extra graphic packs ^(missing resolutions^) for !GAME_TITLE!
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
    REM : v2 only if no V2 found
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

        echo !rulesFile! | find /IV "!resX2!p" > NUL 2>&1 && (
            echo WARNING : graphic pack folder name does not match 2 x native Height >> !cgpLogFile!
            echo WARNING : graphic pack folder name does not match 2 x native Height
        )

        goto:treatGfxPacks
    )

    REM : a new GFX pack was found
    set /A "newGpExist=1"

    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    REM : be sure that only one default preset exist in file
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_secureRulesFile.log""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "[[]Preset[]].*\nname[ ]*=[ ]*.*\n\$width[ ]*=[ ]*!nativeWidth![ ]*.*\n\$height[ ]*=[ ]*!nativeHeight!\n\$gameWidth[ ]*=[ ]*!nativeWidth![ ]*.*\n\$gameHeight[ ]*=[ ]*!nativeHeight!" --replace "" --logFile !fnrLogFile!
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack!\n"  --replace "version = !vGfxPack!\n\n[Preset]\nname = !nativeWidth!x!nativeHeight! (16/9) (Default)\n$width = !nativeWidth!\n$height = !nativeHeight!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n" --logFile !fnrLogFile!
    
    REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
    set "gpNativeHeight=NOT_FOUND"
    for /F "tokens=4 delims=x " %%s in ('type !rulesFile! ^| find /I "name" ^| find /I "Default" 2^>NUL') do set "gpNativeHeight=%%s"
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
    if not ["!gpNativeHeight!"] == ["NOT_FOUND"] if !gpNativeHeight! NEQ !nativeHeight! (
        echo WARNING : native height in rules.txt does not match >> !cgpLogFile!
        echo WARNING : native height in rules.txt does not match
    )

    call:completeGfxPacks !gpNameFolder!

    if !newGpExist! EQU 1 goto:ending

    :createNew
    REM : create res graphic pack (game support in slahiee repository but not present in gfx pack)
    set "newGpNameFolder=!gpNameFolder:_graphicPacksV2\=!"
    set "newGpName=!gpNameFolder:_%resX2%p=!"
    set "newGpV3="!BFW_GP_FOLDER:"=!\!newGpName:"=!_Resolution""
    set "newGpV3="!BFW_GP_FOLDER:"=!\!newGpName:"=!_Graphics""
    if not exist !newGpV3! mkdir !newGpV3! > NUL 2>&1

    set "bfwRulesFile="!newGpV3:"=!\rules.txt""

    echo Creating V3 pack for !newGpName! ^: !bfwRulesFile!

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
    robocopy !gpResX2! !newGpV3! /S /XF rules.txt

    REM : replacing float Scale = 2.0
    set "fnrLogFile="!fnrLogFolder:"=!\fnr_newGp-resXScale.log""
    echo !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)"  >> !cgpLogFile!
    echo !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)"
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resXScale = 2.0" --replace "resXScale = ($width/$gameWidth)" --logFile !fnrLogFile!

    set "fnrLogFile="!fnrLogFolder:"=!\fnr_newGp-resYScale.log""
    echo !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)" >> !cgpLogFile!
    echo !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)"
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resYScale = 2.0" --replace "resYScale = ($height/$gameHeight)" --logFile !fnrLogFile

    set "fnrLogFile="!fnrLogFolder:"=!\fnr_newGp-resScale.log""
    echo !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)" >> !cgpLogFile!
    echo !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)"
    wscript /nologo !StartHidden! !fnrPath! --cl --dir !newGpV3! --fileMask *_*s.txt --find "resScale = 2.0" --replace "resScale = ($height/$gameHeight)" --logFile !fnrLogFile!


    set "patchFile="!newGpV3:"=!\patches.txt""

    if not exist !patchFile! goto:ending

    REM : replace scale factor in patchFile
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !newGpV3! --fileMask patches.txt --find !patchValue! --replace "$width/$height" --logFile !fnrLogFile!
    
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

        if !vGfxPack! NEQ 2 if !vGfxPack! NEQ 5 (
            set "extraDirectives="!fnrLogFolder:"=!\extraDirectives.log""
            if exist !extraDirectives! del /F !extraDirectives! > NUL 2>&1
            set "extraDirectives169="!fnrLogFolder:"=!\extraDirectives169.log""

            REM : here the rules.txt is stock (extraDirectives are 16/9 ones)
            call:getExtraDirectives > !extraDirectives!
            copy /Y !extraDirectives! !extraDirectives169! > NUL 2>&1

            REM : replacing directives in extraDirectives.log
            set "logFileED="!fnrLogFolder:"=!\fnr_extraDirectives.log""
            if exist !logFileED! del /F !logFileED! > NUL 2>&1
        )

        REM : reset extra directives file
        if !vGfxPack! NEQ 2 if !vGfxPack! NEQ 5 if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1

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
            if !vGfxPack! NEQ 2 if !vGfxPack! NEQ 5 if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1
        )

        if !vGfxPack! NEQ 2 if !vGfxPack! NEQ 5 del /F !extraDirectives! > NUL 2>&1

        REM : remove extra directives left alone in the file (in case of multiple default preset defined)
        if not ["!ed!"] == [""] (
            set "fnrLogFile="!fnrLogFolder:"=!\fnr_secureRulesFile.log""
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "#.*\n\n\n!ed:$=\$!" --replace "\n" --logFile !fnrLogFile!
        )

        if !vGfxPack! NEQ 2 if !vGfxPack! NEQ 5 del /F !extraDirectives169! > NUL 2>&1

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

        REM : GFX version to set
        set "setup="!BFW_PATH:"=!\setup.bat""
        set "lastVersion=NONE"
        for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION" 2^>NUL') do set "lastVersion=%%i"
        set "lastVersion=!lastVersion:"=!"

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
        echo version = !lastVersion! >> !bfwRulesFile!
        echo. >> !bfwRulesFile!
        echo. >> !bfwRulesFile!
    goto:eof
    REM : ------------------------------------------------------------------

    :fillResGraphicPack
        set "overwriteWidth=%~1"
        set "overwriteHeight=%~2"

        echo [Preset] >> !bfwRulesFile!
        echo name = %overwriteWidth%x%overwriteHeight% %~3 >> !bfwRulesFile!
        echo $width = %overwriteWidth% >> !bfwRulesFile!
        echo $height = %overwriteHeight% >> !bfwRulesFile!
        echo $gameWidth = !nativeWidth! >> !bfwRulesFile!
        echo $gameHeight = !nativeHeight! >> !bfwRulesFile!
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
        if !hr! EQU 9 if !wr! EQU 16 call:addPresets169 & goto:eof

        call:addCustomPresets

    goto:eof
    REM : ------------------------------------------------------------------


    :setPresets
    
        set "ratio= (!wr!/!hr!)"

        set /A "end=5760/!hr!"
        set /A "start=360/!hr!"

        set /A "step=1"
        set /A "range=(end-start)"
        set /A "step=range/30"
        if !step! LSS 1 set /A "step=1"

        set /A "previous=6000
        for /L %%i in (%end%,-!step!,%start%) do (

            set /A "wi=!wr!*%%i"
            set /A "hi=!hr!*%%i"

            set /A "offset=!previous!-!hi!"
            if !hi! NEQ 0 if !offset! GEQ 180 (
                call:addResolution
                set /A "previous=!hi!"
            )
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

        if !vGfxPack! EQU 2 goto:setFsPresets
        if not exist !extraDirectives! goto:setFsPresets
        set "ed="
        for /F "delims=~" %%j in ('type !extraDirectives!') do set "ed=!ed!%%j\n"

        if !showEdFlag! EQU 0 if not ["!ed!"] == [""] echo extra directives detected ^:  >> !cgpLogFile! & echo !ed! >> !cgpLogFile!
        if !showEdFlag! EQU 0 if not ["!ed!"] == [""] echo extra directives detected ^: & echo !ed! & set /A "showEdFlag=1"

        REM : no need for 16/9
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
        if !vGfxPack! NEQ 2 if !vGfxPack! NEQ 5 if exist !extraDirectives169! copy /Y !extraDirectives169! !extraDirectives! > NUL 2>&1

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

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*.*\n\$width[ ]*=[ ]*!nativeWidth![ ]*.*\n\$height[ ]*=[ ]*!nativeHeight!" --replace "[Preset]\nname = !wc!x!hc!!ratio:"=!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n\n[Preset]\nname = !nativeWidth!x!nativeHeight! (16/9 Default)\n$width = !nativeWidth!\n$height = !nativeHeight!" --logFile !logFileNewGp!

        if not ["!edu!"] == [""] (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^\$width = !wc!\n\$height = !hc!\n\$gameWidth = !nativeWidth!\n\$gameHeight = !nativeHeight!" --replace "$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!" --logFile !logFileNewGp!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    REM : add a resolution bloc BEFORE the native one in rules.txt
    :pushFrontV5

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*!nativeWidth!x!nativeHeight![ ]*.*\ncategory = Resolution" --replace "[Preset]\nname = !wc!x!hc!!ratio:"=!\ncategory = Resolution\n\n[Preset]\nname = !nativeWidth!x!nativeHeight! (16/9 Default)\ncategory = Resolution" --logFile !logFileNewGp!

    goto:eof
    REM : ------------------------------------------------------------------


    REM : add a resolution bloc AFTER the native one in rules.txt
    :pushBack

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*.*\n\$width[ ]*=[ ]*!nativeWidth![ ]*.*\n\$height[ ]*=[ ]*!nativeHeight![ ]*\n\$gameWidth[ ]*=[ ]*!nativeWidth![ ]*\n\$gameHeight[ ]*=[ ]*!nativeHeight!" --replace "[Preset]\nname = !nativeWidth!x!nativeHeight!  (16/9 Default)\n$width = !nativeWidth!\n$height = !nativeHeight!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n\n[Preset]\nname = !wc!x!hc!!ratio:"=!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!" --logFile !logFileNewGp!

        if not ["!edu!"] == [""] (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^\$width = !nativeWidth!\n\$height = !nativeHeight!\n\$gameWidth = !nativeWidth!\n\$gameHeight = !nativeHeight!" --replace "$width = !nativeWidth!\n$height = !nativeHeight!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!" --logFile !logFileNewGp!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    REM : add a resolution bloc AFTER the native one in rules.txt
    :pushBackV5

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*!nativeWidth!x!nativeHeight![ ]*.*\ncategory = Resolution" --replace "[Preset]\nname = !nativeWidth!x!nativeHeight!  (16/9 Default)\ncategory = Resolution\n\n[Preset]\nname = !wc!x!hc!!ratio:"=!\ncategory = Resolution\n$width = !wc!\n$height = !hc!" --logFile !logFileNewGp!

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to add an extra 16/9 preset in graphic pack of the game
    :addPresets169

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

        if !hc! GTR !nativeHeight! (
            if !vGfxPack! NEQ 5 call:pushBack
            if !vGfxPack! EQU 5 call:pushBackV5
        )

        if !hc! LSS !nativeHeight! (
            if !vGfxPack! NEQ 5 call:pushFront
            if !vGfxPack! EQU 5 call:pushFrontV5
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

        REM : Adding !h!x!w! in rules.txt
        set "logFileNewGp="!fnrLogFolder:"=!\!gpFolderName:"=!-NewGp_!hc!x!wc!.log""
        if exist !logFileNewGp! del /F !logFileNewGp! > NUL 2>&1

        if not ["!edu!"] == [""] (

            if !vGfxPack! NEQ 5 wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!\n!edu!" --logFile !logFileNewGp!
            goto:eof
        )

        if !vGfxPack! NEQ 5 wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\n$width = !wc!\n$height = !hc!\n$gameWidth = !nativeWidth!\n$gameHeight = !nativeHeight!" --logFile !logFileNewGp!

        if !vGfxPack! EQU 5 wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^[[]Preset[]].*\nname[ ]*=[ ]*!nativeWidth!x!nativeHeight!" --replace "[Preset]\nname = !wc!x!hc!!desc!\ncategory = Resolution\n$width = !wc!\n$height = !hc!\n\n[Preset]\nname = !nativeWidth!x!nativeHeight!" --logFile !logFileNewGp!

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
