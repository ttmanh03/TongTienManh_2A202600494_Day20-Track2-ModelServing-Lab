# Day 20 lab setup (Windows). Requires PowerShell 7+ (`pwsh`).
# Two supported paths:
#   1. Native Windows (CPU only, prebuilt llama-cpp-python wheel)
#   2. WSL2 — recommended if you have an NVIDIA GPU; run linux-setup.sh inside WSL.
#
# Run as: pwsh -ExecutionPolicy Bypass -File 00-setup\windows-setup.ps1
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')
$LabRoot = (Get-Location).Path

Write-Host "==> Day 20 lab setup (Windows)" -ForegroundColor Cyan
Write-Host "    repo: $LabRoot"

# 1. Python check (3.10–3.12 supported)
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "ERROR: Python 3.10+ not found. Install from https://www.python.org/downloads/" -ForegroundColor Red
    exit 1
}
$pyVer = (& python --version) 2>&1
Write-Host "    Python: $pyVer"

# Enforce supported versions on Windows to avoid source builds (long paths / toolchain issues).
try {
    $ver = (& python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    $parts = $ver -split '\.'
    $maj = [int]$parts[0]
    $min = [int]$parts[1]
} catch {
    Write-Host "ERROR: Failed to read Python version. Ensure 'python' works in this terminal." -ForegroundColor Red
    exit 1
}

if ($maj -ne 3 -or $min -lt 10 -or $min -gt 12) {
    Write-Host "ERROR: This lab's Windows path supports Python 3.10–3.12. You are using Python $ver." -ForegroundColor Red
    Write-Host "Why: llama-cpp-python often has prebuilt Windows wheels only for 3.10–3.12; newer versions fall back to source builds and may fail (e.g., Windows Long Path / C++ toolchain)." -ForegroundColor Yellow
    Write-Host "Fix:" -ForegroundColor Yellow
    Write-Host "  1) Install Python 3.12 (x64) from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  2) Recreate venv with:  py -3.12 -m venv .venv" -ForegroundColor Yellow
    Write-Host "  3) Run this setup script again" -ForegroundColor Yellow
    exit 1
}

# 2. virtualenv
if (-not (Test-Path '.venv')) {
    Write-Host "==> Creating .venv"
    python -m venv .venv
}
& .\.venv\Scripts\Activate.ps1

Write-Host "==> Upgrading pip"
python -m pip install --upgrade pip wheel | Out-Null

Write-Host "==> Installing Python deps from requirements.txt"
pip install -r requirements.txt

# 3. llama-cpp-python — prebuilt CPU wheel works on Windows out of the box.
#    For CUDA, set $env:LLAMA_CUDA=1 and ensure CUDA Toolkit + cmake are installed.
if ($env:LLAMA_CUDA -eq '1') {
    Write-Host "==> Building llama-cpp-python with CUDA (requires CUDA Toolkit + cmake)"
    $env:CMAKE_ARGS = '-DGGML_CUDA=on'
    pip install --upgrade --force-reinstall --no-cache-dir llama-cpp-python
} else {
    Write-Host "==> Installing prebuilt llama-cpp-python (CPU)"
    pip install --upgrade --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu llama-cpp-python
}

# 4. Probe + download model
python .\00-setup\detect-hardware.py
python .\00-setup\download-model.py

Write-Host ""
Write-Host "==> Setup complete. Activate the venv next time with:" -ForegroundColor Green
Write-Host "    .\.venv\Scripts\Activate.ps1"
Write-Host ""
Write-Host "==> If you have an NVIDIA GPU, consider WSL2 path instead:"
Write-Host "    wsl --install -d Ubuntu-22.04"
Write-Host "    Then inside WSL: bash 00-setup/linux-setup.sh"
Write-Host ""
Write-Host "==> Next: 01-llama-cpp-quickstart\README.md"
