@echo off
echo Добавляю в автозагрузку Windows...
powershell -NoProfile -Command "$startup=[Environment]::GetFolderPath('Startup'); $shortcut=Join-Path $startup 'GigaAM Voice Typer.lnk'; $target='%~dp0start_silent.vbs'; $ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut($shortcut); $sc.TargetPath=$target; $sc.WorkingDirectory='%~dp0'; $sc.Description='GigaAM Voice Typer'; $sc.WindowStyle=7; $sc.Save(); Write-Host 'Создан ярлык:' $shortcut -ForegroundColor Green"
echo.
pause
