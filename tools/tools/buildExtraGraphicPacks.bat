@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    title -= Build extra GFX presets^/packs =-

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

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "fnrLogBegp="!BFW_PATH:"=!\logs\fnr_buildExtraGraphicPacks.log""
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    REM : set current char codeset
    call:setCharSetOnly

    set "setup="!BFW_PATH:"=!\setup.bat""
    REM : GFX version to set
    set "LastVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION" 2^>NUL') do set "LastVersion=%%i"
    set "LastVersion=!LastVersion:"=!"

    REM : get the last version used
    set "newVersion=NOT_FOUND"

    set "pat="!BFW_GP_FOLDER:"=!\graphicPacks*.doNotDelete""

    set "gpl="NOT_FOUND""
    for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do set "gpl="%%a""
    if not [!gpl!] == ["NOT_FOUND"] set "zipLogFile="!BFW_GP_FOLDER:"=!\!gpl:"=!""

    if [!gpl!] == ["NOT_FOUND"] (
        echo WARNING ^: !pat! not found^, force extra pack creation ^!
        REM : create one
        set "dnd="!BFW_GP_FOLDER:"=!\graphicPacks703.doNotDelete""
        echo. > !dnd!
    )

    for /F "delims=~" %%i in (!zipLogFile!) do (
        set "fileName=%%~nxi"
        set "newVersion=!fileName:.doNotDelete=!"
    )

    REM : get the last version used for launching this game
    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
    
    pushd !GAMES_FOLDER!
    REM : searching for meta file
    for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        REM : set/reset gfxType
        set "gfxType=V!LastVersion!"

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%k""
        for /F "delims=<" %%j in (!titleLine!) do set "titleId=%%j"

        call:treatGame
    )

    pause
    goto:eof
REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions


    REM : function to get and set char set code for current host
    :setCharSetOnly

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

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
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

    :cleanGameLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.bfw_tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------
    
    
    :treatGame

        REM : search for a GFX pack for this game

        REM : get game's data for wii-u database file
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';"') do set "libFileLine="%%i""

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
        set /A "resX2=%nativeHeight%*2"

        set "GAME_TITLE=%Desc: =%"
        echo #########################################################
        echo !GAME_TITLE!
        echo #########################################################
        
        if exist !fnrLogBegp! del /F !fnrLogBegp! > NUL 2>&1

        REM : launching the search in all gfx pack folder (V2 and up)

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --ExcludeDir _graphicPacksV --find %titleId:~3% --logFile !fnrLogBegp!

        set "gameName=NONE"

REM : DEBUG
REM type !fnrLogBegp! ^| find "File:" | find /I /V "_BatchFw" | find "Graphics\"
REM pause

        REM : check if a gfx pack exist (latest version of packs)
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogBegp! ^| find "File:" ^| find /I /V "_BatchFw" ^| find "Graphics\"') do (
            set "gpfound=1"

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            REM : TODO uncomment when batchFw will create latest GFX packs
REM            echo Found a V!LastVersion! graphic pack ^: !rulesFile!
            echo Found a V6 graphic pack ^: !rulesFile!

            set "gpLastVersionRes=!rulesFile:\rules.txt=!"
            for %%a in (!gpLastVersionRes!) do set "parentFolder="%%~dpa""
            set "titleFolder=!parentFolder:~0,-2!""

            REM : get the game's name from it
            for /F "delims=~" %%i in (!titleFolder!) do set "gameName=%%~nxi"

            goto:handleGfxPacks
        )

        REM : No new gfx pack found but is a V4 gfx pack exists ?

        REM : TODO update when V6 GFX packs only in _BatchFw_Graphic_Packs root
        REM : if not exist !gfxPacksV4Folder! goto:checkV2packs

REM : DEBUG
REM type !fnrLogBegp! | find "File:" | find /I /V "_BatchFw" | find "_Resolution\" | find /I /V "_Gamepad" | find /I /V "_Performance_"
REM pause

        REM : check if a gfx pack with version > 2 exists ?
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogBegp! ^| find "File:" ^| find /I /V "_BatchFw" ^| find "_Resolution\" ^| find /I /V "_Gamepad" ^| find /I /V "_Performance_"') do (
            set "gpfound=1"

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            REM : TODO replace LastVersion by V4 when batchFw will create latest GFX packs
            echo Found a V4 graphic pack ^: !rulesFile!
            set "gfxType=V4"

            set "gpLastVersionRes=!rulesFile:\rules.txt=!"
            REM : get the game's name from it
            for /F "delims=~" %%i in (!gpLastVersionRes!) do set "str=%%~nxi"
            set "gameName=!str:_Resolution=!"

            goto:handleGfxPacks
        )
        :checkV2packs
        REM : No new gfx pack found but is a V2 gfx pack exists ?
        if not exist !gfxPacksV2Folder! goto:createPacks

REM : DEBUG
REM type !fnrLogBegp! | find "File:" | findstr /R "%resX2%p\\rules.txt"
REM pause
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogBegp! ^| find "File:" ^| findstr /R "%resX2%p\\rules.txt"') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            set "gfxType=V2"

            REM : V2 graphic pack
            set "str=%%i"
            set "str=!str:rules=!"
            set "str=!str:\_graphicPacksV2=!"
            set "str=!str:\=!"
            set "gameName=!str:_%resX2%p=!"

            goto:handleGfxPacks
        )

        :createPacks
        REM : No GFX pack was found

        echo No GFX pack found ^: create them
        echo.
        echo "!BFW_PATH:"=!\tools\createGameGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !gfxType! %titleId%
        echo.
        call "!BFW_PATH:"=!\tools\createGameGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !gfxType! %titleId%

        set "argSup=%Desc: =%"

        goto:creatCap


        :handleGfxPacks

        set "argSup=%gameName%"
        if ["%gameName%"] == ["NONE"] set "argSup="

        REM : only V2 found or V4 found
        echo "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !gfxType! %titleId% !rulesFile! !argSup!
        echo.
        call "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !gfxType! %titleId% !rulesFile! !argSup!

        :creatCap

        echo "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !gfxType! %titleId% !argSup!
        echo.
        call "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !gfxType! %titleId% !argSup!

        echo #########################################################

        REM : update GLogFile
        REM : log in game library log
        if not ["!newVersion!"] == ["NOT_FOUND"] (

            REM : flush glogFile of !GAME_TITLE! graphic packs version
            if exist !glogFile! for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find "!GAME_TITLE! graphic packs version" 2^>NUL') do call:cleanGameLogFile "!GAME_TITLE! graphic packs version"

            set "msg="!GAME_TITLE! graphic packs version=!newVersion!""
            call:log2GamesLibraryFile !msg!
        )

    goto:eof
    