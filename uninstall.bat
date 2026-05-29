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

echo 4. Удаляю кеш моделей GigaAM (v2 и v3) в %%USERPROFILE%%\.cache\huggingface\hub
powershell -NoProfile -Command "$h=Join-Path $env:USERPROFILE '.cache\huggingface\hub'; $d=@(Get-ChildItem $h -Directory -Filter 'models--istupakov--gigaam-*' -ErrorAction SilentlyContinue); if ($d.Count -gt 0) { $ans=Read-Host 'Удалить кеш моделей GigaAM (~1 ГБ)? [y/N]'; if ($ans -ieq 'y') { $d | Remove-Item -Recurse -Force; Write-Host 'Кеш моделей удалён.' } } else { Write-Host 'Кеш моделей не найден.' }"

echo.
echo Готово. Файлы программы (voice_typer.py, .bat, .vbs) остались —
echo можете удалить эту папку вручную.
pause
