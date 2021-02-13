@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main
    setlocal EnableDelayedExpansion
    color 4F

REM : ------------------------------------------------------------------
    REM : No verification is made regarding CEMU's version here
    REM : (game stats were added in CEMU V1.12.0


    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS_PATH="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""

    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

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

    if %nbArgs% NEQ 3 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" settingsSrcFile settingsTargetFile GameId
        echo given {%*}
        timeout /t 4 > NUL 2>&1
        exit 99
    )

    REM : args 1
    set "csSrc=!args[0]!"
    if not exist !csSrc! (
        echo ERROR ^: settingsSrcFile !csSrc:"=! not exist
        timeout /t 4 > NUL 2>&1
        exit 51
    )
    set "csTgt=!args[1]!"
    if not exist !csTgt! (
        echo ERROR ^: settingsTargetFile !csTgt:"=! not exist
        timeout /t 4 > NUL 2>&1
        exit 52
    )
    set "GameId=!args[2]!"
    set "GameId=!GameId:"=!"

    REM : get DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo Updating game with id !GameId! in !csTgt!
    echo using !csSrc!
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    set "csTmp="!TMP:"=!\BfwSettings_!DATE!.xml""
    echo temporary file ^: !csTmp!

    REM : if GameCache node exist in csTgt (CEMU >= 1.12.0)
    type !csTgt! | find /I "<GameCache>" > NUL 2>&1 && call:update


    exit /b !cr!
    goto:eof

REM : ------------------------------------------------------------------
REM : functions


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

    :update

        pushd !BFW_RESOURCES_PATH!
echo csSrc=!csSrc!
echo -------------------------------------------------------
type !csSrc!
echo -------------------------------------------------------
echo ^"xml^.exe^" sel -t -c ^"^/^/GameCache^/Entry^[title_id=^'!GameId!^'^]^" !csSrc!

        REM : get game's stats
        "xml.exe" sel -t -c "//GameCache/Entry[title_id='!GameId!']" !csSrc! > !csTmp! 2>NUL

echo csTmp=!csTmp!
echo -------------------------------------------------------
type !csTmp!
echo -------------------------------------------------------
        set "node="
        for /f "usebackq tokens=*" %%k in (!csTmp!) do (
          set "node=!node!%%k"
        )

        if ["!node!"] == [""] (
            echo ERROR ^: no stats were found for !GameId! in !csSrc:"=!
            timeout /t 4 > NUL 2>&1
            exit 53
        )

        REM : delete node in csTgt
        set "csTgtTmp=!csTgt:.xml=.bfw_tmp!"
        "xml.exe" ed -d "//GameCache/Entry[title_id='!GameId!']" !csTgt! > !csTgtTmp! 2>NUL

        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo Node ^:
        echo !node!

        "xml.exe" ed -s "//GameCache" -t elem -n "!node!" !csTgtTmp! > !csTmp! 2>NUL
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo replacing in temporary file

        rem : replace in file
        set "BfwSettingsLog="!BFW_LOGS_PATH:"=!\fnr_BfwSettings.log""

        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !TMP! --fileMask "BfwSettings_!DATE!.xml" --find "<<" --replace "<" --logFile !BfwSettingsLog!
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !TMP! --fileMask "BfwSettings_!DATE!.xml" --find ">/>" --replace ">" --logFile !BfwSettingsLog!

        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo pretty indent !scTgt!

        xml fo -t !csTmp! > !csTgt!
        set /A "cr=%ERRORLEVEL%"
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        if !cr! EQU 0 (
            echo done
            goto:done
        )

        REM : else check size
        for /F "tokens=*" %%a in (!csTgt!) do if %%~za NEQ 0 echo done & goto:done

        echo done with error ^!
        !MessageBox! "ERROR : when patching settings.xml. Restoring settings.xml backup, game stats computation ignored !" 4112
        echo see !csTmp! and !csTgtTmp!
        set "backup="!cs:"=!_bfw_old""
        if exist !backup! del /F !cs! > NUL 2>&1 & move /Y !backup! !cs! > NUL 2>&1

        :done
        del /F !csTmp! > NUL 2>&1
        del /F !csTgtTmp! > NUL 2>&1
        del /F !BfwSettingsLog!> NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------
