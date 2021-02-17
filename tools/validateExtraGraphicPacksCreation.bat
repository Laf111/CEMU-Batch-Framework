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
    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""

    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""

    REM : temporary folder for symlinks creation
    set "gfxpLinksFolder="!BFW_PATH:"=!\logs\gfxpLinksFolder""

    if exist !gfxpLinksFolder! rmdir /Q /S !gfxpLinksFolder! > NUL 2>&1
    mkdir !gfxpLinksFolder! > NUL 2>&1

    REM : set current char codeset
    call:setCharSetOnly

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )

    cls
    echo =========================================================
    echo Check last GFX packs version completion
    echo =========================================================
    echo.

    REM : flag for creating old update and DLC paths
    set /A "buildOldUpdatePaths=1"

    REM : get the last version of GFX packs downloaded
    set "newVersion=NOT_FOUND"

    set "pat="!BFW_GP_FOLDER:"=!\graphicPacks*.doNotDelete""

    REM : --------------------------------------------------------------------------------------
    REM : get the github version of the last downloaded packs
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
    echo ^> last github repository version downloaded      ^: !newVersion!

    set "setup="!BFW_PATH:"=!\setup.bat""

    set "strBfwMaxVgfxp=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION=" 2^>NUL') do set "strBfwMaxVgfxp=%%i"
    set "strBfwMaxVgfxp=!strBfwMaxVgfxp:"=!"
    set /A "gfxPackVersion=!strBfwMaxVgfxp:V=!"

    echo ^> last version of GFX packs supported by BatchFw ^: !strBfwMaxVgfxp!

    REM : force GAME_GP_FOLDER
    set "GAME_GP_FOLDER=!gfxpLinksFolder!"

    pushd !BFW_GP_FOLDER!
    REM : V6 and up gfx packs
    for /F "delims=~" %%i in ('dir /B /S /A:D Graphics 2^> NUL') do (
        call:treatGpLatestVersion "%%i"
    )

    if exist !gfxpLinksFolder! del /F /S !gfxpLinksFolder! > NUL 2>&1

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
    
    :createPacks

        set "argSup=%gameName%"
        if ["%gameName%"] == [""] set "argSup="

        echo Complete resolution graphic packs^.^.^.
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createExtraGraphicPacks.bat""
        call !toBeLaunch! !rulesFile! %titleId%

        echo Create BatchFW FPS cap graphic packs^.^.^.
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createCapGraphicPacks.bat""
        echo !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !strBfwMaxVgfxp! %titleId% !argSup!

        call !toBeLaunch! !BFW_GP_FOLDER!  !GAME_GP_FOLDER! !strBfwMaxVgfxp! %titleId% !argSup!

    goto:eof
    REM : ------------------------------------------------------------------
    
    :treatGpLatestVersion
        set "graphicsFolder="%~1""

        for %%a in (!graphicsFolder!) do set "parentFolder="%%~dpa""
        set "gamePackFolder=!parentFolder:~0,-2!""

        for /F "delims=~" %%i in (!gamePackFolder!) do set "gameName=%%~nxi"
        set "rulesFile="!graphicsFolder:"=!\rules.txt""

        for /F "tokens=2 delims=~=," %%k in ('type !rulesFile! ^| find "titleIds"') do set "titleId=%%k"
        set "titleId=!titleId: =!"
        echo #########################################################
        echo !gameName! [!titleId!]
        echo #########################################################

        echo Found a resolution graphic pack ^: !rulesFile!
        call:createPacks

        REM : update !glogFile! (log2GamesLibraryFile does not add a already present message in !glogFile!)
        set "msg="!gameName! [%titleId%] graphic packs version=!newVersion!""
        call:log2GamesLibraryFile !msg!

    goto:eof