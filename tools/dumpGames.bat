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
        echo ERROR^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
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
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHiddenCmdWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenCmdWait.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    
    REM : set current char codeset
    call:setCharSet

    REM : create folders 
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\onlineFiles""

    cls

    @echo =========================================================
    @echo Dump installed games from your Wii-U
    @echo =========================================================
    @echo.
    @echo On your Wii-U^, you need to ^:
    @echo - disable the sleeping/shutdown features
    @echo - if you^'re using a permanent hack ^(CBHC^)^:
    @echo    ^* launch HomeBrewLauncher
    @echo    ^* then ftp-everywhere for CBHC
    @echo - if you're not^: 
    @echo    ^* first run Mocha CFW HomeBrewLauncher
    @echo    ^* then ftp-everywhere for MOCHA
    @echo.
    @echo - get the IP adress displayed on Wii-U gamepad
    @echo.
    @echo Press any key to continue when you^'re ready
    @echo ^(CTRL-C^) to abort    
    pause
    
    set /P "wiiuIp=Please enter your Wii-U local IP adress : ""
    
    REM : winScp FTP configuration
    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    
    REM : prepare winScp.ini file
    copy /Y  !winScpIniTmpl! !winScpIni! > NUL
    REM : set WiiU ip adress
    !StartHidenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "USER@FTPiiU-IP" --replace "USER@!wiiuIp!"
    REM  : set LocalDirectory
    !StartHidenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "LocalDirectory=!GAMES_FOLDER:\=%%5C!" --replace
    
    REM -------------------------------------------------------------------------------------------------
    REM : Import saves, games, updates and DLC from your Wii-U
    REM -------------------------------------------------------------------------------------------------
    
    :checkConnection
    
    !StartHiddenCmdWait! !WinScp! /session "USER@!wiiuIp!" /command "ls /storage_mlc/usr/save/system/act" "exit"
    if !ERRORLEVEL! NEQ 0 (
        ping !wiiuIp! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo ERROR ^: unable to ping !wiiuIp!^, check if FTP server is running on the WII-U
        ) else (            
            @echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before FTP_every_where on the Wii-U           
        )
        @echo Pause this script until you fix it ^(CTRL-C to abort^)
        goto:checkConnection
    )    

    REM : scans folder 
    set /A "noOldScan=0"
    :scanMyWii
    set "BFW_WIIUSCAN_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU\Scans""
    if not exist !BFW_WIIUSCAN_FOLDER! (
        mkdir !BFW_WIIUSCAN_FOLDER! > NUL
        set "scanNow="!BFW_TOOLS_PATH:"=!\scanWiiU.bat""
        call !scanNow!
        set /A "noOldScan=1"
    )
        
    set "LAST_SCAN="NOT_FOUND""
    for /F %%i in ('dir /B /A:D /O:N !BFW_WIIUSCAN_FOLDER!') do set "LAST_SCAN="%%i""  
    
    if [!LAST_SCAN!] == ["NOT_FOUND"] (
        @echo ERROR^: last scan results were not found
        pause
        exit 90
    )
    cls    
    if !noOldScan! EQU 1 goto:getLocalTitleId

    @echo Last Scan found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getLocalTitleId
    
    rmdir /Q /S !BFW_WIIUSCAN_FOLDER!
    goto:scanMyWii
    
    REM : get the list of titleId of your installed games    
    :getLocalTitleId

    REM create a log file containing all your games titleId
    set "localTid="!LAST_SCAN:"=!\localTitleIds.log""    
    if exist !localTid! del /F !localTid!
    
    pushd !GAMES_FOLDER!
    REM : searching for meta file
    for /F "delims=" %%i in ('dir /B /S meta.xml ^|  find /I /V "\mlc01" 2^> NUL') do (

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        for /F "delims=<" %%i in (!titleLine!) do set /A "NB_GAMES+=1" && echo %%i >> !localTid!
    )                
   
    REM : get title;endTitleId;source;dataFound from scan results
    set "wholeGamesList="!LAST_SCAN:"=!\wholeGamesList.log""
    set /A "nbGames=0"

    for /F "delims=~; tokens=1-4" %%i in ('type !wholeGamesList! | find /V "title"') do (
        
        set "titles[!nbGames!]=%%i"            
        set "endTitlesId[!nbGames!]=%%j"
        set "titlesSrc[!nbGames!]=%%k"
        
        set /A "nbGames+=1"
    )
    
    REM : selected games
    set /A "nbGamesSelected=0"
    
    REM : loop on the games installed on you Wii-U (NAND and USB)
    for /L %%i (1, 1, !nbGames!) do (
        set /A "ind1=%%i"
        set /A "ind0=!ind1!-1"
        type !localTid! | find "!endTitlesId[%ind0%]!" > NUL call:selectGame %ind0%

    if !nbGamesSelected! EQU 0 (
        echo WARNING : no games selected ^?
        pause
        exit 11
    )

    REM : get BatchFw users list
    set "USERSLIST="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSLIST=%%i !USERSLIST!"
        set /A "nbUsers+=1"
    )
    
    REM : get current date
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    echo Starting FTP transfert at %DATE%
    
    REM : loop on the games selected
    for /L %%i (1, 1, !nbGames!) do (
    
        set "name=!selectedTitles[%%i]!"
        
        @echo -------------------------------------------------------------------------------------------------        
        @echo Importing !name!^.^.^.
        
        REM : create local folders
        set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!name!""
        call:createLocalFolders %%i
        
        REM : dump the game by FTP
        call:getGame !selectedtitlesSrc[%%i]! !selectedEndTitlesId[%%i]!

    )
    @echo All transferts ended^, done    

