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
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

    set "killBatchFw="!BFW_TOOLS_PATH:"=!\killBatchFw.bat""

    REM : optional second arg
    set "GAME_FOLDER_PATH="NONE""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "myLog="!BFW_PATH:"=!\logs\updateGamesGraphicPacks.log""
    set "fnrLogUggp="!BFW_PATH:"=!\logs\fnr_updateGamesGraphicPacks.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : flag to create leagcy packs
    set "createLegacyPacks=true"

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

    echo ========================================================= > !myLog!

    if %nbArgs% NEQ 4 (
        echo ERROR ^: on arguments passed ^!  >> !myLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" gfxType GAME_FOLDER_PATH titleId lockFile >> !myLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" gfxType GAME_FOLDER_PATH titleId lockFile
        echo given {%*} >> !myLog!
        echo given {%*}

        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"

    if not exist !BFW_GP_FOLDER! (
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^! >> !myLog!
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!

        exit /b 1
    )
    REM : check if GFX pack folder was treated to be DOS compliant
    call:checkGpFolders

    REM : GFX version to set
    set "setup="!BFW_PATH:"=!\setup.bat""
    set "LastVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION" 2^>NUL') do set "LastVersion=%%i"
    set "LastVersion=!LastVersion:"=!"

    set "gfxType=!args[0]!"
    set "gfxType=%gfxType:"=%"

    REM : get and check BFW_GP_FOLDER
    set "GAME_FOLDER_PATH=!args[1]!"

    if not exist !GAME_FOLDER_PATH! (
        echo ERROR ^: !GAME_FOLDER_PATH! does not exist ^!

        exit /b 2
    )
    set "titleId=!args[2]!"
    set "titleId=%titleId:"=%"

    set "lockFile=!args[3]!"

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    echo Update all graphic packs for !GAME_TITLE! >> !myLog!
    echo ========================================================= >> !myLog!

    REM : check if BatchFw have to complete graphic packs for this game
    set "completeGP="NONE""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "COMPLETE_GP" 2^>NUL') do set "completeGP="YES""

    REM : get the last version used
    set "newVersion=NOT_FOUND"

    set "pat="!BFW_GP_FOLDER:"=!\graphicPacks*.doNotDelete""

    set "gpl="NOT_FOUND""
    for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do set "gpl="%%a""
    if not [!gpl!] == ["NOT_FOUND"] set "zipLogFile="!BFW_GP_FOLDER:"=!\!gpl:"=!""

    if [!gpl!] == ["NOT_FOUND"] (
        echo WARNING ^: !pat! not found^, force extra pack creation ^! >> !myLog!
        REM : create one
        set "dnd="!BFW_GP_FOLDER:"=!\graphicPacks563.doNotDelete""
        echo. > !dnd!
        goto:treatOneGame
    )

    for /F "delims=~" %%i in (!zipLogFile!) do (
        set "fileName=%%~nxi"
        set "newVersion=!fileName:.doNotDelete=!"
    )

    REM : get the last version used for launching this game
    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""

    set "lastInstalledVersion=NOT_FOUND"
    if not exist !glogFile! goto:treatOneGame

    for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find /I "!GAME_TITLE!" ^| find /I "graphic packs version" 2^>NUL') do set "lastInstalledVersion=%%i"

    if ["!lastInstalledVersion!"] == ["NOT_FOUND"] goto:treatOneGame
    set "lastInstalledVersion=!lastInstalledVersion: =!"
    set "newVersion=!newVersion: =!"

    :treatOneGame
    echo lastInstalledVersion ^: !lastInstalledVersion!
    echo newVersion  ^: !newVersion!

    set "codeFullPath="!GAME_FOLDER_PATH:"=!"\code""

    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""

    if exist !fnrLogUggp! del /F !fnrLogUggp!

    REM : launching the search
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogUggp!
    call:updateGraphicPacks

    REM : log in game library log
    if not ["!newVersion!"] == ["NOT_FOUND"] (

        REM : flush glogFile of !GAME_TITLE! graphic packs version
        if exist !glogFile! for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find "!GAME_TITLE! graphic packs version" 2^>NUL') do call:cleanGameLogFile "!GAME_TITLE! graphic packs version"

        set "msg="!GAME_TITLE! graphic packs version=!newVersion!""
        call:log2GamesLibraryFile !msg!
    )

    REM : before waitingLoop :
    REM : (re)create links for new update/DLC folders tree (in case of drive letter changing)
    set "endIdUp=%titleId:~8,8%"
    call:lowerCase !endIdUp! endIdLow

    set "oldDlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000\!endIdUp!\aoc""
    set "newDlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c\!endIdLow!""
    call:linkMlcFolder !oldDlcFolder! !newDlcFolder! dlc

    set "oldUpdateFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000\!endIdUp!""
    set "newUpdateFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000e\!endIdLow!""
    call:linkMlcFolder !oldUpdateFolder! !newUpdateFolder! update

    REM : monitor LaunchGame.bat until cemu is launched
    set "logFileTmp="!TMP:"=!\BatchFw_updateGameGfx_process.list""

    REM : wait the create*.bat end before continue
    echo Waiting all child processes end >> !myLog!
    echo Waiting all child processes end
    
    :waitLoop
    wmic process get Commandline | find  ".exe" | find /I /V "wmic" | find /I /V "find" > !logFileTmp!
    type !logFileTmp! | find /I "_BatchFW_Install" | find /I "GraphicPacks.bat" | find /I "create" > NUL 2>&1 && goto:waitLoop

    del /F !logFileTmp! > NUL 2>&1

    REM : link GFX packs in GAMES_FOLDER_PATH\Cemu\graphicPacks
    
    REM : BatchFW folders
    set "BFW_LEGACY_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""

    REM : clean links in game's graphic pack folder
    for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        rmdir /Q !gpLink! > NUL 2>&1
    )

    REM : search game's graphic pack folder
    set "fnrLogLgp="!BFW_PATH:"=!\logs\fnr_linkGamePacks.log""
    if exist !fnrLogLgp! del /F !fnrLogLgp!
    REM : Re launching the search (to get the freshly created packs)

    REM : search in the needed folder
    if ["!gfxType!"] == ["!LastVersion!"] (
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --includeSubDirectories --ExcludeDir _graphicPacksV2 --fileMask "rules.txt" --find !titleId:~3! --logFile !fnrLogLgp!
    ) else (
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_LEGACY_GP_FOLDER! --includeSubDirectories --fileMask "rules.txt" --find !titleId:~3! --logFile !fnrLogLgp!
    )
    
    REM : import GFX packs
    call:importGraphicPacks

    if ["!gfxType!"] == ["!LastVersion!"] (
        call:importMods
        goto:checkPackLinks
    )

    REM : search in all Host_*.log
    set "pat="!BFW_PATH:"=!\logs\Host_*.log""
    for /F "delims=~" %%i in ('dir /S /B !pat! 2^>NUL') do (
        set "currentLogFile="%%i""

        REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)

        for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (
            REM : add to the list if not already present
            if not ["!ARLIST!"] == [""] echo !ARLIST! | find /V "%%j" > NUL 2>&1 && set "ARLIST=%%j !ARLIST!"
            if ["!ARLIST!"] == [""] set "ARLIST=%%j !ARLIST!"
        )
        REM : get the SCREEN_MODE
        for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%j"
    )
    if ["!ARLIST!"] == [""] goto:checkPackLinks

    echo ARLIST=!ARLIST! >> !myLog!
    echo ARLIST=!ARLIST!

    REM : import user defined ratios graphic packs
    for %%a in (!ARLIST!) do (
        if ["%%a"] == ["1610"] call:importOtherGraphicPacks 1610
        if ["%%a"] == ["219"]  call:importOtherGraphicPacks 219
        if ["%%a"] == ["43"]   call:importOtherGraphicPacks 43
        if ["%%a"] == ["489"]  call:importOtherGraphicPacks 489
    )

    :checkPackLinks

    REM : check that at least one GFX pack was listed
    dir /B /A:L !GAME_GP_FOLDER! > NUL 2>&1 && goto:endMain

    REM : stop execution something wrong happens
    REM : warn user
    cscript /nologo !MessageBox! "ERROR ^: No GFX packs were found ^!, let CEMU start but check what happens" 4112

    REM : delete lock file in CEMU_FOLDER
    if exist !lockFile! del /F !lockFile! > NUL 2>&1

    exit 80

    :endMain

    echo --------------------------------------------------------- >> !myLog!
    echo done >> !myLog!
    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :linkMlcFolder

        set "oldFolder=%1"
        set "newFolder=%2"
        set "mlcDataType=%~3"

        REM : create if needed
        if not exist !oldFolder! mkdir !oldFolder! > NUL 2>&1
        if not exist !newFolder! mkdir !newFolder! > NUL 2>&1

        REM : clean ONLY links in both
        for /F "delims=~" %%a in ('dir /A:L /B !oldFolder! 2^>NUL') do (
            set "link="!oldFolder:"=!\%%a""
            rmdir /Q !link! > NUL 2>&1
        )
        for /F "delims=~" %%a in ('dir /A:L /B !newFolder! 2^>NUL') do (
            set "link="!newFolder:"=!\%%a""
            rmdir /Q !link! > NUL 2>&1
        )

        set "oldMetaXml="!oldFolder:"=!\meta\meta.xml""
        set "newMetaXml="!newFolder:"=!\meta\meta.xml""

        REM : where is installed ?
        REM : nowhere -> goto:eof
        if not exist !oldMetaXml! if not exist !newMetaXml! goto:eof
        if not exist !newMetaXml! if not exist !oldMetaXml! goto:eof

        REM : initialize with the case installed in 00050000\!endIdUp!, no installation in 0005000X\!endIdLow!
        set "link=!newFolder!"
        set "target=!oldFolder!"

        REM : if installed in 0005000X\!endIdLow!, no installation in 00050000\!endIdUp!
        if exist !newMetaXml! (
            set "link=!oldFolder!"
            set "target=!newFolder!"
        )

        call:cleanGamesLibraryFile "!GAME_TITLE! mlc !mlcDataType! install path"

        set "msgFull=mlc !mlcDataType! install path=!target:"=!"
        echo !msgFull! >> !myLog!
        set "msgLog="!GAME_TITLE! !msgFull!""
        call:log2GamesLibraryFile !msgLog!

        for /F "delims=~" %%a in ('dir /B !target! ^| find /I /V "aoc"') do (

            REM : basename of GAME FOLDER PATH (used to name shorcut)
            for /F "delims=~" %%b in ("%%a") do set "name=%%~nxb"

            set "l="!link:"=!\!name!""
            set "t="!target:"=!\!name!""

            REM : create the link
            mklink /J /D !l! !t! >> !myLog!
        )

    goto:eof
    REM : ------------------------------------------------------------------


    REM : lower case
    :lowerCase

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:A=a!"
        set "str=!str:B=b!"
        set "str=!str:C=c!"
        set "str=!str:D=d!"
        set "str=!str:E=e!"
        set "str=!str:F=f!"
        set "str=!str:G=g!"
        set "str=!str:H=h!"
        set "str=!str:I=i!"
        set "str=!str:J=j!"
        set "str=!str:K=k!"
        set "str=!str:L=l!"
        set "str=!str:M=m!"
        set "str=!str:N=n!"
        set "str=!str:O=o!"
        set "str=!str:P=p!"
        set "str=!str:Q=q!"
        set "str=!str:R=r!"
        set "str=!str:S=s!"
        set "str=!str:T=t!"
        set "str=!str:U=u!"
        set "str=!str:W=w!"
        set "str=!str:X=x!"
        set "str=!str:Y=y!"
        set "str=!str:Z=z!"

        set "%2=!str!"

    goto:eof

    :importMods
        REM : search user's mods under %GAME_FOLDER_PATH%\Cemu\mods
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\mods""
        if not exist !pat! mkdir !pat! > NUL 2>&1
        for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do (
            set "modName="%%a""
            set "mod="!GAME_FOLDER_PATH:"=!\Cemu\mods\!modName:"=!""
            set "tName="MOD_!modName:"=!""

            set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

            REM : if link exist , delete it
            if exist !linkPath! rmdir /Q !linkPath! > NUL 2>&1
            mklink /J /D !linkPath! !mod!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :getFirstFolder

        set "firstFolder=!gp!"
        :getFirstLevel
        echo !firstFolder! | find "\" > NUL 2>&1 && (

            set "tfp="!BFW_GP_FOLDER:"=!\!firstFolder:"=!""
            for %%a in (!tfp!) do set "parentFolder="%%~dpa""
            set "tfp=!parentFolder:~0,-2!""

            for /F "delims=~" %%i in (!tfp!) do set "firstFolder=%%~nxi"

            goto:getFirstLevel
        )
        set "rgp=!firstFolder!"
    goto:eof
    REM : ------------------------------------------------------------------

    :createGpLinks
        set "str="%~1""
        set "str=!str:~2!"

        set "gp="!str:\rules=!"

        REM : if more than one folder level exist (LastVersion packs, get only the first level
        call:getFirstFolder rgp

        set "linkPath="!GAME_GP_FOLDER:"=!\!rgp:"=!""
        set "targetPath="!BFW_GP_FOLDER:"=!\!rgp:"=!""
        if ["!gfxType!"] == ["V2"] set "targetPath="!BFW_GP_FOLDER:"=!\_graphicPacksV2\!gp:"=!""

        if not exist !linkPath! mklink /J /D !linkPath! !targetPath!

    goto:eof
    REM : ------------------------------------------------------------------


    :importOtherGraphicPacks

        set "filter=%~1"

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLgp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:" 2^>NUL') do call:createGpLinks "%%i"

    goto:eof
    REM : ------------------------------------------------------------------


    :importGraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogLgp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:" 2^>NUL') do call:createGpLinks "%%i"

    goto:eof
    REM : ------------------------------------------------------------------

    :checkGpFolders

        for /F "delims=~" %%i in ('dir /B /A:D !BFW_GP_FOLDER! ^| find "^!" 2^>NUL') do (
            echo Treat GFX pack folder to be DOS compliant
            wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE
            goto:eof
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :cleanGameLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.bfw_tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :updateGraphicPacks

        set "codeFullPath=!codeFullPath:\\=\!"

        REM : not game folder, skip
        if not exist !codeFullPath! goto:eof

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

        REM : update game's graphic packs
        if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL 2>&1

        set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
        REM : get game's data for wii-u database file
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

        REM : strip line to get data
        for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
           set "titleIdRead=%%a"
           set "Desc=%%b"
           set "productCode=%%c"
           set "companyCode=%%d"
           set "notes=%%e"
           set "versions=%%f"
           set "region=%%g"
           set "acdn=%%h"
           set "icoId=%%i"
           set "nativeHeight=%%j"
           set "nativeFps=%%k"
        )

        REM : check if a gp exist for this game (for the last version of GFX pack)
        for /F "delims=~" %%i in ('dir /b /a:d !BFW_GP_FOLDER! ^| find /V "_Performance_" ^| find /I /V "_Resolution_" ^| find /I "_Resolution" 2^>NUL') do (

            set "gpFolder="!BFW_GP_FOLDER:"=!\%%i""
            set "rulesFile="!gpFolder:"=!\rules.txt""

            REM : launching the search
            if exist !rulesFile! for /F "tokens=2 delims=~=" %%i in ('type !rulesFile! ^| find /I "%titleId:~3%" 2^>NUL') do (
                if ["!lastInstalledVersion!"] == ["!newVersion!"] goto:eof
                call:updateGPFolder
                pushd !GAMES_FOLDER!
                goto:eof
            )
        )

        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------


    :updateGPFolder

        REM : check if graphic pack is present for this game (if the game is not supported
        REM : in Slashiee repo, it was deleted last graphic pack's update) => re-create game's graphic packs

        set /A "resX2=%nativeHeight%*2"

        set "gpfound=0"
        set "LastVersionfound=0"
        set "gameName=NONE"
        set "gpLastVersionRes="NONE""

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:"') do (
            set "gpfound=1"

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            echo !rulesFile! | find "_%resX2%p" | find /I /V "_BatchFW " > NUL 2>&1 && (
                REM : V2 graphic pack
                set "gameName=%%i"
                set "gameName=!gameName:rules=!"
                set "gameName=!gameName:\_graphicPacksV2=!"
                set "gameName=!gameName:\=!"
                set "gameName=!gameName:_%resX2%p=!"
            )

            for /F "delims=~" %%a in ('type !rulesFile! ^| find "version = !LastVersion!"') do (
                REM : graphic pack
                set "LastVersionfound=1"
                REM : if a gp of BatchFW was found goto:eof (no need to be completed ni createExtra)
                echo !rulesFile! | find /I /V "_Resolution_" | find /V "_Performance_" | find /I "_Resolution" > NUL 2>&1 && type !rulesFile! | find /I "BatchFW" > NUL 2>&1 && goto:eof
                echo !rulesFile! | find /I /V "_Resolution_" | find /V "_Performance_" | find /I "_Resolution" > NUL 2>&1 && set "gpLastVersionRes=!rulesFile:\rules.txt=!"
            )
        )

        REM : if a graphic pack was found get the game's name from it
        if not [!gpLastVersionRes!] == ["NONE"] (
            for /F "delims=~" %%i in (!gpLastVersionRes!) do set "str=%%~nxi"
            set "gameName=!str:_Resolution=!"
        )

        set "argSup=%gameName%"
        if ["%gameName%"] == ["NONE"] set "argSup="

        REM : no Gp were found but other version packs found
        REM   (it is the case when graphic pack folder were updated on games that are not supported in Slashiee repo)

        echo titleId=!titleId! >> !myLog!
        echo gpfound=!gpfound! >> !myLog!
        echo found=!LastVersionfound! >> !myLog!
        echo createLegacyPacks=%createLegacyPacks% >> !myLog!

        if %gpfound% EQU 1 if %LastVersionfound% EQU 1 goto:createExtraGP
        REM : if GP found, get the last update version
        if %LastVersionfound% EQU 1 goto:checkRecentUpdate

        echo Create BatchFW graphic packs for this game ^.^.^.
        REM : Create game's graphic pack
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createGameGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId%
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! %titleId%

        goto:createCapGP

        :checkRecentUpdate

        REM : check if a version were used for this game
        if ["!lastInstalledVersion!"] == ["NOT_FOUND"] goto:createExtraGP
        echo Extra graphic packs for this game was built using !lastInstalledVersion!^, !newVersion! is the last downloaded

        :createExtraGP

        if [!completeGP!] == ["NONE"] goto:eof

        if ["!newVersion!"] == ["NOT_FOUND"] echo Creating Extra graphic packs for !GAME_TITLE! ^.^.^.
        if not ["!newVersion!"] == ["NOT_FOUND"] echo Creating Extra graphic packs for !GAME_TITLE! based on !newVersion! ^.^.^.

        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createExtraGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! %titleId% !createLegacyPacks! !argSup!

        :createCapGP

        REM : create FPS cap graphic packs
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createCapGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!

    goto:eof
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
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------


    :cleanGamesLibraryFile

        REM : pattern to ignore in log file
        set "pat=%~1"
        set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
        set "logFileTmp="!glogFile:"=!.bfw_tmp""
        if exist !logFileTmp! (
            del /F !glogFile! > NUL 2>&1
            move /Y !logFileTmp! !glogFile! > NUL 2>&1
        )

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
        if not exist !glogFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !glogFile! ^| find /I "!msg!" 2^>NUL') do goto:eof

        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.bfw_tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL 2>&1
        move /Y !gLogFileTmp! !glogFile! > NUL 2>&1

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
