@echo off
setlocal
cd /d "%~dp0"
echo Core-resolved MCF pilot: fixed fiber, four scenes, clean/noisy, HIO/ER.
echo CPU double, 600-second soft cap. Do not run alongside another pilot.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_mcf_pilot"
echo MATLAB exit code: %ERRORLEVEL%
pause
