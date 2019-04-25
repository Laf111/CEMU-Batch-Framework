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
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    
    REM : set current char codeset
    call:setCharSet

    REM : create folders 
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\onlineFiles""

    cls

    REM : create folders 
    set "BFW_ONLINE_FOLDER="!GAMES_FOLDER:"=!\_BatchFW_WiiU\onlineFiles""
    if not exist !BFW_ONLINE_FOLDER! mkdir !BFW_ONLINE_FOLDER! > NUL
    
    @echo =========================================================
    @echo Get online files from your Wii-U
    @echo =========================================================
    @echo.
    set "f1="!BFW_ONLINE_FOLDER:"=!\otp.bin""
    set "f2="!BFW_ONLINE_FOLDER:"=!\seeprom.bin""
    if exist !f1! if exist !f2! goto:beginProcess
    
    @echo First^, you have to use NandDumper to get otp.bin and seeprom.bin 
    @echo and copy them manually in !BFW_ONLINE_FOLDER!    
    @echo.
    @echo Consult the pinned guide on Cemu^'s reddit to know how    
    @echo Press any key to continue to exit
    pause
    exit 99
    
    :beginProcess
        
    @echo Make sure the Wii U account you want to dump^/use has 
    @echo the "Save password" option checked ^(auto login^) ^!
    @echo.
    @echo.
    
    set "WinScpFolder="!BFW_RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    if not exist !winScpIni! goto:getWiiuIp
    
    REM : get the hostname
    for /F "delims== tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    REM : and teh port
    for /F "delims== tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"
    
    @echo Found an existing configuration ^:
    @echo.
    @echo PortNumber=!ipRead!
    @echo HostName=!portRead!
    @echo.
    choice /C yn /N /M "Use this setup (y, n)? : "
    if !ERRORLEVEL! EQU 1 set "wiiuIp=!ipRead!" && goto:checkConnection

    :getWiiuIp    
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
    set /P "wiiuIp=Please enter your Wii-U local IP adress : "
    set /P "port=Please enter the port used : "
        
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    
    
    REM : prepare winScp.ini file
    copy /Y  !winScpIniTmpl! !winScpIni! > NUL
    set "fnrLog="!BFW_PATH:"=!\logs\fnr_WinScp.log""
    
    REM : set WiiU ip adress
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-IP" --replace "!wiiuIp!" --logFile !fnrLog!
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-port" --replace "!port!" --logFile !fnrLog!

    :checkConnection
    curl -s !wiiuIp! > NUL
    if !ERRORLEVEL! NEQ 0 (
        @echo ERROR^: unable to connect to !wiiuIp!^, check if FTP server is running on the WII-U
        pause
        exit 2
    ) 
    set "ftplogFile="!BFW_PATH:"=!\logs\ftpCheck.log""

    !WinScp! /session "USER@!wiiuIp!" /command "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "failed to retrieve directory listing" && (
        @echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before FTP_every_where on the Wii-U
        @echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    cls
    
    set "CCERTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\ccerts""
    if not exist !CCERTS_FOLDER! mkdir !CCERTS_FOLDER! > NUL

    set "SCERTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\scerts""
    if not exist !SCERTS_FOLDER! mkdir !SCERTS_FOLDER! > NUL

    set "MIIH_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10056000""
    if not exist !MIIH_FOLDER! mkdir !MIIH_FOLDER! > NUL

    set "JFL_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001500A""
    if not exist !JFL_FOLDER! mkdir !JFL_FOLDER! > NUL

    set "UFL_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001510A""
    if not exist !UFL_FOLDER! mkdir !UFL_FOLDER! > NUL

    set "EFL_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001520A""
    if not exist !EFL_FOLDER! mkdir !EFL_FOLDER! > NUL

    set "ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\mlc01\usr\save\system\act\80000001""
    if not exist !ACCOUNTS_FOLDER! mkdir !ACCOUNTS_FOLDER! > NUL

    set "WIIU_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\wiiuAccounts\usr\save\system\act""
    if not exist !WIIU_ACCOUNTS_FOLDER! mkdir !WIIU_ACCOUNTS_FOLDER! > NUL  
        
    @echo Launching FTP transferts^.^.^.

    REM : run ftp transferts ^: 
    @echo - CCERTS
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!CCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/ccerts" "exit"
    @echo - SCERTS
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!SCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/scerts" "exit"
    @echo - MIIs Head
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!MIIH_FOLDER!" /storage_mlc/sys/title/0005001b/10056000" "exit"
    @echo - Friend list
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!JFL_FOLDER!" /storage_mlc/sys/title/00050030/1001500A" "exit"
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!UFL_FOLDER!" /storage_mlc/sys/title/00050030/1001510A" "exit"
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!EFL_FOLDER!" /storage_mlc/sys/title/00050030/1001520A" "exit"
    @echo - WII-U accounts
    !winScp! /session "USER@!wiiuIp!" /command "synchronize local "!WIIU_ACCOUNTS_FOLDER!" /storage_mlc/usr/save/system/act" "exit"

    @echo Waiting for all transfert end^.^.^.

    REM : wait all transfert end
    :waitingLoop
    timeout /T 1 > NUL
    for /F "delims=" %%j in ('wmic process get Commandline ^| find /I /V "wmic" ^| find /I "winScp.com" ^| find /I /V "find"') do (
        goto:waitingLoop
    )

    @echo All transferts done

    REM : check if files found under JFL_FOLDER, if not files are presents, delete the folder
    REM : use tools\getMyShaderCachesSize.bat:getFolderSize

    call:getFolderSize !JFL_FOLDER! folderSize
    if !folderSize! EQU 0 rmdir /Q /S !JFL_FOLDER!

    call:getFolderSize !EFL_FOLDER! folderSize
    if !folderSize! EQU 0 rmdir /Q /S !EFL_FOLDER!

    call:getFolderSize !UFL_FOLDER! folderSize
    if !folderSize! EQU 0 rmdir /Q /S !UFL_FOLDER!

    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    
    REM : associate BatchFw's users to Wii-U accounts
    set "setAccountToUsers="!BFW_TOOLS_PATH:"=!\setWiiuAccountToUsers.bat""
    call !setAccountToUsers!
    
    
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
