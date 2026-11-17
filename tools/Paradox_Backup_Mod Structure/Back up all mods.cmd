@echo off
setlocal
if exist "%~dp0backup_mods.exe" goto run_backup
echo Building the V executable...
v -prod -o "%~dp0backup_mods.exe" "%~dp0."
if errorlevel 1 goto finished
:run_backup
"%~dp0backup_mods.exe" %*
:finished
set "backup_exit_code=%errorlevel%"
echo.
if not "%backup_exit_code%"=="0" echo Backup reported a problem. Review the output above.
pause
exit /b %backup_exit_code%
