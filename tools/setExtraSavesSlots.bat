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

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""

    REM : set current char codeset
    call:setCharSet

    REM : search if launchGame.bat is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "launchGame.bat" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: launchGame^.bat is already^/still running^! If needed^, use ^'Wii-U Games^\BatchFw^\Kill BatchFw Processes^.lnk^'^. Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "launchGame.bat" | find /I /V "find"
        pause
        exit 100
    )

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : get the list of your installed games
    set /A nbUsers=0
    set /A nbGames=0
    set arrayGames=""
    set arraySlots=""
    set arrayLabels=""
    set arrayUsers=""

    REM : activate QUIETMODE by default
    set /A "QUIET_MODE=1"

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    if %nbArgs% GTR 3 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" USER^* GAME_FOLDER_PATH^* SLOT_LABEL^*
        echo ^(^* for optionnal^ argument^)
        echo given {%*}
        timeout /t 8 > NUL 2>&1
        exit /b 99
    )

    REM : 0 args => display games status for all users QUIETMODE=1 [not interactive]
    if %nbArgs% EQU 0 (
        title Set extra saves slots

        set /A "nbUsers=0"
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "USER_REGISTERED" 2^>NUL') do (
            set "arrayUsers[!nbUsers!]=%%i"
            set /A "nbUsers+=1"
        )

        if !nbUsers! EQU 0 (
            echo You have to launch the setup before this script ^^! launching setup^.bat
            set "setup="!BFW_PATH:"=!\setup.bat""
            wscript /nologo !Start! !setup!
            timeout /t 4 > NUL 2>&1
            exit 51
        )
    ) else (

        set "currentUser=!args[0]!"
        set "currentUser=!currentUser:"=!"

        set "arrayUsers[0]=!currentUser!"
        set /A "nbUsers=1"

        REM : 1 arg => set/modify extra slots for !currentUser! for all games QUIETMODE=0 [interactive]
        if %nbArgs% EQU 1 set /A "QUIET_MODE=0"

        REM : 2 args => display the game status for !currentUser! QUIETMODE=1 [interactive]
        if %nbArgs% GEQ 2 (

            set "GAME_FOLDER_PATH=!args[1]!"

            if not exist !GAME_FOLDER_PATH! (
                echo ERROR ^: !GAME_FOLDER_PATH! does not exist
                timeout /t 8 > NUL 2>&1
                exit /b 1
            )
            set /A "nbGamesSelected=1"

            REM : fill arrays of selection
            set "selectedGames[0]=!GAME_FOLDER_PATH!"

            for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxg"

            REM : default values
            set /A "slotNumber=0"
            set "slotLabel=No slots defined yet"
            set "activeLabel="NONE""

            REM : ingame saves folder
            set "igsvf="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""
            if exist !igsvf! (
                pushd !igsvf!
                call:treatUser
                pushd !GAMES_FOLDER!
            ) else (
                echo !GAME_TITLE! ^: sorry^, no saves found for !GAME_TITLE!
                goto:EndScript
            )

            set /A "selectedSlots[0]=!slotNumber!"

            REM : 3 args => create a new slot for the game (!currentUser!) from the last used one using a given label and activate it [not interactive]
            if %nbArgs% EQU 3 set "slotLabel=!args[2]!"

            set "selectedLabels[0]=!slotLabel!"
            goto:argsAvailable
        )        
    )

    :getList
    set /A "nbGames=0"
    REM : Loop on the game selected
    if %nbArgs% NEQ 0 (
        cls
        echo =========================================================
        echo ID_NUMBER ^: GAME_TITLE =^> USER ^: activeSlot [activeSlotLabel]
        echo =========================================================
        echo.
    )

    pushd !GAMES_FOLDER!
    REM : searching for code folder to find in only one rpx file (the bigger one)
    for /F "delims=~" %%i in ('dir /B /S /A:D code 2^> NUL ^| find /I /V "\mlc01" ^| find /I /V "\_BatchFw_Install"') do (

        set "codeFullPath="%%i""
        set "GAME_FOLDER_PATH=!codeFullPath:\code=!"
        REM : get Title
        for /F "delims=~" %%g in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxg"

        call:getExtraSlotState
    )
    echo ---------------------------------------------------------

    if %nbArgs% EQU 0 goto:EndScript
    if !QUIET_MODE! EQU 0 (
        echo.
        echo You can set^/modify^/delete extra save slots^.
        echo Define the list of games you wish to modify^.
        echo.
        echo.
    )

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

    set /P "listGamesSelected=Please enter game's ID numbers list (separated with a space): "
    echo.
    if not ["!listGamesSelected: =!"] == [""] (
        echo !listGamesSelected! | findStr /R /V /C:"^[0-9 ]*$" > NUL 2>&1 && echo ERROR^: not a list of integers && pause && goto:getList

        echo =========================================================
        for %%l in (!listGamesSelected!) do (
            echo %%l | findStr /R /V "[0-9]" > NUL 2>&1 && echo ERROR^: %%l not in the list && pause && goto:getList
            set /A "number=%%l"
            if !number! GEQ !nbGames! echo ERROR^: !number! not in the list & pause & goto:getList

            set "selectedGames[!nbGamesSelected!]=!arrayGames[%%l]!"
            set "selectedSlots[!nbGamesSelected!]=!arraySlots[%%l]!"
            set "selectedLabels[!nbGamesSelected!]=!arrayLabels[%%l]!"

            for /F "delims=~" %%g in (!arrayGames[%%l]!) do set "GAME_TITLE=%%~nxg"
            echo !GAME_TITLE!

            set /A "nbGamesSelected+=1"
        )
    ) else (
        goto:getList
    )
    echo =========================================================
    echo.

    choice /C ync /N /M "Continue (y, n : define another list) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit 98
    if !ERRORLEVEL! EQU 2 cls & goto:getList


    if !nbGamesSelected! EQU 0 (
        echo No games selected ^?
        pause
        goto:getList
    )

    :argsAvailable

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    REM : Loop on the game selected
    set /a "nbgmo=nbGamesSelected-1"
    for /L %%i in (0,1,!nbgmo!) do (
        if %nbArgs% LEQ 1 cls
        if %nbArgs% EQU 1 echo =========================================================

        set "gamePath=!selectedGames[%%i]!"
        set /A "activeSlot=!selectedSlots[%%i]!"
        set "label=!selectedLabels[%%i]!"

        call:setExtraSlot %%i
    )

    if %nbArgs% LEQ 1 echo =========================================================

    :EndScript
    if %nbArgs% EQU 0 pause > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 exit !ERRORLEVEL!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    REM : get the number of the last remaining slot
    :getLastSlotNumber

        set /A "lastSlot=0"
        REM : Get the slot number of the remaining slot
        set "pat="!igsvf:"=!\!title!_!currentUser!_slot*.rar""

        for /F "delims=~" %%g in ('dir /S /B /O:-D /T:W !pat! 2^>NUL') do (

            set "slotFile="%%g""
            REM : get slotNumber
            set "str=!slotFile:"=!"
            set "str=!str:~-5!"
            set /A "lastSlot=!str:.rar=!"
        )
        set /A "%1=!lastSlot!"

    goto:eof
    REM : -----------------------------------------------------------------

    REM : override default's user save with a given slot
    :overrideUserSave

        REM : No slot defined, create it from current save
        set "userSave="!igsvf:"=!\!title!_!currentUser!.rar""

        if !nbSlots! EQU 1 (
            call:getLastSlotNumber srcSlot
        ) else (
            :askSlot
            set /P "answer=Please, enter the slot's number to overwrite default save : "
            echo !answer! | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askSlot

            set /A "srcSlot=!answer!"
            set "srcSlotFile="!igsvf:"=!\!title!_!currentUser!_slot!srcSlot!.rar""
            if exist !srcSlotFile! goto:slotFound
            echo ERROR^: slot!srcSlot! does not exist^!
            goto:askSlot
        )
        :slotFound
        set "srcSlotFileLabel="!igsvf:"=!\!title!_!currentUser!_slot!srcSlot!.txt""

        choice /C yn /N /M "Copying '!title!_!currentUser!_slot!srcSlot!' to '!title!_!currentUser!'? (y/n to cancel)"
        if !ERRORLEVEL! EQU 2 goto:eof

        copy /Y !srcSlotFile! !userSave!
        pause

    goto:eof
    REM : -----------------------------------------------------------------

    REM : deactivate all slots
    :deactivateAllSlots

        if exist !activeSlotFile! (
            attrib -R !activeSlotFile! > NUL 2>&1
            echo Deleting !title!_!currentUser!_activeSlot.txt^.^.^.
            del /F !activeSlotFile!
            set /A "activeSlot=0"
            pause
        )

    goto:eof
    REM : -----------------------------------------------------------------

    REM : delete all slots  (keep initial user save)
    :deleteAllSlots

        REM : Get the slot number of the remaining slot
        set "pat="!igsvf:"=!\!title!_!currentUser!_slot*.*""

        choice /C yn /N /M "You're about to delete all slots, confirm deletion? : (y/n to cancel)"
        if !ERRORLEVEL! EQU 2 goto:eof

        for /F "delims=~" %%g in ('dir /S /B /O:-D /T:W !pat! 2^>NUL') do del /F "%%g"
        call:deactivateAllSlots

    goto:eof
    REM : -----------------------------------------------------------------

    REM : activate a slot
    :activateSlot
        REM : optional arg
        set "slotToActivate=%~1"

        if not ["!slotToActivate!"] == [""] (
            set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!slotToActivate!.rar""
            if not exist !slotFile! (
                echo ERROR^: slot!slotToActivate! does not exist^!
                goto:eof
            )
        ) else (
            REM : ask wich one to activate
            if !nbSlots! GEQ 2 (
                :askSlotToActivate
                set /P "answer=Please, enter the slot's number to activate : "
                echo !answer! | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askSlotToActivate
                set /A "slotToActivate=!answer!"

                set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!slotToActivate!.rar""
                if exist !slotFile! goto:slotFound
                echo ERROR^: slot!slotToActivate! does not exist^!
                goto:askSlotToActivate

            ) else (
                call:getLastSlotNumber slotToActivate
                set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!slotToActivate!.rar""
            )
        )
        :slotFound
        REM : already active exit
        if !slotToActivate! EQU !activeSlot! (
            echo slot!slotToActivate! is already active
            REM : should never enter here with 3 args but...
            if %nbArgs% NEQ 3 pause
            goto:eof
        )

        set "slotFileLabel="!igsvf:"=!\!title!_!currentUser!_slot!slotToActivate!.txt""
        if not exist !slotFileLabel! (

            if %nbArgs% NEQ 3 (
                REM : add the label
                set /P "labelRead=Please, enter a label for this slot (use only ASCII characters) : "
                set "label=!labelRead! @!DATE!"
            )
            REM : else args=3 label remain inchanged
            echo !label!> !slotFileLabel!
        )

        echo| set /p="Activating slot!slotToActivate!:"
        type !slotFileLabel!
        if exist !activeSlotFile! attrib -R !activeSlotFile! > NUL 2>&1
        echo !title!_!currentUser!_slot!slotToActivate!^.rar> !activeSlotFile!
        attrib +R !activeSlotFile! > NUL 2>&1
        REM : update activeSlot
        set /A "activeSlot=!slotToActivate!"
        if ["!slotToActivate!"] == [""] (
            pause
        ) else (
            timeout /T 2 > NUL 2>&1
        )

    goto:eof
    REM : -----------------------------------------------------------------

    REM : delete an existing slot
    :deleteSlot
        echo.

        REM : default value
        set /A "slotToDelete=1"

        REM : before delete a slot, if at least 3 slots exists, ask wich one to activate
        if !nbSlots! GEQ 2 (
            :askSlot
            set /P "answer=Please, enter the slot's number to delete : "
            echo !answer! | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askSlot
            set /A "slotToDelete=!answer!"

            set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!slotToDelete!.rar""
            if exist !slotFile! goto:slotFound
            echo ERROR^: slot!slotToDelete! does not exist^!
            goto:askSlot

        ) else (
            REM : get the remaining slot number
            call:getLastSlotNumber slotToDelete
        )

        :slotFound
        type !activeSlotFile! | find "!currentUser!_slot!slotToDelete!" > NUl 2>&1 && (
            if !nbSlots! GTR 2 (
                echo This slot is the active one ^!
                call:activateSlot
            )
        )

        echo.
        choice /C yn /N /M "Delete !title!_!currentUser!_slot!slotToDelete!.rar ^? (y/n to cancel)"
        if !ERRORLEVEL! EQU 2 goto:eof

        set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!slotToDelete!.rar""
        set "slotFileLabel="!igsvf:"=!\!title!_!currentUser!_slot!slotToDelete!.txt""

        del /F !slotFile! > NUL 2>&1
        del /F !slotFileLabel! > NUL 2>&1
        set /A "nbSlots-=1"

        type !activeSlotFile! | find "!currentUser!_slot!slotToDelete!" > NUl 2>&1 && (
            if !nbSlots! EQU 1 (
                call:getLastSlotNumber slotToActivate
                call:activateSlot !slotToActivate!
            )
        )
        
        if !nbSlots! EQU 1 (
            REM : only one slot existed and now was deleted

            REM : remove activeSlotFile
            if exist !activeSlotFile! (
                attrib -R !activeSlotFile! > NUL 2>&1
                del /F !activeSlotFile! > NUL 2>&1
            )
        )
        pause

    goto:eof
    REM : ------------------------------------------------------------------

    :getNextSlotNumber

        set /A "incSlot=0"
        :incSlotToUse
        set /A "incSlot=incSlot+1"
        set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!incSlot!.rar""
        if exist !slotFile! goto:incSlotToUse

        set /A "%1=!incSlot!"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : create a new extra slot and activate it
    :createNewSlot

        REM : if exist slots, ask for the source slot to be copied
        set /A "srcSlot=0"

        echo.
        if !activeSlot! NEQ 0 (

            if !nbSlots! GTR 1 (
                :askSrcSlot
                set /P "answer=Please, enter the source slot number for creating the new one (0 for defaut user save) : "
                echo !answer! | findStr /R /V "[0-9]" > NUL 2>&1 && goto:askSrcSlot
                set /A "srcSlot=!answer!"
                if !srcSlot! EQU 0 goto:slotFound

                set "srcSlotFile="!igsvf:"=!\!title!_!currentUser!_slot!srcSlot!.rar""
                if exist !srcSlotFile! goto:slotFound
                echo ERROR^: slot!srcSlot! does not exist^!
                goto:askSrcSlot
            ) else (
                call:getLastSlotNumber srcSlot
            )
        ) else (
            call:getLastSlotNumber srcSlot
        )

        :slotFound
        if !srcSlot! NEQ 0 (

            call:getNextSlotNumber incSlot

            set "srcSlotFile="!igsvf:"=!\!title!_!currentUser!_slot!srcSlot!.rar""

            if %nbArgs% NEQ 3 (
                choice /C yn /N /M "Copying '!title!_!currentUser!_slot!srcSlot!' to '!title!_!currentUser!_slot!incSlot!'? (y/n to cancel)"
                if !ERRORLEVEL! EQU 2 goto:eof
            )
            copy /Y !srcSlotFile! !slotFile!

        ) else (
            REM : srcSlot=0
            call:getNextSlotNumber incSlot

            set "slotFile="!igsvf:"=!\!title!_!currentUser!_slot!incSlot!.rar""
            set "slotFileLabel="!igsvf:"=!\!title!_!currentUser!_slot!incSlot!.txt""

            REM : No slot defined, create it from current save
            set "userSave="!igsvf:"=!\!title!_!currentUser!.rar""

            if %nbArgs% NEQ 3 (
                choice /C yn /N /M "Copying '!title!_!currentUser!' to '!title!_!currentUser!_slot!incSlot!'? (y/n to cancel)"
                if !ERRORLEVEL! EQU 2 goto:eof
            )
            copy /Y !userSave! !slotFile!

            if %nbArgs% NEQ 3 (
                set /P "labelRead=Please, enter a label for this slot (use only ASCII characters) : "
                set "newLabel=!labelRead! @!DATE!"

                echo !newLabel!> !slotFileLabel!
            ) else (
                set "slotFileLabel="!igsvf:"=!\!title!_!currentUser!_slot!slotToActivate!.txt""

                if not exist !slotFileLabel! (
                    REM : add the label
                    set /P "labelRead=Please, enter a label for this slot (use only ASCII characters) : "
                    set "newLabel=!labelRead! @!DATE!"

                    echo !label!> !slotFileLabel!
                )

                        echo| set /p="Activating slot!slotToActivate!:"
                        type !slotFileLabel!

            )
        )
        call:activateSlot !incSlot!

    goto:eof
    REM : ------------------------------------------------------------------


    :formatLine

        set "l=%1"
        set "fn=%2"
        set "l=%l:"=%"
        set "fn=%fn:"=%"

        set "str=!slotNumber! ^: !l:%fn%=bytes! [!currentLabel:"=!]"
        set "str=!str:   = !"
        set "str=!str:  = !"
        set "str=!str:  =, !"

        set "%3=!str!"

    goto:eof
    REM : ------------------------------------------------------------------

    :setExtraSlot

        set /A "gameIndex=%~1"

        REM : get Title
        for /F "delims=~" %%g in (!gamePath!) do set "title=%%~nxg"

        REM : ingame saves folder
        set "igsvf="!gamePath:"=!\Cemu\inGameSaves""

        REM : No slot defined, create it from current save
        set "userSave="!igsvf:"=!\!title!_!currentUser!.rar""
        if not exist !userSave! (
            echo !title! ^: sorry^, no saves found for !currentUser!
            if %nbArgs% EQU 0 pause
            goto:eof
        )

        set "activeSlotFile="!igsvf:"=!\!title!_!currentUser!_activeSlot.txt""

        :getChoice
        if %nbArgs% LEQ 1 cls
        set /A "nbSlots=0"

        REM : when called from desktop QUIET_MODE=0, ask for srcSlot
        if %nbArgs% LEQ 2 if %nbArgs% NEQ 0 (
            echo =========================================================
            if !activeSlot! NEQ 0 (
                echo '!title!' extra slots ^(active one is marked using ^>^)
            ) else (
                echo '!title!' extra slots ^:
            )
            set "pat="!igsvf:"=!\!title!_!currentUser!_slot*.rar""

            for /F "delims=~" %%g in ('dir /S /B /T:W !pat! 2^>NUL') do (
                echo ---------------------------------------------------------
                set "slotFile="%%g""
                set "pat2=!currentUser:"=!_slot"

                for /F "delims=~" %%k in ('dir /T:W !slotFile! 2^>NUL ^| find "!pat2!"') do set "line="%%k""


                set "currentLabel="NOT_FOUND""

                set "slotLabelFile=!slotFile:.rar=.txt!"
                for /F "delims=~" %%j in ('type !slotLabelFile! 2^>NUL') do set "currentLabel="%%j""

                REM : get slotNumber
                set "str=!slotFile:"=!"
                set "str=!str:~-5!"
                set /A "slotNumber=!str:.rar=!"
                set "currentLabel=!currentLabel:  =!"
                for /F "delims=~" %%j in (!slotFile!) do set "fileName="%%~nxj""

                call:formatLine !line! !fileName! details

                if !slotNumber! EQU !activeSlot! (
                    echo ^> !details!
                ) else (
                    echo   !details!
                )
                set /A "nbSlots+=1"
            )
            echo =========================================================

            echo.
            echo What do you want to do ^?

            echo.
            if !nbGamesSelected! GTR 1 (
                echo    1 ^: done with this game^, continue with the next one
            ) else (
                echo    1 ^: done with this game^, exit
            )
            echo.
            echo  or
            echo.
            echo    2 ^: create a new extra slot and activate it

            if !nbSlots! GTR 0 (
                echo    3 ^: activate a slot
                echo    4 ^: delete an existing slot
                echo    5 ^: override default^'s user save with a given slot and deactivate all slots
                echo    6 ^: override default^'s user save with a given slot and delete all slots
                echo    7 ^: delete all slots ^(keep default user^'s save^)
                echo    8 ^: deactivate all slots ^(use default user^'s save and do not delete slots^)

                echo.
                choice /C 12345678 /N /M "Please, enter your choice   : "
                set /A "userChoice=!ERRORLEVEL!"

            ) else (
                echo.
                choice /C 12 /N /M "Please, enter your choice   : "
                set /A "userChoice=!ERRORLEVEL!"

            )

            choice /C yn /N /M "Confirm !userChoice!? (y/n to cancel) : "
            if !ERRORLEVEL! EQU 2 goto:getChoice

            if !userChoice! EQU 1 timeout /T 3 > NUL 2>&1 & goto:eof
            if !userChoice! EQU 2 call:createNewSlot
            if !userChoice! EQU 3 call:activateSlot
            if !userChoice! EQU 4 call:deleteSlot
            if !userChoice! EQU 5 call:overrideUserSave & call:deactivateAllSlots
            if !userChoice! EQU 6 call:overrideUserSave & call:deleteAllSlots
            if !userChoice! EQU 7 call:deleteAllSlots
            if !userChoice! EQU 8 call:deactivateAllSlots

            goto:getChoice
        )
        if %nbArgs% EQU 3 (
            REM : 3 args => create a new slot for the game (!currentUser!) from the last used one using a given label and activate it [not interactive]
            set /A "nbSlots=1"

            REM : force activeSlot to 0
            set /A "activeSlot=0"
            call:createNewSlot
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :treatUser

        set "userActiveSlotFile="!igsvf:"=!\!GAME_TITLE!_!currentUser!_activeSlot.txt""

        if exist !userActiveSlotFile! (

            REM : get relative path of activeSave file
            for /F "delims=~" %%i in ('type !userActiveSlotFile! 2^>NUL') do set "activeSave="%%i""
            REM : activeLabel = !GAME_TITLE!_!currentUser!_slot%slotNumber%.txt""
            set "activeLabel=!activeSave:.rar=.txt!"

            if exist !activeSave! (
                if not exist !activeLabel! (
                    REM : should never happens
                    REM : create it
                    echo "!activeSave! @!DATE!" > !activeLabel!
                )
                goto:activeSlotFound
            )

            REM : if !activeSave! does not exist : fix things
            REM : search for the last modified slot file

            REM : if exists remove !activeLabel! as here !activeSave! doesn't exist
            if exist !activeLabel!  del /F !activeLabel! > NUL 2>&1

            REM : search for last slot used
            set "activeSave="NONE""

            REM : loop on all file found (reverse sorted by date => exit loop whith the last modified one)
            for /F "delims=~" %%i in ('dir /B /O:-D /T:W !GAME_TITLE!_!currentUser!_slot*.rar  2^>NUL') do (
                set "activeSave="%%i""
            )
            REM : if no slot was found
            if not [!activeSave!] == ["NONE"] (
                REM : remove !userActiveSlotFile! (leave slotNumber and slotLable to theirs default values : 0, No slots define yet)
                del /F !userActiveSlotFile!  > NUL 2>&1

                goto:activeSlotFound
            )

            REM : set this slot
            set "activeLabel=!activeSave:.rar=.txt!"
            if not exist !activeLabel! (
                REM : should never happens
                REM : fix it (creates it here)
                echo "!activeSave! @!DATE!" > !activeLabel!

                REM : update userActiveSlotFile file
                echo !activeSave! > !userActiveSlotFile!
            )
        )

        :activeSlotFound
        REM : if a slot was found
        if not [!activeLabel!] == ["NONE"] (

            REM : get slotNumber
            set "str=!activeLabel:"=!"
            set "str=!str:~-5!"
            set /A "slotNumber=!str:.txt=!"

            REM : get slotLabel
            for /F "delims=~" %%i in ('type !activeLabel! 2^>NUL') do set "slotLabel="%%i""

        ) else (
            REM : check if a save exist for the user
            set "userSave="!GAME_TITLE!_!currentUser!.rar""

            if not exist !userSave! (
                REM : overide slotLabel
                set "slotLabel="No Save found""
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :getExtraSlotState


        echo ---------------------------------------------------------

        REM : ingame saves folder
        set "igsvf="!GAME_FOLDER_PATH:"=!\Cemu\inGameSaves""

        REM : default values
        set /A "slotNumber=0"
        set "slotLabel="No slots define yet""
        if not exist !igsvf! (
            set "msg=no saves found"
            mkdir !igsvf! > NUl 2>&1
        ) else (

            REM cd to ingame saves folder
            pushd !igsvf!
            set /A "fromOne=nbUsers-1"
            set "msg="
            for /L %%u in (0,1,!fromOne!) do (

                REM : default values
                set /A "slotNumber=0"
                set "slotLabel="No slots define yet""
                set "activeLabel="NONE""

                set "currentUser=!arrayUsers[%%u]!"

                call:treatUser

                if !slotNumber! NEQ 0 (
                    if %nbArgs% EQU 0 (
                        set "msg=!currentUser! [!slotNumber!=!slotLabel:"=!]^, !msg!"
                    ) else (
                        set "msg=!currentUser! [!slotNumber!=!slotLabel:"=!]"
                    )
                ) else (
                    if %nbArgs% EQU 0 (
                        set "msg=!currentUser! [!slotLabel:"=!]^, !msg!"
                    ) else (
                        set "msg=!currentUser! [!slotLabel:"=!]"
                    )
                )

            )
        )

        if %nbArgs% EQU 0 (
            echo '!GAME_TITLE!' ^: !msg!
        ) else (
            echo !nbGames! ^: '!GAME_TITLE!' =^>  !msg!
        )

        REM : store in arrays only if nbArg <> 0
        if %nbArgs% NEQ 0 (
            set "arrayGames[!nbGames!]=!GAME_FOLDER_PATH!"
            set "arraySlots[!nbGames!]=!slotNumber!"
            set "arrayLabels[!nbGames!]=!slotLabel!"
        )

        set /A "nbGames+=1"
        pushd !GAMES_FOLDER!
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


    