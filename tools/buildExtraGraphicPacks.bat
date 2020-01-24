@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

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

    pushd !GAMES_FOLDER!
    REM : searching for meta file
    for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^| find /I /V "\mlc01"') do (

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
            echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    
    :treatGame

        for %%a in (!META_FILE!) do set "parentFolder="%%~dpa""
        set "metaF=!parentFolder:~0,-2!""
        set "GAME_FOLDER_PATH=!metaF:\meta=!"

        REM : basename of GAME_FOLDER_PATH (to get GAME_TITLE)
        for /F "delims=~" %%l in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxl"

        echo #########################################################
        echo !GAME_TITLE!
        echo #########################################################

        REM : search for a GFX pack for this game

        REM : get game's data for wii-u database file
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

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

        if exist !fnrLogBegp! del /F !fnrLogBegp! > NUL 2>&1

        REM : launching the search in all gfx pack folder (V2 and up)
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogBegp!

        set "gameName=NONE"

        REM : check if a gfx pack with version > 2 exists ?
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogBegp! ^| find "File:" ^| find /I /V "_BatchFw" ^| find "_Resolution\" ^| find /I /V "_Gamepad" ^| find /I /V "_Performance_"') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            echo GFX pack found ^: !rulesFile!
            echo.

            set "gpLastVersionRes=!rulesFile:\rules.txt=!"
            REM : get the game's name from it
            for /F "delims=~" %%i in (!gpLastVersionRes!) do set "str=%%~nxi"
            set "gameName=!str:_Resolution=!"

            goto:handleGfxPacks
        )

        REM : No new gfx pack found but is a V2 gfx pack exists ?
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogBegp! ^| find "File:" ^| findstr /r "%resX2%p\\rules.txt"') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            echo Only V2 GFX pack found ^: !rulesFile!
            echo.
            REM : V2 graphic pack
            set "str=%%i"
            set "str=!str:rules=!"
            set "str=!str:\_graphicPacksV2=!"
            set "str=!str:\=!"
            set "gameName=!str:_%resX2%p=!"

            goto:handleGfxPacks
        )

        REM : No GFX pack was found : createCapGraphicPacks.bat
        echo No GFX pack found ^: create them
        echo.
        echo "!BFW_PATH:"=!\tools\createGameGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" %titleId% !title!
        echo.
        call "!BFW_PATH:"=!\tools\createGameGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" %titleId% !title!
        goto:creatCap


        :handleGfxPacks
        set "argSup=%gameName%"
        if ["%gameName%"] == ["NONE"] set "argSup="

        REM : only V2 found or V3 found
        echo "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" %titleId% !rulesFile! !title! !argSup!
        echo.
        call "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" %titleId% !rulesFile! !title! !argSup!

        :creatCap

        echo "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" %titleId% !title! !argSup!
        echo.
        call "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" %titleId% !title! !argSup!

        echo #########################################################

    goto:eof
    