@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"
    title !THIS_SCRIPT!
    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    REM : directory of this script
    pushd "%~dp0" >NUL && set "BFW_TOOLS_PATH="!CD!"" && popd >NUL

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "antRenamerPath="!BFW_RESOURCES_PATH:"=!\Renamer.exe""
    set "antRenamerBatch="!BFW_RESOURCES_PATH:"=!\rename.arb""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSetAndLocale

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims==" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    REM : if a network connection was not found, exit 10
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        @echo No active connection was found, cancel updating
        exit /b 20
    )
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""

    REM : powerShell script in _BatchFW_Graphic_Packs
    set "pwsGetVersion="!BFW_PATH:"=!\resources\ps1\getLatestGP.ps1""

    set "lgpvLog="!BFW_PATH:"=!\logs\latestGraphicPackVersion.log""

    Powershell.exe -executionpolicy remotesigned -File !pwsGetVersion! *> !lgpvLog!
    if !ERROLEVEL! NEQ 0 (
        @echo Failed to get the last graphic Packs update available 
        type !lgpvLog!
        timeout /T 4 > NUL
        exit /b 10
    )
    
    for /F %%i in ('type !lgpvLog!') do set "zipFile=%%i"

    set "zipLogFile="!BFW_GP_FOLDER:"=!\!zipFile:.zip=.doNotDelete!""

    if exist !zipLogFile! (
        @echo No new graphic Packs update available, last version is still !zipFile!
        timeout /T 4 > NUL
        exit /b 20
    )
    if ["!zipFile!"] == ["graphicPacks.zip"] (
        @echo Searching for a new graphic packs release failed ^!
        @echo Network connection was refused^, please check you powerscript policy
        timeout /T 4 > NUL
        exit /b 30
    )

    @echo Do you want to update BatchFW^'s graphic pack folder to !zipFile! ^?
    call:getUserInput "Enter your choice ? : (n by default in 12sec)" "n,y" ANSWER 12
    if [!ANSWER!] == ["n"] (
        @echo Cancelled by user
        timeout /T 4 > NUL
        exit /b 40
    )

    REM : launch graphic pack update
    @echo =========================================================
    @echo Update BatchFW^'s graphic packs
    @echo ---------------------------------------------------------
    REM : copy powerShell script in _BatchFW_Graphic_Packs
    set "pws_src="!BFW_RESOURCES_PATH:"=!\ps1\updateGP.ps1""
    set "pws_target="!BFW_GP_FOLDER:"=!\updateGP.ps1""

    copy /Y !pws_src! !pws_target! > NUL
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo Error when copying !pws_src!
        exit /b 9
    )

    @echo Launching update to !zipFile!^.^.^.
    pushd !BFW_GP_FOLDER!

    REM : delete all V3 gp

    call:deleteV3gp

    REM : delete all previous update log files
    set "pat=!BFW_GP_FOLDER:"=!\graphicPacks*.doNotDelete"
    for /F %%a in ('dir /B !pat! 2^>NUL') do del /F "%%a"

    REM : launching powerShell script
    Powershell -executionpolicy remotesigned -File updateGP.ps1 *> updateGP.log
    set /A "cr=!ERRORLEVEL!"

    REM : rename folders that contains forbiden characters : & !
    set "pat="!BFW_GP_FOLDER:"=!\*.*""
    wscript /nologo !StartMinimized! !antRenamerPath! !antRenamerBatch! -aF !pat! -g -x

    pushd !GAMES_FOLDER!

    :waitingLoopProcesses
    for /F "delims=" %%j in ('wmic process get Commandline ^| find /V "wmic" ^| find /I "Renamer.exe" ^| find /V "find"') do (
        goto:waitingLoopProcesses
    )

    if !cr! NEQ 0 (
        @echo ERROR : While updating graphic packs folder ^!
        pause
        exit /b !cr!
    )

    exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : ------------------------------------------------------------------
    :deleteV3gp
        set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
        if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL

        set "fnrLogDV3gp="!BFW_PATH:"=!\logs\fnr_deleteV3gp.log""
        if exist !fnrLogDV3gp! del /F !fnrLogDV3gp!

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask rules.txt --includeSubDirectories --find "version = 3" --logFile !fnrLogDV3gp!


        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogDV3gp! ^| find "File:" ^| find /V "^!" 2^>NUL') do (
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""
            set "gp=!rulesFile:\rules.txt=!"

            rmdir /Q /S !gp! 2>NUL
        )

        if exist !fnrLogDV3gp! del /F !fnrLogDV3gp!
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
        set cr=!ERRORLEVEL!
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
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get char set code for current host
    :setCharSetAndLocale

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL
        call:log2HostFile "charCodeSet=%CHARSET%"

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic path Win32_OperatingSystem get Locale /value ^| find "="') do set "L0CALE_CODE=%%f"

        REM : set YES/NO according to locale (used to protect cmd windows when closing then with mouse)
        REM : default = ENG
        set "yes=y"
        set "no=n"

        if ["%L0CALE_CODE%"] == ["0407"] (
            REM : locale = GER
            set "yes=j"
            set "no=n"
        )
        if ["%L0CALE_CODE%"] == ["0C0a"] (
            REM : locale = SPA
            set "yes=s"
            set "no=n"
        )
        if ["%L0CALE_CODE%"] == ["040c"] (
            REM : locale = FRA
            set "yes=o"
            set "no=n"
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
