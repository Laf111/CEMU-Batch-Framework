@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    set "THIS_SCRIPT=%~0"

    title Import a transferable cache for a game

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
    set "getShaderCacheFolder="!BFW_RESOURCES_PATH:"=!\getShaderCacheName""

    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "browseFile="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFileDialog.vbs""

    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% EQU 0 goto:beginImport
    if %nbArgs% NEQ 2 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" GAME_FOLDER_PATH ShaderCacheName
        echo given {%*}
        pause
        exit 1
    )

    set "GAME_FOLDER_PATH=!args[0]!"

    set "sci=!args[1]!"
    set "sci=!sci:"=!"

    :beginImport
    cls
    echo =========================================================
    echo Import a transferable cache file
    echo =========================================================
    echo.

    REM : browse to the file
    :askInputFile
    echo.
    echo Please browse to the transferable cache file

    for /F %%b in ('cscript /nologo !browseFile! "select a the transferable cache file"') do set "file=%%b" && set "TRANSF_CACHE=!file:?= !"
    if [!TRANSF_CACHE!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askInputFile
    )

    REM : check the extension
    for /F "delims=~" %%i in (!TRANSF_CACHE!) do set "ext=%%~xi"
    if not ["!ext!"] == [".bin"] (
        echo Please browse to a bin file ^(^.bin^)
        goto:askInputFile
    )
    for %%a in (!TRANSF_CACHE!) do set "folder="%%~dpa""
    set "SOURCE_FOLDER=!folder:~0,-2!""

    REM : with args
    if %nbArgs% NEQ 0 goto:getTargetFolder

    REM : Ask if tc for CEMU > 1.16 => newTc=1
    set /A "newTc=0"

    REM : analyse length of file
    for /F "delims=~" %%i in (!TRANSF_CACHE!) do set "fn=%%~ni"

    REM : cache > 1.16
    echo !fn! | findStr /R "^[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9].$" > NUL 2>&1 && (
        echo !fn! | find "00050000" > NUL 2>&1 && (
            set /A "newTc=1"
            goto:askGameFolder
        )
    )
    REM : is it look like an old shader cache name
    echo !fn! | findStr /R "^[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9].$" > NUL 2>&1 && (
        set /A "newTc=0"
        goto:askGameFolder
    )

    REM : else ask user
    choice /C yn /N /M "Is this cache is for versions of CEMU > 1.16 (y, n)? : "
    if %ERRORLEVEL% EQU 1 set /A "newTc=1"
    
    :askGameFolder
    echo.
    echo Please browse to the game^'s folder
    echo.

    for /F %%b in ('cscript /nologo !browseFolder! "select a game's folder"') do set "folder=%%b" && set "GAME_FOLDER_PATH=!folder:?= !"
    if [!GAME_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askGameFolder
    )
    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !GAME_FOLDER_PATH!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !GAME_FOLDER_PATH! is not DOS compatible^!^, please choose another location
        pause
        goto:askGameFolder
    )

    set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
    REM : cd to codeFolder
    pushd !codeFolder!
    set "RPX_FILE="project.rpx""
    REM : get bigger rpx file present under game folder
    if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
        set "RPX_FILE="%%i""
    )
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : if no rpx file found, ignore GAME
    if [!RPX_FILE!] == ["NONE"] (
        echo This folder does not contain rpx file under a code subfolder
        goto:askGameFolder
    )

    REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    REM : compute shaderCacheId
    set "sci=NOT_FOUND"
    call:getShaderCacheName
    if !newTc! EQU 0 goto:checkSizes

    REM : new cache built with titleId
    set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
    if not exist !META_FILE! (
        echo No meta folder found under game folder^, aborting^!
        goto:metaFix
    )

    REM : get Title Id from meta.xml
    :getTitleLine
    set "titleLine="NONE""
    for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
    if [!titleLine!] == ["NONE"] (
        echo No titleId found in the meta^.xml file ^?
        :metafix
        echo No game profile was found because no meta^/meta^.xml file exist under game^'s folder ^!
        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        if not exist !metaFolder! mkdir !metaFolder! > NUL 2>&1
        echo "Please pick your game titleId ^(copy to clipboard^) in WiiU-Titles-Library^.csv"
        echo "Then close notepad to continue"

        set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !wiiTitlesDataBase!
        REM : create the meta.xml file
        echo ^<^?xml^ version=^"1.0^"^ encoding=^"utf-8^"^?^> > !META_FILE!
        echo ^<menu^ type=^"complex^"^ access=^"777^"^> >> !META_FILE!
        echo ^ ^ ^<title_version^ type=^"unsignedInt^"^ length=^"4^"^>0^<^/title_version^> >> !META_FILE!
        echo ^ ^ ^<title_id^ type=^"hexBinary^"^ length=^"8^"^>################^<^/title_id^> >> !META_FILE!
        echo ^<^/menu^> >> !META_FILE!
        echo "Paste-it in meta^/meta^.xml file ^(replacing ################ by the title id of the game ^(16 characters^)^)"
        echo "Then close notepad to continue"
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !META_FILE!
        goto:getTitleLine
    )

    for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

    if !titleId! == "################" goto:metafix

    set "endIdUp=!titleId!
    call:lowerCase !endIdUp! sci

    :checkSizes

    if ["!sci!"] == ["NOT_FOUND"] (
        echo Error when computing shader cache name^.
        pause
        exit 50
    )

    REM : check the files sizes
    for /F "tokens=*" %%a in (!TRANSF_CACHE!)  do set "newSize=%%~za"

    :getTargetFolder
    REM : search for existing cache
    set "TARGET_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\ShaderCache\transferable""
    if not exist !TARGET_FOLDER! mkdir !TARGET_FOLDER! > NUL 2>&1

    pushd !TARGET_FOLDER!

    set "oldCache="NONE""
    for /F "delims=~" %%i in ('dir /B /O:D /T:W !sci!.bin 2^>NUL') do (
        set "oldCache="!TARGET_FOLDER:"=!\%%i""
    )
    pushd !GAMES_FOLDER!

    REM : if no cache is found
    if [!oldCache!] == ["NONE"] goto:copyCache

    REM : get size
    for /F "tokens=*" %%a in (!oldCache!)  do set "oldSize=%%~za"

    if %newSize% LSS %oldSize% (
        echo WARNING the size of the new file is lower than your current cache
        call:getUserInput "Do you want to continue? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] (
            echo Cancelled by user
            timout /T 3 > NUL 2>&1
            exit 1
        )
    )

    :copyCache
    set "newPath="!TARGET_FOLDER:"=!\!sci!.bin""

    copy /Y !TRANSF_CACHE! !newPath! > NUL 2>&1

    echo !TRANSF_CACHE! successfully copied to
    echo !TARGET_FOLDER! as !sci!.bin

    if %nbArgs% NEQ 0 goto:endMain
    echo =========================================================
    echo This windows will close automatically in 12s
    echo     ^(n^) ^: don^'t close^, i want to read history log first
    echo     ^(q^) ^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    :endMain
    if %nbArgs% EQU 0 endlocal
    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : lower case
    :lowerCase

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:A=a!"
        set "str=!str:B=b!"
        set "str=!str:C=c!"
        set "str=!str:D=d!"
        set "str=!str:E=e!"
        set "str=!str:F=f!"
        set "str=!str:G=g!"
        set "str=!str:H=h!"
        set "str=!str:I=i!"
        set "str=!str:J=j!"
        set "str=!str:K=k!"
        set "str=!str:L=l!"
        set "str=!str:M=m!"
        set "str=!str:N=n!"
        set "str=!str:O=o!"
        set "str=!str:P=p!"
        set "str=!str:Q=q!"
        set "str=!str:R=r!"
        set "str=!str:S=s!"
        set "str=!str:T=t!"
        set "str=!str:U=u!"
        set "str=!str:W=w!"
        set "str=!str:X=x!"
        set "str=!str:Y=y!"
        set "str=!str:Z=z!"

        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------


    :getShaderCacheName

        pushd !getShaderCacheFolder!
        set "rpx_path="!codeFolder:"=!\!RPX_FILE:"=!""
        echo Computing RPX hash of !rpx_path!

        for /F %%l in ('getShaderCacheName.exe !rpx_path!') do set "sci=%%l"
        echo Shader Cache named computed=!sci!

        pushd !GAMES_FOLDER!
    goto:eof
    REM : ------------------------------------------------------------------

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

                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
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
