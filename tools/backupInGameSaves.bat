@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main


    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""


    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS="!BFW_PATH:"=!\logs""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : RAR.exe path
    set "rarExe="!BFW_PATH:"=!\resources\rar.exe""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% NEQ 5 (
        echo ERROR on arguments passed^!
        echo SYNTAX^: %THIS_FILE% GAME_FOLDER_PATH MLC01_FOLDER_PATH user endTitleId slotNumber
        echo given {%*}
        pause
        exit /b 99
    )

    REM : get and check MLC01_FOLDER_PATH
    set "GAME_FOLDER_PATH=!args[0]!"
    if not exist !GAME_FOLDER_PATH! (
        echo ERROR^: game^'s folder !GAME_FOLDER_PATH! does not exist^!
        pause
        exit /b 1
    )

    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[1]!"
    if not exist !MLC01_FOLDER_PATH! (
        echo ERROR^: mlc01 folder !MLC01_FOLDER_PATH! does not exist^!
        pause
        exit /b 3
    )

    set "user=!args[2]!"
    set "currentUser=!user:"=!"

    set "endTitleId=!args[3]!"
    set "endTitleId=!endTitleId:"=!"
    set "endTitleId=!endTitleId: =!"

    set "slotNumberStr=!args[4]!"
    set "slotNumberStr=!slotNumberStr:"=!"
    set /A "slotNumber=!slotNumberStr: =!"

    REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    set "inGameSavesFolder="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
    if not exist !inGameSavesFolder! mkdir !inGameSavesFolder! > NUL 2>&1

    pushd !inGameSavesFolder!
    set "rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!.rar""

    if !slotNumber! NEQ 0 set "rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!_slot!slotNumber!.rar""

    REM : if exists rename-it the time of the compression
    set "waitFile=!rarFile:.rar=.bfw_wait!"
    if exist !waitFile! del /F !waitFile! > NUL 2>&1

    if exist !rarFile! move /Y !rarFile! !waitFile! > NUL 2>&1

    set usrSaveFolder="!MLC01_FOLDER_PATH:"=!\usr\save"
    for /F "delims=~" %%i in ('dir /b /o:n /a:d !usrSaveFolder! 2^>NUL') do (
        call:compress "%%i" cr
    )
    REM : compression ok? finished
    if exist !rarFile! del /F !waitFile! > NUL 2>&1

    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :compress
        set "sf="!MLC01_FOLDER_PATH:"=!\usr\save\%~1\%endTitleId%""

        REM : check if a user folder exist
        set "userFolder="!sf:"=!\user"
        if not exist !userFolder! goto:eof

        if exist !sf! (
            wscript /nologo !StartHiddenWait! !rarExe! u -ed -ap"mlc01\usr\save\%~1" -ep1 -r -inul -w!BFW_LOGS! !rarFile! !sf! > NUL 2>&1
            set "%1=!ERRORLEVEL!"
        )

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

    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove special characters from %1 ^(such as ^&, ^(,^), ^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove special characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove special characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
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