@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main


    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"
    title Import Games with updates and DLC
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
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

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

    if %nbArgs% EQU 0 (
        title Import Games with updates and DLC

        @echo =========================================================
        @echo Import new games in your library and prepare them for
        @echo emulation with CEMU using BatchFw^.
        @echo.
        @echo If folders ^(DLC^) and ^(UPDATE^) are found^, batchFw will
        @echo install them in each game^'s folder^.
        @echo.
        @echo If DLC or UPDATE folders are found without the game in the
        @echo folder^, they will be skipped^.
        @echo In this case BatchFw has already built the mlc01 folder
        @echo structure^, just move their content to the right place^:
        @echo.
        @echo - update in mlc01^/usr^/title^/titleId[0^:7]/titleId[8^:15]
        @echo - dlc    in mlc01^/usr^/title^/titleId[0^:7]/titleId[8^:15]/aoc
        @echo.
        @echo =========================================================

        @echo Launching in 40s
        @echo     ^(y^) ^: launch now
        @echo     ^(n^) ^: cancel
        @echo ---------------------------------------------------------
        call:getUserInput "Enter your choice ? : " "y,n" ANSWER 40
        if [!ANSWER!] == ["n"] (
            REM : Cancelling
            choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
            goto:eof
        )

        goto:begin
    )

    if %nbArgs% NEQ 1 (
        @echo ERROR on arguments passed^(%nbArgs%^)
        @echo SYNTAXE^: "!THIS_SCRIPT!" INPUT_FOLDER
        @echo given {%*}
        pause
        exit 9
    )

    REM : get and check INPUT_FOLDER
    set "INPUT_FOLDER=!args[0]!"

    goto:inputsAvailable

    :begin
    cls
    :askInputFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a source folder"') do set "folder=%%b" && set "INPUT_FOLDER=!folder:?= !"
    if [!INPUT_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askInputFolder
    )

    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !INPUT_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo Path to !INPUT_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askInputFolder
    )

    :inputsAvailable
    set "INPUT_FOLDER=!INPUT_FOLDER:\\=\!"

    pushd !INPUT_FOLDER!

    REM : rename folders that contains forbiden characters : & ! .
    if %nbArgs% EQU 0 wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!INPUT_FOLDER! /REPLACECI^:^^!^: /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE

    :scanGamesFolder
    cls
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

    REM using the sort /V, first come the game, then update and DLC (if availables)

    REM initialize a endTitleId variable here so it will be visible in all functions (installDlc, installUpdate)
    set "endTitleId=NONE"

    REM : loop on game's code folders found
    for /F "delims=~" %%i in ('dir /b /o:n /a:d /s code ^| findStr /R "\\code$" ^| find /I /V "\mlc01" ^| sort /R 2^>NUL') do (

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

            if !cr! GTR 1 @echo Please rename !GAME_FOLDER_PATH! to be DOS compatible ^,otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder

            REM : basename of GAME FOLDER PATH (to get GAME_FOLDER_NAME)
            for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_FOLDER_NAME=%%~nxi"

            echo !GAME_FOLDER_PATH! | find /I /V "(DLC)" | find /I /V "(UPDATE DATA)" > NUL 2>&1 && call:prepareGame
            echo !GAME_FOLDER_PATH! | find "(UPDATE DATA)" > NUL 2>&1 && call:installUpdate
            echo !GAME_FOLDER_PATH! | find "(DLC)" > NUL 2>&1 && call:installDlc

        ) else (
            pushd !GAMES_FOLDER!

            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            @echo !folderName! ^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
            for %%a in (!GAME_FOLDER_PATH!) do set "basename=%%~dpa"

            REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!% are also a problem with dos expansion
            set "str="!folderName!""
            set "str=!str:&=!"
            set "str=!str:\!=!"
            set "str=!str:%%=!"
            set "str=!str:?=!"
            set "str=!str:\"=!"
            set "str=!str:^=!"
            set "newFolderName=!str:"=!"
            set "newName="!basename!!newFolderName:"=!""

            call:getUserInput "Renaming folder for you ? (y, n) : " "y,n" ANSWER

            if [!ANSWER!] == ["y"] move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^' ^?^), please do it by yourself otherwise game will be ignored ^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )
    if %nbArgs% EQU 1 goto:exiting

    @echo =========================================================
    @echo Treated !NB_GAMES_TREATED! games
    @echo #########################################################


    @echo This windows will close automatically in 15s
    @echo     ^(n^) ^: don^'t close^, i want to read history log first
    @echo     ^(q^) ^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    :exiting
    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :prepareGame

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
        if [!RPX_FILE!] == ["NONE"] goto:eof

        set "GAME_TITLE=!GAME_FOLDER_NAME!"
        REM : if USB Helper output : NAME[Id], get only the name
        echo "!GAME_FOLDER_PATH!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        set "target="!GAMES_FOLDER:"=!\!GAME_TITLE!""

        if exist !target! goto:eof

        @echo =========================================================
        @echo - !GAME_TITLE!
        @echo ---------------------------------------------------------
        @echo.

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            @echo No meta folder not found under game folder !GAME_TITLE! ^?^, skipping ^!
            @echo ---------------------------------------------------------
            goto:eof
        )

        REM : get Title Id from meta.xml
        :getTitleLine
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:eof
        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

        set "endTitleId=%titleId:~8,8%"

        REM : moving game's folder

        set "source="!INPUT_FOLDER:"=!\!GAME_TITLE!""

        move /Y !GAME_FOLDER_PATH! !source! > NUL 2>&1

        :moveGame
        call:moveFolder !source! !target! cr
        if !cr! NEQ 0 (
            cscript /nologo !MessageBox! "ERROR While moving game cr=!cr!^, close all explorer^.exe that might interfer ^!" 4112
            if !ERROLRLEVEL! EQU 4 goto:moveGame
        )

        REM : creating mlc01 folder structure
        set "sysFolder="!target:"=!\mlc01\sys\title\0005001b\10056000\content""

        if not exist !sysFolder! (
            @echo Creating system save^'s folder
            mkdir !sysFolder! > NUL 2>&1
        )
        set "saveFolder="!target:"=!\mlc01\usr\save\00050000\%endTitleId%""

        if not exist !saveFolder! (
            @echo Creating saves folder
            mkdir !saveFolder! > NUL 2>&1
        )

        set /A NB_GAMES_TREATED+=1
        @echo.

    goto:eof
    REM : ------------------------------------------------------------------

    :installUpdate

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            @echo No meta folder not found under update folder !GAME_FOLDER_NAME! ^?^, skipping ^!
            @echo ---------------------------------------------------------
            goto:eof
        )

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:eof
        for /F "delims=<" %%i in (!titleLine!) do set "titleIdU=%%i"

        set "endTitleIdU=%titleIdU:~8,8%"

        if not ["!endTitleIdU!"] == ["!endTitleId!"] (
            @echo This update is not related to a game that exists in !INPUT_FOLDER!^, skipping ^!
            @echo ---------------------------------------------------------
            goto:eof
        )

        REM : moving to game's folder
        set "target="!GAMES_FOLDER:"=!\!GAME_TITLE!\mlc01\usr\title\00050000\%endTitleId%""

        if not exist !target! (
            @echo Creating update^'s folder
            mkdir !target! > NUL 2>&1
        )
        set "source="!INPUT_FOLDER:"=!\%endTitleId%""

        move /Y !GAME_FOLDER_PATH! !source! > NUL 2>&1

        :moveUpdate
        call:moveFolder !source! !target! cr
        if !cr! NEQ 0 (
            cscript /nologo !MessageBox! "ERROR While moving !GAME_TITLE!^'s update ^, close all explorer^.exe that might interfer ^!" 4112
            if !ERROLRLEVEL! EQU 4 goto:moveUpdate
        )
        @echo update installed

    goto:eof
    REM : ------------------------------------------------------------------

    :installDlc

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            @echo No meta folder not found under DLC folder !GAME_FOLDER_NAME! ^?^, skipping ^!
            @echo ---------------------------------------------------------
            goto:eof
        )

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:eof
        for /F "delims=<" %%i in (!titleLine!) do set "titleIdDlc=%%i"

        set "endTitleIdDlc=!titleIdDlc:~8,8!"

        if not ["!endTitleIdDlc!"] == ["!endTitleId!"] (
            @echo this DLC is not related to a game that exists in !INPUT_FOLDER!^, skipping ^!
            @echo ---------------------------------------------------------
            goto:eof
        )

        REM : moving to game's folder
        set "target="!GAMES_FOLDER:"=!\!GAME_TITLE!\mlc01\usr\title\00050000\%endTitleId%\%endTitleId%_aoc""
        set "source="!INPUT_FOLDER:"=!\%endTitleId%_aoc""

        move /Y !GAME_FOLDER_PATH! !source! > NUL 2>&1

        :moveDlc
        call:moveFolder !source! !target! cr
        if !cr! NEQ 0 (
            cscript /nologo !MessageBox! "ERROR While moving !GAME_TITLE!^'s DLC ^, close all explorer^.exe that might interfer ^!" 4112
            if !ERROLRLEVEL! EQU 4 goto:moveDlc
        )

        move /Y !target! !target:%endTitleId%_=! > NUL 2>&1
        @echo DLC installed

    goto:eof


    REM : ------------------------------------------------------------------
    REM : function to optimize a folder move (move if same drive letter much type faster)
    :moveFolder

        REM arg1 source
        set "source="%~1""
        REM arg2 target
        set "target="%~2""
        REM arg3 = return code

        set "source=!source:\\=\!"
        set "target=!target:\\=\!"

        if not exist !source! goto:eof
        if [!source!] == [!target!] if exist !target! goto:eof
        if not exist !target! mkdir !target!

        REM : source drive
        for %%a in (!source!) do set "sourceDrive=%%~da"

        REM : target drive
        for %%a in (!target!) do set "targetDrive=%%~da"

        REM : if folders are on the same drive
        if ["!sourceDrive!"] == ["!targetDrive!"] (

            if exist !target! rmdir /Q /S !target!
            move /Y !source! !target! > NUL 2>&1
            set /A "cr=!ERRORLEVEL!"
            if !cr! EQU 1 (
                set /A "%3=1"
            ) else (
                set /A "%3=0"
            )
            goto:eof
        )

        REM : else robocopy
        robocopy !source! !target! /S /MOVE /IS /IT > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! GTR 7 set /A "%3=1"
        if !cr! GEQ 0 set /A "%3=0"

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
