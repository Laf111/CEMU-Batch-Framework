@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    REM : wiiu title keys Site
    set "wiiutitlekeysSite="http://wiiutitlekeys.altervista.org""

    set "THIS_SCRIPT=%~0"

    title Search and download a game
    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "JNUSFolder="!BFW_RESOURCES_PATH:"=!\JNUST""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "download="!BFW_TOOLS_PATH:"=!\downloadTitleId.bat""
    REM : output folder
    set "targetFolder=!GAMES_FOLDER!"

    REM : check if java is installed
    java -version > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: java is not installed^, exiting
        pause
        exit 50
    )

    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo ERROR^: no active network connection found^, exiting
        pause
        exit 51
    )
    
    REM : set current char codeset
    call:setCharSet
    
    set "titleKeysDataBase="!JNUSFolder:"=!\titleKeys.txt""
    if not exist !titleKeysDataBase! call:createKeysFile

    if not exist !titleKeysDataBase! (
        echo ERROR^: no keys file found^, exiting
        pause
        exit 52
    )

    :askKeyWord
    cls
    set /P  "pat=Enter a key word to search for the game (part of the title, titleId...): "
    echo.
    echo =========================== Matches ===========================
    REM : get userArray, choice args
    set /A "nbRes=0"
    set "titleIds="
    set "titleKeys="
    set "titles="
    set "regions="

    for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!pat!" ^| find /I "00050000" ^| find /I /V "Demo" 2^>NUL') do (
        set "titleIds[!nbRes!]=%%a"
        set "titleKeys[!nbRes!]=%%b"
        set "titles[!nbRes!]="%%c""
        set "regions[!nbRes!]=%%d"
        set /A "nbRes+=1"
        echo !nbRes! ^: %%c [%%d] %%a
    )

    echo ===============================================================
    echo s ^: to relaunch your search
    echo c ^: to cancel
    echo ---------------------------------------------------------------
    echo.
    :askChoice
    set /p "answer=Enter your choice : "

    if ["!answer!"] == ["s"] goto:askKeyWord
    if ["!answer!"] == ["c"] (
        echo.
        echo Cancelled by user
        pause
        exit 55
    )

    echo !answer! | findstr /R "^[0-9]*.$" > NUL 2>&1 && goto:checkInteger
    goto:askChoice

    :checkInteger
    set /A "index=answer-1"
    if !index! GEQ !nbRes! goto:askChoice

    set /A "decryptMode=0"

    title Download !titles[%index%]! [!regions[%index%]!]
    cls
    echo ===============================================================
    echo !titles[%index%]! [!regions[%index%]!] ^(!titleIds[%index%]!^)
    echo ===============================================================
    echo.
    echo Pay attention to the space remaining on the target device because
    echo there^'s no way to check it until all transferts end^!
    echo.
    echo You can download a WUP package for the game to be installed on
    echo your Wii-U using WUP Installer GX2^. You^'ll have to browse to the
    echo target location in this case ^(for example^: %%SD_CARD%%\install^)
    echo.
    echo If you choose to extract the game ^(for CEMU^)^, game will be
    echo extracted and prepared for emulation^.
    echo.
    choice /C yn /N /M "Extract games (= RPX format for CEMU)? :"
    if !ERRORLEVEL! EQU 1 set /A "decryptMode=1" && goto:begin

    :askOutputFolder
    set "targetFolder="NONE""
    for /F %%b in ('cscript /nologo !browseFolder! "Please, browse to the output folder"') do set "folder=%%b" && set "targetFolder=!folder:?= !"
    if [!targetFolder!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 1 > NUL 2>&1 && exit 75
        goto:askOutputFolder
    )

    REM : copy JNUSFolder content in !targetFolder!
    robocopy !JNUSFolder! !targetFolder! /S /IS /IT  > NUL 2>&1

    REM : override JNUSFolder path
    set "JNUSFolder=!targetFolder!"

    :begin
    cls
    echo ===============================================================
    echo Temporary folder ^: !JNUSFolder!
    echo ---------------------------------------------------------------
    set "titleKeysDataBase="!JNUSFolder:"=!\titleKeys.txt""
    set "jnusTool="!JNUSFolder:"=!\JNUSTool.jar""

    REM : download meta/meta.xml to get the title name
    pushd !JNUSFolder!

    java -jar JNUSTool.jar !titleIds[%index%]! !titleKeys[%index%]! -file /code/app.xml > NUL 2>&1

    REM : get the last modified folder in
    set "initialGameFolderName="NOT_FOUND""
    for /F "delims=~" %%x in ('dir /A:D /O:D /T:W /B * 2^>NUL') do set "initialGameFolderName="%%x""
    if [!initialGameFolderName!] == ["NOT_FOUND"] (
        echo ERROR^: failed to download meta^.xlm
        pause
        exit 60
    )
    set "gameFolderName=!initialGameFolderName:?=!"

    REM : secureGameTitle
    call:secureGameTitle !gameFolderName! gameFolderName
    echo "!gameFolderName!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!gameFolderName!) do set "gameFolderName="%%~nxi""

    if !decryptMode! EQU 0 (
        echo ^> Downloading WUP of !titles[%index%]! [!regions[%index%]!]^.^.^.
        title Downloading WUP of !titles[%index%]! [!regions[%index%]!]
    ) else (

        set "finalPath="!GAMES_FOLDER:"=!\!gameFolderName:"=!"

        if exist !finalPath! (
            echo ERROR^: Game already exist in !finalPath!^, exiting
            rmdir /Q /S !initialGameFolderName! > NUL 2>&1
            pause
            exit 61
        )

        echo ^> Downloading RPX package of !titles[%index%]! [!regions[%index%]!]^.^.^.
        title Downloading RPX package of !titles[%index%]! [!regions[%index%]!]
    )

    REM : download the game
    wscript /nologo !StartWait! !download! !JNUSFolder! !titleIds[%index%]! !decryptMode! !titleKeys[%index%]!

    REM : compute update and DLC titleId
    set "titleId=!titleIds[%index%]!"
    set "endTitleId=%titleId:~8,8%"

    set "utid=0005000e!endTitleId!"
    REM : if a update exist, download it
    type !titleKeysDataBase! | find /I "!utid!" > NUL 2>&1 && (
        echo ^> Downloading update found for !titles[%index%]! [!regions[%index%]!]^.^.^.
        wscript /nologo !StartWait! !download! !JNUSFolder! !utid! !decryptMode!
    )

    set "dtid=0005000c!endTitleId!"
    REM : if a DLC exist, download it
    type !titleKeysDataBase! | find /I "!dtid!" > NUL 2>&1 && (
        echo ^> Downloading DLC found !titles[%index%]! [!regions[%index%]!]^.^.^.
        wscript /nologo !StartWait! !download! !JNUSFolder! !dtid! !decryptMode!
    )

