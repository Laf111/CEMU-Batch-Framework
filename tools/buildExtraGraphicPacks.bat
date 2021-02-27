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
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "fnrLogUggp="!BFW_PATH:"=!\logs\fnr_buildExtraGraphicPacks.log""
    REM : gamesLibrary.log
    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""


    set "uggp="!BFW_TOOLS_PATH:"=!\updateGamesGraphicPacks.bat""

    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    set "gfxPacksV4Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV4""
    set "gfxPacksV2Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
    
    REM : set current char codeset
    call:setCharSetOnly

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

    REM : --------------------------------------------------------------------------------------
    REM : loop on games and complete/create GFX packs

    pushd !GAMES_FOLDER!

    REM : searching for meta file
    for /F "delims=~" %%m in ('dir /B /S meta.xml 2^> NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        REM : meta.xml
        set "META_FILE="%%m""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%k""
        for /F "delims=<" %%j in (!titleLine!) do set "titleId=%%j"

        REM : compute GAME_GP_FOLDER (used by createGameGraphicPacks)

        set "GAME_FOLDER_PATH=!META_FILE:\meta\meta.xml=!"
        set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\GraphicPacks""


        REM : get information on game using WiiU Library File
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!titleId!';"') do set "libFileLine="%%i""

        if [!libFileLine!] == ["NONE"] wscript /nologo !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112

        REM : strip line to get data
        for /F "tokens=1-12 delims=;" %%a in (!libFileLine!) do (
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
           set "typeCapFps=%%l"
        )
        set /A "resX2=!nativeHeight!*2"

        call:treatGame

        echo done for !GAME_FOLDER_PATH:%GAMES_FOLDER%=!
    )

    pause
    goto:eof
REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

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

    :createPacks

        set "argSup=%gameName%"
        if ["%gameName%"] == [""] set "argSup="

        REM : if a macthing res gfx pack was found, check the a recent update
        if !resGfxPvFound! NEQ 0 goto:createExtraGP

        echo Create BatchFW resolution graphic packs^.^.^.
        REM : Create game's graphic pack
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createGameGraphicPacks.bat""
        echo !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! "V!vGfxPack!" %titleId% !argSup!
        call !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! "V!vGfxPack!" %titleId% !argSup!
        goto:createCapGP

        :createExtraGP
        echo Complete resolution graphic packs^.^.^.
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createExtraGraphicPacks.bat""
        echo !toBeLaunch! !resGfxPack! %titleId%
        call !toBeLaunch! !resGfxPack! %titleId% 

        :createCapGP
        echo Create BatchFW FPS cap graphic packs^.^.^.
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createCapGraphicPacks.bat""
        echo !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! "V!vGfxPack!" %titleId% !argSup!
        call !toBeLaunch! !BFW_GP_FOLDER!  !GAME_GP_FOLDER! "V!vGfxPack!" %titleId% !argSup!

    goto:eof
    REM : ------------------------------------------------------------------

    REM : search gfx packs for VgfxPackVersion [4, 999]
    :searchResolutionGfxPacks

        REM : loop on the gfx packs found (reversed list => _graphicPacksVi (i decreasing)
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! 2^>NUL ^| find "File:" ^| find /I /V "_BatchFw" ^| sort /R') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""
            REM : Get the version of the GFX pack (res or not)
            set "vGfxPackStr=NOT_FOUND"

            for /F "delims=~= tokens=2" %%i in ('type !rulesFile! 2^>NUL ^| find /I "Version"') do set "vGfxPackStr=%%i"
            if ["!vGfxPackStr!"] == ["NOT_FOUND"] (
                echo ERROR : version was not found in !rulesFile! >> !myLog!
                echo ERROR : version was not found in !rulesFile!
            ) else (
                set "vGfxPackStr=!vGfxPackStr: =!"
                set /A "vGfxPack=!vGfxPackStr!"
                set /A "resPackFlag=1"
                REM : search for a resolution pack

                echo !rulesFile! | findStr /R /V "Resolution\\rules\.txt" | findStr /R /V "Graphics\\rules\.txt" | findStr /R /V "_%resX2%p\\rules\.txt" > NUL 2>&1 && set /A "resPackFlag=0"
                if !resPackFlag! EQU 1 (

                    set "resGfxPack=!rulesFile!"

                    set "rulesFolder=!rulesFile:\rules.txt=!"
                    if !vGfxPack! GEQ 6 (
                        REM : V6
                        for %%a in (!rulesFolder!) do set "parentFolder="%%~dpa""
                        set "titleFolder=!parentFolder:~0,-2!""
                        for /F "delims=~" %%i in (!titleFolder!) do set "gameName=%%~nxi"
                    ) else (
                        REM : V4
                        if !vGfxPack! GEQ 3 (
                            echo !rulesFile! | find /I "\Graphics" > NUL 2>&1 && (
                                for %%a in (!rulesFolder!) do set "parentFolder="%%~dpa""
                                set "titleFolder=!parentFolder:~0,-2!""

                                for /F "delims=~" %%i in (!titleFolder!) do set "gameName=%%~nxi"
                            )
                            echo !rulesFile! | find /I "_Resolution\" > NUL 2>&1 && (
                                for /F "delims=~" %%i in (!rulesFolder!) do set "gameName=%%~nxi"
                                set "gameName=!gameName:_Resolution=!"
                            )
                        ) else (
                            REM : V2
                            set "str=%%i"
                            set "str=!str:rules=!"
                            set "str=!str:\_graphicPacksV2=!"
                            set "str=!str:\=!"
                            set "gameName=!str:_%resX2%p=!"
                        )
                    )
                    echo Found a V!vGfxPack! resolution graphic pack ^: !rulesFile!
                    set "resGfxPvFound=!vGfxPack!"

                    call:createPacks
                )
            )
        )
        if !resGfxPvFound! EQU 0 (
            set "gameName=!DescRead: =!"
            call:createPacks
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :treatGame

        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        REM : Complete/create last gfx packs version in FIRST (reverse loop in updateGamesGraphicPacks.bat)
        echo #########################################################
        echo !GAME_TITLE! packs
        echo #########################################################

        if exist !fnrLogUggp! del /F !fnrLogUggp! > NUL 2>&1
        REM : launching the search in all gfx pack folder (V2 and up)
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogUggp!

        set "resGfxPvFound=0"
        set "resGfxPack="NOT_FOUND""
        set "gameName="

        call:searchResolutionGfxPacks

        REM : update !glogFile! (log2GamesLibraryFile does not add a already present message in !glogFile!)
        set "msg="!GAME_TITLE! [%titleId%] graphic packs version=!newVersion!""
        call:log2GamesLibraryFile !msg!

        REM : for older packs, it done in scripts called


        echo #########################################################

    goto:eof
    