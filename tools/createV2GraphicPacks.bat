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

    set "createOneV2GraphicPack="!BFW_TOOLS_PATH:"=!\createOneV2GraphicPack.bat""

    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "cgpv2LogFile="!BFW_LOGS:"=!\createV2GraphicPacks.log""

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

    echo. > !cgpv2LogFile!
    if %nbArgs% NEQ 4 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER titleIdsList nativeHeight GAME_TITLE >> !cgpv2LogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER titleIdsList nativeHeight GAME_TITLE
        echo given {%*} >> !cgpv2LogFile!
        echo given {%*}
        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"
    
    REM : get titleId list
    set "titleIdsList=!args[1]!"

    set "a2=!args[2]!"
    set /A "nativeHeight=!a2:"=!"

    if !nativeHeight! EQU 720 set /A "nativeWidth=1280"
    if !nativeHeight! EQU 1080 set /A "nativeWidth=1920"

    set "a3=!args[3]!"
    set "GAME_TITLE=!a3:"=!"

    set "gfxPacksV2Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV2""

    echo ========================================================= >> !cgpv2LogFile!
    echo =========================================================
    echo Create V2 graphic packs for !GAME_TITLE! >> !cgpv2LogFile!
    echo Create V2 graphic packs for !GAME_TITLE!
    echo ========================================================= >> !cgpv2LogFile!
    echo =========================================================
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv  >> !cgpv2LogFile!
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv

    REM : create resolution graphic packs
    call:createResGP

    echo Waiting all child process end^.^.^. >> !cgpv2LogFile!
    echo Waiting all child process end^.^.^.
    call:WaitAllChildProcessEnd
    
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions


    :WaitAllChildProcessEnd

        echo Waiting until all chlid process end ^(V2 packs^)^.^.^.
        :waitingLoop
        wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "_BatchFw_Install" | find  /I "V2GraphicPack" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
            goto:waitingLoop
        )
        wmic process get Commandline 2>NUL | find "fnr.exe" | find  /I "_BatchFw_Install" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
            goto:waitingLoop
        )

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

        echo + !wc!x!hc!!desc! GFX packs >> !cgpv2LogFile!
        echo + !wc!x!hc!!desc! GFX packs

        wscript /nologo !StartHidden! !createOneV2GraphicPack! !nativeWidth! !nativeHeight! !wc! !hc! "!GAME_TITLE!" "!desc!" !titleIdsList!
        
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

        set /A "nbLaunched=0"
        
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

        echo ---------------------------------------------------------  >> !cgpv2LogFile!
        echo ---------------------------------------------------------
        echo Create !ratioPassed:-=/! resolution packs >> !cgpv2LogFile!
        echo Create !ratioPassed:-=/! resolution packs
        echo ---------------------------------------------------------  >> !cgpv2LogFile!
        echo ---------------------------------------------------------

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
            echo Unable to get desired aspect ratio ^(choosen during setup^) ^? >> !cgpv2LogFile!
            echo Unable to get desired aspect ratio ^(choosen during setup^) ^?
            echo Delete batchFW outputs and relaunch >> !cgpv2LogFile!
            echo Delete batchFW outputs and relaunch
            exit /b 2
        ) else (
            set /A "nbAr-=1"
        )

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


