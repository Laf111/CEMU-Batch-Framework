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


    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "imgConverter="!BFW_RESOURCES_PATH:"=!\convert.exe""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
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
    REM : initialize QUIET_MODE to 0 (inactive)
    set /A "QUIET_MODE=0"
    if %nbArgs% EQU 0 (
        echo Creating icons for all games
        goto:createIcons
    )
    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    if %nbArgs% NEQ 1 (
        echo ERROR on arguments passed^!
        echo SYNTAX^: "!THIS_SCRIPT!"  GAME_FOLDER_PATH
        echo given {%*}
        pause
        exit /b 99
    )

    REM : get and check GAME_FOLDER_PATH
    set GAME_FOLDER_PATH=!args[0]!
    if not exist !GAME_FOLDER_PATH! (
        echo ERROR^: CEMU folder !GAME_FOLDER_PATH! does not exist ^^!
        pause
        exit /b 1
    )

    :createIcons
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder
    echo =========================================================

    echo Launching in 30s
    echo     ^(y^)^: launch now
    echo     ^(n^)^: cancel
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice ? : " "y,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Cancelling
        choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
        goto:eof
    )
    cls
    :scanGamesFolder
    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder_cifag.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        echo =========================================================
        echo ERROR^: Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        echo List of game^'s folder^(s^)^:
        echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        echo ---------------------------------------------------------
        echo Fix-it by removing characters here replaced in the folder^'s name by^?
        echo Exiting until you rename or move those folders
        echo =========================================================
        pause
        goto:eof
    )

    set /A NB_GAMES_TREATED=0

    if %nbArgs% EQU 1 goto:treatOneGame

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
            call:jpg2Ico

        ) else (

            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            echo !folderName!^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
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
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )
    goto:ending

    :treatOneGame

    REM : check path
    call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"

    if !cr! EQU 0 (
        REM : check if folder name contains forbiden character for batch file
        set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
        call !tobeLaunch! !GAME_FOLDER_PATH!
        set /A "cr=!ERRORLEVEL!"

        if !cr! GTR 1 echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
        if !cr! EQU 1 goto:treatOneGame
        call:jpg2Ico
    )

    :ending
    if !QUIET_MODE! EQU 1 goto:exiting

    echo =========================================================
    echo Treated !NB_GAMES_TREATED! games
    echo #########################################################
    echo This windows will close automatically in 15s
    echo     ^(n^)^: don^'t close^, i want to read history log first
    echo     ^(q^)^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM Waiting before exiting
        pause
    )

    :exiting
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

    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove special characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove special characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove special characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
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

    :jpg2Ico

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

        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        REM : flag for tga Icon found
        set /A "tgaFound=0"

        REM : path to meta.xml file
        set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
        if not exist !META_FILE! goto:searchJpgFile

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] goto:searchTgaFile

        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

        REM : get information on game using WiiU Library File
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';"') do set "libFileLine="%%i""

        REM : add-it to the library
        if [!libFileLine!] == ["NONE"] (
             set "titleIdIco=%titleId%"
             REM : add a line in wiiTitlesDataBase
             attrib -r !wiiTitlesDataBase! > NUL 2>&1
             echo ^'%titleId%^'^;!GAME_TITLE!^;-^;-^;-^;-^;-^;-^;^'%titleId%^'^;720^;60^;SYNCSCR >> !wiiTitlesDataBase!
            REM sorting the file
            set "tmpFile=!wiiTitlesDataBase:.csv=.tmp!"
            type !wiiTitlesDataBase! | sort > !tmpFile!
            move /Y !tmpFile! !wiiTitlesDataBase! > NUL 2>&1
            del /F !tmpFile! > NUL 2>&1

             attrib +r !wiiTitlesDataBase! > NUL 2>&1
             goto:searchTgaFile
        )

        REM : strip line to get data
        for /F "tokens=1-10 delims=;" %%a in (!libFileLine!) do (
           set "titleId=%%a"
           set "desc=%%b"
           set "productCode=%%c"
           set "companyCode=%%d"
           set "notes=%%e"
           set "versions=%%f"
           set "region=%%g"
           set "acdn=%%h"
           set "icoId=%%i"
        )
        set "titleId=%titleId:'=%"
        set "titleIdIco=%icoId:'=%"

        REM : looking for ico file close to rpx file
        set "ICO_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\00050000*.ico""
        for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL' ) do set "ICO_FILE="%%i""

        if [!ICO_FILE!] == ["NONE"] goto:searchTgaFile

        set "NEW_ICO_PATH="!GAME_FOLDER_PATH:"=!\Cemu\%titleId%.ico""
        if [!ICO_FILE!] == ["%titleIdIco%.ico"] goto:checkDataBase

        set "OLD_ICO_PATH="!GAME_FOLDER_PATH:"=!\Cemu\!ICO_FILE:"=!""

        REM : renaming ico file with title Id
        move /Y !OLD_ICO_PATH! !NEW_ICO_PATH! > NUL 2>&1

        :checkDataBase
        set "dataBaseIco="!BFW_PATH:"=!\resources\gamesIcons\%titleIdIco%.ico""
        REM : copy ico to dadabase if needed
        if not exist !dataBaseIco! copy /Y !NEW_ICO_PATH! !dataBaseIco! > NUL 2>&1

        goto:eof

        :searchTgaFile
        set "TGA_FILE="!GAME_FOLDER_PATH:"=!\meta\iconTex.tga""
        if not exist !TGA_FILE! goto:searchJpgFile

        set "INPUT_IMG=!TGA_FILE!"
        set /A "tgaFound=1"
        goto:convert

        :searchJpgFile
        REM : search for jpg file
        set "JPG_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\*.jpg""
        for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL' ) do set "JPG_FILE="%%i""

        echo =========================================================
        echo - !GAME_TITLE!
        echo ---------------------------------------------------------
        echo.

        REM : if a ico file alread exist, exit
        if [!JPG_FILE!] == ["NONE"] (
            echo No jpg file found in the Cemu folder^, skip this game^!
            goto:eof
        )

        set "OLD_JPG_PATH="!GAME_FOLDER_PATH:"=!\Cemu\!JPG_FILE:"=!""
        set "INPUT_IMG="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.jpg""
        REM : rename JPEG_FILE with GAME_TITLE (if needed)
        if not exist !INPUT_IMG! (
            echo Renaming !JPG_FILE:"=!" to !GAME_TITLE!.jpg
            move /Y !OLD_JPG_PATH! !INPUT_IMG! > NUL 2>&1
        )
        :convert
        set "CemuSubFolder="!GAME_FOLDER_PATH:"=!\Cemu""
        if not exist !CemuSubFolder! mkdir !CemuSubFolder! > NUL 2>&1
        set "ICO_PATH="!CemuSubFolder:"=!\%titleId%.ico""

        echo Creating !GAME_TITLE! icon
        REM : convert-it in ICO centered format
        call !imgConverter! !INPUT_IMG! -resize 256x256 !ICO_PATH!

        if !ERRORLEVEL! EQU 0 (
            echo !GAME_TITLE! icon created^!
            if !tgaFound! EQU 0 del /F !NEW_JPG_PATH! > NUL 2>&1
            set /A NB_GAMES_TREATED+=1
            del /F !INPUT_IMG! > NUL 2>&1
        ) else (
            echo Error when launching Conversion^!
            pause
        )

        set "dataBaseIco="!BFW_PATH:"=!\resources\gamesIcons\%titleIdIco%.ico""
        REM : copy ico to dadabase if needed
        if !tgaFound! EQU 0 if not exist !dataBaseIco! copy /Y !ICO_PATH! !dataBaseIco! > NUL 2>&1

        echo.

    goto:eof

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
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
