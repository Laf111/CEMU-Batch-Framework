@echo off
setlocal EnableExtensions
title Import Wii-U saves
REM : ------------------------------------------------------------------
REM : When called with args, this script treat ONLY ONE game at the time
REM : When called without, it use the last Wii-U scan and treat only ALL
REM : games that exist in local AND remote locations

REM : main

    setlocal EnableDelayedExpansion
    color 4F

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
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""

    set "syncFolder="!BFW_TOOLS_PATH:"=!\ftpSyncFolders.bat""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

    set "setExtraSavesSlots="!BFW_TOOLS_PATH:"=!\setExtraSavesSlots.bat""
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )
    
    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : J2000 unix timestamp (/ J1970)
    set /A "j2000=946684800"

    REM : by default
    set "wiiuSaveMode=SYNCR"
    REM : read the configuration parameters for Wii-U saves (SYNCR/BOTH)
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "WII-U_SAVE_MODE=" 2^>NUL') do set "wiiuSaveMode=%%i"
    
    if %nbArgs% NEQ 0 goto:getArgsValue

    title Import CEMU saves from WiiU

    echo =========================================================
    echo Import Wii-U saves to CEMU
    echo =========================================================
    echo.

    if ["!wiiuSaveMode!"] == ["SYNCR"] (
        echo You choose to synchronize CEMU and Wii-U saves^.
    ) else (
        echo You choose to keep both saves ^(CEMU and Wii-U saves^)^.
    )
     choice /C yn /N /M "Do you want to change it? (y/n): "
    if !ERRORLEVEL! EQU 2 goto:saveModeOK

    set "wiiuSaveMode=BOTH"
    choice /C yn /N /M "Synchronize your saves between CEMU and your Wii-U? (y/n): "
    if !ERRORLEVEL! EQU 1 set "wiiuSaveMode=SYNCR"

    set "msg="WII-U_SAVE_MODE=!wiiuSaveMode!""
    call:log2HostFile !msg!

    :saveModeOK
    echo.
    echo On your Wii-U^, you need to ^:
    echo - disable the sleeping^/shutdown features
    echo - launch WiiU FTP Server and press B to mount NAND paths
    echo - get the IP adress displayed on Wii-U gamepad
    echo.
    echo Press any key to continue when you^'re ready
    echo ^(CTRL-C^) to abort
    pause
    cls

    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    if not exist !winScpIni! goto:getWiiuIp

    REM : get the hostname
    set "ipRead="
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    if ["!ipRead!"] == [""] goto:getWiiuIp
    REM : and the port
    set "portRead="
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"
    if ["!portRead!"] == [""] goto:getWiiuIp

    echo Found an existing FTP configuration ^:
    echo.
    echo PortNumber=!ipRead!
    echo HostName=!portRead!
    echo.
    choice /C yn /N /M "Use this setup (y, n)? : "
    if !ERRORLEVEL! EQU 1 set "wiiuIp=!ipRead!" && goto:checkConnection

    :getWiiuIp
    set /P "wiiuIp=Please enter your Wii-U local IP adress : "
    set /P "port=Please enter the port used : "

    REM : prepare winScp.ini file
    copy /Y  !winScpIniTmpl! !winScpIni! > NUL 2>&1
    set "fnrLog="!BFW_PATH:"=!\logs\fnr_WinScp.log""

    REM : set WiiU ip adress
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-IP" --replace "!wiiuIp!" --logFile !fnrLog!
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-port" --replace "!port!" --logFile !fnrLog!

    :checkConnection
    REM : check its state
    set /A "state=0"
    call:getHostState !wiiuIp! state

    if !state! EQU 0 (
        echo ERROR^: !wiiuIp! was not found on your network ^!
        pause
        exit 2
    )

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck_iws.log""
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=8 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Connection failed" > NUL 2>&1 && (
        echo ERROR ^: unable to connect^, check that your Wii-U is powered on and that
        echo WiiuFtpServer was launched with mounting NAND paths ^(press B^)
        echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before WiiuFtpServer on the Wii-U
        echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    cls
    
    REM : scans folder
    set /A "noOldScan=0"
    :scanMyWii
    set "BFW_WIIUSCAN_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU\Scans""
    if not exist !BFW_WIIUSCAN_FOLDER! (
        mkdir !BFW_WIIUSCAN_FOLDER! > NUL 2>&1
        set "scanNow="!BFW_TOOLS_PATH:"=!\scanWiiU.bat""
        call !scanNow! !wiiuIp!
        set /A "noOldScan=1"
    )

    set "LAST_SCAN="NOT_FOUND""
    for /F "delims=~" %%i in ('dir /B /A:D /O:N !BFW_WIIUSCAN_FOLDER! 2^>NUL') do set "LAST_SCAN="%%i""

    if [!LAST_SCAN!] == ["NOT_FOUND"] (
        set "scanNow="!BFW_TOOLS_PATH:"=!\scanWiiU.bat""
        call !scanNow! !wiiuIp!
        set /A "noOldScan=1"
        goto:scanMyWii
    )
    cls
    if !noOldScan! EQU 1 goto:getLocalTitleId

    echo The last WiiU^'s scan found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getLocalTitleId

    rmdir /Q /S !BFW_WIIUSCAN_FOLDER! > NUL 2>&1
    goto:scanMyWii

    REM : get the list of titleId of your installed games
    :getLocalTitleId

    REM create a log file containing all your games titleId
    set "localTid="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\localTitleIds.log""
    if exist !localTid! del /F !localTid!

    pushd !GAMES_FOLDER!
    REM : searching for meta file
    for /F "delims=~" %%i in ('dir /B /S meta.xml 2^>NUL ^|  find /I /V "\mlc01"') do (

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        for /F "delims=<" %%i in (!titleLine!) do set /A "NB_GAMES+=1" && echo %%i >> !localTid!
    )

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "gamesList="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\gamesList.csv""

    set /A "nbGames=0"

    cls
    echo =========================================================

    set "completeList="
    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "title"') do (

        set "second=%%j"
        set "endTitleId=!second:'=!"

        REM : if the game is also installed on your PC
        type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (
            set "titles[!nbGames!]=%%i"
            set "endTitlesId[!nbGames!]=!endTitleId!"
            set "titlesSrc[!nbGames!]=%%k"
            echo !nbGames!	: %%i

            set "completeList=!nbGames! !completeList!"
            set /A "nbGames+=1"
        )
    )

    echo =========================================================

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

     set /P "listGamesSelected=Please enter game's numbers list (separated with a space) or 'all' to treat all games : "
    :displayList

    if not ["!listGamesSelected!"] == ["all"] (

        if not ["!listGamesSelected!"] == [""] (
            echo !listGamesSelected! | findStr /R /V /C:"^[0-9 ]*$" > NUL 2>&1 && echo ERROR^: not a list of integers && pause && goto:getList

            echo =========================================================
            for %%l in (!listGamesSelected!) do (
                echo %%l | findStr /R /V "[0-9]" > NUL 2>&1 && echo ERROR^: %%l not in the list && pause && goto:getList
                set /A "number=%%l"
                if !number! GEQ !nbGames! echo ERROR^: !number! not in the list & pause & goto:getList

                echo - !titles[%%l]!
                set "selectedTitles[!nbGamesSelected!]=!titles[%%l]!"
                set "selectedEndTitlesId[!nbGamesSelected!]=!endTitlesId[%%l]!"
                set "selectedtitlesSrc[!nbGamesSelected!]=!titlesSrc[%%l]!"

                set /A "nbGamesSelected+=1"
            )
        ) else (
            goto:getList
        )
    ) else (
        set "listGamesSelected=!completeList!"
        goto:displayList
    )
        echo =========================================================
    echo.
    choice /C ync /N /M "Continue (y, n) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit /b 98
    if !ERRORLEVEL! EQU 2 goto:getList

    cls
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit 11
    )
    set /A "nbGamesSelected-=1"

    pushd !GAMES_FOLDER!
    REM : use the endTitleId to get GAME_FOLDER_PATH and mostly the GAME_TITLE used for naming rar file !
    REM : update titles[0-!nbGames!]

    REM : Loop on the game selected
    for /L %%i in (0,1,!nbGamesSelected!) do (
    REM : get the endTitleId
        set "endTitleId=!selectedEndTitlesId[%%i]!"

        call:updateTitle %%i
    )

    set "userSavesToImport="select""

    REM : get BatchFw users list
    set "USERSARRAY="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSARRAY[!nbUsers!]=%%i"
        set /A "nbUsers+=1"
    )

    REM : ask for saves import mode
    call:getSavesUserMode userSavesToImport
    
    goto:treatments

    :getArgsValue
    if %nbArgs% NEQ 5 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" WIIU_IP_ADRESS GAME_TITLE endTitleId src userSavesToImport
        echo given {%*}
        pause
        if %nbArgs% EQU 0 exit 9
        if %nbArgs% NEQ 0 exit /b 9
    )
    REM WII-U IO ADRESS (wll be check in syncFolder.bat
    set "wiiuIp=!args[0]!"

    REM : get GAME_TITLE
    set "GAME_TITLE=!args[1]!"
    set "GAME_TITLE=!GAME_TITLE:"=!"

    REM : get endTitleId
    set "endTitleId=!args[2]!"
    set "endTitleId=!endTitleId:"=!"

    REM : get and check src
    set "src=!args[3]!"
    set "src=!src:"=!"
    if not ["!src!"] == ["mlc"] if not ["!src!"] == ["usb"] (
        echo ERROR^: !src! is not a valid storage source ^!
        if %nbArgs% EQU 0 exit 3
        if %nbArgs% NEQ 0 exit /b 3
    )
    REM : user to import saves during a game's dump.
    REM : values
    REM : - select => choose manually (value initialized when there is no args given)
    REM : - all => import all existing saves for all users
    REM : - !user! => import all existing saves for !user!
    set "userSavesToImport=!args[4]!"

    set "selectedTitles[0]=!GAME_TITLE!"
    set "selectedEndTitlesId[0]=!endTitleId!"
    set "selectedtitlesSrc[0]=!src!"
    REM : array start from 0
    set /A "nbGamesSelected=0"

    :treatments
    cls

    REM : online files folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""

    set "USERS_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
    if not exist !USERS_ACCOUNTS_FOLDER! (
        echo ERROR^: !USERS_ACCOUNTS_FOLDER! does not exist ^!
        echo Use Wii-U Games^\Wii-U^\Get online files^.lnk
        echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
        echo before this script
        pause
        if %nbArgs% EQU 0 exit 99
        if %nbArgs% NEQ 0 exit /b 99

    )

    for /L %%n in (0,1,!nbGamesSelected!) do call:importSaves %%n
    echo =========================================================
    if %nbArgs% EQU 0 pause

    if !ERRORLEVEL! NEQ 0 (
        if %nbArgs% NEQ 0 exit /b !ERRORLEVEL!
        exit /b !ERRORLEVEL!
    )
    if %nbArgs% NEQ 0 exit /b 0
    exit 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    :getSavesUserMode
        REM : init to none (choice number 1)
        set "%1=none"

        echo.
        echo Please select an import mode for Wii-U saves ^:
        echo.

        :getChoice
        echo    1 ^: do not import saves for all games and users
        echo    2 ^: import all saves for all BatchFw^'s user
        echo    3 ^: import all saves only for a given BatchFw^'s user
        echo    4 ^: select what to do ^(per game and per user^)
        echo        ^(will interrupt the downloading process^)
        echo.
        choice /C 12345 /N /M "Please, enter your choice : "
        set "userChoice=!ERRORLEVEL!"

        choice /C yn /N /M "Confirm choice !userChoice!? (y/n to cancel) : "
        if !ERRORLEVEL! EQU 2 goto:getChoice

        REM : handling choice
        if !userChoice! EQU 1 goto:eof

        if !userChoice! EQU 2 set "%1=all" & goto:eof

        if !userChoice! EQU 3 (
            echo.
            set /A "nbUserm1=nbUsers-1"
            for /L %%i in (0,1,!nbUserm1!) do echo %%i ^: !USERSARRAY[%%i]!

            echo.
            :askUser
            set /P "num=Enter the BatchFw user's number [0, !nbUserm1!] : "

            echo %num% | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askUser

            if %num% LSS 0 goto:askUser
            if %num% GEQ %nbUsers% goto:askUser

            set "%1=!USERSARRAY[%num%]!"
            goto:eof
        )

        set "%1=select"

    goto:eof
    REM : ------------------------------------------------------------------


    :hex2Dec
        set "hex=%~1"

        set /A "%2=0x%hex%"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : get a node value in a xml file
    REM : !WARNING! current directory must be !BFW_RESOURCES_PATH!
    :getValueInXml

        set "xPath="%~1""
        set "xmlFile="%~2""
        set "%3=NOT_FOUND"

        REM : return the first match
        for /F "delims=~" %%x in ('xml.exe sel -t -c !xPath! !xmlFile! 2^>NUL') do (
            set "%3=%%x"

            goto:eof
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :updateGameStatsInLastSettings

        REM : get the last_played from Wii-U
        call:getValueInXml "//account[@persistentId='!folder!']/timestamp/text()" !saveInfo! wtsj2kHex
        if ["!wtsj2kHex!"] == ["NOT_FOUND"] goto:eof

        REM : compute Wii-U last_played in J1970

        REM : wtsj2kHex -> wtsj2k
        call:hex2Dec !wtsj2kHex! wtsj2k
        REM : wtsj1970=wtsj2k-J2000
        set /A "wtsj1970=wtsj2k+j2000"

        REM : save the time played relative to 1970 for the account in a wiiuStatsFile
        echo !folder! 1970 timestamp=!wtsj1970! >> !wiiuStatsFile!

        REM : check if exist a last settings exist for !currentUser!
        set "lus="!GAME_FOLDER_PATH:"=!\Cemu\settings\!currentUser!_lastSettings.txt""
        if not exist !lus! goto:eof

        REM : get the last modified settings for the current user
        for /F "delims=~" %%i in ('type !lus!') do set "ls=%%i"
        set "lst="!GAME_FOLDER_PATH:"=!\Cemu\settings\!ls:"=!""
        REM : if not exist !lst! do not create it : exit
        REM : import have to be handled in launchGame.bat / wizardFirstLaunch.bat or updateGameStats.bat
        if not exist !lst! goto:eof

        REM : get last_played with RPX path from CEMU settings
        call:getValueInXml "//GameCache/Entry[path='!RPX_FILE:"=!']/last_played/text()" !lst! ctsj1970
        if ["!ctsj1970!"] == ["NOT_FOUND"] goto:eof

        REM :if ctsj1970 > wtsj1970 nothing to do
        REM :if ctsj1970 < wtsj1970
        if !ctsj1970! LSS !wtsj1970! (
            REM : update last settings.xml saved for !currentUser!

            REM : CEMU time_played=wtsj1970-ctsj1970
            set /A "tp=wtsj1970-ctsj1970"
            set "ltmp=!lst!0"
            xml ed -u "//GameCache/Entry[path='!RPX_FILE:"=!']/time_played" -v "!tp!" !lst! > !ltmp!
            xml ed -u "//GameCache/Entry[path='!RPX_FILE:"=!']/last_played" -v "!wtsj1970!" !ltmp! > !lst!
            if !ERRORLEVEL! EQU 0 del /F !lst! > NUL 2>&1 & move /Y !ltmp! !lst!
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :updateTitle

        set "num=%~1"

        REM : searching for meta file
        for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

            REM : meta.xml
            set "META_FILE="%%i""

            type !META_FILE! | find /I "!endTitleId!" > NUL 2>&1 && (

                for %%a in (!META_FILE!) do set "parentFolder="%%~dpa""
                set "str=!parentFolder:~0,-2!""
                for %%a in (!str!) do set "parentFolder="%%~dpa""
                set "GAME_FOLDER_PATH=!parentFolder:~0,-2!""

                REM : update titles[%num%] with folder's name (GAME_TITLE)
                for /F "delims=~" %%a in (!GAME_FOLDER_PATH!) do set "selectedTitles[%num%]=%%~nxa"
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :importSaves
        set /A "num=%~1"

        REM : set GAME_TITLE (used for naming user's rar file)
        set "GAME_TITLE=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        timeout /T 4 > NUL 2>&1
        cls
        echo =========================================================
        echo Import saves for !GAME_TITLE! ^(%endTitleId%^)
        echo Source location ^: ^/storage_!src!
        echo =========================================================

        REM : (re) compute GAME_FOLDER_PATH (in function of the presence of args or not)
        set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!GAME_TITLE!""

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
        set "DATE=%ldt%"

        REM : temporary folder where recreated the Wii-U save
        set "TMP_DLSAVE_PATH="!GAMES_FOLDER:"=!\_BatchFw_WiiU\ImportSave""
        if not exist !TMP_DLSAVE_PATH! mkdir !TMP_DLSAVE_PATH! > NUL 2>&1

        set "gslog="!TMP_DLSAVE_PATH:"=!\ImportSaveFromWii-U_!GAME_TITLE!.log""

        set "localFolder="!TMP_DLSAVE_PATH:"=!\mlc01\usr\save\00050000\!endTitleId!""
        set "localFolderMeta="!localFolder:"=!\meta""
        set "saveinfo="!localFolderMeta:"=!\saveinfo.xml""
        REM : save the time played relative to 1970 in a wiiuStatsFile
        set "wiiuStatsFile="!TMP_DLSAVE_PATH:"!\mlc01\usr\save\00050000\!endTitleId!.stats""
        if exist !wiiuStatsFile! del /F /S !wiiuStatsFile!
        
        REM : launching transfert
        call !syncFolder! !wiiuIp! local !localFolder! "/storage_!src!/usr/save/00050000/!endTitleId!" "!GAME_TITLE! (saves)"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            echo ERROR when downloading existing saves ^!
            pause
            exit /b 50
        )

        echo Synchronize last imported saves for !GAME_TITLE! ^(%endTitleId%^) before choosing to import
        echo ---------------------------------------------------------
        
        set "localFolderUser="!localFolder:"=!\user""
        if not exist !localFolderUser! (
            echo WARNING ^: no saves found for !GAME_TITLE!
            goto:eof
        )        
        REM : creates saves for each users
        call:createUsersSaves

        echo ---------------------------------------------------------

        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------

    REM : get the last modified save file (including slots if defined)
    :getLastModifiedSaveFile

        set "saveFile="NONE""

        REM : patern
        set "pat="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!*.rar""

        REM : reverse loop => last elt is the last modified
        for /F "delims=~" %%g in ('dir /S /B /O:-D /T:W !pat! 2^>NUL') do set "saveFile="%%g""

        set "%1=!saveFile!"

    goto:eof
    REM : ------------------------------------------------------------------


    REM : search for Wii-U import slot or create one
    :getWiiUSlot
        set "%2="NONE""

        REM : check if slots are defined
        set "activeSlotFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_activeSlot.txt""
        if exist !activeSlotFile! (

            REM : search for last slots used with a label containing "Wii-U import"
            set "pat="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_slot*.txt""
            for /F "delims=~" %%i in ('dir /S /B /O:D !pat!') do (

                findstr /S /I "Wii-U import" "%%i" > NUL 2>&1 && (
                    REM : found the first slot used for Wii-U import
                    set "slotLabelFile="%%i""
                    set "slotFile=!slotLabelFile:.txt=.rar!"
                    if exist !slotFile! (
                        REM : activate it
                        attrib -R !activeSlotFile! > NUL 2>&1
                        echo !slotFile!>!activeSlotFile!
                        attrib +R !activeSlotFile! > NUL 2>&1

                        set "%2=!slotFile!"
                        goto:eof
                    )
                )

            )
        )
        REM : if not found, create a new extra slot and activate it
        call !setExtraSavesSlots! !currentUser! !GAME_FOLDER_PATH! "Wii-U import"
        REM : get the last modified save for currentUser
        set "lastSlot="NONE""
        call:getLastModifiedSaveFile lastSlot
        if exist !lastSlot! set "%2=!lastSlot!"

    goto:eof
    REM : ------------------------------------------------------------------


    :importSavesForCurrentUser

        REM : here userSavesToImport <> none

        set "inGameSaveFolder="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
        if not exist !inGameSaveFolder! mkdir !inGameSaveFolder! > NUL 2>&1

        REM : for the current user :
        set "rarFile="!inGameSaveFolder:"=!\!GAME_TITLE!_!currentUser!.rar""
    
        if not [!userSavesToImport!] == ["all"] (

            if [!userSavesToImport!] == ["select"] (
                choice /C yn /N /M "Import !currentUser! saves from Wii-U (y, n)? : "
                if !ERRORLEVEL! EQU 2 goto:eof

                REM : check if slots are defined
                set "activeSlotFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_activeSlot.txt""
                if exist !activeSlotFile! (

                    REM : Display / select active slot for this game and user
                    echo "Extra save slots were defined for this game by !currentUser! ^:

                    REM : display/create slos
                    call !setExtraSavesSlots! !currentUser! !GAME_FOLDER_PATH!

                    REM : enter the slot to use
                    :askSlot
                    set /P "answer=Please, enter the slot's number to use : "
                    echo !answer! | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askSlot
                    set /A "srcSlot=!answer!"

                    set "srcSlotFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_slot!srcSlot!.rar""
                    if exist !srcSlotFile! goto:slotFound
                    echo ERROR^: slot!srcSlot! does not exist^!
                    goto:askSlot

                    :slotFound
                    set "rarFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_slot!srcSlot!.rar""

                ) else (

                    REM : create a first extra slot save / overwrite the user save ?
                    choice /C yn /N /M "A save already exists for !currentUser!, create a new extra slot and activate it? (y, n) : "
                    if !ERRORLEVEL! EQU 1 (
                        REM : create a new extra slot and activate it
                        call !setExtraSavesSlots! !currentUser! !GAME_FOLDER_PATH! "Wii-U import"

                        REM : get the last modified save for currentUser
                        set "lastSlot="NONE""
                        call:getLastModifiedSaveFile lastSlot
                        if not [!lastSlot!] == ["NONE"]  set "rarFile=!lastSlot!"

                    ) else (
                        choice /C yn /N /M "Overwrite save for !currentUser! ? (y, n) : "
                        if !ERRORLEVEL! EQU 2 goto:eof

                        REM : backup the CEMU save
                        set "rarFileCemu="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!_Cemu_!DATE!.rar""
                        copy /Y !rarFile! !rarFileCemu! > NUL 2>&1
                    )
                )
                REM else rarFile unchanged
            ) else (
                REM : one user mode
                if not [!userSavesToImport!] == ["!currentUser!"] goto:eof
            )

            if [!wiiuSaveMode!] == ["BOTH"] (
                REM : get and activate OR create a slots for Wii-U save

                call:getWiiUSlot lastSlot
                if not [!lastSlot!] == ["NONE"]  set "rarFile=!lastSlot!"
            )

            REM : treatment for the user
            echo Importing !folder! save ^(!currentUser!^)

            REM : backup the CEMU save
            if exist !rarFile! (
                set "rarFileCemu="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!_Cemu_!DATE!.rar""
                copy /Y !rarFile! !rarFileCemu! > NUL 2>&1
                REM : copy OK : delete the user's save
                if !ERRORLEVEL! EQU 0  del /F !rarFile! > NUL 2>&1
            )

            cd !folder!
            REM : add the user's folder content, rename folder to 80000001 in the archive file
            wscript /nologo !StartHiddenWait! !rarExe! a -ed -ap"mlc01\usr\save\00050000\%endTitleId%\user\80000001" -ep1 -r -inul -w!BFW_LOGS! !rarFile! * > NUL 2>&1

            cd ..
            REM : common folder
            if exist common (
                cd common
                wscript /nologo !StartHiddenWait! !rarExe! a -ed -ap"mlc01\usr\save\00050000\%endTitleId%\user\common" -ep1 -r -inul -w!BFW_LOGS! !rarFile! * > NUL 2>&1
                cd ..
            )
            REM : cd to meta
            cd !localFolderMeta!

            REM : overwrite !saveInfo!
            echo ^<^?xml version=^"1^.0^" encoding=^"UTF-8^"^?^>^<info^>^<account persistentId=^"80000001^"^>^<timestamp^>0000000000000000^<^/timestamp^>^<^/account^>^<^/info^> > !saveInfo!

            REM : add the meta folder content
            wscript /nologo !StartHiddenWait! !rarExe! a -ed -ap"mlc01\usr\save\00050000\%endTitleId%\meta" -ep1 -r -inul -w!BFW_LOGS! !rarFile! * > NUL 2>&1

            echo !DATE! ^: !GAME_TITLE! WII-U saves imported for !currentUser! >> !gslog!
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :createUsersSaves

        set "accountEntries="""
        set /A "nbUsersTreated=0"

        REM : get BatchFw users list
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%i""
            set "currentUser=!user:"=!"

            set "pat="!USERS_ACCOUNTS_FOLDER:"=!\%%i*.dat""
            set "folder=NONE"
            for /F "delims=~" %%j in ('dir /B !pat! 2^>NUL') do (
                set "filename="%%j""
                set "noext=!filename:.dat=!"
                set "folder=!noext:%%i=!"
                set "folder=!folder:"=!"
            )
            if ["!folder!"] == ["NONE"] (
                echo WARNING^: no account associated with %%i
                echo You should use Wii-U Games^\Wii-U^\Get online files^.lnk
                echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
                echo before this script
                goto:eof
            )

            REM : cd to user
            pushd !localFolderUser!
                
            if not exist !folder! (
                echo WARNING ^: no Wii-U saves found for !currentUser!
                goto:eof
            )
            REM : import saves (if asked)
            if not [!userSavesToImport!] == ["none"] call:importSavesForCurrentUser

            REM : cd to BFW_RESOURCES_PATH to use xml.exe
            pushd !BFW_RESOURCES_PATH!

            REM : update user last settings using saveinfo file
            call:updateGameStatsInLastSettings

            pushd !GAMES_FOLDER!

            set /A "nbUsersTreated+=1"            
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
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_OperatingSystem get Locale /value 2^>NUL ^| find "="') do set "L0CALE_CODE=%%f"

    goto:eof
    REM : ------------------------------------------------------------------

    :getHostState
        set "ipaddr=%~1"
        set /A "state=0"
        ping -n 1 !ipaddr! > NUL 2>&1
        if !ERRORLEVEL! EQU 0 set /A "state=1"

        set "%2=%state%"
    goto:eof
    REM : ------------------------------------------------------------------

