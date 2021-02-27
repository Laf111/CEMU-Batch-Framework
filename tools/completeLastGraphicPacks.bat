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

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "clgpLogFile="!BFW_PATH:"=!\logs\completeLastGraphicPacks.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

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

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    REM : starting DATE
    set "startingDate=%ldt%"
    echo. > !clgpLogFile!

    if %nbArgs% NEQ 1 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" RULES >> !clgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" RULES
        echo given {%*} >> !clgpLogFile!
        echo given {%*}
        exit /b 99
    )

    REM : BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    set "rulesFile=!args[0]!"

    REM : Get the version of the GFX pack
    set "vGfxPackStr=NOT_FOUND"
    for /F "delims=~= tokens=2" %%i in ('type !rulesFile! ^| find /I "Version"') do set "vGfxPackStr=%%i"
    set "vGfxPackStr=%vGfxPackStr: =%"
    if ["!vGfxPackStr!"] == ["NOT_FOUND"] (
        echo ERROR : version was not found in !rulesFile! >> !cgpLogFile!
        echo ERROR : version was not found in !rulesFile!
        exit /b 75
    )
    set /A "vGfxPack=!vGfxPackStr!"

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
                                
    REM : Get the first titleId from the list in the GFX pack
    set "titleId=NOT_FOUND"
    for /F "delims=~=, tokens=2" %%i in ('type !rulesFile! ^| find /I "titleIds"') do set "titleId=%%i"
    set "titleId=%titleId: =%"
    if ["%titleId%"] == ["NOT_FOUND"] (
        echo ERROR : titleId was not found in !rulesFile! >> !clgpLogFile!
        echo ERROR : titleId was not found in !rulesFile!
        goto:eof
    )

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine

    !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
    echo ERROR^: Unable to get informations on the game for titleId %titleId% ^? >> !clgpLogFile!
    echo ERROR^: Unable to get informations on the game for titleId %titleId% ^?
    echo ERROR^: Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase! >> !clgpLogFile!
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

    echo ========================================================= >> !clgpLogFile!
    echo =========================================================
    echo Complete V6 graphic packs ^(missing presets^) for !gameName! >> !clgpLogFile!
    echo Complete V6 graphic packs ^(missing presets^) for !gameName!
    echo ========================================================= >> !clgpLogFile!
    echo =========================================================
    echo Native height set to !nativeHeight! in WiiU-Titles-Library^.csv  >> !clgpLogFile!
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
        echo Unable to get desired aspect ratio ^(choosen during setup^) ^? >> !clgpLogFile!
        echo Unable to get desired aspect ratio ^(choosen during setup^) ^?
        echo Delete batchFW outputs and relaunch >> !clgpLogFile!
        echo Delete batchFW outputs and relaunch
        exit /b 2
    ) else (
        set /A "nbAr-=1"
    )

    set "gpNativeHeight=NOT_FOUND"

    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    REM : get NativeHeight from rules.txt
    set "gpNativeHeight=NOT_FOUND"
    for /F "tokens=2 delims=~=" %%s in ('type !rulesFile! ^| findstr /R "^$gameHeight.*=" 2^>NUL') do set "gpNativeHeight=%%s" & goto:gpNativeHeightFound1
    :gpNativeHeightFound1
    set "gpNativeHeight=!gpNativeHeight: =!"

    if ["!gpNativeHeight!"] == ["NOT_FOUND"] for /F "tokens=4 delims=x " %%s in ('type !rulesFile! ^| find /I "name" ^| find /I "Native" 2^>NUL') do set "gpNativeHeight=%%s" & goto:gpNativeHeightFound2
    :gpNativeHeightFound2

    if ["!gpNativeHeight!"] == ["NOT_FOUND"] (
        echo WARNING : native height was not found in !rulesFile! >> !clgpLogFile!
        echo WARNING : native height was not found in !rulesFile!
    )

    echo Native height set to !gpNativeHeight! in rules.txt >> !clgpLogFile!
    echo Native height set to !gpNativeHeight! in rules.txt
    echo. >> !clgpLogFile!
    echo.
    REM : Add a check consistency on Native height define in WiiU-Titles-Library.csv and rules.txt
    if not ["!gpNativeHeight!"] == ["NOT_FOUND"] if !gpNativeHeight! NEQ !nativeHeight! (
        echo WARNING : native height in rules.txt does not match >> !clgpLogFile!
        echo WARNING : native height in rules.txt does not match
    )

    call:completeGfxPacks !gameName!

    REM : Linux formating (CRLF -> LF)
    call:dosToUnix

    REM : force UTF8 format
    set "utf8="!rulesFolder:"=!\rules.bfw_tmp""
    copy /Y !rulesFile! !utf8! > NUL 2>&1
    type !utf8! > !rulesFile!
    del /F !utf8! > NUL 2>&1

    echo =========================================================  >> !clgpLogFile!
    echo =========================================================


    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "endingDate=%ldt%"
    REM : starting DATE

    echo starting date = %startingDate% >> !clgpLogFile!
    echo starting date = %startingDate%
    echo ending date = %endingDate% >> !clgpLogFile!
    echo ending date = %endingDate%

    exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions


    REM : function to create extra graphic packs for a game
    :completeGfxPacks

        set "gpFolderName="%~1""
        set "gpResX2="
        set /A "showEdFlag=0"

        REM : add a flag for aspect ratios presets (BOTW)
        set /A "existAspectRatioPreset=0"

        REM : check if aspect ratio presets exist
        type !rulesFile! | find "$aspectRatioWidth" > NUL 2>&1 && (
            set /A "existAspectRatioPreset=1"
        )

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

    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix_extra.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------

    :addResolution

        set "hc=!hi!"
        set "wc=!wi!"

        REM : fullscreen resolutions
        if !hi! EQU !nativeHeight! if !wi! EQU !nativeWidth! goto:eof
        if !n5Found! EQU 1 call:addPresets & goto:eof

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

        REM : in order to inser the preset sorted in the rules.txt file
        REM : first check if the 1080 or (1050 for aspect ratio */10) preset already exist
        REM : this prest if at the rank 6 (5 starting from 0) in the array

        set /A "h5=!hArray[5]!"
        REM : compute w5
        set /A "w5=!h5!*!wr!"
        set /A "w5=!w5!/!hr!"

        set /A "isOdd=!w5!%%2"
        if !isOdd! EQU 1 set /A "w5+=1"

        set /A "n5Found=0"

        set "logFileFindPreset="!fnrLogFolder:"=!\!gpFolderName:"=!-Find_!h5!x!w5!.log""
        del /F !logFileFindPreset! > NUL 2>&1

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt"  --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!w5!x!h5!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\n" --logFile !logFileFindPreset!
        for /F "tokens=2-3 delims=." %%i in ('type !logFileFindPreset! ^| find /I /V "^!" ^| find "File:" 2^>NUL') do set /A "n5Found=1"

        if !n5Found! EQU 1 (

            REM :   - loop from (4,-1,0)
            set /A "previousH=!h5!"
            set /A "previousW=!w5!"

            for /L %%i in (4,-1,0) do (
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

            set /A "previousH=!h5!"
            set /A "previousW=!w5!"

            REM :   - loop from (6,1,24)
            for /L %%i in (6,1,24) do (
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
        )

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

        echo ---------------------------------------------------------  >> !clgpLogFile!
        echo ---------------------------------------------------------
        echo Create !ratioPassed:-=/! missing resolution presets >> !clgpLogFile!
        echo Create !ratioPassed:-=/! missing resolution presets
        echo ---------------------------------------------------------  >> !clgpLogFile!
        echo ---------------------------------------------------------

        REM : compute Width and Height using ratioPassed
        for /F "delims=- tokens=1-2" %%a in ("!ratioPassed!") do set "wr=%%a" & set "hr=%%b"

        set "aspectRatioWidth=!wr!"
        set "aspectRatioHeight=!hr!"
        REM  : if a aspect ratio preset exists (push back one)
        if !existAspectRatioPreset! EQU 1 (
            if not ["!ratioPassed: =!"] == ["16-9"] (
                set "logFileAr="!fnrLogFolder:"=!\!gpFolderName:"=!-!ratioPassed!.log""
                wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "[[]Preset[]].*\nname[ ]*=[ ]*16:9.*\ncategory[ ]*=[ ]*Aspect[ ]*Ratio" --replace "[Preset]\nname = 16:9 (Default)\ncategory = Aspect Ratio\n\n[Preset]\nname = !aspectRatioWidth!:!aspectRatioHeight! (!description: =_!)\ncategory = Aspect Ratio\n$aspectRatioWidth = !aspectRatioWidth!\n$aspectRatioHeight = !aspectRatioHeight!" --logFile !logFileAr!
            )
        )

        REM : complete full screen GFX presets (and packs for GFX packs V2)
        call:setPresets

    goto:eof
    REM : ------------------------------------------------------------------

    REM : add a resolution bloc BEFORE the native one in rules.txt
    :pushFront

        if !existAspectRatioPreset! EQU 0 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\n$width = !wc!\n$height = !hc!\n\n[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\n$width = !previousW!\n$height = !previousH!\n" --logFile !logFileNewGp!
        ) else (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\ncondition[ ]*=[ ]*\(\(\(\$aspectRatioWidth[ ]*-[ ]*!aspectRatioWidth!\)[ ]*==[ ]*0\)[ ]*\+[ ]*\(\(\$aspectRatioHeight[ ]*-[ ]*!aspectRatioHeight!\)[ ]*==[ ]*0\)\)[ ]*==[ ]*2.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !wc!\n$height = !hc!\n\n[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !previousW!\n$height = !previousH!\n" --logFile !logFileNewGp!
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : add a resolution bloc AFTER the native one in rules.txt
    :pushBack

        if !existAspectRatioPreset! EQU 0 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\n$width = !previousW!\n$height = !previousH!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
        ) else (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^^[[]Preset[]].*\nname[ ]*=[ ]*!previousW!x!previousH!.*\ncategory[ ]*=[ ]*(TV|) Resolution.*\ncondition[ ]*=[ ]*\(\(\(\$aspectRatioWidth[ ]*-[ ]*!aspectRatioWidth!\)[ ]*==[ ]*0\)[ ]*\+[ ]*\(\(\$aspectRatioHeight[ ]*-[ ]*!aspectRatioHeight!\)[ ]*==[ ]*0\)\)[ ]*==[ ]*2.*\n\$width[ ]*=[ ]*!previousW!.*\n\$height[ ]*=[ ]*!previousH!.*\n" --replace "[Preset]\nname = !previousW!x!previousH!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !previousW!\n$height = !previousH!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
        )

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to add an extra 16/9 preset in graphic pack of the game
    :addPresets

        REM : preset exists
        type !rulesFile! | find "name = !wc!x!hc!" > NUL 2>&1 && (
            echo - !wc!x!hc!!ratio! preset already exists >> !clgpLogFile!
            echo - !wc!x!hc!!ratio! preset already exists
            goto:eof
        )

        echo + !wc!x!hc!!ratio! preset >> !clgpLogFile!
        echo + !wc!x!hc!!ratio! preset

        REM : replacing %wToReplace%xresX2 in rules.txt
        set "logFileNewGp="!fnrLogFolder:"=!\!gpFolderName:"=!-NewGp_!hc!x!wc!.log""
        if exist !logFileNewGp! del /F !logFileNewGp! > NUL 2>&1

        if !hc! GTR !h5! (
            call:pushBack
        ) else (
            call:pushFront
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

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to add an extra preset in graphic pack of the game
    :addCustomPresets

        set "wp=!wr!"
        set "hp=!hr!"
        set "suffixGp="
        set "desc= (!description:"=!)"

        call:setParams

        REM : preset exists
        type !rulesFile! | find "name = !wc!x!hc!" > NUL 2>&1 && (
            echo - !wc!x!hc!!desc! preset already exists >> !clgpLogFile!
            echo - !wc!x!hc!!desc! preset already exists
            goto:eof
        )

        echo + !wc!x!hc!!desc! preset >> !clgpLogFile!
        echo + !wc!x!hc!!desc! preset

        REM : replacing %wToReplace%xresX2 in rules.txt
        set "logFileNewGp="!fnrLogFolder:"=!\!gpFolderName:"=!-NewGp_!hc!x!wc!.log""
        if exist !logFileNewGp! del /F !logFileNewGp! > NUL 2>&1

        REM : add presets at the begining of rules.txt (after version =)
        if !existAspectRatioPreset! EQU 0 (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
        ) else (
            wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !rulesFolder! --fileMask "rules.txt" --useRegEx --useEscapeChars --find "^version = !vGfxPack![ ]*" --replace "version = !vGfxPack!\n\n[Preset]\nname = !wc!x!hc!!desc!\ncategory = TV Resolution\ncondition = ((($aspectRatioWidth - !aspectRatioWidth!) == 0) + (($aspectRatioHeight - !aspectRatioHeight!) == 0)) == 2\n$width = !wc!\n$height = !hc!\n" --logFile !logFileNewGp!
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
