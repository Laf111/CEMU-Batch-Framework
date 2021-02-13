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

    REM : set current char codeset
    call:setCharSetOnly

    REM : TODO remove when updated
    echo Need to be updated ^^!
    pause
    exit /b 200


    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )
    
    pushd !BFW_GP_FOLDER!
    REM : V2 to V6 gfx packs
    for /F "delims=~" %%i in ('dir /B  /A:D *_Resolution 2^> NUL ^| find /I /V "_Gamepad" ^| find /I /V "_Performance_"') do (
        call:treatGp "%%i"
    )
    REM : V6 and up gfx packs
    for /F "delims=~" %%i in ('dir /B /S /A:D Graphics 2^> NUL') do (
        call:treatGpLatestVersion "%%i"
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


    :treatGp

        for /F "delims=~" %%i in (%1) do set "name=%%~nxi"
        for /F "tokens=1 delims=_" %%j in ("!name!") do set "title=%%j"
        set "rulesFile="!BFW_GP_FOLDER:"=!\%~1\rules.txt""

        for /F "tokens=2 delims=~=," %%k in ('type !rulesFile! ^| find "titleIds"') do set "tid=%%k"
        echo #########################################################
        echo !title!
        echo #########################################################

        echo "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !rulesFile! !title!
        echo.
        call "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !rulesFile! !title!

        echo "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        echo.
        call "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        echo #########################################################

    goto:eof

    :treatGpLatestVersion
        set "graphicsFolder="%~1""

        for %%a in (!graphicsFolder!) do set "parentFolder="%%~dpa""
        set "gamePackFolder=!parentFolder:~0,-2!""


        for /F "delims=~" %%i in (!gamePackFolder!) do set "title=%%~nxi"
        set "rulesFile="!graphicsFolder:"=!\rules.txt""

        for /F "tokens=2 delims=~=," %%k in ('type !rulesFile! ^| find "titleIds"') do set "tid=%%k"
        echo #########################################################
        echo !title!^, !tid!
        echo #########################################################

        echo "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !rulesFile! !title!
        echo.
        call "!BFW_PATH:"=!\tools\createExtraGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !rulesFile! !title!

        echo "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        echo.
        call "!BFW_PATH:"=!\tools\createCapGraphicPacks.bat" "!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs" !tid! !title!
        echo #########################################################

    goto:eof