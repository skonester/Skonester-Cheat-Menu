@echo off
cd /d "%~dp0"
v run run_comfy_batch.v --run-name v2 --seed-offset 1
if errorlevel 1 goto done
v run finish_comfy_icons.v --run-name v2
:done
pause