REM    REM : wait until all transferts are done
REM    :waitingLoop
REM    wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "downloadTitleId.bat" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
REM        timeout /T 1 > NUL 2>&1
REM        goto:waitingLoop
REM    )
    echo ===============================================================

    REM : update and DLC target folder names
    set "uName="!gameFolderName:"=! (UPDATE DATA)""
    set "dName="!gameFolderName:"=! (DLC)""

    if !decryptMode! EQU 0 (
        REM : WUP format (saved in tmp_%titleId% folder)

        set "folder=tmp_!titleId!"
        if not exist !folder! (
            echo ERROR^: failed to download !titleId!^?
            echo ERROR^: tmp_!titleId! was not found
            pause
            exit 70
        )

        move /Y !folder! !gameFolderName! > NUL 2>&1

        set "folder=tmp_!utid!"
        if exist !folder! move /Y !folder! !uName! > NUL 2>&1

        set "folder=tmp_!dtid!"
        if exist !folder! move /Y !folder! !dName! > NUL 2>&1

        REM : clean targetFolder from JNUSFolder files
        call:cleanTargetFolder

        echo WUP packages created in !JNUSFolder:"=!

    ) else (

        REM : moving GAME_TITLE, GAME_TITLE (UPDATE DATA), GAME_TITLE (DLC) to !GAMES_FOLDER!
        if not [!initialGameFolderName!] == [!gameFolderName!] move /Y !initialGameFolderName! !gameFolderName! > NUL 2>&1

        REM : if exist "GAME_TITLE [XXXXXX]\updates"
        set "folder="!gameFolderName:"=!\updates""

        REM : move "GAME_TITLE [XXXXXX]\updates" to "GAME_TITLE [XXXXXX] (UPDATE DATA)"
        if exist !folder! (
            for /F "delims=~" %%x in ('dir /b !folder! 2^>NUL') do set "version=%%x"
            set "updatePath="!gameFolderName:"=!\updates\!version!""

            move /Y !updatePath! !uName! > NUL 2>&1
            rmdir /Q /S !folder!
        )

        REM : if exist "GAME_TITLE [XXXXXX]\aoc0005000C101D6000"
        set "dlcPath="!gameFolderName:"=!\aoc!dtid!""
        REM : move "GAME_TITLE [XXXXXX]\updates" to "GAME_TITLE [XXXXXX] (DLC)" in !GAMES_FOLDER!
        if exist !dlcPath!  move /Y !dlcPath! !dName! > NUL 2>&1


        REM : call importGames.bat on current folder
        set "tobeLaunch="!BFW_TOOLS_PATH:"=!\importGames.bat""
        call !tobeLaunch! !JNUSFolder!
    )
    rmdir /Q /S !initialGameFolderName! > NUL 2>&1

    endlocal
    exit 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    REM : create keys file
    :createKeysFile

        echo No keys file found^, let^'s create it

        REM : get the default internet browser
        for /f "delims=Z tokens=2" %%a in ('reg query "HKEY_CURRENT_USER\Software\Clients\StartMenuInternet" /s 2^>NUL ^| findStr /ri "\.exe.$"') do set "defaultBrowser=%%a"
        if [!defaultBrowser!] == ["NOT_FOUND"] for /f "delims=Z tokens=2" %%a in ('reg query "HKEY_LOCAL_MACHINE\Software\Clients\StartMenuInternet" /s 2^>NUL ^| findStr /ri "\.exe.$"') do set "defaultBrowser=%%a"

        if [!defaultBrowser!] == ["NOT_FOUND"] (
            echo WARNING^: failed to find an internet browser
            echo Open the following page by your own !wiiutitlekeysSite!
            goto:howTo
        )

        REM ping  -n 1 !wiiutitlekeysSite! > NUL 2>&1
        REM if !ERRORLEVEL! NEQ 0 (
            REM echo ERROR^: !wiiutitlekeysSite! does not respond^.
            REM echo Edit !THIS_SCRIPT!
            REM echo and update wiiutitlekeysSite variable
            REM pause
            REM exit 58
        REM )

        echo Openning !wiiutitlekeysSite!
        timeout /T 3 > NUL 2>&1

        wscript /nologo !Start! !defaultBrowser! !wiiutitlekeysSite!
        :howTo
        echo.
        echo If the site is down^, get another one with a google search
        echo Edit !THIS_SCRIPT!
        echo and change wiiutitlekeysSite variable^.
        echo.
        echo.
        echo To create the keys file ^:
        echo.


        echo.
        echo  1^. select all in this page ^(CTRL+A^)
        echo  2^. paste all in notepad
        echo  3^. save the file and close notepad
        echo.
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" "!JNUSFolder:"=!\titleKeys.txt"


        REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!BFW_PATH:"=!\logs\fnr_titleKeys.log""

        REM : replace all \t\t by \t
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !JNUSFolder! --fileMask "titleKeys.txt" --useEscapeChars --find "0 \t\r\n" --replace "0\t" --logFile !uTdLog!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !JNUSFolder! --fileMask "titleKeys.txt" --useEscapeChars --find " \t" --replace "\t" --logFile !uTdLog!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !JNUSFolder! --fileMask "titleKeys.txt" --useEscapeChars --find "\t\t" --replace "\t" --logFile !uTdLog!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !JNUSFolder! --fileMask "titleKeys.txt" --useEscapeChars --find "\t\t" --replace "\t" --logFile !uTdLog!

        del /F !uTdLog! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------

    REM : JNUSTools file in targetFolder
    :cleanTargetFolder

        pushd !targetFolder!

        del /F config > NUL 2>&1
        del /F JNUSTool.* > NUL 2>&1
        del /F titleKeys.txt"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : check if a string contain *
    :checkStr

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed

            set "%2=KO"
            goto:eof
        )
        set "%2=OK"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureGameTitle

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed

            set "%2=KO"
            goto:eof
        )

        REM : str is expected protected with double quotes
        set "string=%~1"

        call:checkStr "!string!" status
        if ["!status!"] == ["KO"] (
            echo string is not valid
            pause
        )

        set "string=!string:&=!"
        set "string=!string:?=!"
        set "string=!string:\!=!"
        set "string=!string:%%=!"
        set "string=!string:^=!"
        set "string=!string:\=!"
        set "string=!string:/=!"
        set "string=!string:>=!"
        set "string=!string:<=!"
        set "string=!string::=!"
        set "string=!string:|=!"

        REM : WUP restrictions
        set "string=!string:?=!"
        set "string=!string:?=!"
        set "string=!string:?=!"

        set "%2="!string!""

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        REM : build a relative path in case of software is installed also in games folders
        echo msg=!msg! | find %GAMES_FOLDER% > NUL 2>&1 && set "msg=!msg:%GAMES_FOLDER:"=%=%%GAMES_FOLDER:"=%%!"

        if not exist !logFile! (
            set "logFolder="!BFW_LOGS:"=!""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof

       :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------

