@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main


    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        pause
        exit /b 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "getShaderCacheFolder="!BFW_RESOURCES_PATH:"=!\getShaderCacheName""
    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    if %nbArgs% NEQ 0 goto:getArgsValue

    title Copy mlc01 data to each games

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"
    echo Please select mlc01 source folder
    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a mlc01 folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"

    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
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

    REM : check if a usr/save exist
    set usrFolder="!MLC01_FOLDER_PATH:"=!\usr"
    if not exist !usrFolder! (
        echo !usrFolder! not found ^?
        goto:askMlc01Folder
    )
    cls
    goto:inputsAvailables

    :getArgsValue
    if %nbArgs% NEQ 1 (
        echo ERROR on arguments passed^!
        echo SYNTAX^: "!THIS_SCRIPT!" MLC01_FOLDER_PATH
        echo given {%*}
        pause
        exit /b 99
    )
    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[0]!"
    if not exist !MLC01_FOLDER_PATH! (
        echo ERROR^: mlc01 folder !MLC01_FOLDER_PATH! does not exist^!
        pause
        exit /b 1
    )

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables

    REM : basename of MLC01_FOLDER_PATH
    for /F "delims=~" %%i in (!MLC01_FOLDER_PATH!) do set "basename=%%~nxi"
    set CEMU_FOLDER=!MLC01_FOLDER_PATH:\%basename%=!
    set /A "cemuFolderDetected=0"
    set "ctscf="!CEMU_FOLDER:"=!\shaderCache\transferable""
    if exist !ctscf! set /A "cemuFolderDetected=1"

    for %%a in (!CEMU_FOLDER!) do set CEMU_FOLDER_NAME="%%~nxa"

    echo =========================================================
    if !cemuFolderDetected! EQU 0 (
        echo Copy Game data from mlc01 folder to each game^'s folder
    ) else (
        echo Copy Game data from cemu folder to each game^'s folder
    )
    echo  - loadiine Wii-U Games under^: !GAMES_FOLDER!
    echo  - source mlc01 folder^: !MLC01_FOLDER_PATH!
    echo.

    REM : compute size needed only if source and target partitions are differents
    for %%a in (!MLC01_FOLDER_PATH!) do set "driveMlc=%%~da"
    if ["!driveMlc!"] == ["!drive!"] goto:beginScan

    echo Computing the size needed^.^.^.
    echo.
    REM : compute the size needed
    call:getFolderSizeInMb !MLC01_FOLDER_PATH! sizeNeeded

    choice /C yn /N /M "A maximum of !sizeNeeded! Mb are needed on the target partition, continue (y, n)? : "
    if !ERRORLEVEL! EQU 2 (
        REM : Cancelling
        echo Cancelled by user^, exiting in 2s
        exit /b 49
    )
    :beginScan
    echo =========================================================
    if !QUIET_MODE! EQU 1 goto:scanGamesFolder
    echo Launching in 30s
    echo     ^(y^)^: launch now
    echo     ^(n^)^: cancel
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice ? : " "y,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Cancelling
        choice /C y /T 2 /D y /N /M "Cancelled by user, exiting in 2s"
        goto:eof
    )

    :scanGamesFolder
    cls

    REM : check if exist game's folder(s) containing non supported characters
    REM : is done in importSaves.bat

    REM : call to importSaves.bat (it asks which user is concerned by the Mlc01 folder and create his compressed save)
    set "importSave="!BFW_TOOLS_PATH:"=!\importSaves.bat""
    wscript /nologo !StartWait! !importSave! !MLC01_FOLDER_PATH!

    REM : check if exist game's folder(s) containing non supported characters
    set "tmpFile="!BFW_PATH:"=!\logs\detectInvalidGamesFolder_cmdfag.log""
    dir /B /A:D > !tmpFile! 2>&1
    for /F %%i in ('type !tmpFile! ^| find "?"') do (
        cls
        echo =========================================================
        echo ERROR ^: Unknown characters found in game^'s folder^(s^) that is not handled by your current DOS charset ^(%CHARSET%^)
        echo List of game^'s folder^(s^) ^:
        echo ---------------------------------------------------------
        type !tmpFile! | find "?"
        del /F !tmpFile!
        echo ---------------------------------------------------------
        echo Fix-it by removing characters here replaced in the folder^'s name
        echo Exiting until you rename or move those folders
        echo =========================================================
        pause
        goto:eof
    )
    set /A NB_GAMES_TREATED=0

    REM : loop on game's code folders found
    for /F "delims=~" %%g in ('dir /b /o:n /a:d /s code 2^>NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        set "codeFullPath="%%g""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"

        REM : check path
        call:checkPathForDos !GAME_FOLDER_PATH! > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"

        if !cr! EQU 0 (
            REM : check if folder name contains forbiden character for batch file
            set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
            call !tobeLaunch! !GAME_FOLDER_PATH!
            set /A "cr=!ERRORLEVEL!"

            if !cr! GTR 1 echo Please rename !GAME_FOLDER_PATH! to be DOS compatible^, otherwise it will be ignored by BatchFW ^^!
            if !cr! EQU 1 goto:scanGamesFolder
            call:cpGameData

        ) else (

            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            for %%a in (!GAME_FOLDER_PATH!) do set "folderName=%%~nxa"
            echo !folderName!^: Unsupported characters found^, rename-it otherwise it will be ignored by BatchFW ^^!
            for %%a in (!GAME_FOLDER_PATH!) do set "basename=%%~dpa"

            REM : windows forbids creating folder or file with a name that contains \/:*?"<>| but &!% are also a problem with dos expansion
            set "str="!folderName!""
            set "str=!str:&=!"
            set "str=!str:\!=!"
            set "str=!str:%%=!"
            set "str=!str:?=!"
            set "str=!str:\"=!"
            set "str=!str:^=!"
            set "newFolderName=!str:"=!"
            set "newName="!basename!!newFolderName:"=!""

            set /A "attempt=1"
            :tryToMove
            call:getUserInput "Renaming folder for you? (y, n) : " "y,n" ANSWER

            if [!ANSWER!] == ["y"] (
                move /Y !GAME_FOLDER_PATH! !newName! > NUL 2>&1
                if !ERRORLEVEL! NEQ 0 (

                    if !attempt! EQU 1 (
                        !MessageBox! "Check failed on !GAME_FOLDER_PATH:"=!^, close any program that could use this location" 4112
                        set /A "attempt+=1"
                        goto:tryToMove
                    )
                    REM : basename of GAME FOLDER PATH to get GAME_TITLE
                    for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxg"
                    call:fillOwnerShipPatch !GAME_FOLDER_PATH! "!GAME_TITLE!" patch

                    !MessageBox! "Check still failed^, take the ownership on !GAME_FOLDER_PATH:"=! with running as an administrator the script !patch:"=!^. If it^'s done^, do you wish to retry^?" 4116
                    if !ERRORLEVEL! EQU 6 goto:tryToMove
                )
            )
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! EQU 0 timeout /t 2 > NUL 2>&1 && goto:scanGamesFolder
            if [!ANSWER!] == ["y"] if !ERRORLEVEL! NEQ 0 echo Failed to rename game^'s folder ^(contain ^'^^!^'^?^), please do it by yourself otherwise game will be ignored^!
            echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        )
    )

    echo =========================================================
    echo Treated !NB_GAMES_TREATED! games
    echo #########################################################
    if !QUIET_MODE! EQU 1 goto:exiting
    echo ---------------------------------------------------------
    echo Delete and recreate shortcuts for the treated games
    echo ^(otherwise you^'ll get an error when launching the game ask you to do this^)
    echo ---------------------------------------------------------
    echo This windows will close automatically in 12s
    echo     ^(n^) ^: don^'t close^, i want to read history log first
    echo     ^(q^) ^: close it now and quit
    echo ---------------------------------------------------------
    call:getUserInput "Enter your choice? : " "q,n" ANSWER 30
    if [!ANSWER!] == ["n"] (
        REM : Waiting before exiting
        pause
    )
    :exiting
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

    :getShaderCacheName

        pushd !getShaderCacheFolder!
        set "rpx_path=!codeFolder!\!RPX_FILE:"=!"

        for /F %%l in ('getShaderCacheName.exe !rpx_path!') do set "sci=%%l"

        pushd !GAMES_FOLDER!
    goto:eof
    REM : ------------------------------------------------------------------

    REM : lower case
    :lowerCase

        set "str=%~1"

        REM : format strings
        set "str=!str: =!"

        set "str=!str:A=a!"
        set "str=!str:B=b!"
        set "str=!str:C=c!"
        set "str=!str:D=d!"
        set "str=!str:E=e!"
        set "str=!str:F=f!"
        set "str=!str:G=g!"
        set "str=!str:H=h!"
        set "str=!str:I=i!"
        set "str=!str:J=j!"
        set "str=!str:K=k!"
        set "str=!str:L=l!"
        set "str=!str:M=m!"
        set "str=!str:N=n!"
        set "str=!str:O=o!"
        set "str=!str:P=p!"
        set "str=!str:Q=q!"
        set "str=!str:R=r!"
        set "str=!str:S=s!"
        set "str=!str:T=t!"
        set "str=!str:U=u!"
        set "str=!str:W=w!"
        set "str=!str:X=x!"
        set "str=!str:Y=y!"
        set "str=!str:Z=z!"

        set "%2=!str!"

    goto:eof
    REM : ------------------------------------------------------------------

    :cpGameData

        REM : avoiding a mlc01 folder under !GAME_FOLDER_PATH!
        if /I [!GAME_FOLDER_PATH!] == ["!GAMES_FOLDER:"=!\mlc01"] goto:eof

        set "codeFolder="!GAME_FOLDER_PATH:"=!\code""
        REM : cd to codeFolder
        pushd !codeFolder!
        set "RPX_FILE="project.rpx""
	    REM : get bigger rpx file present under game folder
        if not exist !RPX_FILE! set "RPX_FILE="NONE"" & for /F "delims=~" %%i in ('dir /B /O:S *.rpx 2^>NUL') do (
            set "RPX_FILE="%%i""
        )
        REM : cd to GAMES_FOLDER
        pushd !GAMES_FOLDER!

        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : basename of GAME FOLDER PATH (to get GAME_TITLE)
        for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

        set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
        if not exist !META_FILE! (
            echo No meta folder found under game folder^, aborting^!
            goto:metaFix
        )

        REM : get Title Id from meta.xml
        :getTitleLine
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] (
            echo No titleId found in the meta^.xml file^?
            :metafix
            echo No game profile was found because no meta^/meta^.xml file exist under game^'s folder^!
            set "metaFolder="!GAME_FOLDER_PATH:"=!\meta""
            if not exist !metaFolder! mkdir !metaFolder! > NUL 2>&1
            echo "Please pick your game titleId ^(copy to clipboard^) in WiiU-Titles-Library^.csv"
            echo "Then close notepad to continue"

            wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !wiiTitlesDataBase!
            REM : create the meta.xml file
            echo ^<^?xml^ version=^"1.0^"^ encoding=^"utf-8^"^?^> > !META_FILE!
            echo ^<menu^ type=^"complex^"^ access=^"777^"^> >> !META_FILE!
            echo ^ ^ ^<title_version^ type=^"unsignedInt^"^ length=^"4^"^>0^<^/title_version^> >> !META_FILE!
            echo ^ ^ ^<title_id^ type=^"hexBinary^"^ length=^"8^"^>################^<^/title_id^> >> !META_FILE!
            echo ^<^/menu^> >> !META_FILE!
            echo "Paste-it in meta^/meta^.xml file ^(replacing ################ by the title id of the game ^(16 characters^)^)"
            echo "Then close notepad to continue"
            wscript /nologo !StartWait! "%windir%\System32\notepad.exe" !META_FILE!
            goto:getTitleLine
        )
        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

        if !titleId! == "################" goto:metafix

        set "endTitleId=%titleId:~8,8%"

        REM : get game's title from wii-u database file
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| findStr /R /I "^'!titleId!';"') do set "libFileLine="%%i""

        REM : strip line to get data
        for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
           set "titleIdRead=%%a"
           set "Desc=%%b"
           set "productCode=%%c"
           set "companyCode=%%d"
           set "notes=%%e"
           set "versions=%%f"
           set "region=%%g"
           set "acdn=%%h"
           set "icoId=%%i"
           set "nativeHeight=%%j"
           set "nativeFps=%%k"
        )

        set "gfxPackGameTitle=%Desc: =%"

        REM : import cache if CEMU's folder
        if !cemuFolderDetected! EQU 0 goto:treatMlc01Data

        REM : compute shaderCache id to seek for the transferable cache
        set "sci=NOT_FOUND"
        call:getShaderCacheName
        if ["!sci!"] == ["NOT_FOUND"] (
            echo WARNING ^: !GAME_TITLE! shader cache name computation failed ^!
            goto:handleNewTC
        )
        REM : import transferable cache (check size)
        set "gtscf="!GAME_FOLDER_PATH:"=!\Cemu\shaderCache\transferable""
        if not exist !gtscf! mkdir !gtscf! > NUL 2>&1

        set "srcScf="!ctscf:"=!\!sci!.bin""
        set "tgtScf="!gtscf:"=!\!sci!.bin""

        if not exist !srcScf! goto:handleNewTC
        if not exist !tgtScf! robocopy !ctscf! !gtscf! !sci!.bin /MT:32 /IS /IT > NUL 2>&1 & goto:handleNewTC

        set /A "srcSize=0"
        for /F "tokens=*" %%s in (!srcScf!)  do set "srcSize=%%~zs"
        set /A "tgtSize=0"
        for /F "tokens=*" %%s in (!tgtScf!)  do set "tgtSize=%%~zs"

        REM : compare their size : copy only if greater
        if !srcSize! GTR !tgtSize! robocopy !ctscf! !gtscf! !sci!.bin /MT:32 /IS /IT > NUL 2>&1

        :handleNewTC
        REM : for version > 1.16 sci=titleId

        set "endIdUp=!titleId!
        call:lowerCase !endIdUp! sci

        set "srcScf="!ctscf:"=!\!sci!.bin""
        if not exist !srcScf! goto:treatMlc01Data

        set "tgtScf="!gtscf:"=!\!sci!.bin""
        if not exist !tgtScf! robocopy !ctscf! !gtscf! !sci!.bin /MT:32 /IS /IT > NUL 2>&1 & goto:treatMlc01Data

        set /A "srcSize=0"
        for /F "tokens=*" %%s in (!srcScf!)  do set "srcSize=%%~zs"
        set /A "tgtSize=0"
        for /F "tokens=*" %%s in (!tgtScf!)  do set "tgtSize=%%~zs"

        REM : compare their size : copy only if greater
        if !srcSize! GTR !tgtSize! robocopy !ctscf! !gtscf! !sci!.bin /MT:32 /IS /IT > NUL 2>&1
        
        :treatMlc01Data

        echo =========================================================
        echo - !GAME_TITLE! ^(%nativeHeight%p @ %nativeFps%FPS^)
        echo ---------------------------------------------------------

        echo If you play !GAME_TITLE! with !CEMU_FOLDER_NAME:"=!^:
        echo.
        echo Copy game^'s data from !MLC01_FOLDER_PATH!^?
        echo   ^(n^)^: no^, skip
        echo   ^(y^)^: yes ^(default value after 15s timeout^)
        echo.

        call:getUserInput "Enter your choice ? : " "y,n" ANSWER 15
        if [!ANSWER!] == ["n"] (
            REM : skip this game
            echo Skip this GAME
            goto:eof
        )

        if !QUIET_MODE! EQU 0 (
            REM : mlc01 subfolder already present
            set "mlc01Folder="!GAME_FOLDER_PATH:"=!\mlc01""
            if exist !mlc01Folder! (
                choice /C yn /N /M "A mlc01 folder already exists in !GAME_FOLDER_PATH:"=!^, continue ^(y^, n^)^? ^: "
                if !ERRORLEVEL! EQU 2 goto:eof
            )
        )
        echo ---------------------------------------------------------

        set "pat="!MLC01_FOLDER_PATH:"=!\usr\title""
        for /F "delims=~" %%i in ('dir /b /o:n /a:d !pat! 2^>NUL') do (
            call:copyTitle "%%i"
        )

        set "sysSrc="!MLC01_FOLDER_PATH:"=!\sys""
        set "sysTarget="!GAME_FOLDER_PATH:"=!\mlc01\sys""

        set "sysTmpl="!GAME_FOLDER_PATH:"=!\mlc01\sys\title\0005001b\10056000\content""

        if not exist !sysTarget! mkdir !sysTmpl! > NUL 2>&1
        robocopy  !sysSrc! !sysTarget! /MT:32 /S > NUL 2>&1

        set /A NB_GAMES_TREATED+=1

        REM : log to games library log file
        set "msg="!gfxPackGameTitle!:!DATE!-!USERDOMAIN! copy mlc01 data from=!MLC01_FOLDER_PATH:"=!""
        call:log2GamesLibraryFile !msg!

    goto:eof
    REM : ------------------------------------------------------------------

    :getSmb
        set "sr=%~1"
        set /A "d=%~2"

        set /A "%3=!sr:~0,%d%!+1"
    goto:eof
    REM : ------------------------------------------------------------------

    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof
    REM : ------------------------------------------------------------------

    :getFolderSizeInMb

        set "folder="%~1""
        REM : prevent path to be stripped if contain '
        set "folder=!folder:'=`'!"
        set "folder=!folder:[=`[!"
        set "folder=!folder:]=`]!"
        set "folder=!folder:)=`)!"
        set "folder=!folder:(=`(!"

        set "psCommand=-noprofile -command "ls -r -force '!folder:"=!' | measure -s Length""

        set "line=NONE"
        for /F "usebackq tokens=2 delims=:" %%a in (`powershell !psCommand! ^| find /I "Sum"`) do set "line=%%a"
        REM : powershell call always return %ERRORLEVEL%=0

        if ["!line!"] == ["NONE"] (
            set "%2=0"
            goto:eof
        )

        set "sizeRead=%line: =%"

        if ["!sizeRead!"] == [" ="] (
            set "%2=0"
            goto:eof
        )

        set /A "im=0"
        if not ["!sizeRead!"] == ["0"] (

            REM : compute length before switching to 32bits integers
            call:strLength !sizeRead! len
            REM : forcing Mb unit
            if !len! GTR 6 (
                set /A "dif=!len!-6"
                call:getSmb %sizeRead% !dif! smb
                set "%2=!smb!"
                goto:eof
            ) else (
                set "%2=1"
                goto:eof
            )
        )
        set "%2=0.0"

    goto:eof
    REM : ------------------------------------------------------------------
    :copyTitle

        set "tf="!MLC01_FOLDER_PATH:"=!\usr\title\%~1\%endTitleId%""
        if not exist !tf! goto:eof

        REM : check if a meta folder exist
        set "metaFolder="!tf:"=!\meta"
        if not exist !metaFolder! goto:eof

        set "target="!GAME_FOLDER_PATH:"=!\mlc01\usr\title\%~1\%endTitleId%""
        set "metaFolder="!target:"=!\meta""
        if exist !metaFolder! goto:eof

        robocopy !tf! !target! /MT:32 /S > NUL 2>&1
        set /A "cr=!ERRORLEVEL!"
        if !cr! GTR 7 (
            echo ERROR when robocopy !sf! !target!^, cr=!ERRORLEVEL!
            pause
        )
        if !cr! GTR 0 echo - Copying !tf!

    goto:eof
    REM : ------------------------------------------------------------------

    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
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
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
        if not exist !glogFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !glogFile! ^| find /I "!msg!" 2^>NUL') do goto:eof
        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.bfw_tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL 2>&1
        move /Y !gLogFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg! >> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
