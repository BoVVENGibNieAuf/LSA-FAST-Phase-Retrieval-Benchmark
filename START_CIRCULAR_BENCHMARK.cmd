@echo off
setlocal
cd /d "%~dp0"
if defined MATLAB_EXE if exist "%MATLAB_EXE%" goto found
set "MATLAB_EXE="
for /f "delims=" %%I in ('where matlab.exe 2^>nul') do if not defined MATLAB_EXE set "MATLAB_EXE=%%I"
if defined MATLAB_EXE goto found
for /f "delims=" %%D in ('dir /b /ad /o-n "%ProgramFiles%\MATLAB\R*" 2^>nul') do if not defined MATLAB_EXE if exist "%ProgramFiles%\MATLAB\%%D\bin\matlab.exe" set "MATLAB_EXE=%ProgramFiles%\MATLAB\%%D\bin\matlab.exe"
if not defined MATLAB_EXE (
 echo MATLAB not found. Set MATLAB_EXE to the full path of matlab.exe.
 pause
 exit /b 2
)
:found
if not exist "matlab_prefs" mkdir "matlab_prefs"
set "MATLAB_PREFDIR=%CD%\matlab_prefs"
"%MATLAB_EXE%" -wait -logfile "%CD%\circular_validation.log" -batch "setup_project; run_fast_circular_benchmark"
set "RESULT=%ERRORLEVEL%"
echo MATLAB exit code: %RESULT%
echo See circular_validation.log and runs\latest_circular.json.
pause
exit /b %RESULT%
