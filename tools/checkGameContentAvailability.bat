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
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "duLogFile="!BFW_LOGS:"=!\du.log""

    set "JNUSTFolder="!BFW_RESOURCES_PATH:"=!\JNUST""
    REM : exit in case of no JNUSTFolder folder exists
    if not exist !JNUSTFolder! (
        echo ERROR^: !JNUSTFolder! not found
        exit /b 80
    )

    REM : set current char codeset
    call:setCharSet

    REM : check if java is installed
    java -version > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: java is not installed^, exiting
        timeout /t 2 > NUL 2>&1
        exit /b 51
    )

    REM : check if an active network connexion is available
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo ERROR^: no active network connection found^, exiting
        timeout /t 2 > NUL 2>&1
        exit /b 52
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

    if %nbArgs% GTR 3 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" GAME_FOLDER_PATH contentType titleId^*
        echo given {%*}
        timeout /t 2 > NUL 2>&1
        exit /b 99
    )
    if %nbArgs% LSS 2 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" GAME_FOLDER_PATH contentType endTitleId^*
        echo given {%*}
        timeout /t 2 > NUL 2>&1
        exit /b 99
    )

    set /A "DIAGNOSTIC_MODE=0"

    REM : args 1
    set "GAME_FOLDER_PATH=!args[0]!"

    REM : basename of GAME FOLDER PATH to get GAME_TITLE
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    REM : args 2
    set "contentType=!args[1]!"
    set "contentType=!contentType:"=!"

    set "label=update"
    set "searchOption=find /I ^"update^""
    if ["!contentType!"] == ["0005000c"] (
        set "label=DLC"
        set "searchOption=find /I ^"aoc^""
    )
    if %nbArgs% EQU 3 (
        REM : args 3
        set "endTitleId=!args[2]!"
        set "endTitleId=!endTitleId:"=!"
        set "endTitleId=!endTitleId: =!"
    ) else (
        set /A "DIAGNOSTIC_MODE=1"

        REM : META.XML file
        set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""

        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] (
            echo ERROR^: title_id not found in !META_FILE!
            timeout /t 2 > NUL 2>&1
            exit /b 98
        )
        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

        set "endTitleId=!titleId:~8,8!"
    )

    set "config="!JNUSTFolder:"=!\config""
    REM : if JNUS config is not "ready"
    type !config! | find "[COMMONKEY]" > NUL 2>&1 && (
        if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: COMMONKEY not found in !config!
        timeout /t 2 > NUL 2>&1
        exit /b 81
    )
    set "titleKeysDataBase="!JNUSTFolder:"=!\titleKeys.txt""

    if not exist !titleKeysDataBase! (
        if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: !titleKeysDataBase! not found
        timeout /t 2 > NUL 2>&1
        exit /b 82
    )

    REM : cd to JNUSTool folder
    pushd !JNUSTFolder!

    REM : delete subfolders in !JNUSTFolder!
    for /F "delims=~" %%x in ('dir /O:D /T:W /B /S *') do rmdir /Q /S "%%x"  > NUL 2>&1

    set "tid=!contentType!!endTitleId!"
    REM : pattern used to evaluate size of games : set always extracted size since size of some cryted titles are wrong
    set "str="Total Size of Decrypted Files""

    set /A "totalSizeInMb=0"
    set "sizeStr=0"
    type !titleKeysDataBase! | find /I "!tid!" > NUL 2>&1 && (
        call:getSize !tid! !str! !label! sizeStr
    )

    if ["!sizeStr!"] == ["0"] (
        if !DIAGNOSTIC_MODE! EQU 0 echo INFO^: no !label! found^, exiting
        timeout /t 2 > NUL 2>&1
        exit /b 83
    )

    REM : get the last modified meta.xml in !label! folder
    set "mf="NOT_FOUND""
    for /F "delims=~" %%x in ('dir /O:D /T:W /B /S meta.xml 2^>NUL ^| !searchOption!') do set "mf="%%x""
    if [!mf!] == ["NOT_FOUND"] (
        if !DIAGNOSTIC_MODE! EQU 0 (
            echo ERROR^: failed to download meta^.xlm
            echo Check security policy
        )
        timeout /t 2 > NUL 2>&1
        exit /b 60
    )

    set "initialGameFolderName="NOT_FOUND""
    for %%a in (!mf!) do set "parentFolder="%%~dpa""
    set "dirname=!parentFolder:~0,-2!""
    for %%a in (!dirname!) do set "parentFolder="%%~dpa""
    set "fullPath=!parentFolder:~0,-2!""

    if ["!contentType!"] == ["0005000e"] (
        REM : Get the version of the !label!
        for /F "delims=~" %%i in (!fullPath!) do set "folder=%%~nxi"
        set "contentVersion=!folder:v=!"

        for %%a in (!fullPath!) do set "parentFolder="%%~dpa""
        set "contentFolder=!parentFolder:~0,-2!""
        for %%a in (!contentFolder!) do set "parentFolder="%%~dpa""
        set "gamesFolder=!parentFolder:~0,-2!""
        set "initialGameFolderName=!gamesFolder:%JNUSTFolder:"=%\=!"

    ) else (

        for %%a in (!fullPath!) do set "parentFolder="%%~dpa""
        set "gamesFolder=!parentFolder:~0,-2!""
        set "initialGameFolderName=!gamesFolder:%JNUSTFolder:"=%\=!"

        REM : get the version of the content (DLC)
        set "metaContentPath="!fullPath:"=!\meta\meta.xml""
        set "newContentVersion="NONE""
        set "versionLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !metaContentPath! ^| find "<title_version"') do set "versionLine="%%j""
        if [!versionLine!] == ["NONE"] (
            if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: version of !label! not found in !metaContentPath!
            rmdir /Q /S !gamesFolder! > NUL 2>&1
            timeout /t 2 > NUL 2>&1
            exit /b 64
        )
        for /F "delims=<" %%i in (!versionLine!) do set "newContentVersion=%%i"
        if ["!newContentVersion!"] == ["NOT_FOUND"] (
            if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: failed to get verson of !label! in !metaContentPath!
            rmdir /Q /S !gamesFolder! > NUL 2>&1
            timeout /t 2 > NUL 2>&1
            exit /b 65
        )
        REM : str2int
        call:getInteger !newContentVersion! contentVersion
    )

    if ["!initialGameFolderName!"] == ["NOT_FOUND"] (
        if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: failed to get folder of !label!
        timeout /t 2 > NUL 2>&1
        exit /b 61
    )

    if !DIAGNOSTIC_MODE! EQU 0 rmdir /Q /S !gamesFolder! > NUL 2>&1

    REM : check if an !label! exist for the game
    set "oldContentPath="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\!contentType!\!endTitleId!""

    set /A "newVersion=!contentVersion!"

    if exist !oldContentPath! (
        REM : Yes : get the version of the !label! and compare version
        set "mf="!oldContentPath:"=!\meta\meta.xml""

        set "oldContentVersion="NONE""
        set "versionLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !mf! ^| find "<title_version"') do set "versionLine="%%j""
        if [!versionLine!] == ["NONE"] (
            if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: version of !label! not found in !mf!
            timeout /t 2 > NUL 2>&1
            exit /b 64
        )

        :cleanOldVersionLine
        for /F "delims=<" %%i in (!versionLine!) do set "oldContentVersion=%%i"
        if ["!oldContentVersion!"] == ["NOT_FOUND"] (
            if !DIAGNOSTIC_MODE! EQU 0 echo ERROR^: failed to get verson of !label! in !mf!
            timeout /t 2 > NUL 2>&1
            exit /b 65
        )
        REM : str2int
        call:getInteger !oldContentVersion! oldVersion

        if !oldVersion! GEQ !newVersion! (
            REM : new <= old, skip
            if !DIAGNOSTIC_MODE! EQU 0 echo INFO^: no need to update^, your game is up to date
            timeout /t 2 > NUL 2>&1
            exit /b 0
        ) else (
            REM :     new > old popup msg
            if !DIAGNOSTIC_MODE! EQU 0 (
                echo INFO^: new !label! available
                wscript /nologo !Start! !MessageBox! "!label! is available for !GAME_TITLE! ^! ^(v!newVersion! ^, !sizeStr! MB^)^, use ^'Wii-U Games^\Update my games^.lnk^'"
            ) else (
                REM : echo path
                echo !fullPath!?!endTitleId!?!sizeStr!
            )
            timeout /t 2 > NUL 2>&1
            exit /b 1
        )

    ) else (
        REM : popup message and exit
        if !DIAGNOSTIC_MODE! EQU 0 (
            wscript /nologo !Start! !MessageBox! "!label! is available for !GAME_TITLE! ^! ^(v!newVersion! ^, !sizeStr! MB^)^, use ^'Wii-U Games^\Update my games^.lnk^'"
        ) else (
            REM : echo path
            echo !fullPath!?!endTitleId!?!sizeStr!
        )
        timeout /t 2 > NUL 2>&1
        exit /b 1
    )

    endlocal
    exit /b 0

