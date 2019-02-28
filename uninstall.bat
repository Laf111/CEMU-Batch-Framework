@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"
    title !THIS_SCRIPT!

    REM : directory of this script
    pushd "%~dp0" >NUL && set "BFW_PATH="%~dp0"" && popd >NUL

    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""


    REM : get current date
    for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : set current char codeset
    call:setCharSet

    REM : get batch version from log file
    REM : search in logFile, getting only the last occurence
    set "bfwVersion=NONE"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "BFW_VERSION" 2^>NUL') do set "bfwVersion=%%i"
    set "bfwVersion=!bfwVersion: =!"

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    set "WIIU_GAMES_FOLDER="NONE""

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% EQU 0 goto:uninstall

    if %nbArgs% NEQ 1 (
        @echo ERROR ^: on arguments passed ^!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" WIIU_GAMES_FOLDER
        @echo given {%*}
        pause
        exit 99
    )
    REM : get and check WIIU_GAMES_FOLDER
    set "WIIU_GAMES_FOLDER=!args[0]!"
    if not exist !WIIU_GAMES_FOLDER! (
        @echo ERROR ^: WIIU_GAMES_FOLDER folder !WIIU_GAMES_FOLDER! does not exist ^!
        pause
        exit 1
    )

    :uninstall

    REM set Shell.BrowseForFolder arg vRootFolder
    REM : 0  = ShellSpecialFolderConstants.ssfDESKTOP
    set "DIALOG_ROOT_FOLDER="0""


    @echo =========================================================
    @echo         CEMU^'s Batch Framework !bfwVersion! uninstaller
    @echo =========================================================
    @echo ^(in case of false input ^: close this main window to cancel^)
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    call:getUserInput "Are you sure you want to uninstall Batch FW ? (y, n)" "y,n" ANSWER
    @echo ---------------------------------------------------------
    if [!ANSWER!] == ["n"] goto:eof

    if not exist _BatchFW_Graphic_Packs goto:removeReports
    call:getUserInput "Remove _BatchFW_Graphic_Packs folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeReports
    rmdir /Q /S _BatchFW_Graphic_Packs  2>NUL
    @echo ^> _BatchFW_Graphic_Packs deleted ^!
    @echo ---------------------------------------------------------
    :removeReports
    if not exist _BatchFW_Games_Compatibility_Reports goto:removeMissing
    call:getUserInput "Remove _BatchFW_Games_Compatibility_Reports folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeMissing
    rmdir /Q /S _BatchFW_Games_Compatibility_Reports  2>NUL
    @echo ^> _BatchFW_Games_Compatibility_Reports deleted ^!
    @echo ---------------------------------------------------------
    :removeMissing
    if not exist _BatchFW_Missing_Games_Profiles goto:removeController
    call:getUserInput "Remove _BatchFW_Missing_Games_Profiles folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeController
    rmdir /Q /S _BatchFW_Missing_Games_Profiles 2>NUL
    @echo ^> _BatchFW_Missing_Games_Profiles deleted ^!
    @echo ---------------------------------------------------------
    :removeController
    if not exist _BatchFW_Controller_Profiles goto:removeGLCache
    call:getUserInput "Remove _BatchFW_Controller_Profiles folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeGLCache
    rmdir /Q /S _BatchFW_Controller_Profiles 2>NUL
    @echo ^> _BatchFW_Controller_Profiles deleted ^!

    @echo ---------------------------------------------------------
    :removeGLCache
    call:getUserInput "Remove your OpenGL cache backup ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:restoreMlc01

    REM : search your current GLCache
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence

    set "OPENGL_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"

    if [!OPENGL_CACHE!] == ["NOT_FOUND"] goto:restoreMlc01

    REM : openGL cache location
    :cleanBfwGlCache
    set "GLCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuGLCache!\"

    if not exist !GLCacheSavesFolder! goto:restoreMlc01
    rmdir /Q /S !GLCacheSavesFolder! 2>NUL

    @echo ^> OpenGL cache backup was removed ^!

    @echo ---------------------------------------------------------
    :restoreMlc01
    set "mlc01Restored=0"
    call:getUserInput "Restore mlc01 data of each games ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:restoreTransShaderCache

    :getMlc01Target

    call:getFolderPath "Please enter mlc01 target folder" !DIALOG_ROOT_FOLDER! MLC01_FOLDER
    set "script="!BFW_TOOLS_PATH:"=!\restoreMlc01DataForAllGames.bat""
    wscript /nologo !StartWait! !script! !MLC01_FOLDER!
    set "mlc01Restored=1"

    call:getUserInput "Do you want to define another mlc01 target folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["y"] goto:getMlc01Target

    @echo ^> mlc01 data restored
    @echo ---------------------------------------------------------

    :restoreTransShaderCache
    set "TransShaderCacheRestored=0"
    call:getUserInput "Restore all transferable shader cache to a Cemu folder ? (y, n)" "y,n" ANSWER
  
    if [!ANSWER!] == ["n"] goto:removeExtraFolders

    :askCemuFolder
    
    call:getFolderPath "Please enter a Cemu target folder" !DIALOG_ROOT_FOLDER! CEMU_FOLDER
    set "script="!BFW_TOOLS_PATH:"=!\restoreTransShadersForAllGames.bat""
  
    wscript /nologo !StartWait! !script! !CEMU_FOLDER!
    set "TransShaderCacheRestored=1"
    @echo ^> transferable shader caches restored
    @echo ---------------------------------------------------------


    :removeExtraFolders

    for /F "delims=" %%x in ('dir /b /a:d /s mlc01 2^>NUL') do (
        @echo At least one mlc01 subfolder still exist in your games library^.
        @echo If you restored previously each mlc01^'s data, you can choose to delete them all^.
        @echo Otherwise^, keep them^. It contain update^,DLC and your last game^'s saves ^^!
        @echo ---------------------------------------------------------
        call:getUserInput "Delete all mlc01 game's subfolders ? (y, n)" "y,n" ANSWER
        @echo ---------------------------------------------------------
        if [!ANSWER!] == ["n"] goto:removeShaderCache
        REM : get out of the loop
        goto:removeMlc01
    )
    :removeMlc01
    for /F "delims=" %%x in ('dir /b /a:d /s mlc01 2^>NUL') do (
        rmdir /Q /S "%%x" 2>NUL
    )

    :removeShaderCache
    for /F "delims=" %%x in ('dir /b /a:d /s shaderCache 2^>NUL') do (
        @echo At least one shaderCache subfolder still exist in your games library^.
        @echo If you restored previously each shaderCache, you can choose to delete them all^.
        @echo Otherwise^, keep them^. It contain your last game^'s transferable cache ^^!
        @echo ---------------------------------------------------------
        call:getUserInput "Delete all shaderCache games subfolders ? (y, n)" "y,n" ANSWER
        @echo ---------------------------------------------------------
        if [!ANSWER!] == ["n"] goto:removeFoldersLeft
        REM : get out of the loop
        goto:removeTransCache
    )
    :removeTransCache
    for /F "delims=" %%x in ('dir /b /a:d /s shaderCache 2^>NUL') do (
        rmdir /Q /S "%%x" 2>NUL
    )
    :removeFoldersLeft
    @echo Do you want to remove all Cemu extra subfolders created^^?
    @echo That^'s included ^:
    @echo - all compressed saves for all users
    @echo - all controllers profiles
    @echo - all CEMU saved settings
    @echo - your own graphic packs if created ones in Cemu game^'s subfolder
    @echo That^'s excluded ^:
    @echo - mods ^(founded ones will be moved in the game^'s folder before deleting Cemu subfolder^)
    @echo ---------------------------------------------------------

    call:getUserInput "Remove all Cemu extra subfolders created ? (y, n)" "y,n" ANSWER
    @echo ---------------------------------------------------------
    if [!ANSWER!] == ["n"] goto:removeShortcuts

    for /F "delims=" %%x in ('dir /b /a:d /s mods ^| find "Cemu" 2^>NUL') do (
        @echo At least one mods subfolder still exist in your games library^.
        @echo Moving all mods folders in game^'s folders ^.^.^.

        REM : move it under game folder
        for %%a in ("%%i") do set "parentFolder="%%~dpa""
        set "cemuFolder=!parentFolder:~0,-2!""
        for %%a in (!cemuFolder!) do set "parentFolder="%%~dpa""
        set "GAME_FOLDER=!parentFolder:~0,-2!""

        move /Y "%%i" !GAME_FOLDER! > NUL 2>&1
    )

    for /F "delims=" %%x in ('dir /b /a:d /s code 2^>NUL') do (

        set "cf="%%x""
        for %%a in (!cf!) do set "parentFolder="%%~dpa""
        set "gf=!parentFolder:~0,-2!""
        set "cemuFolder="!gf:"=!\Cemu""
        rmdir /Q /S !cemuFolder! 2>NUL
    )
    @echo ^> Batch FW^'s extra files and folders were removed
    @echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    :removeShortcuts
    pushd !GAMES_FOLDER!

    REM : remove shortcut folder
    REM : if not called from this folder
    if [!WIIU_GAMES_FOLDER!] == ["NONE"] (
    REM : get the last location from logFile
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
    )
    if not [!WIIU_GAMES_FOLDER!] == ["NONE"] (

        rmdir /Q /S !WIIU_GAMES_FOLDER! 2>NUL
        @echo ^> !WIIU_GAMES_FOLDER! deleted ^!
        @echo ---------------------------------------------------------
    )

    @echo ^> Done^.
    @echo =========================================================
    @echo This windows will close automatically in 15s
    timeout /T 4 > NUL

    REM remove this folder
    rmdir /Q /S !BFW_PATH! 2>NUL

    if %nbArgs% EQU 0 endlocal
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to open browse folder dialog and check folder's DOS compatbility
    :getFolderPath

        set "TITLE="%~1""
        set "ROOT_FOLDER="%~2""

        :askForFolder
        REM : open folder browser dialog box
        call:runPsCmd !TITLE! !ROOT_FOLDER! FOLDER_PATH
        REM : powershell call always return %ERRORLEVEL%=0

        if [!FOLDER_PATH!] == ["NONE"] (
                choice /C yn /N /M "Do you want to cancel (y, n)? : "
                if !ERRORLEVEL! EQU 1 exit 66
                goto:askForFolder
        )
        REM : check the path
        call:checkPathForDos !FOLDER_PATH!
        set /A "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 goto:eof

        REM detect (,),&,%,£ and ^
        set "str=!FOLDER_PATH!"
        set "str=!str:?=!"
        set "str=!str:^=!"
        set "newPath="!str:"=!""

        if not [!FOLDER_PATH!] == [!newPath!] (
            @echo This folder is not compatible with DOS^. Remove special character from !FOLDER_PATH!
            goto:askForFolder
        )

        REM : trailing slash? if so remove it
        set "_path=!FOLDER_PATH:"=!"
        if [!_path:~-1!] == [\] set "FOLDER_PATH=!FOLDER_PATH:~0,-2!""

        REM : set return value
        set "%3=!FOLDER_PATH!"

    goto:eof

    REM : launch ps script to open dialog box
    :runPsCmd
        set "psCommand="(new-object -COM 'shell.Application')^.BrowseForFolder(0,'%1',0,'%~2').self.path""
      
        set "folderSelected="NONE""
        for /F "usebackq delims=" %%I in (`powershell !psCommand!`) do (
            set "folderSelected="%%I""
        )
        if [!folderSelected!] == ["NONE"] call:runPsCmd %1 %2 FOLDER_PATH 
        REM : in case of DOS characters substitution (might never arrive)
        if not exist !folderSelected! call:runPsCmd %1 %2 FOLDER_PATH
        set "%3=!folderSelected!"

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

            if [%cr%] == [!j!] (
                REM : value found , return function value

                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
        )

    goto:eof
    REM : ------------------------------------------------------------------

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
