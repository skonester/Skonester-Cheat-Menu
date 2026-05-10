@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo SKONESTER LOCALIZATION REBUILDER
echo ========================================
echo.
echo Scanning localization files...
echo.

python rebuild_loc_mod1.py

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Python not found or script failed.
    echo Ensure Python 3 is installed and in your PATH.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] fully_consolidated_l_english.yml has been updated.
echo.
pause
