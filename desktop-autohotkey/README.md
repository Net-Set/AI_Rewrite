# AI Rewrite — Desktop (AutoHotkey v2)

Works **system-wide** on Windows: Notepad, WhatsApp Desktop, Word, Outlook, Telegram,
Discord, browsers — anywhere you can select and paste text.

Free, no billing, no credit card — runs on [Google Gemini's free API tier](https://aistudio.google.com/apikey).

Built with AutoHotkey v2 rather than a general-purpose scripting language, since it's
purpose-built for reliable global hotkeys and simulated keystrokes on Windows.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (free)
- A free [Google Gemini API key](https://aistudio.google.com/apikey)

## Setup

1. **Install AutoHotkey v2** — download from [autohotkey.com](https://www.autohotkey.com/),
   run the installer with default options.
2. **Get a free Gemini API key** — sign in at [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
   with any Google account, click **Create API key**. No credit card required.
3. **Run the script** — double-click `AI_Rewrite.ahk`.
4. A setup window will ask for your API key — paste it, click **Save & Start**.
5. The app minimizes to your system tray. No console window, no further setup.

## Usage

Select text in any application, then press:

| Hotkey | Action |
|---|---|
| `Ctrl+Alt+R` | Fix Grammar & Spelling |
| `Ctrl+Alt+I` | Improve Writing |
| `Ctrl+Alt+F` | Make Formal / Professional |
| `Ctrl+Alt+C` | Make Casual / Friendly |
| `Ctrl+Alt+S` | Make Shorter |

A small notification confirms each step (copying → sending → done), so you can see
exactly what's happening if something goes wrong.

## Updating your API key

Right-click the tray icon → **Update API Key**.

## Compiling to a standalone .exe

AutoHotkey scripts run directly without compilation, but if you'd prefer a single `.exe`:

1. Right-click `AI_Rewrite.ahk` → **Compile Script** (added automatically by the
   AutoHotkey installer)
2. This produces `AI_Rewrite.exe` in the same folder
3. Distribute or run that file directly — no `.ahk` or AutoHotkey installation needed
   on the machine running the compiled exe

## Running on startup

1. Press `Win+R`, type `shell:startup`, press Enter
2. Copy `AI_Rewrite.ahk` (or the compiled `.exe`) into the folder that opens
3. It now launches automatically on every login

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Nothing happens on hotkey press | Make sure text is actually selected (highlighted) before pressing the hotkey |
| "No text selected" every time | Confirm the target app is the focused window when you press the hotkey; try `Ctrl+A` first as a test |
| API error notification | Re-check your key via **Update API Key**; you may have hit Gemini's free daily limit (resets in 24h) |
| Hotkey doesn't work in a specific app | That app may be running as Administrator — right-click `AI_Rewrite.ahk`/`.exe` → **Run as administrator** (Windows blocks lower-privilege apps from sending keystrokes to elevated ones) |

## How it works

`Send("^c")` simulates a copy of your current selection, the clipboard contents are
sent to the Gemini API along with an instruction (e.g. "fix grammar"), and the response
replaces your clipboard before `Send("^v")` pastes it back in place. Your original
clipboard contents are restored afterward so nothing you had copied is lost.

No text is logged or stored anywhere — it goes directly from your clipboard to Google's
Gemini API over HTTPS and back.
