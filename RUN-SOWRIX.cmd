@echo off
setlocal
cd /d "%~dp0"
if not exist ".env" (
    echo Missing .env. Copy the existing working SOWRIX .env into this folder.
    echo Do not generate a replacement session key if you have a working key.
    exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
    echo Creating a project-local Python environment...
    py -3.12 -m venv .venv || exit /b 1
)
".venv\Scripts\python.exe" -m pip install -r requirements.lock || exit /b 1
".venv\Scripts\python.exe" scripts\check_backend_setup.py --check-port || exit /b 1
".venv\Scripts\python.exe" backend\server.py
exit /b %errorlevel%
