@echo off
setlocal
cd /d "%~dp0"
set "MATLAB_PREFDIR=%CD%\matlab_prefs"
if not exist "%MATLAB_PREFDIR%" mkdir "%MATLAB_PREFDIR%"
echo Independent support/optics branch. MATLAB CPU only; 152 solves, resumable.
echo Do not run alongside another MATLAB task. Soft wall cap 1800 seconds per invocation.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -logfile "%CD%\support_optics.log" -batch "addpath('tools'); run_fast_support_optics"
set "RESULT=%ERRORLEVEL%"
echo MATLAB exit code: %RESULT%
pause
exit /b %RESULT%
