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

    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "xmlS="!BFW_RESOURCES_PATH:"=!\xml.exe""
    
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
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
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
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
    set "currentUser=!user:"=!"

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

        @echo Check if the game is really in 1280x720 ^(else change to 1920x1080^)
        @echo and if 60FPS is the FPS when playing the game
        @echo Edit and fix !wiiTitlesDataBase! if needed
        @echo ---------------------------------------------------------
        pause
    )

    REM : _BatchFW_Missing_Games_Profiles folder to store missing games profiles in CEMU_FOLDER\GamesProfiles
    set "MISSING_PROFILES_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Missing_Games_Profiles""

    REM : create folder !GAMES_FOLDER:"=!\_BatchFw_Missing_Games_Profiles (if need)
    if not exist !MISSING_PROFILES_FOLDER! mkdir !MISSING_PROFILES_FOLDER! > NUL 2>&1

    REM : log CEMU
    set "cemuLog="!CEMU_FOLDER:"=!\log.txt""
    set "versionRead=NOT_FOUND"
    if not exist !cemuLog! goto:checkProfile

    for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu" 2^> NUL') do set "versionRead=%%e"

    if ["!versionRead!"] == ["NOT_FOUND"] goto:checkProfile

    REM : comparing version to V1.15.15
    set "v11515="
    call:compareVersions !versionRead! "1.15.15" v11515
    if ["!v11515!"] == [""] @echo Error when comparing versions
    if !v11515! EQU 50 @echo Error when comparing versions

    set "v1156=1"
    set "v1116=1"
    set "v114=1"

    if !v11515! LEQ 1 goto:checkProfile

    set "v1156="
    call:compareVersions !versionRead! "1.15.6" v1156
    if ["!v1156!"] == [""] echo Error when comparing versions ^, result ^= !v1156!

    set "v1116="
    if !v1156! EQU 2 (
        call:compareVersions !versionRead! "1.11.6" v1116
        if ["!v1116!"] == [""] echo Error when comparing versions ^, result ^= !v1116!
    ) else (
        set /A "v1116=1"
    )

    :checkProfile

    REM : check if PROFILE_FILE exist under MISSING_PROFILES_FOLDER
    set "missingProfile="!MISSING_PROFILES_FOLDER:"=!\%titleId%.ini""
    set "CEMU_PF="%CEMU_FOLDER:"=%\gameProfiles""

    REM : handling user game profiles
    if not ["!versionRead!"] == ["NOT_FOUND"] if !v11515! LEQ 1 (
        set "userGameProfile="%CEMU_FOLDER:"=%\gameProfiles\default\%titleId%.ini""
        if exist !userGameProfile! set "CEMU_PF="%CEMU_FOLDER:"=%\gameProfiles\default""
    )
    
    REM : Creating game profile if needed
    if not [!PROFILE_FILE!] == ["NOT_FOUND"] goto:completeGameProfile

    REM : PROFILE_FILE=NOT_FOUND
    REM : define cemu profile path
    set "PROFILE_FILE="%CEMU_PF:"=%\%titleId%.ini""

    REM : if you already generated a profile under MISSING_PROFILES_FOLDER, use it
    if not exist !PROFILE_FILE! if exist !missingProfile! (
        robocopy !MISSING_PROFILES_FOLDER! !CEMU_PF! "%titleId%.ini" > NUL 2>&1
        goto:completeGameProfile
    )

    REM : else, create profile file in CEMU_FOLDER
    if not exist !PROFILE_FILE! call:createGameProfile

    :completeGameProfile
    REM : settings.xml files (a backup is already done in LaunchGame.bat)
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
    set "csTmp0="!CEMU_FOLDER:"=!\settings.bfww_tmp0""
    set "csTmp1="!CEMU_FOLDER:"=!\settings.bfww_tmp1""
    set "csTmp="!CEMU_FOLDER:"=!\settings.bfww_tmp""

    set "exampleFile="!CEMU_FOLDER:"=!\gameProfiles\example.ini""
    
    REM : GFX type to provide
    set "gfxType=V3"

    if ["!versionRead!"] == ["NOT_FOUND"] goto:backupDefaultSettings

    if !v1116! EQU 1 if !v1156! EQU 2 (
        call:compareVersions !versionRead! "1.14.0" v114
        if ["!v114!"] == [""] echo Error when comparing versions
        if !v114! EQU 50 echo Error when comparing versions
        if !v114! EQU 2 set "gfxType=V2"

    ) else (
        if !v1116! EQU 2 (
            set "gfxType=V2"
        ) else (
            if !v1156! EQU 2 (
                call:compareVersions !versionRead! "1.14.0" v114
                if ["!v114!"] == [""] echo Error when comparing versions
                if !v114! EQU 50 echo Error when comparing versions
                if !v114! EQU 2 set "gfxType=V2"

                REM : if CEMU version < 1.12.0 (add games' list in UI)
                call:compareVersions !versionRead! "1.12.0" v112
                if ["!v112!"] == [""] echo Error when comparing versions

                if !v112! EQU 50 echo Error when comparing versions
                if !v112! EQU 2 goto:displayGameProfile
            )
        )
    )

    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL 2>&1
    
    REM : else using CEMU UI for the game profile

    :backupDefaultSettings
    if not exist !cs! goto:displayGameProfile

    REM : check the file size
    for /F "tokens=*" %%a in (!cs!) do if %%~za EQU 0 goto:diffProfileFile

    REM : create a link to GAME_FOLDER_PATH in log folder
    set "TMP_GAME_FOLDER_PATH="!BFW_LOGS:"=!\!GAME_TITLE!""

    if not exist !TMP_GAME_FOLDER_PATH! mklink /D /J !TMP_GAME_FOLDER_PATH! !GAME_FOLDER_PATH! > NUL 2>&1

    REM : remove the node //GamePaths/Entry
    !xmlS! ed -d "//GamePaths/Entry" !cs! > !csTmp0!

    REM : remove the node //GameCache/Entry to force games'list refresh in UI
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
    set "refUserProfileFile="!REF_CEMU_FOLDER:"=!\gameProfiles\default\%titleId%.ini""
    if exist !refUserProfileFile! set "refProfileFile=!refUserProfileFile!"

    if not exist !refProfileFile! (
        @echo No game^'s profile file found ^!
        goto:askRefCemuFolder
    )
    REM : open winmerge on files
    set "WinMergeU="!BFW_PATH:"=!\resources\winmerge\WinMergeU.exe""
    wscript /nologo !StartMaximizedWait! !WinMergeU! !refProfileFile! !PROFILE_FILE!

    goto:step2

    :openProfileFile

    REM : if version of CEMU >= 1.15.6 (v1156<=1)
    if not ["!versionRead!"] == ["NOT_FOUND"] if !v1156! LEQ 1 goto:step2

    @echo Openning !PROFILE_FILE:"=! ^.^.^.
    @echo Complete it ^(if needed^) then close notepad to continue
    wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !PROFILE_FILE!
    @echo ---------------------------------------------------------

    :step2
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

    REM : if just created, copy it in MISSING_PROFILES_FOLDER
    if not exist !missingProfile! robocopy !CEMU_PF! !MISSING_PROFILES_FOLDER! "%titleId%.ini" > NUL 2>&1

    REM : check CEMU options (and controollers settings)
    set "chs="!CEMU_FOLDER:"=!\cemuhook.ini""

    REM : set online files
    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"

    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if not ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] call:setOnlineFiles

    REM : display main CEMU and CemuHook settings and check conistency
    call:checkCemuSettings

    REM : if version of CEMU >= 1.15.6 (v1156<=1)
    if not ["!versionRead!"] == ["NOT_FOUND"] if !v1156! LEQ 1 goto:wait

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    choice /C yn /CS /N /M "Open !exampleFile:"=! to see all settings you can override in the game's profile? (y, n) : "
    if !ERRORLEVEL! EQU 2 goto:reopen

    wscript /nologo !Start! !exampleFile!
    :reopen
    choice /C yn /CS /N /M "Do you need to re-open profile file to modify overrided settings? (y, n) : "
    if !ERRORLEVEL! EQU 1 goto:openProfileFile

    REM : waiting updateGamesGraphicPacks processes ending
    :wait
    set /A "disp=0"
    set "logFileTmp="!TMP:"=!\BatchFw_process.list""

    :waitingLoop
    timeout /T 1 > NUL 2>&1
    wmic process get Commandline | find ".exe" | find  /I "_BatchFW_Install" | find /I /V "wmic"  > !logFileTmp!

    type !logFileTmp! | find /I "updateGamesGraphicPacks.bat" | find /I /V "find"  > NUL 2>&1 && (
        if !disp! EQU 3 (
            @echo Creating ^/ completing graphic packs if needed^, please wait ^.^.^. >> !batchFwLog!
            cscript /nologo !MessageBox! "Create or complete graphic packs if needed^, please wait ^.^.^." 4160
        ) else (
            set /A "disp=disp+1"
        )
        goto:waitingLoop
    )

    REM : remove trace
    del /F !logFileTmp! > NUL 2>&1

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
    if not ["!versionRead!"] == ["NOT_FOUND"] if !v1156! LEQ 1 @echo    - set game^'s profile ^(right click on the game^)

    REM : if version of CEMU < 1.11.6 (v1116<=1)
    if not ["!versionRead!"] == ["NOT_FOUND"] (
        if !v1116! EQU 2 @echo    - set game^'s profile GPUBufferCacheAccuracy^,cpuMode^,cpuTimer
    ) else (
        @echo    - set game^'s profile GPUBufferCacheAccuracy^,cpuMode^,cpuTimer
    )

    @echo ---------------------------------------------------------
    @echo Then close CEMU to continue

    REM : link to graphic pack folder
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""

    REM : check if it is already a link (case of crash) : delete-it
    set "pat="!CEMU_FOLDER:"=!\*graphicPacks*""
    for /F "delims=~" %%a in ('dir /A:L /B !pat! 2^>NUL') do rmdir /Q !graphicPacks! > NUL 2>&1

    if exist !graphicPacksBackup! (
        if exist !graphicPacks! rmdir /Q !graphicPacks! > NUL 2>&1
        move /Y !graphicPacksBackup! !graphicPacks! > NUL 2>&1
    )

    if exist !graphicPacks! move /Y !graphicPacks! !graphicPacksBackup! > NUL 2>&1

    REM : issue with CEMU 1.15.3 that does not compute cortrectly relative path to GFX folder
    REM : when using a simlink with a the target on another partition
    for %%a in (!GAME_GP_FOLDER!) do set "d1=%%~da"
    for %%a in (!graphicPacks!) do set "d2=%%~da"

    set "v1153b="
    if not ["%d1%"] == ["%d2%"] if not ["!versionRead!"] == ["NOT_FOUND"] (
        if !v114! EQU 1 (
            call:compareVersions !versionRead! "1.15.3b" v1153b
            if ["!v1153b!"] == [""] @echo Error when comparing versions >> !batchFwLog!
            if ["!v1153b!"] == [""] @echo Error when comparing versions
            if !v1153b! EQU 50 @echo Error when comparing versions >> !batchFwLog!
            if !v1153b! EQU 50 @echo Error when comparing versions
            if !v1153b! LEQ 1 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL 2>&1 && goto:launchCemu
        ) else (
            set /A "v1153b=2"
        )
    )
    mklink /D /J !graphicPacks! !GAME_GP_FOLDER! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL 2>&1
    :launchCemu

    REM : launching CEMU
    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
    wscript /nologo !StartWait! !cemu!

    if not exist !cs! goto:saveOptions

    REM : set !GAMES_FOLDER! for //GamePaths
    REM : remove the node //GamePaths/Entry
    !xmlS! ed -d "//GamePaths/Entry" !cs! > !csTmp0!
    REM : patch settings.xml to point to !GAMES_FOLDER! (GamePaths node)
    !xmlS! ed -s "//GamePaths" -t elem -n "Entry" -v !GAMES_FOLDER! !csTmp0! > !cs!
    del /F !csTmp0! > NUL 2>&1

    REM : set !GAMES_FOLDER! for //GamePaths in the backup also
    set "csbu="!CEMU_FOLDER:"=!\settings.xml_bfwl_old""
    if exist !csbu! (
        REM : remove the node //GamePaths/Entry
        !xmlS! ed -d "//GamePaths/Entry" !csbu! > !csTmp0!
        REM : patch settings.xml to point to !GAMES_FOLDER! (GamePaths node)
        !xmlS! ed -s "//GamePaths" -t elem -n "Entry" -v !GAMES_FOLDER! !csTmp0! > !csbu!
        del /F !csTmp0! > NUL 2>&1
    )
    
    :saveOptions
    set "scp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
    if not exist !scp! mkdir !scp! > NUL 2>&1

    REM : saving CEMU an cemuHook settings
    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.bin > NUL 2>&1
    set "src="!SETTINGS_FOLDER:"=!\settings.bin""
    set "target="!SETTINGS_FOLDER:"=!\!currentUser!_settings.bin""
    if exist !src! move /Y !src! !target! > NUL 2>&1

    if exist !cs! (
        robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.xml > NUL 2>&1
        set "src="!SETTINGS_FOLDER:"=!\settings.xml""
        set "target="!SETTINGS_FOLDER:"=!\!currentUser!_settings.xml""
        if exist !src! move /Y !src! !target! > NUL 2>&1
    )

     if exist !chs! (
        robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! cemuhook.ini > NUL 2>&1
        set "src="!SETTINGS_FOLDER:"=!\cemuhook.ini""
        set "target="!SETTINGS_FOLDER:"=!\!currentUser!_cemuhook.ini""
        if exist !src! move /Y !src! !target! > NUL 2>&1
    )
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

        set "currentUser=!currentUser!"
        REM : get the account.dat file for the current user and the accId
        set "accId=NONE"

        set "pat="!BFW_ONLINE_ACC:"=!\!currentUser!*.dat""

        for /F "delims=~" %%i in ('dir /B !pat! 2^>NUL') do (
            set "af="!BFW_ONLINE_ACC:"=!\%%i""

            for /F "delims=~= tokens=2" %%j in ('type !af! ^| find /I "AccountId=" 2^>NUL') do set "accId=%%j"
        )

        if ["!accId!"] == ["NONE"] (
            @echo WARNING^: AccountId not found for !currentUser!^, cancel online files installation ^!
            pause
        )
        @echo ---------------------------------------------------------
        @echo AccountId found for !currentUser!

        REM : check if the Wii-U is not power on
        set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
        if not exist !winScpIni! goto:installAccount

        REM : get the hostname
        for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName=" 2^>NUL') do set "ipRead=%%i"
        REM : check its state

        call:getHostState !ipRead! state
        if !state! EQU 1 (
            cscript /nologo !MessageBox! "A host with your last Wii-U adress was found on the network. Be sure that no one is using your account ^(!accId!^) to play online right now^. Cancel to abort using online feature" 4112
            if !ERRORLEVEL! EQU 2 goto:eof
        )

        :installAccount

        REM : copy !af! to "!MLC01_FOLDER_PATH:"=!\usr\save\system\act\80000001\account.dat"
        set "cemuUserFolder="!MLC01_FOLDER_PATH:"=!\usr\save\system\act\80000001""
        if not exist !cemuUserFolder! mkdir !cemuUserFolder! > NUL 2>&1
        set "target="!cemuUserFolder:"=!\account.dat""
        copy /Y !af! !target! > NUL 2>&1

        REM : patch settings.xml
        REM if not nul
        for /F "tokens=*" %%a in (!cs!) do (
            set /A "css=%%~za"

            if !css! EQU 0 (
                @echo WARNING ^: No Setting^.xml found^, cancelling online files installation ^!
                goto:eof
           )
        )

        set "csTmp="!CEMU_FOLDER:"=!\settings.bfww_tmp""

        !xmlS! ed -u "//AccountId" -v !accId! !cs! > !csTmp!

        if exist !csTmp! (
            del /F !cs! > NUL 2>&1
            move /Y !csTmp! !cs! > NUL 2>&1
        )

        set "mlc01OnlineFiles="!BFW_ONLINE_FOLDER:"=!\mlc01OnlineFiles.rar""
        if exist !mlc01OnlineFiles! wscript /nologo !StartHidden! !rarExe! x -o+ -inul -w"!BFW_PATH:"=!logs" !mlc01OnlineFiles! !GAME_FOLDER_PATH!

        REM : copy otp.bin and seeprom.bin if needed
        set "t1="!CEMU_FOLDER:"=!\otp.bin""
        set "t2="!CEMU_FOLDER:"=!\seeprom.bin""
        set "t1o="!CEMU_FOLDER:"=!\otp.bfww_old""
        set "t2o="!CEMU_FOLDER:"=!\seeprom.bfww_old""

        set "s1="!BFW_ONLINE:"=!\otp.bin""
        set "s2="!BFW_ONLINE:"=!\seeprom.bin""

        if exist !s1! if exist !t1! move !t1! !t1o! > NUL 2>&1
        if exist !s2! if exist !t2! move !t2! !t2o! > NUL 2>&1

        if exist !s1! robocopy !BFW_ONLINE! !CEMU_FOLDER! "otp.bin" > NUL 2>&1
        if exist !s2! robocopy !BFW_ONLINE! !CEMU_FOLDER! "seeprom.bin" > NUL 2>&1

        @echo Online account for !currentUser! enabled ^: !accId!

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
            if ["!value!"] == ["2"] @echo Upscale filter [hermithe]
            if ["!value!"] == ["3"] @echo Upscale filter [nearest neighbor]
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
            @echo Audio TV Volume set to [!value! %]
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
            if !v1156! EQU 2 (
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
            )
            cscript /nologo !MessageBox! "Custom timer declared in CemuHook and CEMU^'s default one ^(RDTSC^) is not disabled in the game^'s profile" 4144
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :createGameProfile
       
        @echo # !GAME_TITLE! > %PROFILE_FILE%
        @echo [Graphics] >> %PROFILE_FILE%

        REM : if version of CEMU < 1.15.6 (v1156<=1)
        if not ["!versionRead!"] == ["NOT_FOUND"] if !v1156! EQU 2 (
            @echo GPUBufferCacheAccuracy = 1 >> %PROFILE_FILE%
        ) else (
            @echo GPUBufferCacheAccuracy = medium >> %PROFILE_FILE%
        )

        REM : if version of CEMU < 1.11.6 (v1116<=1)
        if not ["!versionRead!"] == ["NOT_FOUND"] (
            if !v1116! EQU 2 @echo disableGPUFence = true >> %PROFILE_FILE%
        ) else (
            @echo disableGPUFence = true >> %PROFILE_FILE%
        )

        @echo accurateShaderMul = min >> %PROFILE_FILE%
        @echo [CPU] >> %PROFILE_FILE%
        @echo cpuTimer = hostBased >> %PROFILE_FILE%
        @echo cpuMode = Singlecore-Recompiler >> %PROFILE_FILE%
        @echo threadQuantum = 45000 >> %PROFILE_FILE%

        @echo Creating a Game profile for tilte Id ^: %titleId%

    goto:eof
    REM : ------------------------------------------------------------------

    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles""
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
        @echo Controller profiles folders synchronized ^(!CEMU_FOLDER_NAME!\ControllerProfiles vs _BatchFW_Controller_Profiles^)

        pushd !BFW_TOOLS_PATH!

    goto:eof
    REM : ------------------------------------------------------------------

    :importSaves
        set fileFound=%~1

        choice /C yn /N /M "Do you want to use this one : %fileFound% (y, n)?"
        if [!ERRORLEVEL!] == [1] set SAVE_FILE=%fileFound%

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
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------