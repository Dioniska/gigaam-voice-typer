# GigaAM Voice Typer - update an existing install in place (v3 + model switcher).
# Run via update.bat after overwriting the folder on a target machine. It will:
#   1. stop any running instance (old or new, from any folder)
#   2. upgrade onnx-asr / onnxruntime and download/warm all models
#   3. re-point the Startup autostart shortcut to THIS folder (if it existed)
#   4. start the new version
# Messages kept ASCII-only to avoid PowerShell 5.1 console-codepage issues.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Fail($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " GigaAM Voice Typer - update (v3 + model switch) " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$venvPy = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$vbs    = Join-Path $PSScriptRoot "start_silent.vbs"

# --- Step 1: stop any running instance (old version from any folder too) ---
Write-Host "Step 1/4: Stopping any running instance ..." -ForegroundColor Cyan
try {
    Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" |
        Where-Object { $_.CommandLine -like '*voice_typer.py*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Write-Host ("  stopped PID " + $_.ProcessId) }
} catch {}
Start-Sleep -Milliseconds 800

# --- Step 2: make sure the environment is up to date ---
$venvOk = $false
if (Test-Path $venvPy) {
    try {
        $null = & $venvPy --version 2>$null
        if ($LASTEXITCODE -eq 0) { $venvOk = $true }
    } catch {}
}

if (-not $venvOk) {
    Write-Host ""
    Write-Host "Step 2/4: No working .venv here - running full setup ..." -ForegroundColor Yellow
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "setup.ps1")
    if ($LASTEXITCODE -ne 0) { Fail "Setup failed. See messages above." }
} else {
    Write-Host ""
    Write-Host "Step 2/4: Upgrading onnx-asr / onnxruntime (enables v3) ..." -ForegroundColor Cyan
    & $venvPy -m pip install --upgrade --disable-pip-version-check onnx-asr onnxruntime-directml huggingface_hub
    if ($LASTEXITCODE -ne 0) { Fail "pip upgrade failed. Check internet connection." }

    Write-Host "Downloading / warming up models (first run pulls weights, ~1 GB) ..." -ForegroundColor Cyan
    & $venvPy -X utf8 (Join-Path $PSScriptRoot "warmup.py")
    if ($LASTEXITCODE -ne 0) { Fail "Model download/warmup failed. Check internet connection." }
}

# --- Step 3: re-point autostart to THIS folder (so the OLD one never starts) ---
Write-Host ""
Write-Host "Step 3/4: Updating Windows autostart ..." -ForegroundColor Cyan
$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'GigaAM Voice Typer.lnk'
if (Test-Path $lnk) {
    try {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($lnk)
        $sc.TargetPath = $vbs
        $sc.WorkingDirectory = $PSScriptRoot
        $sc.Description = 'GigaAM Voice Typer'
        $sc.WindowStyle = 7
        $sc.Save()
        Write-Host "  autostart shortcut now points to this folder" -ForegroundColor Green
    } catch {
        Write-Host "  could not update autostart shortcut: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  autostart not configured (no shortcut). Run add_autostart.bat to enable it." -ForegroundColor Yellow
}

# --- Step 4: launch the new version now ---
Write-Host ""
Write-Host "Step 4/4: Starting the new version ..." -ForegroundColor Cyan
try {
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
    Write-Host "  started" -ForegroundColor Green
} catch {
    Write-Host "  could not auto-start; run start_silent.vbs manually" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Update complete. The new version is running and set to autostart" -ForegroundColor Green
Write-Host "(if autostart was enabled). Switch models from the tray icon -> Model." -ForegroundColor Cyan
Write-Host ""
