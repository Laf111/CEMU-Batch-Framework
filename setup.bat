@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    REM : CEMU's Batch FrameWork Version
    set BFW_VERSION=V13RC1

    set "THIS_SCRIPT=%~0"
    title !THIS_SCRIPT!

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR Remove DOS reserved characters from the path "!THIS_SCRIPT!"^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit 1
    )

    REM : directory of this script
    pushd "%~dp0" >NUL && set "BFW_PATH="!CD!"" && popd >NUL

    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"

    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    REM : check if
    for %%i in (!BFW_PATH!) do for /F "tokens=2 delims==" %%j in ('wmic path win32_volume where "Caption='%%~di\\'" get FileSystem /value  2^>NUL ^| find /V "NTFS"') do (

        echo This volume is not an NTFS one^^!
        echo BatchFw use Symlinks and need to be installed on a NTFS volume
        pause
        exit 2
    )

    REM : log file for current host
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""
    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "rarExe="!BFW_PATH:"=!\resources\rar.exe""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

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
    set OUTPUT_FOLDER=!args[0]!

   :beginSetup
    REM : initialize log file for current host (if needed)
    call:initLogForHost

    REM : update graphic packs
    set "ubw="!BFW_TOOLS_PATH:"=!\updateBatchFw.bat""
    call !ubw! !BFW_VERSION!
    set /A "cr=!ERRORLEVEL!"
    if !cr! EQU 0 (
        @echo BatchFw updated^, please relaunch
        timeout /t 4 > NUL
        exit 50
    )

    set "msg="BFW_VERSION=%BFW_VERSION%""
    call:log2HostFile !msg!

    REM : set current char codeset
    call:setCharSet
    REM set Shell.BrowseForFolder arg vRootFolder
    REM : 0  = ShellSpecialFolderConstants.ssfDESKTOP
    set "DIALOG_ROOT_FOLDER="0""

    set "readme="!BFW_PATH:"=!\BatchFW_readme.txt""
    set /A "QUIET_MODE=0"
    if exist !readme! set /A "QUIET_MODE=1"
   :scanGamesFolder

    cls
    if %nbArgs% EQU 0 (
        @echo =========================================================
        @echo            CEMU^'s Batch FrameWork !BFW_VERSION! installer
        @echo =========================================================
        @echo ^(in case of false input close this main window to cancel^)
        if %QUIET_MODE% EQU 0 (
            @echo ---------------------------------------------------------
            @echo BatchFw is a batch framework created to launch easily all
            @echo your RPX games ^(loadiines format^) using many versions of CEMU^.
            @echo.
            @echo It is now limited only to CEMU's versions ^>=1^.11 that^:
            @echo -support the -mlc argument
            @echo -use the last saves format
            @echo.
            @echo It gathers all game^'s data in each game^'s folder and so
            @echo also ease the CEMU^'s update process
        )
    ) else (
        @echo =========================================================
        @echo Register more than one CEMU's version
        @echo and optionally Edit your BatchFW^'s settings
        @echo =========================================================
        @echo ^(in case of false input close this main window to cancel^)
    )

   :validateGamesLibrary

    if %nbArgs% EQU 1 goto:externalGP

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
    for /F "delims=" %%i in ('dir /B /S /A:D code ^| find /V "\mlc01" 2^> NUL') do (

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
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    if !NB_GAMES_VALID! EQU 0 (
        @echo No loadiines games^(^*^.rpx^) founds under !GAMES_FOLDER!^^!
        @echo Please extract BatchFw in your loadiines games^' folder
        REM : show doc
        set "tmpFile="!BFW_PATH:"=!\doc\updateInstallUse.txt""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!

        @echo Exiting 10
        pause
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
        if [!ANSWER!] == ["n"] goto:externalGP

        set "tmpFile="!BFW_PATH:"=!\doc\graphicPacksHandling.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
    )
   :externalGP
    REM : check if GAMES_FOLDER\_BatchFW_Graphic_Packs exist
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""

    if not exist !BFW_GP_FOLDER!  mkdir !BFW_GP_FOLDER! > NUL

    REM : check if an internet connection is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims==" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] goto:extractV3pack

    @echo ---------------------------------------------------------
    @echo Downloading latest graphics packs

    REM : update graphic packs
    set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
    call !ugp! -forced
    set /A "cr=!ERRORLEVEL!"

    if !cr! EQU 0 goto:importModForGames

   :extractV3pack
    if %QUIET_MODE% EQU 1 goto:importModForGames

    REM : first launch of setup.bat
    if exist !BFW_GP_FOLDER! rmdir /Q /S !BFW_GP_FOLDER! 2> NUL
    mkdir !BFW_GP_FOLDER!

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Extracting graphics packs^.^.^.
    @echo ---------------------------------------------------------
    REM : extract embeded V3 packs
    set "rarFile="!BFW_RESOURCES_PATH:"=!\V3_GFX_Packs.rar""

    set "BFW_GP_TMP="!BFW_PATH:"=!\logs\gpUpdateTmpDir""
    if not exist !BFW_GP_TMP! mkdir !BFW_GP_TMP! > NUL

    wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul !rarFile! !BFW_GP_TMP! > NUL
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo ERROR while extracting V3_GFX_Packs^.rar, exiting 1
        pause
        exit /b 1
    )

    @echo ^> Graphic packs installed from archive
    set "pat="!BFW_GP_TMP:"=!\graphicPacks*.doNotDelete!""
    move !pat! !BFW_GP_FOLDER! > NUL

    REM : filter graphic pack folder
    set "script="!BFW_TOOLS_PATH:"=!\filterGraphicPackFolder.bat""
    wscript /nologo !StartHidden! !script!

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
    @echo Wii-U Games^\BatchFW^\Tools^\Graphic packs^\Import Mods for my games^.lnk

    @echo ^> Mods were imported in each game^'s folder

   :askGpCompletion
    @echo ---------------------------------------------------------
    REM : flush logFile of COMPLETE_GP
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "COMPLETE_GP" 2^>NUL') do call:cleanHostLogFile COMPLETE_GP

    choice /C yn /N /M "Do you want BatchFW to complete/create graphic packs? (y,n)  "
    if !ERRORLEVEL! EQU 1 (
        set "msg="COMPLETE_GP=YES""
        call:log2HostFile !msg!
        goto:askRatios
    )
    REM : else
    goto:askScreenMode

   :askRatios
    REM : flush logFile of DESIRED_ASPECT_RATIO
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "DESIRED_ASPECT_RATIO" 2^>NUL') do call:cleanHostLogFile DESIRED_ASPECT_RATIO
    REM :? 1366*768
    @echo ---------------------------------------------------------
    @echo Choose your display ratio ^(for extra graphic packs^)
    @echo Ratios availables:
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

    choice /C yn /N /M "Do you want to launch CEMU in fullscreen? (y,n)  "
    if !ERRORLEVEL! EQU 1 goto:getUserMode

    set "msg="SCREEN_MODE=windowed""
    call:log2HostFile !msg!

    REM : browse for OUTPUT_FOLDER
   :getUserMode

    REM : by default: create shortcuts
    set "outputType=LNK"
    @echo ---------------------------------------------------------

    REM : get the users list
    set "usersList=EMPTY"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "USER_REGISTERED" 2^>NUL') do set "usersList=!usersList! %%i"

    if not ["%usersList%"] == ["EMPTY"] goto:handleUsers
    choice /C ny /N /M "Do you want to add more than one user? (y,n)  "
    if !ERRORLEVEL! EQU 1 (
        set "msg="USER_REGISTERED=%USERNAME%""
        call:log2HostFile !msg!
        goto:getSoftware
    )
   :handleUsers
    if ["%usersList%"] == ["EMPTY"] goto:getUsers

    set "usersList=!usersList:EMPTY=!"
    @echo Users already registered in BatchFW: !usersList!
    choice /C ny /N /M "Edit this list? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:getSoftware

    REM : flush logFile of USER_REGISTERED
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "USER_REGISTERED" 2^>NUL') do call:cleanHostLogFile USER_REGISTERED

    REM : Get BatchFw's users registered with the current windows profile

   :getUsers
    set /P "input=Please enter user's name: "
    set "userName=%input: =%"

    set "msg="USER_REGISTERED=%userName%""
    call:log2HostFile !msg!

    choice /C yn /N /M "Add another user? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:getUsers

   :getSoftware
    cls
    @echo ---------------------------------------------------------

    REM : get the software list
    set "softwareList=EMPTY"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "TO_BE_LAUNCHED" 2^>NUL') do set "softwareList=!softwareList! %%i"

    if not ["%softwareList%"] == ["EMPTY"] goto:handleSoftware
    @echo Do you want BatchFw to launch a third party software
    @echo before launching CEMU^?
    @echo ^(E^.G^. DS4Windows^, cemuGyro^, a speed hack^.^.^.^)
    @echo.
    @echo They will be launched in the order you will enter here^.
    @echo.
    choice /C ny /N /M "Register a third party software? (y,n) "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    @echo.
    @echo You^ll be asked to enter the full command line to
    @echo the software and its arguments^.
    @echo Use the file^'s absolute path and be sure that the
    @echo command works by checking it in a cmd prompt before^!
    @echo.
   :handleSoftware
    if ["%softwareList%"] == ["EMPTY"] goto:getSpath

    set "softwareList=!softwareList:EMPTY=!"
    @echo Software already registered in BatchFW: !softwareList!
    choice /C ny /N /M "Edit this list? (y,n) "
    if !ERRORLEVEL! EQU 1 goto:askExtMlC01Folders

    REM : flush logFile of TO_BE_LAUNCHED
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "TO_BE_LAUNCHED" 2^>NUL') do call:cleanHostLogFile TO_BE_LAUNCHED

    REM : Get BatchFw's users registered with the current windows profile

   :getSpath
    @echo ---------------------------------------------------------
    set /P "spath=Enter the full command line: "

    REM : build a relative path in case of software is installed also in games folders
    echo spath=!spath! | find !BFW_PATH! > NUL && set "spath=!spath:%BFW_PATH:"=%=%%BFW_PATH%%!"

    set "msg="TO_BE_LAUNCHED=!spath!""
    call:log2HostFile !msg! 2>NUL

    choice /C yn /N /M "Add another third party software? (y,n): "
    if !ERRORLEVEL! EQU 1 goto:getSpath

   :askExtMlC01Folders
    if %nbArgs% EQU 0 if !QUIET_MODE! EQU 0 (
        @echo ---------------------------------------------------------
        choice /C ny /N /M "Do you use an external mlc01 folder you wish to import? (y,n): "
        if !ERRORLEVEL! EQU 1 goto:getOuptutsType

        set "script="!BFW_TOOLS_PATH:"=!\moveMlc01DataForAllGames.bat""
        choice /C mc /CS /N /M "Move (m) or copy (c)?"
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 2 set "script="!BFW_TOOLS_PATH:"=!\copyMlc01DataForAllGames.bat""
       :getExtMlc01
        wscript /nologo !StartWait! !script!
        set /A "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            @echo ERROR in !script!^, cr=!cr!
            pause
        )
        choice /C yn /N /M "Add another external mlc01 folder? (y,n): "
        if !ERRORLEVEL! EQU 1 goto:getExtMlc01

        @echo ^> External mlc01 data was imported^!
        @echo.
        @echo Next time use the shortcuts in
        @echo Wii-U Games^\BatchFW^\Tools^\Mlc01 folder handling
        @echo.
        pause

    )

   :getOuptutsType
    cls
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo What kind of outputs do you want to launch your games^?
    @echo -
    @echo - 1: Windows shortcuts
    @echo - 2: Executables files
    @echo -
    call:getUserInput "Enter your choice?: " "1,2" ANSWER
    if [!ANSWER!] == ["1"] goto:getOuptutsFolder

    set "outputType=EXE"
    set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
    if %QUIET_MODE% EQU 0 (
        set "tmpFile="!BFW_PATH:"=!\doc\executables.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
    )

   :getOuptutsFolder
    REM : skip if one arg is given
    if %nbArgs% EQU 1 (
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        @echo ^> Ouptuts will be created in !OUTPUT_FOLDER:"=!\Wii-U Games
        goto:registerCemuInstalls
    )
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Define target folder for shortcuts ^(a Wii-U Games subfolder will be created^)
    @echo ---------------------------------------------------------
    call:getFolderPath "Where to create shortcuts? (a Wii-U Games subfolder will be created)" !DIALOG_ROOT_FOLDER! OUTPUT_FOLDER

    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !OUTPUT_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo Please rename !OUTPUT_FOLDER! to be DOS compatible^!^, exiting
        pause
        exit /b 1
    )
    if !cr! EQU 1 goto:getOuptutsFolder
    set "cemuFolderCheck=!OUTPUT_FOLDER:"=!\Cemu.exe""

    if exist !cemuFolderCheck! (
        @echo Not a Cemu install folder^, please enter the output folder
        @echo ^(where shortcuts or exe will be created^)
        goto:getOuptutsFolder
    )

    @echo ^> Ouptuts will be created in !OUTPUT_FOLDER:"=!\Wii-U Games


   :registerCemuInstalls

    REM : get GPU_VENDOR to set default choice on ignoring precompiled shader cache
    for /F "tokens=2 delims==" %%i in ('wmic path Win32_VideoController get Name /value ^| find "="') do (
        set "string=%%i"
        goto:firstOccur
    )
   :firstOccur
    set "GPU_VENDOR=!string: =!"
    call:secureStringPathForDos !GPU_VENDOR! GPU_VENDOR

    set "gpuType=AMD"
    set "noAMD=!GPU_VENDOR:AMD=!"
    if ["!noAMD!"] == ["!GPU_VENDOR!"] set "gpuType=OTHER"
        cls
        @echo ---------------------------------------------------------
        @echo BatchFw needS you to register and import mlc01 data of
        @echo the last^(s^) version^(s^) of CEMU you used to play your games^.
        @echo.

        @echo If you^'re using more than one CEMU version ^(per game
        @echo for example^) register all installations and select the
        @echo games concerned^.
        @echo.

        @echo Once your shortcuts are created^, launch all your games one time to
        @echo let BatchFw copy the transferable cache into the game^'s folder^.
        @echo.

        @echo If you^'re duplicating the same CEMU^'s version for many players^:
        @echo register this version with one user^, and use the shortcut
        @echo Wii-U Games^\BatchFW^\Tools^\Games^'s saves^\Import Saves
        @echo to import saves of other users afterwards^.
        @cls
    )
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo Please^, define your CEMU^'s installations paths
    @echo ---------------------------------------------------------
    @echo ^(note that if you install CEMU^>=1^.15^.1^, you^'d better have it
    @echo installed on C^: to avoid a long copy of your GLCache into
    @echo CEMU^'s install folder^)
    @echo ---------------------------------------------------------

    REM : intialize Number of Cemu Version beginning from 0
    set /A "NBCV=0"

   :getCemuFolder
    set /A "NBCV+=1"

    call:getFolderPath "Browse to your CEMU install folder number %NBCV%" !DIALOG_ROOT_FOLDER! CEMU_FOLDER

    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !CEMU_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        @echo Please rename !GAMES_FOLDER! to be DOS compatible^!^, exiting
        pause
        exit /b 1
    )

    if !cr! EQU 1 (
        set /A "NBCV-=1"
        goto:getCemuFolder
    )

    REM : check that cemu.exe exist in
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe""
    if /I not exist !cemuExe! (
        @echo ERROR No Cemu.exe file found under !CEMU_FOLDER! ^^!
        set /A "NBCV-=1"
        goto:getCemuFolder
    )
    REM : basename of CEMU_FOLDER to get CEMU version
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME=%%~nxa"
    @echo CEMU install %NBCV%^: !CEMU_FOLDER!
    call:regCemuInstall %NBCV% !CEMU_FOLDER!

    @echo ---------------------------------------------------------
    call:getUserInput "Do you want to add another version? (y,n)" "y,n" ANSWER
    if [!ANSWER!] == ["y"] goto:getCemuFolder

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo ^> Done

    if %QUIET_MODE% EQU 0 (
        call:getUserInput "Would you like to see how BatchFW works? (y,n)" "y,n" ANSWER
        if [!ANSWER!] == ["n"] goto:done

        set "tmpFile="!BFW_PATH:"=!\doc\howItWorks.txt""
         wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !tmpFile!
    )
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
    @echo If you want to change global CEMU^'s settings you^'ve just entered here^:
    @echo ---------------------------------------------------------
    @echo ^> simply delete the shortcuts and recreate them using
    @echo Wii-U Games^\Create CEMU^'s shortcuts for selected games^.lnk to
    @echo register a SINGLE version of CEMU
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo If you encounter any issues or have made a mistake when collecting
    @echo settings for a game^:
    @echo ---------------------------------------------------------
    @echo ^> delete the settings saved for !CEMU_FOLDER_NAME! using the shortcut
    @echo Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!^\Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo If you want to change Batch^'s settings ^(such as graphic pack completion^,
    @echo aspects ratios^) and^/or^register more than one version of CEMU^:
    @echo ---------------------------------------------------------
    @echo ^> relaunch this script from its shortcut
    @echo Wii-U Games^\Register CEMU installs^.lnk
    @echo ---------------------------------------------------------
    pause
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if %nbArgs% EQU 1 exit 0
    @echo Openning !OUTPUT_FOLDER:"=!\Wii-U Games^.^.^.
    timeout /T 4 > NUL

    set "folder="!OUTPUT_FOLDER:"=!\Wii-U Games""
    wscript /nologo !Start! "%windir%\explorer.exe" !folder!
    @echo =========================================================
    @echo This windows will close automatically in 15s
    @echo     ^(n^)^: don^'t close^, i want to read history log first
    @echo     ^(q^)^: close it now and quit
    @echo ---------------------------------------------------------
    call:getUserInput "- Enter your choice?: " "q, n" ANSWER 15
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

        REM : first Cemu install
        if %cemuNumber% EQU 1 (

            set "tmpFile="!BFW_PATH:"=!\doc\mlc01data.txt""
            if %QUIET_MODE% EQU 0  wscript /nologo !Start! "%windir%\System32\notepad.exe" !tmpFile!
        )

        choice /C yn /CS /N /M "Use !CEMU_FOLDER_NAME! to copy/move mlc01 (updates, dlc, game saves) your game's folder? (y,n)  "
        if !ERRORLEVEL! EQU 2 goto:createShortcuts

        choice /C mc /CS /N /M "Move (m) or copy (c)?"
        set /A "cr=!ERRORLEVEL!"

        set "mlc01="!CEMU_FOLDER:"=!\mlc01""

        if !cr! EQU 1 call:move
        if !cr! EQU 2 call:copy

       :createShortcuts

        REM : check if CemuHook is installed
        set "dllFile="!CEMU_FOLDER:"=!\keystone.dll""
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

        wscript /nologo !StartWait! !defaultBrowser! "https://cemuhook.sshnuke.net/#Downloads"
        @echo Download and extract CemuHook in !CEMU_FOLDER!

        timeout /T 2 > NUL
        wscript /nologo !Start! "%windir%\explorer.exe" !CEMU_FOLDER!

        choice /C y /N /M "If CemuHook is installed, continue? (y): "

       :checkSharedFonts

        REM : check if sharedFonts were downloaded
        set "sharedFonts="!CEMU_FOLDER:"=!\sharedFonts""
        if exist !sharedFonts! goto:getCemuVersion

       :openCemuAFirstTime

        @echo ---------------------------------------------------------
        @echo Openning CEMU^.^.^.
        @echo Set your REGION^, language
        @echo And finally download sharedFonts using Cemuhook button
        @echo Then close CEMU to continue

        set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
        wscript /nologo !StartWait! !cemu!

       :getCemuVersion
        if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] if not exist !sharedFonts! @echo Download sharedFonts using Cemuhook button && goto:openCemuAFirstTime

        set "clog="!CEMU_FOLDER:"=!\log.txt""
        set /A "post1151=1"
        if not exist !clog! goto:openCemuAFirstTime

         set "version=NOT_FOUND"

        for /f "tokens=1-6" %%a in ('type !clog! ^| find "Init Cemu"') do set "version=%%e"

        if ["%version%"] == ["NOT_FOUND"] goto:extractV2Packs

        set "str=%version:.=%"
        set "n=%str:~0,4%"
        if %n% LSS 1151 set /A "post1151=0"
        if %n% GEQ 1140 goto:autoImportMode

       :extractV2Packs
        set "gfxv2="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs\_graphicPacksV2""
        if exist !gfxv2! goto:autoImportMode

        mkdir !gfxv2! > NUL
        set "rarFile="!BFW_RESOURCES_PATH:"=!\V2_GFX_Packs.rar""

        @echo ---------------------------------------------------------
        @echo graphic pack V2 are needed for this version^, extracting^.^.^.

        wscript /nologo !StartHidden! !rarExe! x -o+ -inul !rarFile! !gfxv2! > NUL
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 1 (
            @echo ERROR while extracting V2_GFX_Packs, exiting 1
            pause
            exit /b 21
        )

       :autoImportMode
        @echo ---------------------------------------------------------
        if %cemuNumber% EQU 1  (

            @echo Do you want to enable automatic settings import between versions of CEMU^?
            @echo.
            @echo y^: Using settings of the last version of CEMU used to play this game
            @echo n^: Will launch the wizard script to collect settings for each game
            @echo.
            @echo If a game shortcut already exists^: skip this game
            @echo.
        )

        REM : importMode
        set "argOpt=-noImport"
        set "IMPORT_MODE=DISABLED"
        call:getUserInput "Enable automatic settings import? (y,n): " "n,y" ANSWER

        if [!ANSWER!] == ["y"] (
            set "argOpt="
            set "IMPORT_MODE=ENABLED"
        )

        set "msg="!CEMU_FOLDER_NAME! installed with automatic import =!IMPORT_MODE:"=!""
        call:log2HostFile !msg!

        REM : GPU is not AMD => ignoring precompiled shaders cache?
        if ["!gpuType!"] == ["OTHER"] (
            set "IGNORE_PRECOMP=DISABLED"
            @echo ---------------------------------------------------------
            if %cemuNumber% EQU 1 (

                @echo Ignore the precompiled shader cache for all games^?
                @echo.
                @echo y^: Use only GPU GLCache backuped per game
                @echo n^: Use in addition precompiled shaders
                @echo.
                @echo if you select y
                @echo   and encounter slow shaders compilation time after the first time^,
                @echo   your display drivers are corrupt^!
                @echo   perform a clean uninstall using DDU and re-install it
                @echo   no need to fully compile shaders for each version of CEMU^,
                @echo   GLCache is shared by all installs
                @echo.
            )
            call:getUserInput "Ignore precompiled shader cache for all games? (y,n): " "n,y" ANSWER

            if [!ANSWER!] == ["y"] (
                set "IGNORE_PRECOMP=ENABLED"
                set "argOpt=%argOpt% -ignorePrecomp"
            )
            set "msg="!CEMU_FOLDER_NAME! installed with ignoring precompiled shader cache=!IGNORE_PRECOMP:"=!""
            call:log2HostFile !msg!
        )

        REM : check if main GPU is iGPU. Ask for -nolegacy if it is the case
        set "noIntel=!GPU_VENDOR:Intel=!"
        if not ["!noIntel!"] == ["!GPU_VENDOR!"] (

            @echo ---------------------------------------------------------
            REM : CEMU < 1.15.1
            if %post1151% EQU 0 (
                call:getUserInput "Disable all Intel GPU workarounds (add -NoLegacy)? (y,n): " "n,y" ANSWER
                if [!ANSWER!] == ["n"] goto:launchCreate
                set "argOpt=%argOpt% -noLegacy"
                goto:launchCreate
            )
            REM : CEMU >= 1.15.1
            if %post1151% EQU 1 (
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
        set "str=!str:£=!"
        set "str=!str:(=!"
        set "str=!str:)=!"
        set "str=!str:%%=!"
        set "str=!str:^=!"
        set "str=!str:"=!"
        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------

   :cleanHostLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.tmp""

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL
        move /Y !logFileTmp! !logFile! > NUL

    goto:eof
    REM : ------------------------------------------------------------------

   :move
        set "ms="!BFW_TOOLS_PATH:"=!\moveMlc01DataForAllGames.bat""
        wscript /nologo !StartWait! !ms! !mlc01!
        set /A "cr=!ERRORLEVEL!"

        if !cr! NEQ 0 (
            @echo ERROR in moveMlc01DataForAllGames^, cr=!cr!
            pause
            exit /b 6
        )
        @echo ^> Game^'s data from !mlc01! moved
    goto:eof
    REM : ------------------------------------------------------------------

   :copy
        set "cs="!BFW_TOOLS_PATH:"=!\copyMlc01DataForAllGames.bat""
        wscript /nologo !StartWait! !cs! !mlc01!
        set /A "cr=!ERRORLEVEL!"

        if !cr! NEQ 0 (
            @echo ERROR in moveMlc01DataForAllGames^, cr=!cr!
            pause
            exit /b 6
        )
        @echo ^> Game^'s data from !mlc01! copied
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to search game in folder
   :searchGameIn

        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\code\*.rpx""

        for /F "delims=" %%j in ('dir /B /O:S !pat! 2^> NUL') do (
            set "RPX_FILE="%%j""
        )
        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        for /F "delims=" %%k in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxk"

        @echo - !GAME_TITLE!

        REM : update existing BatchFw installs (only the first launch of setup.bat)
        if %QUIET_MODE% EQU 1 goto:gameTreated

        set "cemuFolder="!GAME_FOLDER_PATH:"=!\Cemu""
        REM : search for inGameSaves, shaderCache and GAME_TITLE.txt under game folder

        for /F "delims=" %%k in ('dir /B /A:D !GAME_FOLDER_PATH!') do (
            set "folder="!GAME_FOLDER_PATH:"=!\%%k""

            if ["%%k"] == ["inGameSaves"] (
                if not exist !cemuFolder! mkdir !cemuFolder! > NUL

                @echo   An inGameSaves subfolder was found directly under the game^'s path root
                @echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exist^)
                @echo   ^(if you haven't used a BatchFW V10 or later, choose to move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MOVE /IS /IT > NUL
                if !cr! EQU 2 rmdir /Q /S !folder! 2>NUL
            )
            if ["%%k"] == ["shaderCache"] (

                if not exist !cemuFolder! mkdir !cemuFolder! > NUL

                @echo   A shaderCache subfolder was found directly under the game^'s path root
                @echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exist^)
                @echo   ^(if you haven't used a BatchFW V10 or later, choose to move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MOVE /IS /IT > NUL
                if !cr! EQU 2 rmdir /Q /S !folder! 2>NUL
            )
            if ["%%k"] == ["graphicPacks"] (

                if not exist !cemuFolder! mkdir !cemuFolder! > NUL

                @echo   A graphicPacks subfolder was found directly under the game^'s path root
                @echo   Do you want to move it to !cemuFolder!^? ^(you might overwrite existing files if the folder already exist^)
                @echo   ^(if you haven't used a BatchFW V10 or later, choose move without a second thought^)
                choice /C md /CS /N /M " > Move (m) or delete (d)?"
                set /A "cr=!ERRORLEVEL!"
                if !cr! EQU 1 robocopy !folder! !cemuFolder! /S /MOVE /IS /IT > NUL
                if !cr! EQU 2 rmdir /Q /S !folder! 2>NUL
            )

        )
        REM : game info file
        set "gif="!GAME_FOLDER_PATH:"=!\!GAME_TITLE!.txt""

        if exist !gif! (
            if not exist !cemuFolder! mkdir !cemuFolder! > NUL
            move /Y !gif! !cemuFolder! > NUL
        )

       :gameTreated
        set /A NB_GAMES_VALID+=1

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
        set "str=!str:^=!"
        set "newPath="!str:"=!""

        if not [!FOLDER_PATH!] == [!newPath!] (
            @echo This folder is not compatible with DOS^. Remove special character from !FOLDER_PATH! newPath = !newPath!
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

    REM : function to initialize log info for current host
   :initLogForHost

        REM : create install log file for current host (if needed)

        if exist !logFile! goto:eof
        set "logFolder="!BFW_PATH:"=!\logs""
        if not exist !logFolder! mkdir !logFolder! > NUL

        call:log2HostFile "================================================="
        call:log2HostFile "CEMU BATCH Framework history for !USERDOMAIN!"
        call:log2HostFile "-------------------------------------------------"

    goto:eof