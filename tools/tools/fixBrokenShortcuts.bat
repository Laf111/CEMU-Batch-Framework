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
    
    set "lastBfwInstall="!LAST_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\setup.bat""
    if not exist !lastBfwInstall! goto:begin

    echo BatchFw install is still in !LAST_GAMES_FOLDER_PATH!
    echo There^'s no need to fix shortcuts.
    echo.
    choice /C yn /N /M "Do you mean remove broken shortcuts for uninstalled games/Cemu versions (y, n)? : "
    set /A "allShortcuts=!ERRORLEVEL!"
    if !allShortcuts! EQU 1 set "NEW_GAMES_FOLDER_PATH=!LAST_GAMES_FOLDER_PATH!" & goto:fix

    echo.
    echo done
    echo.
    echo =========================================================
    pause & exit 0

    :begin
    echo =========================================================
    echo Fix broken shorcuts created from
    echo !LAST_GAMES_FOLDER_PATH:"=!\_BatchFw_Install
    echo =========================================================
    echo.

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

    :fix
    set "fnrPath="!NEW_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\resources\fnr.exe""
    if not exist !fnrPath! (
        echo BatchFw not seems to be installed in !NEW_GAMES_FOLDER_PATH!
        echo Cancelling^.^.^.
        echo.
        echo =========================================================
        pause
        exit 10
    )

    echo Fixing shortcuts for !NEW_GAMES_FOLDER_PATH!^.^.^.
    echo.

    REM : get the Wii-Games folder
    set "wiiuGF=!shortcutsToolsFolder:\BatchFw\Tools\Shortcuts=!"
    REM : cd to
    pushd !wiiuGF!
    set "tobeRemoved=!wiiuGF:"=!\"

    REM : Loop on every shorcuts found recursively
    if !allShortcuts! EQU 1 (
        for /F "delims=~" %%i in ('dir /S /B "*.lnk" 2^>NUL ^| find /V "_BatchFw " ^| find /V "Wii-U\"') do call:fixShortcut "%%i"    
    ) else (
        for /F "delims=~" %%i in ('dir /S /B "*.lnk" 2^>NUL') do call:fixShortcut "%%i"
    )

    REM : fix progress bar shortcut
    set "progressBar="!NEW_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\resources\progressBar.lnk""
    call:fixShortcut !progressBar!

    REM : update this script
    set "fnrLog="!NEW_GAMES_FOLDER_PATH:"=!\_BatchFw_Install\logs\fnr_brokenShortcuts.log""
    !fnrPath! --cl --dir !shortcutsToolsFolder! --fileMask "fixBrokenShortcuts.bat" --find !LAST_GAMES_FOLDER_PATH! --replace !NEW_GAMES_FOLDER_PATH! --logFile !fnrLog!
    del /F !fnrLog! > NUL 2>&1

    echo.
    echo done
    echo.
    echo =========================================================
    pause & exit 0

    if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :createBrowser

        echo Option Explicit > !browseFolder!
        echo. >> !browseFolder!
        echo Dim strPath^, objArgs^, messageText^, myStartFolder >> !browseFolder!
        echo. >> !browseFolder!
        echo Set objArgs = WScript^.Arguments >> !browseFolder!
        echo. >> !browseFolder!
        echo messageText = objArgs^(0^) >> !browseFolder!
        echo myStartFolder="" >> !browseFolder!
        echo If objArgs^.Count=2 Then >> !browseFolder!
        echo     myStartFolder = objArgs^(1^) >> !browseFolder!
        echo End If >> !browseFolder!
        echo. >> !browseFolder!
        echo strPath = SelectFolder^( myStartFolder^, messageText ^) >> !browseFolder!
        echo If strPath = vbNull Then >> !browseFolder!
        echo     WScript^.Echo """NONE""" >> !browseFolder!
        echo Else >> !browseFolder!
        echo     WScript^.Echo """" ^& Replace^(strPath^," "^,"?"^) ^& """" >> !browseFolder!
        echo End If >> !browseFolder!
        echo. >> !browseFolder!
        echo Function SelectFolder^( myStartFolder^, messageText ^) >> !browseFolder!
        echo. >> !browseFolder!
        echo. >> !browseFolder!
        echo     Dim objFolder^, objItem^, objShell >> !browseFolder!
        echo. >> !browseFolder!
        echo     On Error Resume Next >> !browseFolder!
        echo     SelectFolder = vbNull >> !browseFolder!
        echo. >> !browseFolder!
        echo. >> !browseFolder!
        echo. >> !browseFolder!
        echo     Set objShell  = CreateObject^( "Shell.Application" ^) >> !browseFolder!
        echo     Set objFolder = objShell^.BrowseForFolder^( 0^, messageText^, 0^, myStartFolder ^) >> !browseFolder!
        echo. >> !browseFolder!
        echo     If IsObject^( objfolder ^) Then SelectFolder = objFolder^.Self^.Path >> !browseFolder!
        echo. >> !browseFolder!
        echo End Function >> !browseFolder!

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

        REM : file / folder handler
        echo Set fso = CreateObject^("Scripting.FileSystemObject"^) >> !TMP_VBS_FILE!

        REM : remove shortcut with broken location (log files...)
        echo If NOT fso^.FileExists^(oSc^.TargetPath^) Then  >> !TMP_VBS_FILE!
        echo    If NOT fso^.FolderExists^(oSc^.TargetPath^) Then  >> !TMP_VBS_FILE!
	
        echo        WScript^.echo !shortcut!+" deleted : target path does not exist = "+oSc^.TargetPath >> !TMP_VBS_FILE!

        echo        fso^.DeleteFile^(!shortcut!^) >> !TMP_VBS_FILE!
        echo        WScript^.Quit 1  >> !TMP_VBS_FILE!
        echo     End If  >> !TMP_VBS_FILE!
        echo End If  >> !TMP_VBS_FILE!

        REM : remove shortcuts with a broken icon location (all game's shortcuts for an uninstalled/removed game)
        echo Dim icoData >> !TMP_VBS_FILE!
        echo icoData = Split^(oSc^.IconLocation, Chr^(44^)^) >> !TMP_VBS_FILE!

REM echo WScript^.echo !shortcut!  >> !TMP_VBS_FILE!
REM echo WScript^.echo "    target="+oSc^.TargetPath  >> !TMP_VBS_FILE!
REM echo WScript^.echo "    icon="+icoData^(0^) >> !TMP_VBS_FILE!

        echo If icoData^(0^) ^<^> "" Then >> !TMP_VBS_FILE!

            echo If NOT fso.FileExists^(icoData^(0^)^) Then >> !TMP_VBS_FILE!
            echo    WScript^.echo !shortcut!+" deleted : icon path does not exist = "+icoData^(0^) >> !TMP_VBS_FILE!
            echo    fso^.DeleteFile^(!shortcut!^) >> !TMP_VBS_FILE!
            echo    WScript^.Quit 1  >> !TMP_VBS_FILE!
            echo End If  >> !TMP_VBS_FILE!
        echo End If  >> !TMP_VBS_FILE!

        REM : remove games shortcuts for uninstalled versions of CEMU
        echo findpos = InStr^(oSc^.Arguments^, "launchGame") >> !TMP_VBS_FILE!
        echo If findpos ^<^> 0 Then >> !TMP_VBS_FILE!
        echo     Dim vbsArgsLine  >> !TMP_VBS_FILE!
        REM : split the command line "!launchGame!" "!CEMU_FOLDER!" "!GAME_FILE_PATH!" "!OUTPUT_FOLDER!" "!ICO_PATH!" "!MLC01_FOLDER_PATH!" !user:"=!"
        REM : using " as separator
        echo     vbsArgsLine=Split^(oSc^.Arguments^, Chr^(34^)^) >> !TMP_VBS_FILE!
        REM : vbsArgsLine(3)=!CEMU_FOLDER!
        echo     If NOT fso^.FolderExists^(vbsArgsLine^(3^)^) Then  >> !TMP_VBS_FILE!
        REM : uninstalled version of CEMU, remove the shortcut
        echo    WScript^.echo !shortcut!+" CEMU path does not exist = "+vbsArgsLine^(3^) >> !TMP_VBS_FILE!
        echo        fso^.DeleteFile^(!shortcut!^) >> !TMP_VBS_FILE!
        echo        WScript^.Quit 1  >> !TMP_VBS_FILE!
        echo     End If  >> !TMP_VBS_FILE!
        echo End If     >> !TMP_VBS_FILE!

        echo oSc^.Save  >> !TMP_VBS_FILE!
        echo WScript^.Quit 1  >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        if !ERRORLEVEL! EQU 0 (
            del /F !TMP_VBS_FILE! > NUL 2>&1
            echo ^> !shortcut:%tobeRemoved%=!
        )
    goto:eof
        