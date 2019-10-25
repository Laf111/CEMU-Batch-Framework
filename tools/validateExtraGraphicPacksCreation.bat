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

    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    pushd !BFW_GP_FOLDER!
    for /F "delims=~" %%i in ('dir /B  /A:D *_Resolution ^| find /V "_Performance"') do (
        call:treatGp "%%i"
    )
    pause
    goto:eof


    :treatGp

        for /F "delims=~" %%i in (%1) do set "name=%%~nxi"
        for /F "tokens=1 delims=_" %%j in ("!name!") do set "title=%%j"

        for /F "tokens=2 delims=~=," %%k in ('type "%~1\rules.txt" ^| find "titleIds"') do set "tid=%%k"
        @echo #########################################################
        @echo !title!
        @echo #########################################################

        echo "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        echo.
        call "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!

        echo "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        echo.
        call "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        @echo #########################################################

    goto:eof
    