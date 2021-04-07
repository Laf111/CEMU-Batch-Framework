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
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

    set "setup="!BFW_PATH:"=!\setup.bat""

    REM : optional second arg
    set "GAME_FOLDER_PATH="NONE""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""

    set "myLog="!BFW_LOGS:"=!\updateGamesGraphicPacks.log""

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

    echo ========================================================= >> !myLog!

    if %nbArgs% NEQ 5 (
        echo ERROR ^: on arguments passed ^!  >> !myLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" vgfxpRequiered GAME_FOLDER_PATH titleId buildOldUpdatePaths lockFile >> !myLog!
        echo SYNTAXE ^: "!THIS_SCRIPT!" vgfxpRequiered GAME_FOLDER_PATH titleId buildOldUpdatePaths lockFile
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

    set "strBfwMaxVgfxp=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_GFXP_VERSION=" 2^>NUL') do set "strBfwMaxVgfxp=%%i"
    set "strBfwMaxVgfxp=!strBfwMaxVgfxp:"=!"
    set /A "gfxPackVersion=!strBfwMaxVgfxp:V=!"

    REM : vgfxpRequiered is the version of GFX packs needed by this version of CEMU to run
    set "vgfxpRequiered=!args[0]!"
    set "vgfxpRequiered=!vgfxpRequiered: =!"

    REM : get and check BFW_GP_FOLDER
    set "GAME_FOLDER_PATH=!args[1]!"

    if not exist !GAME_FOLDER_PATH! (
        echo ERROR ^: !GAME_FOLDER_PATH! does not exist ^!

        exit /b 2
    )
    set "titleId=!args[2]!"
    set "titleId=%titleId:"=%"

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : default values (values add for a new game not found in the wii-u titles internal database
    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "DescRead=%%~nxi"

    set "nativeHeight=720"
    set "nativeFps=60"


    REM : get game's data for wii-u database file
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!titleId!';"') do set "libFileLine="%%i""

    REM : strip line to get data
    for /F "tokens=1-12 delims=;" %%a in (!libFileLine!) do (
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
       set "typeCapFps=%%l"
    )

    set /A "resX2=!nativeHeight!*2"

    set "buildOldUpdatePaths=!args[3]!"
    set /A "buildOldUpdatePaths=%buildOldUpdatePaths:"=%"

    set "lockFile=!args[4]!"

    REM : set Game title for packs (folder name)
    set "title=%DescRead:"=%"
    set "GAME_TITLE=%title: =%"

    echo Get !GAME_TITLE! graphic packs for !vgfxpRequiered! packs >> !myLog!
    echo ========================================================= >> !myLog!

    REM : get the current version of GFX packs in BFW_GP_FOLDER
    set "currentVgfxp=NOT_FOUND"

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
        set "currentVgfxp=!fileName:.doNotDelete=!"
        set "currentVgfxp=!currentVgfxp: =!"
    )

    if ["!currentVgfxp!"] == ["NOT_FOUND"] (
        echo ERROR ^: No ^.doNotDelete file found under !BFW_GP_FOLDER!
        exit /b 95
    )

    REM : get the last version of source GFX packs used for creating/completing packs for this game
    set "vgfxpUsed=NOT_FOUND"
    if not exist !glogFile! goto:treatOneGame

    for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find /I "[!titleId!] graphic packs version=" 2^>NUL') do set "vgfxpUsed=%%i"

    if ["!vgfxpUsed!"] == ["NOT_FOUND"] goto:treatOneGame
    set "vgfxpUsed=!vgfxpUsed: =!"

    :treatOneGame
    echo vgfxpUsed ^: !vgfxpUsed! >> !myLog!
    echo currentVgfxp  ^: !currentVgfxp! >> !myLog!

    set "codeFullPath="!GAME_FOLDER_PATH:"=!\code""
    set "GAME_GP_FOLDER="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
    if not exist !GAME_GP_FOLDER! mkdir !GAME_GP_FOLDER! > NUL 2>&1

    echo titleId^: %titleId% >> !myLog!

    REM : optimization : save list of GFX packs in a file to avoid launching the search each time
    REM : Lists V2, V4... are rebuilt only on a GFX packs update, or missing completion state in gLogFile
    REM : those list are created using relative path to BFW_GP_FOLDER (portability OK)
    set "fnrLogUggp="!GAME_GP_FOLDER:"=!\!vgfxpRequiered:"=!Packs.list""

    if [!vgfxpRequiered!] == ["!strBfwMaxVgfxp!"] (
        REM : if status is completed and list exist goto:gfxpSearchDone
        if not ["!currentVgfxp!"] == ["NOT_FOUND"] if ["!vgfxpUsed!"] == ["!currentVgfxp!"] if exist !fnrLogUggp! goto:gfxpSearchDone
        REM : otherwise, delete file
        del /F /S !fnrLogUggp! > NUL 2>&1
        REM : relaunch the search
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --ExcludeDir _graphicPacksV2 --find %titleId:~3% --logFile !fnrLogUggp!
    )
    if [!vgfxpRequiered!] == ["V4"] (
        REM : if status is completed and list exist goto:gfxpSearchDone
        if exist !glogFile! type !glogFile! | find "[!titleId!] graphic packs versionV4=completed" > NUL 2>&1 && if exist !fnrLogUggp! goto:gfxpSearchDone
        REM : otherwise, delete file
        del /F /S !fnrLogUggp! > NUL 2>&1
        REM : relaunch the search
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --ExcludeDir _graphicPacksV2 --find %titleId:~3% --logFile !fnrLogUggp!
    )
    if [!vgfxpRequiered!] == ["V2"] (
        REM : if status is completed and list exist goto:gfxpSearchDone
        if exist !glogFile! type !glogFile! | find "[!titleId!] graphic packs versionV2=completed" > NUL 2>&1 && if exist !fnrLogUggp! goto:gfxpSearchDone
        REM : otherwise, delete file
        del /F /S !fnrLogUggp! > NUL 2>&1
        REM : relaunch the search
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --ExcludeDir _graphicPacksV4 --find %titleId:~3% --logFile !fnrLogUggp!
    )
    :gfxpSearchDone
    call:updateGraphicPacks

    set /A "attempt=1"
    :createUpdateAndDlcLinks
    REM : before waitingLoop :

    REM : if needed create the new folder tree for update and DLC
    REM : if version < 1.1? create links for old folder tree

    REM : (re)create links for new update/DLC folders tree (in case of drive letter changing)
    set "endIdUp=%titleId:~8,8%"
    call:lowerCase !endIdUp! endIdLow

    set "MLC01_FOLDER_PATH="!GAME_FOLDER_PATH:"=!\mlc01""
    set "ffTitleFolder="!MLC01_FOLDER_PATH:"=!\usr\title\00050000""

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
        REM : fail to move folder
        if %ERRORLEVEL% NEQ 0 (
            if !attempt! EQU 1 (
                !MessageBox! "Moving !oldUpdateFolder:"=! failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:createUpdateAndDlcLinks
            )
            call:fillOwnerShipPatch !MLC01_FOLDER_PATH! "!GAME_TITLE!" patch

            !MessageBox! "Move still failed^, take the ownership on !MLC01_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:createUpdateAndDlcLinks
        ) else (
            rmdir /Q /S "!oldUpdateFolder:"=!_tmp" > NUL 2>&1
        )
    )

    REM : log in game library log

    REM : last gfx packs version asked
    if [!vgfxpRequiered!] == ["!strBfwMaxVgfxp!"] (
        REM : update !glogFile!
        if not ["!currentVgfxp!"] == ["NOT_FOUND"] (
            REM : flush glogFile of [!titleId!] graphic packs version
            REM : it will also force to rebuild older packs on the next run (and take eventually new aspect ratios into account)
            if exist !glogFile! type !glogFile! | find "[!titleId!] graphic packs version=" > NUL 2>&1 && call:cleanGameLogFile "[!titleId!] graphic packs version"
            set "msg="!GAME_TITLE! [!titleId!] graphic packs version=!currentVgfxp!""
            call:log2GamesLibraryFile !msg!
        )
    )
    REM : !GAME_TITLE! graphic packs versionVi=completed i=2, 4 are set in createViGraphicPacks.bat
    if not [!vgfxpRequiered!] == ["V2"] (
        REM : for other packs than V2 asked

        REM : link mods in fucntion of the versions supported
        call:linkMods
        REM : move to checkPackLinks
        goto:checkPackLinks
    )

    REM : here vgfxpRequiered=V2 !

    REM : wait the create*.bat end before continue
    echo Waiting all child processes end >> !myLog!

    :waitingLoop
    REM : V2GraphicPack match createOneV2GraphicPack.bat, completeV2GraphicPacks.bat, createV2GraphicPacks.bat
    wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "_BatchFw_Install" | find  /I "V2GraphicPack" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
        goto:waitingLoop
    )

    REM : relaunch the search to get and link V2 packs (made here as new folders are created in V2 completion process)

    del /F !fnrLogUggp! > NUL 2>&1
    REM : relaunching the search in V2 gfx pack folder (to create missing link in GAME_GP_FOLDER in :linkOtherV2GraphicPacks)
    set "gfxPacksV2Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gfxPacksV2Folder! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogUggp!

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

    REM : import user defined ratios graphic packs (specific V2 pack as aspect ratio is used in folder's name)
    for %%a in (!ARLIST!) do call:linkResV2GraphicPacks "%%a"

    call:linkOtherV2GraphicPacks

    :checkPackLinks
    REM :Rebuild links on GFX packs
    echo Check links on GFX packs  >> !myLog!

    REM : check that at least one GFX pack was listed
    dir /B /A:L !GAME_GP_FOLDER! > NUL 2>&1 && (
        pushd !GAME_GP_FOLDER!

        set "resPack="NOT_FOUND""
        if not [!vgfxpRequiered!] == ["V2"] (
            REM : check V6 packs
            for /F "delims=~" %%i in ('dir /A:D /B /S Graphics 2^>NUL') do set "resPack="%%i""

            REM : none, search V4 packs near V6 packs
            if [!resPack!] == ["NOT_FOUND"] for /F "delims=~" %%i in ('dir /A:D /B /S *_Resolution 2^>NUL ^| find /V "_graphicPacksV4"') do set "resPack="%%i""

            REM : none, if not found search for V4 packs under _graphicPacksV4
            if [!resPack!] == ["NOT_FOUND"] for /F "delims=~" %%i in ('dir /A:D /B /S *_Resolution 2^>NUL') do set "resPack="%%i""
        ) else (
            for /F "delims=~" %%i in ('dir /B /S *_%resx2%p* 2^>NUL') do set "resPack="%%i""
        )

        if not [!resPack!] == ["NOT_FOUND"] goto:endMain
    )

    REM : check if a at least a user gp exits (as a folder and ot a link)
    dir /B /A:D !GAME_GP_FOLDER! > NUL 2>&1 && goto:endMain

    REM : warn user
    !MessageBox! "WARNING : No GFX packs were found ! checks logs" 4112

    REM : delete lock file in CEMU_FOLDER
    if exist !lockFile! del /F !lockFile! > NUL 2>&1

    exit /b 80

    :endMain

    echo --------------------------------------------------------- >> !myLog!
    echo done >> !myLog!

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
        if not exist !newUpdateMetaXml! if not exist !oldUpdateMetaXml! (

            if exist !oldDlcFolder! (

                set /A "attempt=1"
                :tryToMoveDlc
                set "tmpFolder="!oldDlcFolder:"=!_tmp""
                move /Y !oldDlcFolder! !tmpFolder! >  NUL 2>&1
                if !ERRORLEVEL! NEQ 0 (

                    if !attempt! EQU 1 (
                        !MessageBox! "Deleting !oldUpdateFolder:"=! failed^, close any program that could use this location" 4112
                        set /A "attempt+=1"
                        goto:tryToMoveDlc
                    )

                    REM : fail to delete the folder
                    call:fillOwnerShipPatch !oldUpdateFolder! "!GAME_TITLE!" patch

                    !MessageBox! "Deleting still failed^, take the ownership on !oldUpdateFolder:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:tryToMoveDlc
                ) else (
                    rmdir /Q /S !tmpFolder! > NUl 2>&1
                )
            )
            goto:eof
        )
        if not exist !oldUpdateMetaXml! if not exist !newUpdateMetaXml! goto:eof

        set /A "attempt=1"
        :tryToMoveFolders
        REM : check if newUpdateFolder exist
        if not exist !newUpdateMetaXml! (

            set "oldDlcMetaXml="!oldDlcFolder:"=!\meta\meta.xml""

            if exist !oldDlcMetaXml! (
                set "folder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c""
                if not exist !folder! mkdir !folder! > NUL 2>&1

                REM : move dlc in new folder tree
                if !ERRORLEVEL! EQU 0 move !oldDlcFolder! !folder! > NUL 2>&1

                set "folder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0005000c\aoc""
                move /Y !folder! !newDlcFolder! > NUL 2>&1
                if %ERRORLEVEL% NEQ 0 (
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
            if %ERRORLEVEL% NEQ 0 (
                rmdir /Q !oldUpdateFolder!
            ) else (
                set /A "success=0"
            )

            if !success! EQU 1 (
                REM : msgbox to user : migrate DLC and update data to new locations, creates links for old locations
                !MessageBox! "Migrate DLC and update data to new locations, creates links for old locations if needed (old versions)"
            ) else (

                if !attempt! EQU 1 (
                    !MessageBox! "Moving update^/DLC to the new locations failed^, close any program that could use !MLC01_FOLDER_PATH:"=!" 4112
                    set /A "attempt+=1"
                    goto:tryToMoveFolders
                )

                REM : fail to move folder
                call:fillOwnerShipPatch !MLC01_FOLDER_PATH! "!GAME_TITLE!" patch

                !MessageBox! "Move still failed^, take the ownership on !MLC01_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                if !ERRORLEVEL! EQU 6 goto:tryToMoveFolders
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
    REM : ------------------------------------------------------------------

    :linkLastVersionMods

        REM : is this version works with the current CEMU ?
        if !vModGfxPack! GEQ 4 (
            REM : if link exist , delete it (mklink does not handle relative paths)
            if exist !linkPath! rmdir /Q !linkPath! > NUL 2>&1
            mklink /J /D !linkPath! !mod! >> !mylog!
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :linkV4Mods

        REM : is this version works with the current CEMU ?
        if !vModGfxPack! GEQ 3 if !vModGfxPack! LEQ 5 (
            REM : if link exist , delete it (mklink does not handle relative paths)
            if exist !linkPath! rmdir /Q !linkPath! > NUL 2>&1
            mklink /J /D !linkPath! !mod! >> !mylog!
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :linkMods
        REM : search user's mods under %GAME_FOLDER_PATH%\Cemu\mods
        set "pat="!GAME_FOLDER_PATH:"=!\Cemu\mods""
        if not exist !pat! mkdir !pat! > NUL 2>&1
        for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do (
            set "modName="%%a""
            set "mod="!GAME_FOLDER_PATH:"=!\Cemu\mods\!modName:"=!""

            set "rulesModFile="!mod:"=!\rules.txt""
            if exist !rulesModFile! (

                set "tName="MOD_!modName:"=!""
                set "linkPath="!GAME_GP_FOLDER:"=!\!tName:"=!""

                for /F "delims=~= tokens=2" %%i in ('type !rulesModFile! 2^>NUL ^| find /I "Version"') do set "vModGfxPackStr=%%i"
                if ["!vModGfxPackStr!"] == ["NOT_FOUND"] (
                    echo ERROR : version was not found in !rulesFile! >> !myLog!
                    echo ERROR : version was not found in !rulesFile!
                ) else (
                    set "vModGfxPackStr=!vModGfxPackStr: =!"
                    set /A "vModGfxPack=!vModGfxPackStr!"

                    if [!vgfxpRequiered!] == ["!strBfwMaxVgfxp!"] call:linkLastVersionMods
                    if [!vgfxpRequiered!] == ["V4"] call:linkV4Mods
                )
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :getMainGfxpFolder

        set "folder=!targetPath!"
        set "lastFolder=!folder!"

        :rewindPath

        for /F "delims=~" %%i in (!folder!) do set "folderName=%%~nxi"

        echo !folderName! | find "_graphicPacksV" > NUL 2>&1 && goto:endFct
        echo !folderName! | find "_BatchFw_Graphic_Packs" > NUL 2>&1 && goto:endFct

        set "lastFolder=!folder!"
        for %%a in (!folder!) do set "parentFolder="%%~dpa""
        set "folder=!parentFolder:~0,-2!""
        goto:rewindPath

        :endFct
        set "targetPath=!lastFolder!"

        for /F "delims=~" %%i in (!lastFolder!) do set "folderName=%%~nxi"
        set "linkPath="!GAME_GP_FOLDER:"=!\!folderName:"=!""
        goto:eof
    REM : ------------------------------------------------------------------

    :createGfxpLink
        set "rules="%~1""

        set "gp=!rules:\rules.txt=!"
        set "relativePath=!gp:*_BatchFw_Graphic_Packs\=!"

        set "linkPath="!GAME_GP_FOLDER:"=!\!relativePath:"=!""
        set "linkPath=!linkPath:\_graphicPacksV2=!"
        set "linkPath=!linkPath:\_graphicPacksV4=!"

        REM : link already exist, exit
        if exist !linkPath! goto:eof

        set "targetPath="!BFW_GP_FOLDER:"=!\!relativePath:"=!""
        call:getMainGfxpFolder

        if exist !targetPath! if not exist !linkPath! mklink /J /D !linkPath! !targetPath! >> !myLog!
 
    goto:eof
    REM : ------------------------------------------------------------------


    :linkResV2GraphicPacks

        set "filter=%~1"
        set "filter=!filter:-=!"

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find /I /V "^!" ^| find "p%filter%" ^| find "File:" 2^>NUL') do (
            set "str="%%i""
            set "str="!str:~2!
            set "str="_BatchFw_Graphic_Packs\_graphicPacksV2\!str:"=!""

            call:createGfxpLink !str!
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :linkOtherV2GraphicPacks

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find /I /V "^!" ^| findStr /R /V /C:"_[0-9]*p" ^| find "File:" 2^>NUL') do (
            set "str="%%i""
            set "str="!str:~2!
            set "str="_BatchFw_Graphic_Packs\_graphicPacksV2\!str:"=!""

            call:createGfxpLink !str!
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

    REM : search gfx packs for VgfxPackVersion [4, 999]
    :searchForLastVersionPacks

        REM : loop on the gfx packs found (reversed list => _graphicPacksVi (i decreasing)
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! 2^>NUL ^| find "File:" ^| find /I /V "_BatchFw" ^| find /V "_graphicPacksV" ^| sort /R') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""
            REM : Get the version of the GFX pack (res or not)
            set "vGfxPackStr=NOT_FOUND"

            for /F "delims=~= tokens=2" %%i in ('type !rulesFile! 2^>NUL ^| find /I "Version"') do set "vGfxPackStr=%%i"
            if ["!vGfxPackStr!"] == ["NOT_FOUND"] (
                echo ERROR : version was not found in !rulesFile! >> !myLog!
                echo ERROR : version was not found in !rulesFile!
            ) else (
                set "vGfxPackStr=!vGfxPackStr: =!"
                set /A "vGfxPack=!vGfxPackStr!"
                REM : is this version works with the current CEMU ?

                REM : TODO : change when V4 packs no longer supported
                if !vGfxPack! GEQ 4 if !vGfxPack! LEQ 999 (

                    set /A "resPackFlag=1"
                    REM : filter to keep resolution packs of requiered version only f(vgfxpRequiered)
                    REM : TODO to be modify when V4 packs will no longer supported
                    echo !rulesFile! | findStr /R /V "Resolution\\rules\.txt" | findStr /R /V "Graphics\\rules\.txt" > NUL 2>&1 && set /A "resPackFlag=0"
                    if !resPackFlag! EQU 1 (

                        REM : still no res GFX pack found
                        if !resGfxPvFound! EQU 0 (

                            REM : the most recent res gfx pack was found (reverse loop)
                            if [!resGfxPack!] == ["NOT_FOUND"] (
                                set "resGfxPack=!rulesFile!"

                                set "rulesFolder=!rulesFile:\rules.txt=!"
                                echo !rulesFile! | find /I "\Graphics" > NUL 2>&1 && (
                                    for %%a in (!rulesFolder!) do set "parentFolder="%%~dpa""
                                    set "titleFolder=!parentFolder:~0,-2!""

                                    for /F "delims=~" %%i in (!titleFolder!) do set "gameName=%%~nxi"
                                )
                                echo !rulesFile! | find /I "_Resolution\" > NUL 2>&1 && (
                                    for /F "delims=~" %%i in (!rulesFolder!) do set "gameName=%%~nxi"
                                    set "gameName=!gameName:_Resolution=!"
                                )
                                echo Found a V!vGfxPack! resolution graphic pack ^: !rulesFile! >> !myLog!
                                set "resGfxPvFound=!vGfxPack!"
                                set "relativePath=!rulesFile:*_BatchFw_Graphic_Packs\=!"
                                call:createGfxpLink !relativePath!
                            )
                        )
                        REM : else no link (only the last matching one)

                    ) else (
                        REM : other kind of matching packs than resolution ones
                        REM : create link in GAME_GP_FOLDER
                        set "relativePath=!rulesFile:*_BatchFw_Graphic_Packs\=!"
                        call:createGfxpLink !relativePath!
                    )
                )
                REM : GFX pack not macthing
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : search gfx packs for V4 [3, 5]
    :searchForV4Packs

        REM : loop on the gfx packs found (reversed list => _graphicPacksVi (i decreasing)
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! 2^>NUL ^| find "File:" ^| find /I /V "_BatchFw" ^| find /V "_graphicPacksV2" ^| sort /R') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""
            REM : Get the version of the GFX pack (res or not)
            set "vGfxPackStr=NOT_FOUND"

            for /F "delims=~= tokens=2" %%i in ('type !rulesFile! 2^>NUL ^| find /I "Version"') do set "vGfxPackStr=%%i"
            if ["!vGfxPackStr!"] == ["NOT_FOUND"] (
                echo ERROR : version was not found in !rulesFile! >> !myLog!
                echo ERROR : version was not found in !rulesFile!
            ) else (
                set "vGfxPackStr=!vGfxPackStr: =!"
                set /A "vGfxPack=!vGfxPackStr!"
                REM : is this version works with the current CEMU ?
                if !vGfxPack! GEQ 3 if !vGfxPack! LEQ 5 (

                    set /A "resPackFlag=1"
                    REM : filter to keep resolution packs of requiered version only f(vgfxpRequiered)
                    echo !rulesFile! | findStr /R /V "Resolution\\rules\.txt" > NUL 2>&1 && set /A "resPackFlag=0"
                    if !resPackFlag! EQU 1 (

                        REM : still no res GFX pack found
                        if !resGfxPvFound! EQU 0 (

                            REM : the most recent res gfx pack was found (reverse loop)
                            if [!resGfxPack!] == ["NOT_FOUND"] (
                                set "resGfxPack=!rulesFile!"

                                set "rulesFolder=!rulesFile:\rules.txt=!"

                                echo !rulesFile! | find /I "\Graphics" > NUL 2>&1 && (
                                    for %%a in (!rulesFolder!) do set "parentFolder="%%~dpa""
                                    set "titleFolder=!parentFolder:~0,-2!""

                                    for /F "delims=~" %%i in (!titleFolder!) do set "gameName=%%~nxi"
                                )
                                echo !rulesFile! | find /I "_Resolution\" > NUL 2>&1 && (
                                    for /F "delims=~" %%i in (!rulesFolder!) do set "gameName=%%~nxi"
                                    set "gameName=!gameName:_Resolution=!"
                                )
                                echo Found a V!vGfxPack! resolution graphic pack ^: !rulesFile! >> !myLog!
                                set "resGfxPvFound=!vGfxPack!"
                                set "relativePath=!rulesFile:*_BatchFw_Graphic_Packs\=!"
                                call:createGfxpLink !relativePath!
                            )
                        )
                        REM : else no link (only the last matching one)

                    ) else (
                        REM : other kind of matching packs than resolution ones
                        REM : create link in GAME_GP_FOLDER
                        set "relativePath=!rulesFile:*_BatchFw_Graphic_Packs\=!"
                        call:createGfxpLink !relativePath!
                    )
                )
                REM : GFX pack not matching
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : search gfx packs for V2 [0, 2]
    :searchForV2Packs

        REM : loop on the gfx packs found (reversed list => _graphicPacksVi (i decreasing)
        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! 2^>NUL ^| find "File:" ^| find /I /V "_BatchFw"  ^| find "_graphicPacksV2" ^| sort /R') do (

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""
            REM : Get the version of the GFX pack (res or not)
            set "vGfxPackStr=NOT_FOUND"

            for /F "delims=~= tokens=2" %%i in ('type !rulesFile! 2^>NUL ^| find /I "Version"') do set "vGfxPackStr=%%i"
            if ["!vGfxPackStr!"] == ["NOT_FOUND"] (
                echo ERROR : version was not found in !rulesFile! >> !myLog!
                echo ERROR : version was not found in !rulesFile!
            ) else (
                set "vGfxPackStr=!vGfxPackStr: =!"
                set /A "vGfxPack=!vGfxPackStr!"
                REM : is this version works with the current CEMU ?
                if !vGfxPack! GEQ 0 if !vGfxPack! LEQ 2 (

                    set /A "resPackFlag=1"
                    REM : filter to keep resolution packs of requiered version only f(vgfxpRequiered)
                    echo !rulesFile! | findStr /R /V "_%resX2%p\\rules" > NUL 2>&1 && set /A "resPackFlag=0"
                    if !resPackFlag! EQU 1 (
                        REM : the most recent res gfx pack was found (reverse loop)
                        if [!resGfxPack!] == ["NOT_FOUND"] (
                            set "resGfxPack=!rulesFile!"

                            set "rulesFolder=!rulesFile:\rules.txt=!"
                            REM : V2
                            set "str=%%i"
                            set "str=!str:rules=!"
                            set "str=!str:\_graphicPacksV2=!"
                            set "str=!str:\=!"
                            set "gameName=!str:_%resX2%p=!"
                            echo Found a V!vGfxPack! resolution graphic pack ^: !rulesFile! >> !myLog!
                            set "resGfxPvFound=!vGfxPack!"
                        )

                    ) else (
                        REM : do not create a link in GAME_GP_FOLDER, it will done at the end of the main
                        set "relativePath=!rulesFile:*_BatchFw_Graphic_Packs\=!"
                    )
                )
                REM : GFX pack not macthing
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :updateGPFolder


        REM : clean links in game's graphic pack folder
        for /F "delims=~" %%a in ('dir /A:L /B !GAME_GP_FOLDER! 2^>NUL') do (
            set "gpLink="!GAME_GP_FOLDER:"=!\%%a""
            rmdir /Q !gpLink! > NUL 2>&1
        )

        REM : check if graphic pack is present for this game (if the game is not supported
        REM : in Slashiee repo, it was deleted last graphic pack's update) => re-create game's graphic packs

        set "resGfxPvFound=0"
        set "resGfxPack="NOT_FOUND""
        set "gameName="

        REM : search in function of vgfxpRequiered to optimize treatment time
        REM : searchFor*Packs (not for V2 only) link the packs !
        if [!vgfxpRequiered!] == ["V2"] call:searchForV2Packs && goto:rulesSearchDone
        if [!vgfxpRequiered!] == ["V4"] call:searchForV4Packs && goto:rulesSearchDone
        call:searchForLastVersionPacks

        :rulesSearchDone

        set "argSup=%gameName%"
        if ["%gameName%"] == [""] set "argSup="

        echo gameName=%gameName% >> !myLog!
        echo titleId=!titleId! >> !myLog!
        echo resGfxPvFound=!resGfxPvFound! >> !myLog!

        REM : if a macthing res gfx pack was found, check the a recent update
        if !resGfxPvFound! NEQ 0 goto:checkCompletionState

        REM : no Gp were found but other version packs found
        REM   (it is the case when graphic pack folder were updated on games that are not supported in Slashiee repo)

        REM : no suitable resolution pack found for this version of CEMU (even in older but supported packs) : create vgfxpRequiered packs

        REM : adjust message in function of a first creation
        if ["!vgfxpUsed!"] == ["NOT_FOUND"] (
            REM : adjust message in function of CAP packs creation
            if ["!typeCapFps!"] == ["NOEF"] (
                wscript /nologo !Start! !MessageBox! "Create GFX res packs for this game ^: the native resolution in internal database is !nativeHeight!p^. Use texture cache info in CEMU ^(Debug^/View texture cache info^) to see if native res is correct^. If needed^, update resources^/wiiTitlesDataBase^.csv then delete the packs created using the dedicated shortcut in order to force them to rebuild^."
            ) else (
                wscript /nologo !Start! !MessageBox! "Create GFX res and FPS packs for this game ^: the native resolution and FPS in internal database are !nativeHeight!p and !nativeFps!FPS^. Use texture cache info in CEMU ^(Debug^/View texture cache info^) to see if native res is correct^. Check while in game ^(not in cutscenes^) if the FPS is correct^. If needed^, update resources^/wiiTitlesDataBase^.csv then delete the packs created using the dedicated shortcut in order to force them to rebuild^."
            )
        ) else (
            REM : no res pack found, create them for !vgfxpRequiered!
            type !logFile! | find "USE_PROGRESSBAR=YES" > NUL 2>&1 && goto:launchCreateGameGraphicPacks

            wscript /nologo !Start! !MessageBox! "New GFX packs version detected, please wait : create GFX res and FPS packs for this game." pop8sec
        )

        :launchCreateGameGraphicPacks
        echo Create BatchFW graphic packs for this game ^.^.^. >> !myLog!
        REM : Create game's graphic pack
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createGameGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !vgfxpRequiered! %titleId% "!argSup!" >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !vgfxpRequiered! %titleId% "!argSup!"
        REM : not waiting because pack will be linked in create*GraphicPacks.bat and afterward for V2 packs
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !vgfxpRequiered! %titleId% "!argSup!"

        REM : move to CAP gfx packs creation
        goto:createCapGP

        :checkCompletionState
        REM : Games already completed for the last versions of gfx packs supported by CEMU (and created by BatchFw if missing in the repo)
        REM : are listed in !glogFile! with the string "!GAME_TITLE! [!titleId!] graphic packs version=graphicPacksXXX"
        REM : (where XXX is the last version of gfx packs downloaded from the CEMU graphic packs gitHub repository)

        REM : check if BatchFw have to complete graphic packs for this game
        set /A "comGP=0"
        type !logFile! | find /I "COMPLETE_GP=YES" > NUL 2>&1 && set /A "comGP=1"
        if !comGP! EQU 0 goto:createCapGP
        
        if [!vgfxpRequiered!] == ["V2"] (
            REM : Games already completed for V2 of gfx packs are listed in !glogFile! with the string
            REM : "!GAME_TITLE! [!titleId!] graphic packs versionV2=completed"
            if exist !glogFile! type !glogFile! | find "[!titleId!] graphic packs versionV2=completed" > NUL 2>&1 && (
                echo V2 packs already completed, nothing to do >> !myLog!
                goto:eof
            )
            echo !resGfxPack! | find "_graphicPacksV2" > NUL 2>&1 && wscript /nologo !Start! !MessageBox! "Check if V2 packs need to be completed^.^.^." pop8sec
        )

        if [!vgfxpRequiered!] == ["V4"] (
            REM : Games already completed for V4 of gfx packs are listed in !glogFile! with the string
            REM : "!GAME_TITLE! [!titleId!] graphic packs versionV4=completed"
            echo !resGfxPack! | find "_graphicPacksV4" > NUL 2>&1 && (
                if exist !glogFile! type !glogFile! | find "[!titleId!] graphic packs versionV4=completed" > NUL 2>&1 && (
                    echo V4 packs already completed, nothing to do >> !myLog!
                    goto:eof
                )
            )
            echo !resGfxPack! | find "_graphicPacksV4" > NUL 2>&1 && wscript /nologo !Start! !MessageBox! "Check if V4 packs need to be completed^.^.^." pop8sec
        )
        echo !resGfxPack! | find "_graphicPacksV" > NUL 2>&1 && goto:launchCreateExtraGraphicPacks
        REM : resGfxPack is located in BFW_GP_FOLDER

        REM : Never completed => goto:createExtraGP
        if ["!vgfxpUsed!"] == ["NOT_FOUND"] goto:createExtraGP

        REM : already completed, check if it was for the last version downloaded
        if not ["!currentVgfxp!"] == ["NOT_FOUND"] if ["!vgfxpUsed!"] == ["!currentVgfxp!"] (
            echo Last version of source GFX packs used = current version, nothing to do >> !myLog!
            goto:eof
        ) else (
            echo Extra graphic packs for this game was built using !vgfxpUsed!^, !currentVgfxp! is the last downloaded >> !myLog!
        )

        :createExtraGP

        REM : here resGfxPack contain a matching version the
        REM : - gfxPackVersion range. It was never completed or with an older version of GFX packs (downloaded earlier)
        REM : - V4 range + never completed
        REM : - V2 range + never completed

        REM : traces
        if ["!currentVgfxp!"] == ["NOT_FOUND"] (
            echo Complete graphic packs for !GAME_TITLE! ^.^.^. >> !myLog!
        else
            echo Complete graphic packs for !GAME_TITLE! based on !currentVgfxp! ^.^.^. >> !myLog!
        )

        REM : adjust message in function of a first completion/creation
        if ["!vgfxpUsed!"] == ["NOT_FOUND"] (
            REM : never completed

            REM : adjust message in function of CAP packs creation
            if not ["!typeCapFps!"] == ["NOEF"] (
                wscript /nologo !Start! !MessageBox! "Complete GFX res pack and create FPS pack for this game ^: the native FPS in internal database is !nativeFps!FPS^. Check while in game ^(not in cutscenes^) if the FPS is correct^. If needed^, update resources^/wiiTitlesDataBase^.csv then delete the pack created using the dedicated shortcut in order to force it to rebuild^."
            ) else (
                wscript /nologo !Start! !MessageBox! "Complete GFX res pack for this game..." pop8sec
            )

        ) else (
            REM : already completed with heralier version and  V4 or V2 never completed (otherwise already exit earlier)

            type !logFile! | find "USE_PROGRESSBAR=YES" > NUL 2>&1 && goto:launchCreateExtraGraphicPacks

            REM : adjust message in function of CAP packs creation
            if not ["!typeCapFps!"] == ["NOEF"] (
                wscript /nologo !Start! !MessageBox! "New GFX packs version detected, please wait : complete GFX res pack and create FPS pack for this game..." pop8sec
            ) else (
                wscript /nologo !Start! !MessageBox! "New GFX packs version detected, please wait : complete GFX res pack for this game..." pop8sec
            )
        )

        :launchCreateExtraGraphicPacks
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createExtraGraphicPacks.bat""
        echo launching !toBeLaunch! !resGfxPack! !titleId! >> !myLog!
        echo launching !toBeLaunch! !resGfxPack! !titleId!
        REM : not waiting because the found res pack is already linked here earlier and wait loop in
        REM : launchGame.bat and wizardFirstSaving match "GraphicPack" pattern
        wscript /nologo !StartHidden! !toBeLaunch! !resGfxPack! !titleId!

        :createCapGP

        REM : create FPS cap graphic packs
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createCapGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !vgfxpRequiered! %titleId% "!argSup!" >> !myLog!
        echo launching !toBeLaunch! !BFW_GP_FOLDER! !GAME_GP_FOLDER! !vgfxpRequiered! %titleId% "!argSup!"
        wscript /nologo !StartHidden! !toBeLaunch! !BFW_GP_FOLDER!  !GAME_GP_FOLDER! !vgfxpRequiered! %titleId% "!argSup!"

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

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !glogFile! (
            set "logFolder="!BFW_LOGS:"=!""
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

