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
    pushd "%~dp0" >NUL && set "BFW_TOOLS_PATH="!CD!"" && popd >NUL

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""


    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS_PATH:"=!\Host_!USERDOMAIN!.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end
    
    REM : silent mode
    set /A "QUIET_MODE=0"
    set /A "FORCED_MODE=0"
    if !nbArgs! NEQ 0 (
        if [!args[0]!] == ["-silent"] set /A "QUIET_MODE=1"
        if [!args[0]!] == ["-forced"] set /A "FORCED_MODE=1"
    )
    
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
    if !ERRORLEVEL! EQU 1 (
        @echo Failed to get the last graphic Packs update available 
        type !lgpvLog!
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL
        exit /b 10
    )
    for /F %%i in ('type !lgpvLog!') do set "zipFile=%%i"

    set "zipLogFile="!BFW_GP_FOLDER:"=!\!zipFile:.zip=.doNotDelete!""
    if exist !zipLogFile! (
        @echo No new graphics packs update^(s^) available^, last version is still !zipFile:.zip=!
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL
        exit /b 0
    )
    if ["!zipFile!"] == ["graphicPacks.zip"] (
        @echo Searching for a new graphic packs release failed ^!
        @echo Network connection was refused^, please check you powerscript policy
        if !QUIET_MODE! EQU 0 timeout /T 4 > NUL
        exit /b 30
    )
    if !FORCED_MODE! EQU 1 goto:noMsg 
    if !QUIET_MODE! EQU 1 goto:msgBox 
    @echo Do you want to update BatchFW^'s graphic pack folder to !zipFile:.zip=! ^?
    call:getUserInput "Enter your choice ? : (n by default in 12sec)" "n,y" ANSWER 12
    if [!ANSWER!] == ["n"] (
        @echo Cancelled by user
        timeout /T 4 > NUL
        exit /b 40
    )
    goto:updateGP
    
    :msgBox    
    cscript /nologo !MessageBox! "A graphic packs update is available^, do you want to update to !zipFile:.zip=! ^?" 4161
    if !ERRORLEVEL! EQU 2 exit 0
    
    :updateGP    

    REM : launch graphic pack update
    if !QUIET_MODE! EQU 0 @echo =========================================================
    if !QUIET_MODE! EQU 0 @echo Updating BatchFW^'s graphic packs
    if !QUIET_MODE! EQU 0 @echo ---------------------------------------------------------
    
    
    :noMsg
    REM : copy powerShell script in _BatchFW_Graphic_Packs
    set "pws_src="!BFW_RESOURCES_PATH:"=!\ps1\updateGP.ps1""
    
    REM : temporary folder
    set "BFW_GP_TMP="!BFW_PATH:"=!\logs\gpUpdateTmpDir""
    if not exist !BFW_GP_TMP! mkdir !BFW_GP_TMP!
    
    set "pws_target="!BFW_GP_TMP:"=!\updateGP.ps1""

    copy /Y !pws_src! !pws_target! > NUL
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo Error when copying !pws_src!
        exit /b 9
    )

    if !FORCED_MODE! EQU 0 @echo Launching graphic pack update to !zipFile!^.^.^.
    if !FORCED_MODE! EQU 1 @echo Installing !zipFile!^.^.^.
    
    pushd !BFW_GP_TMP!

    REM : launching powerShell script to downaload and extract GFX archive
    Powershell -executionpolicy remotesigned -File updateGP.ps1 *> updateGP.log
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo ERROR While getting and extracting graphic packs folder ^!
        if !QUIET_MODE! EQU 0 pause
        pushd !GAMES_FOLDER!
        rmdir /Q /S !BFW_GP_TMP! > NUL
        exit /b !cr!
    )

    REM : rename folders that contains forbiden characters : & ! .
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!BFW_GP_TMP! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE

    pushd !GAMES_FOLDER!
    
    REM : delete all V3 gp under BFW_GP_FOLDER
    call:deleteV3gp  
    REM : delete all previous update log files in BFW_GP_FOLDER
    set "pat=!BFW_GP_FOLDER:"=!\graphicPacks*.doNotDelete"
    for /F %%a in ('dir /B !pat! 2^>NUL') do del /F "%%a"    
    
    REM : filter graphic pack folder
    set "script="!BFW_TOOLS_PATH:"=!\filterGraphicPackFolder.bat""
    if !QUIET_MODE! EQU 0 wscript /nologo !StartHiddenWait! !script!    
    if !QUIET_MODE! EQU 1 wscript /nologo !StartHidden! !script!
    
    if exist !BFW_GP_TMP! rmdir /Q /S !BFW_GP_TMP! > NUL
    
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
