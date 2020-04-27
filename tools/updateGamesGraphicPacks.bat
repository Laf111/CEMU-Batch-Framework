@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color F0

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenCmd="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenCmd.vbs""
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

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"
    echo Starting Date ^: !DATE! > !myLog!

    echo ========================================================= >> !myLog!

    if %nbArgs% NEQ 5 (
        echo ERROR ^: on arguments passed ^!  >> !myLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" gfxType GAME_FOLDER_PATH titleId buildOldUpdatePaths lockFile >> !myLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" gfxType GAME_FOLDER_PATH titleId buildOldUpdatePaths lockFile
        echo given {%*} >> !myLog!
        echo given {%*}

        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    REM : BatchFW folders
    set "BFW_LEGACY_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs\_graphicPacksV2""

    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"

    if not exist !BFW_GP_FOLDER! (
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^! >> !myLog!
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!

        exit /b 1
    )
    REM : check if GFX pack folder was treated to be DOS compliant
REM    call:checkGpFolders

    REM : GFX version to set
    set "setup="!BFW_PATH:"=!\setup.bat""
    set "LastVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION" 2^>NUL') do set "LastVersion=%%i"
    set "LastVersion=!LastVersion:"=!"

    set "gfxType=!args[0]!"
    set "gfxType=V%gfxType:"=%"

    REM : get and check BFW_GP_FOLDER
    set "GAME_FOLDER_PATH=!args[1]!"

    if not exist !GAME_FOLDER_PATH! (
        echo ERROR ^: !GAME_FOLDER_PATH! does not exist ^!

        exit /b 2
    )
    set "titleId=!args[2]!"
    set "titleId=%titleId:"=%"

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    REM : get game's data for wii-u database file
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^^'!titleId!';"') do set "libFileLine="%%i""

    REM : strip line to get data
    for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
       set "titleIdRead=%%a"
       set "DescRead="%%b""
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

    set "buildOldUpdatePaths=!args[3]!"
    set /A "buildOldUpdatePaths=%buildOldUpdatePaths:"=%"

    set "lockFile=!args[4]!"

    REM : set Game title for packs (folder name)
    set "title=%DescRead:"=%"
    set "GAME_TITLE=%title: =%"

    echo Update all graphic packs for !GAME_TITLE! >> !myLog!
    echo ========================================================= >> !myLog!

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
    echo lastInstalledVersion ^: !lastInstalledVersion! >> !myLog!
    echo newVersion  ^: !newVersion! >> !myLog!

    REM : check if BatchFw have to complete graphic packs for this game
    type !logFile! | find /I "COMPLETE_GP=YES" > NUL 2>&1 && goto:searchForGfxPacks
    goto:CreateLinks

    :searchForGfxPacks
    set "codeFullPath="!GAME_FOLDER_PATH:"=!\code""
    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""

    if exist !fnrLogUggp! del /F !fnrLogUggp! > NUL 2>&1
    echo titleId^: %titleId% >> !myLog!

    REM : launching the search in all gfx pack folder (V2 and up)
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogUggp!

    if ["!lastInstalledVersion!"] == ["!newVersion!"] (
        echo lastInstalledVersion = newVersion^, nothing to do >> !myLog!
        goto:createLinks
    )
    REM : flag to know if GFX pack is found
    set "gpfound=0"
    call:updateGraphicPacks

    REM : log in game library log
    if not ["!newVersion!"] == ["NOT_FOUND"] (

        REM : flush glogFile of !GAME_TITLE! graphic packs version
        if exist !glogFile! for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find "!GAME_TITLE! graphic packs version" 2^>NUL') do call:cleanGameLogFile "!GAME_TITLE! graphic packs version"

        set "msg="!GAME_TITLE! graphic packs version=!newVersion!""
        call:log2GamesLibraryFile !msg!
    )

    :createLinks
    REM : before waitingLoop :

    REM : if needed create the new folder tree for update and DLC
    REM : if version < 1.1? create links for old folder tree

    REM : (re)create links for new update/DLC folders tree (in case of drive letter changing)
    set "endIdUp=%titleId:~8,8%"
    call:lowerCase !endIdUp! endIdLow

    set "ffTitleFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\00050000""
    if not exist !ffTitleFolder! mkdir !ffTitleFolder! > NUL 2>&1
    set "oldDlcFolder="!ffTitleFolder:"=!\!endIdUp!\aoc""
    set "newDlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c\!endIdLow!""
    set "oldUpdateFolder="!ffTitleFolder:"=!\!endIdUp!""
    set "newUpdateFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000e\!endIdLow!""

    set /A "success=1"
    call:linkMlcFolder

    REM : v> 1.15.11 and especially v1.16 and up => delete the folder to avoid popup move message
    if !success! EQU 1 if !buildOldUpdatePaths! EQU 0 if exist !oldUpdateFolder! (

        move /Y !oldUpdateFolder! "!oldUpdateFolder:"=!_tmp" >  NUL 2>&1
        REM : fail to delete folder
        if %ERRORLEVEL% NEQ 0 (
            cscript /nologo !MessageBox! "Fail to delete old update location, check that you have the ownership on !oldUpdateFolder:"=!. Cemu will fail to move update/DLC folders to new locations as well" 4112
        ) else (
            rmdir /Q /S "!oldUpdateFolder:"=!_tmp" > NUL 2>&1
        )
    )

    REM : monitor LaunchGame.bat until cemu is launched
    set "logFileTmp="!TMP:"=!\BatchFw_updateGameGfx_process.list""

    REM : wait the create*.bat end before continue
    echo Waiting all child processes end >> !myLog!
    echo Waiting all child processes end

    :waitLoop
    wmic process get Commandline 2>NUL | find /I ".exe" | find /I /V "wmic" | find /I /V "find" > !logFileTmp!
    type !logFileTmp! | find /I "create" | find /I "GraphicPacks" > NUL 2>&1 && goto:waitLoop
    type !logFileTmp! | find /I "fnr.exe" > NUL 2>&1 && goto:waitLoop

    del /F !logFileTmp! > NUL 2>&1

    if not ["!lastInstalledVersion!"] == ["!newVersion!"] (
        del /F !fnrLogUggp! > NUL 2>&1
        REM : relaunching the search in all gfx pack folder (V2 and up)
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogUggp!
    )

    REM : link GFX packs in GAMES_FOLDER_PATH\Cemu\graphicPacks

    REM : clean links in game's graphic pack folder
    for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
        set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
        rmdir /Q !gpLink! > NUL 2>&1
    )

    REM :Rebuild links on GFX packs
    echo Rebuild links on GFX packs >> !myLog!
    echo Rebuild links on GFX packs

    REM : import GFX packs
    call:linkGraphicPacks

    REM : GFX pack V3 and up : import mods and other ratios already treated in importGraphicPacks
    if not ["!gfxType!"] == ["V2"] (
        call:linkMods
        goto:checkPackLinks
    )

    REM : get DESIRED_ASPECT_RATIO and SCREEN_MODE
    for /F "tokens=2 delims=~=" %%j in ('type !logFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (
        REM : add to the list if not already present
        if not ["!ARLIST!"] == [""] echo !ARLIST! | find /V "%%j" > NUL 2>&1 && set "ARLIST=%%j !ARLIST!"
        if ["!ARLIST!"] == [""] set "ARLIST=%%j !ARLIST!"
    )
    REM : get the SCREEN_MODE
    for /F "tokens=2 delims=~=" %%j in ('type !logFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%j"

    if ["!ARLIST!"] == [""] goto:checkPackLinks

    echo ARLIST=!ARLIST! >> !myLog!
    echo ARLIST=!ARLIST!

    REM : import user defined ratios graphic packs
    for %%a in (!ARLIST!) do call:linkOtherV2GraphicPacks "%%a"

    :checkPackLinks
    REM :Rebuild links on GFX packs
    echo Check links on GFX packs  >> !myLog!
    echo Check links on GFX packs 

    REM : check that at least one GFX pack was listed
    dir /B /A:L !GAME_GP_FOLDER! > NUL 2>&1 && (

        set "resPack="NOT_FOUND""
        if not ["!gfxType!"] == ["V2"] (
            for /F "delims=~" %%i in ('dir /B /S *_Resolution') do set "resPack="%%i""
        ) else (
            for /F "delims=~" %%i in ('dir /B /S *_1440p*') do set "resPack="%%i""
        )

        if not [!resPack!] == ["NOT_FOUND"] goto:endMain
    )

    REM : stop execution something wrong happens
    REM : warn user
    cscript /nologo !MessageBox! "WARNING : No GFX packs were found !" 4112

    REM : delete lock file in CEMU_FOLDER
    if exist !lockFile! del /F !lockFile! > NUL 2>&1

    exit 80

    :endMain
    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"
    echo Ending Date ^: !DATE! >> !myLog!

    echo --------------------------------------------------------- >> !myLog!
    echo done >> !myLog!

    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions


    :linkFolder

        if exist !link! (
            for /F "delims=~" %%a in ('dir /A:L /B !link! 2^>NUL') do (
                set "l="!link:"=!\%%a""
                rmdir /Q !l! > NUL 2>&1
            )
        ) else (
            mkdir !link! > NUL 2>&1
        )

        for /F "delims=~" %%a in ('dir /B /A:D !target! 2^>NUL') do (

            for /F "delims=~" %%b in ("%%a") do set "name=%%~nxb"

            set "l="!link:"=!\!name!""
            set "t="!target:"=!\!name!""

            REM : create the link
            mklink /J /D !l! !t! >> !myLog!
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :linkMlcFolder

        set "oldUpdateMetaXml="!oldUpdateFolder:"=!\meta\meta.xml""
        set "newUpdateMetaXml="!newUpdateFolder:"=!\meta\meta.xml""
        set "newDlcMetaXml="!newDlcFolder:"=!\meta\meta.xml""

        REM : if newUpdatefolder not exist and old folder not exist : exit
        if not exist !newUpdateMetaXml! if not exist !oldUpdateMetaXml! goto:eof
        if not exist !oldUpdateMetaXml! if not exist !newUpdateMetaXml! goto:eof

        :tryToMove
        REM : check if newUpdateFolder exist
        if not exist !newUpdateMetaXml! (

            set "oldDlcMetaXml="!oldDlcFolder:"=!\meta\meta.xml""

            if exist !oldDlcMetaXml! (
                set "folder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c""
                if not exist !folder! mkdir !folder! > NUL 2>&1

                REM : move dlc in new folder tree
                if %ERRORLEVEL% EQU 0 move !oldDlcFolder! !folder! > NUL 2>&1

                set "folder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c\aoc""
                move /Y !folder! !newDlcFolder! > NUL 2>&1
                if %ERRORLEVEL% EQU 0 (
                    rmdir /Q !oldDlcFolder!
                ) else (
                    set /A "success=0"
                )
            )

            REM : new folder does not exist and the old one yes
            REM : move update in new folder tree, delete old tree
            set "folder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000e""
            if not exist !folder! mkdir !folder! > NUL 2>&1

            move /Y !oldUpdateFolder! !folder! > NUL 2>&1
            if %ERRORLEVEL% EQU 0 (
                rmdir /Q !oldUpdateFolder!
            ) else (
                set /A "success=0"
            )

            if !success! EQU 1 (
                REM : msgbox to user : migrate DLC and update data to new locations, creates links for old locations
                cscript /nologo !MessageBox! "Migrate DLC and update data to new locations, creates links for old locations if needed (old versions)"
            ) else (
                REM : fail to move folder
                cscript /nologo !MessageBox! "Fail to move folders of update/DLC to the new locations, close any program that could use this location and check that you have the ownership on !oldUpdateFolder:"=!. Update and/or DLC might be missing !, retry ?" 4116
                if !ERRORLEVEL! EQU 6 goto:tryToMove
            )
        )

        if !buildOldUpdatePaths! EQU 0 goto:eof

        if not exist !newDlcMetaXml! goto:linkUpdate

        set "link=!oldDlcFolder!"
        set "target=!newDlcFolder!"

        call:linkFolder

        :linkUpdate
        set "link=!oldUpdateFolder!"
        set "target=!newUpdateFolder!"

        call:linkFolder

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

    :linkMods
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
            mklink /J /D !linkPath! !mod! >> !mylog!
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

        set "gp=!str:\rules=!"

        echo !gp! | find /I "_graphicPacksV2" > NUL 2>&1 && if not ["!gfxType!"] == ["V2"] goto:eof
        echo !gp! | find /V "_graphicPacksV2" > NUL 2>&1 && if ["!gfxType!"] == ["V2"] goto:eof

        set "rgp=!gp!"

        REM : if more than one folder level exist (LastVersion packs, get only the first level
        echo !gp! | find /V "_graphicPacksV2" > NUL 2>&1 && (
            call:getFirstFolder
        )

        set "linkPath="!GAME_GP_FOLDER:"=!\!rgp:"=!""
        set "linkPath=!linkPath:\_graphicPacksV2=!"

        set "targetPath="!BFW_GP_FOLDER:"=!\!rgp:"=!""

        REM : links are already deleted earlier (more efficient than doing it here)
        REM : if not exist !linkPath! => because of GFX pack subfolder (FPS++ ect...)
        if not exist !linkPath! mklink /J /D !linkPath! !targetPath! >> !myLog!

    goto:eof
    REM : ------------------------------------------------------------------


    :linkOtherV2GraphicPacks

        set "filter=%~1"
        set "filter=!filter:-=!"

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:" 2^>NUL') do call:createGpLinks "%%i"

    goto:eof
    REM : ------------------------------------------------------------------


    :linkGraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find /I /V "^!" ^| find "File:" 2^>NUL') do call:createGpLinks "%%i"

    goto:eof
    REM : ------------------------------------------------------------------

REM    :checkGpFolders
REM
REM        for /F "delims=~" %%i in ('dir /B /A:D !BFW_GP_FOLDER! 2^>NUL ^| find "^!"') do (
REM            echo Treat GFX pack folder to be DOS compliant >> !myLog!
REM            wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE
REM            goto:eof
REM        )
REM
REM    goto:eof
REM    REM : ------------------------------------------------------------------

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

        REM : cd to codeFolder
        pushd !codeFullPath!
        set "RPX_FILE="project.rpx""
	    REM : get bigger rpx file present under game folder
        if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : update game's graphic packs
        if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL 2>&1

        call:updateGPFolder
        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------


    :updateGPFolder

        REM : check if graphic pack is present for this game (if the game is not supported
        REM : in Slashiee repo, it was deleted last graphic pack's update) => re-create game's graphic packs

        set /A "resX2=%nativeHeight%*2"

        set "LastVersionfound=0"
        set "gameName=NONE"

        REM : check if a gfx pack with version > 2 exists ?
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find "File:" ^| find /I /V "_BatchFw" ^| find "_Resolution\" ^| find /I /V "_Gamepad" ^| find /I /V "_Performance_"') do (
            set "gpfound=1"

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            REM : graphic pack
            set "LastVersionfound=1"

            echo Found a V!LastVersion! graphic pack ^: !rulesFile! >> !myLog!

            set "gpLastVersionRes=!rulesFile:\rules.txt=!"
            REM : get the game's name from it
            for /F "delims=~" %%i in (!gpLastVersionRes!) do set "str=%%~nxi"
            set "gameName=!str:_Resolution=!"

            goto:handleGfxPacks
        )

        REM : check if a gfx pack with version >= 5 exists ?
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find "File:" ^| find /I /V "_BatchFw" ^| find "Graphics\"') do (
            set "gpfound=1"

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            REM : graphic pack
            set "LastVersionfound=1"

            echo Found a V!LastVersion! graphic pack ^: !rulesFile! >> !myLog!

            set "gpLastVersionRes=!rulesFile:\rules.txt=!"
            REM : get the game's name from it
            for /F "delims=~" %%i in (!gpLastVersionRes!) do set "str=%%~nxi"
            set "gameName=!str:_Graphics=!"

            goto:handleGfxPacks
        )

        REM : No new gfx pack found but is a V2 gfx pack exists ?
        if not exist !BFW_LEGACY_GP_FOLDER! goto:handleGfxPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find "File:" ^| findstr /R "%resX2%p\\rules.txt"') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            REM : V2 graphic pack
            set "str=%%i"
            set "str=!str:rules=!"
            set "str=!str:\_graphicPacksV2=!"
            set "str=!str:\=!"
            set "gameName=!str:_%resX2%p=!"

            goto:handleGfxPacks
        )

        REM : No GFX pack was found

        :handleGfxPacks
        set "argSup=%gameName%"
        if ["%gameName%"] == ["NONE"] set "argSup="

        set /A "createPack=0"

        REM : no Gp were found but other version packs found
        REM   (it is the case when graphic pack folder were updated on games that are not supported in Slashiee repo)

        echo gameName=!gameName! >> !myLog!
        echo titleId=!titleId! >> !myLog!
        echo gpfound=!gpfound! >> !myLog!
        echo LastVersionfound=!LastVersionfound! >> !myLog!

        if !gpfound! EQU 1 if %LastVersionfound% EQU 1 goto:createExtraGP
        REM : if GP found, get the last update version
        if %LastVersionfound% EQU 1 goto:checkRecentUpdate

        if ["!lastInstalledVersion!"] == ["NOT_FOUND"] cscript /nologo !MessageBox! "Complete and create packs for this game : the native resolution and FPS in internal database are !nativeHeight!p and !nativeFps!FPS. Use texture cache info in CEMU (Debug/View texture cache info) to see if native res is correct. Check while in game (not in cutscenes) if the FPS is correct. If needed, update resources/wiiTitlesDataBase.csv then delete the packs created using the dedicated shortcut in order to force them to rebuild."
        set /A "createPack=1"
        echo Create BatchFW graphic packs for this game ^.^.^. >> !myLog!
        REM : Create game's graphic pack
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createGameGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!

        goto:createCapGP

        :checkRecentUpdate


        REM : check if a version were used for this game
        if ["!lastInstalledVersion!"] == ["NOT_FOUND"] goto:createExtraGP
        echo Extra graphic packs for this game was built using !lastInstalledVersion!^, !newVersion! is the last downloaded >> !myLog!

        :createExtraGP

        if ["!newVersion!"] == ["NOT_FOUND"] echo Complete graphic packs for !GAME_TITLE! ^.^.^. >> !myLog!
        if not ["!newVersion!"] == ["NOT_FOUND"] echo Complete graphic packs for !GAME_TITLE! based on !newVersion! ^.^.^. >> !myLog!

        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createExtraGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !rulesFile! !argSup! >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !rulesFile! !argSup!
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! %titleId% !rulesFile! !argSup!

        :createCapGP
        if ["!lastInstalledVersion!"] == ["NOT_FOUND"] if !createPack! EQU 0 cscript /nologo !MessageBox! "Create CAP FPS packs for this game : the native FPS in internal database is !nativeFps!FPS. Check while in game (not in cutscenes) if the FPS is correct. If needed, update resources/wiiTitlesDataBase.csv then delete the packs created using the dedicated shortcut in order to force them to rebuild."

        REM : create FPS cap graphic packs
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createCapGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!

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

