@echo off
setlocal
cd /d "%~dp0"
echo MCF photon/read-noise scan: 30 new cases plus 6 preserved baseline cases.
echo Fixed mixed sample, hex/measured layouts, 3 paired seeds. CPU sequential.
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -wait -batch "setup_project; run_fast_mcf_noise_scan"
echo MATLAB exit code: %ERRORLEVEL%
pause
