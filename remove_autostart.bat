@echo off
echo Удаляю из автозагрузки Windows...
powershell -NoProfile -Command "$startup=[Environment]::GetFolderPath('Startup'); $shortcut=Join-Path $startup 'GigaAM Voice Typer.lnk'; if (Test-Path $shortcut) { Remove-Item $shortcut; Write-Host 'Ярлык удалён' -ForegroundColor Green } else { Write-Host 'Ярлык не найден (возможно автозагрузка не была настроена)' -ForegroundColor Yellow }"
echo.
pause
