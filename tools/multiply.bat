@echo off
color f0
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : This script multiply numbers (float or integer) with no limitations

    setlocal EnableDelayedExpansion
    call:setCharSet

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]=%~1"
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end
    
    if !nbArgs! EQU 0 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "%~0" number1 number2
        pause
        exit /b 99
    )
    
    REM : Args
    set "str1=!args[0]!"
    set "str2=!args[1]!"

    REM : Args checks
    echo !str1! | findstr /R "^[0-9.]*.$" > NUL 2>&1 && goto:str1Ok
    echo ERROR^:^(!str1!^) is not a number using ^. as decimals delimiter
    exit /b 1
    
    :str1Ok
    echo !str2! | findstr /R "^[0-9.]*.$" > NUL 2>&1 && goto:str2Ok
    echo ERROR^:^(!str2!^) is not a number using ^. as decimals delimiter
    exit /b 2
    
    :str2Ok
    
    REM : compute length and dot rank in the string
    call:getLengthAndDotPositionFloat !str1! length1 dotRank1
    call:getLengthAndDotPositionFloat !str2! length2 dotRank2
    
    REM : position of the decimal part in the result
    set /A "nbDec=0"
    if not ["!dotRank1!"] == [""] set /A "nbDec=length1-1-!dotRank1!"
    if not ["!dotRank2!"] == [""] set /A "nbDec=nbDec+length2-1-!dotRank2!"
    
    REM : remove the dot and compute the product
    set "int1=!str1:.=!"
    set "int2=!str2:.=!"
    call:multiply int1 int2 prodStr

    REM : get the length of the product string
    call:strLength !prodStr! length   
    
    set /A "decPartSize=length-nbDec"
    REM : built the result
    if !nbDec! EQU 0 (
        set result=!prodStr!
    ) else (
        set "result=!prodStr:~0,%decPartSize%!.!prodStr:~%decPartSize%,%nbDec%!"
    )
    
    echo !result!
    
    exit /b 0
 
REM : ------------------------------------------------------------------
REM : functions
REM : ------------------------------------------------------------------

    REM : Get the length of a string
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
    
    REM : Get the length and the dot position in a string
    :getLengthAndDotPositionFloat
    
        set "str=%~1"
        
        REM : dot position in str
        set "dotPos="
        REM : str length
        set /A "len=-1"

        :loop
        set /A "len=len+1"
        set "subStr=!str:~%len%,1!"
        if defined subStr (
            if ["%subStr%"] == ["."] set /A "dotPos=!len!"
            goto:loop
        )
        
        REM : outputs
        set "%2=!len!"
        set "%3=!dotPos!"
        
    goto:eof
        
REM : ------------------------------------------------------------------
    REM : Multiply long integer (bypass 32bits limitation)
    :multiply

        set _num1=!%1!
        set _num2=!%2!
        set _result=%3
        
        for /l %%a in (1,1,2) do (
            for /l %%b in (0,1,9) do (
                set _num%%a=!_num%%a:%%b=%%b !
            )
         )
        for %%a in (!_num1!) do set /a _num1cnt+=1 & set _!_num1cnt!_num1=%%a
        for %%a in (!_num2!) do set /a _num2cnt+=1 & set _!_num2cnt!_num2=%%a
        if !_num1cnt! equ 1 if !_num2cnt! equ 1 (
           set /a !_result!=!_num1! * !_num2!
           goto :eof
        )
        for /l %%b in (!_num2cnt!,-1,1) do (
        
            for /l %%a in (!_num1cnt!,-1,1) do (
                set /a _tmp=!_%%b_num2! * !_%%a_num1! !_plus! !_co!
                set _co=
                set _plus=
                if !_tmp! gtr 9 set _co=!_tmp:~0,1!& set _tmp=!_tmp:~-1!& set _plus=+
                set _num3_%%b=!_num3_%%b!!_spc!!_tmp!
                set _spc= 
                set _tmp=
            )
            if defined _co set _num3_%%b=!_num3_%%b! !_co!& set _co=& set _plus=
            set _num3_%%b=!_zero!!_num3_%%b!
            set _zero=0!_spc1!!_zero!
            set _spc1= 
            for %%a in (!_num3_%%b!) do (
                set /a _cnt+=1
                for %%c in (!_cnt!) do set _num4_%%c=!_num4_%%c!%%a+
            )
            set _cnt=
        )
        for /f %%a in ('set _num4') do set /a _colcnt+=1
        for /l %%a in (1,1,!_colcnt!) do set /a _num5_%%a=!_num4_%%a:~0,-1!
        for /l %%a in (1,1,!_colcnt!) do (
            if defined _co set /a _num5_%%a=!_num5_%%a! + !_co!
            set _co=
            if !_num5_%%a! gtr 9 (
                set _co=!_num5_%%a:~0,-1!
                set _num6=!_num5_%%a:~-1!!_num6!
            ) else (
                set _num6=!_num5_%%a!!_num6!
            )
            set !_result!=!_co!!_num6!
        )
        
    goto:eof
    REM : ------------------------------------------------------------------
    
    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------
    
    