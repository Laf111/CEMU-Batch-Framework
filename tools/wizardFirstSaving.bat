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
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

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
    set "wiiuLibFile="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    
    if not exist !META_FILE! (
        @echo No meta^/meta^.xml file exist under game^'s folder ^!
        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        if not exist !metaFolder! mkdir !metaFolder! > NUL
        @echo Please pick your game titleId ^(copy to clipboard^) in WiiU-Titles-Library^.csv
        @echo ^(if the game is not listed^, search internet to get its title Id and add a row in WiiU-Titles-Library^.csv^)
        @echo Then close notepad to continue

        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !wiiuLibFile!
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
    for /F "delims=" %%i in ('type !wiiuLibFile! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

    if [!libFileLine!] == ["NONE"] (
        @echo ---------------------------------------------------------
        @echo No informations found on the game with a titleId %titleId%
        @echo Adding this game in the data base !wiiuLibFile! ^(720p^,60FPS^)
        @echo '%titleId%';!GAME_TITLE: =!;-;-;-;-;-;-;'%titleId%';720;60 >> !wiiuLibFile!

        REM : update Game's Graphic Packs (wasn't launched in LaunchGame.bat in this case)
        set "ugp="!BFW_TOOLS_PATH:"=!\updateGamesGraphicPacks.bat""
        wscript /nologo !StartHidden! !ugp! true !GAME_FOLDER_PATH!
        
        @echo Check if the game is really in 1280x720 ^(else change to 1920x1080^)
        @echo and if 60FPS is the FPS when playing the game
        @echo Edit and fix !wiiuLibFile! if needed
        @echo ---------------------------------------------------------
        
    
        pause
    )
    
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
    if !ERRORLEVEL! EQU 2 goto:diffProfileFile

    wscript /nologo !Start! !exampleFile!

    :diffProfileFile
    choice /C yn /CS /N /M "Do you want to compare !GAME_TITLE! game profile with an existing profile file? (y, n) : "
    if !ERRORLEVEL! EQU 2 goto:openProfileFile

    :askRefCemuFolder
    REM : get cemu install folder for existing game's profile

    for /F %%b in ('cscript /nologo !browseFolder! "Select a Cemu's install folder as reference"') do set "folder=%%b" && set "REF_CEMU_FOLDER=!folder:?= !"
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

    REM : set online files 
    call:setOnlineFiles    
    
    REM : display main CEMU and CemuHook settings and check conistency
    call:checkCemuSettings
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    choice /C yn /CS /N /M "Open !exampleFile:"=! to see all settings you can override in the game^'s profile? (y, n) : "
    if !ERRORLEVEL! EQU 2 goto:reopen

    wscript /nologo !Start! !exampleFile!
    :reopen
    choice /C yn /CS /N /M "Do you need to re-open profile file to modify overrided settings? (y, n) : "
    if !ERRORLEVEL! EQU 1 goto:openProfileFile

    REM : waiting updateGamesGraphicPacks processes ending
    set "disp=0"
    :waitingLoop
    for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "updateGamesGraphicPacks.bat" ^| find /I /V "find"') do (
        if !disp! EQU 0 (
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

    REM : GFX type to provide
    set "gfxType=V3"
    
    REM : log CEMU
    set "cemuLog="!CEMU_FOLDER:"=!\log.txt""
    if not exist !cemuLog! goto:getPacks

    set "CemuVersionRead=NOT_FOUND"
    set "versionRead=NOT_FOUND"

    for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu"') do set "versionRead=%%e"

    if ["%versionRead%"] == ["NOT_FOUND"] goto:getPacks

    set "str=%versionRead:.=%"
    set /A "CemuVersionRead=%str:~0,4%"
    if %CemuVersionRead% LSS 1140 set "gfxType=V2"
    
    :getPacks
    
    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL
    
    REM : clean links in game's graphic pack folder
    if exist !GAME_GP_FOLDER! for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        rmdir /Q /S !gpLink! 2>NUL
    )
    
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

    if exist !graphicPacksBackup! rmdir /Q !graphicPacks! && move /Y !graphicPacksBackup! !graphicPacks! > NUL

    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if exist !graphicPacks! move /Y !graphicPacks! !graphicPacksBackup!    > NUL

    REM : issue with CEMU 1.15.3 that does not compute cortrectly relative path to GFX folder
    REM : when using a simlink with a the target on another partition
    for %%a in (!GAME_GP_FOLDER!) do set "d1=%%~da"
    for %%a in (!graphicPacks!) do set "d2=%%~da"
        
    if not ["%d1%"] == ["%d2%"] if not ["%CemuVersionRead%"] == ["NOT_FOUND"] if %CemuVersionRead% GEQ 1153 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL & goto:syncCtrlProfiles
    mklink /D /J !graphicPacks! !GAME_GP_FOLDER! 2> NUL
    if !ERRORLEVEL! NEQ 0 robocopy !GAME_GP_FOLDER! !graphicPacks! /mir > NUL

    :syncCtrlProfiles
    REM : synchronized controller profiles (import)
    call:syncControllerProfiles

    REM : launching CEMU
    set "cemu="!CEMU_FOLDER:"=!\Cemu.exe""
    wscript /nologo !StartWait! !cemu!

    set "scp="!GAME_FOLDER_PATH:"=!\Cemu\controllerProfiles""
    if not exist !scp! mkdir !scp! > NUL

    REM : saving CEMU an cemuHook settings
    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.bin > NUL
    set "src="!SETTINGS_FOLDER:"=!\settings.bin""
    set "target="!SETTINGS_FOLDER:"=!\!user!_settings.bin""
    move /Y !src! !target!
    
    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! settings.xml > NUL
    set "src="!SETTINGS_FOLDER:"=!\settings.xml""
    set "target="!SETTINGS_FOLDER:"=!\!user!_settings.xml""
    move /Y !src! !target!

    robocopy !CEMU_FOLDER! !SETTINGS_FOLDER! cemuhook.ini > NUL
    set "src="!SETTINGS_FOLDER:"=!\cemuhook.ini""
    set "target="!SETTINGS_FOLDER:"=!\!user!_cemuhook.ini""
    move /Y !src! !target!
            
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
    timeout /T 2 > NUL
    @echo ---------------------------------------------------------

    exit 0

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :setOnlineFiles

        set "BFW_ONLINE="!GAMES_FOLDER:"=!\_BatchFW_WiiU\onlineFiles""
        set "BFW_ONLINE_ACC="!BFW_ONLINE:"=!\usersAccounts""

        If not exist !BFW_ONLINE_ACC! goto:eof

        REM : get the account.dat file for the current user and the accId
        set "accId=NONE"
        
        set "pat="!BFW_ONLINE_ACC:"=!\!user!*.dat""       

        for /F "delims=~" %%i in ('dir /B !pat!') do (
            set "af="!BFW_ONLINE_ACC:"=!\%%i""
        
            for /F "delims=~= tokens=2" %%j in ('type !af! ^| find /I "AccountId="') do set "accId=%%j"
        )
        
        if ["!accId!"] == ["NONE"] (
            @echo WARNING^: AccountId not found for !user!^, cancel online files installation ^!
            pause
            goto:eof
        )

        REM : copy mlc01 folder to MLC01_FOLDER_PATH if needed
        set "MLC01_FOLDER_PATH="!GAME_FOLDER_PATH:"=!\mlc01""
    
        set "ccerts="!MLC01_FOLDER_PATH:"=!\sys\title\0005001b\10054000\content\ccerts""
        
        if not exist !ccerts! (
            set "omlc01="!BFW_ONLINE:"=!\mlc01""    
            robocopy  !omlc01! !MLC01_FOLDER_PATH! /S > NUL
        )
        
        REM : copy otp.bin and seeprom.bin if needed
        set "t1="!CEMU_FOLDER:"=!\otp.bin""
        set "t2="!CEMU_FOLDER:"=!\seeprom.bin""
        
        set "s1="!BFW_ONLINE_FOLDER:"=!\otp.bin""
        set "S2="!BFW_ONLINE_FOLDER:"=!\seeprom.bin""
       
        if exist !s1! if not exist !t1! robocopy !BFW_ONLINE_FOLDER! !CEMU_FOLDER! otp.bin > NUL
        if exist !s2! if not exist !t2! robocopy !BFW_ONLINE_FOLDER! !CEMU_FOLDER! seeprom.bin > NUL

        REM : patch settings.xml
        set "cs="!CEMU_FOLDER:"=!\settings.xml""
        set "csTmp="!CEMU_FOLDER:"=!\settings.tmp""
              
        type !cs! | find /V "AccountId" | find /V "/Online" | find /V "/content" > !csTmp!
        
        echo         ^<AccountId^>!accId!^<^/AccountId^> >> !csTmp!
        echo     ^<^/Online^> >> !csTmp!
        echo ^<^/content^> >> !csTmp!

        del /F !cs! > NUL
        move /Y !csTmp! !cs! > NUL
        
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
    
    :checkCemuSettings

        REM : check CEMU options (and controollers settings)
        set "cs="!CEMU_FOLDER:"=!\settings.xml""
        if not exist !cs! goto:checkCemuHook
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        @echo Main current CEMU^'s settings ^:
        @echo ---------------------------------------------------------

        REM : get audio et graphic Api
        set "graphicApi=NONE"
        set "audioApi=NONE"
        
        set /A "n=1"
        set "values="
        for /F "tokens=2 delims=~>" %%i in ('type !cs! ^| find /I "<api>"') do (
            
            set "value="NONE""
            for /F "tokens=1 delims=~<" %%j in ('echo "%%i"') do set "value=%%j"" 
            if not [!value!] == ["NONE"] set "values=!values! !value:"=!"
            set /A "n+=1"
        )
        if not ["!values!"] == [""] (
            set "values=!values:~1,%n%!"
            for /F "tokens=1-%n%" %%i in ("!values!") do set "graphicApi=%%i" && set "audioApi=%%j"
        )
        if not ["!graphicApi!"] == ["NONE"] (
            if ["!graphicApi!"] == ["0"] echo Graphics API [OpenGL]
        )

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
        
        
        if not ["!audioApi!"] == ["NONE"] (
            if ["!audioApi!"] == ["0"] echo Audio API used [DirectSound]
            if ["!audioApi!"] == ["1"] echo Audio API used [XAudio]
        )            
        if ["!audioApi!"] == ["NONE"] (
            if ["!graphicApi!"] == ["0"] echo Audio API used [DirectSound]
            if ["!graphicApi!"] == ["1"] echo Audio API used [XAudio]
        )
        
        for /F "tokens=1-6 delims=~<>^" %%i in ('type !cs! ^| find /I "^<delay^>" 2^>NUL') do echo Latency set [%%k ms]
        type !cs! | find /I "<TVDevice><" > NUL && echo Audio TV device [OFF] && goto:getVolume
        type !cs! | find /I /V "<TVDevice>" | find /I "default" > NUL && echo Audio TV device [main audio device] && goto:getVolume
        type !cs! | find /I /V "<TVDevice>" > NUL && echo Audio TV device [use specific user device]

        :getVolume
        for /F "tokens=1-6 delims=~<>^" %%i in ('type !cs! ^| find /I "<TVVolume>" 2^>NUL') do echo Audio TV Volume set [%%k]

        type !cs! | find /I "<AccountId><" > NUL && echo Online mode [OFF] && goto:checkCemuHook
        for /F "tokens=1-6 delims=~<>^" %%i in ('type !cs! ^| find /I "<AccountId>" 2^>NUL') do echo Online mode [ON, id=%%k]
        
        :checkCemuHook
        if not exist !chs! goto:eof
        @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        @echo Current CemuHook^'s settings ^:
        @echo ---------------------------------------------------------
        type !chs! | find /I /V "#" | find /I /V "["
        type !chs! | find /I /V "#" | find /I /V "[" | find /I "customTimerMode" | find /I /V "default" | find /I /V "none" > NUL && (
            type !PROFILE_FILE! | find /I /V "#" | find /I "useRDTSC" | find /I "false" 2> NUL && goto:eof
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
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogWgp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:"') do (

            set "str=%%i"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" | find /V "_graphicPacksV2" && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_FOLDER:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )

            set "tName=!gp:_graphicPacksV2=!"
            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL
            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            if not ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V2"] mklink /J /D !linkPath! !targetPath! > NUL
            if ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V3"] mklink /J /D !linkPath! !targetPath! > NUL
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :importGraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogWgp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:"') do (

            set "str=%%i"
            set "str=!str:~1!"

            set "gp=!str:\rules=!"

            echo !gp! | find "\" | find /V "_graphicPacksV2" && (
                REM : V3 graphic pack with more than one folder's level
                set "fp="!BFW_GP_FOLDER:"=!\!gp:"=!""

                for %%a in (!fp!) do set "parentFolder="%%~dpa""
                set "pfp=!parentFolder:~0,-2!""

                for /F "delims=" %%i in (!pfp!) do set "gp=%%~nxi"
            )
            
            set "tName=!gp:_graphicPacksV2=!"
            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! 2>NUL
            set "targetPath="!BFW_GP_FOLDER:"=!\!gp:_graphicPacksV2=_graphicPacksV2\!""

            if not ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V2"] mklink /J /D !linkPath! !targetPath! > NUL
            if ["!tName!"] == ["!gp!"] if ["!gfxType!"] == ["V3"] mklink /J /D !linkPath! !targetPath! > NUL

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