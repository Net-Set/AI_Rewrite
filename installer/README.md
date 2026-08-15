# `installer/`

Builds the three distributable Windows executables (`AI_Rewrite.exe`, `ai-commit.exe`,
`AI-Rewrite-Setup.exe`) from source. See [`build.ps1`](./build.ps1) for the build itself and
[`Installer.ahk`](./Installer.ahk) for what the installer/uninstaller does.

```powershell
installer/build.ps1
```

Requires PyInstaller (`pip install pyinstaller`) and AutoHotkey v2's bundled `Ahk2Exe.exe`
compiler. Output lands in `installer/dist/`.

## Why Windows/antivirus flags this installer

If you (or someone you sent the exe to) sees **"Windows protected your PC" / Unknown
Publisher** or an antivirus warning when running `AI-Rewrite-Setup.exe`, that's expected
for an unsigned build and isn't a sign anything is actually wrong with the file. Two
separate things cause it:

1. **"Unknown Publisher"** comes purely from the absence of a code-signing (Authenticode)
   certificate on the exe. Windows doesn't infer a publisher name from anywhere else — no
   signature means no identity to display, full stop.
2. **SmartScreen / antivirus warnings** are a reputation + heuristics problem, not a
   detection of anything malicious in this codebase specifically:
   - AutoHotkey-compiled exes (`AI_Rewrite.exe`, `AI-Rewrite-Setup.exe`) and PyInstaller
     one-file exes (`ai-commit.exe`) are common malware packaging tools, so AV heuristics
     key on that shape of file regardless of what it actually does.
   - `Installer.ahk` embeds two other exes via `FileInstall` and writes a
     `HKCU\...\Uninstall` registry entry plus an optional Startup shortcut — structurally
     that's the same pattern a dropper uses, even though here it's just... installing the
     app.
   - Even a signed, brand-new publisher gets SmartScreen friction until enough installs
     report running cleanly — reputation builds over time (an EV code-signing cert is the
     one shortcut that skips this).

### How to fix it for a release you're publishing

`build.ps1` has a built-in (opt-in) signing step. Set one of these before running it and
every exe it produces gets signed automatically; leave them unset and the build still
works, just unsigned, exactly as before:

```powershell
# Option 1: certificate already installed in your user cert store
$env:AI_REWRITE_CERT_THUMBPRINT = "<thumbprint>"

# Option 2: a .pfx file on disk
$env:AI_REWRITE_CERT_PATH = "C:\path\to\cert.pfx"
$env:AI_REWRITE_CERT_PASSWORD = "<password>"

installer/build.ps1
```

Requires `signtool.exe` (ships with the Windows SDK). Signing alone fixes "Unknown
Publisher" immediately; it also helps SmartScreen/AV warnings but doesn't eliminate them
instantly unless the certificate is EV — with an OV cert, reputation still has to build up
over real-world downloads.

To clear a false-positive AV/SmartScreen flag on an already-built exe (signed or not):
- Submit it to Microsoft for analysis: https://www.microsoft.com/en-us/wdsi/filesubmission
- Submit it to VirusTotal and use its false-positive report flow for any engine that flags it

### What to tell users in the meantime

Until a build is signed and has reputation, the honest guidance is: click **"More info" →
"Run anyway"** on the SmartScreen prompt, or add an exception in whatever antivirus flags
it. This is a real, known rough edge of shipping an unsigned free/open-source Windows
installer — not something specific to your download being broken.
