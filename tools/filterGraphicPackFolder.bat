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

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    set "BFW_GP_TMP="!BFW_PATH:"=!\logs\gpUpdateTmpDir""
    if not exist !BFW_GP_TMP! exit 10
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if not exist !BFW_GP_FOLDER! exit 20

    REM create a log file containing all your games titleId
    set "tidLog="!BFW_LOGS:"=!\myTitleIds.log""

    if exist !tidLog! del /F !tidLog!

    pushd !GAMES_FOLDER!

    REM : searching for meta file
    for /F "delims=" %%i in ('dir /B /S meta.xml ^|  find /I /V "\mlc01" 2^> NUL') do (

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        for /F "delims=<" %%i in (!titleLine!) do set /A "NB_GAMES+=1" && echo %%i >> !tidLog!

    )

    if !NB_GAMES! EQU 0 exit 30

    for /F "delims=~=" %%i in ('type !tidLog! 2^>NUL') do call:checkGP %%i

    if exist !BFW_GP_TMP! rmdir /Q /S !BFW_GP_TMP! > NUL 2>&1

    if !cr! NEQ 0 exit !cr!
    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :checkGp
        set "titleId=%~1"
        set "titleId=%titleId: =%"

        set "fnrLogfgf="!BFW_PATH:"=!\logs\fnr_filterGraphicPackFolder.log""
        if exist !fnrLogfgf! del /F !fnrLogfgf!

        REM : launching the search
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_TMP! --fileMask rules.txt --includeSubDirectories --find %titleId% --logFile !fnrLogfgf! > NUL

        for /F "tokens=2-3 delims=." %%j in ('type !fnrLogfgf! ^| find "File:"') do (

            set "str=%%j"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_TMP:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )
            set "gp="!BFW_GP_TMP:"=!\!gp:\=!""

            if exist !gp! move /Y !gp! !BFW_GP_FOLDER! > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"
        )
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
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------



    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
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
        echo !msg! >> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
