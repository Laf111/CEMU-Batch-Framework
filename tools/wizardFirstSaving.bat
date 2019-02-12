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
    set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSetAndLocale

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
    set "user=!user:"=!"


    @echo =========================================================
    @echo - CEMU_FOLDER     ^: !CEMU_FOLDER!
    @echo - GAME_TITLE      ^: !GAME_TITLE!
    @echo - PROFILE_FILE    ^: !PROFILE_FILE!
    @echo - SETTINGS_FOLDER ^: !SETTINGS_FOLDER!

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME="%%~nxa""
    set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME:"=!"

    set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!GAME_TITLE!""

    REM : check game profile
    :checkGameProfile
    REM : Get Game information using titleId
    set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""

    if not exist !META_FILE! (
        @echo No meta^/meta^.xml file exist under game^'s folder ^!
        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        if not exist !metaFolder! mkdir !metaFolder! > NUL
        @echo Please pick your game titleId ^(copy to clipboard^) in WiiU-Titles-Library^.csv
        @echo ^(if the game is not listed^, search internet to get its title Id and add a row in WiiU-Titles-Library^.csv^)
        @echo Then close notepad to continue
        set "df="!BFW_PATH:"=!\resources\WiiU-Titles-Library.csv""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !df!
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

    set "endTitleId=%titleId:~8,8%"
    REM : In case of non saving
    if ["%titleId%"] == ["################"] goto:checkGameProfile

    REM : _BatchFW_Missing_Games_Profiles folder to store missing games profiles in CEMU_FOLDER\GamesProfiles
    set "MISSING_PROFILES_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Missing_Games_Profiles""
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
        robocopy !MISSING_PROFILES_FOLDER! !CEMU_PF! "%titleId%.ini" > NUL
        goto:completeGameProfile
    )

    REM : else, create profile file in CEMU_FOLDER
    call:createGameProfile !PROFILE_FILE!

    :completeGameProfile
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
    set "exampleFile="!CEMU_FOLDER:"=!\gameProfiles\example.ini""
    if not exist !exampleFile! goto:openProfileFile

    choice /C yn /CS /N /M "Do you want to open !exampleFile:"=! to see all settings you can set? (y, n) : "
    if !ERRORLEVEL! EQU 2  goto:diffProfileFile

    wscript /nologo !Start! !exampleFile!

    :diffProfileFile
    choice /C yn /CS /N /M "Do you want to compare !GAME_TITLE! game profile with an existing profile file? (y, n) : "
    if !ERRORLEVEL! EQU 2  goto:openProfileFile

    :askRefCemuFolder
    REM : get cemu install folder for existing game's profile
    set "REF_CEMU_FOLDER=NONE"
    call:getFolderPath "Please select the CEMU install folder that contain the reference profile file" 0 REF_CEMU_FOLDER > NUL
    if ["!REF_CEMU_FOLDER!"] == ["NONE"] goto:diffProfileFile
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
    @echo Openning !PROFILE_FILE:"=! ^.^.^.
    @echo Complete it ^(if needed^) then close notepad to continue
    wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !PROFILE_FILE!
    @echo ---------------------------------------------------------

    :updateMissingProfileFolder

    REM : if just created, copy it in MISSING_PROFILES_FOLDER
    if not exist !missingProfile! robocopy !CEMU_PF! !MISSING_PROFILES_FOLDER! "%titleId%.ini" > NUL

    cls
    REM : create a text file in game's folder to save data for current game
    set "gameInfoFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt""

    if not exist !gameInfoFile! (
        set "pf="!GAME_FOLDER_PATH:"=!\Cemu""
        if not exist !pf! mkdir !pf! > NUL
        set "gt="!BFW_TOOLS_PATH:"=!\getTitleDataFromLibrary.bat""
        wscript /nologo !StartHiddenWait! !gt! "%titleId%" > !gameInfoFile!
    )
    type !gameInfoFile!

    :step2

    REM : check CEMU options (and controollers settings)
    set "chs="!CEMU_FOLDER:"=!\cemuhook.ini""

    REM : display main CEMU and CemuHook settings and check conistency
    call:checkCemuSettings
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    choice /C yn /CS /N /M "Open !exampleFile:"=! to see all settings you can override in the game^'s profile? (y, n) : "
    if !ERRORLEVEL! EQU 2  goto:reopen

    wscript /nologo !Start! !exampleFile!
    :reopen
    choice /C yn /CS /N /M "Do you need to reopen profile file to modify overrided settings? (y, n) : "
    if !ERRORLEVEL! EQU 1  goto:openProfileFile

    REM : waiting updateGamesGraphicPacks processes ending
    set "disp=0"
    :waitingLoop
    for /F "delims=" %%j in ('wmic process get Commandline ^| find /V "wmic" ^| find /I "updateGamesGraphicPacks.bat" ^| find /V "find"') do (
        if !disp! EQU 0 (
            @echo ---------------------------------------------------------
            set "disp=1" && cscript /nologo !MessageBox! "Graphic packs for this game are currently processed^, waiting before open CEMU UI^.^.^." 4160
            
        )
        timeout /T 1 > NUL
        goto:waitingLoop
    )

    REM : create links in game's graphic pack folder
    set "fnrLogWgp="!BFW_PATH:"=!\logs\fnr_wizardGraphicPacks.log""
    if exist !fnrLogWgp! del /F !fnrLogWgp!
    REM : BatchFW graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""

    REM : Re launching the search (to get the freshly created packs)
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask rules.txt --includeSubDirectories --find %titleId% --logFile !fnrLogWgp!

    REM : link all missing graphic packs
    REM : always import 16/9 graphic packs
    call:importGraphicPacks > NUL

    REM : get user defined ratios list
    set "ARLIST="
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do set "ARLIST=%%i !ARLIST!"
    if ["!ARLIST!"] == [""] goto:checkHeightFix

    REM : import user defined ratios graphic packs
    for %%a in (!ARLIST!) do (
        if ["%%a"] == ["1610"] call:importOtherGraphicPacks 1610 > NUL
        if ["%%a"] == ["219"]  call:importOtherGraphicPacks 219 > NUL
        if ["%%a"] == ["43"]   call:importOtherGraphicPacks 43 > NUL
        if ["%%a"] == ["489"]  call:importOtherGraphicPacks 489 > NUL
    )

    :checkHeightFix
    if not ["!tName!"] == ["NOT_FOUND"] (

        set "gpV3="!BFW_GP_FOLDER:"=!\!tName:"=!_Resolution"
        set "rulesFile="!gpV3:"=!\rules.txt""
        if exist !rulesFile! type !rulesFile! | find /I "heightfix" > NUL && (
            @echo Graphic pack for this game use a height fix to avoid black borders
            @echo By default^, BatchFw complete presets with $heightfix=0
            @echo Switch this value to 1 if you encounter black border for the preset choosen
        )
    )

    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    @echo LAUNCHING CEMU^, set your parameters for this game
    @echo ^(no need to set those defined in the game^s profile)
    @echo ---------------------------------------------------------
    timeout /t 1 > NUL

    REM : create a function check cemuHook consistency
    if exist !chs! (
        @echo    CemuHook settings ^: Custom Timer^,timer value
    )

    @echo    CEMU settings ^:
    @echo    - all controller profiles for all players
    @echo    - select graphic pack^(s^)
    @echo    - select amiibo paths^(NFC Tags^)
    @echo.
    @echo And for CEMU versions earlier than 1^.11^.6 ^:
    @echo also GPUBufferCacheAccuracy^,cpuMode^,cpuTimer

    @echo ---------------------------------------------------------
    @echo Then close CEMU to continue

    REM : link to graphic pack folder
    set "graphicPacks="!CEMU_FOLDER:"=!\graphicPacks""
    set "graphicPacksBackup="!CEMU_FOLDER:"=!\graphicPacks_backup""

    REM : check if it is already a link (case of crash) : delete-it
    set "pat="!CEMU_FOLDER:"=!\*graphicPacks*""
    for /F %%a in ('dir /A:L /B !pat! 2^>NUL') do rmdir /Q !graphicPacks! 2>NUL

    if exist !graphicPacksBackup! move /Y !graphicPacksBackup! !graphicPacks! > NUL

    set "graphicPacksSaved="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if exist !graphicPacks! move /Y !graphicPacks! !graphicPacksBackup!    > NUL

    mklink /D /J !graphicPacks! !graphicPacksSaved! > NUL

    REM : synchronized controller profiles (import)
    call:syncControllerProfiles
 
    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
    wscript /nologo !StartWait! !cemu!


    REM : restore CEMU's graphicPacks subfolder
    rmdir /Q /S !graphicPacks! 2>NUL
    if exist !graphicPacksBackup! move /Y !graphicPacksBackup! !graphicPacks! > NUL

    set "scp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
    if not exist !scp! mkdir !scp! > NUL

    REM : saving CEMU an cemuHook settings
    set "filePath="!CEMU_FOLDER:"=!\settings.bin""
    if exist !filePath! robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.bin > NUL

    if exist !cs! robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.xml > NUL

    if exist !chs! robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! cemuhook.ini > NUL

    REM : controller profiles
    set "pat="!CEMU_FOLDER:"=!\controllerProfiles\controller*.*""
    copy /A /Y !pat! !scp! > NUL
    cls

    REM : create transferable schader cache folder
    set "tsc="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
    if not exist !tsc! mkdir !tsc! > NUL

    set "SAVE_FILE="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_%user%.rar""
    if exist !SAVE_FILE! goto:done

    @echo No game^'s save was found for %user% ^^!
    REM : else, search a last modified save file for other user
    set "igsvf="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
    if not exist !igsvf! mkdir !igsvf! > NUL

    set "OTHER_SAVE="NONE""
    set "pat="!igsvf:"=!\!GAME_TITLE!_*.rar""
    for /F "delims=" %%i in ('dir /B /O:D !pat!  2^>NUL') do (
        set "OTHER_SAVE="%%i""
    )
    if [!OTHER_SAVE!] == ["NONE"] goto:done

    choice /C yn /N /M "Do you want to use this one : !OTHER_SAVE:"=! (y, n)?"
    if !ERRORLEVEL! EQU 2 goto:done

    @echo Import save from !OTHER_SAVE:"=!
    set "isv="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!OTHER_SAVE:"=!""
    copy /Y !isv! !SAVE_FILE! > NUL

    timeout /T 3 > NUL

    :done
    cls
    @echo DONE^, CEMU setting are saved under !SETTINGS_FOLDER:"=! ^!
    @echo ---------------------------------------------------------
    @echo - From now^, if you modify your settings during the game they will be saved when closing CEMU^.
    @echo ---------------------------------------------------------
    @echo If you encounter any issues or have made a mistake when collecting settings
    @echo for this game ^:
    @echo ^> delete its settings saved for !CEMU_FOLDER_NAME! using the shortcut
    @echo Wii-U Games^\CEMU^\!CEMU_FOLDER_NAME!^\Delete all my !CEMU_FOLDER_NAME!^'s settings^.lnk
    @echo ^> or delete !SETTINGS_FOLDER:"=! manually
    @echo ---------------------------------------------------------
    pause
    @echo =========================================================
    @echo - Continue with launching the game in a 2s seconds
    timeout /T 2 > NUL
    @echo ---------------------------------------------------------

    exit 0

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :checkCemuSettings

        REM : check CEMU options (and controollers settings)
        set "cs="!CEMU_FOLDER:"=!\settings.xml""
        if exist !cs! (
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            @echo Main current CEMU^'s settings ^:
            @echo ---------------------------------------------------------

            type !cs! | find /I "<fullscreen_menubar>" | find /I "true" > NUL && echo Fullscreen Menubar [ON]
            type !cs! | find /I "<fullscreen_menubar>" | find /I "false" > NUL && echo Fullscreen Menubar [OFF]
            type !cs! | find /I "<VSync>" | find /I "true" > NUL && echo VSync [ON]
            type !cs! | find /I "<VSync>" | find /I "false" > NUL && echo VSync [OFF]
            type !cs! | find /I "<GX2DrawdoneSync>" | find /I "true" > NUL && echo Full sync @GX2DrawDone [ON]
            type !cs! | find /I "<GX2DrawdoneSync>" | find /I "false" > NUL && echo Full sync @GX2DrawDone [OFF]
            type !cs! | find /I "<SeparableShaders>" | find /I "true" > NUL && echo Separable shaders [ON]
            type !cs! | find /I "<SeparableShaders>" | find /I "false" > NUL && echo Conventional shaders [ON]
            type !cs! | find /I "<UpscaleFilter>" | find /I "0" > NUL && echo Upscale filter [bilinear]
            type !cs! | find /I "<UpscaleFilter>" | find /I "1" > NUL && echo Upscale filter [bicubic]
            type !cs! | find /I "<UpscaleFilter>" | find /I "2" > NUL && echo Upscale filter [hermithe]
            type !cs! | find /I "<UpscaleFilter>" | find /I "3" > NUL && echo Upscale filter [nearest neighbor]
            type !cs! | find /I "<DownscaleFilter>" | find /I "0" > NUL && echo DownscaleFilter filter [bilinear]
            type !cs! | find /I "<DownscaleFilter>" | find /I "1" > NUL && echo DownscaleFilter filter [bicubic]
            type !cs! | find /I "<DownscaleFilter>" | find /I "2" > NUL && echo DownscaleFilter filter [hermithe]
            type !cs! | find /I "<DownscaleFilter>" | find /I "3" > NUL && echo DownscaleFilter filter [nearest neighbor]
            type !cs! | find /I "<FullscreenScaling>" | find /I "0" > NUL && echo Fullscreen Scaling [keep aspect ratio]
            type !cs! | find /I "<FullscreenScaling>" | find /I "1" > NUL && echo Fullscreen Scaling [stretch]
            type !cs! | find /I "<api>" | find /I "0" > NUL && echo Audio API used [DirectSound]
            type !cs! | find /I "<api>" | find /I "1" > NUL && echo Audio API used [XAudio]
            for /F "tokens=1-6 delims=~<>^" %%i in ('type !cs! ^| find /I "^<delay^>" 2^>NUL') do echo Latency set [%%k ms]
            type !cs! | find /I "<TVDevice><" > NUL && echo Audio TV device [OFF] && goto:getVolume
            type !cs! | find /V "<TVDevice>" | find /I "default" > NUL && echo Audio TV device [main audio device] && goto:getVolume
            type !cs! | find /V "<TVDevice>" > NUL && echo Audio TV device [use specific user device]

            :getVolume
            for /F "tokens=1-6 delims=~<>^" %%i in ('type !cs! ^| find /I "<TVVolume>" 2^>NUL') do echo Audio TV Volume set [%%k]
            )

        if exist !chs! (
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            @echo Current CemuHook^'s settings ^:
            @echo ---------------------------------------------------------
            type !chs! | find /V "#" | find /V "["
            type !chs! | find /V "#" | find /V "[" | find /I "customTimerMode" | find /V "default" | find /V "none" > NUL && (
                type !PROFILE_FILE! | find /V "#" | find /I "useRDTSC" | find /I "false" 2> NUL && goto:eof
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
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :importOtherGraphicPacks

        set "filter=%~1"
        set "tName=NOT_FOUND"
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogWgp! ^| find /V "^!" ^| find "p%filter%" ^| find "File:"') do (

            set "str=%%i"
            set "gp=!str:rules=!"
            set "gp=!gp:\=!"

            set "tName=!gp:_graphicPacksV2=V2_!"
            set "tName=!tName:V2__=V2_!"

            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL

            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            mklink /J /D !linkPath! !targetPath!

        )
    goto:eof
    REM : ------------------------------------------------------------------

    :importGraphicPacks

        set "tName=NOT_FOUND"
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogWgp! ^| find /V "^!" ^| find /V "p1610" ^| find /V "p219" ^| find /V "p489" ^| find /V "p43" ^| find "File:"') do (

            set "str=%%i"
            set "gp=!str:rules=!"
            set "gp=!gp:\=!"

            set "tName=!gp:_graphicPacksV2=V2_!"
            set "tName=!tName:V2__=V2_!"

            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL

            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            mklink /J /D !linkPath! !targetPath! > NUL
        )
    goto:eof
    REM : ------------------------------------------------------------------


    :createGameProfile

        set "profile="%~1""
        @echo # !GAME_TITLE! > !profile!
        @echo [Graphics] >> !profile!
        @echo GPUBufferCacheAccuracy = 1 >> !profile!
        @echo disableGPUFence = true >> !profile!
        @echo accurateShaderMul = min >> !profile!
        @echo [CPU] >> !profile!
        @echo cpuTimer = hostBased >> !profile!
        @echo cpuMode = Singlecore-Recompiler >> !profile!
        @echo Creating a Game profile using tilte Id ^: %titleId%

    goto:eof
    REM : ------------------------------------------------------------------

    :syncControllerProfiles

        set "CONTROLLER_PROFILE_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Controller_Profiles\!USERDOMAIN!""
        if not exist !CONTROLLER_PROFILE_FOLDER! mkdir !CONTROLLER_PROFILE_FOLDER! > NUL

        set "ccp="!CEMU_FOLDER:"=!\ControllerProfiles""
        if not exist !ccp! goto:eof

        pushd !CONTROLLER_PROFILE_FOLDER!
        REM : import from CONTROLLER_PROFILE_FOLDER to CEMU_FOLDER
        for /F "delims=" %%x in ('dir /b * 2^>NUL') do (
            set "ccpf="!ccp:"=!\%%x""
            if not exist !ccpf! robocopy  !CONTROLLER_PROFILE_FOLDER! !ccp! "%%x" > NUL
        )
        pushd !BFW_TOOLS_PATH!

    goto:eof
    REM : ------------------------------------------------------------------

    :importSaves
        set fileFound=%~1

        choice /C yn /N /M "Do you want to use this one : %fileFound% (y, n)?"
        if [!ERRORLEVEL!] == [1] set SAVE_FILE=%fileFound%

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
        if [!folderSelected!] == ["NONE"] goto:eof
        REM : in case of DOS characters substitution (might never arrive)
        if not exist !folderSelected! call:runPsCmd %1 %2
        set "%3=!folderSelected!"

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