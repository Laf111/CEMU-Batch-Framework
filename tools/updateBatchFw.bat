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
        exit 100
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""


    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS_PATH:"=!\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_LOGS_PATH:"=!\gamesLibrary.log""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

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

    if %nbArgs% EQU 1 (
        set /A "QUIET_MODE=1"
    )

    REM : get the current version from setup
    set "BFW_VERSION=NONE"
    set "setup="!BFW_PATH:"=!\setup.bat""
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_VERSION=" ^| find /V "msg" 2^>NUL') do (
        set "BFW_VERSION=%%i"
        set "BFW_VERSION=!BFW_VERSION:"=!"
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : check if an internet connexion is active
    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"

    REM : if a network connection was not found, exit 10
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo No active connection was found, cancel updating
        exit /b 10
    )

    REM : powerShell script in _BatchFW_Graphic_Packs
    set "pwsGetVersion="!BFW_PATH:"=!\resources\ps1\getLatestBFW.ps1""

    set "bfwVR=NONE"
    for /F "usebackq delims=" %%i in (`Powershell.exe -executionpolicy remotesigned -File !pwsGetVersion!`) do set "bfwVR=%%i"
    if !ERRORLEVEL! EQU 1 (
        echo Failed to get the last BatchFw version available
        exit /b 11
    )
    if ["!bfwVR!"] == ["NONE"] (
        echo Failed to get the last BatchFw version available
        exit /b 12
    )

    REM : current version is a RC (Release Candidate) ?
    echo !BFW_VERSION! | find "RC" > NUL 2>&1 && (

        REM : BFW_VERSION is a RC
        REM : if available version is also a RC one, goto:diff
        echo !bfwVR! | find "RC" > NUL 2>&1 && goto:compare
        REM : else (available version is not a RC => update)
        goto:newVersion
    )

    REM : here BFW_VERSION is not a RC
    REM : bug to avoid V1500
    echo !bfwVR! | find "V1500" > NUL 2>&1 && (
        echo No new BatchFw update^(s^) available^, last version is still V15
        exit /b 15
    )

    echo !bfwVR! | find "RC" > NUL 2>&1 && (
        echo A release candidate version is available^, check https^:^/^/github^.com^/Laf111^/CEMU-Batch-Framework^/releases
        echo if you want to update^, do it manually^.
        timeout /T 4 > NUL 2>&1
        exit /b 14
    )
    REM : here BFW_VERSION is not a RC AND bfwVR is not a RC => continue with comparing

    :compare

    call:compareVersions %bfwVR% %BFW_VERSION% result > NUL 2>&1
    if ["!result!"] == [""] echo Error when comparing versions
    if !result! EQU 50 echo Error when comparing versions

    if !result! EQU 1 goto:newVersion
    echo No new BatchFw update^(s^) available^, last version is still !BFW_VERSION!
    exit /b 13

    :newVersion
    if !QUIET_MODE! EQU 0 (
        echo New version available, do you want to update BatchFW to !bfwVR!^?
        call:getUserInput "Enter your choice ? : (n by default in 30sec)" "n,y" ANSWER 30
        if [!ANSWER!] == ["n"] (
            echo Cancelled by user
            timeout /T 4 > NUL 2>&1
            exit /b 14
        )
    ) else (
        wscript /nologo !Start! !MessageBox! "A new version of BatchFw is available."
        exit /b 0
    )

    REM : launch graphic pack update
    echo =========================================================
    echo Updating BatchFW to !bfwVR!^.^.^.
    echo ---------------------------------------------------------

    REM : copy powerShell script in _BatchFW_Graphic_Packs
    set "pws_src="!BFW_RESOURCES_PATH:"=!\ps1\updateBFW.ps1""

    set "pws_target="!GAMES_FOLDER:"=!\updateBFW.ps1""

    copy /Y !pws_src! !pws_target! > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo Error when copying !pws_src!
        exit /b 6
    )

    REM : treatments to be done before updating to this release
    call:cleanBeforeUpdate

    pushd !GAMES_FOLDER!

    REM : launching powerShell script to downaload and extract archive
    Powershell -executionpolicy remotesigned -File updateBFW.ps1 *> updateBFW.log
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR While getting and extracting batchFw !bfwVR! ^!
        if exist !pws_target! del /F !pws_target! > NUL 2>&1
        if exist updateBFW.log del /F updateBFW.log > NUL 2>&1
        exit /b 7
    )


    if not ["!BFW_VERSION!"] == ["NONE"] call:cleanHostLogFile BFW_VERSION
    echo BFW_VERSION=!bfwVR! >> !logFile!

    if exist !pws_target! del /F !pws_target! > NUL 2>&1
    if exist updateBFW.log del /F updateBFW.log > NUL 2>&1


    REM : treatments to be done after updating to this release
    call:cleanAfterUpdate

    exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :cleanGameLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.bfw_tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    REM : treatments to be done before updating to this release
    :cleanBeforeUpdate

        set "toBeRenamed="!BFW_TOOLS_PATH:"=!\downloadGame.bat""
        set "newName="!BFW_TOOLS_PATH:"=!\downloadGames.bat""
        if exist !toBeRenamed! move /Y !toBeRenamed! !newName! > NUL 2>&1

        set "toBeRenamed="!BFW_RESOURCES_PATH:"=!\icons\downloadGame.ico""
        set "newName="!BFW_RESOURCES_PATH:"=!\icons\downloadGames.ico""
        if exist !toBeRenamed! move /Y !toBeRenamed! !newName! > NUL 2>&1
        
    goto:eof
    REM : ------------------------------------------------------------------

    REM : treatments to be done after updating to this release
   :cleanAfterUpdate


        REM : clean old icons and jpg files
        pushd !GAMES_FOLDER!

        REM : fix : replace [DLC] by (DLC)
        set "pat="*[DLC]*""
        for /F "delims=~" %%i in ('dir /B /S /A:D !pat! 2^> NUL') do (
            set "oldName="%%i""
            set "newName=!oldName:[DLC]=(DLC)!"
            move /Y !oldName! !newName! > NUL 2>&1
        )

        REM : fix : replace [UPDATE DATA] by (UPDATE DATA)
        set "pat="*[UPDATE DATA]*""
        for /F "delims=~" %%i in ('dir /B /S /A:D !pat! 2^> NUL') do (
            set "oldName="%%i""
            set "newName=!oldName:[UPDATE DATA]=(UPDATE DATA)!"
            move /Y !oldName! !newName! > NUL 2>&1
        )

        REM : get the last location from logFile
        set "OUTPUT_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set "OUTPUT_FOLDER="%%i""
        if not [!OUTPUT_FOLDER!] == ["NONE"] (

            REM : instanciate a fixBrokenShortcut.bat
            set "fbsf="!OUTPUT_FOLDER:"=!\BatchFw\Tools\Shortcuts""

            mkdir !fbsf! > NUL 2>&1
            set "target="!fbsf:"=!\fixBrokenShortcuts.bat""

            del /F !target! > NUL 2>&1
            robocopy !BFW_TOOLS_PATH! !fbsf! "fixBrokenShortcuts.bat" > NUL 2>&1

            set "fnrLog="!BFW_LOGS_PATH:"=!\fnr_setup.log""
            !fnrPath! --cl --dir !fbsf! --fileMask "fixBrokenShortcuts.bat" --find "TO_BE_REPLACED" --replace !GAMES_FOLDER! --logFile !fnrLog!
            del /F !fnrLog! > NUL 2>&1
            attrib +R !target!

        )

        set "bcp="!GAMES_FOLDER:"=!\_BatchFw_Missing_Games_Profiles""
        if exist !bcp! rmdir /Q /S !bcp! > NUL 2>&1

        set "wm="!BFW_RESOURCES_PATH:"=!\winmerge""
        if exist !wm! rmdir /Q /S !wm! > NUL 2>&1

        call:cleanGameLogFile "graphic packs version"
        
    goto:eof
    REM : ------------------------------------------------------------------


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
        echo %vir% | findstr /V /R [a-zA-Z] > NUL 2>&1 && set "vir=!vir!00"
        echo !vir! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vir! vir
        echo %vit% | findstr /V /R [a-zA-Z] > NUL 2>&1 && set "vit=!vit!00"
        echo !vit! | findstr /R [a-zA-Z] > NUL 2>&1 && call:formatStrVersion !vit! vit

        REM : versioning separator (init to .)
        set "sep=."
        echo !vit! | find "-" > NUL 2>&1 && set "sep=-"
        echo !vit! | find "_" > NUL 2>&1 && set "sep=_"

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

   :cleanHostLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!logFile:"=!.bfw_tmp""
        if exist !logFileTmp! (
            del /F !logFile! > NUL 2>&1
            move /Y !logFileTmp! !logFile! > NUL 2>&1
        )

        type !logFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !logFile! > NUL 2>&1
        move /Y !logFileTmp! !logFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to get user input in allowed valuesList (beginning with default timeout value) from question and return the choice
    :getUserInput

        REM : arg1 = question
        set "question="%~1""
        REM : arg2 = valuesList
        set "valuesList=%~2"
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional : if given set 1st value as default value after timeOutValue seconds)
        set "timeOutValue=%~4"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if ["%timeOutValue%"] == [""] (
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
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