REM Export : injectWiiuDownloadedGames : 

REM Inject game in executable format will work only for
REM games that you have downloaded or installed using WUP
REM installer previously on your Wii-U^. Dump from digital
REM copy ^(disk^) will not work ^!

REM - browse to GAME_FOLDER_PATH
REM - get the total size of the games (including BatchFw extra files to be sure-> +100Mo)
REM - ask for target 'usb or mlc'
REM - ask user to manually check if enough space is available 
REM - same script but exit if not exist storage_%src%/usr/title/00050000/%endTitleId% 

REM !winScp! synchronize remote "!GAME_FOLDER_PATH:"=!\code" storage_%src%/usr/title/00050000/%endTitleId%/code
REM !winScp! synchronize remote "!GAME_FOLDER_PATH:"=!\content" storage_%src%/usr/title/00050000/%endTitleId%/content  
REM !winScp! synchronize remote "!GAME_FOLDER_PATH:"=!\meta" storage_%src%/usr/title/00050000/%endTitleId%/meta

REM !winScp! synchronize remote !TMP_DLSAVE_PATH! storage_%src%/usr/title/00050000/%endTitleId%

REM not exiting but synchronize ?
    
REM Create import Wii-U saves    

REM Create export CEMU saves (need to know which 8000000X correspond to which BatchFw user)  
    

    
    
    
    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions
    
    
REM : ------------------------------------------------------------------
    :selectGame
        set /A "num=%~1"
    
        choice /C yn /N /M "Do you want to dump !titles[%num%]! (titleId = 0050000!endTitlesId[%num%]!) (y, n)? : "
        if !ERRORLEVEL! EQU 1 (

            set "selected[!nbGamesSelected!]=!endTitlesId[%num%]!"
            set "name=!titles[%num%]!"
            choice /C yn /N /M "Do you want to rename !titles[%num%]! (y, n)? :" 
            if !ERRORLEVEL! EQU 1  set /P "name=Enter new name :"
            set "selectedTitles[!nbGamesSelected!]=!name!"
            set "selectedEndTitlesId[!nbGamesSelected!]=!endTitlesId[%num%]!"
            set "selectedtitlesSrc[!nbGamesSelected!]=!titlesSrc[%num%]!"

            set /A "nbGamesSelected+=1"
        )    
    goto:eof
REM : ------------------------------------------------------------------
   
    
    

REM : ------------------------------------------------------------------
    :getGame
        REM : source (mlc or usb)
        set "src=%~1"
        
        REM : end part of the title Id
        set "endTitleId=%~2"
        
        REM : Import the game (minimized + no wait)
        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        !StartHiddenCmd! !WinScp! /session "USER@!wiiuIp!" /command  "synchronize local "!codeFolder!" /storage_%src%/usr/title/00050000/%endTitleId%/code" "exit" 
        set "contentFolder="!GAME_FOLDER_PATH:"=!\content""
        !StartHiddenCmd! !WinScp! /session "USER@!wiiuIp!" /command  "synchronize local "!contentFolder!" /storage_%src%/usr/title/00050000/%endTitleId%/content" "exit" 
        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        !StartHiddenCmd! !WinScp! /session "USER@!wiiuIp!" /command  "synchronize local "!metaFolder!" /storage_%src%/usr/title/00050000/%endTitleId%/meta" "exit" 
        
        REM : search if this game has an update
        type !remoteUpdates:SRC=%src%! | find %titleId%
        
        REM : YES : import update in mlc01/usr/title (minimized + no wait)
        set "updateFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0050000\%endTitleId%""
        !StartHiddenCmd! !WinScp! /session "USER@!wiiuIp!" /command  "synchronize local "!updateFolder!" /storage_%src%/usr/title/0005000E/%endTitleId%" "exit"   
        
        REM : search if this game has a DLC
        type !remoteDlc:SRC=%src%! | find %titleId%
        
        REM : YES : import dlc in mlc01/usr/title/0050000/%endTitleId%/aoc (minimized + no wait)
        set "dlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0050000\%endTitleId%\aoc""
        !StartHiddenCmd! !WinScp! /session "USER@!wiiuIp!" /command "synchronize local "!dlcFolder!" /storage_%src%/usr/title/0005000C/%endTitleId%" "exit" 
        
        REM : search if this game has saves
        type !remoteSaves:SRC=%src%! | find /V %titleId% > NUL && goto:waitTransfertEnd        
        
        choice /C yn /N /M "Saves were found, do you want to import them (y, n)? : "
        if !ERRORLEVEL! EQU 2  goto:waitTransfertEnd
        
        REM : Get all the content in a temporary folder (minimized + wait)
        set "TMP_DLSAVE_PATH="!LAST_SCAN:"=!\SavesImported""
        !StartHiddenCmd! !WinScp! /session "USER@!wiiuIp!" /command "synchronize local "!TMP_DLSAVE_PATH!" /storage_%src%/usr/title/00050000/%endTitleId%" "exit" 
        
        call:importSaves 
        
        REM : wait until all transferts finish
        @echo Waiting for all transfert end^.^.^.

        REM : wait all transfert end
        :waitingLoop
        timeout /T 1 > NUL
        for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "winScp.com" ^| find /I /V "find"') do (
            goto:waitingLoop
        )
        
    goto:eof
