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

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    cls
    @echo =========================================================
    @echo Import a transferable cache file
    @echo =========================================================

    REM : browse to the file
    :askInputFile
    @echo Please browse to the transferable cache file

    for /F %%b in ('cscript /nologo !browseFile! "select a the transferable cache file"') do set "file=%%b" && set "TRANSF_CACHE=!file:?= !"
    if [!TRANSF_CACHE!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askInputFile
    )

    for %%a in (!TRANSF_CACHE!) do set "folder="%%~dpa""
    set "SOURCE_FOLDER=!folder:~0,-2!""

    :askGameFolder
    @echo Please browse to the game^'s folder

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
        @echo Path to !GAME_FOLDER_PATH! is not DOS compatible^!^, please choose another location
        pause
        goto:askGameFolder
    )

    REM : get bigger rpx file present under game folder
    set "RPX_FILE="NONE""
    set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
    REM : cd to codeFolder
    pushd !codeFolder!
    for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
        set "RPX_FILE="%%i""
    )
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!
    REM : if no rpx file found, ignore GAME
    if [!RPX_FILE!] == ["NONE"] (
        @echo This folder does not contain rpx file under a code subfolder
        goto:askGameFolder
    )

    REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    REM : search for BatchFw game info file
    set "infoFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt""

    if not exist !infoFile! (
        @echo BatchFw^'^s game info file was not found
        @echo The shader cache id is read from Cemu^'s log and
        @echo write in !infoFile! after the first launch
        @echo.
        @echo Please^, launch the game at least one time and
        @echo relaunch this script^.
    )

    for /F "tokens=2 delims=~=" %%i in ('type !infoFile! ^| find /I "ShaderCache Id" 2^>NUL') do set "sci=%%i"
    set "sci=!sci:"=!"
    set "sci=!sci: =!"

    REM : check the files sizes
    for /F "tokens=*" %%a in (!TRANSF_CACHE!)  do set "newSize=%%~za"

    REM : search for existing cache
    set "TARGET_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\ShaderCache\transferable""

    pushd !TARGET_FOLDER!

    set "oldCache="NONE""
    for /F "delims=~" %%i in ('dir /B /O:D *.bin 2^>NUL') do (
        set "oldCache="!TARGET_FOLDER:"=!\%%i""
    )

    pushd !GAMES_FOLDER!

    REM : if no cache is found
    if [!oldCache!] == ["NONE"] goto:copyCache

    REM : get size
    for /F "tokens=*" %%a in (!oldCache!)  do set "oldSize=%%~za"

    if %newSize% LSS %oldSize% (
        @echo WARNING the size of the new file is lower than your current cache
        call:getUserInput "Do you want to continue? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] (
            @echo Cancelled by user
            timout /T 3 > NUL 2>&1
            exit 1
        )
    )

    :copyCache
    set "newName="!SOURCE_FOLDER:"=!\!sci!.bin""

    move /Y !TRANSF_CACHE! !newName! > NUL 2>&1
    robocopy !SOURCE_FOLDER! !TARGET_FOLDER! !sci!.bin > NUL 2>&1

    @echo !TRANSF_CACHE! successfully copied to
    @echo !TARGET_FOLDER! as !sci!.bin

    @echo =========================================================
    @echo This windows will close automatically in 12s
    @echo     ^(n^) ^: don^'t close^, i want to read history log first
    @echo     ^(q^) ^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )
    :exiting
    if %nbArgs% EQU 0 endlocal
    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

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
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
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
