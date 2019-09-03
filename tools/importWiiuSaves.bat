@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : When called with args, this script treat ONLY ONE game at the time
REM : When called without, it use the last Wii-U scan and treat only ALL
REM : games that exist in local AND remote locations

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        if %nbArgs% EQU 0 exit 1
        if %nbArgs% NEQ 0 exit /b 1
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
    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""

    set "ftpReplaceFolders="!BFW_TOOLS_PATH:"=!\ftpReplaceFolders.bat""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    if %nbArgs% NEQ 0 goto:getArgsValue

    title Import CEMU saves to WiiU

    @echo =========================================================
    @echo Import Wii-U saves to CEMU
    @echo =========================================================
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

    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    if not exist !winScpIni! goto:getWiiuIp

    REM : get the hostname
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    REM : and teh port
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"

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
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-IP" --replace "!wiiuIp!" --logFile !fnrLog! > NUL
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-port" --replace "!port!" --logFile !fnrLog! > NUL

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
        set "scanNow="!BFW_TOOLS_PATH:"=!\scanWiiU.bat""
        call !scanNow! !wiiuIp!
        set /A "noOldScan=1"
        goto:scanMyWii
    )
    cls
    if !noOldScan! EQU 1 goto:getLocalTitleId

    @echo The last WiiU^'s scan found is !LAST_SCAN!
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
    for /F "delims=~" %%i in ('dir /B /S meta.xml ^|  find /I /V "\mlc01" 2^> NUL') do (

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
    REM create a log file containing all your games titleId
    set "localTid="!BFW_WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\localTitleIds.log""

    set /A "nbGames=0"

    cls
    @echo =========================================================

    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "title"') do (

        set "second=%%j"
        set "endTitleId=!second:'=!"

        REM : if the game is also installed on your PC
        type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (
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
    call:checkListOfIntegers !listGamesSelected! > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        @echo Invalid numbers or forbiden characters found^, please retry
        pause
        goto:getList
    )
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

    pushd !GAMES_FOLDER!
    REM : use the endTitleId to get GAME_FOLDER_PATH and mostly the GAME_TITLE used for naming rar file !
    REM : update titles[0-!nbGames!]

    REM : Loop on the game selected
    for /L %%i in (0,1,!nbGamesSelected!) do (
    REM : get the endTitleId
        set "endTitleId=!selectedEndTitlesId[%%i]!"

        call:updateTitle %%i
    )

    goto:treatments

    :getArgsValue
    if %nbArgs% NEQ 4 (
        @echo ERROR on arguments passed ^(%nbArgs%^)
        @echo SYNTAX^: "!THIS_SCRIPT!" WIIU_IP_ADRESS GAME_TITLE endTitleId src
        @echo given {%*}
        pause
        if %nbArgs% EQU 0 exit 9
        if %nbArgs% NEQ 0 exit /b 9
    )
    REM WII-U IO ADRESS (wll be check in ftpReplaceFolders.bat
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
        @echo ERROR^: !src! is not a valid storage source ^!
        if %nbArgs% EQU 0 exit 3
        if %nbArgs% NEQ 0 exit /b 3
    )

    set "selectedTitles[0]=!GAME_TITLE!"
    set "selectedEndTitlesId[0]=!endTitleId!"
    set "selectedtitlesSrc[0]=!src!"

    set /A "nbGamesSelected=1"

    :treatments
    cls

    REM : online files folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""

    set "USERS_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
    if not exist !USERS_ACCOUNTS_FOLDER! (
        @echo ERROR^: !USERS_ACCOUNTS_FOLDER! does not exist ^!
        @echo Use Wii-U Games^\Wii-U^\Get online files^.lnk
        @echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
        @echo before this script
        pause
        if %nbArgs% EQU 0 exit 99
        if %nbArgs% NEQ 0 exit /b 99

    )

    for /L %%n in (0,1,!nbGamesSelected!) do call:importSaves %%n
    @echo =========================================================
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

    :updateTitle

        set "num=%~1"

        REM : searching for meta file
        for /F "delims=~" %%i in ('dir /B /S meta.xml ^| find /I /V "\mlc01"') do (

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

        @echo ---------------------------------------------------------
        @echo Import saves for ^:
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

    REM : check list of integers
    :checkListOfIntegers
        set "list="%~1""

        for %%l in (!list!) do (
            if %%l GEQ %nbGames% exit /b 2
        )
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------

    :importSaves
        set /A "num=%~1"

        REM : set GAME_TITLE (used for naming user's rar file)
        set "GAME_TITLE=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        @echo =========================================================
        @echo Import saves for !GAME_TITLE! ^(%endTitleId%^)
        @echo Source location ^: ^/storage_!src!
        @echo =========================================================

        REM : (re) compute GAME_FOLDER_PATH (in function of the presence of args or not)
        set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!GAME_TITLE!""

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
        set "DATE=%ldt%"

        REM : temporary folder where recreated the Wii-U save
        set "TMP_DLSAVE_PATH="!GAMES_FOLDER:"=!\_BatchFw_WiiU\ImportSave_!DATE!""

        set "localFolder="!TMP_DLSAVE_PATH:"=!\mlc01\usr\save\00050000\!endTitleId!""

        REM : launching transfert
        call !ftpReplaceFolders! !wiiuIp! local !localFolder! "/storage_!src!/usr/save/00050000/!endTitleId!" "!GAME_TITLE! (saves)"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            @echo ERROR when downloading existing saves ^!
            pause
            exit /b 50
        )

        set "localFolderUser="!localFolder:"=!\user""
        if not exist !localFolderUser! (
            @echo WARNING ^: no saves found for !GAME_TITLE!
            rmdir /Q /S !TMP_DLSAVE_PATH! > NUL 2>&1
            goto:eof
        )        
        REM : creates saves for each users
        call:createUsersSaves

        @echo ---------------------------------------------------------

        pushd !GAMES_FOLDER!
        rmdir /Q /S !TMP_DLSAVE_PATH! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    :createUsersSaves

        set "accountEntries="""

        set "localFolderMeta="!localFolder:"=!\meta""

        REM : replace the saveinfo.xml
        set "saveInfo="!localFolderMeta:"=!\saveinfo.xml""

        REM : get BatchFw users list
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%i""

            set "pat="!USERS_ACCOUNTS_FOLDER:"=!\%%i*.dat""
            set "folder=NONE"
            for /F "delims=~" %%j in ('dir /B !pat!') do (
                set "filename="%%j""
                set "noext=!filename:.dat=!"
                set "folder=!noext:%%i=!"
                set "folder=!folder:"=!"
            )
            if ["!folder!"] == ["NONE"] (
                @echo WARNING^: no account associated with %%i
                @echo You should use Wii-U Games^\Wii-U^\Get online files^.lnk
                @echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
                @echo before this script
                goto:eof
            )

            REM : cd to user
            pushd !localFolderUser!
                
            if not exist !folder! (
                @echo WARNING ^: no Wii-U saves found for !user:"=!
                goto:eof
            )

            if %nbArgs% EQU 0 (
                choice /C yn /N /M "Import !user! saves from Wii-U (y, n)? : "
                if !ERRORLEVEL! EQU 2 goto:eof
            )
            set "inGameSaveFolder="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
            if not exist !inGameSaveFolder! mkdir !inGameSaveFolder! > NUL 2>&1

            REM : for the current user :
            set "rarFile="!inGameSaveFolder:"=!\!GAME_TITLE!_!user:"=!.rar""

            REM : backup the CEMU save
            set "rarFileCemu="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!user:"=!_Cemu_!DATE!.rar""
            if exist !rarFile! copy /Y !rarFile! !rarFileCemu! > NUL 2>&1

            REM : delete the user's save
            if exist !rarFile! del /F !rarFile! > NUL 2>&1

            cd !folder!
            REM : add the user's folder content, rename folder to 80000001 in the archive file
            !rarExe! a -ed -ap"mlc01\usr\save\00050000\%endTitleId%\user\80000001" -ep1 -r -inul !rarFile! * > NUL 2>&1

            cd ..
            REM : common folder
            if exist common (
                cd common
                !rarExe! a -ed -ap"mlc01\usr\save\00050000\%endTitleId%\user\common" -ep1 -r -inul !rarFile! * > NUL 2>&1
                cd ..
            )
            REM : cd to meta
            cd !localFolderMeta!

            REM : overwrite !saveInfo!
            echo ^<^?xml version=^"1^.0^" encoding=^"UTF-8^"^?^>^<info^>^<account persistentId=^"80000001^"^>^<timestamp^>0000000000000000^<^/timestamp^>^<^/account^>^<^/info^> > !saveInfo!

            REM : add the meta folder content
            !rarExe! a -ed -ap"mlc01\usr\save\00050000\%endTitleId%\meta" -ep1 -r -inul !rarFile! * > NUL 2>&1

        )
    goto:eof
    REM : ------------------------------------------------------------------


    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
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
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_OperatingSystem get Locale /value ^| find "="') do set "L0CALE_CODE=%%f"

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

