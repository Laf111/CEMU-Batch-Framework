@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main
    setlocal EnableDelayedExpansion
    color 4F

    REM : set current char codeset
    call:setCharSet
    
    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit /b 100
    )
    
    REM : ------------------------------------------------------------------
    REM : CEMU's Batch FrameWork Version to produce
    set "BFW_NEXT_VERSION=V23-1"

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=%parentFolder:~0,-2%""
    pushd %BFW_PATH%

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    if not exist !BFW_LOGS! mkdir !BFW_LOGS! > NUL 2>&1
    
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""
    set "fixBatFilesLog="!BFW_LOGS:"=!\fixBatFiles.log""  

    REM : get the last version
    for /F "delims=~= tokens=2" %%i in ('type setup.bat ^| find "BFW_VERSION=V"') do set "value=%%i"
    set "BFW_OLD_VERSION=!value:"=!"
    
    REM : check if folder name contains forbiden character for batch file
    call:securePathForDos %BFW_PATH% SAFE_PATH
    
    if not [%BFW_PATH%] == [!SAFE_PATH!] (
        echo ERROR ^: please rename your folders to have this compatible path 
        echo !SAFE_PATH!
        pause
        exit 95
    )
            
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
        attrib -R !sf! > NUL 2>&1
        !fnrPath! --cl --dir !BFW_PATH! --fileMask setup.bat --find "!BFW_OLD_VERSION!" --replace "!BFW_NEXT_VERSION!" --logFile !fixBatFilesLog!
    )

    set "toBeRemoved=%BFW_PATH:"=%\"

    REM : check Wii-U Title database integrity
    echo ^> Check Wii-U Title database integrity^.^.^.
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    set /A "nbLines=0"
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /C ";"') do set /A "nbLines=%%i"
    if !nbLines! EQU 0 (
        echo ERROR^: !wiiTitlesDataBase! seems to be corrupted
    ) else (
        set /A "nbEntries=nbLines-1"
        echo  Number of entries ^(games declined by regions^) ^: !nbEntries!

        type !wiiTitlesDataBase! | find /V "Native Fps" | find /V "';" && (
            echo ERROR^: line above in !wiiTitlesDataBase! seems to be misformed
        )
        type !wiiTitlesDataBase! | find /V "Native Fps" | find /V ";'" && (
            echo ERROR^: line above in !wiiTitlesDataBase! seems to be misformed
        )
    )

    echo ^> Check bat files^.^.^.
    echo.
    
    REM : Convert all files to ANSI and set them readonly
    set "pat="*.bat""
    for /F "delims=~" %%f in ('dir /S /B !pat! ^| find /V "fixBatFile" ^| find /V "multiply" ^| find /V "downloadGames" ^| find /V "convertWiiuFiles.bat" ^| find /V "updateGame.bat" ^| find /V "checkGameContentAvailability" ^| find /V "detectAndRenameInvalidPath" ^| find /V "downloadTitleId"') do (

        set "filePath="%%f""

        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo ^> !filePath:%toBeRemoved%=!
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo - remove readonly attribute
        attrib -R !filePath! > NUL 2>&1

        echo - remove trailing spaces
        REM : file name
        for /F "delims=~" %%i in (!filePath!) do set "fileName=%%~nxi"

        REM : remove trailing space
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_PATH! --fileMask "!fileName!"  --includeSubDirectories --useRegEx --find "[ ]{1,}\r" --replace "" --logFile !fixBatFilesLog!

        echo - check file consistency
        call:checkFile

        echo - convert file to ANSI
        set "tmpFile=!filePath:.bat=.bfw_tmp!"
        type !filePath! > !tmpFile!
        del /F !filePath! > NUL 2>&1
        move /Y !tmpFile! !filePath! > NUL 2>&1

        echo - set readonly attribute
        attrib +R !filePath! > NUL 2>&1
    )

    REM : remove readonly attribute on fixBrokenShortcuts.bat
    set "filePath="!BFW_TOOLS_PATH:"=!\fixBrokenShortcuts.bat""
    attrib +R !filePath! > NUL 2>&1

    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    echo.
    echo checking specific files^.^.^.
    echo.

    set "filePath="!BFW_TOOLS_PATH:"=!\downloadTitleId.bat""
    echo ^> tools/downloadTitleId.bat

    attrib +R !filePath! > NUL 2>&1
    type !filePath! | find /I "delims=~	" > NUL 2>&1 && goto:checkDownloadGames
    echo ERROR^: TAB was not found line 105^, the file format is not ANSI anymore ^?

    :checkDownloadGames
    set "filePath="!BFW_TOOLS_PATH:"=!\downloadGames.bat""
    echo ^> tools/downloadGames.bat

    attrib +R !filePath! > NUL 2>&1
REM    type !filePath! | find /I "™" > NUL 2>&1 && goto:checkConvertWiiuFiles
REM    echo ERROR^: char ™ not found, the file format is not ANSI anymore ^?

