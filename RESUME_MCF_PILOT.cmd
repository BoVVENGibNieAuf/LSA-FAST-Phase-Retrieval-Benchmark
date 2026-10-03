@echo off
setlocal
cd /d "%~dp0"
echo Resume preserved MCF run: reuse generated inputs and saved iterations.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_mcf_pilot('mcf_20261003_040919_594')"
echo MATLAB exit code: %ERRORLEVEL%
pause
