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
    set "installFolder=!parentFolder:~0,-2!""
    for %%a in (!installFolder!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "syncFolder="!BFW_TOOLS_PATH:"=!\ftpSyncFolders.bat""
    set "importWiiuSaves="!BFW_TOOLS_PATH:"=!\importWiiuSaves.bat""

    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : online files folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""

    set "USERS_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
    if not exist !USERS_ACCOUNTS_FOLDER! (
        @echo ERROR^: !USERS_ACCOUNTS_FOLDER! does not exist ^!^
        @echo Use Wii-U Games^\Wii-U^\Get online files^.lnk
        @echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
        @echo before this script
        pause
        exit 99
    )

    cls
    title Dump games installed on your Wii-U
    @echo =========================================================
    @echo Dump games installed on your Wii-U
    @echo =========================================================
    @echo.
    @echo WARNING ^: it is impossible to get the space left on your Wii-U
    @echo storage device^. Be sure that there^'s sufficient space ^!
    @echo.
    @echo If you want to use online account ^:
    @echo Make sure the Wii U account you want to dump^/use has
    @echo the "Save password" option checked ^(auto login^) ^!
    @echo.
    pause
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
    cls

    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    if not exist !winScpIni! goto:getWiiuIp

    REM : get the hostname
    for /F "delims== tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    REM : and teh port
    for /F "delims== tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"

    @echo Found an existing FTP configuration ^:
    @echo.
    @echo PortNumber=!ipRead!
    @echo HostName=!portRead!
    @echo.
    choice /C yn /N /M "Use this setup (y, n)? : "
    if !ERRORLEVEL! EQU 1 set "wiiuIp=!ipRead!" && goto:checkConnection

    :getWiiuIp
    set /P "wiiuIp=Please enter your Wii-U local IP adress : "
    set /P "port=Please enter the port used : "

    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""


    REM : prepare winScp.ini file
    copy /Y  !winScpIniTmpl! !winScpIni! > NUL 2>&1
    set "fnrLog="!BFW_PATH:"=!\logs\fnr_WinScp.log""

    REM : set WiiU ip adress
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-IP" --replace "!wiiuIp!" --logFile !fnrLog!
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-port" --replace "!port!" --logFile !fnrLog!

    :checkConnection
    cls
    REM : check its state
    set /A "state=0"
    call:getHostState !wiiuIp! state

    if !state! EQU 0 (
        @echo ERROR^: !wiiuIp! was not found on your network ^!
        pause
        exit 2
    )

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck.log""
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        @echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before FTP_every_where on the Wii-U
        @echo Pause this script until you fix it ^(CTRL-C to abort^)
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
    for /F %%i in ('dir /B /A:D /O:N !BFW_WIIUSCAN_FOLDER!') do set "LAST_SCAN="%%i""

    if [!LAST_SCAN!] == ["NOT_FOUND"] (
        @echo ERROR^: last scan results were not found
        pause
        exit 90
    )
    cls
    if !noOldScan! EQU 1 goto:getList

    @echo The last WiiU can found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getList

    rmdir /Q /S !BFW_WIIUSCAN_FOLDER!
    goto:scanMyWii

    REM : get title;endTitleId;source;dataFound from scan results
    :getList
    set "wiiuScanFolder="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!""
    set "gamesList="!wiiuScanFolder:"=!\gamesList.csv""
    set "localTid="!wiiuScanFolder:"=!\localTitleIds.log""

    set "remoteSaves="!wiiuScanFolder:"=!\SRCSaves.log""
    set "remoteUpdates="!wiiuScanFolder:"=!\SRCUpdates.log""
    set "remoteDlc="!wiiuScanFolder:"=!\SRCDlc.log""

    set /A "nbGames=0"

    cls
    @echo =========================================================
    @echo Games found on the Wii-U
    @echo =========================================================

    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "title"') do (

        set "second=%%j"
        set "endTitleId=!second:'=!"

        REM : if the game is not also installed on your PC
        type !localTid! | find /V "!endTitleId!" > NUL 2>&1 && (
            set "titles[!nbGames!]=%%i"
            set "endTitlesId[!nbGames!]=!endTitleId!"
            set "titlesSrc[!nbGames!]=%%k"
            @echo !nbGames!	: %%i

            set /A "nbGames+=1"
        )
    )
    @echo =========================================================

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

    set /P "listGamesSelected=Please enter game's numbers list (separate with a space): "
    call:secureStringPathForDos !listGamesSelected! listGamesSelected
    call:checkListOfGames !listGamesSelected!
    if !ERRORLEVEL! NEQ 0 goto:getList
    @echo ---------------------------------------------------------
    choice /C ync /N /M "Continue (y, n) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 @echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit 98
    if !ERRORLEVEL! EQU 2 goto:getList

    cls
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit 11
    )
    set /A "nbGamesSelected-=1"

    REM : loop on the games selected
    for /L %%i in (0,1,!nbGamesSelected!) do (

        set "name=!selectedTitles[%%i]!"

        REM : create local folders
        set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!name!""
        call:createLocalFolders %%i

        REM : dump the game by FTP
        call:getGame !selectedtitlesSrc[%%i]! !selectedEndTitlesId[%%i]!
    )

    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"
    
    @echo =========================================================
    @echo All transferts ended^, done at !DATE!
    @echo ---------------------------------------------------------
    @echo.
    @echo Forcing a GFX pack update to add GFX packs for new games^.^.^.
    @echo.

    REM : forcing a GFX pack update to add GFX packs for new games
    set "gfxUpdate="!BFW_TOOLS_PATH:"=!\forceGraphicPackUpdate.bat""
    call !gfxUpdate! -silent
    @echo =========================================================
    @echo !GAME_TITLE! dumped successfully
    pause
    
    if !ERRORLEVEL! NEQ 0 exit !ERRORLEVEL!
    exit 0

    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : remove DOS forbiden character from a string
    :secureStringPathForDos

        set "str=%~1"
        set "str=!str:&=!"
        set "str=!str:?=!"
        set "str=!str:(=!"
        set "str=!str:)=!"
        set "str=!str:%%=!"
        set "str=!str:^=!"
        set "str=!str:"=!"
        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : check list of games and create selection
    :checkListOfGames

        @echo ---------------------------------------------------------
        @echo Dump ^:
        @echo.
        for %%l in (!listGamesSelected!) do (
            if %%l GEQ !nbGames! exit /b 1
            @echo - !titles[%%l]!
            set "selectedTitles[!nbGamesSelected!]=!titles[%%l]!"
            set "selectedEndTitlesId[!nbGamesSelected!]=!endTitlesId[%%l]!"
            set "selectedtitlesSrc[!nbGamesSelected!]=!titlesSrc[%%l]!"

            set /A "nbGamesSelected+=1"
            )
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------
    

