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
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "syncFolder="!BFW_TOOLS_PATH:"=!\ftpSyncFolders.bat""
    set "exportWiiuSaves="!BFW_TOOLS_PATH:"=!\exportSavesToWiiu.bat""

    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""

    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : clean ftp logs
    set "pat="!BFW_PATH:"=!\logs\ftp*.log""
    del /F /S !pat! > NUL 2>&1

    set "endTitleId=NONE"
    REM : total size needed on the Wii-U
    set /A "totalMoNeeded=0"
    cls
    title Inject Games dumps to your Wii-U
    echo WARNING^: you must have a permanent CFW installed on the
    echo Wii-U ^(CBHC^) or you^'ll need to launch SIG Patcher each
    echo time you^'ll play the game on the Wii-U^.
    echo.
    echo NOTE ^: the candidates games are only the ones you previously
    echo dumped ^(code^\title^.^* files exist and for which no transfer
    echo errors were detected by BatchFw during the dumping process^)
    echo.
    pause
    cls
    echo On your Wii-U^, you need to ^:
    echo - have your SDCard plugged in your Wii-U
    echo - launch WiiU FTP Server and press B to mount NAND paths
    echo   if you want to inject games on NAND
    echo - get the IP adress displayed on Wii-U gamepad
    echo.
    echo Press any key to continue when you^'re ready
    echo ^(CTRL-C^) to abort
    pause
    cls

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

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck_idtw.log""
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
    echo.
    echo Get games candidates^.^.^.
    if !ERRORLEVEL! EQU 1 goto:getLocalTitleId

    rmdir /Q /S !BFW_WIIUSCAN_FOLDER! > NUL 2>&1
    goto:scanMyWii

    REM : get the list of titleId of your installed dumps
    :getLocalTitleId

    REM create a log file containing all the games titleId for valid dump (code\title.* files exist)
    set "localTid="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\localTitleIds.log""
    if exist !localTid! del /F !localTid!

    pushd !GAMES_FOLDER!
    REM : searching for meta file
    for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^|  find /I /V "\mlc01"') do (

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%k""
        for /F "delims=<" %%j in (!titleLine!) do (

            for %%a in (!META_FILE!) do set "parentFolder="%%~dpa""
            set "str=!parentFolder:~0,-2!""
            for %%a in (!str!) do set "parentFolder="%%~dpa""
            set "GAME_FOLDER_PATH=!parentFolder:~0,-2!""

            set "titleFst="!GAME_FOLDER_PATH:"=!\code\title.fst""
            set "titletmd="!GAME_FOLDER_PATH:"=!\code\title.tmd""

            REM : list game only if title.* files exist
            if exist !titleFst! if exist !titletmd! (
                set /A "NB_GAMES+=1"
                echo %%j >> !localTid!
            )
        )
    )

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "wiiuScanFolder="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!""
    set "gamesList="!wiiuScanFolder:"=!\gamesList.csv""

    set "remoteSaves="!wiiuScanFolder:"=!\SRCSaves.log""
    set "remoteUpdates="!wiiuScanFolder:"=!\SRCUpdates.log""
    set "remoteDlc="!wiiuScanFolder:"=!\SRCDlc.log""

    set /A "nbGames=0"

    cls
    echo =========================================================
    echo List of valid games^'dumps found ^(code^\title^.^* files exist^)
    echo =========================================================

    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "title"') do (

        set "second=%%j"
        set "endTitleId=!second:'=!"

        REM : if the game is also installed on your PC and was dumped (code\title.* files exist)
        type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (
            set "titles[!nbGames!]=%%i"
            set "endTitlesId[!nbGames!]=!endTitleId!"
            set "titlesSrc[!nbGames!]=%%k"
            echo !nbGames!	: %%i

            set /A "nbGames+=1"
        )
    )
    echo =========================================================

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

    set /P "listGamesSelected=Please enter game's numbers list (separated with a space): "
    call:checkListOfGames !listGamesSelected!
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
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit 98
    if !ERRORLEVEL! EQU 2 goto:getList

    cls
    echo =========================================================
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit 11
    )
    set /A "nbGamesSelected-=1"


    set /A "shutdownFlag=0"
    choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
    if !ERRORLEVEL! EQU 1 (
        echo Please^, save all your opened documents before continue^.^.^.
        pause
        set /A "shutdownFlag=1"
    )


    pushd !GAMES_FOLDER!

    REM : Loop on the game selected
    for /L %%i in (0,1,!nbGamesSelected!) do (
    REM : get the endTitleId
        set "endTitleId=!selectedEndTitlesId[%%i]!"
        set "title=!selectedTitles[%%i]!"

        call:prepareGame %%i
    )

    echo.
    echo !totalMoNeeded! Mb are needed on the Wii-U ^!
    echo.
    choice /C yn /N /M "Do you want to continue (y, n)? : "
    if !ERRORLEVEL! EQU 2 (
        echo Cancelled by user^, exiting
        timeout /t 8 > NUL 2>&1
        exit 13
    )
    cls

    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    REM : get BatchFw users list
    set "USERSARRAY="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSARRAY[!nbUsers!]=%%i"
        set /A "nbUsers+=1"
    )
    REM : ask for saves import mode
    call:getSavesUserMode userSavesToExport
    set "START_DATE="

    set /A "nbPass=1"
    call:injectGames
    cls
    echo Fix unexpected transfert errors with a 2nd pass^.^.^.
    echo.
    call:injectGames

    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    echo =========================================================
    echo Now you can stop FTPiiU server on you wii-U
    echo All transferts ended^, done
    echo.
    echo - start ^: !START_DATE!
    echo - end   ^: !DATE!
    echo ---------------------------------------------------------

    REM : if shutdwon is asked
    if !shutdownFlag! EQU 1 echo shutdown in 30s^.^.^. & timeout /T 30 /NOBREAK & shutdown -s -f -t 00

    pause
    
    if !ERRORLEVEL! NEQ 0 exit !ERRORLEVEL!
    exit 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    :injectGames

        for /L %%n in (0,1,!nbGamesSelected!) do (
            set "GAME_TITLE=!selectedTitles[%%n]!"
            set "endTitleIdFolder=!selectedEndTitlesId[%%n]!"
            set "src=!selectedtitlesSrc[%%n]!"

            REM : define local folders
            set "sourceFolder="!GAMES_FOLDER:"=!\!GAME_TITLE!""
            set "codeFolder="!sourceFolder:"=!\code""
            set "contentFolder="!sourceFolder:"=!\content""
            set "metaFolder="!sourceFolder:"=!\meta""

            REM set "updateFolder="!sourceFolder:"=!\mlc01\usr\title\0005000e\!endTitleIdFolder!""
            REM set "dlcFolder="!sourceFolder:"=!\mlc01\usr\title\0005000c\!endTitleIdFolder!""

            !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "option batch continue" "mkdir /storage_!src!/usr/title/00050000/!endTitleIdFolder!" "option batch off" "exit"  > !ftplogFile! 2>&1

            call:injectGame !src!
        )
        set /A "nbPass=nbPass+1"
    goto:eof
    REM : ------------------------------------------------------------------


    :getSavesUserMode
        REM : init to none
        set "%1=none"

        echo.
        echo You can choose a user for which all saves found will be exported^.
        echo Or you can choose to select which user saves to import for each game^.
        echo.
        echo Note that it will interrupt each game^'s upload^, to ask your selection ^!
        echo.
        echo So if you plan to upload more than one game^, you'd better choose
        echo to export all saves found for all users OR no saves at all^.
        echo You still can use the exportWiiuSaves script to do it afterward^.
        echo.

        choice /C yn /N /M "Do you want to export Wii-U saves during the process (y, n)? : "
        if !ERRORLEVEL! EQU 2 goto:eof

        choice /C yn /N /M "For all users (y, n)? : "
        if !ERRORLEVEL! EQU 1 set "%1=all" & goto:eof

        choice /C yn /N /M "Do you want to choose a user now  (y, n = select users during process)? : "
        if !ERRORLEVEL! EQU 2 set "%1=select" & goto:eof

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
    REM : ------------------------------------------------------------------


    :prepareGame

        set "num=%~1"

        REM : update selectedTitles with local GAME_TITLE

        REM : searching for meta file
        for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

            REM : meta.xml
            set "META_FILE="%%i""
            type !META_FILE! | find /I "!endTitleId!" > NUL 2>&1 && (

                for %%a in (!META_FILE!) do set "parentFolder="%%~dpa""
                set "str=!parentFolder:~0,-2!""
                for %%a in (!str!) do set "parentFolder="%%~dpa""
                set "GAME_FOLDER_PATH=!parentFolder:~0,-2!""

                REM : compute the size of the game (excluding update and including DLC), add it to totalMoNeeded
                call:addGameSize !GAME_FOLDER_PATH!

                REM : update titles[%num%] with folder's name (GAME_TITLE)
                for /F "delims=~" %%a in (!GAME_FOLDER_PATH!) do set "selectedTitles[%num%]=%%~nxa"
            )
        )

        goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log
    :log2GamesUploadFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_WIIU_FOLDER:"=!\gameUploadHistory.log""

        echo !msg! >> !glogFile!

    goto:eof
    REM : ------------------------------------------------------------------

    :injectGame

        REM : source (mlc or usb)
        set "src=%~1"

        REM : get saves only the first pass
        if !nbPass! GTR 1 goto:exportGame

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"
        if ["!START_DATE!"] == [""] set "START_DATE=%ldt%"
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo !GAME_TITLE! ^: starting at !DATE!
        echo ---------------------------------------------------------
        echo - injecting !GAME_TITLE! from !sourceFolder!
        set "msg="!GAME_TITLE!: start uploading at !DATE! to=!targetFolder:"=!""
        call:log2GamesUploadFile !msg!

        :exportGame
        REM : Import the game (minimized + no wait)
        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! remote !codeFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/code" "!name! (code)"

        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! remote !contentFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/content" "!name! (content)"

        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! remote !metaFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/meta" "!name! (meta)"