goto:eof

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

    REM : fetch size of download
    :getSize
        set "tid=%~1"
        set "pat=%~2"
        set "type=%~3"
        set "%4=0"

        set "key=NOT_FOUND"
        for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!tid!" 2^>NUL') do set "key=%%b"

        if ["!key!"] == ["NOT_FOUND"] (
            echo ERROR^: why key is not found ^?
            goto:eof
        )

        set "logMetaFile="!BFW_LOGS:"=!\jnust_Meta.log""
        del /F !logMetaFile! > NUL 2>&1
        java -jar JNUSTool.jar !tid! !key! -file /meta/meta.xml > !logMetaFile! 2>&1

        set "strRead="
        for /F "delims=~: tokens=2" %%i in ('type !logMetaFile! ^| find "!pat!" 2^>NUL') do set "strRead=%%i"

        set "strSize="
        for /F "tokens=1" %%i in ("!strRead!") do set "strSize=%%i"

        echo !strSize! | find /I "0." > NUL 2>&1 && (
            set "intSize=1"
            goto:endFctGetSize
        )

        set /A "intSize=0"
        for /F "delims=~. tokens=1" %%i in ("!strSize!") do set /A "intSize=%%i"

        :endFctGetSize

        set "%4=!intSize!"
        set /A "totalSizeInMb=!totalSizeInMb!+!intSize!"

        del /F !logMetaFile! > NUL 2>&1
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

