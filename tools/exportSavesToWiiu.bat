@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Export CEMU saves to your Wii-U

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
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "ftpSyncFolders="!BFW_TOOLS_PATH:"=!\ftpSyncFolders.bat""

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
        exit /b 100
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

    set "endTitleId=NONE"

    REM : J2000 unix timestamp (/ J1970)
    set /A "j2000=946684800"

    REM : by default
    set "wiiuSaveMode=SYNCR"
    REM : read the configuration parameters for Wii-U saves (SYNCR/BOTH)
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "WII-U_SAVE_MODE=" 2^>NUL') do set "wiiuSaveMode=%%i"

    if %nbArgs% NEQ 0 goto:getArgsValue

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
    echo - have your SDCard plugged in your Wii-U
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

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck_estw.log""
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
    for /F "delims=~" %%i in ('dir /B /S meta.xml 2^> NUL ^|  find /I /V "\mlc01"') do (

        REM : meta.xml
        set "META_FILE="%%i""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%k""
        for /F "delims=<" %%j in (!titleLine!) do set /A "NB_GAMES+=1" && echo %%j >> !localTid!
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
    echo =========================================================
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit /b 11
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
    set "userSavesToExport="select""
    goto:treatments

    :getArgsValue
    if %nbArgs% NEQ 5 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" WIIU_IP_ADRESS GAME_TITLE ENDTITLEID SRC userSavesToExport
        echo given {%*}
        pause
        if %nbArgs% EQU 0 exit 9
        if %nbArgs% NEQ 0 exit /b 9
    )
    REM WII-U IO ADRESS (wll be check in ftpSyncFolders.bat
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
    REM : user to export saves during a game's injection.
    REM : values
    REM : - select => choose manually (value initialized when there is no args given)
    REM : - all => import all existing saves for all users
    REM : - !user! => import all existing saves for !user!
    set "userSavesToExport=!args[4]!"

    set "selectedTitles[0]=!GAME_TITLE!"
    set "selectedEndTitlesId[0]=!ENDTITLEID!"
    set "selectedtitlesSrc[0]=!src!"

    set "listGamesSelected=0"

    :treatments
    cls

    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""

    set "TMP_ULSAVE_PATH="!BFW_WIIU_FOLDER:"=!\ExportSave""
    if not exist !TMP_ULSAVE_PATH! mkdir !TMP_ULSAVE_PATH! > NUL 2>&1

    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""
    set "USERS_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
    if not exist !USERS_ACCOUNTS_FOLDER! (
        echo ERROR^: !USERS_ACCOUNTS_FOLDER! does not exist ^!^
        echo Use Wii-U Games^\Wii-U^\Get online files^.lnk
        echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
        echo before this script
        pause
        if %nbArgs% EQU 0 exit 99
        if %nbArgs% NEQ 0 exit /b 99

    )

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    pushd !TMP_ULSAVE_PATH!

    for /L %%n in (0,1,!nbGamesSelected!) do call:exportSaves %%n
    echo =========================================================
    echo Now you can stop FTPiiU server
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

    :exportSaves

        set /A "num=%~1"

        REM : set GAME_TITLE (used for naming user's rar file)
        set "GAME_TITLE=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        REM : cd to codeFolder
        pushd !codeFolder!
        set "RPX_FILE="project.rpx""
	    REM : get bigger rpx file present under game folder
        if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : create remotes folders
        call:createRemoteFolders
        set "cemuSaveFolder="!TMP_ULSAVE_PATH:"=!\mlc01\usr\save\00050000\%endTitleId%""
        set "metaFolder="!cemuSaveFolder:"=!\meta""
        set "saveinfo="!metaFolder:"=!\saveinfo.xml""

        echo =========================================================
        echo Export CEMU saves of !GAME_TITLE! to the Wii-U
        echo =========================================================

        REM : (re) compute GAME_FOLDER_PATH (in function of the presence of args or not)
        set "GAME_FOLDER_PATH="!GAMES_FOLDER:"=!\!GAME_TITLE!""

        REM : download meta folder from the wii-U
        wscript /nologo !StartHiddenWait! !ftpSyncFolders! !wiiuIp! local !metaFolder! "/storage_!src!/usr/save/00050000/!endTitleIdFolder!/meta" "save meta folder"

        set /A "nbUsersTreated=0"
        REM : get BatchFw users list
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "user="%%i""
            set "currentUser=!user:"=!"

            set "pat="!USERS_ACCOUNTS_FOLDER:"=!\!currentUser!*.dat""
            set "folder=NONE"
            for /F "delims=~" %%j in ('dir /B !pat! 2^>NUL') do (
                set "filename="%%j""
                set "noext=!filename:.dat=!"
                set "folder=!noext:%%i=!"
                set "folder=!folder:"=!"
            )
            if ["!folder!"] == ["NONE"] (
                echo WARNING^: no account associated with user %%i
            ) else (
                REM : export saves (if asked)
                if not [!userSavesToExport!] == ["none]" call:exportSavesForCurrentAccount
            )
            pushd !GAMES_FOLDER!
        )


        echo Transfert saves for !GAME_TITLE!^.^.^.
        echo ---------------------------------------------------------

        REM : launching transfert
        call !ftpSyncFolders! !wiiuIp! remote !cemuSaveFolder! "/storage_!src!/usr/save/00050000/!endTitleId!" "Export !GAME_TITLE! saves for !currentUser! to Wii-U"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            echo ERROR when exporting existing saves for !currentUser! ^!
            rmdir /Q /S !cemuUserSaveFolder! > NUL 2>&1
            if %nbArgs% EQU 0 pause && exit 51
            exit /b 51
        )

        REM : log the slot used in a file
        echo !DATE! ^: !currentUser! CEMU saves for !GAME_TITLE! were copied on your Wii-U

        REM : delete user's save folder just extracted
        set "userMlc01Folder="!TMP_ULSAVE_PATH:"=!\mlc01""
        rmdir /Q /S !userMlc01Folder! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :getTs1970

        set "arg=%~2"

        set "ts="
        if not ["!arg!"] == [""] set "ts=%arg%"

        REM : if ts is not given : compute timestamp of the current date
        if ["%ts%"] == [""] for /F "delims=~= tokens=2" %%t in ('wmic os get localdatetime /value') do set "ts=%%t"

        set /A "yy=10000%ts:~0,4% %% 10000, mm=100%ts:~4,2% %% 100, dd=100%ts:~6,2% %% 100"
        set /A "dd=dd-2472663+1461*(yy+4800+(mm-14)/12)/4+367*(mm-2-(mm-14)/12*12)/12-3*((yy+4900+(mm-14)/12)/100)/4"
        set /A "ss=(((1%ts:~8,2%*60)+1%ts:~10,2%)*60)+1%ts:~12,2%-366100-%ts:~21,1%((1%ts:~22,3%*60)-60000)"

        set /A "%1+=dd*86400"

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

    REM : number to hexa with 16 digits
    :num2hex

        set /a "num = %~1"
        set "hex="
        set "hex.10=a"
        set "hex.11=b"
        set "hex.12=c"
        set "hex.13=d"
        set "hex.14=e"
        set "hex.15=f"

        :loop
        set /a "hextmp = num %% 16"
        if %hextmp% gtr 9 set hextmp=!hex.%hextmp%!
        set /a "num /= 16"
        set "hex=%hextmp%%hex%"
        if %num% gtr 0 goto loop

        :loop2
        call:strLength !hex! len
        if !len! LSS 16 set "hex=0!hex!" & goto:loop2

        set "%2=!hex!"

    goto:eof
    REM : ------------------------------------------------------------------

    :updateSaveInfoFile

        REM : init the value with now (J2000)
        call:getTs1970 now
        set /A "nowJ2K=!now!-j2000"
        call:num2hex !nowJ2K! hexValue

        REM : workaround to FTP everywhere issue on dating files (timestamp not handled and equal to 0)
        REM : set "hexValue=0000000000000000"

        set "stmp=!saveInfo!tmp"
        del /F !stmp! > NUL 2>&1

        REM : if exist saveInfo.xml check if !folder! exist in saveinfo.xml
        if exist !saveInfo! (
            REM : if the account is not present in saveInfo.xml
            type !saveInfo! | find /I "!folder!" > NUL 2>&1 && goto:updateSaveInfo
            REM : add it
            xml ed -s "//info" -t elem -n "account persistentId=""!folder!""" !saveInfo! > !stmp!
            xml ed -s "//info/account[@persistentId='!folder!']" -t elem -n "timestamp" -v "!hexValue!" !stmp! > !saveInfo!
            del /F !stmp! > NUL 2>&1
            goto:eof

            :updateSaveInfo
            REM : else update it

            xml ed -u "//info/account[@persistentId='!folder!']/timestamp" -v "!hexValue!" !saveInfo! > !stmp!
            if !ERRORLEVEL! EQU 0 del /F !saveInfo! > NUL 2>&1 & move /Y !stmp! !saveInfo! > NUL 2>&1
            del /F !stmp! > NUL 2>&1
            goto:eof
        )
        REM : if saveinfo.xml does not exist
        echo ^<^?xml version=^"1^.0^" encoding=^"UTF-8^"^?^>^<info^>^<account persistentId=^"!folder!^"^>^<timestamp^>!hexValue!^<^/timestamp^>^<^/account^>^<^/info^> > !saveInfo!

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

    REM : must run in !igsvf! !
    :getCemuUserSave
        REM : initialize with CEMU default save
        set "%1=!rarFile!"

        for /F "delims=~" %%i in ('type !userActiveSlotFile! 2^>NUL') do set "activeSave="%%i""

        if not exist !activeSave! goto:eof

        REM : activeSave = !GAME_TITLE!_!currentUser!_slot%slotNumber%.rar""
        set "activeTextFile=!activeSave:.rar=.txt!"

        set "str=!activeSave:"=!"
        set "str=!str:~-5!"
        set /A "slotNumber=!str:.rar=!"

        for /F "delims=~" %%i in ('type !activeTextFile! 2^>NUL') do set "slotLabel="%%i""
        REM : avoid Wii-U slots
        echo !slotLabel! | find "Wii-U import" > NUL 2>&1 && goto:eof
        echo Use the slot!slotNumber! [!slotLabel:"=!] for !currentUser!

        set "%1=!activeSave!"


    goto:eof
    REM : ------------------------------------------------------------------

    REM : search for last slot or create one (BOTH mode)
    :getWiiUSlot
        REM : initialize with CEMU default save
        set "%1=!rarFile!"

        REM : check if slots are defined
        set "userActiveSlotFile="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_activeSlot.txt""

        if exist !userActiveSlotFile! (

            REM : search for last slots used with a label containing "Wii-U import"
            set "pat="!inGameSavesFolder:"=!\!GAME_TITLE!_!currentUser!_slot*.txt""


            for /F "delims=~" %%i in ('dir /S /B /O:D !pat!') do (
                findstr /S /I "Wii-U import" "%%i" > NUL 2>&1 && (
                    REM : found the first slot used for Wii-U import
                    set "slotLabelFile="%%i""
                    set "slotFile=!slotLabelFile:.txt=.rar!"

                    if exist !slotFile! (
                        REM : activate it
                        attrib -R !userActiveSlotFile! > NUL 2>&1
                        echo !slotFile!>!userActiveSlotFile!
                        attrib +R !userActiveSlotFile! > NUL 2>&1

                        set "%1=!slotFile!"
                        goto:eof
                    )
                )

            )
        )


        if [!wiiuSaveMode!] == ["BOTH"] (
            REM : get and activate OR create a slots for Wii-U save

            REM : if not found, create a new extra slot and activate it
            call !setExtraSavesSlots! !currentUser! !GAME_FOLDER_PATH! "Wii-U import"

            REM : get the last modified save for currentUser
            set "lastSlot="NONE""
            call:getLastModifiedSaveFile lastSlot
            if exist !lastSlot! set "%1=!lastSlot!"
            goto:eof
        )

        REM : SYNCR
        if exist !userActiveSlotFile! (

            set "igsvf="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves"
            pushd !igsvf!
            set "lastSlot="NONE""
            call:getCemuUserSave lastSlot
            if exist !lastSlot! set "%1=!lastSlot!"

            pushd !GAMES_FOLDER!
            goto:eof
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :exportSavesForCurrentAccount

        REM : for the current user : extract rar file in TMP_ULSAVE_PATH
        set "rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!currentUser!.rar""

        if not exist !rarFile! (
            echo No CEMU saves were found for !currentUser!
            goto:eof
        )

        if not [!userSavesToExport!] == ["all"] (

            if [!userSavesToExport!] == ["select"] (
                choice /C yn /N /M "Upload !currentUser! saves on Wii-U (y, n)? : "
                if !ERRORLEVEL! EQU 2 goto:eof
            ) else (
                REM : here userSavesToExport define a user name
                if not [!userSavesToExport!] == ["!currentUser!"] goto:eof
            )
        )

        call:getWiiUSlot lastSlot
        if not [!lastSlot!] == ["NONE"]  set "rarFile=!lastSlot!"

        REM : treatment for the user
        echo Treating !currentUser! ^(!folder!^)

        REM extract the CEMU saves for current user
        wscript /nologo !StartHiddenWait! !rarExe! x -o+ -inul -w!BFW_LOGS! !rarFile! !TMP_ULSAVE_PATH! > NUL 2>&1

        REM : CEMU 80000001 folder for the current user
        set "cemuUserSaveFolder="!cemuSaveFolder:"=!\user\80000001""
        set "wiiuUserSaveFolder="!cemuSaveFolder:"=!\user\!folder:"=!""
        if exist !wiiuUserSaveFolder! rmdir /Q /S !wiiuUserSaveFolder! > NUL 2>&1
        move /Y !cemuUserSaveFolder! !wiiuUserSaveFolder! > NUL 2>&1

        REM : cd to BFW_RESOURCES_PATH to use xml.exe
        pushd !BFW_RESOURCES_PATH!

        REM : update saveinfo file
        call:updateSaveInfoFile

        pushd !GAMES_FOLDER!

        REM : BatchFw use only one account (the same for all users = 80000001)
        REM : => never treat the common folder => remove it
        set "commonUserSaveFolder="!cemuSaveFolder:"=!\user\!folder:"=!""
        if exist !commonUserSaveFolder! (
            REM : remove it before the transfert
            rmdir /Q /S !commonUserSaveFolder! > NUL 2>&1

            REM : no need to update the saveinfo.xml
        )


        set /A "nbUsersTreated+=1"
    goto:eof
    REM : ------------------------------------------------------------------

    :createRemoteFolders
        set "ftplogFile="!TMP_ULSAVE_PATH:"=!\ftpCheck.log""
        !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "mkdir /storage_!src!/usr/save/00050000/!endTitleId!" "exit"  > !ftplogFile! 2>&1

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
