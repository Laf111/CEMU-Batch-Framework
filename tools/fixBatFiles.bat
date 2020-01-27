@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main
    setlocal EnableDelayedExpansion
    color 4F

    REM : set current char codeset
    call:setCharSet
    REM : ------------------------------------------------------------------
    REM : CEMU's Batch FrameWork Version
    set "BFW_NEXT_VERSION=V15-7"

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    pushd !BFW_PATH!

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : get the last version
    for /F "delims=~= tokens=2" %%i in ('type setup.bat ^| find "BFW_VERSION=V"') do set "value=%%i"
    set "BFW_OLD_VERSION=!value:"=!"

    echo =========================================================
    if ["!BFW_OLD_VERSION!"] == ["!BFW_NEXT_VERSION!"] (
        echo Produce BatchFw !BFW_NEXT_VERSION!
        title Produce BatchFw !BFW_NEXT_VERSION!
    ) else (
        echo Produce BatchFw !BFW_NEXT_VERSION! from !BFW_OLD_VERSION!
        title Produce BatchFw !BFW_NEXT_VERSION! from !BFW_OLD_VERSION!
    )
    echo =========================================================
REM : ------------------------------------------------------------------

    set "changeLog="!BFW_PATH:"=!\Change.log""
    REM : ------------------------------------------------------------------
    REM : Check that the new version appear in the Change.log
    type !changeLog! | find "!BFW_NEXT_VERSION!" > NUL 2>&1 && goto:patchSetup

    echo ERROR^: Change.log does not contains !BFW_NEXT_VERSION!
    pause
    exit /b 1

    REM : sleep 3 sec (called from restoreBfwDefaultSettings.bat)
    timeout /T 3 > NUL 2>&1

    :patchSetup
    echo ^> Check BFW_VERSION in files^.^.^.

    set "sf="!BFW_PATH:"=!\setup.bat""
    attrib -R !sf! > NUL 2>&1
    REM : ------------------------------------------------------------------
    REM : Patch version in setup.bat
    if not ["!BFW_OLD_VERSION!"] == ["!BFW_NEXT_VERSION!"] (
        echo Replacing !BFW_OLD_VERSION! with !BFW_NEXT_VERSION! in setup.bat
        !fnrPath! --cl --dir !BFW_PATH! --fileMask setup.bat --find "!BFW_OLD_VERSION!" --replace "!BFW_NEXT_VERSION!"
    )

    echo ^> Remove trailing space^.^.^.
    REM : remove trailing space
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_PATH! --fileMask "*.bat" --excludeFileMask "*multiplyLongInteger*" --includeSubDirectories --useRegEx --find "[ ]{1,}\r" --replace ""

    echo ^> Convert all files to ANSI and set them readonly^.^.^.
    REM : ------------------------------------------------------------------
    REM : Convert all files to ANSI and set them readonly
    for /F "delims=~" %%f in ('dir /S /B *.bat ^| find /V "fixBatFile" ^| find /V "multiplyLongInteger"') do (

        set "filePath="%%f""

        call:checkFile

        set "tmpFile=!filePath:.bat=.bfw_tmp!"
        type !filePath! > !tmpFile!
        del /F !filePath! > NUL 2>&1
        move /Y !tmpFile! !filePath! > NUL 2>&1
        attrib +R !filePath! > NUL 2>&1
    )

    REM : check multiplyLongInteger
    pushd !BFW_TOOLS_PATH!
    for /F %%r in ('multiplyLongInteger.bat 720 2') do set "result=%%r"
    if not ["!result!"] == ["1440"] (
        echo ERROR^: multiplyLongInteger^.bat format was changed ^! 720x2=!result!
        pause
        exit /b 10
    )
    echo ^> Convert multiplyLongInteger ^: OK^, 720x2=!result!

    pause
    exit /b 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions


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

    goto:eof
    REM : ------------------------------------------------------------------


    :checkFile

        type !filePath! | find /I "goto::" && echo ERROR^: syntax error in !filePath!
        type !filePath! | find "TODO" && echo WARNING^: TODO found in !filePath!

    goto:eof