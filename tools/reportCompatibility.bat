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
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

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

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : check args
    if %nbArgs% NEQ 8 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" GAME_FOLDER_PATH CEMU_FOLDER USER TITLE_ID MLC01_FOLDER_PATH CEMU_STATUS SHADER_CACHE_ID FPS
        echo given {%*}
        pause
        exit /b 99
    )

    REM : get arguments
    set "GAME_FOLDER_PATH=!args[0]!"
    set "CEMU_FOLDER=!args[1]!"
    set "user=!args[2]!"
    set "user=!user:"=!"
    set "titleId=!args[3]!"
    set "titleId=!titleId:"=!"

    set "MLC01_FOLDER_PATH=!args[4]!"

    set "CEMU_STATUS=!args[5]!"
    set "CEMU_STATUS=!CEMU_STATUS:"=!"
    set "SHADER_CACHE_ID=!args[6]!"
    set "SHADER_CACHE_ID=!SHADER_CACHE_ID:"=!"
    set "FPS=!args[7]!"
    set "FPS=!FPS:"=!"

    REM : check GAME_FOLDER_PATH
    if not exist !GAME_FOLDER_PATH! (
        echo GAME_FOLDER_PATH does not exist ^: !GAME_FOLDER_PATH!
        exit /b 1
    )
    REM : check MLC01_FOLDER_PATH
    if not exist !MLC01_FOLDER_PATH! (
        echo MLC01_FOLDER_PATH does not exist ^: !MLC01_FOLDER_PATH!
        exit /b 2
    )
    REM : check CEMU_FOLDER
    if not exist !CEMU_FOLDER! (
        echo CEMU_FOLDER does not exist ^: !CEMU_FOLDER!
        exit /b 3
    )

    REM : basename of CEMU_FOLDER to get CEMU version (used to name shorcut)
    for %%a in (!CEMU_FOLDER!) do set "CEMU_FOLDER_NAME="%%~nxa""
    set "CEMU_FOLDER_NAME=!CEMU_FOLDER_NAME:"=!"
    set "VERSION=NONE"

    REM : log CEMU
    set "cemuLog="!CEMU_FOLDER:"=!\log.txt""

    set "versionRead=NOT_FOUND"
    if exist !cemuLog! (

        for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu" 2^> NUL') do set "versionRead=%%e"
        set "VERSION=!versionRead!"
    ) else (
        REM : get it from the executable
        set "cemuExe="!CEMU_FOLDER:"=!\Cemu.exe""

        set "here="%CD:"=%""
        pushd !BFW_TOOLS_PATH!
        for /F %%a in ('getDllOrExeVersion.bat !cemuExe!') do set "versionRead=%%a"
        set "VERSION=%versionRead:~0,-2%"
        pushd !here!
    )

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""

    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'%titleId%';" 2^>NUL') do set "libFileLine="%%i""

    REM : add-it to the library
    if [!libFileLine!] == ["NONE"] (
        attrib -r !wiiTitlesDataBase! > NUL 2>&1
        echo ^'%titleId%^'^;!GAME_TITLE!^;-^;-^;-^;-^;-^;-^;^'%titleId%^'^;720^;60^;SYNCSCR >> !wiiTitlesDataBase!
        REM sorting the file
        set "tmpFile=!wiiTitlesDataBase:.csv=.tmp!"
        type !wiiTitlesDataBase! | sort > !tmpFile!
        move /Y !tmpFile! !wiiTitlesDataBase! > NUL 2>&1
        del /F !tmpFile! > NUL 2>&1
        attrib +r !wiiTitlesDataBase! > NUL 2>&1
    )

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    set "EXIST_IN_DATABASE=no"
    set "REGION=UNKNOWN"
    REM : check if a GAME_TITLE is found in
    set "gameInfoFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt""

    set "libFileLine="NONE""
    for /F "tokens=2 delims=~=" %%i in ('type !gameInfoFile! ^| find /I "REGION" 2^>NUL') do set "REGION=%%i" && set "EXIST_IN_DATABASE=yes"
    set "REGION=%REGION:"=%"

    set "beginTitleId=%titleId:~0,8%"
    set "endTitleId=%titleId:~8,8%"

    REM : get game version :
    REM :   1-look in !MLC01_FOLDER_PATH!\usr\title\%beginTitleId%\%endTitleId%\meta\meta.xml
    REM :   2-GAME_FOLDER_PATH\meta\meta.xml

    set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
    set "META_FILE_MLC01="!MLC01_FOLDER_PATH:"=!\usr\title\%beginTitleId%\%endTitleId%\meta\meta.xml""
    if exist !META_FILE_MLC01! set META_FILE=!META_FILE_MLC01!
    set "META_FILE_MLC01="!MLC01_FOLDER_PATH:"=!\usr\title\0005000e\%endTitleId%\meta\meta.xml""
    if exist !META_FILE_MLC01! set META_FILE=!META_FILE_MLC01!

    REM : get Title Id from meta.xml
    set "versionLine="NONE""
    for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_version"') do set "versionLine="%%j""
    if [!versionLine!] == ["NONE"] goto:dlc
    for /F "delims=<" %%i in (!versionLine!) do set "str=%%i"
    REM : str2int
    call:getInteger !str! GAME_VERSION

    :dlc
    REM : check if a DLC is present :
    set "DLC=no"
    set "META_FILE_DLC="!MLC01_FOLDER_PATH:"=!\usr\title\%beginTitleId%\%endTitleId%\aoc\meta\meta.xml""
    if exist !META_FILE_DLC! set "DLC=yes"
    set "META_FILE_DLC="!MLC01_FOLDER_PATH:"=!\usr\title\0005000c\%endTitleId%\meta\meta.xml""
    if exist !META_FILE_DLC! set "DLC=yes"

    REM : update GAME_VERSION,DLC,ShaderCahe in gameInfoFile
    REM --------------------------------------------------------------------------------
    set "gameInfoFileTmp="!gameInfoFile:"=!.bfw_tmp""
    type !gameInfoFile! | find /I /V "game" | find /I /V "DLC" | find /I /V "ShaderCache" | find /I /V "Updated" > !gameInfoFileTmp!

    del /F /S !gameInfoFile! > NUL 2>&1
    move /Y !gameInfoFileTmp! !gameInfoFile! > NUL 2>&1

    REM : GAME_VERSION
    echo game version     ="%GAME_VERSION%" >> !gameInfoFile!
    REM : DLC
    echo DLC installed    ="%DLC%" >> !gameInfoFile!
    REM : ShaderCache Id
    if not ["%SHADER_CACHE_ID%"] == ["NOT_FOUND"] echo ShaderCache Id   ="%SHADER_CACHE_ID%" >> !gameInfoFile!

    REM : update reports
    REM --------------------------------------------------------------------------------

     REM : search for saves
    set "SAVES_FOUND=no"
    set "rarFile="NONE""
    set "pat="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_*.*""
    for /F "delims=~" %%i in ('dir /B /O:S !pat! 2^>NUL') do (
        set "rarFile="%%i""
    )

    REM : if found
    if not [!rarFile!] == ["NONE"] set "SAVES_FOUND=yes"

    set "CPU=NOT_FOUND"
    for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_Processor get Name /value 2^>NUL ^| find "="') do set "CPU="%%f""

    set "OS_VERSION=NONE"
    for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_OperatingSystem get Name /value 2^>NUL ^| find "="') do set "OS_VERSION="%%f""
    for  /f "tokens=1-3 delims=|" %%f in (!OS_VERSION!) do (
        set OS_VERSION=%%f
    )

    REM : get GPU_VENDOR
    set "GPU_VENDOR=NOT_FOUND"
    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get Name /value 2^>NUL ^| find "="') do (
        set "string=%%i"
        echo "!string!" | find /I "NVIDIA" > NUL 2>&1 && (
            set "GPU_VENDOR=!string: =!"
        )
    )

    if ["!GPU_VENDOR!"] == ["NOT_FOUND"] set "GPU_VENDOR=!string: =!"

    set "GPU_DRIVERS_VERSION=NONE"

    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_VideoController get DriverVersion /value 2^>NUL ^| find "="') do (
        set "GPU_DRIVERS_VERSION=%%i"
    )

    for /F "tokens=2 delims=~=" %%i in ('wmic path Win32_ComputerSystem get TotalPhysicalMemory/value 2^>NUL ^| find "="') do (
        set "ramInBytes=%%i"
    )
    set "ramInBytes=%ramInBytes: =%"
    set /A "ramInKb=%ramInBytes:~,-3%"
    set /A "ramInMb=ramInKb/1024"
    set /A "ramInGb=ramInMb/1024"
    set "RAM=!ramInGb!Go RAM"

    REM : fill additionnals notes
    set "ADD_NOTES="

    REM : add game version
    set "ADD_NOTES=GAME_VERSION=%GAME_VERSION%,"

    REM : precise if a DLC is intalled
    set "ADD_NOTES=%ADD_NOTES% DLC installed=%DLC%"

    REM : get region of games and directives in game's profile
    set "profileFile="!CEMU_FOLDER:"=!\gameProfiles\%titleId%.ini""

    for /F "delims=~" %%i in ('type !profileFile! ^| find /I /V "#" ^| find /I /V "[" 2^>NUL') do (
        set "line=%%i"
        set "line=!line: =!"
        set "ADD_NOTES=!ADD_NOTES!^, !line!"
    )

    set "GAMES_REPORT_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!""
    if not exist !GAMES_REPORT_FOLDER! mkdir !GAMES_REPORT_FOLDER! > NUL 2>&1

    if not ["!CEMU_STATUS!"] == ["Loads"] goto:gameReportUpToDate
    set "GAMES_REPORT_PATH="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!\Working_games_list.csv""

    REM : if report doesn't exist, creating it
    if not exist !GAMES_REPORT_PATH! (
        echo Working games on !USERDOMAIN!; > !GAMES_REPORT_PATH!
        echo ; >> !GAMES_REPORT_PATH!
        echo ; >> !GAMES_REPORT_PATH!
        echo Game Title;Cemu Version;OS Version;Region;CPU[RAM];GPU;Tester;Status;Additional Notes;title Id;Exist in WiiU-Titles-Library^.csv;Game Version;DLC installed;Saves found;ShaderCacheId >> !GAMES_REPORT_PATH!
    )

    REM : report exist, find in !GAME_TITLE!
    type !GAMES_REPORT_PATH! | find /I "%titleId%" > NUL 2>&1
    if !ERRORLEVEL! EQU 0 goto:gameReportUpToDate

    REM : add line for current game
    echo !GAME_TITLE!;!CEMU_FOLDER_NAME!;!OS_VERSION!;!REGION!;%CPU:"=%;%GPU_VENDOR:"=% with drivers %GPU_DRIVERS_VERSION:"=%;!user!;%CEMU_STATUS%;!ADD_NOTES!;'%titleId%';%EXIST_IN_DATABASE%;%GAME_VERSION%;%DLC%;%SAVES_FOUND%;%SHADER_CACHE_ID% >> !GAMES_REPORT_PATH!

    :gameReportUpToDate

    set "CEMU_REPORT_PATH="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports\!USERDOMAIN!\!CEMU_FOLDER_NAME!_games_compatibility_list.csv""

    REM : if report doesn't exist, creating it
    if not exist !CEMU_REPORT_PATH! (
        echo !CEMU_FOLDER_NAME! games compatibility list report; > !CEMU_REPORT_PATH!
        echo ; >> !CEMU_REPORT_PATH!
        echo ;CEMU satus enums :  ; >> !CEMU_REPORT_PATH!
        echo ; >> !CEMU_REPORT_PATH!
        echo ;Perfect;Game can be played with no issues.; >> !CEMU_REPORT_PATH!
        echo ;Playable;Game can be played through with minor audio or graphical glitches.; >> !CEMU_REPORT_PATH!
        echo ;Runs;Starts, maybe runs well, but major glitches/issues prevent game from being completed.; >> !CEMU_REPORT_PATH!
        echo ;Loads;Game loads, but crashes in title screen/menu/in-game.; >> !CEMU_REPORT_PATH!
        echo ;Unplayable;Crashes when booting/infinite black screen.; >> !CEMU_REPORT_PATH!
        echo ; >> !CEMU_REPORT_PATH!
        echo ; >> !CEMU_REPORT_PATH!
        echo Game Title;Cemu Version;OS Version;Region;CPU[RAM];GPU;Tester;FPS;Status;Additional Notes;title Id;Exist in WiiU-Titles-Library^.csv;Game Version;DLC installed;Saves found;ShaderCacheId;ReportRow  >> !CEMU_REPORT_PATH!
    )

    REM : report exist, find in !GAME_TITLE!
    type !CEMU_REPORT_PATH! | find /I "%titleId%" > NUL 2>&1
    if !ERRORLEVEL! EQU 0 goto:reportUpToDate

    REM : report line for http://compat.cemu.info/
    for /F "tokens=1-3 delims=~." %%f in ("!VERSION!") do set "MAIN_VERSION=%%f.%%g"

    set "REPORT_LINE="^{^{testsection^|!MAIN_VERSION!^|collapsed^}^}^{^{testline^|version=!VERSION!^|OS=!OS_VERSION!^|region=!REGION!^|CPU=%CPU:"=%^[%RAM:"=%^]^|GPU=%GPU_VENDOR:"=% with drivers %GPU_DRIVERS_VERSION:"=%^|user=!user!^|FPS=%FPS%^|rating=%CEMU_STATUS%^|notes=!ADD_NOTES:"=!^}^}^{^{testend^}^}""
    if ["!VERSION!"] == ["!CEMU_FOLDER_NAME!"] set "REPORT_LINE="^{^{testsection^|%CEMU_1ST_DIGIT%.%CEMU_2ND_DIGIT%^|collapsed^}^}^{^{testline^|version=%CEMU_1ST_DIGIT%.%CEMU_2ND_DIGIT%.%CEMU_3RD_DIGIT%^|OS=!OS_VERSION!^|region=!REGION!^|CPU=%CPU:"=%^[%RAM:"=%]^|GPU=%GPU_VENDOR:"=% with drivers %GPU_DRIVERS_VERSION:"=%^|user=!user!^|FPS=%FPS%^|rating=%CEMU_STATUS%^|notes=!ADD_NOTES:"=!^}^}^{^{testend^}^}""

    REM : add line for current game
    echo !GAME_TITLE!;!CEMU_FOLDER_NAME!;!OS_VERSION!;!REGION!;%CPU:"=%[!RAM:"=!];%GPU_VENDOR:"=% with drivers %GPU_DRIVERS_VERSION:"=%;!user!;;%CEMU_STATUS%;!ADD_NOTES!;'%titleId%';%EXIST_IN_DATABASE%;%GAME_VERSION%;%DLC%;%SAVES_FOUND%;%SHADER_CACHE_ID%;!REPORT_LINE:"=!  >> !CEMU_REPORT_PATH!

    :reportUpToDate

    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    REM : function to compute string length
    :getInteger
        Set "str=%~1"

        Set "s=#%str%"
        Set "len=0"

        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )

        set /A "index=0"
        set /A "left=len"
        set /A "lm1=len-1"

        for /L %%l in (0,1,%lm1%) do (
            set "char=!str:~%%l,1!"
            if not ["!char!"] == ["0"] (
                set /A "left=%len%-%%l"
                set /A "index=%%l"
                goto:intFound
            )
        )
        :intFound

        set "%2=!str:~%index%,%left%!"

    goto:eof


    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove specials characters from %1 ^(such as ^&,^(,^),^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo This path ^(!toCheck!^) is not compatible with DOS^. Remove specials characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
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
        for /F %%i in ('type !logFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------