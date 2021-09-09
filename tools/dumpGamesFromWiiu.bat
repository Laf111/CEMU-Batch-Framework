@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
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
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "syncFolder="!BFW_TOOLS_PATH:"=!\ftpSyncFolders.bat""
    set "importWiiuSaves="!BFW_TOOLS_PATH:"=!\importWiiuSaves.bat""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "rulesFiles="!BFW_PATH:"=!\logs\rulesFiles.log""

    set /A "totalMoCopied=0"

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit /b 100
    )
    
    REM : clean ftp logs
    set "pat="!BFW_PATH:"=!\logs\ftp*.log""
    del /F /S !pat! > NUL 2>&1

    REM : online files folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""

    set "USERS_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
    if not exist !USERS_ACCOUNTS_FOLDER! (
        echo ERROR^: !USERS_ACCOUNTS_FOLDER! does not exist ^!^
        echo Use Wii-U Games^\Wii-U^\Get online files^.lnk
        echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
        echo before this script
        pause
        exit /b 99
    )

    cls
    title Dump games installed on your Wii-U
    echo =========================================================
    echo Dump games installed on your Wii-U
    echo =========================================================
    echo.
    echo WARNING ^: no check can be done on amount of data donwloaded^.
    @echo Be sure you have enough space left^!
    echo.
    echo BE AWARE ^: transfert errors on update and DLC files can occur
    echo on symlinks not handled by FTPiiU server^.
    echo These files are not used by CEMU^.
    echo Just ignore those errors^.
    pause
    
    cls
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
        echo ERROR^: !wiiuIp! was not found on your network ^!
        pause
        exit /b 2
    )

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck.log""
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
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

    REM : get last scan folder
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
        echo ERROR^: last scan results were not found
        pause
        exit /b 90
    )
    cls
    if !noOldScan! EQU 1 goto:getList

    echo The last WiiU^'s scan found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getList

    rmdir /Q /S !BFW_WIIUSCAN_FOLDER!
    goto:scanMyWii
        
    REM : get title;endTitleId;source;dataFound from scan results
    :getList

    set "wiiuScanFolder="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!""
    set "gamesList="!wiiuScanFolder:"=!\gamesList.csv""

    set "remoteSaves="!wiiuScanFolder:"=!\SRCSaves.log""
    set "remoteUpdates="!wiiuScanFolder:"=!\SRCUpdates.log""
    set "remoteDlc="!wiiuScanFolder:"=!\SRCDlc.log""

    set /A "nbGames=0"
    
    cls
    echo =========================================================
    echo Games found on the Wii-U
    echo =========================================================
    REM : loop on games
    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "title"') do (

        set "second=%%j"
        set "endTitleId=!second:'=!"

        set "titles[!nbGames!]=%%i"
        set "endTitlesId[!nbGames!]=!endTitleId!"
        set "titlesSrc[!nbGames!]=%%k"
        echo !nbGames!	: %%i

        set /A "nbGames+=1"
    )
    echo =========================================================

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

    set /P "listGamesSelected=Please enter game's numbers list (separated with a space): "
    if not ["!listGamesSelected: =!"] == [""] (
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
    echo =========================================================
    echo.
    choice /C ync /N /M "Continue (y, n) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit /b 98
    if !ERRORLEVEL! EQU 2 goto:getList
    
    cls
    echo =========================================================
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit /b 11
    )

    REM : get BatchFw users list
    set "USERSARRAY="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSARRAY[!nbUsers!]=%%i"
        set /A "nbUsers+=1"
    )

    REM : ask for saves import mode and set shutdownFlag accordingly
    set /A "shutdownFlag=0"
    call:getSavesUserMode userSavesToImport

    if !shutdownFlag! EQU 1 (
        choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
        if !ERRORLEVEL! EQU 2 (
            set /A "shutdownFlag=0"
        ) else (
            echo Please^, save all your opened documents before continue^.^.^.
            pause
        )
    )

    cls
    set /A "nbGamesSelected-=1"
    set "START_DATE="

    set /A "nbPass=1"
    call:loopOnGames

    cls
    echo Fix unexpected transfert errors with a 2nd pass^.^.^.
    echo.
    call:loopOnGames

    call:waitEndOfTransfers
    
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"
    
    echo =========================================================
    echo Now you can stop FTPiiU server on you wii-U
    echo All transferts ended^, done
    echo - start ^: !START_DATE!
    echo - end   ^: !DATE!
    echo ---------------------------------------------------------

    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if not exist !BFW_GP_FOLDER! goto:launchSetup
    set "pat="!BFW_GP_FOLDER:"=!\*_Resolution""

    if exist !rulesFiles! del /F !rulesFiles! > NUL 2>&1
    for /F "delims=~" %%p in ('dir /B /S !pat! 2^>NUL') do echo "%%p\rules.txt" >> !rulesFiles!

    pushd !BFW_GP_FOLDER!
    REM : V6 gfx packs support
    for /F "delims=~" %%p in ('dir /A:D /B /S Graphics 2^>NUL') do echo "%%p\rules.txt" >> !rulesFiles!

    REM : check if an internet connection is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] goto:launchSetup
    
    set /A "nbGameWithGfxPack=0"
    call:checkGfxPacksAvailability

    if !nbGameWithGfxPack! LSS !nbGamesSelected! (

        echo No GFX pack were found for at least one game^.
        echo.
        choice /C yn /N /M "Do you want to update GFX packs folder ? (y,n):"
        if !ERRORLEVEL! EQU 1 (
            set "ugp="!BFW_PATH:"=!\tools\updateGraphicPacksFolder.bat""
            call !ugp!        
        )

    ) else (
        echo GFX packs found for all games^, no need to update GFX packs
    )

    :launchSetup
        
    if !nbGamesSelected! NEQ 0 (
        echo New Games were added to your library^, launching setup^.bat^.^.^.
        set "setup="!BFW_PATH:"=!\setup.bat""
        timeout /T 3 > NUL 2>&1

        REM : last loaction used for batchFw outputs

        REM : get the last location from logFile
        set "OUTPUT_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set "OUTPUT_FOLDER="%%i""
        if not [!OUTPUT_FOLDER!] == ["NONE"] (
            set "pf=!OUTPUT_FOLDER:\Wii-U Games=!"
            wscript /nologo !Start! !setup! !pf!
        ) else (
            wscript /nologo !Start! !setup!
        )
        exit 15
    )

    REM : if shutdwon is asked
    if !shutdownFlag! EQU 1 echo shutdown in 5min^.^.^. & timeout /T 300 /NOBREAK & shutdown -s -f -t 00
    
    echo =========================================================
    echo games dumped successfully ^(!totalMoCopied! Mb^)
    echo.

    pause
    
    exit 0

    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :waitEndOfTransfers

        :waitingLoop
        REM : wait all transfert end
        timeout /T 1 > NUL 2>&1
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "ftpSyncFolders.bat" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && goto:waitingLoop

    goto:eof
    REM : ------------------------------------------------------------------

    :getSavesUserMode
        REM : init to none (choice number 1)
        set "%1=none"
        set /A "shutdownFlag=1"

        echo.
        if ["!wiiuSaveMode!"] == ["SYNCR"] (
            echo You choose to synchronize CEMU and Wii-U saves^,
        ) else (
            echo You choose to keep both saves ^(CEMU and Wii-U saves^)^,
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
        set /A "shutdownFlag=0"

    goto:eof
    REM : ------------------------------------------------------------------

    :checkGfxPacksAvailability

        for /F "delims=~" %%p in ('type !rulesFiles!') do (

            for /L %%i in (0,1,!nbGamesSelected!) do (

                set "titleId=!selectedEndTitlesId[%%i]!"
                echo %%p | find /I "!titleId!" > NUL 2>&1 && (

                    set /A "nbGameWithGfxPack=nbGameWithGfxPack+1"
                    if !nbGameWithGfxPack! EQU !nbGamesSelected! goto:eof
                )
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :loopOnGames

        REM : loop on the games selected
        for /L %%i in (0,1,!nbGamesSelected!) do (

            set "GAME_TITLE=!selectedTitles[%%i]!"
            set "endTitleIdFolder=!selectedEndTitlesId[%%i]!"

            REM : define local folders
            set "targetFolder="!GAMES_FOLDER:"=!\!GAME_TITLE!""
            set "codeFolder="!targetFolder:"=!\code""
            set "contentFolder="!targetFolder:"=!\content""
            set "metaFolder="!targetFolder:"=!\meta""
            set "updateFolder="!targetFolder:"=!\mlc01\usr\title\0005000e\!endTitleIdFolder!""
            set "dlcFolder="!targetFolder:"=!\mlc01\usr\title\0005000c\!endTitleIdFolder!""

            call:createRequieredFolders > NUL 2>&1
            REM : dump the game by FTP
            call:getGame !selectedtitlesSrc[%%i]!
        )
        set /A "nbPass=nbPass+1"
    goto:eof
    REM : ------------------------------------------------------------------
    
    :getGame
        REM : source (mlc or usb)
        set "src=%~1"

        REM : get saves only the first pass
        if !nbPass! GTR 1 goto:importGame

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"
        if ["!START_DATE!"] == [""] set "START_DATE=%ldt%"
        echo !GAME_TITLE! ^: starting at !DATE!
        echo ---------------------------------------------------------
        echo - dumping !GAME_TITLE! to !targetFolder!
        set "msg="!GAME_TITLE!: start downloading at !DATE! to=!targetFolder:"=!""
        call:log2GamesDownloadFile !msg!

        :importGame
        REM : Import the game (minimized + no wait)
        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !codeFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/code" "!name! (code)"

        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !contentFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/content" "!name! (content)"

        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !metaFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/meta" "!name! (meta)"

        call:waitEndOfTransfers

        REM : search if this game has an update
        set "srcRemoteUpdate=!remoteUpdates:SRC=%src%!"
        type !srcRemoteUpdate! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            if !nbPass! EQU 1 echo - dumping update

            REM : YES : import update in mlc01/usr/title (minimized + no wait)
            wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !updateFolder! "/storage_%src%/usr/title/0005000e/!endTitleIdFolder!" "!name! (update)"
        )
        REM : search if this game has a DLC
        set "srcRemoteDlc=!remoteDlc:SRC=%src%!"
        type !srcRemoteDlc! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            if !nbPass! EQU 1 echo - dumping DLC

            REM : YES : import dlc in mlc01/usr/title/0005000C/!endTitleIdFolder! (minimized + no wait)
            wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !dlcFolder! "/storage_%src%/usr/title/0005000c/!endTitleIdFolder!" "!name! (DLC)"
        )

        call:waitEndOfTransfers

        REM : get saves only the first pass
        if !nbPass! GTR 1 (

            REM : compute the game size (waitEndOfTransfers already call for game files)
            set /A "dumpSize=0"
            call:getFolderSizeInMb !targetFolder! dumpSize
            set /A "totalMoCopied+=!dumpSize!"
            goto:eof
        )
        
        REM : search if this game has saves
        set "srcRemoteSaves=!remoteSaves:SRC=%src%!"
        type !srcRemoteSaves! | find "!endTitleIdFolder!" > NUL 2>&1 && (
            if not ["!userSavesToImport!"] == ["none"] (
                echo - dumping saves

                REM : Import Wii-U saves
                if not ["!userSavesToImport!"] == ["select"] (
                    wscript /nologo !StartMinimizedWait! !importWiiuSaves! "!wiiuIp!" "!GAME_TITLE!" !endTitleIdFolder! !src! !userSavesToImport!
                ) else (
                    wscript /nologo !StartMaximizedWait! !importWiiuSaves! "!wiiuIp!" "!GAME_TITLE!" !endTitleIdFolder! !src! !userSavesToImport!
                )
            )
        )

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"

        echo ---------------------------------------------------------
        echo !GAME_TITLE! ^: ending at !DATE!
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        set "msg="!GAME_TITLE!: downloaded at !DATE!""
        call:log2GamesDownloadFile !msg!
        
    goto:eof
    REM : ------------------------------------------------------------------


    :getSmb
        set "sr=%~1"
        set /A "d=%~2"

        set /A "%3=!sr:~0,%d%!+1"
    goto:eof
    REM : ------------------------------------------------------------------

    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof
    REM : ------------------------------------------------------------------

    :getFolderSizeInMb

        set "folder="%~1""
        REM : prevent path to be stripped if contain '
        set "folder=!folder:'=`'!"
        set "folder=!folder:[=`[!"
        set "folder=!folder:]=`]!"
        set "folder=!folder:)=`)!"
        set "folder=!folder:(=`(!"

        set "psCommand=-noprofile -command "ls -r -force '!folder:"=!' | measure -s Length""

        set "line=NONE"
        for /F "usebackq tokens=2 delims=:" %%a in (`powershell !psCommand! ^| find /I "Sum"`) do set "line=%%a"
        REM : powershell call always return %ERRORLEVEL%=0

        if ["!line!"] == ["NONE"] (
            set "%2=0"
            goto:eof
        )

        set "sizeRead=%line: =%"

        if ["!sizeRead!"] == [" ="] (
            set "%2=0"
            goto:eof
        )

        set /A "im=0"
        if not ["!sizeRead!"] == ["0"] (

            REM : compute length before switching to 32bits integers
            call:strLength !sizeRead! len
            REM : forcing Mb unit
            if !len! GTR 6 (
                set /A "dif=!len!-6"
                call:getSmb %sizeRead% !dif! smb
                set "%2=!smb!"
                goto:eof
            ) else (
                set "%2=1"
                goto:eof
            )
        )
        set "%2=0.0"

    goto:eof
    REM : ------------------------------------------------------------------
    
    REM : ------------------------------------------------------------------
    :createRequieredFolders

        REM : in all case
        set "gameFolder="!GAMES_FOLDER:"=!\!GAME_TITLE!""
        if not exist !gameFolder! mkdir !gameFolder! > NUL 2>&1
        set "cemuSaveFolder="!gameFolder:"=!\Cemu\inGameSaves""
        if not exist !cemuSaveFolder! mkdir !cemuSaveFolder! > NUL 2>&1

        if not exist !codeFolder! mkdir !codeFolder! > NUL 2>&1
        if not exist !contentFolder! mkdir !contentFolder! > NUL 2>&1
        if not exist !metaFolder! mkdir !metaFolder! > NUL 2>&1
        REM : updateFolder is created with dlc one
        if not exist !dlcFolder! mkdir !dlcFolder! > NUL 2>&1
    goto:eof

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

    REM : function to log
    :log2GamesDownloadFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_WIIU_FOLDER:"=!\gameDownloadHistory.log""

        echo !msg! >> !glogFile!

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

    