REM : (update and DLC can't be injected because some of thems use symlink to game's file on the wii-u file system)
REM : those links disappear with RPX format (dump or uncompress) and cannot be replaced by files (symlink failed to be downloaded by FTP)

        REM REM : search if this game has an update
        REM set "srcRemoteUpdate=!remoteUpdates:SRC=%src%!"
        REM type !srcRemoteUpdate! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            REM if !nbPass! EQU 1 echo - injecting update
            REM !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "option batch on" "mkdir /storage_!src!/usr/title/0005000e/!endTitleIdFolder!" "option batch off" "exit"  > !ftplogFile! 2>&1

            REM REM : YES : import update in mlc01/usr/title (minimized + no wait)
            REM wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! remote !updateFolder! "/storage_%src%/usr/title/0005000e/!endTitleIdFolder!" "!name! (update)"
        REM )

        REM REM : search if this game has a DLC
        REM set "srcRemoteDlc=!remoteDlc:SRC=%src%!"
        REM type !srcRemoteDlc! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            REM if !nbPass! EQU 1 echo - injecting DLC
            REM !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "option batch on" "mkdir /storage_!src!/usr/title/0005000c/!endTitleIdFolder!" "option batch off" "exit"  > !ftplogFile! 2>&1
            REM REM : YES : import dlc in mlc01/usr/title/0005000c/!endTitleIdFolder! (minimized + no wait)
            REM wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! remote !dlcFolder! "/storage_%src%/usr/title/0005000c/!endTitleIdFolder!" "!name! (DLC)"
        REM )

        REM : get saves only the first pass
        if !nbPass! GTR 1 goto:endInject

        REM : search if this game has saves
        set "srcRemoteSaves=!remoteSaves:SRC=%src%!"
        type !srcRemoteSaves! | find "!endTitleIdFolder!" > NUL 2>&1 && (
            if not ["!userSavesToExport!"] == ["none"] (
                echo - injecting saves

                REM : Export Wii-U saves
                wscript /nologo !StartMaximizedWait! !exportWiiuSaves! "!wiiuIp!" "!GAME_TITLE!" !endTitleIdFolder! !src! !userSavesToExport!
            )
        )

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"

        echo ---------------------------------------------------------
        echo !GAME_TITLE! ^: ending at !DATE!
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        set "msg="!GAME_TITLE!: uploaded at !DATE!""
        call:log2GamesUploadFile !msg!

        :endInject

    goto:eof
    REM : ------------------------------------------------------------------

    :addGameSize
        set "gamefolder="%~1""
        set /A "totalGameSize=0"

        REM : compte the size using powershell (symlinks are taken into account)
        set "folder="!gamefolder:"=!\Code""
        call:getFolderSizeInMb !folder! sgCode
        set /A "totalMoNeeded+=!sgCode!"
        set /A "totalGameSize+=!sgCode!"

        set "folder="!gamefolder:"=!\Meta""
        call:getFolderSizeInMb !folder! sgMeta
        set /A "totalMoNeeded+=!sgMeta!"
        set /A "totalGameSize+=!sgMeta!"

        set "folder="!gamefolder:"=!\Content""
        call:getFolderSizeInMb !folder! sgContent
        set /A "totalMoNeeded+=!sgContent!"
        set /A "totalGameSize+=!sgContent!"

REM : (update and DLC can't be injected because some of thems use symlink to game's file on the wii-u file system)
REM : those links disappear with RPX format (dump or uncompress) and cannot be replaced by files (symlink failed to be downloaded by FTP)

        REM set "folder="!gamefolder:"=!\mlc01\usr\title\0005000e""
        REM if not exist !folder! goto:dlc

        REM call:getFolderSizeInMb !folder! sgUpdate
        REM set /A "totalMoNeeded+=!sgUpdate!"

        REM :dlc
        REM set "folder="!gamefolder:"=!\mlc01\usr\title\0005000c""
        REM if not exist !folder! goto:eof

        REM call:getFolderSizeInMb !folder! sgDlc
        REM set /A "totalMoNeeded+=!sgDlc!"
        REM set /A "totalGameSize+=!sgDlc!"

        echo size needed for !title! ^: !totalGameSize! Mb

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

    