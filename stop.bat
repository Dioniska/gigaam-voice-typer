@echo off
echo Останавливаю GigaAM Voice Typer...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe' OR Name='python.exe'\" | Where-Object { $_.CommandLine -like '*voice_typer.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Write-Host 'Stopped PID' $_.ProcessId }"
timeout /t 1 > nul
