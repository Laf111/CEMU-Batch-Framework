@echo off
setlocal EnableExtensions
timeout /t 3 > NUL 2>&1
REM : force riority to High
wmic process where name="cemu.exe" call setpriority 128 > NUL 2>&1
REM : force riority to Realtime (will work only when launching as admin)
wmic process where name="cemu.exe" call setpriority 256 > NUL 2>&1
exit 0