REM    :checkConvertWiiuFiles
REM    set "filePath="!BFW_TOOLS_PATH:"=!\convertWiiuFiles.bat""
REM    echo ^> tools/convertWiiuFiles.bat

REM    attrib +R !filePath! > NUL 2>&1
    type !filePath! | find /I "™" > NUL 2>&1 && goto:checkmultiply
    echo ERROR^: char ™ not found, the file format is not ANSI anymore ^?

    :checkmultiply
    set "filePath="!BFW_TOOLS_PATH:"=!\multiply.bat""
    echo ^> tools/multiply.bat

    attrib +R !filePath! > NUL 2>&1
    pushd !BFW_TOOLS_PATH!
    for /F %%a in ('!filePath! 1234 4321') do set /A "result=%%a"
    if !result! NEQ 5332114 (
        echo ERROR^: 1234x4321 ^<^> 5332114 ^(=!result!^) the file format is not ANSI anymore ^?
    )

    set "filePath="!BFW_TOOLS_PATH:"=!\updateGames.bat""
    echo ^> tools/updateGames.bat
    attrib +R !filePath! > NUL 2>&1

    set "filePath="!BFW_TOOLS_PATH:"=!\checkGameContentAvailability.bat""
    echo ^> tools/checkGameContentAvailability.bat
    attrib +R !filePath! > NUL 2>&1

    set "filePath="!BFW_TOOLS_PATH:"=!\detectAndRenameInvalidPath.bat""
    echo ^> tools/detectAndRenameInvalidPath.bat
    attrib +R !filePath! > NUL 2>&1

    echo.
    echo =========================================================
    echo done
    echo.

    pause
    exit /b 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    REM : remove DOS forbiden character from a path
    :securePathForDos
        REM : str is expected protected with double quotes
        set "string=%~1"
        
        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed in path
            set "string=!string:*=!"
        )

        echo "%~1" | find "(" > NUL 2>&1 && (
            echo ^( is not allowed in path
            set "string=!string:(=!"
        )
        echo "%~1" | find ")" > NUL 2>&1 && (
            echo ^) is not allowed in path
            set "string=!string:)=!"
        )
        if ["!string!"] == ["%~1"] (

            set "string=!string:&=!"
            set "string=!string:?=!"
            set "string=!string:\!=!"
            set "string=!string:%%=!"
            set "string=!string:^=!"
            set "string=!string:/=!"
            set "string=!string:>=!"
            set "string=!string:<=!"
            set "string=!string:|=!"

            REM : WUP restrictions
            set "string=!string:™=!"
            set "string=!string:®=!"
            set "string=!string:©=!"
            set "string=!string:É=E!"
            
        )
        set "%2="!string!""

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

    goto:eof
    REM : ------------------------------------------------------------------


    :checkFile

        type !filePath! | find /I "2>&1 set" && echo ERROR^: syntax error1 in !filePath!
        type !filePath! | find /I "goto::" && echo ERROR^: syntax error2 in !filePath!
        type !filePath! | find /I "call::" && echo ERROR^: syntax error3 in !filePath!
        type !filePath! | find /I ".bat.bat" && echo ERROR^: syntax error4 in !filePath!
        type !filePath! | find /I ":=" | find /V "::" && echo ERROR^: syntax error5 in !filePath!
        type !filePath! | find /I " TODO" && echo WARNING^: TODO found in !filePath!
        type !filePath! | find /I "echo OK" && echo WARNING^: unexpected debug traces^? in !filePath!

        set /A "wngDetected=0"
        REM : loop on ':' find in the file
        for /F "delims=:~ tokens=2" %%p in ('type !filePath! ^| find /I /V "REM" ^| find /I /V "echo" ^| find "   :" ^| find /V "=" ^| find /I /V "choice " ^| findStr /R "[A-Z]*" 2^>NUL') do (

            set "label=%%p"
            REM : search for "call:!label!" count occurences
            set /A "nbCall=0"
            for /F "delims=~" %%c in ('type !filePath! ^| find /I /C "call:!label: =!" 2^>NUL') do set /A "nbCall=%%c"

            REM : search for "goto:!label!" count occurences
            set /A "nbGoto=0"
            for /F "delims=~" %%c in ('type !filePath! ^| find /I /C "goto:!label: =!" 2^>NUL') do set /A "nbGoto=%%c"

            if !nbCall! EQU 0 if !nbGoto! EQU 0 (
                echo.
                echo WARNING ^: !label! not used in !filePath!
                set /A "wngDetected=1"
                pause
            )
            if !nbGoto! EQU 0 if !nbCall! EQU 0 if !wngDetected! EQU 0 (
                echo.
                echo WARNING ^: !label! not used in !filePath!
                set /A "wngDetected=1"
                pause
            )
        )
        if !wngDetected! EQU 1 timeout /T 3 > NUL 2>&1

    goto:eof