# Rebuilds the three executables that make up AI-Rewrite-Setup.exe.
# Run from anywhere; paths below are resolved relative to this script.
#
# Requirements (all already used elsewhere in this repo):
#   - Python + `pip install pyinstaller requests` (for ai-commit.exe)
#   - AutoHotkey v2 + its bundled Ahk2Exe compiler (for AI_Rewrite.exe / the installer itself)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ahk2exe = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$ahkBase = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

Write-Host "Building ai-commit.exe (PyInstaller)..."
python -m PyInstaller --onefile --console --name ai-commit `
    --distpath "$root\dist" --workpath "$root\build" --specpath "$root\build" `
    "$root\..\git-commit-tool\ai_commit.py"

Write-Host "Building AI_Rewrite.exe (Ahk2Exe)..."
& $ahk2exe /in "$root\..\desktop-autohotkey\AI_Rewrite.ahk" /out "$root\dist\AI_Rewrite.exe" /base $ahkBase

Write-Host "Building AI-Rewrite-Setup.exe (Ahk2Exe)..."
& $ahk2exe /in "$root\Installer.ahk" /out "$root\dist\AI-Rewrite-Setup.exe" /base $ahkBase

Write-Host "Done: $root\dist\AI-Rewrite-Setup.exe"
