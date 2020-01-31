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
    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "replaceFolders="!BFW_TOOLS_PATH:"=!\ftpReplaceFolders.bat""
    set "exportWiiuSaves="!BFW_TOOLS_PATH:"=!\exportSavesToWiiu.bat""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

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

    set "endTitleId=NONE"
    if %nbArgs% NEQ 0 goto:getArgsValue

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
    echo - if you^'re using a permanent hack ^(CBHC^)^:
    echo    ^* launch HomeBrewLauncher
    echo    ^* then ftp-everywhere for CBHC
    echo - if you^'re not^:
    echo    ^* first run Mocha CFW HomeBrewLauncher
    echo    ^* then ftp-everywhere for MOCHA
    echo.
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
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    REM : and teh port
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"

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

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck.log""
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before FTP_every_where on the Wii-U
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

        set "titleFst="!GAME_FOLDER_PATH:"=!\code\title.fst
        set "titletmd="!GAME_FOLDER_PATH:"=!\code\title.tmd

        REM : list game only if title.* files exist
        if exist !titleFst! if exist !titletmd!
            set "zeroSizedFilesReport="!GAME_FOLDER_PATH:"=!\Cemu\zeroSizedFilesFromDump.txt""
            if exist !zeroSizedFilesReport! type !zeroSizedFilesReport! | find "Dump is valid" > NUL 2>&1 && set /A "NB_GAMES+=1" & echo %%j >> !localTid!
            if not exist !zeroSizedFilesReport! set /A "NB_GAMES+=1" & echo %%j >> !localTid!
        )
    )

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "gamesList="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\gamesList.csv""

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

    set /P "listGamesSelected=Please enter game's numbers list (separate with a space): "
    call:checkListOfIntegers !listGamesSelected! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo Invalid numbers or forbiden characters found^, please retry
        pause
        goto:getList
    )

    call:checkListOfGames !listGamesSelected!

    if !ERRORLEVEL! NEQ 0 goto:getList
    echo ---------------------------------------------------------
    choice /C ync /N /M "Continue (y, n) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit 98
    if !ERRORLEVEL! EQU 2 goto:getList

    cls
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit 11
    )
    set /A "nbGamesSelected-=1"

    pushd !GAMES_FOLDER!
    REM : use the endTitleId to get GAME_FOLDER_PATH and mostly the GAME_TITLE (if you have renamed it after the dump)

    REM : Loop on the game selected
    for /L %%i in (0,1,!nbGamesSelected!) do (
    REM : get the endTitleId
        set "endTitleId=!selectedEndTitlesId[%%i]!"
        call:updateTitle %%i
    )

    goto:treatments

    :getArgsValue
    if %nbArgs% NEQ 4 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" WIIU_IP_ADRESS GAME_TITLE ENDTITLEID SRC
        echo given {%*}
        pause
        if %nbArgs% EQU 0 exit 9
        if %nbArgs% NEQ 0 exit /b 9
    )
    REM WII-U IO ADRESS (wll be check in ftpReplaceFolders.bat
    set "wiiuIp=!args[0]!"

    REM : get GAME_TITLE
    set "GAME_TITLE=!args[1]!"
    set "GAME_TITLE=!GAME_TITLE:"=!"

    REM : get ENDTITLEID
    set "ENDTITLEID=!args[2]!"
    set "ENDTITLEID=!ENDTITLEID:"=!"

    REM : get and check src
    set "src=!args[3]!"
    set "src=!src:"=!"
    if not ["!src!"] == ["mlc"] if not ["!src!"] == ["usb"] (
        echo ERROR^: !src! is not a valid storage source ^^!
        if %nbArgs% EQU 0 exit 3
        if %nbArgs% NEQ 0 exit /b 3
    )

    set "selectedTitles[0]=!GAME_TITLE!"
    set "selectedEndTitlesId[0]=!ENDTITLEID!"
    set "selectedtitlesSrc[0]=!src!"

    set "listGamesSelected=0"

    :treatments
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

    for /L %%n in (0,1,!nbGamesSelected!) do (
        set "GAME_TITLE=!selectedTitles[%%i]!"
        set "endTitleIdFolder=!selectedEndTitlesId[%%i]!"

        REM : define local folders
        set "sourceFolder="!GAMES_FOLDER:"=!\!GAME_TITLE!""
        set "codeFolder="!sourceFolder:"=!\code""
        set "contentFolder="!sourceFolder:"=!\content""
        set "metaFolder="!sourceFolder:"=!\meta""
        set "updateFolder="!sourceFolder:"=!\mlc01\usr\title\0005000e\!endTitleIdFolder!""
        set "dlcFolder="!sourceFolder:"=!\mlc01\usr\title\0005000c\!endTitleIdFolder!""

        call:injectGame !selectedtitlesSrc[%%n]!
    )
    echo =========================================================
    echo Now you can stop FTPiiU server and launch SaveMii to
    echo import your save^(s^) for your game^(s^)
    echo.
    
    if %nbArgs% EQU 0 pause
    if !ERRORLEVEL! NEQ 0 timeout /T 3 > NUL 2>&1

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
        REM : init to none
        set "%1=none"

        :askSavesMode
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

        set "TMP_ULSAVE_PATH="!BFW_WIIU_FOLDER:"=!\SaveMii""
        set "gslog="!TMP_ULSAVE_PATH:"=!\ExportSaveMii_GAME_TITLE.log""
        echo To know which SaveMii slots were filled^, check the log files
        echo created for each games as !gslog!
        echo.

        choice /C yn /N /M "Do you want to export Wii-U saves during the process (y, n)? : "
        if !ERRORLEVEL! EQU 2 goto:eof

        choice /C yn /N /M "For all users (y, n)? : "
        if !ERRORLEVEL! EQU 1 set "%1=all" & goto:eof

        choice /C yn /N /M "Do you want to choose a user now  (y, n = select users during process)? : "
        if !ERRORLEVEL! EQU 2 set "%1=select" & goto:eof

        for /L %%i in (0,1,!nbUsers!) do echo %%i ^: !USERSARRAY[%%i]!

        echo.
        :askUser
        set /P "num=Enter the BatchFw user's number [0, !nbUsers!] : "

        echo %num% | findStr /RV "^[0-9]*.$" > NUL 2>&1 && goto:askUser

        if %num% LSS 0 goto:askUser
        if %num% GTR %nbUsers% goto:askUser

        set "%1=!USERSARRAY[%num%]!"
    goto:eof
    REM : ------------------------------------------------------------------

    :updateTitle

        set "num=%~1"

        REM : searching for meta file
        for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^| find /I /V "\mlc01"') do (

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

    REM : check list of games and create selection
    :checkListOfGames

        echo ---------------------------------------------------------
        echo Inject valid dump for ^:
        echo.
        for %%l in (!listGamesSelected!) do (
            if %%l GEQ !nbGames! exit /b 1
            echo - !titles[%%l]!
            set "selectedTitles[!nbGamesSelected!]=!titles[%%l]!"
            set "selectedEndTitlesId[!nbGamesSelected!]=!endTitlesId[%%l]!"
            set "selectedtitlesSrc[!nbGamesSelected!]=!titlesSrc[%%l]!"

            set /A "nbGamesSelected+=1"
            )
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------

    REM : check list of integers
    :checkListOfIntegers
        set "list="%~1""

        for %%l in (!list!) do (
            echo %%l | findStr /RV "^[0-9]*.$" > NUL 2>&1 && exit /b 1
            if %%l GEQ %nbGames% exit /b 2
        )
        exit /b 0

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

        :exportGame
        REM : Import the game (minimized + no wait)
        wscript /nologo !StartMinimized! !replaceFolders! !wiiuIp! remote !codeFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/code" "!name! (code)"

        wscript /nologo !StartMinimized! !replaceFolders! !wiiuIp! remote !contentFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/content" "!name! (content)"

        wscript /nologo !StartMinimized! !replaceFolders! !wiiuIp! remote !metaFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/meta" "!name! (meta)"

        if !nbPass! GTR 1 goto:waitingLoop

        echo Waiting end of all current transferts^.^.^.
        echo.
        :waitingLoop
        REM : wait all transfert end
        timeout /T 1 > NUL 2>&1
        wmic process get Commandline 2>NUL | find /I "WinSCP.exe" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && timeout /T 2 > NUL 2>&1 && goto:waitingLoop

        REM : search if this game has an update
        set "srcRemoteUpdate=!remoteUpdates:SRC=%src%!"
        type !srcRemoteUpdate! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            if !nbPass! EQU 1 echo - injecting update

            REM : YES : import update in mlc01/usr/title (minimized + no wait)
            wscript /nologo !StartMinimized! !replaceFolders! !wiiuIp! local !updateFolder! "/storage_%src%/usr/title/0005000e/!endTitleIdFolder!" "!name! (update)"
        )
        REM : search if this game has a DLC
        set "srcRemoteDlc=!remoteDlc:SRC=%src%!"
        type !srcRemoteDlc! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            if !nbPass! EQU 1 echo - injecting DLC

            REM : YES : import dlc in mlc01/usr/title/0005000c/!endTitleIdFolder! (minimized + no wait)
            wscript /nologo !StartMinimized! !replaceFolders! !wiiuIp! local !dlcFolder! "/storage_%src%/usr/title/0005000c/!endTitleIdFolder!" "!name! (DLC)"
        )

        REM : get saves only the first pass
        if !nbPass! GTR 1 goto:endInject

        echo Waiting end of all current transferts^.^.^.
        echo.
        :waitingLoop2
        REM : wait all transfert end
        timeout /T 1 > NUL 2>&1
        wmic process get Commandline | find /I "WinSCP.exe" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && timeout /T 2 > NUL 2>&1 && goto:waitingLoop2

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

        echo !GAME_TITLE! ^: ending at !DATE!

        :endInject
        REM : list of zero sized file detected when dumping game
        set "zeroSizedFilesReport="!sourceFolder:"=!\Cemu\zeroSizedFilesFromDump.txt""
        echo - rebuilding symlinks

        REM : rebuild all symlinks on Wii-U file system
        call:rebuildRemoteLinks

    goto:eof

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
    REM : ------------------------------------------------------------------

    :rebuildRemoteLinks

        REM : recreate symlinks to game's folder on the Wii-U file system
        set "zeroSizedFilesReport="!sourceFolder:"=!\Cemu\zeroSizedFilesFromDump.txt""

        set "ftpGameLogFile="!BFW_PATH:"=!\logs\ftpCheck.log""
        set /A "nbi=0"
        for /F %%e in ('type !zeroSizedFilesReport! ^| find ">" 2^>NUL') do (

            set "line=%%e"
            set "winRelativePath=!line:>=!"
            set "linuxRelativePath=!winRelativePath:\=/!"

            set "linkPath="/storage_%src%/usr/title/!linuxRelativePath!"

            set "targetPath=!linkPath:0005000e=00050000!"
            set "targetPath=!targetPath:0005000c=00050000!"

            REM : here no need to create the folders because sync command as already did it

            wscript /nologo !startHidden! !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ln !targetPath! !linkPath!" "exit" > !ftpGameLogFile! 2>&1

            REM : limit to 8 simultaneous transfers
            set /A "nbI+=1"
            set /A "mul5=!nbI!%%8"
            if !mul5! EQU 0 (

                :waitingLoop
                REM : wait all transfert end
                timeout /T 1 > NUL 2>&1
                wmic process get Commandline 2>NUL | find /I "WinSCP.exe" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && timeout /T 1 > NUL 2>&1 && goto:waitingLoop
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
            echo Host char codeSet not found ^?^, exiting 1
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

    