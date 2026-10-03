@echo off
setlocal
cd /d "%~dp0"
echo MCF layouts: hex, jitter, measured core positions; 3 paired seeds.
echo Sequential CPU runs. Reopening continues an unfinished batch.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_mcf_layouts"
echo MATLAB exit code: %ERRORLEVEL%
pause
