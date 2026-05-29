# GigaAM Voice Typer - first-time installer.
# Run via setup.bat. Messages kept ASCII-only to avoid PowerShell 5.1
# console-codepage issues on non-English Windows.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Section($msg) {
    Write-Host ""
    Write-Host "=== $msg ===" -ForegroundColor Cyan
}

function Fail($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " GigaAM Voice Typer - installation              " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will take 5-15 minutes depending on your network."
Write-Host "It will download: Python 3.12 (if missing), pip packages (~500 MB),"
Write-Host "and the GigaAM v3 models (~1 GB total for all variants)."
Write-Host ""

# --- Step 1: Find or install Python 3.10 / 3.11 / 3.12 ---
Write-Section "Step 1/4: Locate Python"

$pyExe = $null
foreach ($v in '3.12', '3.11', '3.10') {
    try {
        $out = & py "-$v" -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $out -and (Test-Path $out.Trim())) {
            $pyExe = $out.Trim()
            Write-Host "Found Python ${v}: $pyExe" -ForegroundColor Green
            break
        }
    } catch {}
}

if (-not $pyExe) {
    Write-Host "Python 3.10-3.12 not found. Trying winget..." -ForegroundColor Yellow

    $hasWinget = $false
    try { $null = & winget --version 2>$null; $hasWinget = ($LASTEXITCODE -eq 0) } catch {}

    if (-not $hasWinget) {
        Fail "winget is not available. Install Python 3.12 manually from https://www.python.org/downloads/ (check 'Add Python to PATH'), then run setup.bat again."
    }

    & winget install -e --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Fail "winget could not install Python. Install it manually from https://www.python.org/downloads/"
    }

    Start-Sleep -Seconds 3
    try {
        $out = & py "-3.12" -c "import sys; print(sys.executable)"
        if ($out) { $pyExe = $out.Trim() }
    } catch {}
    if (-not $pyExe) {
        Fail "Python was installed but is not visible in this session. Close this window and run setup.bat again."
    }
    Write-Host "Python installed: $pyExe" -ForegroundColor Green
}

# --- Step 2: VC++ Redistributable (required by onnxruntime) ---
Write-Section "Step 2/4: Visual C++ Redistributable"

try {
    & winget install -e --id Microsoft.VCRedist.2015+.x64 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VC++ Redistributable installed" -ForegroundColor Green
    } else {
        Write-Host "VC++ already present (exit $LASTEXITCODE) - continuing" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not check VC++ via winget - probably already installed. Continuing." -ForegroundColor Yellow
}

# --- Step 3: venv + pip packages ---
Write-Section "Step 3/4: Virtual environment and dependencies"

$venvDir = Join-Path $PSScriptRoot ".venv"
$venvPy  = Join-Path $venvDir "Scripts\python.exe"

# Detect a broken venv (e.g. copied from another machine where the base
# Python lives at C:\Users\OtherUser\... that doesn't exist here).
$venvBroken = $false
if (Test-Path $venvPy) {
    try {
        $null = & $venvPy --version 2>$null
        if ($LASTEXITCODE -ne 0) { $venvBroken = $true }
    } catch { $venvBroken = $true }
}

if ($venvBroken) {
    Write-Host "Existing .venv points to a Python that doesn't exist on this machine (probably copied from another PC). Recreating ..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $venvDir
}

if (-not (Test-Path $venvPy)) {
    Write-Host "Creating virtual environment in .venv ..."
    & $pyExe -m venv $venvDir
    if ($LASTEXITCODE -ne 0) { Fail "Failed to create venv" }
}

Write-Host "Upgrading pip ..."
& $venvPy -m pip install --upgrade pip --quiet --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { Fail "Failed to upgrade pip" }

Write-Host "Installing packages (this is the slowest step) ..."
$pkgs = @(
    'onnxruntime-directml',
    'onnx-asr',
    'sounddevice',
    'numpy',
    'keyboard',
    'pyperclip',
    'huggingface_hub',
    'pystray',
    'Pillow'
)
& $venvPy -m pip install --upgrade --disable-pip-version-check @pkgs
if ($LASTEXITCODE -ne 0) { Fail "Failed to install pip packages. See output above." }

Write-Host "All packages installed" -ForegroundColor Green

# --- Step 4: Download models + warmup (all variants from asr.py) ---
Write-Section "Step 4/4: Downloading GigaAM v3 models (~1 GB total, first run only)"

& $venvPy -X utf8 (Join-Path $PSScriptRoot "warmup.py")
$warmupExit = $LASTEXITCODE

if ($warmupExit -ne 0) {
    Fail "Model download or initialization failed. Check internet connection and try again."
}

# --- Done ---
Write-Section "Installation complete"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Double-click " -NoNewline; Write-Host "start_silent.vbs" -ForegroundColor Yellow -NoNewline; Write-Host "   - run in background (recommended)"
Write-Host "  2. Or " -NoNewline; Write-Host "start.bat" -ForegroundColor Yellow -NoNewline; Write-Host " - run with console window (debug)"
Write-Host "  3. " -NoNewline; Write-Host "add_autostart.bat" -ForegroundColor Yellow -NoNewline; Write-Host " - launch automatically on Windows logon"
Write-Host ""
Write-Host "Usage: hold Ctrl+Win, speak, release. Recognized text is pasted at cursor."
Write-Host ""
