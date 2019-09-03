@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color F0

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "shortcutsToolsFolder=!SCRIPT_FOLDER:\"="!"
    set "browseFolder="!shortcutsToolsFolder:"=!\BrowseFolderDialog.vbs""
    set "fnrPath="!shortcutsToolsFolder:"=!\fnr.exe""

    REM : Last installation path
    set "LAST_GAMES_FOLDER_PATH="TO_BE_REPLACED""

    @echo =========================================================
    @echo Fix broken shorcuts created from
    @echo !LAST_GAMES_FOLDER_PATH:"=!\_BatchFw_Install
    @echo =========================================================
    @echo.

    :askGamesFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Enter the new location of your games"') do set "folder=%%b" && set "NEW_GAMES_FOLDER_PATH=!folder:?= !"
    if [!NEW_GAMES_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 1 > NUL 2>&1 && exit 75
        goto:askGamesFolder
    )

    @echo Fixing shortcuts by using now !NEW_GAMES_FOLDER_PATH!^.^.^.

    REM : get the Wii-Games folder
    set "wiiuGF=!shortcutsToolsFolder:\BatchFw\Tools\Shortcuts=!"
    REM : cd to
    pushd !wiiuGF!

    REM : Loop on every shorcuts found recursively
    for /F "delims=~" %%i in ('dir /S /B "*.lnk"') do call:fixShortcut "%%i"

    REM : update this script
    set "fnrLog="!NEW_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\logs\fnr_brokenShortcuts.log""
    !fnrPath! --cl --dir !shortcutsToolsFolder! --fileMask "fixBrokenShortcuts.bat" --find !LAST_GAMES_FOLDER_PATH! --replace !NEW_GAMES_FOLDER_PATH! --logFile !fnrLog!  > NUL
    del /F !fnrLog! > NUL 2>&1

    @echo done
    timeout /T 2
    if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions


    REM : function to update the shortcuts folder that become obsolete
    :fixShortcut

        set "shortcut="%~1""

        REM : create a tempory vbs script
        set "TMP_VBS_FILE="!TEMP!\FIXRACC.vbs""

        REM : create script file
        echo set oWS = WScript^.CreateObject^("WScript.Shell"^) > !TMP_VBS_FILE!
        echo set oSc = oWS^.CreateShortcut^(!shortcut!^) >> !TMP_VBS_FILE!

        echo oSc^.TargetPath = Replace^(oSc^.TargetPath^,!LAST_GAMES_FOLDER_PATH!^,!NEW_GAMES_FOLDER_PATH!^) >> !TMP_VBS_FILE!
        echo oSc^.Arguments = Replace^(oSc^.Arguments^,!LAST_GAMES_FOLDER_PATH!^,!NEW_GAMES_FOLDER_PATH!^) >> !TMP_VBS_FILE!
        echo oSc^.WorkingDirectory = Replace^(oSc^.WorkingDirectory^,!LAST_GAMES_FOLDER_PATH!^,!NEW_GAMES_FOLDER_PATH!^) >> !TMP_VBS_FILE!
        echo oSc^.IconLocation = Replace^(oSc^.IconLocation^,!LAST_GAMES_FOLDER_PATH!^,!NEW_GAMES_FOLDER_PATH!^) >> !TMP_VBS_FILE!

        echo oSc^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        if !ERRORLEVEL! EQU 0 del /F !TMP_VBS_FILE!

    goto:eof
        