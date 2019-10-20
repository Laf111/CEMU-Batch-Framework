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
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : RAR.exe path
    set "rarExe="!BFW_PATH:"=!\resources\rar.exe""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% NEQ 3 (
        @echo ERROR on arguments passed^!
        @echo SYNTAX^: %THIS_FILE% GAME_FOLDER_PATH MLC01_FOLDER_PATH user
        @echo given {%*}
        pause
        exit /b 99
    )

    REM : get and check MLC01_FOLDER_PATH
    set "GAME_FOLDER_PATH=!args[0]!"
    if not exist !GAME_FOLDER_PATH! (
        @echo ERROR^: game^'s folder !GAME_FOLDER_PATH! does not exist^!
        pause
        exit /b 1
    )

    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[1]!"
    if not exist !MLC01_FOLDER_PATH! (
        @echo ERROR^: mlc01 folder !MLC01_FOLDER_PATH! does not exist^!
        pause
        exit /b 3
    )

    set "user=!args[2]!"

    REM : No need to handles saves in function of their nature :
    REM : CEMU version earlier than 1.10 : mlc01/emulatorSave in CEMU_FOLDER
    REM : CEMU version from 1.10         : mlc01/usr/save/titleId[0:8]\titleId[8:15] in MLC01_FOLDER

    REM : Because, what happen in CEMU if 2 folders are present in an old version -> nothing
    REM : in a newer version : ask for change location -> create a the new saves files and use them

    REM : So backup systematically /mlc01/emulatorSave and /usr/save.

    REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    set META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml"
    if not exist !META_FILE! (
        @echo No meta folder not found under game folder^?^, aborting ^^!
        goto:metaFix
    )

    REM : get Title Id from meta.xml
    :getTitleLine
    set "titleLine="NONE""
    for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
    if [!titleLine!] == ["NONE"] (
        @echo No titleId found in the meta^.xml file
        :metafix
        @echo No game profile was found because no meta^/meta^.xml file exist under game^'s folder
        set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
        if not exist !metaFolder! mkdir !metaFolder! > NUL 2>&1
        @echo "Please pick your game titleId ^(copy to clipboard^) in WiiU-Titles-Library^.csv"
        @echo "Then close notepad to continue"

        set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !wiiTitlesDataBase!

        REM : create the meta.xml file
        @echo ^<^?xml^ version=^"1.0^"^ encoding=^"utf-8^"^?^> > !META_FILE!
        @echo ^<menu^ type=^"complex^"^ access=^"777^"^> >> !META_FILE!
        @echo ^ ^ ^<title_version^ type=^"unsignedInt^"^ length=^"4^"^>0^<^/title_version^> >> !META_FILE!
        @echo ^ ^ ^<title_id^ type=^"hexBinary^"^ length=^"8^"^>################^<^/title_id^> >> !META_FILE!
        @echo ^<^/menu^> >> !META_FILE!
        @echo "Paste-it in meta^/meta^.xml file ^(replacing ################ by the title id of the game ^(16 characters^)^)"
        @echo "Then close notepad to continue"
        wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !META_FILE!
        goto:getTitleLine
    )
    for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

    if !titleId! == "################" goto:metafix

    set "endTitleId=%titleId:~8,8%"

    set "inGameSavesFolder="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
    if not exist !inGameSavesFolder! mkdir !inGameSavesFolder! > NUL 2>&1

    pushd !inGameSavesFolder!
    set "rarFile="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_!user:"=!.rar""

    REM : if exist rename-it
    set "oldFile=!rarFile:.rar=.bfw_old!"
    if exist !rarFile! move /Y !rarFile! !oldFile! > NUL 2>&1

    set usrSaveFolder="!MLC01_FOLDER_PATH:"=!\usr\save"
    for /F "delims=~" %%i in ('dir /b /o:n /a:d !usrSaveFolder! 2^>NUL') do (
        call:compress "%%i" cr
    )

    set "emulatorSaveFolder="!MLC01_FOLDER_PATH:"=!\emulatorSave""

    if not exist !emulatorSaveFolder! goto:done

    REM : compress old saved files (before Cemu 1.10)
    set "shaderCacheIdLine=NONE"
    set gameFile="!GAME_FOLDER_PATH:"=!\Cemu\!GAME_TITLE!.txt"
    for /F "delims=~" %%i in ('type !gameFile! ^| find /I "shaderCache"') do set "shaderCacheIdLine="%%i""

    if [!shaderCacheIdLine!] == ["NONE"] goto:done

    set "shaderCacheId="NONE""
    for /F "tokens=1-2 delims=~=" %%a in (!shaderCacheIdLine!) do set "strTmp=%%b"
    set "strTmp=!strTmp: =!"
    set "shaderCacheId=!strTmp:"=!"

    if [!shaderCacheId!] == ["NONE"] goto:done
    set pat="!emulatorSaveFolder:"=!\!shaderCacheId!*"
    REM : in case of a future playing game with old save format on a version >= 1.11
    REM : to avoid loosing saves (in old format), systematically backup-it in a !GAME_TITLE!_emulatorSave.rar
    REM : under inGameSaves
    set "rarFileEmuSave="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves\!GAME_TITLE!_emulatorSave.rar""

    for /F "delims=~" %%i in ('dir /b /o:n !pat! 2^>NUL') do (
        set "folder="!emulatorSaveFolder:"=!\%%i""
        !rarExe! a -ed -ap"mlc01\emulatorSave" -ep1 -r -inul  !rarFileEmuSave! !folder! > NUL 2>&1
    )

    :done
    if !cr! EQU 0 (
        if exist !rarFile! (
            @echo Backup in !rarFile!
            del /F !oldFile! > NUL 2>&1
        ) else (
            move /Y !oldFile! !rarFile! > NUL 2>&1
        )
    ) else (
        if exist !oldFile! if exist !rarFile! del /F !rarFile! > NUL 2>&1
        move /Y !oldFile! !rarFile! > NUL 2>&1
        @echo Error when backup !rarFile!^, restoring it
    )


    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :compress
        set "sf="!MLC01_FOLDER_PATH:"=!\usr\save\%~1\%endTitleId%""

        if exist !sf! (
            !rarExe! a -ed -ap"mlc01\usr\save\%~1" -ep1 -r -inul !rarFile! !sf! > NUL 2>&1
            set "%1=!ERRORLEVEL!"
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------

    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove special characters from %1 ^(such as ^&, ^(,^), ^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove special characters from this path ^(such as ^&,^(,^),^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo This path ^(!toCheck!^) is not compatible with DOS^. Remove special characters from this path ^(such as ^&,^(,^),^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
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