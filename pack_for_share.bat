@echo off
title GigaAM Voice Typer - pack for sharing
cd /d "%~dp0"
echo.
echo Packing folder for sharing (excludes .venv, logs, __pycache__).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$src = '%~dp0'.TrimEnd('\'); ^
     $tmp = Join-Path $env:TEMP ('GigaAM-Voice-Portable_' + [guid]::NewGuid().ToString('N')); ^
     New-Item -ItemType Directory -Path $tmp | Out-Null; ^
     $exclude = @('.venv','.git','__pycache__','voice_typer.log','_setup_test.log','model_config.txt'); ^
     Get-ChildItem $src -Force | Where-Object { ($exclude -notcontains $_.Name) -and ($_.Extension -ne '.zip') -and ($_.Extension -ne '.log') } | ForEach-Object { Copy-Item $_.FullName -Destination $tmp -Recurse -Force }; ^
     $zip = Join-Path $src 'GigaAM-Voice-Portable.zip'; ^
     if (Test-Path $zip) { Remove-Item $zip -Force }; ^
     Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip -Force; ^
     Remove-Item $tmp -Recurse -Force; ^
     $size = [math]::Round((Get-Item $zip).Length/1KB, 1); ^
     Write-Host ''; ^
     Write-Host ('Created: ' + $zip + ' (' + $size + ' KB)') -ForegroundColor Green; ^
     Write-Host 'Send this zip to another PC. Receiver: unzip, then double-click setup.bat.' -ForegroundColor Cyan"
echo.
pause
