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

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "cv2gpLogFile="!BFW_LOGS:"=!\completeV2GraphicPacks.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "instanciateResX2gp="!BFW_TOOLS_PATH:"=!\instanciateResX2gp.bat""
    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

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

    echo. > !cv2gpLogFile!
    if %nbArgs% NEQ 1 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" RULES >> !cv2gpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" RULES
        echo given {%*} >> !cv2gpLogFile!
        echo given {%*}
        exit /b 99
    )

    REM : BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    set "rulesFile=!args[0]!"

    set "rulesFolder=!rulesFile:\rules.txt=!"
    for /F "delims=~" %%i in (!rulesFolder!) do set "gpNameFolder=%%~nxi"

    REM : Get the first titleId from the list in the GFX pack
    set "titleId=NOT_FOUND"
    for /F "delims=~=, tokens=2" %%i in ('type !rulesFile! ^| find /I "titleIds"') do set "titleId=%%i"
    set "titleId=%titleId: =%"
    if ["%titleId%"] == ["NOT_FOUND"] (
        echo ERROR : titleId was not found in !rulesFile! >> !cv2gpLogFile!
        echo ERROR : titleId was not found in !rulesFile!
        goto:eof
    )

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine

    !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
    echo ERROR^: Unable to get informations on the game for titleId %titleId% ^? >> !cv2gpLogFile!
    echo ERROR^: Unable to get informations on the game for titleId %titleId% ^?
    echo ERROR^: Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase! >> !cv2gpLogFile!
    echo ERROR^: Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase!
    exit /b 3

    :stripLine
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

    if !nativeHeight! EQU 720 set /A "nativeWidth=1280"
    if !nativeHeight! EQU 1080 set /A "nativeWidth=1920"

    REM : double of the native height of the game
    set /A "resX2=!nativeHeight!*2"
    set "GAME_TITLE=!gpNameFolder:_%resX2%p=!"
    
    echo ========================================================= >> !cv2gpLogFile!
    echo =========================================================
    echo Complete V2 graphic packs for !GAME_TITLE! >> !cv2gpLogFile!
    echo Complete V2 graphic packs for !GAME_TITLE!
    echo ========================================================= >> !cv2gpLogFile!
    echo =========================================================
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv  >> !cv2gpLogFile!
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv

    REM : SCREEN_MODE
    set "screenMode=fullscreen"
    set "aspectRatiosList="
    set "aspectRatiosArray="
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
        echo Unable to get desired aspect ratio ^(choosen during setup^) ^? >> !cv2gpLogFile!
        echo Unable to get desired aspect ratio ^(choosen during setup^) ^?
        echo Delete batchFW outputs and relaunch >> !cv2gpLogFile!
        echo Delete batchFW outputs and relaunch
        exit /b 2
    ) else (
        set /A "nbAr-=1"
    )

    set "rulesFolder=!rulesFile:\rules.txt=!"

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!rulesFolder!) do set "gpNameFolder=%%~nxi"

    set "gpNativeHeight=NOT_FOUND"

    REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
    type !rulesFile! | find /I "height = !resX2!" > NUL 2>&1 && (
        set "gpNativeHeight=!nativeHeight!"
    )

    echo !rulesFile! | find /I /V "!resX2!p" > NUL 2>&1 && (
        echo WARNING : graphic pack folder name does not match 2 x native Height >> !cv2gpLogFile!
        echo WARNING : graphic pack folder name does not match 2 x native Height
    )

    if ["!gpNativeHeight!"] == ["NOT_FOUND"] (
        echo WARNING : native height was not found in !rulesFile! >> !cv2gpLogFile!
        echo WARNING : native height was not found in !rulesFile!
    )

    echo Native height set to !gpNativeHeight! in rules.txt >> !cv2gpLogFile!
    echo Native height set to !gpNativeHeight! in rules.txt
    echo. >> !cv2gpLogFile!
    echo.
    REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
    if not ["!gpNativeHeight!"] == ["NOT_FOUND"] if !gpNativeHeight! NEQ !nativeHeight! (
        echo WARNING : native height in rules.txt does not match >> !cv2gpLogFile!
        echo WARNING : native height in rules.txt does not match
    )

    call:completeGfxPacks !gpNameFolder!

    echo =========================================================  >> !cv2gpLogFile!
    echo =========================================================
    echo Waiting all child process end^.^.^. >> !cv2gpLogFile!
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
        wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "_BatchFw_Install" | find  /I "instanciateResX2gp.bat" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
            goto:waitingLoop
        )
        wmic process get Commandline 2>NUL | find "fnr.exe" | find  /I "_BatchFw_Install" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
            goto:waitingLoop
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to create extra graphic packs for a game
    :completeGfxPacks

        set "gpFolderName="%~1""
        set "gpResX2="
        set /A "showEdFlag=0"

        REM : add a flag for aspect ratios presets (BOTW)
        set /A "existAspectRatioPreset=0"

        REM : create missing resolution graphic packs
        for /L %%a in (0,1,!nbAr!) do (

            call:createMissingRes "!aspectRatiosArray[%%a]!" "!descArray[%%a]!"
            if not ["!screenMode!"] == ["fullscreen"] (
                REM : add windowed ratio for 16-9
                if ["!aspectRatiosArray[%%a]!"] == ["16-9"] call:createMissingRes "401-210" "16/9 windowed"
                REM : add windowed ratio for 16-10
                if ["!aspectRatiosArray[%%a]!"] == ["16-10"] call:createMissingRes "361-210" "16/10 windowed"
                REM : add windowed ratio for 683-384
                if ["!aspectRatiosArray[%%a]!"] == ["683-384"] call:createMissingRes "377-192" "16/9 laptop windowed"
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :addResolution

        set "hc=!hi!"
        set "wc=!wi!"

        REM : fullscreen resolutions
        if !hi! EQU !nativeHeight! if !wi! EQU !nativeWidth! goto:eof
        if ["!ratio!"] == [" (16/9)"] call:addPresets & goto:eof

        call:addCustomPresets

    goto:eof
    REM : ------------------------------------------------------------------


    :setPresets

        set "ratio= (!wr!/!hr!)"
        set "desc= !ratio:"=!"

        REM : define resolution range with height, length=25
        set "hList=480 540 720 840 900 1080 1200 1320 1440 1560 1680 1800 2040 2160 2400 2640 2880 3240 3600 3960 4320 4440 4920 5400 5880"
        REM : customize for */10 ratios, length=25
        if ["!hr!"] == ["10"] set "hList=400 600 800 900 950 1050 1200 1350 1500 1600 1800 1950 2250 2400 2550 2700 3000 3200 3600 3900 4200 4500 4950 5400 5850"

        set /A "nbH=0"
        for %%i in (%hList%) do set "hArray[!nbH!]=%%i" && set /A "nbH+=1"

        set /A "hMin=%hArray[0]%"
        REM : compute wMin
        set /A "wMin=!hMin!*!wr!"
        set /A "wMin=!wMin!/!hr!"

        set /A "isOdd=!wMin!%%2"
        if !isOdd! EQU 1 set /A "wMin+=1"

        set /A "hMax=%hArray[24]%"
        REM : compute wMax
        set /A "wMax=!hMax!*!wr!"
        set /A "wMax=!wMax!/!hr!"

        set /A "isOdd=!wMax!%%2"
        if !isOdd! EQU 1 set /A "wMax+=1"

        set /A "previousH=!hMax!"
        set /A "previousW=!wMax!"

        REM :   - loop from (24,-1,0)
        for /L %%i in (24,-1,0) do (
            set /A "hi=!hArray[%%i]!"

            REM : compute wi
            set /A "wi=!hi!*!wr!"
            set /A "wi=!wi!/!hr!"

            set /A "isOdd=!wi!%%2"
            if !isOdd! EQU 1 set /A "wi+=1"

            call:addResolution
            set /A "previousH=!hi!"
            set /A "previousW=!wi!"
        )

      goto:eof
    REM : ------------------------------------------------------------------


    :createMissingRes

        REM : ratioPassed, ex 16-9
        set "ratioPassed=%~1"
        REM : description
        set "description="%~2""

        echo ---------------------------------------------------------  >> !cv2gpLogFile!
        echo ---------------------------------------------------------
        echo Create !ratioPassed:-=/! missing V2 resolution packs >> !cv2gpLogFile!
        echo Create !ratioPassed:-=/! missing V2 resolution packs
        echo ---------------------------------------------------------  >> !cv2gpLogFile!
        echo ---------------------------------------------------------

        REM : compute Width and Height using ratioPassed
        for /F "delims=- tokens=1-2" %%a in ("!ratioPassed!") do set "wr=%%a" & set "hr=%%b"

        set "aspectRatioWidth=!wr!"
        set "aspectRatioHeight=!hr!"

        REM : complete full screen GFX presets (and packs for GFX packs V2)
        call:setPresets

    goto:eof
    REM : ------------------------------------------------------------------



    REM : function to add an extra 16/9 preset in graphic pack of the game
    :addPresets

        set "gpPath=!rulesFolder:_%resX2%p=!"
        set "newGp="!gpPath:"=!_!hc!p!""
        set "gpResX2=!rulesFolder!"

        if not exist !newGp! (
            wscript /nologo !StartHidden! !instanciateResX2gp! !nativeWidth! !nativeHeight! !gpResX2! !newGp! !wc! !hc! "!ratio!" > NUL 2>&1

            echo + !wc!x!hc!!ratio! V2 pack >> !cv2gpLogFile!
            echo + !wc!x!hc!!ratio! V2 pack
        ) else (
            echo - !wc!x!hc!!ratio! V2 pack already exists >> !cv2gpLogFile!
            echo - !wc!x!hc!!ratio! V2 pack already exists

        )

    goto:eof
    REM : ------------------------------------------------------------------

    :setParams

        REM : init
        set "wp=!wr!"
        set "suffixGp="

        set "sd=!desc!"
        set "sd=!sd: =!"
        set "sd=!sd:(=!"
        set "sd=!sd:)=!"
        set "sd=!sd:/=-!"

        set "hp=!hr!_!sd!"

        if ["!ratio!"] == [" (16/9)"] (
            set "desc= (16/9)"
            set "wp=16"
            set "hp=9"
            set "suffixGp="
            goto:eof
        )
        if ["!ratio!"] == [" (16/10)"] (
            set "desc= (16/10)"
            set "wp=16"
            set "hp=10"
            set "suffixGp="
            goto:eof
        )

        echo !ratio! | find /I " (361/210)" > NUL 2>&1 && (
            set "desc= (16/10) windowed"
            set "wp=16"
            set "hp=10"
            set "suffixGp=Win"
            goto:eof
        )
        echo !ratio! | find /I " (401/210)" > NUL 2>&1 && (
            set "desc= (16/9) windowed"
            set "wp=16"
            set "hp=9"
            set "suffixGp=Win"
            goto:eof
        )
        echo !ratio! | find /I " (377/192)" > NUL 2>&1 && (
            set "desc= (16/9 laptop) windowed"
            set "wp=16"
            set "hp=9_laptop"
            set "suffixGp=Win"
            goto:eof
        )
        echo !ratio! | find /I " (683/384)" > NUL 2>&1 && (
            set "desc= (16/9 laptop)"
            set "wp=16"
            set "hp=9_laptop"
            goto:eof
        )

        echo !ratio! | find /I " (64/27)" > NUL 2>&1 && (
            set "wp=21"
            set "hp=9_uw237"
            goto:eof
        )

        echo !ratio! | find /I " (32/15)" > NUL 2>&1 && (
            set "wp=21"
            set "hp=9_uw24"
            goto:eof
        )

        echo !ratio! | find /I " (12/15)" > NUL 2>&1 && (
            set "wp=21"
            set "hp=9_uw213"
            goto:eof
        )

        echo !ratio! | find /I " (37/20)" > NUL 2>&1 && (
            set "wp=Tv"
            set "hp=Flat_r185"
            goto:eof
        )

        echo !ratio! | find /I " (1024/429)" > NUL 2>&1 && (
            set "wp=Tv"
            set "hp=Scope_r239"
            goto:eof
        )

        echo !ratio! | find /I " (256/135)" > NUL 2>&1 && (
            set "wp=Tv"
            set "hp=Dci_r189"
            goto:eof
        )
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to add an extra preset in graphic pack of the game
    :addCustomPresets

        set "wp=!wr!"
        set "hp=!hr!"
        set "suffixGp="
        set "desc= (!description:"=!)"

        call:setParams

        set "gpPath=!rulesFolder:_%resX2%p=!"
        set "newGp="!gpPath:"=!_!hc!p!wp!!hp!!suffixGp!""
        set "gpResX2=!rulesFolder!"

        if not exist !newGp! (
            REM : search for ResX2p489
            set "gpResX2p="!gpResX2:"=!489""

            if not exist !gpResX2p! (
                REM : try ResX2p219
                set "gpResX2p="!gpResX2:"=!219""
            )

            if exist !gpResX2p! (
                set "gpResX2=!gpResX2p!"
            )
            wscript /nologo !StartHidden! !instanciateResX2gp! !nativeWidth! !nativeHeight! !gpResX2! !newGp! !wc! !hc! "!desc!" > NUL 2>&1

            echo + !wc!x!hc!!desc! V2 pack >> !cv2gpLogFile!
            echo + !wc!x!hc!!desc! V2 pack
        ) else (
            echo - !wc!x!hc!!desc! V2 pack already exists >> !cv2gpLogFile!
            echo - !wc!x!hc!!desc! V2 pack already exists
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
