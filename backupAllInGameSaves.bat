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

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    
    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    set "USERSLIST="
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do set "USERSLIST=%%i !USERSLIST!"
    if ["!USERSLIST!"] == [""] (
        @echo No BatchFW^'s users registered ^^!
        @echo Delete _BatchFw_Install folder and reinstall
        pause
        exit /b 9
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    cls
    @echo =========================================================
    @echo Save all games progression files

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

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"    
    @echo Please select mlc01 source folder
    @echo For each game^, if a mlc01 folder is found under game^'s folder it will be used instead^!

    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder!') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"
    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 exit 75
        goto:askMlc01Folder
    )

    REM : check if folder name contains forbiden character for !MLC01_FOLDER_PATH!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !MLC01_FOLDER_PATH!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo Path to !MLC01_FOLDER_PATH! is not DOS compatible^!^, please choose another location
        pause
        goto:askMlc01Folder
    )
    
    REM : check if a usr/title exist
    set usrTitle="!MLC01_FOLDER_PATH:"=!\usr\title"
    if not exist !usrTitle! (
        @echo !usrTitle! not found^?
        goto:askMlc01Folder
    )

    goto:inputsAvailables

    :getArgsValue
    if %nbArgs% NEQ 1 (
        @echo ERROR on arguments passed^!
        @echo SYNTAXE^: "!THIS_SCRIPT!" MLC01_FOLDER_PATH
        @echo given {%*}
        pause
        exit /b 99
    )
    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[0]!"
    if not exist !MLC01_FOLDER_PATH! (
        @echo ERROR^: mlc01 folder !MLC01_FOLDER_PATH! does not exist^!
        pause
        exit /b 1
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

    @echo  - source mlc01 folder^: !MLC01_FOLDER_PATH!
    @echo =========================================================
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder

    @echo Launching in 12s
    @echo     ^(y^)^: launch now
    @echo     ^(n^)^: cancel
    @echo ---------------------------------------------------------
    call:getUserInput "Enter your choice ? : " "y,n" ANSWER 12
    if [!ANSWER!] == ["n"] (
        REM : Cancelling
        choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
        goto:eof
    )

    :scanGamesFolder
    cls

    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        @echo =========================================================
        @echo ERROR^: Unknown characters found in game^'s folder^(s^) that are not handled by your current DOS charset ^(%CHARSET%^)
        @echo List of game^'s folder^(s^)^:
        @echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        @echo ---------------------------------------------------------
        @echo Fix-it by removing characters here replaced in the folder^'s name
        @echo Exiting until you rename or move those folders
        @echo =========================================================
        pause
        goto:eof
    )

    set /A NB_SAVES_TREATED=0
    REM : loop on game's code folders found
    for /F "delims=" %%i in ('dir /b /o:n /a:d /s code ^| findStr /R "\\code$" ^| find /I /V "\aoc" ^| find /I /V "\mlc01" 2^>NUL') do (

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
            call:saveGameProgressionFiles

        ) else (

            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            @echo !folderName!^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
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
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    @echo =========================================================
    @echo Treated !NB_SAVES_TREATED! saves
    if ["%QUIET_MODE%"] == ["1"] goto:exiting

    @echo #########################################################
    @echo This windows will close automatically in 12s
    @echo     ^(n^)^: don^'t close^, i want to read history log first
    @echo     ^(q^)^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 12
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    :exiting
    if %nbArgs% EQU 0 endlocal
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : saving function
    :saveGameProgressionFiles

        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\code\*.rpx""
        for /F "delims=" %%i in ('dir /B /O:S !pat! 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : ignore game that already have mlc01 subfolder
        set "mlc01Folder="!GAME_FOLDER_PATH:"=!\mlc01""
        if exist !mlc01Folder! (
            set MLC01_FOLDER_PATH=!mlc01Folder!
            goto:treatThisGame
        )

        @echo WARNING^: MLC01_FOLDER_PATH does not exist and no mlc01 was found under !GAME_FOLDER_PATH!^?
        goto:eof

        :treatThisGame

        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        @echo =========================================================
        @echo - !GAME_TITLE!
        @echo ---------------------------------------------------------

        for %%a in (!USERSLIST!) do (

            set rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_%%a.rar"

            if not exist !rarFile! goto:skipUser

            REM : ELSE copy inGameSaves\!USERNAME!.rar to !GAME_TITLE!_%%a_%DATE%.rar
            set "str=!rarFile:"=!"
            set backup="!str:.rar=!_%DATE%.rar"

            @echo Game saves found, backuping under !backup!
            copy /Y !rarFile! !backup! > NUL
            set /A "cr=!ERRORLEVEL!"
            if !cr! NEQ 0 (
                @echo ERROR when copying !rarFile! to !backup!
                pause
            )
            :skipUser
            echo. > NUL
        )

        set /A NB_SAVES_TREATED+=1
        )



    goto:eof
    REM : ------------------------------------------------------------------

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

       set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
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