@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F
    title Import all user^'s saves from a mlc01 target folder

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit /b 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_LOGS="!BFW_LOGS:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""

    set "setExtraSavesSlots="!BFW_TOOLS_PATH:"=!\setExtraSavesSlots.bat""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    REM : RAR.exe path
    set "rarExe="!BFW_PATH:"=!\resources\rar.exe""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit /b 100
    )


    set "USERSLIST="
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do set "USERSLIST=%%i !USERSLIST!"
    if ["!USERSLIST!"] == [""] (
        echo No BatchFw^'s users registered ^^!
        echo Delete _BatchFw_Install folder and reinstall
        pause
        exit /b 9
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    cls
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
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"
    echo Please select mlc01 source folder

    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a mlc01 folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"
    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askMlc01Folder
    )

    REM : check if folder name contains forbiden character for !MLC01_FOLDER_PATH!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !MLC01_FOLDER_PATH!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !MLC01_FOLDER_PATH! is not DOS compatible^!^, please choose another location
        pause
        goto:askMlc01Folder
    )

    REM : check if a usr/title exist
    set usrSave="!MLC01_FOLDER_PATH:"=!\usr\save"
    if not exist !usrSave! (
        echo !usrSave! not found ^?
        goto:askMlc01Folder
    )

    goto:inputsAvailables

    :getArgsValue
    if %nbArgs% NEQ 1 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" MLC01_FOLDER_PATH
        echo given {%*}
        pause
        exit /b 99
    )
    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[0]!"
    if not exist !MLC01_FOLDER_PATH! (
        echo ERROR ^: mlc01 folder !MLC01_FOLDER_PATH! does not exist ^!
        pause
        exit /b 1
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    cls

    REM : check if more than user is defined
    set /A "nbUsers=0"
    set "userLeftList="

    REM : check if ml01 path is within a CEMU install
    for %%a in (!MLC01_FOLDER_PATH!) do set "parentFolder="%%~dpa""
    set "CEMU_FOLDER=!parentFolder:~0,-2!""
    set "cs="!CEMU_FOLDER:"=!\Settings.xml""
    set /A "importGsFlag=0"

    if not exist !cs! goto:getAccountsUsed

    choice /C yn /N /M "Do you want to import games stats from !CEMU_FOLDER:"=! ? (y/n) :"
    if !ERRORLEVEL! EQU 1 set /A "importGsFlag=1"

    REM : get userArray, choice args
    set /A "nbUsers=0"
    set "cargs="
    for /F "tokens=2 delims=~=" %%a in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        if !importGsFlag! EQU 1 echo !nbUsers! ^: %%a
        set "users[!nbUsers!]="%%a""
        set "userLeftList=!userLeftList! %%a"
        set "cargs=!cargs!!nbUsers!"
        set /A "nbUsers+=1"
    )
    set /A "nbUsers-=1"

    if !importGsFlag! EQU 0 goto:getAccountsUsed

    :getUserGamesStats

    set /P "num=Enter the BatchFw user's number [0, !nbUsers!] : "

    echo %num% | findStr /R /V "[0-9]" > NUL 2>&1 && goto:getUserGamesStats

    if %num% LSS 0 goto:getUserGamesStats
    if %num% GTR !nbUsers! goto:getUserGamesStats

    set "gamesStatUser=!users[%num%]!"

    :getAccountsUsed

    set "sf="!MLC01_FOLDER_PATH:"=!\usr\save\00050000""

    if not exist !sf! goto:beginImport

    REM : loop on all 800000XX folders found
    pushd !sf!

    set /A "nbAccount=1"
    set "accounts="
    set "currentAccount="!BFW_LOGS:"=!\currentAccount.log""

    :loopAccounts
    dir /B /S /A:D 8000000!nbAccount! > !currentAccount! 2>&1
    type !currentAccount! | find /I "8000000!nbAccount!" > NUL 2>&1 && (
        REM :
        echo ---------------------------------------------------------------
        choice /C yn /N /M "Account 8000000!nbAccount! detected, import it ? (y/n) :"
        if !ERRORLEVEL! EQU 2 (
            echo.
            echo skipping account 8000000!nbAccount!
            set /A "ua=!nbAccount!-1"
            set "accounts[!ua!]=SKIPPED"
            set /A "nbAccount+=1"
            goto:loopAccounts
        )
REM        REM : if game stats was asked
REM        if !importGsFlag! EQU 1 (
REM            set /A "nbAcc=!nbAccount!-1"
REM            set "accounts[!nbAcc!]=!gamesStatUser:"=!"
REM            set /A "nbAccount+=1"
REM            goto:accountCreated
REM        )
        if not ["!userLeftList!"] == ["  "] (
            for /L %%l in (0,1,!nbUsers!) do (
                echo !userLeftList!  | find !users[%%l]! > NUL 2>&1 && echo %%l ^: !users[%%l]!
            )
            echo.
            echo Which BatchFw^'s user will use it ?
            echo.

            choice /C !cargs!s /N /M "Enter the user id (number above) : "
            set /A "cr=!ERRORLEVEL!"
            set /A "un=cr-1"
        ) else (
            echo No more BatchFw^'s user defined left
            echo Add a new user using the setup^.bat to associate to the account 8000000!nbAccount!
            echo.
            echo skipping account 8000000!nbAccount!
            echo.
            goto:accountCreated
        )
        set /A "nbAcc=!nbAccount!-1"
        call:setAccount !nbAcc! !un!

        set /A "nbAccount+=1"
        goto:loopAccounts
    )
    :accountCreated
    echo ===============================================================
    set /A "nbAccount-=1"
    echo.
    echo !nbAccount! accounts found in !sf!
    echo.
    set /A "nbAccount-=1"
    if exist !currentAccount! del /F !currentAccount! > NUL 2>&1
    if ["!nbAcc!"] == [""] (
        echo.
        echo No accounts selected^, exiting
        pause
        exit /b 10
    )
    echo ===============================================================
    set /A "nbAccToDisplay=!nbAccount!+1"
    echo Found !nbAccToDisplay! accounts in this mlc path^.
    echo You^'ve chosen to associate ^:
    echo.

    for /L %%l in (0,1,!nbAccount!) do (
        set /A "acc=%%l+1"
        echo account 8000000!acc! ^: !accounts[%%l]!
    )
    echo.
    if !QUIET_MODE! EQU 0 pause
    :beginImport
    cls

    echo =========================================================
    echo Import saves from ^: !MLC01_FOLDER_PATH!
    echo =========================================================
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder

    echo Launching in 30s
    echo     ^(y^) ^: launch now
    echo     ^(n^) ^: cancel
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice ? : " "y,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Cancelling
        choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
        goto:eof
    )
    cls
    :scanGamesFolder
    pushd !GAMES_FOLDER!
    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder_is.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        echo =========================================================
        echo ERROR ^: Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        echo List of game^'s folder^(s^) ^:
        echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        echo ---------------------------------------------------------
        echo Fix-it by removing characters here replaced in the folder^'s name by ^?
        echo Exiting until you rename or move those folders
        echo =========================================================
        if !QUIET_MODE! EQU 0 pause
        exit /b 20
    )

    set /A NB_SAVES_TREATED=0
    REM : loop on game's code folders found
    for /F "delims=~" %%g in ('dir /b /o:n /a:d /s code 2^>NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        set "codeFullPath="%%g""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : check path
        call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 0 (
            REM : check if folder name contains forbiden character for batch file
            set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
            call !tobeLaunch! !GAME_FOLDER_PATH!
            set /A "cr=!ERRORLEVEL!"

            if !cr! GTR 1 echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:importSavesForUsers

        ) else (

            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            echo !folderName! ^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
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

            set /A "attempt=1"
            :tryToMove
            call:getUserInput "Renaming folder for you? (y, n) : " "y,n" ANSWER

            if [!ANSWER!] == ["y"] (
                move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
                if !ERRORLEVEL! NEQ 0 (

                    if !attempt! EQU 1 (
                        !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=!^, close any program that could use this location" 4112
                        set /A "attempt+=1"
                        goto:tryToMove
                    )
                    REM : basename of GAME FOLDER PATH to get GAME_TITLE
                    for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxg"
                    call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                    !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:tryToMove
                )
            )
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^' ^?^), please do it by yourself otherwise game will be ignored ^!
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )
    echo =========================================================
    echo Treated !NB_SAVES_TREATED! saves

    if !QUIET_MODE! EQU 1 goto:exiting

    echo #########################################################
    if !QUIET_MODE! EQU 1 goto:exiting
    echo ---------------------------------------------------------
    echo This windows will close automatically in 12s
    echo     ^(n^) ^: don^'t close^, i want to read history log first
    echo     ^(q^) ^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    :exiting
    echo =========================================================
    echo Waiting the end of all child processes before ending ^.^.^.
    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :fillOwnerShipPatch
        set "folder=%1"
        set "title=%2"

        set "patch="%USERPROFILE:"=%\Desktop\BFW_GetOwnerShip_!title:"=!.bat""
        set "WIIU_GAMES_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
        if not [!WIIU_GAMES_FOLDER!] == ["NONE"] (

            set "patchFolder="!WIIU_GAMES_FOLDER:"=!\OwnerShip Patchs""
            if not exist !patchFolder! mkdir !patchFolder! > NUL 2>&1
            set "patch="!patchFolder:"=!\!title:"=!.bat""
        )
        set "%3=!patch!"

        echo echo off > !patch!
        echo REM ^: RUN THIS SCRIPT AS ADMINISTRATOR >> !patch!

        type !patch! | find /I !folder! > NUL 2>&1 && goto:eof

        echo echo ------------------------------------------------------->> !patch!
        echo echo Get the ownership of !folder! >> !patch!
        echo echo ------------------------------------------------------->> !patch!
        echo takeown /F !folder! /R /SKIPSL >> !patch!
        echo icacls !folder! /grant %%username%%^:F /T /L >> !patch!
        echo pause >> !patch!
        echo del /F %%0 >> !patch!
    goto:eof

    REM : get a node value in a xml file
    REM : !WARNING! current directory must be !BFW_RESOURCES_PATH!
    :getValueInXml

        set "xPath="%~1""
        set "xmlFile="%~2""
        set "%3=NOT_FOUND"

        REM : return the first match
        for /F "delims=~" %%x in ('xml.exe sel -t -c !xPath! !xmlFile! 2^>NUL') do (
            set "%3=%%x"

            goto:eof
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :updateLastSettings

        pushd !BFW_RESOURCES_PATH!

        REM : get the rpxFilePath used
        set "rpxFilePath="NOT_FOUND""
        for /F "delims=~<> tokens=3" %%p in ('type !cs! ^| find "<path>" ^| find "!GAME_TITLE!" 2^>NUL') do set "rpxFilePath="%%p""

        if [!rpxFilePath!] == ["NOT_FOUND"] goto:eof

        REM : get game Id with RPX path
        call:getValueInXml "//GameCache/Entry[path='!rpxFilePath:"=!']/title_id/text()" !cs! gid

        if ["!gid!"] == ["NOT_FOUND"] goto:eof

        set "currentUser=!gamesStatUser:"=!"
        set "sf="!GAME_FOLDER_PATH:"=!\Cemu\settings""
        set "lls="!sf:"=!\!currentUser!_lastSettings.txt"

        if not exist !lls! (
            echo !GAME_TITLE! ^: no last settings file found for !currentUser!
            goto:eof
        )
        pushd !sf!

        for /F "delims=~" %%i in ('type !lls!') do set "ls=%%i"

        if not exist !ls! goto:eof

        set "lst="!sf:"=!\!ls:"=!""

        REM : update !lst! games stats for !GAME_TITLE! using !cs! ones
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\updateGameStats.bat""
        wscript /nologo !StartHiddenWait! !toBeLaunch! !cs! !lst! !gid!

        echo.
        echo !GAME_TITLE! ^: games stats were sucessfully imported for !currentUser!

    goto:eof
    REM : ------------------------------------------------------------------

    :importGamesStats

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
        if [!RPX_FILE!] == ["NONE"] goto:eof

        set "RPX_FILE_PATH="!codeFolder:"=!\!RPX_FILE:"=!""
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!

        REM : need to treat this game ?
        call:updateLastSettings

    goto:eof
    REM : ------------------------------------------------------------------

    :setAccount
        set /A "na=%~1"
        set /A "nu=%~2"

        set "user=!users[%nu%]!"
        set "toRemove=!user:"=!"

        set "userLeftList=!userLeftList:%toRemove%=!"

        set "accounts[%na%]=!user:"=!"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : get the last modified save file (including slots if defined)
    :getLastModifiedSaveFile

        set "saveFile="NONE""

        REM : patern
        set "pat="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!*.rar""

        REM : reverse loop => last elt is the last modified
        for /F "delims=~" %%g in ('dir /S /B /O:-D /T:W !pat! 2^>NUL') do set "saveFile="%%g""

        set "%1=!saveFile!"

    goto:eof
    REM : ------------------------------------------------------------------

    :importSavesForUsers

        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        REM : cd to codeFolder
        pushd !codeFolder!
        set "RPX_FILE="project.rpx""
		if not exist !RPX_FILE! for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!
        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
        if not exist !META_FILE! (
            echo No meta folder not found under game folder ^?^, aborting ^^!
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

        set "startTitleId=%titleId:~0,8%"
        set "endTitleId=%titleId:~8,8%"

        REM : check if a save exist for this game in MLC01_FOLDER_PATH
        set "saveFolder="!MLC01_FOLDER_PATH:"=!\usr\save\%startTitleId%\%endTitleId%""
        if not exist !saveFolder! goto:eof

        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        set "inGameSavesFolder="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
        if not exist !inGameSavesFolder! mkdir !inGameSavesFolder! > NUL 2>&1

        REM : create a rar file that contains all accounts
        pushd !inGameSavesFolder!
        set "commonRarFile="!inGameSavesFolder:"=!\!GAME_TITLE!_common.rar""
        wscript /nologo !StartHiddenWait! !rarExe! a -ed -ap"mlc01\usr\save\%startTitleId%" -ep1 -r -inul -w!BFW_LOGS! !commonRarFile! !saveFolder!

        REM : delete all accounts in
        wscript /nologo !StartHiddenWait! !rarExe! d -r -inul -w!BFW_LOGS! !commonRarFile! "mlc01\usr\save\00050000\101d6000\user\8000000*\*"

        REM : Loop on accounts array
        for /L %%l in (0,1,!nbAccount!) do (

            set /A "nAcc=%%l+1"
            set "accountFolder="!MLC01_FOLDER_PATH:"=!\usr\save\%startTitleId%\%endTitleId%\user\8000000!nAcc!""

            if exist !accountFolder! if not ["!accounts[%%l]!"] == ["SKIPPED"] (
                set "currentUser=!accounts[%%l]!"
                
                REM : save file
                set "rarFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!.rar""
                echo =========================================================
                echo !currentUser! save detected for !GAME_TITLE!
                echo ---------------------------------------------------------
                echo.
                if exist !rarFile! (

                    REM : check if slots are defined
                    set "activeSlotFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_activeSlot.txt""

                    if exist !activeSlotFile! (
                        echo "Extra save slots were defined for this game by !currentUser! ^:

                        REM : display/create slos
                        call:setExtraSavesSlots !currentUser! !GAME_FOLDER_PATH!

                        REM : enter the slot to use
                        :askSlot
                        set /P "answer=Please, enter the slot's number to use : "
                        echo !answer! | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askSlot
                        set /A "srcSlot=!answer!"

                        set "srcSlotFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_slot!srcSlot!.rar""
                        if exist !srcSlotFile! goto:slotFound
                        echo ERROR^: slot!srcSlot! does not exist^!
                        goto:askSlot

                        :slotFound
                        set "rarFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_slot!srcSlot!.rar""
                        REM : prepare the archive with commonRarFile
                        copy /Y !commonRarFile! !rarFile! > NUL 2>&1
                        REM : add user account in commonRarFile
                        wscript /nologo !StartHidden! !rarExe! a -ed -ap"mlc01\usr\save\%startTitleId%\%endTitleId%\user\80000001" -ep1 -r -inul -w!BFW_LOGS! !rarFile! "!accountFolder:"=!\*"

                    ) else (

                        REM : create a first extra slot save / overwrite the user save ?
                        choice /C yn /N /M "A save already exists for !currentUser!, create a new extra slot and activate it? (y, n) : "
                        if !ERRORLEVEL! EQU 1 (
                            REM : create a new extra slot and activate it
                            call:setExtraSavesSlots !currentUser! !GAME_FOLDER_PATH! "imported from !MLC01_FOLDER_PATH:"=!"

                            REM : get the last modified save for currentUser
                            set "lastSlot="NONE""
                            call:getLastModifiedSaveFile lastSlot
                            if not [!lastSlot!] == ["NONE"]  set "rarFile=!lastSlot!"

                        ) else (
                            choice /C yn /N /M "Overwrite save for !currentUser! ? (y, n) : "
                            if !ERRORLEVEL! EQU 2 goto:endFct

                            REM : backup the CEMU save
                            set "rarFileCemu="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!_Cemu_!DATE!.rar""
                            copy /Y !rarFile! !rarFileCemu! > NUL 2>&1
                        )

                        REM : prepare the archive with commonRarFile
                        copy /Y !commonRarFile! !rarFile! > NUL 2>&1

                        REM : add user account in commonRarFile
                        wscript /nologo !StartHidden! !rarExe! a -ed -ap"mlc01\usr\save\%startTitleId%\%endTitleId%\user\80000001" -ep1 -r -inul -w!BFW_LOGS! !rarFile! "!accountFolder:"=!\*"
                    )

                ) else (
                    REM : creates it
                    REM : prepare the archive with commonRarFile
                    copy /Y !commonRarFile! !rarFile! > NUL 2>&1

                    REM : add user account in commonRarFile
                    wscript /nologo !StartHidden! !rarExe! a -ed -ap"mlc01\usr\save\%startTitleId%\%endTitleId%\user\80000001" -ep1 -r -inul -w!BFW_LOGS! !rarFile! "!accountFolder:"=!\*"
                )

                if !importGsFlag! EQU 1 if [!gamesStatUser!] == ["!currentUser!"] (
                    echo Importing games^' stats for !currentUser!
                    echo.
                    call:importGamesStats
                )
                set /A NB_SAVES_TREATED+=1
            )
        )
        set "targetSaveFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\save\%startTitleId%\%endTitleId%""
        if not exist !targetSaveFolder! mkdir !targetSaveFolder! > NUL 2>&1
        :endFct
        del /F !commonRarFile! > NUL 2>&1

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

       set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
