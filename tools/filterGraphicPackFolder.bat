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
        exit 1
    )
  
    REM : directory of this script
    pushd "%~dp0" >NUL && set "BFW_TOOLS_PATH="!CD!"" && popd >NUL

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    
    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSetAndLocale

    set "BFW_GP_TMP="!BFW_PATH:"=!\logs\gpUpdateTmpDir""    
    if not exist !BFW_GP_TMP! exit 10
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""
    if not exist !BFW_GP_FOLDER! exit 20
    
    REM create a log file containing all your games titleId
    set "tidLog="!BFW_LOGS:"=!\myTitleIds.log""
    
    if exist !tidLog! del /F !tidLog!
    
    pushd !GAMES_FOLDER!
    
    REM : searching for code folder to find in only one rpx file (the bigger one)
    for /F "delims=" %%i in ('dir /B /S meta.xml ^|  find /V "\mlc01" 2^> NUL') do (

        REM : meta.xml
        set "META_FILE="%%i""
    
        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        for /F "delims=<" %%i in (!titleLine!) do set /A "NB_GAMES+=1" && echo %%i >> !tidLog!
    
    )    
    
    if !NB_GAMES! EQU 0 exit 30
    
    REM : cd to BFW_GP_FOLDER
    pushd !BFW_GP_TMP!
    
    REM : loop on the gfx folders found
    for /F "delims=" %%i in ('dir /b /o:n /s rules.txt 2^>NUL') do (

        set "rulesFile="%%i""
        
        set /A "found=0"
        call:checkGp
        if ["!found!"] == ["1"] (
            for /F %%j in (!rulesFile!) do set "parentFolder="%%~dpj""
            set "folder=!parentFolder:~0,-2!""

            move /Y !folder! !BFW_GP_FOLDER! > NUL
            set /A "cr=!ERRORLEVEL!"
        )
    )
    
    set "pat="!BFW_GP_TMP:"=!\graphicPacks*.doNotDelete!""
    move !pat! !BFW_GP_FOLDER! > NUL
    
    pushd !GAMES_FOLDER!
    if exist !BFW_GP_TMP! rmdir /Q /S !BFW_GP_TMP! > NUL
    
    if !cr! NEQ 0 exit !cr!
    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :checkGp 


        set "titleLine="NONE""
        for /F "tokens=1-2 delims==" %%i in ('type !rulesFile! ^| find "titleIds"') do set "titleLine=%%j"
        if [!titleLine!] == ["NONE"] goto:eof
        set "titleLine=!titleLine:,= !"
        
        REM : loop on titleId for this game
        for %%a in (!titleLine!) do (
            set "tid=%%a"
            set "tid=!tid: =!"
            
            type !tidLog! | find /I "!tid!" > NUL && set /A "found=1" && goto:eof
        )
        set /A "found=0"

    goto:eof
    REM : ------------------------------------------------------------------

    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
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
        echo !msg! >> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
