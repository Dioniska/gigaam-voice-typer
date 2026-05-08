@echo off
title GigaAM Voice Typer
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
    echo Окружение не найдено. Сначала запустите setup.bat
    pause
    exit /b 1
)
set PYTHONUTF8=1
chcp 65001 > nul
".venv\Scripts\python.exe" -X utf8 voice_typer.py
pause
