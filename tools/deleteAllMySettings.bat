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


    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!


    @echo =========================================================

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : get current date
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : initialize QUIET_MODE to 0 (inactive)
    set /A "QUIET_MODE=0"

    REM : initialize for every host
    set "HOST=*"

    REM : initialize for every version
    set "CEMU_FOLDER_NAME=*"

    if %nbArgs% EQU 0 (
        @echo Delete all my settings for each game ^(for all CEMU versions^) saved for all host
        goto:del
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    if %nbArgs% GTR 2 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!"  HOST^* CEMU_FOLDER_NAME^*
        @echo given {%*}
        pause
        exit /b 99
    )

    REM : HOST given
    if %nbArgs% GEQ 1 (
        set "HOST=!args[0]!"
        set "HOST=!HOST:"=!"
        set "HOST=!HOST: =!"
        if %nbArgs% EQU 1 @echo Delete all my settings for each game ^(for all CEMU versions^) saved for !HOST! host
    )

    REM : CEMU version given
    if %nbArgs% EQU 2 (
        set "CEMU_FOLDER_NAME=!args[1]!"
        set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME:"=!"
        set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME: =!"
        @echo Delete my !CEMU_FOLDER_NAME! settings for each game saved for host !HOST!
    )


    :del
    @echo =========================================================
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder

    @echo Launching in 12s
    @echo     ^(y^) ^: launch now
    @echo     ^(n^) ^: cancel
    @echo ---------------------------------------------------------
    call:getUserInput "Enter your choice ? : " "y,n" ANSWER 12
    if [!ANSWER!] == ["n"] (
        REM : Cancelling
        choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
        goto:eof
    )

    cls
    :scanGamesFolder
    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        @echo =========================================================
        @echo ERROR ^: Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        @echo List of game^'s folder^(s^) ^:
        @echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        @echo ---------------------------------------------------------
        @echo Fix-it by removing characters here replaced in the folder^'s name by ^?
        @echo Exiting until you rename or move those folders
        @echo =========================================================
        pause
        goto:eof
    )

    set /A NB_GAMES_TREATED=0
    REM : loop on game's code folders found
    for /F "delims=" %%i in ('dir /b /o:n /a:d /s code ^| findStr /R "\\code$" ^| find /V "\aoc" ^| find /V "\mlc01" 2^>NUL') do (

        set "codeFullPath="%%i""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : check path
        call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 0 (
            REM : check if folder name contains forbiden character for batch file
            set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
            call !tobeLaunch! !GAME_FOLDER_PATH!
            set /A "cr=!ERRORLEVEL!"

            if !cr! GTR 1 @echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder

            call:delSettingsIn

        ) else (

            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            @echo !folderName! ^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
            for %%a in (!GAME_FOLDER_PATH!) do set "basename=%%~dpa"

            REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!% are also a problem with dos expansion
            set "str="!folderName!""
            set "str=!str:&=!"
            set "str=!str:\!=!"
            set "str=!str:%%=!"
            set "str=!str:.=!"
            set "str=!str:?=!"
            set "str=!str:\"=!"
            set "str=!str:^=!"
            set "newFolderName=!str:"=!"
            set "newName="!basename!!newFolderName:"=!""

            call:getUserInput "Renaming folder for you ? (y, n) : " "y,n" ANSWER

            if [!ANSWER!] == ["y"] move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^' ^?^), please do it by yourself otherwise game will be ignored ^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    @echo =========================================================
    @echo Treated !NB_GAMES_TREATED! games
    @echo #########################################################
    @echo This windows will close automatically in 15s
    @echo     ^(n^) ^: don^'t close^, i want to read history log first
    @echo     ^(q^) ^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "- Enter your choice ? : " "q,n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    if !NB_GAMES_TREATED! NEQ 0 (

        REM : HOST not given
        if %nbArgs% GEQ 1 set "msg="!GAME_TITLE!:!DATE!-!USERDOMAIN! delete all settings stored for all CEMU version""
        REM : HOST given
        if %nbArgs% EQU 2 set "msg="!GAME_TITLE!:!DATE!-!HOST! delete all settings stored for !CEMU_FOLDER_NAME!""
        call:log2GamesLibraryFile !msg!
    )

    if %nbArgs% EQU 0 endlocal
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions


    :delSettingsIn

        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\code\*.rpx""
        for /F "delims=" %%i in ('dir /B /O:S !pat! 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        if ["!HOST!"] == ["*"] goto:removeAllHost

        set "rootDir="!GAME_FOLDER_PATH:"=!\Cemu\settings\!HOST!""
        if not exist !rootDir! goto:eof
        pushd !rootDir!

        if ["!CEMU_FOLDER_NAME!"] == ["*"] goto:removeAllSettings

        set "rootDir="!GAME_FOLDER_PATH:"=!\Cemu\settings\!HOST!\!CEMU_FOLDER_NAME!""
        if not exist !rootDir! goto:eof
        @echo =========================================================
        @echo - !GAME_TITLE!
        @echo ---------------------------------------------------------
        @echo - Deleting settings saved for !CEMU_FOLDER_NAME!^?
        @echo     ^(n^) ^: skip
        @echo     ^(y^) ^: default value after 15s timeout
        @echo ---------------------------------------------------------
        call:getUserInput "- Enter your choice ? : " "y,n" ANSWER 15
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip this GAME
            goto:eof
        )

        for /F "delims=" %%j in ('dir /o:n /a:d /b * ^| find "!CEMU_FOLDER_NAME!" 2^>NUL') do (
            rmdir /S /Q "%%j" 2>NUL
            @echo - "%%j" deleted ^^!
        )
        goto:endTreatment

       :removeAllSettings
        @echo =========================================================
        @echo - !GAME_TITLE!
        @echo ---------------------------------------------------------
        @echo.        @echo - Deleting all settings saved for all versions^?
        @echo     ^(n^) ^: skip
        @echo     ^(y^) ^: default value after 15s timeout
        @echo.        @echo ---------------------------------------------------------
        call:getUserInput "- Enter your choice ? : " "y,n" ANSWER 15
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip this GAME
            goto:eof
        )
        for /F "delims=" %%j in ('dir /o:n /a:d /b * 2^>NUL') do (
            rmdir /S /Q "%%j" 2>NUL
            @echo - "%%j" deleted ^^!
        )
        goto:endTreatment

        :removeAllHost

        REM : all Hosts, all settings
        set "rootDir="!GAME_FOLDER_PATH:"=!\Cemu\settings""
        if not exist !rootDir! goto:eof
        @echo =========================================================
        @echo - !GAME_TITLE!
        @echo ---------------------------------------------------------
        @echo.        @echo - Deleting all settings saved for all host^?
        @echo     ^(n^) ^: skip
        @echo     ^(y^) ^: default value after 15s timeout
        @echo.        @echo ---------------------------------------------------------
        call:getUserInput "- Enter your choice ? : " "y,n" ANSWER 15
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip this GAME
            goto:eof
        )

        pushd !rootDir!
        for /F "delims=" %%j in ('dir /o:n /a:d /b * 2^>NUL') do (
            rmdir /S /Q "%%j" 2>NUL
            @echo - "%%j" deleted ^^!
        )

        :endTreatment
        set /A NB_GAMES_TREATED+=1

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
        set /A "ERRORLEVEL=0"

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
        echo !msg! >> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\GamesLibrary.log""
        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL
        move /Y !gLogFileTmp! !glogFile! > NUL

    goto:eof
    REM : ------------------------------------------------------------------

