@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    title Delete BatchFw^'s graphic packs

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 100
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS_PATH:"=!\Host_!USERDOMAIN!.log""
    set "GLFile="!BFW_LOGS_PATH:"=!\gamesLibrary.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : with no args treat all packs
    set "selected=ALL"

    if !nbArgs! NEQ 0 (
        set "titleId=!args[0]!"
        set "selected=!titleId:"=!"
    )
    
    if not ["!selected!"] == ["ALL"] (

        REM : check titleId
        call:strLength !selected! len

        if !len! NEQ 16 (
            echo ERROR^: !selected! is not a titleId^, exiting
            pause
            exit 99
        )

        type !wiiTitlesDataBase! | find /I "!selected!" > NUL 2>&1 && goto:deletePacks

        REM : else
        echo ERROR^: !selected! was not found in !wiiTitlesDataBase!^, exiting
        pause
        exit 50

    )

    :deletePacks

    REM : BatchFw common GFX packs foldr
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    if not exist !BFW_GP_FOLDER! (
        echo ERROR^: !BFW_GP_FOLDER! does not exist^, exiting
        pause
        exit 51
    )

    REM : cd to BFW_GP_FOLDER
    pushd !BFW_GP_FOLDER!
    cls
    if ["!selected!"] == ["ALL"] (
        title Delete all GFX packs created by BatchFw

        echo =========================================================
        echo Deleting all GFX packs created by BatchFw ^?
        echo.
        pause
        cls
        REM : search rules.txt file that contains BatchFw
        set "fnrSearch="!BFW_LOGS_PATH:"=!\fnr_deleteBatchFwGraphicPacks.log""
        if exist !fnrSearch! del /F !fnrSearch!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find "BatchFw" --logFile !fnrSearch!

        for /F "tokens=2-3 delims=." %%j in ('type !fnrSearch! ^| find /I /V "^!" ^| find "File:"') do (
            set "rulesFile="!BFW_GP_FOLDER:"=!%%j.%%k""
            set "gpFolder=!rulesFile:\rules.txt=!"

            for /F "delims=~" %%i in (!gpFolder!) do set "gfxPackName=%%~nxi"

            call:deleteFolder
        )
        REM : clean the game library log for all games and version of packs
        call:cleanGameLibFile "] graphic packs version"        
    ) else (

        set "gameTitle=NONE"

        for /F "delims=~; tokens=2" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!selected!';" 2^>NUL') do set "DescRead="%%i""
        REM : set Game title for packs (folder name)
        set "title=!DescRead:"=!"
        set "gameTitle=!title: =!"
        
        echo =========================================================
        echo Delete !gameTitle!'s GFX packs created by BatchFw ^?
        echo.
        pause
        cls
        set "fnrSearch="!BFW_LOGS_PATH:"=!\fnr_deleteBatchFwGraphicPacks_!gameTitle:"=!.log""
        
        if exist !fnrSearch! del /F !fnrSearch!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find !selected! --logFile !fnrSearch!

        for /F "tokens=2-3 delims=." %%j in ('type !fnrSearch! ^| find /I /V "^!" ^| find "File:"') do (
            set "rulesFile="!BFW_GP_FOLDER:"=!%%j.%%k""
            REM : this script is not intend to be called directlty by user
            REM : tid is supposed to correspond to a games for which BatchFw had created GFX packs
            REM : but in case of it had been substituate by official one, check if it is still a BatchFw one
            type !rulesFile! | find /I "BatchFw" > NUL 2>&1 && (

                set "gpFolder=!rulesFile:\rules.txt=!"
                for /F "delims=~" %%i in (!gpFolder!) do set "gfxPackName=%%~nxi"

                call:deleteFolder
            )
        )

        REM : clean the game library log for this game (all version of packs)
        call:cleanGameLibFile "[!selected!] graphic packs version"
    )
    if exist !fnrSearch! del /F !fnrSearch!
    echo =========================================================
    echo done successfully
    echo.
    pause
    exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :cleanGameLibFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!GLFile:"=!.bfw_tmp""

        type !GLFile! | find /I /V "!pat!" > !logFileTmp! 2>&1

        del /F /S !GLFile! > NUL 2>&1
        move /Y !logFileTmp! !GLFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :deleteFolder

        title Delete BatchFw^'s graphic packs created for !gameTitle!    
        set /A "attempt=1"
        :tryToDelete
        rmdir /Q /S !gpFolder! > NUL 2>&1
        if %ERRORLEVEL% NEQ 0 (
            echo ERROR^: Fail to delete folder, close any program that could use this location
            echo also check that you have the ownership on !gpFolder:"=!
            echo.
            choice /C yn /N /M "Retry (y/n)?"
            if !ERRORLEVEL! EQU 1 goto:tryToDelete
        )
        echo ^> !gpFolder:"=! deleted

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to compute string length
    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if %ERRORLEVEL% NEQ 0 (
            echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

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
