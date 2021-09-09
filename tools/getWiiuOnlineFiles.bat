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
    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

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

    REM : flag for Batch user creation from wiiU accounts (1 if arg given)
    set /A "useWiiuAccounts=0"
    if %nbArgs% EQU 0 goto:createFolders

    if %nbArgs% NEQ 1 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" -wiiuAccounts
        echo given {%*}
        pause
        exit /b 9
    )

    REM : get and check GAME_FOLDER_PATH
    set "str=!args[0]!"
    if not [!str!] == ["-wiiuAccounts"] (
        echo ERROR^: first arg is not -wiiuAccounts ^^!
        exit /b 1
    )

    set /A "useWiiuAccounts=1"

    :createFolders
    REM : create folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""

    REM : create folders
    if not exist !BFW_ONLINE_FOLDER! mkdir !BFW_ONLINE_FOLDER! > NUL 2>&1

    :checkBinFiles
    set "f1="!BFW_ONLINE_FOLDER:"=!\otp.bin""
    set "f2="!BFW_ONLINE_FOLDER:"=!\seeprom.bin""
    if exist !f1! if exist !f2! goto:beginProcess

    echo First^, you have to use NandDumper to get otp^.bin and seeprom^.bin
    
    echo.
    echo Consult the pinned guide on Cemu^'s reddit to know how
    echo Press any key to continue or CTRL^+C to exit
    pause

    :askOutputFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Browse to the folder containing those files"') do set "folder=%%b" && set "BUP_FOLDER=!folder:?= !"
    if [!BUP_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askOutputFolder
    )
    robocopy !BUP_FOLDER! !BFW_ONLINE_FOLDER! "otp.bin" > NUL 2>&1
    robocopy !BUP_FOLDER! !BFW_ONLINE_FOLDER! "seeprom.bin" > NUL 2>&1
    goto:checkBinFiles

    :beginProcess
    
    echo =========================================================
    echo Get online files from your Wii-U
    echo =========================================================
    echo.
    echo.
    echo To download files throught FTP^, on your Wii-U^ you need to ^:
    echo.
    echo - disable the sleeping^/shutdown features
    echo - launch WiiU FTP Server and press B to mount NAND paths
    echo - get the IP adress displayed on Wii-U gamepad
    echo.
    echo Make sure the Wii U account you want to dump^/use has
    echo the "Save password" option checked ^(auto login^) ^!
    echo.
    echo Press any key to continue when you^'re ready
    echo ^(CTRL-C^) to abort
    pause
    cls

    set "WIIU_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\wiiuAccounts\usr\save\system\act""
    if not exist !WIIU_ACCOUNTS_FOLDER! mkdir !WIIU_ACCOUNTS_FOLDER! > NUL 2>&1
       
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
    cls
    REM : check its state
    set /A "state=0"
    call:getHostState !wiiuIp! state

    if !state! EQU 0 (
        echo ERROR^: !wiiuIp! was not found on your network ^!
        echo exiting 2
        if %nbArgs% EQU 0 pause && exit 2
        if %nbArgs% NEQ 0 exit /b 2
    )

    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck_gwof.log""
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

    set "CCERTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\ccerts""
    if not exist !CCERTS_FOLDER! mkdir !CCERTS_FOLDER! > NUL 2>&1

    set "SCERTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\scerts""
    if not exist !SCERTS_FOLDER! mkdir !SCERTS_FOLDER! > NUL 2>&1

    set "MIIH_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10056000""
    if not exist !MIIH_FOLDER! mkdir !MIIH_FOLDER! > NUL 2>&1

    set "JFL_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001500A""
    set "UFL_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001510A""
    set "EFL_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001520A""

    set "ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\usr\save\system\act\80000001""
    if not exist !ACCOUNTS_FOLDER! mkdir !ACCOUNTS_FOLDER! > NUL 2>&1

    echo Launching FTP transferts^.^.^.

    REM : run ftp transferts ^:
    echo.
    echo ---------------------------------------------------------
    echo - CCERTS
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!CCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/ccerts" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - SCERTS
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!SCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/scerts" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - MIIs Head
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!MIIH_FOLDER!" /storage_mlc/sys/title/0005001b/10056000" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - Friend list
    echo ---------------------------------------------------------

    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001500A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:US
    )
    echo.
    echo found JPN one
    if not exist !JFL_FOLDER! mkdir !JFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!JFL_FOLDER!" /storage_mlc/sys/title/00050030/1001500A" "exit"

    :US
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001510A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:EU
    )
    echo.
    echo found USA one
    if not exist !UFL_FOLDER! mkdir !UFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!UFL_FOLDER!" /storage_mlc/sys/title/00050030/1001510A" "exit"

    :EU
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001520A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:compressMlc01
    )
    echo found EUR one
    if not exist !EFL_FOLDER! mkdir !EFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!EFL_FOLDER!" /storage_mlc/sys/title/00050030/1001520A" "exit"

    :compressMlc01
    set "BFW_MLC01_ONLINE_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01""
    set "mlc01OnlineFiles="!BFW_ONLINE_FOLDER:"=!\mlc01OnlineFiles.rar""

    wscript /nologo !StartHidden! !rarExe! u -ep1 -inul -w!BFW_LOGS! !mlc01OnlineFiles! !BFW_MLC01_ONLINE_FOLDER!

    echo.
    echo ---------------------------------------------------------
    echo - WII-U accounts
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!WIIU_ACCOUNTS_FOLDER!" /storage_mlc/usr/save/system/act" "exit"

    echo Waiting for all transfert end^.^.^.

    REM : wait all transfert end
    :waitingLoop
    timeout /T 1 > NUL 2>&1
    wmic process get Commandline 2>NUL | find ".exe" | find  /I "_BatchFW_Install" | find /I /V "wmic" | find /I "winScp.com" | find /I /V "find" > NUL 2>&1 && (
        goto:waitingLoop
    )

    echo All transferts done

    if !useWiiuAccounts! EQU 0 (
        REM : associate BatchFw's users to Wii-U accounts
        set "setAccountToUsers="!BFW_TOOLS_PATH:"=!\setWiiuAccountToUsers.bat""
        call !setAccountToUsers!
    ) else (
        echo ---------------------------------------------------------
        echo - Create BatchFw^' users from Wii-U players list
        echo ---------------------------------------------------------
        call:setUsersFromWiiu
    )
    
    if !ERRORLEVEL! NEQ 0 (
        if %nbArgs% EQU 0 exit 0
        if %nbArgs% NEQ 0 exit /b 0
    )

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    REM : remove DOS forbiden character from a string
   :secureUserNameForBfw
        set "str=%~1"

        REM : DOS reserved characters
        set "str=!str:&=!"
        set "str=!str:^!=!"
        set "str=!str:%%=!"

        REM : add . and ~
        set "str=!str:.=!"
        echo !str! | find "~" > NUL 2>&1 && (
            echo Please remove ~ ^(unsupported charcater^) from !str!
            exit /b 50
        )
        
        REM : Forbidden characters for files in WINDOWS
        set "str=!str:?=!"
        set "str=!str:\=!"
        set "str=!str:/=!"
        set "str=!str::=!"
        set "str=!str:"=!"
        set "str=!str:>=!"
        set "str=!str:<=!"
        set "str=!str:|=!"
        set "str=!str:^=!"

        echo !str! | find "*" > NUL 2>&1 && (
            echo Please remove * ^(unsupported charcater^) from !str!
            exit /b 50
        )
        echo !str! | find "=" > NUL 2>&1 && (
            echo Please remove = ^(unsupported charcater^) from !str!
            exit /b 50
        )

        set "%2=!str!"
        exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------


    :setUsersFromWiiu

        set "usersFolderAccount="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
        if  exist !usersFolderAccount! rmdir /Q /S !usersFolderAccount!
        mkdir !usersFolderAccount! > NUL 2>&1

        REM : loop on all 800000XX folders found
        pushd !WIIU_ACCOUNTS_FOLDER!
        for /F "delims=~" %%d in ('dir /B /A:D 800000* 2^>NUL') do (

            set "af="!WIIU_ACCOUNTS_FOLDER:"=!\%%d\account.dat""

            for /F "delims=~= tokens=2" %%n in ('type !af! ^| find /I "IsPasswordCacheEnabled=0"') do (
                echo WARNING^: this account seems to not have "Save password" option checked ^(auto login^) ^!
                echo it might be unusable with CEMU
                echo.
                echo Check "Save password" option for %%d account on the Wii-U and relaunch this script
                echo.
                pause
            )

            REM : get AccountId from account.dat
            set "accId=NONE"
            for /F "delims=~= tokens=2" %%n in ('type !af! ^| find /I "AccountId="') do set "accId=%%n"
            if ["%accId%"] == ["NONE"] (
                echo ERROR^: fail to parse !af!
                pause
            )
            REM : Ask for Batch's user
            echo Which batchFw^'s user use the accountId
            echo ^> !accId!
            echo on the Wii-U ^(folder^'s name is %%d^) ^?
            echo.

            call:getUser user
            set "currentUser=!user:"=!"

            set "msg="USER_REGISTERED=!currentUser!""
            call:log2HostFile !msg!

            REM : copy the file
            set "uf="!usersFolderAccount:"=!\!currentUser!%%d.dat""

            copy /Y !af! !uf! > NUL 2>&1
            echo saving %%d\account.dat to !uf!
            echo ---------------------------------------------------------
        )


    goto:eof
    REM : ------------------------------------------------------------------

    :getUser

        :askUser
        set /P "input=Please enter BatchFw's user name : "
        call:secureUserNameForBfw "!input!" safeInput
        if !ERRORLEVEL! NEQ 0 (
            echo ^~^, ^* or ^= are not allowed characters ^!
            echo Please remove them
            goto:askUser
        )

        if not ["!safeInput!"] == ["!input!"] (
            echo Some unhandled characters were found ^!
            echo list = ^^ ^| ^< ^> ^" ^: ^/ ^\ ^? ^. ^! ^& %%
            choice /C yn /N /M "Use !safeInput! instead ? (y,n): "
            if !ERRORLEVEL! EQU 2 goto:askUser
        )
        set "%1="!safeInput!""

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

    REM : function to log info for current host
   :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        REM : build a relative path in case of software is installed also in games folders
        echo msg=!msg! | find %BFW_PATH% > NUL 2>&1 && set "msg=!msg:%BFW_PATH:"=%=%%BFW_PATH:"=%%!"

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
    