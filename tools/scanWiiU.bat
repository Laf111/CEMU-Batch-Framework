@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    set "THIS_SCRIPT=%~0"
    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        if %nbArgs% EQU 0 exit 1
        if %nbArgs% EQU 0 exit /b 1
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

    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    set "BFW_WIIUSCAN_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU\Scans""
    if not exist !BFW_WIIUSCAN_FOLDER! mkdir !BFW_WIIUSCAN_FOLDER! > NUL 2>&1

    REM : get current date
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    set "wiiuScanFolder="!BFW_WIIUSCAN_FOLDER:"=!\!DATE!""

    @echo =========================================================
    @echo Take a snapshot of Games^, updates and DLC and saves
    @echo installed on your PC and on your Wii-U
    @echo =========================================================
    @echo.

    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""

    if %nbArgs% NEQ 0 (
        set "wiiuIp=!args[0]!"
        goto:checkConnection
    )

    @echo On your Wii-U^, you need to ^:
    @echo - disable the sleeping^/shutdown features
    @echo - if you^'re using a permanent hack ^(CBHC^)^:
    @echo    ^* launch HomeBrewLauncher
    @echo    ^* then ftp-everywhere for CBHC
    @echo - if you^'re not^:
    @echo    ^* first run Mocha CFW HomeBrewLauncher
    @echo    ^* then ftp-everywhere for MOCHA
    @echo.
    @echo - get the IP adress displayed on Wii-U gamepad
    @echo.
    @echo Press any key to continue when you^'re ready
    @echo ^(CTRL-C^) to abort
    pause
    cls

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
    REM : check its state
    set /A "state=0"
    call:getHostState !wiiuIp! state

    if !state! EQU 0 (
        @echo ERROR^: !wiiuIp! was not found on your network ^!
        pause
        exit 2
    )

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck.log""
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        @echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before FTP_every_where on the Wii-U
        @echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    cls
    
    REM : ok so far, create scan folder
    mkdir !wiiuScanFolder!

    REM : log files
    set "remoteTids="!wiiuScanFolder:"=!\SRCTitleIds.log""
    set "remoteSaves="!wiiuScanFolder:"=!\SRCSaves.log""
    set "remoteUpdates="!wiiuScanFolder:"=!\SRCUpdates.log""
    set "remoteDlc="!wiiuScanFolder:"=!\SRCDlc.log""

    REM : get the list of titleId of your installed games
    REM create a log file containing all your games titleId
    set "localTid="!wiiuScanFolder:"=!\localTitleIds.log""
    if exist !localTid! del /F !localTid!

    pushd !GAMES_FOLDER!
    REM : searching for meta file
    for /F "delims=~" %%i in ('dir /B /S meta.xml ^|  find /I /V "\mlc01" 2^> NUL') do (

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%k""
        for /F "delims=<" %%l in (!titleLine!) do echo %%l >> !localTid!
    )

    REM : if needed, dump account.dat for all users
    REM : online files folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""
    set "SITENAME=FTP2WIIU"

    set "WIIU_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\wiiuAccounts\usr\save\system\act""
    if not exist !WIIU_ACCOUNTS_FOLDER! (

        mkdir !WIIU_ACCOUNTS_FOLDER! > NUL 2>&1

        @echo synchronize WII-U accounts

        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!WIIU_ACCOUNTS_FOLDER!" /storage_mlc/usr/save/system/act" "exit"

        REM : associate BatchFw's users to Wii-U accounts
        set "setAccountToUsers="!BFW_TOOLS_PATH:"=!\setWiiuAccountToUsers.bat""
        wscript /nologo !StartWait! !setAccountToUsers!
    )

    REM : lists of games and their endTitleId
    set /A "nbGames=0"
    set /A "nbGamesMlc=0"
    set /A "nbGamesUsb=0"

    for %%i in (mlc usb) do (
        set "src=%%i"

        @echo Scanning wii-u storage_!src!^.^.^.

        REM : get saves list
        set "outputFile=!remoteSaves:SRC=%%i!"
        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/save/00050000" "exit" > !outputFile!
        if !ERRORLEVEL! NEQ 0 (
            @echo WARNING when getting saves list on storage_!src!
        )

        REM : get games list
        set "outputFile=!remoteTids:SRC=%%i!"
        set "gamesListSrc=!outputFile!"

        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/title/00050000"  "exit" > !outputFile!
        if !ERRORLEVEL! NEQ 0 (
            @echo WARNING when getting games list on storage_!src!
        )

        REM : get updates list
        set "outputFile=!remoteUpdates:SRC=%%i!"
        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/title/0005000E"  "exit" > !outputFile!
        if !ERRORLEVEL! NEQ 0 (
            @echo WARNING when getting updates list on storage_!src!
        )

        REM : get DLC list
        set "outputFile=!remoteDlc:SRC=%%i!"
        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/title/0005000C"  "exit" > !outputFile!
        if !ERRORLEVEL! NEQ 0 (
            @echo WARNING when getting DLC list on storage_!src!
        )

        REM : parsing the %src%GamesList.txt and get the titleIds
        for /F "tokens=9" %%j in ('type !gamesListSrc! ^| find "Drwxr"') do (

            REM : get title using endTitleId
            set "title=NOT_FOUND"
            for /F "delims=~; tokens=2" %%t in ('type !wiiTitlesDataBase! ^| find /I "'00050000%%j';"') do set "title=%%t"

            if not ["!title!"] == ["NOT_FOUND"] (
                set "titles[!nbGames!]=!title!"
                set "endTitlesId[!nbGames!]=%%j"
                set "titlesSrc[!nbGames!]=!src!"

                set /A "nbGames+=1"
                if ["!src!"] == ["mlc"] set /A "nbGamesMlc+=1"
                if ["!src!"] == ["usb"] set /A "nbGamesUsb+=1"
             )
        )
    )
    if !nbGames! EQU 0 (
        echo WARNING : no games were found ^?
        pause
        exit /b 10
    )

    REM : create a global list of saves
    set "output=!remoteSaves:SRC=!"
    type !remoteSaves:SRC=mlc! | find "Drwxr" > !output!
    type !remoteSaves:SRC=usb! | find "Drwxr" >> !output!

    REM : create a global list of updates
    set "output=!remoteUpdates:SRC=!"
    type !remoteUpdates:SRC=mlc!  | find "Drwxr" > !output!
    type !remoteUpdates:SRC=usb!  | find "Drwxr" >> !output!

    REM : create a global list of Dlc
    set "output=!remoteDlc:SRC=!"
    type !remoteDlc:SRC=mlc!  | find "Drwxr" > !output!
    type !remoteDlc:SRC=usb!  | find "Drwxr" >> !output!

    set "gamesList="!wiiuScanFolder:"=!\gamesList.csv""
    set "tmpFile=!gamesList:csv=tmp!"
    cls

    @echo =========================================================
    @echo List of games found ^:
    @echo ---------------------------------------------------------

    REM : loop on the games found
    set /A "nbg=!nbGames!-1"

    for /L %%i in (0,1,!nbg!) do (

        @echo !titles[%%i]! [!endTitlesId[%%i]!] found on !titlesSrc[%%i]!

        set "save="
        set "file=!remoteSaves:SRC=!"
        type !file! | find /I "!endTitlesId[%%i]!" > NUL 2>&1 && set "save=X"

        set "update="
        set "file=!remoteUpdates:SRC=!"
        type !file! | find /I "!endTitlesId[%%i]!" > NUL 2>&1 && set "update=X"

        set "file=!remoteDlc:SRC=!"
        set "dlc="
        type !file! | find /I "!endTitlesId[%%i]!" > NUL 2>&1 && set "dlc=X"

        @echo !titles[%%i]!;^'!endTitlesId[%%i]!^';!titlesSrc[%%i]!;!save!;!update!;!dlc! >> !tmpFile!
    )

    REM : create gamesList
    @echo title;endTitleId;source;save;update;dlc > !gamesList!
    type !tmpFile! | sort >> !gamesList!
    del /F !tmpFile!

    @echo =========================================================
    @echo Total ^: !nbGames! games found ^(mlc ^: %nbGamesMlc%^, usb ^: %nbGamesUsb%^)
    @echo =========================================================
    @echo Results folder ^: !wiiuScanFolder!
    @echo ---------------------------------------------------------
    pause

    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

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

