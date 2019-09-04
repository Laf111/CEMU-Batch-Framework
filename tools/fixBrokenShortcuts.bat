@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color F0

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "shortcutsToolsFolder=!SCRIPT_FOLDER:\"="!"

    REM : Last installation path
    set "LAST_GAMES_FOLDER_PATH="TO_BE_REPLACED""
    
    @echo =========================================================
    @echo Fix broken shorcuts created from
    @echo !LAST_GAMES_FOLDER_PATH:"=!\_BatchFw_Install
    @echo =========================================================
    @echo.

    set "lastBfwInstall="!LAST_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\setup.bat""
    if exist !lastBfwInstall! (
        @echo BatchFw install is still in !LAST_GAMES_FOLDER_PATH!
        @echo There^'s no need to fix shortcuts ^!
        @echo.
        @echo =========================================================
        pause
        exit 0
    )

    set "browseFolder="!TEMP!\browseFolder.vbs""
    call:createBrowser

    :askGamesFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Enter the new location of your games"') do set "folder=%%b" && set "NEW_GAMES_FOLDER_PATH=!folder:?= !"
    if [!NEW_GAMES_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 1 > NUL 2>&1 && exit 75
        goto:askGamesFolder
    )

    del /F !browseFolder! > NUL 2>&1

    set "fnrPath="!NEW_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\resources\fnr.exe""
    if not exist !fnrPath! (
        @echo BatchFw not seems to be installed in !NEW_GAMES_FOLDER_PATH!
        @echo Cancelling^.^.^.
        @echo.
        @echo =========================================================
        pause
        exit 10
    )

    @echo Fixing shortcuts by using now !NEW_GAMES_FOLDER_PATH!^.^.^.
    @echo.

    REM : get the Wii-Games folder
    set "wiiuGF=!shortcutsToolsFolder:\BatchFw\Tools\Shortcuts=!"
    REM : cd to
    pushd !wiiuGF!
    set "tobeRemoved=!wiiuGF:"=!\"

    REM : Loop on every shorcuts found recursively
    for /F "delims=~" %%i in ('dir /S /B "*.lnk"') do call:fixShortcut "%%i"

    REM : update this script
    set "fnrLog="!NEW_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\logs\fnr_brokenShortcuts.log""
    !fnrPath! --cl --dir !shortcutsToolsFolder! --fileMask "fixBrokenShortcuts.bat" --find !LAST_GAMES_FOLDER_PATH! --replace !NEW_GAMES_FOLDER_PATH! --logFile !fnrLog! > NUL 2>&1
    del /F !fnrLog! > NUL 2>&1

    @echo.
    @echo done
    @echo.
    @echo =========================================================
    pause
    if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :createBrowser

        @echo Option Explicit > !browseFolder!
        @echo. >> !browseFolder!
        @echo Dim strPath^, objArgs^, messageText^, myStartFolder >> !browseFolder!
        @echo. >> !browseFolder!
        @echo Set objArgs = WScript^.Arguments >> !browseFolder!
        @echo. >> !browseFolder!
        @echo messageText = objArgs^(0^) >> !browseFolder!
        @echo myStartFolder="" >> !browseFolder!
        @echo If objArgs^.Count=2 Then >> !browseFolder!
        @echo     myStartFolder = objArgs^(1^) >> !browseFolder!
        @echo End If >> !browseFolder!
        @echo. >> !browseFolder!
        @echo strPath = SelectFolder^( myStartFolder^, messageText ^) >> !browseFolder!
        @echo If strPath = vbNull Then >> !browseFolder!
        @echo     WScript^.Echo """NONE""" >> !browseFolder!
        @echo Else >> !browseFolder!
        @echo     WScript^.Echo """" ^& Replace^(strPath^," "^,"?"^) ^& """" >> !browseFolder!
        @echo End If >> !browseFolder!
        @echo. >> !browseFolder!
        @echo Function SelectFolder^( myStartFolder^, messageText ^) >> !browseFolder!
        @echo. >> !browseFolder!
        @echo. >> !browseFolder!
        @echo     Dim objFolder^, objItem^, objShell >> !browseFolder!
        @echo. >> !browseFolder!
        @echo     On Error Resume Next >> !browseFolder!
        @echo     SelectFolder = vbNull >> !browseFolder!
        @echo. >> !browseFolder!
        @echo. >> !browseFolder!
        @echo. >> !browseFolder!
        @echo     Set objShell  = CreateObject^( "Shell.Application" ^) >> !browseFolder!
        @echo     Set objFolder = objShell^.BrowseForFolder^( 0^, messageText^, 0^, myStartFolder ^) >> !browseFolder!
        @echo. >> !browseFolder!
        @echo     If IsObject^( objfolder ^) Then SelectFolder = objFolder^.Self^.Path >> !browseFolder!
        @echo. >> !browseFolder!
        @echo End Function >> !browseFolder!

    goto:eof

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

        if !ERRORLEVEL! EQU 0 (
            del /F !TMP_VBS_FILE! > NUL 2>&1
            @echo ^> !shortcut:%tobeRemoved%=!
        )
    goto:eof
        