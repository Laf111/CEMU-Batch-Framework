@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"
    title Uninstall BatchFw

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"

    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_TOOLS_PATH="!BFW_PATH:"=!\tools""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenCmd="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenCmd.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    
    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    REM : set current char codeset
    call:setCharSet

    REM : get BatchFw version
    set "bfwVersion=NONE"
    set "setup="!BFW_PATH:"=!\setup.bat""
    for /F "tokens=2 delims=~=" %%i in ('type !setup! ^| find /I "BFW_VERSION="  ^| find /V "msg" 2^>NUL') do (
        set "bfwVersion=%%i"
        set "bfwVersion=!bfwVersion:"=!"
        goto:cdGF
    )
    :cdGF
    title Uninstall BatchFw !bfwVersion!

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
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" WIIU_GAMES_FOLDER
        echo given {%*}
        pause
        exit 99
    )
    REM : get and check WIIU_GAMES_FOLDER
    set "WIIU_GAMES_FOLDER=!args[0]!"
    if not exist !WIIU_GAMES_FOLDER! (
        echo ERROR ^: WIIU_GAMES_FOLDER folder !WIIU_GAMES_FOLDER! does not exist ^!
        pause
        exit 1
    )

    :uninstall
    echo =========================================================
    echo         CEMU^'s Batch Framework !bfwVersion! uninstaller
    echo =========================================================
    echo ^(in case of false input ^: close this main window to cancel^)
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    call:getUserInput "Are you sure you want to uninstall Batch FW ? (y, n)" "y,n" ANSWER
    echo ---------------------------------------------------------
    if [!ANSWER!] == ["n"] goto:eof

    call:getUserInput "Do you want to delete all (including games) ? (y, n)" "y,n" ANSWER
    echo ---------------------------------------------------------
    if [!ANSWER!] == ["y"] (
        call:getUserInput "Are you sure ? (y, n)" "y,n" ANSWER
        if [!ANSWER!] == ["y"] (
            wscript /nologo !StartHiddenCmd! "%windir%\system32\cmd.exe"  /C rmdir /Q /S !GAMES_FOLDER! > NUL 2>&1
            goto:eof
        )
    )
    set "BatchFW_Graphic_Packs="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if not exist !BatchFW_Graphic_Packs! goto:removeWiiuFolder
    call:getUserInput "Remove _BatchFW_Graphic_Packs folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeWiiuFolder
    rmdir /Q /S !BatchFW_Graphic_Packs!  > NUL 2>&1
    echo ^> _BatchFW_Graphic_Packs deleted ^!
    echo ---------------------------------------------------------
    :removeWiiuFolder
    set "BatchFW_WiiU="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    if not exist !BatchFW_WiiU! goto:removeReports
    call:getUserInput "Remove _BatchFw_WiiU folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeReports
    rmdir /Q /S !BatchFW_WiiU!  > NUL 2>&1
    echo ^> _BatchFw_WiiU deleted ^!
    echo ---------------------------------------------------------
    :removeReports
    set "BatchFW_Games_Compatibility_Reports="!GAMES_FOLDER:"=!\_BatchFw_Games_Compatibility_Reports""
    if not exist !BatchFW_Games_Compatibility_Reports! goto:removeMissing
    call:getUserInput "Remove _BatchFW_Games_Compatibility_Reports folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeMissing
    rmdir /Q /S !BatchFW_Games_Compatibility_Reports!  > NUL 2>&1
    echo ^> _BatchFW_Games_Compatibility_Reports deleted ^!
    echo ---------------------------------------------------------
    :removeMissing
    set "BatchFW_Missing_Games_Profiles="!GAMES_FOLDER:"=!\_BatchFw_Missing_Games_Profiles""
    if not exist !BatchFW_Missing_Games_Profiles! goto:removeController
    call:getUserInput "Remove _BatchFW_Missing_Games_Profiles folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeController
    rmdir /Q /S !BatchFW_Missing_Games_Profiles! > NUL 2>&1
    echo ^> _BatchFW_Missing_Games_Profiles deleted ^!
    echo ---------------------------------------------------------
    :removeController
    set "BatchFW_Controller_Profiles="!GAMES_FOLDER:"=!\_BatchFw_Controller_Profiles""
    if not exist !BatchFW_Controller_Profiles! goto:removeGpuCache
    call:getUserInput "Remove _BatchFW_Controller_Profiles folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:removeGpuCache
    rmdir /Q /S !BatchFW_Controller_Profiles! > NUL 2>&1
    echo ^> _BatchFW_Controller_Profiles deleted ^!

    echo ---------------------------------------------------------
    :removeGpuCache
    call:getUserInput "Remove your GPU caches ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:restoreMlc01

    REM : search your current GLCache
    REM : check last path saved in log file

    REM : search in logFile, getting only the last occurence

    set "OPENGL_CACHE="NOT_FOUND""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "OPENGL_CACHE" 2^>NUL') do set "OPENGL_CACHE=%%i"

    if [!OPENGL_CACHE!] == ["NOT_FOUND"] goto:restoreMlc01

    REM : openGL cache location
    set "GLCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuGLCache!\"

    if not exist !GLCacheSavesFolder! goto:cleanBfwVkCache
    rmdir /Q /S !GLCacheSavesFolder! > NUL 2>&1
    echo ^> OpenGL caches were removed ^!

    :cleanBfwVkCache
    set "VkCacheSavesFolder=!OPENGL_CACHE:GLCache=_BatchFW_CemuVkCache!"
    if not exist !VkCacheSavesFolder! goto:restoreMlc01
    rmdir /Q /S !VkCacheSavesFolder! > NUL 2>&1

    echo ^> Vulkan caches were removed ^!

    echo ---------------------------------------------------------
    :restoreMlc01
    set "mlc01Restored=0"
    call:getUserInput "Copy back mlc01 data of each games in a mlc01 folder? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["n"] goto:restoreTransShaderCache

    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a mlc01 folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"
    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askMlc01Folder
    )
    REM : check if folder name contains forbiden character for !MLC01_FOLDER_PATH!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !MLC01_FOLDER_PATH!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !MLC01_FOLDER_PATH! is not DOS compatible^!^, please choose another location
        pause
        goto:askMlc01Folder
    )

    REM : check if a usr/title exist
    set usrTitle="!MLC01_FOLDER_PATH:"=!\usr\title"
    if not exist !usrTitle! (
        echo !usrTitle! not found ^?
        goto:askMlc01Folder
    )

    set "script="!BFW_TOOLS_PATH:"=!\restoreMlc01DataForAllGames.bat""
    wscript /nologo !StartWait! !script! !MLC01_FOLDER_PATH!
    set "mlc01Restored=1"

    call:getUserInput "Do you want to define another mlc01 target folder ? (y, n)" "y,n" ANSWER
    if [!ANSWER!] == ["y"] goto:askMlc01Folder

    echo ^> mlc01 data restored
    echo ---------------------------------------------------------

    :restoreTransShaderCache
    set "TransShaderCacheRestored=0"
    call:getUserInput "Restore all transferable shader cache to a Cemu folder ? (y, n)" "y,n" ANSWER

    if [!ANSWER!] == ["n"] goto:restoreSaves

    :askCemuFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a Cemu's install folder"') do set "folder=%%b" && set "CEMU_FOLDER=!folder:?= !"
    if [!CEMU_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askCemuFolder
    )
    REM : check if folder name contains forbiden character for !CEMU_FOLDER!
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !CEMU_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !CEMU_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askCemuFolder
    )

    REM : check that cemu.exe exist in
    set "cemuExe="!CEMU_FOLDER:"=!\cemu.exe" "
    if not exist !cemuExe! (
        echo ERROR^, No Cemu^.exe file found under !CEMU_FOLDER! ^^!
        goto:askCemuFolder
    )

    set "script="!BFW_TOOLS_PATH:"=!\restoreTransShadersForAllGames.bat""
  
    wscript /nologo !StartWait! !script! !CEMU_FOLDER!
    set "TransShaderCacheRestored=1"
    echo ^> transferable shader caches restored
    echo ---------------------------------------------------------

    :restoreSaves
    set "restoreUserSavesOfAllGames=0"
    call:getUserInput "Restore all saves for all users to a mlc01 folder ? (y, n)" "y,n" ANSWER

    if [!ANSWER!] == ["n"] goto:removeExtraFolders


    set "script="!BFW_TOOLS_PATH:"=!\restoreUserSavesOfAllGames.bat""
    wscript /nologo !StartWait! !script! !MLC01_FOLDER_PATH!

    set "restoreUserSavesOfAllGames=1"
    echo ^> all saves of all users for all games were restored
    echo ---------------------------------------------------------

    :removeExtraFolders

    for /F "delims=~" %%x in ('dir /b /a:d /s mlc01 2^>NUL') do (
        echo At least one mlc01 subfolder still exist in your games library^.
        echo If you restored previously each mlc01^'s data, you can choose to delete them all^.
        echo Otherwise^, keep them^. It contain update^,DLC and your last game^'s saves ^^!
        echo ---------------------------------------------------------
        call:getUserInput "Delete all mlc01 game's subfolders ? (y, n)" "y,n" ANSWER
        echo ---------------------------------------------------------
        if [!ANSWER!] == ["n"] goto:removeShaderCache
        REM : get out of the loop
        goto:removeMlc01
    )
    :removeMlc01
    for /F "delims=~" %%x in ('dir /b /a:d /s mlc01 2^>NUL') do (
        rmdir /Q /S "%%x" > NUL 2>&1
    )

    :removeShaderCache
    for /F "delims=~" %%x in ('dir /b /a:d /s shaderCache 2^>NUL') do (
        echo At least one shaderCache subfolder still exist in your games library^.
        echo If you restored previously each shaderCache, you can choose to delete them all^.
        echo Otherwise^, keep them^. It contain your last game^'s transferable cache ^^!
        echo ---------------------------------------------------------
        call:getUserInput "Delete all shaderCache games subfolders ? (y, n)" "y,n" ANSWER
        echo ---------------------------------------------------------
        if [!ANSWER!] == ["n"] goto:removeFoldersLeft
        REM : get out of the loop
        goto:removeTransCache
    )
    :removeTransCache
    for /F "delims=~" %%x in ('dir /b /a:d /s shaderCache 2^>NUL') do (
        rmdir /Q /S "%%x" > NUL 2>&1
    )
    :removeFoldersLeft
    echo Do you want to remove all Cemu extra subfolders created^?
    echo That^'s included ^:
    echo - all CEMU saved settings
    echo - your own graphic packs if created ones in Cemu game^'s subfolder
    echo That^'s excluded ^:
    echo - mods ^(founded ones will be moved in the game^'s folder before deleting Cemu subfolder^)
    echo ---------------------------------------------------------

    call:getUserInput "Remove all Cemu extra subfolders created ? (y, n)" "y,n" ANSWER
    echo ---------------------------------------------------------
    if [!ANSWER!] == ["n"] goto:removeShortcuts

    pushd !GAMES_FOLDER!
    for /F "delims=~" %%x in ('dir /b /a:d /s mods 2^>NUL ^| find "Cemu"') do (
        echo At least one mods subfolder still exist in your games library^.
        echo Moving all mods folders in game^'s folders ^.^.^.

        REM : move it under game folder
        for %%a in ("%%i") do set "parentFolder="%%~dpa""
        set "cemuFolder=!parentFolder:~0,-2!""
        for %%a in (!cemuFolder!) do set "parentFolder="%%~dpa""
        set "GAME_FOLDER=!parentFolder:~0,-2!""

        set /A "attempt=1"
        :tryToMove
        move /Y "%%i" !GAME_FOLDER! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (

            if !attempt! EQU 1 (
                cscript /nologo !MessageBox! "Monving %%i failed^, close any program that could use this location" 4112
                set /A "attempt+=1"
                goto:tryToMove
            )

            REM : basename of GAME FOLDER PATH to get GAME_TITLE
            for /F "delims=~" %%i in ("%%i") do set "name=%%~nxi"
            call:fillOwnerShipPatch "%%i" "!name!" patch

            cscript /nologo !MessageBox! "Check still failed^, take the ownership on %%i with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
            if !ERRORLEVEL! EQU 6 goto:tryToMove
        )
    )

    for /F "delims=~" %%x in ('dir /b /a:d /s code 2^>NUL') do (

        set "cf="%%x""
        for %%a in (!cf!) do set "parentFolder="%%~dpa""
        set "gf=!parentFolder:~0,-2!""
        set "cemuFolder="!gf:"=!\Cemu""
        rmdir /Q /S !cemuFolder! > NUL 2>&1
    )
    echo ^> Batch FW^'s extra files and folders were removed
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    :removeShortcuts
    pushd !GAMES_FOLDER!

    REM : remove shortcut folder
    REM : if not called from this folder
    if [!WIIU_GAMES_FOLDER!] == ["NONE"] (
    REM : get the last location from logFile
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
    )
    if not [!WIIU_GAMES_FOLDER!] == ["NONE"] (

        rmdir /Q /S !WIIU_GAMES_FOLDER! > NUL 2>&1
        echo ^> !WIIU_GAMES_FOLDER! deleted ^!
        echo ---------------------------------------------------------
    )

    echo ^> Done^.
    echo =========================================================
    echo This windows will close automatically in 15s
    timeout /T 4 > NUL 2>&1

    REM remove this folder
    rmdir /Q /S !BFW_PATH! > NUL 2>&1

    if %nbArgs% EQU 0 endlocal
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :fillOwnerShipPatch
        set "folder=%1"
        set "title=%2"

        set "patch="%USERPROFILE:"=%\Desktop\BFW_GetOwnerShip_!title:"=!.bat""
        set "WIIU_GAMES_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create shortcuts" 2^>NUL') do set "WIIU_GAMES_FOLDER="%%i""
        if not [!WIIU_GAMES_FOLDER!] == ["NONE"] (

            set "patchFolder="!WIIU_GAMES_FOLDER:"=!\OwnerShip Patchs""
            if not exist !patchFolder! mkdir !patchFolder! > NUL 2>&1
            set "patch="!patchFolder:"=!\!title:"=!.bat""
        )
        set "%3=!patch!"

        echo echo off > !patch!
        echo REM ^: RUN THIS SCRIPT AS ADMINISTRATOR >> !patch!

        type !patch! | find /I !folder! > NUL 2>&1 && goto:eof

        echo echo ------------------------------------------------------->> !patch!
        echo echo Get the ownership of !folder! >> !patch!
        echo echo ------------------------------------------------------->> !patch!
        echo takeown /F !folder! /R /SKIPSL >> !patch!
        echo icacls !folder! /grant %%username%%^:F /T /L >> !patch!
        echo pause >> !patch!
        echo del /F %%0 >> !patch!
    goto:eof

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
