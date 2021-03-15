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
    set "glogFile="!BFW_LOGS_PATH:"=!\gamesLibrary.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!
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

    REM : execution modes
    set /A "WARN_MODE=0"
    set /A "QUIET_MODE=0"
    set /A "FORCED_MODE=0"
    if !nbArgs! NEQ 0 (
        if [!args[0]!] == ["-warn"] set /A "WARN_MODE=1" & set /A "QUIET_MODE=1"
        if [!args[0]!] == ["-silent"] set /A "QUIET_MODE=1"
        if [!args[0]!] == ["-forced"] set /A "FORCED_MODE=1"
        if [!args[0]!] == ["-forcedSilent"] set /A "FORCED_MODE=1" & set /A "FORCED_MODE_SLIENT=1"
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    REM : if a network connection was not found, exit 10
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo No active connection was found, cancel updating
        exit /b 20
    )
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    REM : powerShell script in _BatchFW_Graphic_Packs
    set "pwsGetVersion="!BFW_PATH:"=!\resources\ps1\getLatestGP.ps1""

    set "lgpvLog="!BFW_PATH:"=!\logs\latestGraphicPackVersion.log""

    Powershell.exe -executionpolicy bypass -File !pwsGetVersion! *> !lgpvLog!
    if !ERRORLEVEL! EQU 1 (
        echo Failed to get the last graphic Packs update available
        type !lgpvLog!
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL 2>&1
        exit /b 10
    )
    for /F %%i in ('type !lgpvLog!') do set "zipFile=%%i"

    set "zipLogFile="!BFW_GP_FOLDER:"=!\!zipFile:.zip=.doNotDelete!""
    if exist !zipLogFile! (
        echo No new graphics packs update available^, last version is still !zipFile:.zip=!
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL 2>&1
        exit /b 1
    )
    if ["!zipFile!"] == ["graphicPacks.zip"] (
        echo Searching for a new graphic packs release failed ^!
        echo Network connection was refused^, please check you powerscript policy
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL 2>&1
        exit /b 30
    )
    if ["!zipFile!"] == [""] (
        echo Searching for a new graphic packs release failed ^!
        echo Network connection was refused^, please check you powerscript policy
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL 2>&1
        exit /b 31
    )
    if !FORCED_MODE! EQU 1 goto:noMsg
    if !QUIET_MODE! EQU 1 goto:msgBox
    echo Do you want to update BatchFW^'s graphic pack folder to !zipFile:.zip=! ^?
    call:getUserInput "Enter your choice ? : (n by default in 30sec)" "n,y" ANSWER 30
    if [!ANSWER!] == ["n"] (
        echo Cancelled by user
        timeout /T 4 > NUL 2>&1
        exit /b 2
    )
    goto:updateGP

    :msgBox

    if !WARN_MODE! EQU 1 (
        wscript /nologo !Start! !MessageBox! "A graphic packs update is available^, use Wii-U Games^\Update my graphic packs to latest^.lnk to update to !zipFile:.zip=!"
        exit /b 0
    ) else (
        !MessageBox! "A graphic packs update is available^, do you want to update to !zipFile:.zip=! ?" 4161
        if !ERRORLEVEL! EQU 2 exit /b 2
    )
    :updateGP
    
    REM : launch graphic pack update
    if !QUIET_MODE! EQU 0 echo =========================================================
    if !QUIET_MODE! EQU 0 echo Updating BatchFW^'s graphic packs
    if !QUIET_MODE! EQU 0 echo ---------------------------------------------------------


    :noMsg
    if !QUIET_MODE! EQU 0 title Updating GFX packs to !zipFile:.zip=!
    REM : clean old packs
    for /F "delims=~" %%a in ('dir /A:D /B !BFW_GP_FOLDER! 2^>NUL ^| find /I /V "_graphicPacksV"') do (
        set "pack="!BFW_GP_FOLDER:"=!\%%a""
        if exist !pack! rmdir /Q /S !pack! > NUL 2>&1
    )

    REM : copy powerShell script in _BatchFW_Graphic_Packs
    set "pws_src="!BFW_RESOURCES_PATH:"=!\ps1\updateGP.ps1""

    REM : BatchFw's GFX packs folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if not exist !BFW_GP_FOLDER! mkdir !BFW_GP_FOLDER! > NUL 2>&1
    set "pws_target="!BFW_GP_FOLDER:"=!\updateGP.ps1"" > NUL 2>&1
    set "uplog="!BFW_GP_FOLDER:"=!\updateGP.log""

    copy /Y !pws_src! !pws_target! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo Error when copying !pws_src!
        exit /b 9
    )

    if !FORCED_MODE! EQU 0 echo Launching graphic pack update to !zipFile!^.^.^.
    if !FORCED_MODE! EQU 1 echo Installing !zipFile!^.^.^.

    pushd !BFW_GP_FOLDER!

    REM : launching powerShell script to downaload and extract GFX archive
    Powershell -executionpolicy bypass -File updateGP.ps1 *> updateGP.log
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR While getting and extracting graphic packs folder ^!
        if !QUIET_MODE! EQU 0 pause
        pushd !GAMES_FOLDER!
        rmdir /Q /S !BFW_GP_FOLDER! > NUL 2>&1
        exit /b !cr!
    )

    REM : rename folders that contains forbiden characters : & ! . ( )
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /REPLACECI^:^^(^:[ /REPLACECI^:^^)^:] /EXECUTE /RECURSIVE

    REM : delete all previous update log files in BFW_GP_FOLDER
    set "pat="graphicPacks*.doNotDelete""
    for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do del /F "%%a"

    set "noDelFile=!BFW_GP_FOLDER:"=!\!zipFile:zip=doNotDelete!"
    echo !DATE! ^: !USERNAME! on !USERDOMAIN! > !noDelFile!
    del /F !pws_target! > NUL 2>&1
    del /F !uplog! > NUL 2>&1

    type !logFile! | find /I "COMPLETE_GP=YES" > NUL 2>&1 && (

        if !QUIET_MODE! EQU 0 if !FORCED_MODE_SLIENT! EQU 0 (
            echo.
            echo If you do not plan to play at once^, you can now complete GFX packs
            echo for ALL your games in a row ^? ^(to avoid build on each next run^)
            echo.
            call:getUserInput "Do you want to complete GFX packs for ALL your games ? : (y by default in 30sec)" "y,n" ANSWER 30
            if [!ANSWER!] == ["n"] goto:flushGLogFile

            pushd !BFW_TOOLS_PATH!

            REM : complete all GFX packs for games installed
            set "tobeLaunch="!BFW_PATH:"=!\tools\buildExtraGraphicPacks.bat""
            wscript /nologo !Start! !tobeLaunch!

        )

        :flushGLogFile
        REM : in all case and specially when the updated is forced, clean all version used for completing GFX packs in glogFile
        REM : it will also force to rebuild older packs on the next run (and take eventually new aspect ratios into account)
        if exist !glogFile! (
            REM : clean log file for all games and GFX packs version (force to eventually add new aspect ratios)
            call:cleanGameLogFile "graphic packs version"
        )
    )
    exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :cleanGameLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.bfw_tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get user input in allowed valuesList (beginning with default timeout value) from question and return the choice
    :getUserInput

        REM : arg1 = question
        set "question="%~1""
        REM : arg2 = valuesList
        set "valuesList=%~2"
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional : if given set 1st value as default value after timeOutValue seconds)
        set "timeOutValue=%~4"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if ["%timeOutValue%"] == [""] (
            set choiceCmd=choice /C %choiceValues% /CS /N /M !question!
        ) else (
            set choiceCmd=choice /C %choiceValues% /CS /N /T %timeOutValue% /D %defaultTimeOutValue% /M !question!
        )

        REM : launching and get return code
        !choiceCmd!
        set /A "cr=!ERRORLEVEL!"
        set j=1
        for %%i in ("%valuesList:,=" "%") do (

            if [!cr!] == [!j!] (
                REM : value found , return function value
                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
        )

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
        if !ERRORLEVEL! NEQ 0 (
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
