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

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : cd to BFW_TOOLS_PATH
    pushd !BFW_TOOLS_PATH!

    REM : get current date
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"


    if not exist !logFile! (
        @echo !logFile:"=! not found^, cancelling
        pause
        goto:eof
    )
    cls
    @echo =========================================================
    REM : search your current GLCache
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence

    set "OPENGL_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"

    if not [!OPENGL_CACHE!] == ["NOT_FOUND"] if exist !OPENGL_CACHE! goto:glCacheFound

    REM : else search it
    pushd "%LOCALAPPDATA%"
    set "cache="NOT_FOUND""
    for /F "delims=" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if [!cache!] == ["NOT_FOUND"] pushd "%APPDATA%" && for /F "delims=" %%x in ('dir /b /o:n /a:d /s GLCache 2^>NUL') do set "cache="%%x""
    if not [!cache!] == ["NOT_FOUND"] set "OPENGL_CACHE=!cache!"
    pushd !BFW_TOOLS_PATH!

    if [!OPENGL_CACHE!] == ["NOT_FOUND"] (
        @echo Unable to find your GPU GLCache folder ^? cancelling
        goto:eof
    )
    REM : save path to log file
    set "msg="OPENGL_CACHE=!OPENGL_CACHE:"=!""
    call:log2HostFile !msg!

    REM : openGL cache location
    :glCacheFound

    set "GLCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuGLCache!"

    set "size=0"
    if exist !GLCacheSavesFolder! call:getFolderSize !GLCacheSavesFolder! size
    @echo Global OpenGL Cache size ^(Mo^) ^: %size%
    @echo ---------------------------------------------------------

    for /F "delims=" %%x in ('dir /b /o:n /a:d !GLCacheSavesFolder! 2^>NUL') do (

        set "gpuVersion="!GLCacheSavesFolder:"=!\%%x""
        call:getGameCacheSize
    )
    pushd !BFW_TOOLS_PATH!

    @echo =========================================================

    REM : search in logFile
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "install folder path" 2^>NUL') do (
        call:getCachesSizes "%%i"
    )

    @echo This windows will close automatically in 12s
    @echo     ^(n^) ^: don^'t close^, i want to read history log first
    @echo     ^(q^) ^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "- Enter your choice ? : " "q,n" ANSWER 12
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    if %nbArgs% EQU 0 endlocal
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :getGameCacheSize

        pushd !gpuVersion!
        for /F "delims=" %%y in ('dir /b /o:n /a:d * 2^>NUL') do (

            set "gameGLCacheFolder="!gpuVersion:"=!\%%y""
            set "sizeG=0"
            call:getFolderSize !gameGLCacheFolder! sizeG
            @echo - %%y shader cache size ^: !sizeG!
        )
        cd ..

    goto:eof
    REM : ------------------------------------------------------------------

    :getCachesSizes

        set "CEMU_FOLDER="%~1""

        REM : get version
        for %%a in (!CEMU_FOLDER!) do set CEMU_FOLDER_NAME="%%~nxa"

        REM : if CEMU_FOLDER not exist anymore
        if not exist !CEMU_FOLDER! (
            @echo !CEMU_FOLDER:"=! doesn^'t exist anymore^, cleaning logFile
            call:cleanHostLogFile !CEMU_FOLDER_NAME!
            goto:eof
        )

        @echo Size of !CEMU_FOLDER_NAME:"=! subfolders ^(Mo^) ^:
        @echo ---------------------------------------------------------


        :precompiled
        set "precompiled="!CEMU_FOLDER:"=!\ShaderCache\precompiled""
        set "sizeP=0"
        if exist !precompiled! call:getFolderSize !precompiled! sizeP
        @echo - precompiled     ^: %sizeP%

        :transferable
        set "transferable="!CEMU_FOLDER:"=!\ShaderCache\transferable""
        set "sizeT=0"
        if exist !transferable! call:getFolderSize !transferable! sizeT
        @echo - transferable    ^: %sizeT%
        @echo =========================================================

    goto:eof
    REM : ------------------------------------------------------------------

    :getFolderSize

        set "folder="%~1""
        REM : prevent path to be stripped if contain '
        set "folder=!folder:'=`'!"
        set "folder=!folder:[=`[!"
        set "folder=!folder:]=`]!"
        set "folder=!folder:)=`)!"
        set "folder=!folder:(=`(!"

        set "psCommand=-noprofile -command "ls -r '!folder:"=!' | measure -s Length""

        set "line=NONE"
        for /F "usebackq tokens=2 delims=:" %%a in (`powershell !psCommand! ^| find /I "Sum"`) do set "line=%%a"
        REM : powershell call always return %ERRORLEVEL%=0
        if ["!line!"] == ["NONE"] (
            set "%2=0"
            goto:eof
        )

        set "sizeRead=!line: =!"

        if ["%sizeRead%"] == [" ="] (
            set "%2=0"
            goto:eof
        )

        if not ["%sizeRead%"] == ["0"] set "%2=%sizeRead:~,-6%"
        if ["%sizeRead%"] == [""] set "%2=0"

    goto:eof

    :cleanHostLogFile
        REM : patern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.tmp""

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL
        move /Y !logFileTmp! !logFile! > NUL

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

            if [%cr%] == [!j!] (
                REM : value found , return function value

                set /A "ERRORLEVEL=0" & set "%3=%%i"
                goto:eof
            )
            set /A j+=1
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
        dir !toCheck! > NUL
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
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL
        call:log2HostFile "charCodeSet=%CHARSET%"

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
