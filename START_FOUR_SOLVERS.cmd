@echo off
setlocal
cd /d "%~dp0"
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_four_solvers"
echo MATLAB exit code: %ERRORLEVEL%
pause
