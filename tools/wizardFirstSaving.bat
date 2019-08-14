@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"
    title Collecting settings

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^!^)^, cr=!cr!
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

    set "xmlS="!BFW_RESOURCES_PATH:"=!\xml.exe""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

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

    if %nbArgs% GTR 5 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER GAME_TITLE PROFILE_FILE SETTINGS_FOLDER user
        @echo given {%*}
        pause
        exit 99
    )
    if %nbArgs% LEQ 4 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CEMU_FOLDER GAME_TITLE PROFILE_FILE SETTINGS_FOLDER user
        @echo given {%*}
        pause
        exit 99
    )
    REM : get and check CEMU_FOLDER
    set "CEMU_FOLDER=!args[0]!"
    if not exist !CEMU_FOLDER! (
        @echo ERROR ^: CEMU folder !CEMU_FOLDER! does not exist ^!
        pause
        exit 1
    )

    REM : get and check GAME_TITLE
    set "GAME_TITLE=!args[1]!"
    set "GAME_TITLE=!GAME_TITLE:"=!"
    REM : get and check PROFILE_FILE
    set "PROFILE_FILE=!args[2]!"

    REM : get and check SETTINGS_FOLDER
    set "SETTINGS_FOLDER=!args[3]!"

    set "user=!args[4]!"

    @echo =========================================================
    @echo - CEMU_FOLDER     ^: !CEMU_FOLDER!
    @echo - GAME_TITLE      ^: !GAME_TITLE!
    @echo - PROFILE_FILE    ^: !PROFILE_FILE!
    @echo - SETTINGS_FOLDER ^: !SETTINGS_FOLDER!
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME="%%~nxa""
    set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME:"=!"

    set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!GAME_TITLE!""

    REM : check game profile
    :checkGameProfile
    REM : Get Game information using titleId
    set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    if not exist !META_FILE! (
        @echo No meta^/meta^.xml file exist under game^'s folder ^!
        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        if not exist !metaFolder! mkdir !metaFolder! > NUL 2>&1
        @echo Please pick your game titleId ^(copy to clipboard^) in WiiU-Titles-Library^.csv
        @echo ^(if the game is not listed^, search internet to get its title Id and add a row in WiiU-Titles-Library^.csv^)
        @echo Then close notepad to continue

        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !wiiTitlesDataBase!
        @echo ^<^?xml^ version=^"1.0^"^ encoding=^"utf-8^"^?^> > !META_FILE!
        @echo ^<menu^ type=^"complex^"^ access=^"777^"^> >> !META_FILE!
        @echo ^ ^ ^<title_version^ type=^"unsignedInt^"^ length=^"4^"^>0^<^/title_version^> >> !META_FILE!
        @echo ^ ^ ^<title_id^ type=^"hexBinary^"^ length=^"8^"^>################^<^/title_id^> >> !META_FILE!
        @echo ^<^/menu^> >> !META_FILE!
        @echo Paste-it in !META_FILE! file ^(replacing ################ by the title id of the game ^(16 characters^)^)
        @echo Then close notepad to continue and relaunch
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !META_FILE!
        cls
        @echo ---------------------------------------------------------
    )


    REM : get Title Id from meta.xml
    set "titleLine="NONE""
    for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
    if [!titleLine!] == ["NONE"] (
        cscript /nologo !MessageBox! "ERROR ^: unable to find titleId from meta^.xml^, please check ^! exiting^.^.^." 4112
        goto:eof
    )
    for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"
    REM : In case of non saving
    if ["%titleId%"] == ["################"] goto:checkGameProfile

    if ["%titleId:ffffffff=%"] == ["%titleId%"] goto:getTitleFromDataBase
    if ["%titleId:FFFFFFFF=%"] == ["%titleId%"] goto:getTitleFromDataBase

    REM : check if game is recognized
    call:checkValidity %titleId%

    :getTitleFromDataBase

    set "endTitleId=%titleId:~8,8%"

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

    if [!libFileLine!] == ["NONE"] (
        @echo ---------------------------------------------------------
        @echo No informations found on the game with a titleId %titleId%
        @echo Adding this game in the data base !wiiTitlesDataBase! ^(720p^,60FPS^)
        @echo '%titleId%';!GAME_TITLE!;-;-;-;-;-;-;'%titleId%';720;60 >> !wiiTitlesDataBase!

        REM : update Game's Graphic Packs (wasn't launched in LaunchGame.bat in this case)
        set "ugp="!BFW_TOOLS_PATH:"=!\updateGamesGraphicPacks.bat""
        wscript /nologo !StartHidden! !ugp! true !GAME_FOLDER_PATH!

        @echo Check if the game is really in 1280x720 ^(else change to 1920x1080^)
        @echo and if 60FPS is the FPS when playing the game
        @echo Edit and fix !wiiTitlesDataBase! if needed
        @echo ---------------------------------------------------------
        pause
    )

    REM : _BatchFW_Missing_Games_Profiles folder to store missing games profiles in CEMU_FOLDER\GamesProfiles
    set "MISSING_PROFILES_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Missing_Games_Profiles""
    REM : check if PROFILE_FILE exist under MISSING_PROFILES_FOLDER
    set "missingProfile="!MISSING_PROFILES_FOLDER:"=!\%titleId%.ini""
    set "CEMU_PF="!CEMU_FOLDER:"=!\gameProfiles""

    REM : Creating game profile if needed
    if not [!PROFILE_FILE!] == ["NOT_FOUND"] goto:completeGameProfile

    REM : PROFILE_FILE=NOT_FOUND
    REM : define cemu profile path
    set "PROFILE_FILE="!CEMU_PF:"=!\%titleId%.ini""

    REM : if you already generated a profile under MISSING_PROFILES_FOLDER, use it
    if not exist !PROFILE_FILE! if exist !missingProfile! (
        robocopy !MISSING_PROFILES_FOLDER! !CEMU_PF! "%titleId%.ini" > NUL 2>&1
        goto:completeGameProfile
    )

    set /A "v1156=99"
    call:compareVersions %versionRead% "1.15.6" v1156
    if ["!v1156!"] == [""] echo Error when comparing versions ^, result ^= !v1156!

    set /A "v1116=99"
    call:compareVersions %versionRead% "1.11.6" v1116
    if ["!v1116!"] == [""] echo Error when comparing versions ^, result ^= !v1116!

    REM : else, create profile file in CEMU_FOLDER
    if not exist !PROFILE_FILE! call:createGameProfile !PROFILE_FILE!

    :completeGameProfile
    REM : settings.xml files
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
    set "csTmp0="!CEMU_FOLDER:"=!\settings.tmp0""
    set "csTmp1="!CEMU_FOLDER:"=!\settings.tmp1""
    set "csTmp="!CEMU_FOLDER:"=!\settings.tmp""
    set "backup="!CEMU_FOLDER:"=!\settings.old""
    set "exampleFile="!CEMU_FOLDER:"=!\gameProfiles\example.ini""
    
    REM : GFX type to provide
    set "gfxType=V3"

    REM : log CEMU
    set "cemuLog="!CEMU_FOLDER:"=!\log.txt""
    if not exist !cemuLog! goto:backupDefaultSettings

    set "versionRead=NOT_FOUND"
    for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu" 2^> NUL') do set "versionRead=%%e"

    if ["%versionRead%"] == ["NOT_FOUND"] goto:displayGameProfile
    
    call:compareVersions %versionRead% "1.14.0" result
    if ["!result!"] == [""] echo Error when comparing versions
    if !result! EQU 50 echo Error when comparing versions
    if !result! EQU 2 set "gfxType=V2"

    REM : if CEMU version < 1.12.0 (add games' list in UI)
    call:compareVersions %versionRead% "1.12.0" result
    if ["!result!"] == [""] echo Error when comparing versions
    if !result! EQU 50 echo Error when comparing versions
    if !result! EQU 2 goto:displayGameProfile

    REM : else using CEMU UI for the game profile

    :backupDefaultSettings
    REM : clean links in game's graphic pack folder
    for /F "delims=~" %%a in ('dir /A:L /B !BFW_LOGS! 2^>NUL') do (
        set "link="!BFW_LOGS:"=!\%%a""
        rmdir /Q /S !link! > NUL 2>&1
    )

    REM : check the file size
    for /F "tokens=*" %%a in (!cs!) do if %%~za EQU 0 goto:diffProfileFile
    
    REM : backup settings.xml
    copy /Y !cs! !backup! > NUL 2>&1

    REM : create a link to GAME_FOLDER_PATH in log folder
    set "TMP_GAME_FOLDER_PATH="!BFW_LOGS:"=!\!GAME_TITLE!""

    if not exist !TMP_GAME_FOLDER_PATH! mklink /D /J !TMP_GAME_FOLDER_PATH! !GAME_FOLDER_PATH! > NUL 2>&1

    REM : remove the node //GamePaths/Entry
    !xmlS! ed -d "//GamePaths/Entry" !cs! > !csTmp0!

    REM : remove the node //GameCache/Entry
    !xmlS! ed -d "//GameCache/Entry" !csTmp0! > !csTmp1!
    
    REM : patch settings.xml to point to !GAMES_FOLDER! (GamePaths node)
    !xmlS! ed -s "//GamePaths" -t elem -n "Entry" -v !BFW_LOGS! !csTmp1! > !csTmp!

    REM : patch settings.xml to point to local mlc01 folder (GamePaths node)
    set "MLC01_FOLDER_PATH=!GAME_FOLDER_PATH:"=!\mlc01"

    !xmlS! ed -u "//mlc_path" -v "!MLC01_FOLDER_PATH!/" !csTmp! > !cs!
    if exist !cs! del /F !csTmp!* > NUL 2>&1
    goto:diffProfileFile

    :displayGameProfile

    @echo SET THE GAME^'S PROFILE
    @echo ---------------------------------------------------------
    @echo.
    @echo All settings defined in the game^'s profile override CEMU^'s UI ones ^!
    @echo.
    @echo To see which parameters are handled in this version^, you can
    @echo choose to open the example^.ini below^.
    @echo Define at least ^:
    @echo.
    @echo [Graphics]
    @echo GPUBufferCacheAccuracy = 1 ^(2^:low^, 1^:medium^, 0^:high^)
    @echo.
    @echo [CPU]
    @echo cpuMode = Singlecore-Recompiler ^(Singlecore-Interpreter^, Singlecore-Recompiler^, Dualcore-Recompiler^, Triplecore-Recompiler^)
    @echo cpuTimer = hostBased ^(cycleCounter^, hostBased^)
    @echo.
    @echo ---------------------------------------------------------

    REM : ask to open example.ini of this version
    if not exist !exampleFile! goto:openProfileFile

    choice /C yn /CS /N /M "Do you want to open !exampleFile:"=! to see all settings you can set? (y, n) : "
    if !ERRORLEVEL! EQU 2 goto:diffProfileFile

    wscript /nologo !Start! !exampleFile!

    :diffProfileFile
    if [!PROFILE_FILE!] == ["NOT_FOUND"] goto:askRefCemuFolder
    choice /C yn /CS /N /M "Do you want to compare !GAME_TITLE! game profile with an existing profile file? (y, n) : "
    if !ERRORLEVEL! EQU 2 goto:openProfileFile

    :askRefCemuFolder
    REM : get cemu install folder for existing game's profile

    for /F %%b in ('cscript /nologo !browseFolder! "Select a Cemu's install folder as reference"') do set "folder=%%b" && set "REF_CEMU_FOLDER=!folder:?= !"
    if [!REF_CEMU_FOLDER!] == ["NONE"] goto:openProfileFile
    REM : check that profile file exist in
    set "refProfileFile="!REF_CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""
    if /I not exist !refProfileFile! (
        @echo No game^'s profile file found under !REF_CEMU_FOLDER:"=!\gameProfiles ^!
        goto:askRefCemuFolder
    )
    REM : open winmerge on files
    set "WinMergeU="!BFW_PATH:"=!\resources\winmerge\WinMergeU.exe""
    wscript /nologo !StartMaximizedWait! !WinMergeU! !refProfileFile! !PROFILE_FILE!

    goto:updateMissingProfileFolder

    :openProfileFile

    REM : if version of CEMU >= 1.15.6 (v1156<=1)
    if !v1156! LEQ 1 goto:step2

    @echo Openning !PROFILE_FILE:"=! ^.^.^.
    @echo Complete it ^(if needed^) then close notepad to continue
    wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !PROFILE_FILE!
    @echo ---------------------------------------------------------

    :updateMissingProfileFolder

    REM : if just created, copy it in MISSING_PROFILES_FOLDER
    if not exist !missingProfile! robocopy !CEMU_PF! !MISSING_PROFILES_FOLDER! "%titleId%.ini" > NUL 2>&1

    cls
    REM : create a text file in game's folder to save data for current game
    set "gameInfoFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt""

    if not exist !gameInfoFile! (
        set "pf="!GAME_FOLDER_PATH:"=!\Cemu""
        if not exist !pf! mkdir !pf! > NUL 2>&1
        set "gt="!BFW_TOOLS_PATH:"=!\getTitleDataFromLibrary.bat""
        wscript /nologo !StartHiddenWait! !gt! "%titleId%" > !gameInfoFile!
    )

    type !gameInfoFile!

    :step2

    REM : check CEMU options (and controollers settings)
    set "chs="!CEMU_FOLDER:"=!\cemuhook.ini""

    REM : set online files
    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"

    for /F "tokens=1 delims==" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] call:setOnlineFiles

    REM : display main CEMU and CemuHook settings and check conistency
    call:checkCemuSettings

    REM : if version of CEMU >= 1.15.6 (v1156<=1)
    if !v1156! LEQ 1 goto:wait

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    choice /C yn /CS /N /M "Open !exampleFile:"=! to see all settings you can override in the game's profile? (y, n) : "
    if !ERRORLEVEL! EQU 2 goto:reopen

    wscript /nologo !Start! !exampleFile!
    :reopen
    choice /C yn /CS /N /M "Do you need to re-open profile file to modify overrided settings? (y, n) : "
    if !ERRORLEVEL! EQU 1 goto:openProfileFile

    REM : waiting updateGamesGraphicPacks processes ending
    :wait
    set "disp=0"
    :waitingLoop
    for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "updateGamesGraphicPacks.bat" ^| find /I /V "find" 2^>NUL') do (
        if !disp! EQU 0 (
            set "disp=1" && cscript /nologo !MessageBox! "Graphic packs for this game are currently processed^, waiting before open CEMU UI^.^.^." 4160
        )
        timeout /T 1 > NUL 2>&1
        goto:waitingLoop
    )

    REM : create links in game's graphic pack folder
    set "fnrLogWgp="!BFW_PATH:"=!\logs\fnr_wizardGraphicPacks.log""
    if exist !fnrLogWgp! del /F !fnrLogWgp!
    REM : BatchFW graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    REM : Re launching the search (to get the freshly created packs)
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId% --logFile !fnrLogWgp! > NUL

    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL 2>&1

    REM : clean links in game's graphic pack folder
    if exist !GAME_GP_FOLDER! for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        if exist !gpLink! rmdir /Q /S !gpLink! > NUL 2>&1
    )

    REM : always import 16/9 graphic packs
    call:importGraphicPacks > NUL 2>&1

    REM : get user defined ratios list
    set "ARLIST="
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do set "ARLIST=%%i !ARLIST!"
    if ["!ARLIST!"] == [""] goto:checkHeightFix

    REM : import user defined ratios graphic packs
    for %%a in (!ARLIST!) do (
        if ["%%a"] == ["1610"] call:importOtherGraphicPacks 1610 > NUL 2>&1
        if ["%%a"] == ["219"]  call:importOtherGraphicPacks 219 > NUL 2>&1
        if ["%%a"] == ["43"]   call:importOtherGraphicPacks 43 > NUL 2>&1
        if ["%%a"] == ["489"]  call:importOtherGraphicPacks 489 > NUL 2>&1
    )

    :checkHeightFix
    if not ["!tName!"] == ["NOT_FOUND"] (

        set "gpV3="!BFW_GP_FOLDER:"=!\!tName:"=!_Resolution"
        set "rulesFile="!gpV3:"=!\rules.txt""
        if exist !rulesFile! type !rulesFile! | find /I "heightfix" > NUL 2>&1 && (
            @echo Graphic pack for this game use a height fix to avoid black borders
            @echo By default^, BatchFw complete presets with ^$heightfix=0
            @echo Switch this value to 1 if you encounter black border for the preset choosen
        )
    )
    REM : synchronized controller profiles (import)
    call:syncControllerProfiles

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo LAUNCHING CEMU^, set your parameters for this game
    @echo ^(no need to set those defined in the game^s profile^)
    @echo ---------------------------------------------------------
    timeout /t 1 > NUL 2>&1

    REM : create a function check cemuHook consistency
    if exist !chs! (
        @echo    CemuHook settings ^: Custom Timer^,timer value
    )

    @echo    CEMU settings ^:
    @echo    - all controller profiles for all players
    @echo    - select graphic pack^(s^)
    @echo    - select amiibo paths^(NFC Tags^)

    REM : if version of CEMU >= 1.15.6 (v1156<=1)
    if !v1156! LEQ 1 @echo    - set game^'s profile ^(right click on the game^)

    REM : if version of CEMU < 1.11.6 (v1116<=1)
    if !v1116! EQU 2 @echo    - set game^'s profile GPUBufferCacheAccuracy^,cpuMode^,cpuTimer

    @echo ---------------------------------------------------------
    @echo Then close CEMU to continue

    REM : link to graphic pack folder
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""

    REM : check if it is already a link (case of crash) : delete-it
    set "pat="!CEMU_FOLDER:"=!\*graphicPacks*""
    for /F %%a in ('dir /A:L /B !pat! 2^>NUL') do rmdir /Q !graphicPacks! > NUL 2>&1

    if exist !graphicPacksBackup! (
        if exist !graphicPacks! rmdir /Q !graphicPacks! > NUL 2>&1
        move /Y !graphicPacksBackup! !graphicPacks! > NUL 2>&1
    )

    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if exist !graphicPacks! move /Y !graphicPacks! !graphicPacksBackup! > NUL 2>&1

    REM : issue with CEMU 1.15.3 that does not compute cortrectly relative path to GFX folder
    REM : when using a simlink with a the target on another partition
    for %%a in (!GAME_GP_FOLDER!) do set "d1=%%~da"
    for %%a in (!graphicPacks!) do set "d2=%%~da"

    if not ["%d1%"] == ["%d2%"] if not ["%versionRead%"] == ["NOT_FOUND"] (
        call:compareVersions %versionRead% "1.15.3" result
        if ["!result!"] == [""] echo Error when comparing versions
        if !result! EQU 50 echo Error when comparing versions
        if !result! LEQ 1 (
            robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL 2>&1
            goto:launchCemu
        )
    )
    if not exist !graphicPacks! mklink /D /J !graphicPacks! !GAME_GP_FOLDER! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL 2>&1

    :launchCemu

    REM : launching CEMU
    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
    wscript /nologo !StartWait! !cemu!

    set "scp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
    if not exist !scp! mkdir !scp! > NUL 2>&1

    REM : saving CEMU an cemuHook settings
    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.bin > NUL 2>&1
    set "src="!SETTINGS_FOLDER:"=!\settings.bin""
    set "target="!SETTINGS_FOLDER:"=!\!user:"=!_settings.bin""
    if exist !src! move /Y !src! !target! > NUL 2>&1

    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.xml > NUL 2>&1
    set "src="!SETTINGS_FOLDER:"=!\settings.xml""
    set "target="!SETTINGS_FOLDER:"=!\!user:"=!_settings.xml""
    if exist !src! move /Y !src! !target! > NUL 2>&1

    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! cemuhook.ini > NUL 2>&1
    set "src="!SETTINGS_FOLDER:"=!\cemuhook.ini""
    set "target="!SETTINGS_FOLDER:"=!\!user:"=!_cemuhook.ini""
    if exist !src! move /Y !src! !target! > NUL 2>&1

    REM : controller profiles
    set "pat="!CEMU_FOLDER:"=!\controllerProfiles\controller*.*""
    copy /A /Y !pat! !scp! > NUL 2>&1
    cls

    REM : create transferable schader cache folder
    set "tsc="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
    if not exist !tsc! mkdir !tsc! > NUL 2>&1

    :done
    REM : if a TMP_GAME_FOLDER_PATH was used, delete it
    if exist !TMP_GAME_FOLDER_PATH! rmdir /Q !TMP_GAME_FOLDER_PATH! > NUL 2>&1

    cls
    @echo DONE^, CEMU setting are saved under !SETTINGS_FOLDER:"=! ^!
    @echo ---------------------------------------------------------
    @echo - From now^, if you modify your settings during the game they will be saved when closing CEMU^.
    @echo ---------------------------------------------------------
    @echo If you encounter any issues or have made a mistake when
    @echo collecting settings for a game^:
    @echo ^> delete the settings saved for !CEMU_FOLDER_NAME! using
    @echo the shortcut in Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!
    @echo Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    @echo ^> or delete !SETTINGS_FOLDER:"=! manually
    @echo ---------------------------------------------------------
    pause
    @echo =========================================================
    @echo - Continue with launching the game in a 2s seconds
    timeout /T 2 > NUL 2>&1
    @echo ---------------------------------------------------------

    exit 0

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :setOnlineFiles

        set "BFW_ONLINE="!GAMES_FOLDER:"=!\_BatchFw_WiiU\onlineFiles""
        set "BFW_ONLINE_ACC="!BFW_ONLINE:"=!\usersAccounts""

        If not exist !BFW_ONLINE! goto:eof

        REM : get the account.dat file for the current user and the accId
        set "accId=NONE"

        set "pat="!BFW_ONLINE_ACC:"=!\!user:"=!*.dat""

        for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL') do (
            set "af="!BFW_ONLINE_ACC:"=!\%%i""

            for /F "delims=~= tokens=2" %%j in ('type !af! ^| find /I "AccountId=" 2^>NUL') do set "accId=%%j"
        )

        if ["!accId!"] == ["NONE"] (
            @echo WARNING^: AccountId not found for !user:"=!^, cancel online files installation ^!
            pause
        )

        REM : install other files needed for online play
        set "onLineMlc01Files="!BFW_ONLINE:"=!\mlc01""
        if exist !onLineMlc01Files! (
            set "ccerts="!MLC01_FOLDER_PATH!\sys\title\0005001b\10054000\content\ccerts""
            if not exist !ccerts! xcopy !onLineMlc01Files! "!MLC01_FOLDER_PATH!" /R /S /Y > NUL 2>&1
        )
      
        REM : copy otp.bin and seeprom.bin if needed
        set "t1="!CEMU_FOLDER:"=!\otp.bin""
        set "t2="!CEMU_FOLDER:"=!\seeprom.bin""

        set "s1="!BFW_ONLINE_FOLDER:"=!\otp.bin""
        set "S2="!BFW_ONLINE_FOLDER:"=!\seeprom.bin""

        if exist !s1! if not exist !t1! robocopy !BFW_ONLINE_FOLDER! !CEMU_FOLDER! otp.bin > NUL 2>&1
        if exist !s2! if not exist !t2! robocopy !BFW_ONLINE_FOLDER! !CEMU_FOLDER! seeprom.bin > NUL 2>&1

        if not ["!accId!"] == ["NONE"] (
            REM : patch settings.xml
            !xmlS! ed -u "//AccountId" -v !accId! !cs! > !csTmp!

            if exist !csTmp! (
                del /F !cs! > NUL 2>&1
                move /Y !csTmp! !cs! > NUL 2>&1
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------




    REM : function to check unrecognized game
    :checkValidity
        set "id=%~1"

        REM : check if titleId correspond to a game wihtout meta\meta.xml file
        set "begin=%id:~0,8%"
        call:check8hexValue %begin%
        set "end=%id:~8,8%"
        call:check8hexValue %end%

    goto:eof

    :check8hexValue
        set "halfId=%~1"

        if ["%halfId:ffffffff=%"] == ["%halfId%"] goto:eof
        if ["%halfId:FFFFFFFF=%"] == ["%halfId%"] goto:eof

        @echo Ooops it look like your game have a problem ^:
        @echo - if no meta^\meta^.xml file exist^, CEMU give an id BEGINNING with ffffffff
        @echo   using the BATCH framework ^(wizardFirstSaving.bat^) on the game
        @echo   will help you to create one^.
        @echo - if CEMU not recognized the game^, it give an id ENDING with ffffffff
        @echo   you might have made a mistake when applying a DLC over game^'s files
        @echo   to fix^, overwrite game^'s file with its last update or if no update
        @echo   are available^, re-dump the game ^!
        pause
        exit /b 2
    goto:eof
    REM : ------------------------------------------------------------------

    REM : get a node value in a xml file
    REM : !WARNING! current directory must be !BFW_RESOURCES_PATH!
    :getValueInXml

        set "xPath="%~1""
        set "xmlFile="%~2""

        for /F "delims=~" %%x in ('xml.exe sel -t -c !xPath! !xmlFile!') do (
            set "%3=%%x"

            goto:eof
        )

        set "%3=NOT_FOUND"

    goto:eof
    REM : ------------------------------------------------------------------


    
    :checkCemuSettings

        REM : check CEMU options (and controollers settings)
        if not exist !cs! goto:checkCemuHook
        for /F "tokens=*" %%a in (!cs!) do if %%~za EQU 0 goto:checkCemuHook
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        @echo Main current CEMU^'s settings ^:
        @echo ---------------------------------------------------------

        pushd !BFW_RESOURCES_PATH!

        REM : get graphic settings
        call:getValueInXml "//Graphic/api/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["0"] @echo Graphics API [OpenGL]
            if ["!value!"] == ["1"] @echo Graphics API [Vulkan]
        )

        call:getValueInXml "//Graphic/fullscreen_menubar/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["true"] @echo Fullscreen Menubar [ON]
            if ["!value!"] == ["false"] @echo Fullscreen Menubar [OFF]
        )

        call:getValueInXml "//Graphic/VSync/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["true"] @echo VSync [ON]
            if ["!value!"] == ["false"] @echo VSync [OFF]
        )

        call:getValueInXml "//Graphic/GX2DrawdoneSync/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["true"] @echo Full sync @GX2DrawDone [ON]
            if ["!value!"] == ["false"] @echo Full sync @GX2DrawDone [OFF]
        )

        call:getValueInXml "//Graphic/SeparableShaders/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["true"] @echo Using separable shaders
            if ["!value!"] == ["false"] @echo Using conventional shaders
        )

        call:getValueInXml "//Graphic/UpscaleFilter/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["0"] @echo Upscale filter [bilinear]
            if ["!value!"] == ["1"] @echo Upscale filter [bicubic]
            if ["!value!"] == ["1"] @echo Upscale filter [hermithe]
            if ["!value!"] == ["1"] @echo Upscale filter [nearest neighbor]
        )

        call:getValueInXml "//Graphic/DownscaleFilter/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["0"] @echo Downscale filter [bilinear]
            if ["!value!"] == ["1"] @echo Downscale filter [bicubic]
            if ["!value!"] == ["2"] @echo Downscale filter [hermithe]
            if ["!value!"] == ["3"] @echo Downscale filter [nearest neighbor]
        )

        call:getValueInXml "//Graphic/FullscreenScaling/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["true"] @echo Fullscreen Scaling [keep aspect ratio]
            if ["!value!"] == ["false"] @echo Fullscreen Scaling [stretch]
        )

        REM : get audio settings
        @echo ---------------------------------------------------------
        call:getValueInXml "//Audio/api/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == ["0"] @echo Audio API [Direct sound]
            if ["!value!"] == ["1"] @echo Audio API [XAudio2]
            if ["!value!"] == ["2"] @echo Audio API [XAudio2]
        )

        call:getValueInXml "//Audio/delay/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            @echo Latency set to [!value! ms]
        )

        call:getValueInXml "//Audio/TVDevice/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == [""] @echo Audio TV device [OFF]
            if ["!value!"] == ["default"] @echo Audio TV device [primary sound driver]
            if not ["!value!"] == [""] if not ["!value!"] == ["default"] @echo Audio TV device [use specific user device]
        )

        call:getValueInXml "//Audio/TVVolume/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            @echo Audio TV Volume set to [!value! ms]
        )

        REM : online mode
        @echo ---------------------------------------------------------
        call:getValueInXml "//AccountId/text()" !cs! value
        if not ["!value!"] == ["NOT_FOUND"] (
            if ["!value!"] == [""] (@echo Online mode [OFF]) else (@echo Online mode [ON using !value! account])
        )

        pushd !BFW_TOOLS_PATH!
        
        :checkCemuHook
        if not exist !chs! goto:eof
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        @echo Current CemuHook^'s settings ^:
        @echo ---------------------------------------------------------
        type !chs! | find /I /V "#" | find /I /V "["
        type !chs! | find /I /V "#" | find /I /V "[" | find /I "customTimerMode" | find /I /V "default" | find /I /V "none" > NUL 2>&1 && (
            type !PROFILE_FILE! | find /I /V "#" | find /I "useRDTSC" | find /I "false" > NUL 2>&1 && goto:eof
            @echo ---------------------------------------------------------
            @echo WARNING ^: custom timer declared in CemuHook and CEMU^'s default
            @echo one ^(RDTSC^) is not disabled in the game^'s profile
            @echo Be aware that might cause crash for some games since 1^.14
            @echo.
            @echo If you really want to use a custom timer^, You^'d better
            @echo had the following lines in the game^'s profile
            @echo.
            @echo [General]
            @echo useRDTSC = false
            @echo.
            cscript /nologo !MessageBox! "Custom timer declared in CemuHook and CEMU^'s default one ^(RDTSC^) is not disabled in the game^'s profile" 4144
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :importOtherGraphicPacks

        set "filter=%~1"
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogWgp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:" 2^>NUL') do (

            set "str=%%i"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" | find /V "_graphicPacksV2" > NUL 2>&1 && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_FOLDER:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )

            set "tName=!gp:_graphicPacksV2=!"
            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! > NUL 2>&1
            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            if not ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V2"] mklink /J /D !linkPath! !targetPath! > NUL 2>&1
            if ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V3"] mklink /J /D !linkPath! !targetPath! > NUL 2>&1
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :importGraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogWgp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:" 2^>NUL') do (

            set "str=%%i"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" | find /V "_graphicPacksV2" > NUL 2>&1 && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_FOLDER:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )

            set "tName=!gp:_graphicPacksV2=!"
            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! > NUL 2>&1
            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            if not ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V2"] mklink /J /D !linkPath! !targetPath! > NUL 2>&1
            if ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V3"] mklink /J /D !linkPath! !targetPath! > NUL 2>&1

        )
    goto:eof
    REM : ------------------------------------------------------------------

    :createGameProfile

        set "profile="%~1""

        @echo # !GAME_TITLE! > !profile!
        @echo [Graphics] >> !profile!

        REM : if version of CEMU < 1.15.6 (v1156<=1)
        if !v1156! EQU 2 (
            @echo GPUBufferCacheAccuracy = 1 >> !profile!
        ) else (
            @echo GPUBufferCacheAccuracy = medium >> !profile!
        )

        REM : if version of CEMU < 1.11.6 (v1116<=1)
        if !v1116! EQU 2 @echo disableGPUFence = true >> !profile!

        @echo accurateShaderMul = min >> !profile!
        @echo [CPU] >> !profile!
        @echo cpuTimer = hostBased >> !profile!
        @echo cpuMode = Singlecore-Recompiler >> !profile!
        @echo threadQuantum = 45000 >> !profile!

        @echo Creating a Game profile for tilte Id ^: %titleId%

    goto:eof
    REM : ------------------------------------------------------------------

    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles\!USERDOMAIN!""
        if not exist !CONTROLLER_PROFILE_FOLDER! mkdir !CONTROLLER_PROFILE_FOLDER! > NUL 2>&1

        set "ccp="!CEMU_FOLDER:"=!\ControllerProfiles""
        if not exist !ccp! goto:eof

        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            if not exist !ccpf! robocopy  !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" > NUL 2>&1
        )
        @echo ---------------------------------------------------------
        @echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!\ControllerProfiles vs _BatchFW_Controller_Profiles\!USERDOMAIN!^)

        pushd !BFW_TOOLS_PATH!

    goto:eof
    REM : ------------------------------------------------------------------

    :importSaves
        set fileFound=%~1

        choice /C yn /N /M "Do you want to use this one : %fileFound% (y, n)?"
        if [!ERRORLEVEL!] == [1] set SAVE_FILE=%fileFound%

    goto:eof
    REM : ------------------------------------------------------------------

    REM : functions to compare Cemu Versions
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

    :compareDigits

            set /A "num=%~1"

            set "dr=99"
            set "dt=99"
            for /F "tokens=%num% delims=~%sep%" %%r in ("!vir!") do set "dr=%%r"
            for /F "tokens=%num% delims=~%sep%" %%t in ("!vit!") do set "dt=%%t"

            if !dt! LSS !dr! set "%2=2" && goto:eof
            if !dt! GTR !dr! set "%2=1" && goto:eof

    goto:eof

    REM : if vit < vir return 1
    REM : if vit = vir return 0
    REM : if vit > vir return 2
    :compareVersions
        set "vit=%~1"
        set "vir=%~2"

        REM : versioning separator
        set "sep=."

        call:countSeparators !vit! nbst
        call:countSeparators !vir! nbsr

        REM : get the number minimum of sperators found
        set /A "minNbSep=!nbst!"
        if !nbsr! LSS !nbst! set /A "minNbSep=!nbsr!"
        set /A "minNbSep+=1"

        REM : Loop on the minNbSep and comparing each number
        REM : note that the shell can compare 1c with 1d for example
        for /L %%l in (1,1,!minNbSep!) do (
            call:compareDigits %%l result
            if !result! NEQ 0 set "%2=!result!" && goto:eof
        )

    goto:eof

    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
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