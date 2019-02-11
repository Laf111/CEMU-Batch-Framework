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

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSetAndLocale

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

    REM : get current date
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM set Shell.BrowseForFolder arg vRootFolder
    REM : 0  = ShellSpecialFolderConstants.ssfDESKTOP
    set "DIALOG_ROOT_FOLDER="0""

    @echo Please select CEMU target folder
    :askCemuFolder
    call:getFolderPath "Please select CEMU target folder" !DIALOG_ROOT_FOLDER! CEMU_FOLDER

    REM : check that cemu.exe exist in
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe" "
    if /I not exist !cemuExe! (
        @echo ERROR^, No Cemu^.exe file found under !CEMU_FOLDER! ^^!
        goto:askCemuFolder
    )
    cls
    goto:inputsAvailables

    :getArgsValue
    if %nbArgs% NEQ 1 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER
        @echo given {%*}
        pause
        exit /b 99
    )
    REM : get and check CEMU_FOLDER
    set "CEMU_FOLDER=!args[0]!"
    if not exist !CEMU_FOLDER! (
        @echo ERROR ^: !CEMU_FOLDER! does not exist ^!
        pause
        exit /b 1
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables


    REM : check if folder name contains forbiden character for !CEMU_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !CEMU_FOLDER!
    set cr=!ERRORLEVEL!
    if %cr% NEQ 0 (
        @echo Please rename !CEMU_FOLDER! path to be DOS compatible ^!^, exiting
        pause
        exit /b 2
    )

    for %%a in (!CEMU_FOLDER!) do set CEMU_FOLDER_NAME="%%~nxa"

    @echo =========================================================
    @echo Restore transferable shader cache to a CEMU install folder for each game^'s chosen
    @echo  - loadiine Wii-U Games under ^: !GAMES_FOLDER!
    @echo  - target CEMU folder ^: !CEMU_FOLDER!
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
        if !QUIET_MODE! EQU 0 pause
    )
    set /A NB_GAMES_TREATED=0
    REM : loop on game's code folders found
    for /F "delims=" %%i in ('dir /b /o:n /a:d /s code ^| find /V "\aoc" ^| find /V "\mlc01" 2^>NUL') do (

        set "codeFullPath="%%i""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : check path
        call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 0 (
            REM : check if folder name contains forbiden character for batch file
            set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
            call !tobeLaunch! !GAME_FOLDER_PATH!
            set cr=!ERRORLEVEL!

            if !cr! GTR 1 @echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:mvGameData

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
    if ["%QUIET_MODE%"] == ["1"] goto:exiting
    @echo ---------------------------------------------------------
    @echo Delete and recreate shortcut for the treated games
    @echo ^(otherwise you^'ll get an error when launching the game ask you to do this^)
    @echo ---------------------------------------------------------
    @echo This windows will close automatically in 12s
    @echo     ^(n^) ^: don^'t close^, i want to read history log first
    @echo     ^(q^) ^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "- Enter your choice ? : " "q,n" ANSWER 12
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

    :mvGameData

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

        @echo =========================================================
        @echo - !GAME_TITLE!
        @echo ---------------------------------------------------------

        @echo - Moving game^'s data to !CEMU_FOLDER! ^?
        @echo     ^(n^) ^: no^, skip
        @echo     ^(y^) ^: yes ^(default value after 8s timeout^)
        @echo -

        call:getUserInput "- Enter your choice ? : " "y,n" ANSWER 8
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip this GAME
            goto:eof
        )        
        @echo ---------------------------------------------------------

        
        set "sf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
        if not exist !sf! (
            @echo Nothing to do for !GAME_TITLE!
            goto:eof
        )
        
        set "target="!CEMU_FOLDER:"=!\ShaderCache\transferable""
     
        call:moveFolder !sf! !target! cr
        if !cr! NEQ 0 (
            @echo - ERROR when moving !sf! !target!^, cr=!ERRORLEVEL!
            pause
        ) else (
            echo - Moving !sf!
        )
        rmdir /Q /S "!GAME_FOLDER_PATH:"=!\Cemu\shaderCache" 2>NUL

        :logInfos
        REM : log to games library log file
        set "msg="!GAME_TITLE!:!DATE!-!USERDOMAIN! restore transferable shader cache for !GAME_TITLE! in=!CEMU_FOLDER:"=!""
        call:log2GamesLibraryFile !msg!

        set /A NB_GAMES_TREATED+=1

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to optimize a folder move (move if same drive letter much type faster)
    :moveFolder

        REM arg1 source
        set "source="%~1""
        REM arg2 target
        set "target="%~2""
        REM arg3 = return code

        if not exist !source! goto:eof
        if not exist !target! mkdir !target!

        REM : source drive
        for %%a in (!source!) do set "sourceDrive=%%~da"

        REM : target drive
        for %%a in (!target!) do set "targetDrive=%%~da"

        REM : if folders are on the same drive
        if ["!sourceDrive!"] == ["!targetDrive!"] (

            for %%a in (!target!) do set "parentFolder="%%~dpa""
            set "parentFolder=!parentFolder:~0,-2!""
            if exist !target! rmdir /Q /S !target! 2>NUL

            REM : use move command (much type faster)
            move /Y !source! !parentFolder! > NUL
            set /A "cr=!ERRORLEVEL!"
            if !cr! EQU 1 (
                set /A "%3=1"
            ) else (
                set /A "%3=0"
            )

           goto:eof
        )

        REM : else robocopy
        robocopy !source! !target! /S /MOVE /IS /IT > NUL
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 7 set /A "%3=1"
        if !cr! GEQ 0 set /A "%3=0"

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

    REM : function to open browse folder dialog and check folder's DOS compatbility
    :getFolderPath

        set "TITLE="%~1""
        set "ROOT_FOLDER="%~2""

        :askForFolder
        REM : open folder browser dialog box
        call:runPsCmd !TITLE! !ROOT_FOLDER! FOLDER_PATH
        REM : powershell call always return %ERRORLEVEL%=0

        REM : check the path
        call:checkPathForDos !FOLDER_PATH!
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 goto:eof

        REM detect (,),&,%,£ and ^
        set "str=!FOLDER_PATH!"
        set "str=!str:?=!"
        set "str=!str:\"=!"
        set "str=!str:^=!"
        set "newPath="!str:"=!""

        if not [!FOLDER_PATH!] == [!newPath!] (
            @echo This folder is not compatible with DOS^. Remove special character from !FOLDER_PATH!
            goto:askForFolder
        )

        REM : trailing slash? if so remove it
        set "_path=!FOLDER_PATH:"=!"
        if [!_path:~-1!] == [\] set "FOLDER_PATH=!FOLDER_PATH:~0,-2!""

        REM : set return value
        set "%3=!FOLDER_PATH!"

    goto:eof

    REM : launch ps script to open dialog box
    :runPsCmd
        set "psCommand="(new-object -COM 'shell.Application')^.BrowseForFolder(0,'%1',0,'%~2').self.path""

        set "folderSelected="NONE""
        for /F "usebackq delims=" %%I in (`powershell !psCommand!`) do (
            set "folderSelected="%%I""
        )
        if [!folderSelected!] == ["NONE"] call:runPsCmd %1 %2
        REM : in case of DOS characters substitution (might never arrive)
        if not exist !folderSelected! call:runPsCmd %1 %2
        set "%3=!folderSelected!"

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

            if [%cr%] == [!j!] (
                REM : value found , return function value

                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
        )

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
