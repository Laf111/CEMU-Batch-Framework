@echo off
setlocal EnableExtensions
timeout /t 3 > NUL
REM : force riority to High
wmic process where name="cemu.exe" call setpriority 128 > NUL
REM : force riority to Realtime (will work only when launching as admin)
wmic process where name="cemu.exe" call setpriority 256 > NUL
exit 0