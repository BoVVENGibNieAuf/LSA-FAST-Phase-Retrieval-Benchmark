@echo off
setlocal
cd /d "%~dp0"
echo Small synthetic software test only: four scenes, HIO/ER, CPU, no noise.
echo Do not run alongside another MATLAB reconstruction.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_synthetic_pilot"
echo MATLAB exit code: %ERRORLEVEL%
pause
