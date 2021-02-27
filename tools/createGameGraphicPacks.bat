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
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""
    set "cggpLogFile="!BFW_LOGS:"=!\createGameGraphicPacks.log""
    set "fnrSearch="!BFW_LOGS:"=!\fnr_createGameGraphicPacks.log""
    
    set "createLastVersion="!BFW_TOOLS_PATH:"=!\createLastGraphicPacks.bat""
    set "createV4="!BFW_TOOLS_PATH:"=!\createV4GraphicPacks.bat""
    set "createV2="!BFW_TOOLS_PATH:"=!\createV2GraphicPacks.bat""

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

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    REM : starting DATE
    set "startingDate=%ldt%"
    echo. > !cggpLogFile!

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if not exist !BFW_GP_FOLDER! (
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
        echo Bad titleId ^^! must have at least 16 hexadecimal characters^, given !titleId!
        goto:getTitleId
    )
    REM : check too long
    set "checkLenght=!titleId:~16,1!"

    if not ["x!checkLenght!x"] == ["xx"] (
        echo Bad titleId ^^! must have 16 hexadecimal characters^, given !titleId!
        goto:getTitleId
    )
    set "titleId=!titleId!"

    REM : get gfxPackVersion version to create
    echo.
    echo Which version of pack to you wish to create ^?
    echo.
    echo     - 1 ^: CEMU ^< 1^.14
    echo     - 2 ^: 1^.14 ^< CEMU ^< 1^.21
    echo     - 3 ^: CEMU ^> 1^.21
    echo.
    choice /C 123 /T 15 /D 3 /N /M "Enter your choice ? : "
    set /A "crx2=!ERRORLEVEL!*2"
    set "gfxPackVersion=V!crx2!"

    REM get all title Id for this game
    set "titleIdsList=!titleId!"
    call:getAllTitleIds

    set "list=!titleIdsList:^,= !"
    set "list=!list:"=!"

    REM : search meta in games folder file that contains titleId
    set "GAME_GP_FOLDER="NOT_FOUND""
    REM : loop on all title Id for this game
    for %%t in (%list%) do (
        set "tid=%%t"

        REM : check if the game exist in !GAMES_FOLDER! (not dependant of the game folder's name)
        set "fnrSearch="!BFW_LOGS:"=!\fnr_createGameGraphicPacks.log""

        if exist !fnrSearch! del /F !fnrSearch! > NUL 2>&1
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !GAMES_FOLDER! --fileMask "meta.xml" --ExcludeDir "content, code, mlc01, Cemu" --includeSubDirectories --find !tid!  --logFile !fnrSearch!

        for /F "tokens=2-3 delims=." %%j in ('type !fnrSearch! ^| find /I /V "^!" ^| find "File:"') do (

            set "metaFile="!GAMES_FOLDER:"=!%%j.%%k""

            set "gameFolder=!metaFile:\meta\meta.xml=!"
            for /F "delims=~" %%p in (!gameFolder!) do set "gameName=%%~nxp"

            REM : get NAME from game's folder and set GAME_GP_FOLDER
            set "GAME_GP_FOLDER="!gameFolder:"=!\Cemu\graphicPacks""
            goto:inputsAvailables
        )
    )
    if [!GAME_GP_FOLDER!] == ["NOT_FOUND"] (
        echo GAME_FOLDER not found using titleId=!titleId!
        pause
        exit /b 201
    )

    goto:inputsAvailables

    REM : getArgsValue
    :getArgsValue
    if %nbArgs% LEQ 3 (
        echo ERROR ^: on arguments passed ^^! >> !cggpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^* >> !cggpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^*
        echo where NAME is optional >> !cggpLogFile!
        echo where NAME is optional
        echo given {%*} >> !cggpLogFile!
        echo given {%*}
        exit /b 99
    )
    if %nbArgs% GTR 5 (
        echo ERROR ^: on arguments passed ^^! >> !cggpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^* >> !cggpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER gfxPackVersion TITLE_ID NAME^*
        echo where NAME is optional >> !cggpLogFile!
        echo where NAME is optional
        echo given {%*} >> !cggpLogFile!
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
        !MessageBox! "Unable to get informations on the game for titleId !titleId! in !wiiTitlesDataBase:"=!" 4112
        exit /b 3
    )
    echo createGameGraphicPacks ^: unable to get informations on the game for titleId !titleId! ^? >> !cggpLogFile!
    echo createGameGraphicPacks ^: unable to get informations on the game for titleId !titleId! ^?
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase! >> !cggpLogFile!
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase!

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

    REM get all title Id for this game
    set "titleIdsList=!titleId!"
    call:getAllTitleIds

    set "title=%DescRead:"=%"
    if ["!gameName!"] == [""] set "GAME_TITLE=%title: =%"

    echo ========================================================= >> !cggpLogFile!
    echo =========================================================
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv  >> !cggpLogFile!
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv
    echo ---------------------------------------------------------
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
    echo Creating GFX packs^.^.^.  >> !cggpLogFile!
    echo Creating GFX packs^.^.^.

    REM : create resolution graphic packs
    if not ["!gfxPackVersion!"] == ["V2"] goto:V4packs

    REM : V2 packs
    echo !createV2! !BFW_GP_FOLDER! !titleIdsList! !nativeHeight! "!GAME_TITLE!" >> !cggpLogFile!
    echo Create V2 packs^.^.^.
    call !createV2! !BFW_GP_FOLDER! !titleIdsList! !nativeHeight! "!GAME_TITLE!"

    REM : update !glogFile! (log2GamesLibraryFile does not add a already present message in !glogFile!)
    set "msg="!GAME_TITLE! [!titleId!] graphic packs versionV2=completed""
    call:log2GamesLibraryFile !msg!

    goto:endMain

    :V4packs
    if not ["!gfxPackVersion!"] == ["V4"] goto:V6packs

    REM : V4 packs
    echo !createV4! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !titleIdsList! !nativeHeight! "!GAME_TITLE!" >> !cggpLogFile!
    call !createV4! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !titleIdsList! !nativeHeight! "!GAME_TITLE!"

    REM : update !glogFile! (log2GamesLibraryFile does not add a already present message in !glogFile!)
    set "msg="!GAME_TITLE! [!titleId!] graphic packs versionV4=completed""
    call:log2GamesLibraryFile !msg!
    goto:endMain

    :V6packs
    REM : V4 packs
    echo !createLastVersion! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !titleIdsList! !nativeHeight! "!GAME_TITLE!" >> !cggpLogFile!
    call !createLastVersion! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !titleIdsList! !nativeHeight! "!GAME_TITLE!"

    REM : !glogFile! is updated in updateGamesGraphicPacks

    :endMain
    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "endingDate=%ldt%"

    echo ========================================================= >> !cggpLogFile!
    echo =========================================================

    echo starting date = %startingDate% >> !cggpLogFile!
    echo starting date = %startingDate%
    echo ending date = %endingDate% >> !cggpLogFile!
    echo ending date = %endingDate%

    if %nbArgs% EQU 0 endlocal && pause
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :getAllTitleIds

        REM now searching using icoId
        for /F "delims=~; tokens=1" %%i in ('type !wiiTitlesDataBase! ^| find /I ";%icoId%;"') do (
            set "titleIdRead=%%i"
            set "titleIdRead=!titleIdRead:'=!"
            echo !titleIdsList! | find /V "!titleIdRead!" > NUL 2>&1 && (
                set "titleIdsList=!titleIdsList!^,!titleIdRead!"
            )
        )
        set "titleIdsList="!titleIdsList!""

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
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !glogFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !glogFile! ^| find /I "!msg!" 2^>NUL') do goto:eof

        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.bfw_tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL 2>&1
        move /Y !gLogFileTmp! !glogFile! > NUL 2>&1

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


