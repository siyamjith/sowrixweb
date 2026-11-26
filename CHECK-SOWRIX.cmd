@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
    echo Run RUN-SOWRIX.cmd first to install dependencies.
    exit /b 1
)
".venv\Scripts\python.exe" scripts\check_backend_setup.py %*
exit /b %errorlevel%
