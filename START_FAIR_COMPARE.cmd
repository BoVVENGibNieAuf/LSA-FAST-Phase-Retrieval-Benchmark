@echo off
setlocal
cd /d "%~dp0"
echo FAST/HIO vs ER pilot: 40 iterations each, shared completed calibration.
echo Do not run alongside another MATLAB reconstruction.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_fair_pilot"
echo MATLAB exit code: %ERRORLEVEL%
pause
