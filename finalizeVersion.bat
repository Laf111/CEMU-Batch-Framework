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
    set "BFW_NEXT_VERSION=V13-6"

    REM : get the last version
    for /F "delims=~= tokens=2" %%i in ('type setup.bat ^| find "BFW_VERSION=V"') do set "value=%%i"
    set "BFW_OLD_VERSION=!value:"=!"

    @echo =========================================================
    if ["!BFW_OLD_VERSION!"] == ["!BFW_NEXT_VERSION!"] (
        @echo Produce BatchFw !BFW_NEXT_VERSION!
        title Produce BatchFw !BFW_NEXT_VERSION!
    ) else (
        @echo Produce BatchFw !BFW_NEXT_VERSION! from !BFW_OLD_VERSION!
        title Produce BatchFw !BFW_NEXT_VERSION! from !BFW_OLD_VERSION!
    )
    @echo =========================================================
REM : ------------------------------------------------------------------

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_PATH=!SCRIPT_FOLDER:\"="!"
    pushd !BFW_PATH!
    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "changeLog="!BFW_PATH:"=!\Change.log""
    REM : ------------------------------------------------------------------
    REM : Check that the new version appear in the Change.log
    type !changeLog! | find "!BFW_NEXT_VERSION!" > NUL && goto:patchSetup

    @echo ERROR^: Change.log does not contains !BFW_NEXT_VERSION!
    pause
    exit /b 1


    :patchSetup
    REM : ------------------------------------------------------------------
    REM : Patch version in setup.bat
    if not ["!BFW_OLD_VERSION!"] == ["!BFW_NEXT_VERSION!"] (
        @echo Replacing !BFW_OLD_VERSION! with !BFW_NEXT_VERSION! in setup.bat
        !fnrPath! --cl --dir !BFW_PATH! --fileMask setup.bat --find "!BFW_OLD_VERSION!" --replace "!BFW_NEXT_VERSION!"
    )

    REM : remove trailing space
    wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_PATH! --fileMask "*.bat" --excludeFileMask "finalizeVersion" --includeSubDirectories --useRegEx --find "[ ]{1,}\r" --replace ""
    
    REM : ------------------------------------------------------------------
    REM : Convert all files to ANSI and set readonly
    for /F "delims=~" %%f in ('dir /S /B *.bat ^| find /V "!THIS_SCRIPT!"') do (

        set "filePath="%%f""
        set "tmpFile=!filePath:.bat=.tmp!"
        type !filePath! > !tmpFile!
        del /F !filePath! > NUL
        move /Y !tmpFile! !filePath! > NUL
        attrib +R !filePath! > NUL
    )

    pause
    exit /b 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions


    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims==" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL

    goto:eof
    REM : ------------------------------------------------------------------

