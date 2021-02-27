@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

REM    color 4F
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
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "cgpv4LogFile="!BFW_LOGS:"=!\createV4GraphicPacks.log""

    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    REM : set current char codeset
    call:setCharSet

    REM : output = path to gfx pack created
    set "gfxpPath="NOT_CREATED""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    echo. > !cgpv4LogFile!

    if %nbArgs% NEQ 5 (
        echo ERROR ^: on arguments passed ^!
        echo ERROR ^: on arguments passed ^! >> !cgpv4LogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER titleIdsList nativeHeight GAME_TITLE
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER GAME_GP_FOLDER titleIdsList nativeHeight GAME_TITLE >> !cgpv4LogFile!
        echo given {%*}
        echo given {%*} >> !cgpv4LogFile!
        exit /b 99
        exit /b 99 >> !cgpv4LogFile!
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"

    set "GAME_GP_FOLDER=!args[1]!"

    REM : get titleId list
    set "titleIdsList=!args[2]!"

    set "a3=!args[3]!"
    set /A "nativeHeight=!a3:"=!"

    if !nativeHeight! EQU 720 set /A "nativeWidth=1280"
    if !nativeHeight! EQU 1080 set /A "nativeWidth=1920"

    set "a4=!args[4]!"
    set "GAME_TITLE=!a4:"=!"
    set "gfxPacksV4Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV4""

    REM : initialize graphic pack (always create new ones in gfxPacksV4Folder)
    set "gfxp="!gfxPacksV4Folder:"=!\!GAME_TITLE!_Resolution""

    if not exist !gfxp! mkdir !gfxp! > NUL 2>&1
    set "gfxpPath="!gfxp:"=!\rules.txt""

    echo =========================================================
    echo ========================================================= >> !cgpv4LogFile!
    echo Create V4 graphic packs for !GAME_TITLE!
    echo Create V4 graphic packs for !GAME_TITLE! >> !cgpv4LogFile!
    echo =========================================================
    echo ========================================================= >> !cgpv4LogFile!

    REM : create resolution graphic packs
    call:createResGP

    REM : create link to res pack in GAME_GP_FOLDER (not found in searchFor*Packs)
    set "relativePath=!gfxpPath:*_BatchFw_Graphic_Packs\=!"
    call:createGfxpLink !relativePath!

    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

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
        set "linkPath=!linkPath:\_graphicPacksV4=!"

        REM : link already exist, exit
        if exist !linkPath! goto:eof

        set "targetPath="!BFW_GP_FOLDER:"=!\!relativePath:"=!""
        call:getMainGfxpFolder

        if exist !targetPath! if not exist !linkPath! mklink /J /D !linkPath! !targetPath! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------
        
    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix_create.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gfxp! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------

    :initResGraphicPack

        echo [Definition] > !gfxpPath!
        set "list=!titleIdsList:"=!"
        echo titleIds = !list! >> !gfxpPath!

        echo name = Resolution >> !gfxpPath!
        echo path = "!GAME_TITLE!/Graphics/Resolution" >> !gfxpPath!
        if !nativeHeight! EQU 720 (
            echo description = Created by BatchFw considering that the native resolution is 720p^. Check Debug^/View texture cache info in CEMU ^: 1280x720 must be overrided ^. If it is not^, change the native resolution to 1080p in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !gfxpPath!
        ) else (
            echo description = Created by BatchFw considering that the native resolution is 1080p. Check Debug^/View texture cache info in CEMU ^: 1920x1080 must be overrided ^. If it is not^, change the native resolution to 720p in _BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !gfxpPath!
        )
        echo version = 4 >> !gfxpPath!
        echo. >> !gfxpPath!

        echo. >> !gfxpPath!
        echo [Default] >> !gfxpPath!
        echo $width = !nativeWidth! >> !gfxpPath!
        echo $height = !nativeHeight! >> !gfxpPath!
        echo $gameWidth = !nativeWidth! >> !gfxpPath!
        echo $gameHeight = !nativeHeight! >> !gfxpPath!
        echo. >> !gfxpPath!
        echo. >> !gfxpPath!
        echo # TV Resolution >> !gfxpPath!
        echo. >> !gfxpPath!
    goto:eof
    REM : ------------------------------------------------------------------

    :fillResGraphicPack
        set "overwriteWidth=%~1"
        set "overwriteHeight=%~2"

        echo [Preset] >> !gfxpPath!
        echo name = %overwriteWidth%x%overwriteHeight% %~3 >> !gfxpPath!
        echo $width = %overwriteWidth% >> !gfxpPath!
        echo $height = %overwriteHeight% >> !gfxpPath!
        echo $gameWidth = !nativeWidth! >> !gfxpPath!
        echo $gameHeight = !nativeHeight! >> !gfxpPath!
        echo. >> !gfxpPath!

    goto:eof
    REM : ------------------------------------------------------------------

    :finalizeResGraphicPack


        REM : res ratios instructions ------------------------------------------------------
        set /A "resRatio=1"

        REM : loop to create res res/2 res/3 .... res/8
        :beginLoopRes

        set /A "r=!nativeHeight!%%!resRatio!"
        if !r! NEQ 0 set /A "resRatio+=1" & goto:beginLoopRes

        REM : compute targetHeight
        set /A "targetHeight=!nativeHeight!/!resRatio!"

        REM : compute targetWidth
        set /A "targetWidth=!nativeWidth!/!resRatio!"

        REM 1^/%resRatio% res : %targetWidth%x%targetHeight%
        call:writeRoundedFilters >> !gfxpPath!

        if !targetHeight! LEQ 8 goto:addFilters
        if !resRatio! GEQ 12 goto:addFilters
        set /A "resRatio+=1"
        goto:beginLoopRes

        :addFilters

        REM : add commonly used 16/9 res filters
        echo # add commonly used 16^/9 res filters >> !gfxpPath!
        echo #  >> !gfxpPath!
        echo #  >> !gfxpPath!

        if !nativeHeight! EQU 720 (
            REM : (1080/2 = 540, for 1080 treated when resRatio = 2)

            echo # 960 x 540 Res >> !gfxpPath!
            echo [TextureRedefine] >> !gfxpPath!
            echo width = 960 >> !gfxpPath!
            echo height = 540 >> !gfxpPath!
            echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
            echo formatsExcluded = 0x431 >> !gfxpPath!
            echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !gfxpPath!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* 540 >> !gfxpPath!
            echo #  >> !gfxpPath!

            echo # 960 x 544 Res >> !gfxpPath!
            echo [TextureRedefine] >> !gfxpPath!
            echo width = 960 >> !gfxpPath!
            echo height = 544 >> !gfxpPath!
            echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
            echo formatsExcluded = 0x431 >> !gfxpPath!
            echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !gfxpPath!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* 544 >> !gfxpPath!
            echo #  >> !gfxpPath!
        )

        echo # 1137 x 640 Res >> !gfxpPath!
        echo [TextureRedefine] >> !gfxpPath!
        echo width = 1137 >> !gfxpPath!
        echo height = 640 >> !gfxpPath!
        echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
        echo formatsExcluded = 0x431 >> !gfxpPath!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 1137 >> !gfxpPath!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !gfxpPath!
        echo #  >> !gfxpPath!

        echo # 1152 x 640 Res >> !gfxpPath!
        echo [TextureRedefine] >> !gfxpPath!
        echo width = 1152 >> !gfxpPath!
        echo height = 640 >> !gfxpPath!
        echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
        echo formatsExcluded = 0x431 >> !gfxpPath!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 1152 >> !gfxpPath!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !gfxpPath!
        echo #  >> !gfxpPath!

        echo # 896 x 504 Res >> !gfxpPath!
        echo [TextureRedefine] >> !gfxpPath!
        echo width = 896 >> !gfxpPath!
        echo height = 504 >> !gfxpPath!
        echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
        echo formatsExcluded = 0x431 >> !gfxpPath!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 896 >> !gfxpPath!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 504 >> !gfxpPath!
        echo #  >> !gfxpPath!

        echo # 768 x 432 Res >> !gfxpPath!
        echo [TextureRedefine] >> !gfxpPath!
        echo width = 768 >> !gfxpPath!
        echo height = 432 >> !gfxpPath!
        echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
        echo formatsExcluded = 0x431 >> !gfxpPath!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 768 >> !gfxpPath!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 432 >> !gfxpPath!
        echo #  >> !gfxpPath!

        echo # 512 x 288 Res >> !gfxpPath!
        echo [TextureRedefine] >> !gfxpPath!
        echo width = 512 >> !gfxpPath!
        echo height = 288 >> !gfxpPath!
        echo tileModesExcluded = 0x001 # For Video Playback >> !gfxpPath!
        echo formatsExcluded = 0x431 >> !gfxpPath!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 512 >> !gfxpPath!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 288 >> !gfxpPath!

        REM : force UTF8 format
        set "utf8=!gfxpPath:rules.txt=rules.bfw_tmp!"
        copy /Y !gfxpPath! !utf8! > NUL 2>&1
        type !utf8! > !gfxpPath!
        del /F !utf8! > NUL 2>&1

        REM : Linux formating (CRLF -> LF)
        call:dosToUnix

    goto:eof
    REM : ------------------------------------------------------------------

    :writeRoundedFilters

        REM : loop on -8,-4,0,4,12 (rounded values)
        set /A "rh=0"
        for /L %%i in (-8,4,12) do (

            echo # 1/!resRatio! Res rounded at %%i
            echo [TextureRedefine]
            echo width = !targetWidth!

            set /A "rh=!targetHeight!+%%i"
            echo height = !rh!
            echo tileModesExcluded = 0x001 # For Video Playback
            echo formatsExcluded = 0x431
            echo overwriteWidth = ^($width^/$gameWidth^) ^* !targetWidth!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* !rh!
            echo.
        )
        echo.

    goto:eof
    REM : ------------------------------------------------------------------

    :setParams

        echo !ratio! | find /I " (361/210)" > NUL 2>&1 && set "desc= (16/10) windowed"

        echo !ratio! | find /I " (401/210)" > NUL 2>&1 && set "desc= (16/9) windowed"

        echo !ratio! | find /I " (377/192)" > NUL 2>&1 && set "desc= (16/9 laptop) windowed"

        echo !ratio! | find /I " (683/384)" > NUL 2>&1 && set "desc= (16/9 laptop)"

        REM : others ratios already have a description up to date

    goto:eof
    REM : ------------------------------------------------------------------

    :addResolution

        set "hc=!hi!"
        set "wc=!wi!"

        set "desc= (!description:"=!)"

        call:setParams

        echo + !wc!x!hc!!desc! GFX packs
        echo + !wc!x!hc!!desc! GFX packs >> !cgpv4LogFile!

        REM : V3 and up
        set "descUpdated=!desc!"
        if !hc! EQU !nativeHeight! if !wc! EQU !nativeWidth! (
            set "descUpdated=!desc:)=! Default)"
        )
        call:fillResGraphicPack !wc! !hc! "!descUpdated!"

    goto:eof
    REM : ------------------------------------------------------------------


    :setPresets

        set "ratio= (!wr!/!hr!)"

        REM : define resolution range with height, length=25
        set "hList=480 540 720 840 900 1080 1200 1320 1440 1560 1680 1800 2040 2160 2400 2640 2880 3240 3600 3960 4320 4440 4920 5400 5880"
        REM : customize for */10 ratios, length=25
        if ["!hr!"] == ["10"] set "hList=400 600 800 900 950 1050 1200 1350 1500 1600 1800 1950 2250 2400 2550 2700 3000 3200 3600 3900 4200 4500 4950 5400 5850"

        set /A "nbH=0"
        for %%i in (%hList%) do set "hArray[!nbH!]=%%i" && set /A "nbH+=1"

        set /A "hMax=%hArray[24]%"
        set /A "previous=!hMax!"

        REM :   - loop from (24,-1,0)
        for /L %%i in (24,-1,0) do (
            set /A "hi=!hArray[%%i]!"

            REM : compute wi
            set /A "wi=!hi!*!wr!"
            set /A "wi=!wi!/!hr!"

            set /A "isOdd=!wi!%%2"
            if !isOdd! EQU 1 set /A "wi+=1"

            call:addResolution
            set /A "previous=!hi!"
        )


    goto:eof
    REM : ------------------------------------------------------------------


    :createGfxPacks
        REM : ratioPassed, ex 16-9
        set "ratioPassed=%~1"
        REM : description
        set "description="%~2""

        echo ---------------------------------------------------------
        echo --------------------------------------------------------- >> !cgpv4LogFile!
        echo Create !ratioPassed:-=/! resolution packs
        echo Create !ratioPassed:-=/! resolution packs >> !cgpv4LogFile!
        echo ---------------------------------------------------------
        echo --------------------------------------------------------- >> !cgpv4LogFile!

        REM : compute Width and Height using ratioPassed
        for /F "delims=- tokens=1-2" %%a in ("!ratioPassed!") do set "wr=%%a" & set "hr=%%b"

        REM : GFX packs
        call:setPresets

        )

    goto:eof
    REM : ------------------------------------------------------------------

    :createResGP

        REM : SCREEN_MODE
        set "screenMode=fullscreen"
        set "aspectRatiosArray="
        set "aspectRatiosList="
        set "descArray="
        set /A "nbAr=0"

        REM : search in all Host_*.log
        set "pat="!BFW_PATH:"=!\logs\Host_*.log""

        for /F "delims=~" %%i in ('dir /S /B !pat! 2^>NUL') do (
            set "currentLogFile="%%i""

            REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)
            for /F "tokens=2-3 delims=~=" %%j in ('type !currentLogFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (

                echo !aspectRatiosList! | find /I /V "%%j" > NUL 2>&1 && (
                    set "aspectRatiosArray[!nbAr!]=%%j"
                    set "descArray[!nbAr!]=%%k"
                    set /A "nbAr+=1"
                    set "aspectRatiosList=!aspectRatiosList! %%j"
                )
            )
            REM : get the SCREEN_MODE
            for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%j"
        )


        if !nbAr! EQU 0 (
            echo Unable to get desired aspect ratio ^(choosen during setup^) ^?
            echo Unable to get desired aspect ratio ^(choosen during setup^) ^? >> !cgpv4LogFile!
            echo Delete batchFW outputs and relaunch
            echo Delete batchFW outputs and relaunch >> !cgpv4LogFile!
            exit /b 2
        ) else (
            set /A "nbAr-=1"
        )

        call:initResGraphicPack !nativeHeight! !nativeWidth! !GAME_TITLE!

        for /L %%a in (0,1,!nbAr!) do (

            call:createGfxPacks "!aspectRatiosArray[%%a]!" "!descArray[%%a]!"

            if not ["!screenMode!"] == ["fullscreen"] (
                REM : add windowed ratio for 16-10
                if ["!aspectRatiosArray[%%a]!"] == ["16-10"] call:createGfxPacks "361-210" "16/10 windowed"
                REM : add windowed ratio for 16-9
                if ["!aspectRatiosArray[%%a]!"] == ["16-9"] call:createGfxPacks "401-210" "16/9 windowed"
                REM : add windowed ratio for 683-384
                if ["!aspectRatiosArray[%%a]!"] == ["683-384"] call:createGfxPacks "377-192" "16/9 laptop windowed"
            )

        )

        call:finalizeResGraphicPack

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
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


