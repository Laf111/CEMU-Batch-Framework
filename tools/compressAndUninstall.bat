@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    REM color 4F
    color F0

    set "THIS_SCRIPT=%~0"

    title Compress and uninstall games

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
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
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    
    set "rarExe="!BFW_RESOURCES_PATH:"=!\rar.exe""
    set "multiply="!BFW_TOOLS_PATH:"=!\multiply.bat""
    
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "du="!BFW_RESOURCES_PATH:"=!\du.exe""

    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS:"=!\gamesLibrary.log""
    set "duLogFile="!BFW_LOGS:"=!\du.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!
    cls
    echo =========================================================
    echo Compress and uninstall Games
    echo.
    echo NOTE ^: you'll need to use an archive manager that supports
    echo RAR 5 archive files to open them under windows
    echo =========================================================
    echo.

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    :getList
    REM : max size need when treating sequencially games (biggest game selected)
    set /A "maxSizeNeededOnDiskInMb=0"
    set /A "nbGames=0"

    REM : loop on game's code folders found
    for /F "delims=~" %%g in ('dir /b /o:n /a:d /s code 2^>NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        set "codeFullPath="%%g""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"
        set "gamesPath[!nbGames!]=!GAME_FOLDER_PATH!"
        set "titles[!nbGames!]=!GAME_TITLE!"
        echo !nbGames!	: !GAME_TITLE!

        set /A "nbGames+=1"
    )
    echo.
    echo =========================================================
    echo.

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

            set "selectedTitles[!nbGamesSelected!]=!titles[%%l]!"
            set "selectedGamesPath[!nbGamesSelected!]=!gamesPath[%%l]!"

            REM : compute uncompressedSize = size of !GAME_FOLDER_PATH!
            set /A "sizeNeeded=0"
            call:getSizeInMb !gamesPath[%%l]! sizeNeeded
            if !sizeNeeded! GTR !maxSizeNeededOnDiskInMb! set /A "maxSizeNeededOnDiskInMb=sizeNeeded"

            echo - !titles[%%l]! ^(!sizeNeeded! Mb^)
            set /A "nbGamesSelected+=1"
        )
    ) else (
        goto:getList
    )
    echo =========================================================
    echo.

    choice /C ync /N /M "Continue (y, n : define another list) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit 98
    if !ERRORLEVEL! EQU 2 cls & goto:getList

    echo =========================================================

    if !nbGamesSelected! EQU 0 (
        echo No games selected ^?
        pause
        goto:getList
    )

    set /A "progress=0"
    title Compress and uninstall games !progress!%%
    set /A "step=100/nbGamesSelected"

    REM : number to array index
    set /A "nbGamesSelected-=1"

    pushd !GAMES_FOLDER!

    REM : compute space left on drive
    set "psc="Get-CimInstance -ClassName Win32_Volume ^| Select-Object Name^, FreeSpace^, BlockSize ^| Format-Table -AutoSize""
    for /F "tokens=2-3" %%i in ('powershell !psc! ^| find "!drive!" 2^>NUL') do set "fsbStr=%%i"

    REM : free space in Kb
    set /A "fskb=!fsbStr:~0,-3!"
    REM : free space in Mb
    set /A "spaceLeftInMb=fskb/1024"

    echo.
    echo Free Space left on "!drive!" ^: !spaceLeftInMb! Mb
    echo Space needed            ^: !maxSizeNeededOnDiskInMb! Mb
    echo ---------------------------------------------------------

    if !maxSizeNeededOnDiskInMb! GEQ !spaceLeftInMb! (
        echo Not enought space left on !drive! to process^, remove some games or cancel
        goto:getList
    )
    echo.
    choice /C yn /N /M "Compress and uninstall those games (y, n)? : "
    if !ERRORLEVEL! EQU 2 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit 98
    echo.

    set /A "shutdownFlag=0"
    choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
    if !ERRORLEVEL! EQU 1 (
        echo Please^, save all your opened documents before continue^.^.^.
        pause
        set /A "shutdownFlag=1"
    )
    cls
    REM : Loop on the game selected
    for /L %%i in (0,1,!nbGamesSelected!) do (

        set "GAME_FOLDER_PATH=!selectedGamesPath[%%i]!"
        set "GAME_TITLE=!selectedTitles[%%i]!"
        call:compressAndUninstall

        set /A "progress=progress+step"
        title Compress and uninstall games !progress!%%
    )

    title Compress and uninstall games 100%%

    REM : if shutdwon is asked
    if !shutdownFlag! EQU 1 echo shutdown in 30s^.^.^. & timeout /T 30 /NOBREAK & shutdown -s -f -t 00

    echo =========================================================
    pause

    endlocal
    exit 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :fillOwnerShipPatch
        set "folder=%1"
        set "title=%2"

        set "patch="%USERPROFILE:"=%\Desktop\BFW_GetOwnerShip_!title:"=!.bat""
        set "WIIU_GAMES_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
        if not [!WIIU_GAMES_FOLDER!] == ["NONE"] (

            set "patchFolder="!WIIU_GAMES_FOLDER:"=!\OwnerShip Patchs""
            if not exist !patchFolder! mkdir !patchFolder! > NUL 2>&1
            set "patch="!patchFolder:"=!\!title:"=!.bat""
        )
        set "%3=!patch!"

        echo echo off > !patch!
        echo REM ^: RUN THIS SCRIPT AS ADMINISTRATOR >> !patch!

        type !patch! | find /I !folder! > NUL 2>&1 && goto:eof

        echo echo ------------------------------------------------------->> !patch!
        echo echo Get the ownership of !folder! >> !patch!
        echo echo ------------------------------------------------------->> !patch!
        echo takeown /F !folder! /R /SKIPSL >> !patch!
        echo icacls !folder! /grant %%username%%^:F /T /L >> !patch!
        echo pause >> !patch!
        echo del /F %%0 >> !patch!
    goto:eof
    REM : ------------------------------------------------------------------

    :cleanGameLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.bfw_tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :compressAndUninstall

        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""

        REM : cd to codeFolder
        pushd !codeFolder!
        set "RPX_FILE="project.rpx""
        REM : get bigger rpx file present under game folder
        if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] (
            echo This !codeFolder! does not contain rpx file
            goto:eof
        )

        echo ---------------------------------------------------------
        set "compresslogFile="!BFW_PATH:"=!\logs\!GAME_TITLE!.log""
        echo ^>Compressing !GAME_TITLE!^.^.^.
        echo (log=!compresslogFile!)
        echo.

        set "archiveFile="!GAME_FOLDER_PATH:"=!.rar""

        echo COMPRESSING DATE ^: !DATE! >> !compresslogFile!

        wscript /nologo !StartHiddenWait! !rarExe! a -ep1 -t -r -m5 -w!BFW_LOGS! !archiveFile! "!GAME_TITLE!" >> !compresslogFile!
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 10 (
            type !compresslogFile! | find "WARNING:"
            echo Skip this game
            goto:eof
        )
        if !cr! GTR 1 (
            echo ERROR ^: rar^.exe return !cr!^, please consult !compresslogFile!
            echo Skip this game
            goto:eof
        )

        echo !archiveFile! created suceesfully
        echo.

        echo ^>Uninstalling !GAME_TITLE!^.^.^.
        echo.

        set /A "attempt=1"
        :tryToRemMove
        rmdir /Q /S !GAME_FOLDER_PATH! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                echo Failed to delete !GAME_FOLDER_PATH:"=!^, close any program that could use this location
                pause
                set /A "attempt+=1"
                goto:tryToReMove
            )
            REM : basename of GAME FOLDER PATH to get GAME_TITLE
            for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxg"
            call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

            choice /C yn /N /M "Still failed, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!. If it's done, do you wish to retry (y/n)?
            if !ERRORLEVEL! EQU 2 (
                echo Impossible to delete !GAME_FOLDER_PATH! by script^, please do it by your own ^!
                goto:eof
            )
            if !ERRORLEVEL! EQU 1 goto:tryToReMove
        )

        if exist !GAME_FOLDER_PATH! goto:tryToReMove

        echo !GAME_TITLE! folder succesfully deleted
        echo.

        echo ^>Clean !GAME_TITLE! BatchFw data^.^.^.
        echo.

        REM : flushing gamesLibrary with !GAME_TITLE!
        call:cleanGameLogFile "!GAME_TITLE!"

        echo !GAME_TITLE! uninstalled successfully
        echo.

        echo ---------------------------------------------------------
        echo.
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


    REM : ------------------------------------------------------------------
    :getSizeInMb

        set "folder="%~1""

        set "smb=-1"
        !du! /accepteula -nobanner -q -c !folder! > !duLogFile!

        set "sizeRead=-1"
        for /F "delims=~, tokens=6" %%a in ('type !duLogFile!') do set "sizeRead=%%a"


        if ["!sizeRead!"] == ["-1"] goto:endFct
        if ["!sizeRead!"] == ["0"] set "smb=0" & goto:endFct

        REM : 1/(1024^2)=0.00000095367431640625
        for /F %%a in ('!multiply! !sizeRead! 95367431640625') do set "result=%%a"

        set /A "lr=0"
        call:strLength !result! lr
        REM : size in Mb
        if !lr! GTR 20 (
            set /A "smb=!result:~0,-20!"
        ) else (
            set /A "smb=1"
        )

        :endFct

        set "%2=!smb!"
    goto:eof
    REM : ------------------------------------------------------------------

    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
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


        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg! >> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
