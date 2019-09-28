@echo off
setlocal EnableExtensions

    title Display games^'stats taking all hosts and CEMU versions into account
REM : ------------------------------------------------------------------
REM : main
    setlocal EnableDelayedExpansion
    color 4F

REM : ------------------------------------------------------------------

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
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMaximizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMaximizedWait.vbs""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "xmlS="!BFW_RESOURCES_PATH:"=!\xml.exe""

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

    if %nbArgs% NEQ 1 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" userId
        @echo given {%*}
        timeout /t 4 > NUL 2>&1
        exit 99
    )

    REM : args 1
    set "user=!args[0]!"

    title Display !user:"=! games^'stats taking all hosts and CEMU versions into account
    @echo =========================================================

    set "versionRead=NOT_FOUND"

    REM : get the last Cemu installation on this host
    REM : search in logFile, getting only the last occurence
    set "CEMU_FOLDER="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "install folder path" 2^>NUL') do (
        set "CEMU_FOLDER="NOT_FOUND""
        call:getCemuInstall "%%i" CEMU_FOLDER
        if not [!CEMU_FOLDER!] == ["NOT_FOUND"] goto:backupCs
    )
    if [!CEMU_FOLDER!] == ["NOT_FOUND"] (
        @echo ERROR^: No suitable installation of CEMU found on this host ^!
        timeout /t 4 > NUL 2>&1
        exit 51
    )

    :backupCs
    REM : backup settings.xml -> old
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
    set "backup="!CEMU_FOLDER:"=!\settings.bfw_old""

    if exist !backup! (
        copy /Y !backup! !cs! > NUL 2>&1
    ) else (
        copy /Y !cs! !backup! > NUL 2>&1
    )

    pushd !BFW_RESOURCES_PATH!
    REM : delete node in csTgt
    set "csTmp=!cs:.xml=.bfw_tmp!"
    "xml.exe" ed -d "//GamePaths/Entry" !cs! > !csTmp!

    set "csTmp1=!cs:.xml=.bfw_tmp1!"
    REM : remove the node //GameCache/Entry
    "xml.exe" ed -d "//GameCache/Entry" !csTmp! > !csTmp1!

    set "csTmp2=!cs:.xml=.bfw_tmp2!"
    "xml.exe" ed -s "//GamePaths" -t elem -n "Entry" -v !GAMES_FOLDER! !csTmp1! > !csTmp2!

    set "MLC01_FOLDER_PATH=!CEMU_FOLDER:"=!\mlc01"
    "xml.exe" ed -u "//mlc_path" -v "!MLC01_FOLDER_PATH!/" !csTmp2! > !cs!
    if exist !cs! del /F !csTmp!* > NUL 2>&1

    REM : loop on each games
    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!
    @echo Loop on games played by !user:"=!^.^.^.
    @echo.

    set /A "GAMES_PLAYED=0"
    REM : searching for code folder to find in only one rpx file (the bigger one)
    for /F "delims=~" %%i in ('dir /B /S /A:D code ^| find /I /V "\mlc01" 2^> NUL') do (

        set "codeFullPath="%%i""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : check folder
        call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 0 (
            REM : check if folder name contains forbiden character for batch file
            set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
            call !tobeLaunch! !GAME_FOLDER_PATH!
            set /A "cr=!ERRORLEVEL!"

            if !cr! GTR 1 @echo Please rename the game^'s folder to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:getStats

        ) else (

            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            @echo !folderName!^: Unsupported characters found^, rename it otherwise it will be ignored by BatchFW ^^!
            for %%a in (!GAME_FOLDER_PATH!) do set "basename=%%~dpa"

            REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!% are also a problem with dos expansion
            set "str="!folderName!""
            set "str=!str:&=!"
            set "str=!str:\!=!"
            set "str=!str:%%=!"
            set "str=!str:.=!"
            set "str=!str:?=!"
            set "str=!str:\"=!"
            set "str=!str:^=!"
            set "newFolderName=!str:"=!"
            set "newName="!basename!!newFolderName:"=!""

            call:getUserInput "Renaming folder for you? (y,n): " "y,n" ANSWER

            if [!ANSWER!] == ["y"] move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 @echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )
    @echo.
    if !GAMES_PLAYED! EQU 0 (
        @echo.
        @echo WARNING^: No games were played by !user:"=!^, exiting^.^.^.
        @echo.
        timeout /T 4 > NUL 2>&1
        exit 1
    )
    @echo.
    @echo =========================================================
    @echo Use !versionRead! to display stats
    @echo ^(do not launch games with it^)
    @echo.
    @echo =========================================================

    timeout /T 3 > NUL 2>&1

    REM : open CEMU
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe""

    wscript /nologo !StartMaximizedWait! !cemuExe!

    REM : if a backup on settings.xml exist, restore it
    set "cs="!CEMU_FOLDER:"=!\settings.xml""
    set "backup="!CEMU_FOLDER:"=!\settings.bfw_old""

    if exist !backup! (
        del /F !cs!
        move /Y !backup! !cs! > NUL 2>&1
    )
    @echo done

    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

REM : ------------------------------------------------------------------

    :getCemuInstall
        set "cemuInstallFolder="%~1""

        if not exist !cemuInstallFolder! (
            @echo WARNING^: Cemu^'s install in !cemuInstallFolder:"=! was not found on this host ^!
            goto:eof
        )

        REM : check version > 1.12.0
        set "cemuLog="!cemuInstallFolder:"=!\log.txt""
        if not exist !cemuLog! (
            @echo WARNING^: No log^.txt found in the last Cemu^'s install in !cemuInstallFolder:"=! ^!
            goto:eof
        )

        for /f "tokens=1-6" %%a in ('type !cemuLog! ^| find "Init Cemu" 2^> NUL') do set "versionRead=%%e"
        if ["!versionRead!"] == ["NOT_FOUND"] (
            @echo WARNING^: Version of CEMU not found in log^.txt ^!
            goto:eof
        )

        REM : if current version >=1.12.0
        call:compareVersions !versionRead! "1.12.0" result
        if ["!result!"] == [""] @echo Error when comparing versions
        if !result! EQU 50 @echo Error when comparing versions
        if !result! EQU 2 (
            @echo WARNING^: Last Cemu's install in !cemuInstallFolder:"=! is anterior to 1^.12^.0 ^!
            @echo         And does not support games^'list
            goto:eof
        )
        set "%2=!cemuInstallFolder!"

    goto:eof

    REM : get a node value in a xml file
    REM : !WARNING! current directory must be !BFW_RESOURCES_PATH!
    :getValueInXml

        set "xPath="%~1""
        set "xmlFile="%~2""

        for /F "delims=~" %%x in ('xml.exe sel -t -c !xPath! !xmlFile!') do (
            set "%3=%%x"

            goto:eof
        )

        set "%3=NOT_FOUND"

    goto:eof
    REM : ------------------------------------------------------------------

    :resolveSettingsPath
        set "prefix=%GAME_FOLDER_PATH:"=%\Cemu\settings\"
        set "%1=!css:%prefix%=!"
    goto:eof
    REM : ------------------------------------------------------------------

    :getModifiedFile
        set "folder="%~1""
        set "pattern="%~2""
        set "way=-First"

        if ["%~3"] == ["first"] set "way=-Last"

        REM : minimize all windows befaore launching in full screen
        set "psCommand="Get-ChildItem -recurse -Path !folder:"='! -Filter !pattern:"='! ^| Sort-Object LastAccessTime -Descending ^| Select-Object !way! 1 ^| Select -ExpandProperty FullName""
        for /F "delims=~" %%a in ('powershell !psCommand! 2^>NUL') do set "%4="%%a"" && goto:eof
        set "%4="NOT_FOUND""
    goto:eof
    REM : ------------------------------------------------------------------



    :getStats

        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        REM : cd to codeFolder
        pushd !codeFolder!
        for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : update !cs! games stats for !GAME_TITLE!
        set "sf="!GAME_FOLDER_PATH:"=!\Cemu\settings""
        set "lls="!sf:"=!\!user:"=!_lastSettings.txt"
        if not exist !lls! goto:eof

        pushd !sf!
        :getLastModifiedSettings
        for /F "delims=~" %%i in ('type !lls!') do set "ls=%%i"

        if not exist !ls!  (
            @echo Warning ^: last settings folder was not found^, !ls! does not exist

            REM : rebuild it
            call:getModifiedFile !sf! "!user:"=!_settings.xml" last css
            if not exist !css! del /F !lls! > NUL 2>&1 && goto:eof
            call:resolveSettingsPath ltarget
            @echo !ltarget!> !lls!

            goto:getLastModifiedSettings
        )
        set "lst="!sf:"=!\!ls:"=!""
        pushd !BFW_RESOURCES_PATH!

        for /F "delims=~" %%k in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxk"
        @echo - !GAME_TITLE!

        REM : get game Id with RPX path
        set "RPX_FILE_PATH="!codeFolder:"=!\!RPX_FILE:"=!""
        set "gamePath=!RPX_FILE_PATH!"

        REM : get game Id with RPX path
        :getRpx

        call:getValueInXml "//GameCache/Entry[path='!gamePath:"=!']/title_id/text()" !lst! gid
        if not ["!gid!"] == ["NOT_FOUND"] goto:updateGameStats

        set "gamePath_USB="!drive!!gamePath:~3!"

        if [!gamePath!] == [!gamePath_USB!] (
            REM : try with _BatchFW_Install\logs\ and left for BatchFw V14 compatibility
            echo !gamePath! | find "_BatchFW_Install" > NUL 2>&1 && (
                set "gamePath_LOGS=!gamePath:%GAME_TITLE%=_BatchFW_Install\logs\%GAME_TITLE%!"
                if [!gamePath!] == [!gamePath_LOGS!] goto:eof
                set "gamePath=!gamePath_LOGS!"
                goto:getRpx
            )
            goto:eof
        )
        goto:getRpx

        :updateGameStats

        REM : update !cs! games stats for !GAME_TITLE! using !ls! ones
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\updateGameStats.bat""
        wscript /nologo !StartHiddenWait! !toBeLaunch! !lst! !cs! !gid!

        set /A "GAMES_PLAYED+=1"

    goto:eof

    REM : COMPARE VERSIONS : function to count occurences of a separator
    :countSeparators
        set "string=%~1"
        set /A "count=0"

        :again
        set "oldstring=!string!"
        set "string=!string:*%sep%=!"
        set /A "count+=1"
        if not ["!string!"] == ["!oldstring!"] goto:again
        set /A "count-=1"
        set "%2=!count!"

    goto:eof

    REM : COMPARE VERSIONS :
    REM : if vit < vir return 1
    REM : if vit = vir return 0
    REM : if vit > vir return 2
    :compareVersions
        set "vit=%~1"
        set "vir=%~2"

        REM : format strings
        echo %vir% | findstr /VR [a-zA-Z] > NUL 2>&1 && set "vir=!vir!00"
        echo !vir! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vir! vir
        echo %vit% | findstr /VR [a-zA-Z] > NUL 2>&1 && set "vit=!vit!00"
        echo !vit! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vit! vit

        REM : versioning separator (init to .)
        set "sep=."
        @echo !vit! | find "-" > NUL 2>&1 set "sep=-"
        @echo !vit! | find "_" > NUL 2>&1 set "sep=_"

        call:countSeparators !vit! nbst
        call:countSeparators !vir! nbsr

        REM : get the number minimum of sperators found
        set /A "minNbSep=!nbst!"
        if !nbsr! LSS !nbst! set /A "minNbSep=!nbsr!"

        if !minNbSep! NEQ 0 goto:loopSep

        if !vit! EQU !vir! set "%3=0" && goto:eof
        if !vit! LSS !vir! set "%3=2" && goto:eof
        if !vit! GTR !vir! set "%3=1" && goto:eof

        :loopSep
        set /A "minNbSep+=1"
        REM : Loop on the minNbSep and comparing each number
        REM : note that the shell can compare 1c with 1d for example
        for /L %%l in (1,1,!minNbSep!) do (

            call:compareDigits %%l result

            if not ["!result!"] == [""] if !result! NEQ 0 set "%3=!result!" && goto:eof
        )
        REM : check the length of string
        call:strLength !vit! lt
        call:strLength !vir! lr

        if !lt! EQU !lr! set "%3=0" && goto:eof
        if !lt! LSS !lr! set "%3=2" && goto:eof
        if !lt! GTR !lr! set "%3=1" && goto:eof

        set "%3=50"

    goto:eof

    REM : COMPARE VERSION : function to compare digits of a rank
    :compareDigits
        set /A "num=%~1"

        set "dr=99"
        set "dt=99"
        for /F "tokens=%num% delims=~%sep%" %%r in ("!vir!") do set "dr=%%r"
        for /F "tokens=%num% delims=~%sep%" %%t in ("!vit!") do set "dt=%%t"

        set "%2=50"

        if !dt! LSS !dr! set "%2=2" && goto:eof
        if !dt! GTR !dr! set "%2=1" && goto:eof
        if !dt! EQU !dr! set "%2=0" && goto:eof
    goto:eof

    REM : COMPARE VERSION : function to compute string length
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

    REM : COMPARE VERSION : function to format string version without alphabetic charcaters
    :formatStrVersion

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:V=!"
        set "str=!str:v=!"
        set "str=!str:RC=!"
        set "str=!str:rc=!"

        set "str=!str:A=01!"
        set "str=!str:B=02!"
        set "str=!str:C=03!"
        set "str=!str:D=04!"
        set "str=!str:E=05!"
        set "str=!str:F=06!"
        set "str=!str:G=07!"
        set "str=!str:H=08!"
        set "str=!str:I=09!"
        set "str=!str:J=10!"
        set "str=!str:K=11!"
        set "str=!str:L=12!"
        set "str=!str:M=13!"
        set "str=!str:N=14!"
        set "str=!str:O=15!"
        set "str=!str:P=16!"
        set "str=!str:Q=17!"
        set "str=!str:R=18!"
        set "str=!str:S=19!"
        set "str=!str:T=20!"
        set "str=!str:U=21!"

        set "str=!str:W=23!"
        set "str=!str:X=24!"
        set "str=!str:Y=25!"
        set "str=!str:Z=26!"

        set "str=!str:a=01!"
        set "str=!str:b=02!"
        set "str=!str:c=03!"
        set "str=!str:d=04!"
        set "str=!str:e=05!"
        set "str=!str:f=06!"
        set "str=!str:g=07!"
        set "str=!str:h=08!"
        set "str=!str:i=09!"
        set "str=!str:j=10!"
        set "str=!str:k=11!"
        set "str=!str:l=12!"
        set "str=!str:m=13!"
        set "str=!str:n=14!"
        set "str=!str:o=15!"
        set "str=!str:p=16!"
        set "str=!str:q=17!"
        set "str=!str:r=18!"
        set "str=!str:s=19!"
        set "str=!str:t=20!"
        set "str=!str:u=21!"

        set "str=!str:w=23!"
        set "str=!str:x=24!"
        set "str=!str:y=25!"
        set "str=!str:z=26!"

        set "%2=!str!"

    goto:eof

    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion: &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get user input in allowed valuesList (beginning with default timeout value) from question and return the choice
    :getUserInput

        REM : arg1 = question
        set question=%1
        REM : arg2 = valuesList
        set valuesList=%~2
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional: if given set 1st value as default value after timeOutValue seconds)
        set timeOutValue=%~4

        REM : init return
        set "%3=?"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if [%timeOutValue%] == [] (
            set choiceCmd=choice /C %choiceValues% /CS /N /M !question!
        ) else (
            set choiceCmd=choice /C %choiceValues% /CS /N /T %timeOutValue% /D %defaultTimeOutValue% /M !question!
        )

        REM : launching and get return code
        !choiceCmd!
        set /A "cr=!ERRORLEVEL!"
        set j=1
        for %%i in ("%valuesList:,=" "%") do (

            if [!cr!] == [!j!] (
                REM : value found , return function value

                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
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

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        REM : build a relative path in case of software is installed also in games folders
        echo msg=!msg! | find %GAMES_FOLDER% > NUL 2>&1 && set "msg=!msg:%GAMES_FOLDER:"=%=%%GAMES_FOLDER:"=%%!"

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