REM : ------------------------------------------------------------------

    
    
REM : ------------------------------------------------------------------
    :createLocalFolders
        set /A "num=%~1"
    
        set "CODE_PATH="!GAME_FOLDER_PATH:"=!\code""
        mkdir !CODE_PATH!
        set "CONTENT_PATH="!GAME_FOLDER_PATH:"=!\content""
        mkdir !CONTENT_PATH!
        set "META_PATH="!GAME_FOLDER_PATH:"=!\meta""
        mkdir !META_PATH!
        
        set "SAVES_ARCHIVES_PATH="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
        mkdir !SAVES_ARCHIVES_PATH!
        
        set "SAVES_PATH="!GAME_FOLDER_PATH:"=!\mlc01\usr\0050000\!selectedEndTitlesId[%num%]!""
        mkdir !SAVES_PATH!
        
        set "DLC_PATH="!GAME_FOLDER_PATH:"=!\mlc01\title\0050000\!selectedEndTitlesId[%num%]!\aoc""
        mkdir !DLC_PATH!
    goto:eof    
    
REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
    :importSaves
    
        REM : loop on all 8000000X folders found
        pushd !TMP_DLSAVE_PATH!
        
        if ["!USERSLIST!"] == [""] (
            @echo no users detected^, creating saves for !USERNAME!
            set "USERSLIST=!USERNAME!"
        )
        
        @echo List of BatchFw^'s users ^: !USERSLIST!
        @echo.
        
        
        @echo Wii-U create 800000XX folders in order of creation 
        @echo This script will associate BatchFw^'s user to a wii-U account
        @echo.
        
REM : TODO see if 800000X in /storage_mlc/usr/save/system/act is reuse to name 800000Y in game's folder 
REM : if it's right => no need of BatchFw's user list : use "BFW_ONLINE_FOLDER:"=!\usersAccounts\!user!_%%d_%accId%.dat
REM : to get %%d = 800000X

REM : if it is right => take this into account in import/export Saves scripts

REM : JD2018 => Sarah => 8000002 ? à priori 8000001 => Fabrice

        
        for /F "delims=" %%p in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxp"
        
        for /F %%d in ('dir 800000*') do ( 
            
            REM : Ask for which Batch's user it is to be used
            @echo Please enter the name of the batchFw^'s user that use 
            @echo the folder %%d on the Wii-U ^? 
            set /P "user=BatchFw^'s user name ^: "
            
            REM : backup 80000001 if needed and rename 8000000X to 80000001
            if [ "%%d" NEQ "80000001" ] (
                move 80000001 80000001_backup
                move %%d 80000001
            )
            REM : compress the folder (with extra files ant the same level????) in GAME_FOLDER_PATH\Cemu\inGameSave    
            set "rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!user!.rar""
            
            set "folder="!TMP_DLSAVE_PATH:"=!\80000001""
            !rarExe! a -ed -ap"mlc01\usr\save\0050000\%endTitleId%" -ep1 -r -inul !rarFile! !folder! > NUL    
    
            if [ "%%d" NEQ "80000001" ] (
                move 80000001 %%d
                move 80000001_backup 80000001 
            )
        )
        
    goto:eof    
    
REM : ------------------------------------------------------------------

    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13>> !batchFwLog!
            @echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11>> !batchFwLog!
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12>> !batchFwLog!
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
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
            @echo Host char codeSet not found ^?^, exiting 1>> !batchFwLog!
            @echo Host char codeSet not found ^?^, exiting 1
            timeout /t 8 > NUL
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic path Win32_OperatingSystem get Locale /value ^| find "="') do set "L0CALE_CODE=%%f"

    goto:eof
    REM : ------------------------------------------------------------------
