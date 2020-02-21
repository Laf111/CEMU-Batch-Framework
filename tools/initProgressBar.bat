@echo off
color f
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"
    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : create the shortcut in !BFW_RESOURCES_PATH!
    call:fixShortcut

    exit 0
goto:eof


REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    REM : function to update the shortcuts folder that become obsolete
    :fixShortcut

        set "shortcut="!BFW_RESOURCES_PATH:"=!\progressBar.lnk""
        set "target="!BFW_TOOLS_PATH:"=!\progressBar.bat""
        set "icon="!BFW_RESOURCES_PATH:"=!\icons\BatchFw.ico""

        REM : create a tempory vbs script
        set "TMP_VBS_FILE="!TEMP!\BatchFw_progressBar.vbs""

        REM : create script file
        echo set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo set oSc = oWS^.CreateShortcut^(!shortcut!^) >> !TMP_VBS_FILE!
        echo oSc^.TargetPath = !target! >> !TMP_VBS_FILE!
        echo oSc^.WorkingDirectory = !BFW_TOOLS_PATH! >> !TMP_VBS_FILE!
        echo oSc^.IconLocation = !icon! >> !TMP_VBS_FILE!

        echo oSc^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        if !ERRORLEVEL! EQU 0 del /F !TMP_VBS_FILE! > NUL 2>&1
    goto:eof
    REM : ------------------------------------------------------------------
