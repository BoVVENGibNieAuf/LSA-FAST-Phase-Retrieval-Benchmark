@echo off
setlocal
cd /d "%~dp0"
set "MATLAB_PREFDIR=%CD%\matlab_prefs"
if not exist "%MATLAB_PREFDIR%" mkdir "%MATLAB_PREFDIR%"
echo Fixed Poisson experiment: 48 solves, CPU only. Completed solves are reused.
echo Do not run alongside another MATLAB comparison.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -logfile "%CD%\poisson_stage.log" -batch "addpath('tools'); run_fast_poisson_stage"
set "RESULT=%ERRORLEVEL%"
echo MATLAB exit code: %RESULT%
pause
exit /b %RESULT%
