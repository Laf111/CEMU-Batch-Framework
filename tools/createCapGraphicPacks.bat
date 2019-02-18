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
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""    
    
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""    
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""    

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    
    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSetAndLocale

    REM : game's name 
    set "gameName=NONE"
        
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

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_Graphic_Packs""
    if exist !BFW_GP_FOLDER! (
        goto:getTitleId
    )
    REM set Shell.BrowseForFolder arg vRootFolder
    REM : 0  = ShellSpecialFolderConstants.ssfDESKTOP
    set "DIALOG_ROOT_FOLDER="0""

    @echo Please select a reference graphicPacks folder

    call:getFolderPath "Please select CEMU install folder" !DIALOG_ROOT_FOLDER! CEMU_FOLDER
    REM : set BFW_GP_FOLDER to CEMU_FOLDER GraphicPacks subfolder
    set "BFW_GP_FOLDER="!CEMU_FOLDER!\GraphicPacks""

    :getTitleId
    set "checkLenght="
    set "titleId="

    set /P "input=Enter title Id : "
    set "titleId=%input: =%"

    REM : check too short
    set "checkLenght=!titleId:~15,1!"

    if ["x!checkLenght!x"] == ["xx"] (
        @echo Bad titleId ^^! must have at least 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )
    REM : check too long
    set "checkLenght=!titleId:~16,1!"

    if not ["x!checkLenght!x"] == ["xx"] (
        @echo Bad titleId ^^! must have 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )

    goto:inputsAvailables

    REM : titleID and BFW_GP_FOLDER
    :getArgsValue

    if %nbArgs% GTR 3 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID GPV3_NAME^*
        @echo given {%*}
        pause
        exit /b 99
    )
    if %nbArgs% LSS 2 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID GPV3_NAME^*
        @echo given {%*}
        pause
        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"
    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"

    if not exist !BFW_GP_FOLDER! (
        @echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!
        pause
        exit /b 1
    )
    REM : get titleId
    set "titleId=!args[1]!"
    set "titleId=%titleId: =%"

    if %nbArgs% EQU 3 (
        set "gameName=!args[2]!"
        set "gameName=!gameName:"=!"
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

    REM : check if folder name contains forbiden character for !BFW_GP_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !BFW_GP_FOLDER!
    set cr=!ERRORLEVEL!
    if !cr! NEQ 0 (
        @echo Please rename !BFW_GP_FOLDER! path to be DOS compatible ^!^, exiting
        pause
        exit /b 2
    )
    set titleId=%titleId:"=%
    set "ftid=%titleId:~0,16%"

    REM : check if game is recognized
    call:checkValidity %ftid%

    set "wiiuLibFile="!BFW_PATH:"=!\resources\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=" %%i in ('type !wiiuLibFile! ^| find /I "'%ftid%';"') do set "libFileLine="%%i""
    
    if not [!libFileLine!] == ["NONE"] goto:stripLine

    if !QUIET_MODE! EQU 1 (
        @echo Unable to get informations on the game for titleId %ftid% ^?
        @echo Check your entry or if you sure, add a row for this game in !wiiuLibFile!
        pause
        exit /b 3
    )
    @echo Unable to get informations on the game for titleId %ftid% ^?
    @echo Check your entry or if you sure^, add a row for this game in !wiiuLibFile!

    goto:getTitleId

    :stripLine
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

    set "title=%Desc:"=%"
    set "GAME_TITLE=%title: =_%"
        
    REM get all title Id for this game (in case of a new V3 res gp creation)
    set "titleIdList="
    call:getAllTitleIds
  

    REM : create FPS CAP graphic packs
    if not ["!gameName!"] == ["NONE"] set "GAME_TITLE=!gameName!"

    @echo =========================================================
    @echo Create FPS cap graphic packs for !GAME_TITLE!
    @echo =========================================================
    if !QUIET_MODE! EQU 1 goto:begin

    @echo Launching in 12s
    @echo     ^(y^) ^: launch now
    @echo     ^(n^) ^: cancel
    @echo ---------------------------------------------------------
    choice /C yn /T 6 /D y /N /M "Enter your choice ? : "
    if !ERRORLEVEL! EQU 2 (
        @echo Cancelled by user ^!
        goto:eof
    )

    :begin
    REM : FPS++ found flag
    set /A "fpsPP=0"
    set /A "fpsPPV3=0"
    
    REM : initialize V3 graphic pack               
    set "gpV3="!BFW_GP_FOLDER:"=!\!GAME_TITLE!_Speed"" 
    
    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""     
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL    
           
    set "rulesFileV3="!gpV3:"=!\rules.txt""
    set "v3ExistFlag=1"
    
    if not exist !gpV3! (
        set "v3ExistFlag=0"
        mkdir !gpV3! > NUL
        call:initV3CapGP
    ) 
    
    REM : create FPS cap graphic packs
    call:createCapGP
    
    REM : finalize V3 graphic packs if a FPS++ pack was not found
    if !fpsPPV3! EQU 1 rmdir /Q /S !gpV3! 2>NUL && set "v3ExistFlag=1"  
    if %v3ExistFlag% EQU 0 call:finalizeV3CapGP

    if %nbArgs% EQU 0 endlocal && pause
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    exit /b 0
goto:eof


REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :getAllTitleIds
   
        REM now searching using icoId
        set "line="NONE""
        
        for /F "delims=" %%i in ('type !wiiuLibFile! ^| find /I ";%icoId%;"') do ( 
            for /F "tokens=1-11 delims=;" %%a in ("%%i") do (            
               set "titleIdRead=%%a"
               set "titleIdList=!titleIdList!^,!titleIdRead:'=!"
             )        
        )
        set "titleIdList=!titleIdList:~1!" 
    goto:eof
    
    REM : ------------------------------------------------------------------

    REM : function for multiplying integers
    :mulfloat

        REM : get a
        set "numA=%~1"
        REM : get b
        set "numB=%~2"
        REM : get nbDecimals
        set /A "decimals=%~3"

        set /A "one=1"
        set /A "decimalsP1=decimals+1"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        if not ["!numA:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numA% does not have %decimals% decimals
            pause
            exit /b 1
        )

        if not ["!numB:~-%decimalsP1%,1!"] == ["."] (
            echo ERROR ^: the number %numB% does not have %decimals% decimals
            pause
            exit /b 2
        )

        set "fpA=%numA:.=%"
        set "fpB=%numB:.=%"

        REM : a * b
        if %fpB% GEQ %fpA% set /A "mul=fpA*fpB/one"
        if %fpA% GEQ %fpB% set /A "mul=fpB*fpA/one"

        set /A "result=!mul:~0,-%decimals%!"
        REM : floor
        set /A "result=%result%+1"

        REM : output
        set "%4=%result%"

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------
    
    :initV3CapGP
    
        @echo [Definition] > !rulesFileV3!
        @echo titleIds = !titleIdList! >> !rulesFileV3!

        @echo name = Speed Adjustment >> !rulesFileV3!
        @echo path = "!GAME_TITLE!/Modifications/Speed Adjustment" >> !rulesFileV3!
        @echo description = Allows you to adjust the game speed. Please note that the ability to consistently reach the speed will depend on your specs. >> !rulesFileV3!
        @echo version = 3 >> !rulesFileV3!
        @echo # >> !rulesFileV3!
        @echo [Preset] >> !rulesFileV3!
        @echo name = 100%% Speed ^(Default^) >> !rulesFileV3!
        @echo $FPS = %nativeFps% >> !rulesFileV3!
        @echo # >> !rulesFileV3!
        
    goto:eof
    REM : ------------------------------------------------------------------
    
    :fillCapV3GP
            
        set "desc1=%~1"
        set "desc2=%~2"
        
        set "desc=!desc1!%% !desc2!"
        if %v3ExistFlag% EQU 0 ( 
        
            @echo [Preset] >> !rulesFileV3!
            @echo name = !desc! >> !rulesFileV3!
            @echo $FPS = %fps% >> !rulesFileV3!
            @echo # >> !rulesFileV3!
            goto:eof
        )
        
        REM : search for "!desc1!" in rulesFile: if found exit
        for /F "delims=" %%i in ('type !rulesFileV3! ^| find /V "#" ^| find /I "!desc1!"') do goto:eof
    
        REM : not found add it by replacing a [Preset] bloc 

        REM : Adding !fps! preset in rules.txt
        set "logFileV3="!fnrLogFolder:"=!\!gameName:"=!-V3_!fps!cap.log""
        if exist !logFileV3! del /F !logFileV3!
    
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !gpV3! --fileMask rules.txt --find "[Preset]\nname = 100" --replace "[Preset]\nname = !desc!\n$FPS = !fps!\n\n[Preset]\nname = 100" --logFile !logFileV3!
        
         
        
    goto:eof
    REM : ------------------------------------------------------------------
    
    :finalizeV3CapGP

        @echo [Control] >> !rulesFileV3!
        @echo vsyncFrequency = $FPS >> !rulesFileV3!
        
        REM : force UTF8 format
        set "utf8=!rulesFileV3:rules.txt=rules.tmp!"
        copy /Y !rulesFileV3! !utf8! > NUL
        type !utf8! > !rulesFileV3!
        del /F !utf8! > NUL
        
    goto:eof
    REM : ------------------------------------------------------------------
        
    :createCapV2GP

        set "syncValue=%~1"
        set "description=%~2"
        
        set "bfwgpv2="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
        if not exist !bfwgpv2! goto:eof
        set "gp="!bfwgpv2:"=!\_BatchFW_%description: =_%""

        if exist !gp! (
            @echo ^^! !gp! already exist, skipped ^^!
            goto:eof
        )
        if not exist !gp! mkdir !gp! > NUL

        set "rulesFileV2="!gp:"=!\rules.txt""

        @echo [Definition] > !rulesFileV2!
        @echo titleIds = !titleIdList! >> !rulesFileV2!

        @echo name = "%description:"=%" >> !rulesFileV2!
        @echo version = 2 >> !rulesFileV2!
        @echo # >> !rulesFileV2!

        @echo # Cap FPS to %syncValue% >> !rulesFileV2!
        @echo [Control] >> !rulesFileV2!

        @echo vsyncFrequency = %syncValue% >> !rulesFileV2!

        REM : force UTF8 format
        set "utf8=!rulesFileV2:rules.txt=rules.tmp!"
        copy /Y !rulesFileV2! !utf8! > NUL
        type !utf8! > !rulesFileV2!
        del /F !utf8! > NUL

    goto:eof
    REM : ------------------------------------------------------------------

    :createCapGP

        REM : initialized for 60FPS games running @60FPS on WiiU
        set /A "factor=1"
        REM : 30FPS game detected flag
        set /A "g30=0"

        REM : for 30FPS games running @60FPS on WiiU
        if ["%nativeFps%"] == ["30"] (

            set /A "g30=1"

            REM : double the value used as nativeFps
            set /A "nativeFps=%nativeFps%*2"

            REM : graphic pack created by BatchFw : gameName=NONE no FPS++
            if [!gameName!] == ["NONE"] goto:create            

            REM : search V3 FPS++ graphic pack or patch for this game
            set "pat="!BFW_GP_FOLDER:"=!\!GAME_TITLE!*FPS++*""
            REM : graphic pack created by BatchFw : gameName=NONE
            for /F "delims=" %%d in ('dir /B !pat! 2^>NUL') do (
                set /A "fpsPPV3=1"
                set /A "fpsPP=1"
            )

            :checkV2FPSpp
            REM : search V2 FPS++ graphic pack or patch for this game
            set "bfwgpv2="!BFW_GP_FOLDER:"=!\_graphicPacksV2""
            if not exist !bfwgpv2! goto::checkV3FPSpp
        
            set "pat="!bfwgpv2:"=!\!GAME_TITLE!*FPS++*""            
            for /F "delims=" %%d in ('dir /B !pat! 2^>NUL') do (
                set /A "fpsPP=1"
                goto:create
            )
            REM : else = 30 FPS native games without FPS++ : double vsyncValue to cap at target FPS
            set /A "factor=2"            
        )

        
        :create
       if %fpsPP% EQU 1 goto:capMenu

        if %g30% EQU 1 goto:cap110
        REM : cap to 105%
        call:mulfloat "%nativeFps%.00" "1.04" 2 fps
        set /A "targetFps=%fps%/%factor%"
        call:createCapV2GP %fps% "!GAME_TITLE!_%targetFps%FPS_cap"
        if %fpsPPV3% EQU 0 call:fillCapV3GP "105" "Speed (%targetFps%FPS)"

        :cap110
        REM : cap to 110%
        call:mulfloat "%nativeFps%.00" "1.09" 2 fps
        set /A "targetFps=%fps%/%factor%"
        call:createCapV2GP %fps% "!GAME_TITLE!_%targetFps%FPS_cap"
        if %fpsPPV3% EQU 0 call:fillCapV3GP "110" "Speed (%targetFps%FPS)"
        REM : cap to 120%
        call:mulfloat "%nativeFps%.00" "1.19" 2 fps
        set /A "targetFps=%fps%/%factor%"
        call:createCapV2GP %fps% "!GAME_TITLE!_%targetFps%FPS_cap"
        if %fpsPPV3% EQU 0 call:fillCapV3GP "120" "Speed (%targetFps%FPS)"
        :capMenu
        if %g30% EQU 0 goto:done
        REM : cap to 150%
        call:mulfloat "%nativeFps%.00" "1.49" 2 fps
        set /A "targetFps=%fps%/%factor%"
        call:createCapV2GP %fps% "!GAME_TITLE!_%targetFps%FPS_cap"
        if %fpsPPV3% EQU 0 call:fillCapV3GP "150" "Speed (%targetFps%FPS)"
        if %g30% EQU 1 if %fpsPP% EQU 0 goto:done

        REM : cap to 200%
        call:mulfloat "%nativeFps%.00" "1.99" 2 fps
        set /A "targetFps=%fps%/%factor%"
        call:createCapV2GP %fps% "!GAME_TITLE!_%targetFps%FPS_cap"
        if %fpsPPV3% EQU 0 call:fillCapV3GP "200" "Speed (%targetFps%FPS)"

        :done
        @echo FPS cap graphic packs created ^^!
    goto:eof
    REM : ------------------------------------------------------------------

    :create



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

        if x%halfId:ffffffff=%==x%halfId% goto:eof
        if x%halfId:FFFFFFFF=%==x%halfId% goto:eof

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
        if [!folderSelected!] == ["NONE"] call:runPsCmd %1 %2
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


