@echo off
setlocal
cd /d "%~dp0"
where xelatex >nul 2>nul
if errorlevel 1 goto tectonic
xelatex -interaction=nonstopmode -halt-on-error main.tex
if errorlevel 1 goto fail
xelatex -interaction=nonstopmode -halt-on-error main.tex
if errorlevel 1 goto fail
goto done
:tectonic
where tectonic >nul 2>nul
if errorlevel 1 goto missing
tectonic --keep-logs main.tex
if errorlevel 1 goto fail
:done
echo Built main.pdf successfully.
pause
exit /b 0
:missing
echo Install XeLaTeX or Tectonic first.
:fail
echo Build failed. Review main.log or the console output.
pause
exit /b 1
