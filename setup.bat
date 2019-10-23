@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    REM : CEMU's Batch FrameWork Version
    set "BFW_VERSION=V15"

    set "THIS_SCRIPT=%~0"
    title -= BatchFw %BFW_VERSION% setup =-

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_PATH=!SCRIPT_FOLDER:\"="!"

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        @echo ERROR Remove DOS reserved characters from the path "!THIS_SCRIPT!"^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"

    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    REM : paths and tools used
    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""

    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
    set "quick_Any2Ico="!BFW_RESOURCES_PATH:"=!\quick_Any2Ico.exe""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "browseFile="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFileDialog.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : initialize log file for current host (if needed)
    call:initLogForHost

    REM : set current char codeset
    call:setCharSet

    REM : check if file system is NTFS
    for %%i in (!BFW_PATH!) do for /F "tokens=2 delims=~=" %%j in ('wmic path win32_volume where "Caption='%%~di\\'" get FileSystem /value ^| find /I /V "NTFS"') do (

        @echo This volume is not an NTFS one^^!
        @echo BatchFw use Symlinks and need to be installed on a NTFS volume
        pause
        exit 2
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : rename folders that contains forbiden characters : & ! .
    wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!GAMES_FOLDER! /REPLACECI^:^^!^: /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE

    REM : check if DLC and update folders are presents (some games need to be prepared)
    call:checkGamesToBePrepared

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
        title -= Install BatchFw %BFW_VERSION% =-
        goto:beginSetup
    )

    if %nbArgs% NEQ 1 (
        @echo ERROR on arguments passed^(%nbArgs%^)
        @echo SYNTAXE^: "!THIS_SCRIPT!" OUTPUT_FOLDER
        @echo given {%*}
        pause
        exit 9
    )

    REM : get and check OUTPUT_FOLDER
    set "OUTPUT_FOLDER=!args[0]!"
    for %%a in (!OUTPUT_FOLDER!) do set "drive=%%~da"
    if [!OUTPUT_FOLDER!] == ["!drive!\"] set "OUTPUT_FOLDER="!drive!""

    :beginSetup

    call:cleanHostLogFile BFW_VERSION

    set "msg="BFW_VERSION=%BFW_VERSION%""
    call:log2HostFile !msg!

    @echo Checking for update ^.^.^.
    REM : update BatchFw
    set "ubw="!BFW_TOOLS_PATH:"=!\updateBatchFw.bat""
    call !ubw! %BFW_VERSION%
    set /A "cr=!ERRORLEVEL!"
    if !cr! EQU 0 (

        @echo BatchFw updated^, please relaunch
        timeout /t 4 > NUL 2>&1
        set "ChangeLog="!BFW_PATH:"=!\Change.log""
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !ChangeLog!
        exit 75
    )
    timeout /t 2 > NUL 2>&1
    set "readme="!BFW_PATH:"=!\BatchFw_readme.txt""
    set /A "QUIET_MODE=0"
    if exist !readme! set /A "QUIET_MODE=1"

    :scanGamesFolder
    set "OUTPUT_FOLDER=!OUTPUT_FOLDER:\\=\!"
    cls
    if %nbArgs% EQU 0 (
        @echo =========================================================
        @echo            CEMU^'s Batch FrameWork !BFW_VERSION! installer
        @echo =========================================================
        @echo ^(in case of false input close this main window to cancel^)
        if %QUIET_MODE% EQU 0 (
            @echo ---------------------------------------------------------
            @echo BatchFw is a batch framework created to launch easily all
            @echo your RPX games ^(loadiines format^) using many versions of
            @echo CEMU^.
            @echo.
            @echo It is now limited only to CEMU's versions ^>=1^.11 that^:
            @echo -support the -mlc argument
            @echo -use the last saves format
            @echo.
            @echo It gathers all game^'s data in each game^'s folder and so
            @echo ease the CEMU^'s update process and make your loadiine
            @echo games library portable^.
        )
    ) else (
        @echo =========================================================
        @echo Set your BatchFw^'s settings and register more than
        @echo one CEMU's version
        @echo =========================================================
        @echo ^(in case of false input close this main window to cancel^)
    )

    :validateGamesLibrary

    @echo ---------------------------------------------------------
    @echo Scanning your games library^.^.^.
    @echo ---------------------------------------------------------

    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        @echo =========================================================
        @echo ERROR Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        @echo List of game^'s folder^(s^)^:
        @echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        @echo ---------------------------------------------------------
        @echo Fix-it by removing characters here replaced in the folder^'s name by ^'^?^'
        @echo Otherwise, they will be ignored by batchFW^!
        @echo =========================================================
        pause
    )
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : scanning games folder (parent folder of _CEMU_Batch_Framework folder)
    set /A NB_GAMES_VALID=0
    REM : searching for code folder to find in only one rpx file (the bigger one)
    for /F "delims=~" %%i in ('dir /B /S /A:D code ^| find /I /V "\mlc01" 2^> NUL') do (

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

            if !cr! GTR 1 @echo Please rename the game^'s folder to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:searchGameIn

        ) else (

            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            @echo !folderName!^: Unsupported characters found^, rename it otherwise it will be ignored by BatchFW ^^!
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

            call:getUserInput "Renaming folder for you? (y,n): " "y,n" ANSWER

            if [!ANSWER!] == ["y"] move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    @echo =========================================================
    @echo ^> %NB_GAMES_VALID% valid games found

    if %QUIET_MODE% EQU 0 (

        @echo ---------------------------------------------------------
        call:getUserInput "Read the goals of BatchFW? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] goto:goalsOK

        set "tmpFile="!BFW_PATH:"=!\doc\goal.txt""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :goalsOK
        call:getUserInput "Read informations on CEMU interfaces history? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] goto:iFOK

        set "tmpFile="!BFW_PATH:"=!\doc\cemuInterfacesHistory.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :iFOK
        call:getUserInput "Read how graphic packs are handled? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] goto:wiiuOK

        set "tmpFile="!BFW_PATH:"=!\doc\graphicPacksHandling.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

       :wiiuOK
        call:getUserInput "Read about Wii-U transferts feature? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] goto:importModForGames

        set "tmpFile="!BFW_PATH:"=!\doc\syncWii-U.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
    )

    :importModForGames
    cls
    @echo ---------------------------------------------------------
    call:getUserInput "Have you got some mods for your games that you wish to import (y,n)? " "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:askGpCompletion

    :askAnotherModFolder
    set "im="!BFW_TOOLS_PATH:"=!\importModsForAllGames.bat""
    wscript /nologo !StartWait! !im!

    call:getUserInput "Do you want to add another mod folder (y,n)?" "y,n" ANSWER
    if [!ANSWER!] == ["y"] goto:askAnotherModFolder
    @echo Next time use the shortcut in
    @echo Wii-U Games^\_BatchFw^\Tools^\Graphic packs^\Import Mods for my games^.lnk

    @echo ^> Mods were imported in each game^'s folder

    :askGpCompletion
    @echo ---------------------------------------------------------
    REM : flush logFile of COMPLETE_GP
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "COMPLETE_GP" 2^>NUL') do call:cleanHostLogFile COMPLETE_GP

    choice /C yn /N /M "Do you want BatchFW to complete graphic packs? (y,n):"
    if !ERRORLEVEL! EQU 1 (
        set "msg="COMPLETE_GP=YES""
        call:log2HostFile !msg!
        goto:askRatios
    )
    REM : else
    goto:askScreenMode

    :askRatios
    REM : get the users list
    set "ratiosList=EMPTY"
    set /A "changeArList=0"

    REM : search in all Host_*.log
    set "pat="!BFW_PATH:"=!\logs\Host_*.log""
    for /F %%i in ('dir /S /B !pat! 2^>NUL') do (
        set "currentLogFile="%%i""

        REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (
            REM : add to the list if not already present
            echo !ratiosList! | find /V "%%i" > NUL 2>&1 && set "ratiosList=%%i !ratiosList!"
        )
    )

    if ["%ratiosList%"] == ["EMPTY"] goto:getRatios

    set "ratiosList=!ratiosList:EMPTY=!"
    @echo Aspect ratios already defined in BatchFW: !ratiosList!
    choice /C ny /N /M "Change this list? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askScreenMode

    REM : flush logFile of DESIRED_ASPECT_RATIO
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "DESIRED_ASPECT_RATIO" 2^>NUL') do call:cleanHostLogFile DESIRED_ASPECT_RATIO

    :getRatios
    set /A "changeArList=1"

    @echo ---------------------------------------------------------
    @echo Choose your display ratio ^(for extra graphic packs^) ^:
    @echo.
    @echo     ^(1^)^: 16/9
    @echo     ^(2^)^: 16/10
    @echo     ^(3^)^: 21/9
    @echo     ^(4^)^: 4/3
    @echo     ^(5^)^: 16/3 ^(48/9^)
    @echo     ^(c^)^: cancel
    @echo ---------------------------------------------------------

    :askRatioAgain
    choice /C 12345c /N /M "Enter your choice: "
    if !ERRORLEVEL! EQU 1 (
        set "msg="DESIRED_ASPECT_RATIO=169""
        call:log2HostFile !msg!
    )
    if !ERRORLEVEL! EQU 2 (
        set "msg="DESIRED_ASPECT_RATIO=1610""
        call:log2HostFile !msg!
    )
    if !ERRORLEVEL! EQU 3 (
        set "msg="DESIRED_ASPECT_RATIO=219""
        call:log2HostFile !msg!
    )
    if !ERRORLEVEL! EQU 4 (
        set "msg="DESIRED_ASPECT_RATIO=43""
        call:log2HostFile !msg!
    )
    if !ERRORLEVEL! EQU 5 (
        set "msg="DESIRED_ASPECT_RATIO=489""
        call:log2HostFile !msg!
    )
    choice /C yn /N /M "Add another ratio? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askRatioAgain

    :askScreenMode
    @echo ---------------------------------------------------------
    REM : flush logFile of SCREEN_MODE
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "SCREEN_MODE" 2^>NUL') do call:cleanHostLogFile SCREEN_MODE

    choice /C yn /N /M "Do you want to launch CEMU in fullscreen? (y,n):"
    if !ERRORLEVEL! EQU 1 goto:getUserMode

    set "msg="SCREEN_MODE=windowed""
    call:log2HostFile !msg!

    :externalGP
    REM : check if GAMES_FOLDER\_BatchFw_Graphic_Packs exist
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    REM : check if an internet connection is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] goto:extractV3pack

    @echo ---------------------------------------------------------
    @echo Checking latest graphics packs^'update

    REM : update graphic packs
    set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
    call !ugp!
    set /A "cr=!ERRORLEVEL!"
    REM : if user cancelled the update
    if !cr! EQU 1 if not exist !BFW_GP_FOLDER! goto:beginExtraction
    if !changeArList! EQU 1 if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        REM : force a graphic pack update
        @echo Forcing a GFX pack update to take new ratios into account^.^.^.
        @echo.

        REM : forcing a GFX pack update to add GFX packs for new games
        set "gfxUpdate="!BFW_TOOLS_PATH:"=!\forceGraphicPackUpdate.bat""
        call !gfxUpdate! -silent
    )

    if !cr! EQU 0 goto:getUserMode

    :extractV3pack
    if %QUIET_MODE% EQU 1 goto:getUserMode

    :beginExtraction
    REM : first launch of setup.bat
    if exist !BFW_GP_FOLDER!  goto:getUserMode
    mkdir !BFW_GP_FOLDER! > NUL 2>&1

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Extracting integrated graphics packs^.^.^.
    @echo ---------------------------------------------------------
    REM : extract embeded V3 packs
    set "rarFile="!BFW_RESOURCES_PATH:"=!\V3_GFX_Packs.rar""

    wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul -w"!BFW_PATH:"=!logs" !rarFile! !BFW_GP_FOLDER! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo ERROR while extracting V3_GFX_Packs^.rar^, exiting 1
        pause
        exit /b 1
    )

    @echo ^> Graphic packs installed from archive

    REM : get users
    :getUserMode

    REM : rename GFX folders that contains forbiden characters : & ! .
    wscript /nologo !StartHidden! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE

    REM : by default: create shortcuts
    @echo ---------------------------------------------------------

    REM : get the users list
    set "usersList=EMPTY"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "USER_REGISTERED" 2^>NUL') do set "usersList=!usersList! [%%i]"

    if not ["%usersList%"] == ["EMPTY"] goto:handleUsers
    choice /C ny /N /M "Do you want to add more than one user? (y,n):"
    if !ERRORLEVEL! EQU 1 (
        set "msg="USER_REGISTERED=!USERNAME!""
        call:log2HostFile !msg!
        goto:getSoftware
    )
    :handleUsers
    if ["%usersList%"] == ["EMPTY"] goto:getUsers

    set "usersList=!usersList:EMPTY=!"
    @echo Users already registered in BatchFW: !usersList!
    choice /C ny /N /M "Change this list? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:getSoftware

    REM : flush logFile of USER_REGISTERED
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "USER_REGISTERED" 2^>NUL') do call:cleanHostLogFile USER_REGISTERED

    REM : Get BatchFw's users registered with the current windows profile
    set /A "alreadyAsked=0"
    :getUsers

    if !alreadyAsked! EQU 1 goto:batchFwUsers
    REM : Have a Wii-U ?
    @echo You can use your Wii-U to create BatchFw^'users list
    @echo For that^, you need to had dumped your NAND in order
    @echo to provide files to play online and have launched
    @echo ftpiiU server on your Wii-U^.
    @echo.
    choice /C yn /N /M "Continue and create users' list from your Wii-U? (y,n):"
    if !ERRORLEVEL! EQU 2 set /A "alreadyAsked=1" && goto:batchFwUsers

    REM : get online files and accounts
    pushd !BFW_TOOLS_PATH!
    set "tobeLaunch="!BFW_TOOLS_PATH:"=!\getWiiuOnlineFiles.bat""
    call !tobeLaunch! -wiiuAccounts
    set /A "cr=!ERRORLEVEL!"
    pushd !GAMES_FOLDER!
    if !cr! NEQ 0 (
        @echo.
        @echo Fail to get users from wiiU ^!
        goto:handleUsers
    )

    @echo.
    choice /C yn /N /M "Do you want to import some saves from your WII-U now? (y,n):"
    if !ERRORLEVEL! EQU 2 goto:getSoftware

    @echo.
    @echo BatchFw need to take a snapshot of your Wii-U to
    @echo will list games^, saves^, updates and DLC
    @echo precising where they are installed ^(mlc or usb^)
    @echo.

    pushd !BFW_TOOLS_PATH!
    set "tobeLaunch="!BFW_TOOLS_PATH:"=!\scanWiiU.bat""
    wscript /nologo !StartWait! !tobeLaunch!

    @echo.
    @echo Now getting your wii-U saves^.^.^.
    @echo.

    set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importWiiuSaves.bat""
    wscript /nologo !StartWait! !tobeLaunch!
    pushd !GAMES_FOLDER!
    goto:getSoftware
    
    :batchFwUsers
    set /P "input=Please enter BatchFw's user name : "
    call:secureUserNameForBfw "!input!" safeInput
    if !ERRORLEVEL! NEQ 0 (
        @echo ^~^, ^* or ^= are not allowed characters ^!
        @echo Please remove them
        goto:getUsers
    )

    if not ["!safeInput!"] == ["!input!"] (
        @echo Some unhandled characters were found ^!
        @echo ^^ ^| ^< ^> ^" ^: ^/ ^\ ^? ^. ^! ^& %%
        @echo list = ^^ ^| ^< ^> ^" ^: ^/ ^\ ^? ^. ^! ^& %%
        choice /C yn /N /M "Use !safeInput! instead ? (y,n): "
        if !ERRORLEVEL! EQU 2 goto:getUsers
    )
    set "user="!safeInput!""

    set "msg="USER_REGISTERED=!user:"=!""
    call:log2HostFile !msg!

    choice /C yn /N /M "Add another user? (y,n): "
    if !ERRORLEVEL! EQU 1  goto:getUsers

    :getSoftware
    cls
    @echo ---------------------------------------------------------

    REM : get the software list
    set "softwareList=EMPTY"
    for /F "tokens=2 delims=~@" %%i in ('type !logFile! ^| find "TO_BE_LAUNCHED" 2^>NUL') do (

        set "command=%%i"
   
        call:isSoftwareValid "!command!" program valid

        if !valid! EQU 1 (
            set "softwareList=!softwareList! !program!"
        ) else (
            call:cleanHostLogFile !program:"='!
        )
    )
    if not ["!softwareList!"] == ["EMPTY"] goto:handleSoftware

    @echo Do you want BatchFw to launch a third party software before
    @echo launching CEMU^?
    @echo ^(E^.G^. DS4Windows^, wiimoteHook^, cemuGyro^, a speed hack^.^.^.^)
    @echo.
    @echo They will be launched in the order you will enter here^.
    @echo.
    choice /C ny /N /M "Register a third party software? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    @echo.
    :handleSoftware
    if ["!softwareList!"] == ["EMPTY"] goto:askS

    set "softwareList=!softwareList:EMPTY=!"
    @echo Software already registered in BatchFW: !softwareList!
    choice /C ny /N /M "Change this list? (y,n) "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    REM : flush logFile of TO_BE_LAUNCHED
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "TO_BE_LAUNCHED" 2^>NUL') do call:cleanHostLogFile TO_BE_LAUNCHED

    :askS
    @echo ---------------------------------------------------------
    choice /C ny /N /M "Do you need to enter arguments for the 3rd party software? (y,n): "
    if !ERRORLEVEL! EQU 2 goto:askSpath

    REM : browse to the file
    :browse3rdP
    for /F %%b in ('cscript /nologo !browseFile! "Please browse to 3rd party program"') do set "file=%%b" && set "spath=!file:?= !"
    if [!spath!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders
        goto:browse3rdP
    )
    goto:reg3rdPartySotware


    :askSpath
    @echo Enter full paths for the software and its arguments
    @echo ALL SURROUNDED by double quotes^.
    set /P "spath=Enter the full command line: "

    REM : resolve venv for search
    for /F "tokens=1 delims=~'" %%j in ("!spath!") do set "program="%%j""

    if not exist !program! (
        @echo !spath! is not valid ^!
        goto:askSpath
    )

    :reg3rdPartySotware
    set "spath=!spath:"='!"
    set "msg=TO_BE_LAUNCHED@!spath!"

    choice /C ny /N /M "Do you want BatchFw to close it after Cemu stops? (y,n) "
    if !ERRORLEVEL! EQU 1  set "msg="!msg!@N""
    if !ERRORLEVEL! EQU 2  set "msg="!msg!@Y""

    call:log2HostFile !msg!

    set "name="NONE""
    set "program="NONE""
    set "firstArg="NONE""
    for /F "tokens=1 delims=~'" %%j in ("!spath!") do set "program="%%j""
    for /F "delims=~" %%i in (!program!) do set "name=%%~nxi"

    set "icoFile=!name:.exe=.ico!"
    set "icoPath="!BFW_RESOURCES_PATH:"=!\icons\!icoFile!""
    if not exist !icoPath! call !quick_Any2Ico! "-res=!program:"=!" "-icon=!icoPath:"=!" -formats=256

    choice /C yn /N /M "Add another third party software? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:askSpath

    :askExtMlC01Folders
    set /A "useMlcFolderFlag=0"
    if %nbArgs% EQU 0 if !QUIET_MODE! EQU 0 (
        @echo ---------------------------------------------------------
        choice /C ny /N /M "Do you use an/some external mlc01 folder(s) you wish to import? (y,n): "
        if !ERRORLEVEL! EQU 1 goto:getOuptutsFolder

        set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
        wscript /nologo !Start! "%windir%\System32\notepad.exe" !tmpFile!

        @echo.
        @echo If you have defined more than one user^, you^'ll need to
        @echo define which user^'s save is it.
        @echo.

       :getExtMlc01
        set "script="!BFW_TOOLS_PATH:"=!\moveMlc01DataForAllGames.bat""
        choice /C mc /CS /N /M "Move (m) or copy (c) data?"
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 2 set "script="!BFW_TOOLS_PATH:"=!\copyMlc01DataForAllGames.bat""

        wscript /nologo !StartWait! !script!

        choice /C yn /N /M "Add another external mlc01 folder? (y,n): "
        if !ERRORLEVEL! EQU 1 goto:getExtMlc01

        @echo ^> Externals mlc01 data was imported^!
        @echo.
        @echo Next time use the shortcuts in
        @echo Wii-U Games^\_BatchFw^\Tools^\Mlc01 folder handling
        @echo and^/or
        @echo Wii-U Games^\_BatchFw^\Tools^\Games^'s saves to import
        @echo only save for a user from a ml01 folder
        @echo.
        pause
        set /A "useMlcFolderFlag=1"

    )

    :getOuptutsFolder
    cls
    REM : skip if one arg is given
    if %nbArgs% EQU 1 (
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        @echo ^> Ouptuts will be created in !OUTPUT_FOLDER:"=!\Wii-U Games
        timeout /T 3 > NUL 2>&1
        goto:getOuptutsType
    )

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Define target folder for shortcuts ^(a Wii-U Games subfolder will be created^)
    @echo ---------------------------------------------------------
    :askOutputFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select an output folder (a Wii-U Games subfolder will be created)"') do set "folder=%%b" && set "OUTPUT_FOLDER=!folder:?= !"
    if [!OUTPUT_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askOutputFolder
    )
    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !OUTPUT_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo Path to !OUTPUT_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askOutputFolder
    )

    set "cemuFolderCheck=!OUTPUT_FOLDER:"=!\Cemu.exe""

    if exist !cemuFolderCheck! (
        @echo Not a Cemu install folder^, please enter the output folder
        @echo ^(where shortcuts or exe will be created^)
        goto:getOuptutsFolder
    )

    @echo ^> Ouptuts will be created in !OUTPUT_FOLDER:"=!\Wii-U Games
    timeout /T 3 > NUL 2>&1

    :getOuptutsType
    if %QUIET_MODE% EQU 0 if !NB_GAMES_VALID! EQU 0 (
        if not exist !BFW_WIIU_FOLDER! (
            @echo No loadiines games^(^*^.rpx^) founds under !GAMES_FOLDER!^!
            @echo Please extract BatchFw in your loadiines games^' folder
            REM : show doc
            set "tmpFile="!BFW_PATH:"=!\doc\updateInstallUse.txt""
            wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
            pause
            @echo Exiting 10
        )
    )

    set "outputType=LNK"
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo What kind of outputs do you want to launch your games^?
    @echo.
    @echo 1^: Windows shortcuts
    @echo 2^: Executables files ^(to define Steam shorcuts^)
    @echo.
    REM : display only if shortcuts have already been created
    set /A "alreadyInstalled=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set /A "alreadyInstalled=1"
    if %alreadyInstalled% EQU 1 (
        @echo 3^: Cancel^, i just wanted to set BatchFw^'s settings
        @echo.
        call:getUserInput "Enter your choice ?: " "1,2,3" ANSWER
    ) else (
        if exist !BFW_WIIU_FOLDER! if !NB_GAMES_VALID! EQU 0 (
            @echo 3^: Cancel^, for dumping my games now
            call:getUserInput "Enter your choice ?: " "1,2,3" ANSWER
        ) else (
            call:getUserInput "Enter your choice ?: " "1,2" ANSWER
        )
        if not exist !BFW_WIIU_FOLDER! (
            call:getUserInput "Enter your choice ?: " "1,2" ANSWER
        )
    )
    if [!ANSWER!] == ["3"] exit 70
    if [!ANSWER!] == ["1"] (

        REM : instanciate a fixBrokenShortcut.bat
        set "fbsf="!OUTPUT_FOLDER:"=!\Wii-U Games\BatchFw\Tools\Shortcuts""
        if exist !fbsf! goto:registerCemuInstalls

        mkdir !fbsf! > NUL 2>&1
        robocopy !BFW_TOOLS_PATH! !fbsf! "fixBrokenShortcuts.bat" > NUL 2>&1

        set "fnrLog="!BFW_PATH:"=!\logs\fnr_setup.log""
        !fnrPath! --cl --dir !fbsf! --fileMask "fixBrokenShortcuts.bat" --find "TO_BE_REPLACED" --replace !GAMES_FOLDER! --logFile !fnrLog!  > NUL
        del /F !fnrLog! > NUL 2>&1

        goto:registerCemuInstalls
    )
    set "outputType=EXE"
    set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
    if %QUIET_MODE% EQU 0 (
        set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
    )

    :registerCemuInstalls

    REM : get GPU_VENDOR
    set "GPU_VENDOR=NOT_FOUND"
    set "gpuType=OTHER"
    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get Name /value ^| find "="') do (
        set "string=%%i"
        echo "!string!" | find /I "NVIDIA" > NUL 2>&1 && (
            set "gpuType=NVIDIA"
            set "GPU_VENDOR=!string: =!"
        )
        echo "!string!" | find /I "AMD" > NUL 2>&1 && (
            set "gpuType=AMD"
            set "GPU_VENDOR=!string: =!"
        )
    )

    if ["!GPU_VENDOR!"] == ["NOT_FOUND"] set "GPU_VENDOR=!string: =!"
    call:secureStringPathForDos !GPU_VENDOR! GPU_VENDOR

    cls

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Please^, define your CEMU^'s installations paths
    @echo ---------------------------------------------------------
    @echo ^> No need to have cemuHook installed ^(you^'ll be asked
    @echo    to install it^)
    @echo ^> If you install CEMU^>=1^.15^.1^, you^'d better have it
    @echo installed on C^: to avoid a long copy of your GLCache into
    @echo CEMU^'s install folder
    @echo ---------------------------------------------------------

    REM : intialize Number of Cemu Version beginning from 0
    set /A "NBCV=0"

    :askCemuFolder
    set /A "NBCV+=1"

    for /F %%b in ('cscript /nologo !browseFolder! "Select a Cemu's install folder"') do set "folder=%%b" && set "CEMU_FOLDER=!folder:?= !"
    if [!CEMU_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askCemuFolder
    )

    REM : check if folder name contains forbiden character for !CEMU_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !CEMU_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo Path to !CEMU_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askCemuFolder
    )
    REM : check that cemu.exe exist in
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe" "
    if not exist !cemuExe! (
        @echo ERROR^, No Cemu^.exe file found under !CEMU_FOLDER! ^^!
        goto:askCemuFolder
    )

    if !cr! EQU 1 (
        set /A "NBCV-=1"
        goto:askCemuFolder
    )

    REM : basename of CEMU_FOLDER to get CEMU version
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"
    @echo CEMU install %NBCV%^: !CEMU_FOLDER!
    call:regCemuInstall %NBCV% !CEMU_FOLDER!

    @echo ---------------------------------------------------------
    call:getUserInput "Do you want to add another version? (y,n)" "y,n" ANSWER
    if [!ANSWER!] == ["y"] goto:askCemuFolder

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo ^> Done
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if %QUIET_MODE% EQU 1 goto:done

    @echo You^'ll need to launch each game one time with the last versions
    @echo of CEMU you used^, to let BatchFw copy the transferable cache into
    @echo the game^'s folder^.^(lets boot the game to the menu^)
    @echo.

    call:getUserInput "Would you like to see how BatchFW works? (y,n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:done

    set "tmpFile="!BFW_PATH:"=!\doc\howItWorks.txt""
    wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

    :done
    cls
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if not exist !readme! (
        @echo BatchFW_readme^.txt created^, switch this script in ^'silent mode^'
        @echo if needed open BatchFW_readme^.txt with its shortcut
        REM : building documentation
        call:buildDoc
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    )
    @echo If you want to change global CEMU^'s settings you^'ve just
    @echo entered here^:
    @echo ---------------------------------------------------------
    @echo ^> simply delete the shortcuts and recreate them using
    @echo Wii-U Games^\Create CEMU^'s shortcuts for selected games^.lnk
    @echo to register a SINGLE version of CEMU
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo If you encounter any issues or have made a mistake when
    @echo collecting settings for a game^:
    @echo ---------------------------------------------------------
    @echo ^> delete the settings saved for !CEMU_FOLDER_NAME! using
    @echo the shortcut in Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!
    @echo Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo If you want to change Batch^'s settings ^(such as graphic
    @echo pack completion^, aspects ratios^) and^/or^ register more
    @echo than one version of CEMU^:
    @echo ---------------------------------------------------------
    @echo ^> relaunch this script from its shortcut
    @echo Wii-U Games^\Set BatchFw settings and register CEMU installs^.lnk
    @echo ---------------------------------------------------------
    @echo You can now only use the shortcuts created in
    @echo !OUTPUT_FOLDER:"=!\Wii-U Games
    @echo There^'s no need to launch scripts from _BatchFw_Install now^!
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if %nbArgs% EQU 1 exit 0
    @echo Openning !OUTPUT_FOLDER:"=!\Wii-U Games^.^.^.
    timeout /T 4 > NUL 2>&1

    set "folder="!OUTPUT_FOLDER:"=!\Wii-U Games""
    wscript /nologo !Start! "%windir%\explorer.exe" !folder!
    @echo =========================================================
    @echo This windows will close automatically in 15s
    @echo     ^(n^)^: don^'t close^, i want to read history log first
    @echo     ^(q^)^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "Enter your choice?: " "q, n" ANSWER 15
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )

    endlocal
    if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions
    
    REM : check if (DLC) or (UPDATE DATA) folders exist
    :checkGamesToBePrepared

        REM : already pushed to GAMES_FOLDER
        set /A "needImport=0"

        set "pat=*(DLC)*"
        for /F "delims=~" %%i in ('dir /A:d /B !pat! 2^>NUL') do set /A "needImport=1"
        set "pat=*(UPDATE DATA)*"
        for /F "delims=~" %%i in ('dir /A:d /B !pat! 2^>NUL') do set /A "needImport=1"

        REM : if need call import script and wait
        if !needImport! EQU 0 goto:eof

        @echo Hum^.^.^. some DLC and UPDATE DATA folders were found
        @echo Preparing those games for emulation^.^.^.
        timeout /T 5 > NUL 2>&1

        REM : calling importGames.bat
        set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importGames.bat""
        call !tobeLaunch! !GAMES_FOLDER!

        @echo ---------------------------------------------------------
        @echo ^> Games ready for emulation
        timeout /T 5 > NUL 2>&1
        cls

    goto:eof
    REM : ------------------------------------------------------------------


    REM : build doc
    :buildDoc
        set "tmpFile="!BFW_PATH:"=!\doc\goal.txt""
        type !tmpFile! > !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\updateInstallUse.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\howItWorks.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\cemuInterfacesHistory.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
        type !tmpFile! >> !readme!
        set "tmpFile="!BFW_PATH:"=!\doc\contributors.txt""
        type !tmpFile! >> !readme!
    goto:eof
    REM : ------------------------------------------------------------------

    :regCemuInstall

        set "cemuNumber=%1"
        set "CEMU_FOLDER="%~2""

        for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"

        if %nbArgs% EQU 1 goto:createShortcuts
        if !useMlcFolderFlag! EQU 1 goto:createShortcuts

        REM : first Cemu install
        if %cemuNumber% EQU 1 (

            set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
            if %QUIET_MODE% EQU 0  wscript /nologo !Start! "%windir%\System32\notepad.exe" !tmpFile!
        )

        choice /C yn /CS /N /M "Use !CEMU_FOLDER_NAME! to copy/move mlc01 (updates, dlc, game saves) your game's folder? (y,n):"
        if !ERRORLEVEL! EQU 2 goto:createShortcuts

        choice /C mc /CS /N /M "Move (m) or copy (c)?"
        set /A "cr=!ERRORLEVEL!"

        set "mlc01="!CEMU_FOLDER:"=!\mlc01""

        if !cr! EQU 1 call:move
        if !cr! EQU 2 call:copy

       :createShortcuts

        REM : check if CemuHook is installed
        set "dllFile="!CEMU_FOLDER:"=!\keystone.dll""

       :checkCemuHook
        if exist !dllFile! goto:checkSharedFonts

        @echo ---------------------------------------------------------
        @echo CemuHook was not found^. It is requiered to
        @echo - play videos
        @echo - enable FPS++ packs
        @echo - to enable controller^'s motions
        if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] goto:getCemuVersion

        set "defaultBrowser="NOT_FOUND""
        for /f "delims=Z tokens=2" %%a in ('reg query "HKEY_CURRENT_USER\Software\Clients\StartMenuInternet" /s 2^>NUL ^| findStr /ri ".exe""$"') do set "defaultBrowser=%%a"
        if [!defaultBrowser!] == ["NOT_FOUND"] for /f "delims=Z tokens=2" %%a in ('reg query "HKEY_LOCAL_MACHINE\Software\Clients\StartMenuInternet" /s 2^>NUL ^| findStr /ri ".exe""$"') do set "defaultBrowser=%%a"
        if [!defaultBrowser!] == ["NOT_FOUND"] goto:openCemuAFirstTime

        @echo Opening CemuHook download page^.^.^.
        @echo Download and extract CemuHook in !CEMU_FOLDER!

        wscript /nologo !Start! !defaultBrowser! "https://cemuhook.sshnuke.net/#Downloads"

        timeout /T 2 > NUL 2>&1
        wscript /nologo !Start! "%windir%\explorer.exe" !CEMU_FOLDER!

        choice /C y /N /M "If CemuHook is installed, continue? (y): "
        goto:checkCemuHook

       :checkSharedFonts

        REM : check if sharedFonts were downloaded
        set "sharedFonts="!CEMU_FOLDER:"=!\sharedFonts""
        if exist !sharedFonts! goto:getCemuVersion

       :openCemuAFirstTime

        @echo ---------------------------------------------------------
        @echo Openning CEMU^.^.^.
        @echo Set your REGION^, language
        @echo Download sharedFonts using Cemuhook button^, if they are missing
        @echo Then close CEMU to continue

        set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
        wscript /nologo !StartWait! !cemu!

       :getCemuVersion
        if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] if not exist !sharedFonts! @echo Download sharedFonts using Cemuhook button & goto:openCemuAFirstTime

        set "clog="!CEMU_FOLDER:"=!\log.txt""
        set /A "v1151=2"
         set "versionRead=NOT_FOUND"
         if not exist !clog! goto:openCemuAFirstTime

        for /f "tokens=1-6" %%a in ('type !clog! ^| find "Init Cemu"') do set "versionRead=%%e"
        if ["!versionRead!"] == ["NOT_FOUND"] goto:extractV2Packs

        call:compareVersions !versionRead! "1.15.1" v1151
        if ["!v1151!"] == [""] echo Error when comparing versions
        if !v1151! EQU 50 echo Error when comparing versions

        if !v1151! EQU 2 (
            call:compareVersions !versionRead! "1.14.0" result
            if ["!result!"] == [""] echo Error when comparing versions
            if !result! EQU 50 echo Error when comparing versions
            if !result! EQU 1 goto:autoImportMode
            if !result! EQU 0 goto:autoImportMode
        ) else (
            goto:autoImportMode
        )
       :extractV2Packs
        set "gfxv2="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""
        if exist !gfxv2! goto:autoImportMode

        mkdir !gfxv2! > NUL 2>&1
        set "rarFile="!BFW_RESOURCES_PATH:"=!\V2_GFX_Packs.rar""

        @echo ---------------------------------------------------------
        @echo graphic pack V2 are needed for this version^, extracting^.^.^.

        wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w"!BFW_PATH:"=!logs" !rarFile! !gfxv2! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 1 (
            @echo ERROR while extracting V2_GFX_Packs, exiting 1
            pause
            exit /b 21
        )

       :autoImportMode
        @echo ---------------------------------------------------------
        if %cemuNumber% EQU 1  (

            @echo AUTOMATIC SETTINGS IMPORT is enable by default
            @echo but if it causes issues^, you still can disable it
            @echo.
            @echo For each games^, if no settings exist for a given
            @echo version of CEMU^, BatchFw will try to find suitables
            @echo settings and you won^'t have to re-enter your settings
            @echo.
            if %QUIET_MODE% EQU 0 pause
            if %QUIET_MODE% EQU 1 timeout /t 2 > NUL 2>&1
        )

        REM : importMode
        set "argOpt="
        set "IMPORT_MODE=ENABLED"
        call:getUserInput "Disable automatic settings import? (y,n : default in 10sec): " "n,y" ANSWER 10

        if [!ANSWER!] == ["y"] (
            set "argOpt=-noImport"
            set "IMPORT_MODE=DISABLED"
        )

        set "msg="!CEMU_FOLDER_NAME! installed with automatic import=!IMPORT_MODE:"=!""
        call:log2HostFile !msg!

        set "IGNORE_PRECOMP=DISABLED"
        REM : GPU is NVIDIA => ignoring precompiled shaders cache
        if ["!gpuType!"] == ["NVIDIA"] (
            set "IGNORE_PRECOMP=ENABLED"
            set "argOpt=%argOpt% -ignorePrecomp"
        )

        set "msg="!CEMU_FOLDER_NAME! installed with ignoring precompiled shader cache=!IGNORE_PRECOMP:"=!""
        call:log2HostFile !msg!

        REM : check if main GPU is iGPU. Ask for -nolegacy if it is the case
        set "noIntel=!GPU_VENDOR:Intel=!"
        if ["!gpuType!"] == ["OTHER"] if not ["!noIntel!"] == ["!GPU_VENDOR!"] (

            @echo ---------------------------------------------------------
            REM : CEMU < 1.15.1
            if !v1151! LEQ 1 (
                call:getUserInput "Disable all Intel GPU workarounds (add -NoLegacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -noLegacy"
                goto:launchCreate
            )
            REM : CEMU >= 1.15.1
            if !v1151! EQU 0 (
                call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -Legacy"
                goto:launchCreate
            )
            if !v1151! EQU 2 (
                call:getUserInput "Enable all Intel GPU workarounds (add -Legacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -Legacy"
                goto:launchCreate
            )
        )

       :launchCreate
        if ["%outputType%"] == ["EXE"] goto:createExe

        REM : calling createShortcuts.bat
        set "tobeLaunch="!BFW_PATH:"=!\createShortcuts.bat""
        call !tobeLaunch! !CEMU_FOLDER! !OUTPUT_FOLDER! %argOpt%
        set /A "cr=!ERRORLEVEL!"

        if !cr! NEQ 0 (
            @echo ERROR in createShortcuts^, cr=!cr!
            pause
            exit /b 5
        )
        @echo ^> Shortcuts created for !CEMU_FOLDER_NAME!
        goto:eof

       :createExe
        REM : calling createExecutables.bat
        set "tobeLaunch="!BFW_PATH:"=!\createExecutables.bat""
        call !tobeLaunch! !CEMU_FOLDER! !OUTPUT_FOLDER! %argOpt%
        set /A "cr=!ERRORLEVEL!"

        if !cr! NEQ 0 (
            @echo ERROR in createCemuLancherExecutables^, cr=!cr!
            pause
            exit /b 5
        )
        @echo ^> Executables created for !CEMU_FOLDER_NAME!
    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureStringPathForDos

        set "str=%~1"
        set "str=!str:&=!"
        set "str=!str:?=!"
        set "str=!str:(=!"
        set "str=!str:)=!"
        set "str=!str:%%=!"
        set "str=!str:^=!"
        set "str=!str:"=!"
        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureUserNameForBfw
        set "str=%~1"

        REM : DOS reserved characters
        set "str=!str:&=!"
        set "str=!str:^!=!"
        set "str=!str:%%=!"

        REM : add . and ~
        set "str=!str:.=!"
        @echo !str! | find "~" > NUL 2>&1 && (
            echo Please remove ^~ ^(unsupported charcater^) from !str!
            exit /b 50
        )

        REM : add . ? (%userName%_settings.*) ?
        REM : Forbidden characters for files in WINDOWS
        set "str=!str:?=!"
        set "str=!str:\=!"
        set "str=!str:/=!"
        set "str=!str::=!"
        set "str=!str:"=!"
        set "str=!str:>=!"
        set "str=!str:<=!"
        set "str=!str:|=!"
        set "str=!str:^=!"

        @echo !str! | find "*" > NUL 2>&1 && (
            echo Please remove ^* ^(unsupported charcater^) from !str!
            exit /b 50
        )
        @echo !str! | find "=" > NUL 2>&1 && (
            echo Please remove ^= ^(unsupported charcater^) from !str!
            exit /b 50
        )

        set "%2=!str!"
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------
    
    :cleanHostLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.bfw_tmp""

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL 2>&1
        move /Y !logFileTmp! !logFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :move
        set "ms="!BFW_TOOLS_PATH:"=!\moveMlc01DataForAllGames.bat""
        wscript /nologo !StartWait! !ms! !mlc01!

        @echo ^> Game^'s data from !mlc01! moved
    goto:eof
    REM : ------------------------------------------------------------------

    :copy
        set "cs="!BFW_TOOLS_PATH:"=!\copyMlc01DataForAllGames.bat""
        wscript /nologo !StartWait! !cs! !mlc01!

        @echo ^> Game^'s data from !mlc01! copied
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to search game in folder
    :searchGameIn

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

        for /F "delims=~" %%k in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxk"

        @echo - !GAME_TITLE!

        REM : update existing BatchFw installs (only the first launch of setup.bat)
        if %QUIET_MODE% EQU 1 goto:gameTreated

        set "cemuFolder="!GAME_FOLDER_PATH:"=!\Cemu""
        REM : search for inGameSaves, shaderCache and GAME_TITLE.txt under game folder

        for /F "delims=~" %%k in ('dir /B /A:D !GAME_FOLDER_PATH!') do (
            set "folder="!GAME_FOLDER_PATH:"=!\%%k""

            if ["%%k"] == ["inGameSaves"] (
                if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1

                @echo   An inGameSaves subfolder was found directly under the game^'s path root
                @echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exists^)
                @echo   ^(if you haven't used a BatchFW V10 or later, choose to move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MOVE /IS /IT > NUL 2>&1
                if !cr! EQU 2 rmdir /Q /S !folder! > NUL 2>&1
            )
            if ["%%k"] == ["shaderCache"] (

                if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1

                @echo   A shaderCache subfolder was found directly under the game^'s path root
                @echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exists^)
                @echo   ^(if you haven't used a BatchFW V10 or later, choose to move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MOVE /IS /IT > NUL 2>&1
                if !cr! EQU 2 rmdir /Q /S !folder! > NUL 2>&1
            )
            if ["%%k"] == ["graphicPacks"] (

                if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1

                @echo   A graphicPacks subfolder was found directly under the game^'s path root
                @echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exists^)
                @echo   ^(if you haven't used a BatchFW V10 or later, choose move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MOVE /IS /IT > NUL 2>&1
                if !cr! EQU 2 rmdir /Q /S !folder! > NUL 2>&1
            )

        )
        REM : game info file
        set "gif="!GAME_FOLDER_PATH:"=!\!GAME_TITLE!.txt""

        if exist !gif! (
            if not exist !cemuFolder! mkdir !cemuFolder! > NUL 2>&1
            move /Y !gif! !cemuFolder! > NUL 2>&1
        )

       :gameTreated
        set /A NB_GAMES_VALID+=1

    goto:eof
    REM : ------------------------------------------------------------------

    REM : COMPARE VERSIONS : function to count occurences of a separator
    :countSeparators
        set "string=%~1"
        set /A "count=0"

       :again
        set "oldstring=!string!"
        set "string=!string:*%sep%=!"
        set /A "count+=1"
        if not ["!string!"] == ["!oldstring!"] goto:again
        set /A "count-=1"
        set "%2=!count!"

    goto:eof

    REM : COMPARE VERSIONS :
    REM : if vit < vir return 1
    REM : if vit = vir return 0
    REM : if vit > vir return 2
    :compareVersions
        set "vit=%~1"
        set "vir=%~2"

        REM : format strings
        echo %vir% | findstr /VR [a-zA-Z] > NUL 2>&1 && set "vir=!vir!00"
        echo !vir! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vir! vir
        echo %vit% | findstr /VR [a-zA-Z] > NUL 2>&1 && set "vit=!vit!00"
        echo !vit! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vit! vit

        REM : versioning separator (init to .)
        set "sep=."
        @echo !vit! | find "-" > NUL 2>&1 set "sep=-"
        @echo !vit! | find "_" > NUL 2>&1 set "sep=_"

        call:countSeparators !vit! nbst
        call:countSeparators !vir! nbsr

        REM : get the number minimum of sperators found
        set /A "minNbSep=!nbst!"
        if !nbsr! LSS !nbst! set /A "minNbSep=!nbsr!"

        if !minNbSep! NEQ 0 goto:loopSep

        if !vit! EQU !vir! set "%3=0" && goto:eof
        if !vit! LSS !vir! set "%3=2" && goto:eof
        if !vit! GTR !vir! set "%3=1" && goto:eof

       :loopSep
        set /A "minNbSep+=1"
        REM : Loop on the minNbSep and comparing each number
        REM : note that the shell can compare 1c with 1d for example
        for /L %%l in (1,1,!minNbSep!) do (

            call:compareDigits %%l result

            if not ["!result!"] == [""] if !result! NEQ 0 set "%3=!result!" && goto:eof
        )
        REM : check the length of string
        call:strLength !vit! lt
        call:strLength !vir! lr

        if !lt! EQU !lr! set "%3=0" && goto:eof
        if !lt! LSS !lr! set "%3=2" && goto:eof
        if !lt! GTR !lr! set "%3=1" && goto:eof

        set "%3=50"

    goto:eof

    REM : COMPARE VERSION : function to compare digits of a rank
    :compareDigits
        set /A "num=%~1"

        set "dr=99"
        set "dt=99"
        for /F "tokens=%num% delims=~%sep%" %%r in ("!vir!") do set "dr=%%r"
        for /F "tokens=%num% delims=~%sep%" %%t in ("!vit!") do set "dt=%%t"

        set "%2=50"

        if !dt! LSS !dr! set "%2=2" && goto:eof
        if !dt! GTR !dr! set "%2=1" && goto:eof
        if !dt! EQU !dr! set "%2=0" && goto:eof
    goto:eof

    REM : COMPARE VERSION : function to compute string length
    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof

    REM : COMPARE VERSION : function to format string version without alphabetic charcaters
    :formatStrVersion

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:V=!"
        set "str=!str:v=!"
        set "str=!str:RC=!"
        set "str=!str:rc=!"

        set "str=!str:A=01!"
        set "str=!str:B=02!"
        set "str=!str:C=03!"
        set "str=!str:D=04!"
        set "str=!str:E=05!"
        set "str=!str:F=06!"
        set "str=!str:G=07!"
        set "str=!str:H=08!"
        set "str=!str:I=09!"
        set "str=!str:J=10!"
        set "str=!str:K=11!"
        set "str=!str:L=12!"
        set "str=!str:M=13!"
        set "str=!str:N=14!"
        set "str=!str:O=15!"
        set "str=!str:P=16!"
        set "str=!str:Q=17!"
        set "str=!str:R=18!"
        set "str=!str:S=19!"
        set "str=!str:T=20!"
        set "str=!str:U=21!"

        set "str=!str:W=23!"
        set "str=!str:X=24!"
        set "str=!str:Y=25!"
        set "str=!str:Z=26!"

        set "str=!str:a=01!"
        set "str=!str:b=02!"
        set "str=!str:c=03!"
        set "str=!str:d=04!"
        set "str=!str:e=05!"
        set "str=!str:f=06!"
        set "str=!str:g=07!"
        set "str=!str:h=08!"
        set "str=!str:i=09!"
        set "str=!str:j=10!"
        set "str=!str:k=11!"
        set "str=!str:l=12!"
        set "str=!str:m=13!"
        set "str=!str:n=14!"
        set "str=!str:o=15!"
        set "str=!str:p=16!"
        set "str=!str:q=17!"
        set "str=!str:r=18!"
        set "str=!str:s=19!"
        set "str=!str:t=20!"
        set "str=!str:u=21!"

        set "str=!str:w=23!"
        set "str=!str:x=24!"
        set "str=!str:y=25!"
        set "str=!str:z=26!"

        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion: &, %, !
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
        set question=%1
        REM : arg2 = valuesList
        set valuesList=%~2
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional: if given set 1st value as default value after timeOutValue seconds)
        set timeOutValue=%~4

        REM : init return
        set "%3=?"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if [%timeOutValue%] == [] (
            set choiceCmd=choice /C %choiceValues% /CS /N /M !question!
        ) else (
            set choiceCmd=choice /C %choiceValues% /CS /N /T %timeOutValue% /D %defaultTimeOutValue% /M !question!
        )

        REM : launching and get return code
        !choiceCmd!
        set /A "cr=!ERRORLEVEL!"
        set j=1
        for %%i in ("%valuesList:,=" "%") do (

            if [!cr!] == [!j!] (
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

        REM : build a relative path in case of software is installed also in games folders
        echo msg=!msg! | find %GAMES_FOLDER% > NUL 2>&1 && set "msg=!msg:%GAMES_FOLDER:"=%=%%GAMES_FOLDER:"=%%!"

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

    REM : function to initialize log info for current host
    :initLogForHost

        REM : create install log file for current host (if needed)

        if exist !logFile! goto:eof
        set "logFolder="!BFW_PATH:"=!\logs""
        if not exist !logFolder! mkdir !logFolder! > NUL 2>&1

        REM : get last modified Host log (configuration)
        set "lastHostLog="NONE""
        set "patHostLog="!BFW_PATH:"=!\logs\Host_*.log""

        REM : getting the last modified one including _j.bin (conventionnal shader cache)
        for /F "delims=~" %%i in ('dir /B /S /O:D !patHostLog! 2^>NUL') do set "lastHostLog="%%i""

        call:log2HostFile "================================================="
        call:log2HostFile "CEMU BATCH Framework history and settings for !USERDOMAIN!"
        call:log2HostFile "-------------------------------------------------"

        REM : check if _BatchFw_WiiU\OnlineFiles\usersAccounts exist and contains files
        if not exist !BFW_WIIU_FOLDER! goto:scanOtherHost
        @echo =========================================================
        @echo New installation on host !USERDOMAIN!
        @echo -------------------------------------------------
        @echo Found a _BatchFw_WiiU folder^, trying to get Wii-U user^'s profiles
        @echo to define BatchFw^'s users^.^.^.
        @echo.

        set "pat="!BFW_WIIU_FOLDER:"=!\OnlineFiles\usersAccounts\*.dat""
        for /F "delims=~" %%i in ('dir /B !pat! 2^> NUL') do (
            REM : get user name
            for /F "tokens=1 delims=8" %%j in ("%%i") do (
                @echo ^> Found %%j user with an online account
                @echo USER_REGISTERED=%%j>>!logFile!
            )
        )
        @echo.
        @echo. ^(you can modify users list later in the setup process^)
        pause
        goto:3rdPartySoftware

       :scanOtherHost

        REM : if no file found
        if [!lastHostLog!] == ["NONE"] goto:eof
        
        REM : get registered users list from the last modified Host log
        type !lastHostLog! | find /I "USER_REGISTERED" > NUL && (
            @echo =========================================================
            @echo New installation for host !USERDOMAIN!
            @echo -------------------------------------------------
            @echo Getting users defined for the last previous installation
            @echo using !lastHostLog:"=!
            @echo.
            type !lastHostLog! | find /I "USER_REGISTERED"
            type !lastHostLog! | find /I "USER_REGISTERED">>!logFile!
            @echo.
            @echo ^(you can modify users list later in the setup process^)
            pause
        )

       :3rdPartySoftware

        REM : if no file found
        if [!lastHostLog!] == ["NONE"] goto:eof

        @echo -------------------------------------------------
        @echo Try to keep 3rd party software defined in last installation
        @echo using !lastHostLog:"=!
        @echo.

        for /F "tokens=2 delims=~@" %%j in ('type !lastHostLog! ^| find "TO_BE_LAUNCHED" 2^> NUL') do (

            set "command=%%j"
            call:isSoftwareValid "!command!" program valid

            if !valid! EQU 1 (
                @echo ^> !command:'=!

                type !lastHostLog! | find "TO_BE_LAUNCHED">>!logFile!
            )
        )
        @echo.
        @echo ^(you can modify this list later in the setup process^)
        @echo -------------------------------------------------
        pause
    goto:eof

    REM : function that resolve environnemnt variable (such as %GAMES_FOLDER%)
    REM : and try to repaired paths where only the drive letter has changed
    :resolveVenv
        set "value="%~1""
        set "resolved=%value:"=%"

        REM : check if value is a path
        echo %resolved% | find ":" > NUL 2>&1 && (
            REM : check if it is only a device letter issue (in case of portable library)
            set "tmpStr='!drive!%resolved:~3%"

            set "newLocation=!tmpStr:'="!"
            if exist !newLocation! set "resolved=!tmpStr!"
        )

        set "%2=!resolved!"
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to check if a 3rd party software exist or can be patched (resolveEnv)
    :isSoftwareValid

        set "fc="%~1""

        for /F "delims=~" %%k in (!fc!) do call:resolveVenv "%%k" command

        set "program="NONE""
        set "firstArg="NONE""

        REM : resolve venv for search
        for /F "tokens=1 delims=~'" %%k in ("!command!") do set "program="%%k""
        for /F "tokens=3 delims=~'" %%k in ("!command!") do set "firstArg="%%k""

        set "%2=!program!"

        if exist !program! set /A "%3=1" & goto:eof

        set /A "%3=0"

    goto:eof

