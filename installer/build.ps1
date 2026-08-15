# Rebuilds the three executables that make up AI-Rewrite-Setup.exe.
# Run from anywhere; paths below are resolved relative to this script.
#
# Requirements (all already used elsewhere in this repo):
#   - Python + `pip install pyinstaller requests` (for ai-commit.exe)
#   - AutoHotkey v2 + its bundled Ahk2Exe compiler (for AI_Rewrite.exe / the installer itself)
#
# Code signing (optional but strongly recommended - see installer/README.md "Why
# Windows/antivirus flags this installer" for why unsigned exes trigger "Unknown
# Publisher" and AV/SmartScreen warnings). Signing is skipped automatically if none
# of these are set, so the build still works with no certificate configured:
#   - $env:AI_REWRITE_CERT_THUMBPRINT  - thumbprint of a cert already in the
#     current user's certificate store (CurrentUser\My), OR
#   - $env:AI_REWRITE_CERT_PATH + $env:AI_REWRITE_CERT_PASSWORD - path to a
#     .pfx file and its password
#   - $env:AI_REWRITE_TIMESTAMP_URL - optional, defaults to DigiCert's RFC 3161
#     timestamp server so signatures stay valid after the cert expires

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ahk2exe = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$ahkBase = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
$timestampUrl = if ($env:AI_REWRITE_TIMESTAMP_URL) { $env:AI_REWRITE_TIMESTAMP_URL } else { "http://timestamp.digicert.com" }

function Get-SignTool {
    $candidate = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($candidate) { return $candidate.Source }
    $kits = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Filter "signtool.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "*x64*" } | Select-Object -Last 1
    if ($kits) { return $kits.FullName }
    return $null
}

function Sign-Exe([string]$exePath) {
    if (-not ($env:AI_REWRITE_CERT_THUMBPRINT -or ($env:AI_REWRITE_CERT_PATH -and $env:AI_REWRITE_CERT_PASSWORD))) {
        Write-Host "  (skipping signing - no AI_REWRITE_CERT_THUMBPRINT or AI_REWRITE_CERT_PATH/PASSWORD set)"
        return
    }
    $signtool = Get-SignTool
    if (-not $signtool) {
        Write-Warning "  signtool.exe not found (install the Windows SDK) - leaving $exePath unsigned"
        return
    }
    Write-Host "  Signing $exePath..."
    if ($env:AI_REWRITE_CERT_THUMBPRINT) {
        & $signtool sign /sha1 $env:AI_REWRITE_CERT_THUMBPRINT /fd SHA256 /tr $timestampUrl /td SHA256 /d "AI Rewrite" $exePath
    } else {
        & $signtool sign /f $env:AI_REWRITE_CERT_PATH /p $env:AI_REWRITE_CERT_PASSWORD /fd SHA256 /tr $timestampUrl /td SHA256 /d "AI Rewrite" $exePath
    }
    if ($LASTEXITCODE -ne 0) { throw "signtool failed on $exePath (exit $LASTEXITCODE)" }
}

Write-Host "Building ai-commit.exe (PyInstaller)..."
python -m PyInstaller --onefile --console --name ai-commit `
    --distpath "$root\dist" --workpath "$root\build" --specpath "$root\build" `
    "$root\..\git-commit-tool\ai_commit.py"
Sign-Exe "$root\dist\ai-commit.exe"

Write-Host "Building AI_Rewrite.exe (Ahk2Exe)..."
& $ahk2exe /in "$root\..\desktop-autohotkey\AI_Rewrite.ahk" /out "$root\dist\AI_Rewrite.exe" /base $ahkBase
Sign-Exe "$root\dist\AI_Rewrite.exe"

Write-Host "Building AI-Rewrite-Setup.exe (Ahk2Exe)..."
& $ahk2exe /in "$root\Installer.ahk" /out "$root\dist\AI-Rewrite-Setup.exe" /base $ahkBase
Sign-Exe "$root\dist\AI-Rewrite-Setup.exe"

Write-Host "Done: $root\dist\AI-Rewrite-Setup.exe"
