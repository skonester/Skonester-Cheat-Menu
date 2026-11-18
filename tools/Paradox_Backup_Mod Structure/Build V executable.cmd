@echo off
setlocal
v -prod -o "%~dp0backup_mods.exe" "%~dp0."
set "build_exit_code=%errorlevel%"
echo.
if "%build_exit_code%"=="0" echo Built backup_mods.exe successfully.
if not "%build_exit_code%"=="0" echo Build failed. Check that the V compiler is installed.
pause
exit /b %build_exit_code%