REM : ------------------------------------------------------------------
    :getGame
        REM : source (mlc or usb)
        set "src=%~1"

        REM : end part of the title Id
        set "endTitleId=%~2"

        REM : get current date
        for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"

        @echo ---------------------------------------------------------
        @echo !name! ^: starting at !DATE!
        @echo - dumping game

        REM : Import the game (minimized + no wait)
        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""

        wscript /nologo !StartMinimized! !syncFolder! !wiiuIp! local !codeFolder! "/storage_%src%/usr/title/00050000/%endTitleId%/code" "!name! (code)"

        set "contentFolder="!GAME_FOLDER_PATH:"=!\content""
        wscript /nologo !StartMinimized! !syncFolder! !wiiuIp! local !contentFolder! "/storage_%src%/usr/title/00050000/%endTitleId%/content" "!name! (meta)"

        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        wscript /nologo !StartMinimized! !syncFolder! !wiiuIp! local !metaFolder! "/storage_%src%/usr/title/00050000/%endTitleId%/meta" "!name! (content)"

        REM : search if this game has an update
        set "srcRemoteUpdate=!remoteUpdates:SRC=%src%!"
        type !srcRemoteUpdate! | find "%endTitleId%" > NUL 2>&1 && (

            @echo - dumping update

            REM : YES : import update in mlc01/usr/title (minimized + no wait)
            set "updateFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0050000\%endTitleId%""
            wscript /nologo !StartMinimized! !syncFolder! !wiiuIp! local !updateFolder! "/storage_%src%/usr/title/0005000E/%endTitleId%" "!name! (update)"
        )
        REM : search if this game has a DLC
        set "srcRemoteDlc=!remoteDlc:SRC=%src%!"
        type !srcRemoteDlc! | find "%endTitleId%" > NUL 2>&1 && (

            @echo - dumping DLC

            REM : YES : import dlc in mlc01/usr/title/0050000/%endTitleId%/aoc (minimized + no wait)
            set "dlcFolder="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0050000\%endTitleId%\aoc""
            wscript /nologo !StartMinimized! !syncFolder! !wiiuIp! local !dlcFolder! "/storage_%src%/usr/title/0005000C/%endTitleId%" "!name! (DLC)"
        )
        REM : search if this game has saves
        set "srcRemoteSaves=!remoteSaves:SRC=%src%!"
        type !srcRemoteSaves! | find /V "%endTitleId%" > NUL 2>&1 && goto:waitingLoop

        @echo - dumping saves
        
        REM : Import Wii-U saves
        wscript /nologo !StartHiddenWait! !importWiiuSaves! !wiiuIp! !GAME_FOLDER_PATH! %endTitleId% %src%

        :waitingLoop
        REM : wait all transfert end
        timeout /T 1 > NUL 2>&1
        for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "winScp.com" ^| find /I /V "find"') do timeout /T 2 > NUL 2>&1 && goto:waitingLoop

        REM : get current date
        for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"

        @echo end of transferts at !DATE!

    goto:eof
REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
    :createLocalFolders
        set /A "num=%~1"

        set "CODE_PATH="!GAME_FOLDER_PATH:"=!\code""
        if not exist !CODE_PATH! mkdir !CODE_PATH! > NUL 2>&1
        set "CONTENT_PATH="!GAME_FOLDER_PATH:"=!\content""
        if not exist !CONTENT_PATH! mkdir !CONTENT_PATH! > NUL 2>&1
        set "META_PATH="!GAME_FOLDER_PATH:"=!\meta""
        if not exist !META_PATH! mkdir !META_PATH! > NUL 2>&1

        set "SAVES_ARCHIVES_PATH="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
        if not exist !SAVES_ARCHIVES_PATH! mkdir !SAVES_ARCHIVES_PATH! > NUL 2>&1

        set "DLC_PATH="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\0050000\!selectedEndTitlesId[%num%]!\aoc""
        if not exist !DLC_PATH! mkdir !DLC_PATH! > NUL 2>&1
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
        dir !toCheck! > NUL 2>&1
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
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic path Win32_OperatingSystem get Locale /value ^| find "="') do set "L0CALE_CODE=%%f"

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

    