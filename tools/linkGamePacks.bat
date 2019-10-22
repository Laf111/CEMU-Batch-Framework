@echo off
color f
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

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
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "myLog="!BFW_PATH:"=!\logs\linkGamePacks.log""
    
    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% NEQ 3 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" titleId gfxType GAME_TITLE
        @echo given {%*}
        pause
        exit /b 99
    )

    set "titleId=!args[0]!"
    set "titleId=!titleId:"=!"
    set "gfxType=!args[1]!"
    set "gfxType=!gfxType:"=!"
    set "GAME_TITLE=!args[2]!"
    set "GAME_TITLE=!GAME_TITLE:"=!"

    REM : BatchFW folders
    set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!GAME_TITLE!""
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    set "BFW_LEGACY_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""
    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""

    REM : clean links in game's graphic pack folder
    for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        rmdir /Q !gpLink! > NUL 2>&1
    )

    REM : search game's graphic pack folder
    set "fnrLogLgp="!BFW_PATH:"=!\logs\fnr_linkGamePacks.log""
    if exist !fnrLogLgp! del /F !fnrLogLgp!
    REM : Re launching the search (to get the freshly created packs)

    REM : search in the needed folder
    if ["!gfxType!"] == ["V3"] (
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --includeSubDirectories --ExcludeDir _graphicPacksV2 --fileMask "rules.txt" --find !titleId:~3! --logFile !fnrLogLgp!
    ) else (
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_LEGACY_GP_FOLDER! --includeSubDirectories --fileMask "rules.txt" --find !titleId:~3! --logFile !fnrLogLgp!
    )

    call:importGraphicPacks > !myLog!

    if ["!gfxType!"] == ["V3"] (
        call:importMods >> !myLog!
        goto:endMain
    )

    REM : get user defined ratios list
    set "ARLIST="
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do set "ARLIST=%%i !ARLIST!"
    if ["!ARLIST!"] == [""] goto:endMain

    REM : import user defined ratios graphic packs
    for %%a in (!ARLIST!) do (
        if ["%%a"] == ["1610"] call:importOtherGraphicPacks 1610 >> !myLog!
        if ["%%a"] == ["219"]  call:importOtherGraphicPacks 219 >> !myLog!
        if ["%%a"] == ["43"]   call:importOtherGraphicPacks 43 >> !myLog!
        if ["%%a"] == ["489"]  call:importOtherGraphicPacks 489 >> !myLog!
    )

    :endMain

    exit /b 0
goto:eof


REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :importMods
        REM : search user's mods under %GAME_FOLDER_PATH%\Cemu\mods
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\mods""
        if not exist !pat! mkdir !pat! > NUL 2>&1
        for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do (
            set "modName="%%a""
            set "mod="!GAME_FOLDER_PATH:"=!\Cemu\mods\!modName:"=!""
            set "tName="MOD_!modName:"=!""

            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! > NUL 2>&1
            mklink /J /D !linkPath! !mod!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :getFirstFolder

        set "firstFolder=!gp!"
        :getFirstLevel
        echo !firstFolder! | find "\" > NUL 2>&1 && (

            set "tfp="!BFW_GP_FOLDER:"=!\!firstFolder:"=!""
            for %%a in (!tfp!) do set "parentFolder="%%~dpa""
            set "tfp=!parentFolder:~0,-2!""

            for /F "delims=~" %%i in (!tfp!) do set "firstFolder=%%~nxi"

            goto:getFirstLevel
        )
        set "rgp=!firstFolder!"
    goto:eof
    REM : ------------------------------------------------------------------

    :createGpLinks
        set "str="%~1""
        set "str=!str:~2!"

        set "gp="!str:\rules=!"


        REM : if more than one folder level exist (V3 packs, get only the first level
        call:getFirstFolder rgp


        set "linkPath="!GAME_GP_FOLDER:"=!\!rgp:"=!""
        set "targetPath="!BFW_GP_FOLDER:"=!\!rgp:"=!""
        if ["!gfxType!"] == ["V2"] set "targetPath="!BFW_GP_FOLDER:"=!\_graphicPacksV2\!gp:"=!""

        if not exist !linkPath! mklink /J /D !linkPath! !targetPath!

    goto:eof
    REM : ------------------------------------------------------------------


    :importOtherGraphicPacks

        set "filter=%~1"
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLgp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:" 2^>NUL') do call:createGpLinks "%%i"

    goto:eof
    REM : ------------------------------------------------------------------


    :importGraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLgp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:" 2^>NUL') do call:createGpLinks "%%i"

    goto:eof
    REM : ------------------------------------------------------------------
