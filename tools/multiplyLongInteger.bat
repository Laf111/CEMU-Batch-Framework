@ECHO OFF
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
SETLOCAL

SET _FIRST=%1
SET _SECOND=%2

echo !_FIRST! | findStr /R "^[0-9]*$" > NUL 2>&1 && (
    echo ERROR^:^(!_FIRST!^)notAnInteger
    exit /b 1
)

echo !_SECOND! | findStr /R "^[0-9]*$" > NUL 2>&1 && (
    echo ERROR^:^(!_SECOND!^)notAnInteger
    exit /b 2
)

CALL :MULTIPLY _FIRST _SECOND _ANSWER
ECHO !_ANSWER!

exit /b 0
GOTO :END

:MULTIPLY
   ::MULTIPLY NUMBERS LARGER THAN 32-BITS
   ::SYNTAX: CALL MULTIPLY _VAR1 _VAR2 _VAR3
   ::VER 1.2 - Fixed ending carry over bug - Thanks Justin
   ::hieyeque1@gmail.com - drop me a note telling me
   ::if this has helped you.  Sometimes I don't know if anyone uses my stuff
   ::Its free for the world to use.
   ::I retain the rights to it though, you may not copyright this
   ::to prevent others from using it, you may however copyright works
   ::as a whole that use this code.
   ::Just don't try to stop others from using this through some legal means.
   ::CopyRight Brian Williams 5/18/2009
   :: _VAR1 = VARIABLE AGAINST WHICH WE SHALL COMPARE
   :: _VAR2 = VARIABLE TO BE COMPARED
   :: _VAR3 = VARIABLE WITH TRUE/FALSE RETURNED
   SET _NUM1=!%1!
   SET _NUM2=!%2!
   SET _RESULT=%3
   FOR /L %%A IN (1,1,2) DO (
      FOR /L %%B IN (0,1,9) DO (
         SET _NUM%%A=!_NUM%%A:%%B=%%B !
         )
      )
   FOR %%A IN (!_NUM1!) DO SET /A _NUM1CNT+=1 & SET _!_NUM1CNT!_NUM1=%%A
   FOR %%A IN (!_NUM2!) DO SET /A _NUM2CNT+=1 & SET _!_NUM2CNT!_NUM2=%%A
   IF !_NUM1CNT! EQU 1 IF !_NUM2CNT! EQU 1 (
      SET /A !_RESULT!=!_NUM1! * !_NUM2!
      GOTO :EOF
      )
   FOR /L %%B IN (!_NUM2CNT!,-1,1) DO (
      FOR /L %%A IN (!_NUM1CNT!,-1,1) DO (
         SET /A _TMP=!_%%B_NUM2! * !_%%A_NUM1! !_PLUS! !_CO!
         SET _CO=
         SET _PLUS=
         IF !_TMP! GTR 9 SET _CO=!_TMP:~0,1!& SET _TMP=!_TMP:~-1!& SET _PLUS=+
         SET _NUM3_%%B=!_NUM3_%%B!!_SPC!!_TMP!
         SET _SPC= 
         SET _TMP=
         )
      IF DEFINED _CO SET _NUM3_%%B=!_NUM3_%%B! !_CO!& SET _CO=& SET _PLUS=
      SET _NUM3_%%B=!_ZERO!!_NUM3_%%B!
      SET _ZERO=0!_SPC1!!_ZERO!
      SET _SPC1= 
      FOR %%A IN (!_NUM3_%%B!) DO (
        SET /A _CNT+=1
        FOR %%C IN (!_CNT!) DO SET _NUM4_%%C=!_NUM4_%%C!%%A+
        )
      SET _CNT=
      )
   FOR /F %%A IN ('SET _NUM4') DO SET /A _COLCNT+=1
   FOR /L %%A IN (1,1,!_COLCNT!) DO SET /A _NUM5_%%A=!_NUM4_%%A:~0,-1!
   FOR /L %%A IN (1,1,!_COLCNT!) DO (
      IF DEFINED _CO SET /A _NUM5_%%A=!_NUM5_%%A! + !_CO!
      SET _CO=
      IF !_NUM5_%%A! GTR 9 (
         SET _CO=!_NUM5_%%A:~0,-1!
         SET _NUM6=!_NUM5_%%A:~-1!!_NUM6!
         ) ELSE (
         SET _NUM6=!_NUM5_%%A!!_NUM6!
         )
      SET !_RESULT!=!_CO!!_NUM6!
      )
   GOTO :EOF

:END