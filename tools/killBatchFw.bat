@echo off
setlocal EnableExtensions
title Kill all BatchFw^'s process
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" & set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAMES_FOLDER!) do set "GAMES_FOLDER_NAME=%%~nxi"

    REM : stoping user's software
    type !logFile! | find /I "TO_BE_LAUNCHED" > NUL 2>&1 & (

        @echo ---------------------------------------------------------
        @echo killing 3rd party Software^.^.^.
        @echo ---------------------------------------------------------

        set "stopThirdPartySoftware="!BFW_TOOLS_PATH:"=!\stopThirdPartySoftware.bat""
        wscript /nologo !StartHiddenWait! !stopThirdPartySoftware!
    )

    @echo ---------------------------------------------------------
    @echo killing CEMU^.^.^.
    @echo ---------------------------------------------------------

    REM : kill CEMU's running process
    wmic process where "Name like '%%cemu.exe%%'" call terminate

    @echo ---------------------------------------------------------
    @echo killing BatchFw^'s process^.^.^.
    @echo ---------------------------------------------------------

    wmic process where "CommandLine like '%%!GAMES_FOLDER_NAME!%%'" call terminate

exit 0