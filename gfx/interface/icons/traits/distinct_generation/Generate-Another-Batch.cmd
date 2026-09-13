@echo off
cd /d "%~dp0"
"C:\Users\admin\AppData\Local\Programs\Python\Python311\python.exe" run_comfy_batch.py --run-name v2 --seed-offset 1
if errorlevel 1 goto done
"C:\Users\admin\AppData\Local\Programs\Python\Python311\python.exe" finish_comfy_icons.py --run-name v2
:done
pause
