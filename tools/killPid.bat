@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    timeout /T %2

    taskkill /F /pid %1

goto:eof

