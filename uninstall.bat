@echo off
title GigaAM Voice Typer - Uninstall
echo Удаление GigaAM Voice Typer
echo.
echo 1. Останавливаю работающий процесс...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe' OR Name='python.exe'\" | Where-Object { $_.CommandLine -like '*voice_typer.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 1 > nul

echo 2. Удаляю автозагрузку (если есть)...
powershell -NoProfile -Command "$s=Join-Path ([Environment]::GetFolderPath('Startup')) 'GigaAM Voice Typer.lnk'; if (Test-Path $s) { Remove-Item $s }"

echo 3. Удаляю виртуальное окружение (.venv)...
if exist ".venv" rmdir /s /q ".venv"

echo 4. Удаляю кеш модели в %%USERPROFILE%%\.cache\huggingface\hub\models--istupakov--gigaam-v2-onnx
set MODEL_CACHE=%USERPROFILE%\.cache\huggingface\hub\models--istupakov--gigaam-v2-onnx
if exist "%MODEL_CACHE%" (
    set /p del_model="Удалить кеш модели (~240 МБ)? [y/N]: "
    if /i "%del_model%"=="y" rmdir /s /q "%MODEL_CACHE%"
)

echo.
echo Готово. Файлы программы (voice_typer.py, .bat, .vbs) остались —
echo можете удалить эту папку вручную.
pause
