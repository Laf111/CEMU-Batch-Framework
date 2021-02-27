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

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""

    set "cgpLogFile="!BFW_LOGS:"=!\createExtraGraphicPacks.log""

    set "completeLastGraphicPacks="!BFW_TOOLS_PATH:"=!\completeLastGraphicPacks.bat""
    set "completeV4="!BFW_TOOLS_PATH:"=!\completeV4GraphicPacks.bat""
    set "completeV2="!BFW_TOOLS_PATH:"=!\completeV2GraphicPacks.bat""

    REM : set current char codeset
    call:setCharSet


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
    echo. > !cgpLogFile!

    if %nbArgs% NEQ 2 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" RULES_FILE TITLE_ID>> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" RULES_FILE TITLE_ID
        echo given {%*} >> !cgpLogFile!
        echo given {%*}

        exit /b 99
    )

    set "rulesFile=!args[0]!"
    set "titleId=!args[1]!"
    set "titleId=!titleId:"=!"
    set "titleId=!titleId: =!"

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


    echo Completing V!vGfxPack! pack^.^.^.  >> !cgpLogFile!
    echo Completing V!vGfxPack! pack^.^.^.

    set "rulesFolder=!rulesFile:\rules.txt=!"

    if !vGfxPack! GTR 2 goto:V4packs
    REM : V2 packs
    echo !completeV2! !rulesFile! >> !cgpLogFile!
    echo !completeV2! !rulesFile!

    REM : for V2 packs, as new folders are created and linked afterward in updateGamesGraphicPacks.bat
    REM : do not wait
    call !completeV2! !rulesFile!

    for /F "delims=~" %%i in (!rulesFolder!) do set "gpNameFolder=%%~nxi"
    set "GAME_TITLE=!gpNameFolder:_%resX2%p=!"

    REM : update !glogFile! (log2GamesLibraryFile does not add a already present message in !glogFile!)
    set "msg="!GAME_TITLE! [%titleId%] graphic packs versionV2=completed""
    call:log2GamesLibraryFile !msg!
    
    goto:endMain

    :V4packs
    if !vGfxPack! GEQ 6 goto:V6packs

    REM : V4 packs
    echo !completeV4! !rulesFile! >> !cgpLogFile!
    echo !completeV4! !rulesFile!

    call !completeV4! !rulesFile!

    set "GAME_TITLE=!gpNameFolder:_resolution=!"
    
    REM : update !glogFile! (log2GamesLibraryFile does not add a already present message in !glogFile!)
    set "msg="!GAME_TITLE! [%titleId%] graphic packs versionV4=completed""
    call:log2GamesLibraryFile !msg!

    goto:endMain

    :V6packs
    REM : V6 packs
    echo !completeLastGraphicPacks! !rulesFile! >> !cgpLogFile!
    echo !completeLastGraphicPacks! !rulesFile!

    call !completeLastGraphicPacks! !rulesFile!

    REM : !glogFile! is updated in updateGamesGraphicPacks

    :endMain
    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "endingDate=%ldt%"
    REM : starting DATE

    echo ========================================================= >> !cgpLogFile!
    echo =========================================================

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
