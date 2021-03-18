@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    REM : set current char codeset
    call:setCharSet

    REM : create folders
    set "BFW_WIIU_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_WiiU""
    set "BFW_ONLINE_FOLDER="!BFW_WIIU_FOLDER:"=!\OnlineFiles""

    set "WIIU_ACCOUNTS_FOLDER="!BFW_ONLINE_FOLDER:"=!\wiiuAccounts\usr\save\system\act""
    if not exist !WIIU_ACCOUNTS_FOLDER! (
        echo ERROR^: !WIIU_ACCOUNTS_FOLDER! does not exist ^!^
        echo Use Wii-U Games^\Wii-U^\Get online files^.lnk
        echo or Wii-U Games^\Wii-U^\Scan my Wii-U^.lnk
        echo before this script
        pause
        exit 99
    )
    cls

    echo =========================================================
    echo Associate BatchFw^'s users to Wii-U accounts
    echo =========================================================

    REM : display BatchFw users list
    set "USERSARRAY="
    set /A "nbUsers=0"
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
        set "USERSARRAY[!nbUsers!]=%%i"
        set /A "nbUsers+=1"
    )
    if !nbUsers! EQU 0 (
        echo No users were found^!^. Please restore BatchFw factory settings
        pause
        exit 50
    )
    set /A "nbUsers-=1"

    echo =========================================================

    set "usersFolderAccount="!BFW_ONLINE_FOLDER:"=!\usersAccounts""
    if  exist !usersFolderAccount! rmdir /Q /S !usersFolderAccount!
    mkdir !usersFolderAccount! > NUL 2>&1


    REM : loop on all 800000XX folders found
    pushd !WIIU_ACCOUNTS_FOLDER!
    for /F "delims=~" %%d in ('dir /B /A:D 80* 2^>NUL') do (

        set "af="!WIIU_ACCOUNTS_FOLDER:"=!\%%d\account.dat""

        for /F "delims=~= tokens=2" %%n in ('type !af! ^| find /I "IsPasswordCacheEnabled=0"') do (
            echo WARNING^: this account seems to not have "Save password" option checked ^(auto login^) ^!
            echo it might be unusable with CEMU
            echo.
            echo Check "Save password" option for %%d account on the Wii-U and relaunch this script
            echo.
        )

        REM : get AccountId from account.dat
        set "accId=NONE"
        for /F "delims=~= tokens=2" %%n in ('type !af! ^| find /I "AccountId="') do set "accId=%%n"
        if ["%accId%"] == ["NONE"] (
            echo ERROR^: fail to parse !af!
            pause
        )
        REM : Ask for Batch's user
        echo Which batchFw^'s user use the accountId
        echo ^> !accId!
        echo on the Wii-U ^(folder^'s name is %%d^) ^?
        echo.

        set "user=NONE"
        call:getUser user

        REM : copy the file
        set "uf="!usersFolderAccount:"=!\!user!%%d.dat""

        copy /Y !af! !uf! > NUL 2>&1
        echo saving \%%d\account.dat to !uf!
        echo ---------------------------------------------------------
    )
    echo =========================================================
    echo if you had mistaken^, relaunch this script to change the
    echo association
    echo.
    echo if an account was not listed^, you might have to relaunch
    echo Wii-U Games\Wii-U\Get online files^.lnk
    echo to synchronize folders with your Wii-U first

    pause

    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    :getUser

        for /L %%i in (0,1,!nbUsers!) do echo %%i ^: !USERSARRAY[%%i]!
        echo.
        :askUser
        set /P "num=Enter the BatchFw user's number [0, !nbUsers!] : "

        echo %num% | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askUser

        if %num% LSS 0 goto:askUser
        if %num% GTR %nbUsers% goto:askUser

        set "%1=!USERSARRAY[%num%]!"
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_OperatingSystem get Locale /value 2^>NUL ^| find "="') do set "L0CALE_CODE=%%f"

    goto:eof
    REM : ------------------------------------------------------------------
