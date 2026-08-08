# AI Rewrite — Desktop (AutoHotkey v2)

Works **system-wide** on Windows: Notepad, WhatsApp Desktop, Word, Outlook, Telegram,
Discord, browsers — anywhere you can select and paste text.

Free to run — works with [Google Gemini's free API tier](https://aistudio.google.com/apikey),
and can optionally use OpenAI or Anthropic Claude instead if you'd rather bring your own key
for those.

Built with AutoHotkey v2 rather than a general-purpose scripting language, since it's
purpose-built for reliable global hotkeys and simulated keystrokes on Windows.

## Features

- **System-wide** — works identically in any Windows app via simulated copy/paste, not
  limited to the browser
- **Five built-in rewrite modes** — Fix Grammar, Improve Writing, Make Formal, Make
  Casual, Make Shorter — each on its own hotkey
- **Custom instructions** — type any request instead of using a fixed mode
  (`Ctrl+Alt+A`)
- **Three AI providers** — Google Gemini (free), OpenAI, or Anthropic Claude; switch
  anytime with no restart
- **Starts with Windows** — enabled by default on first run, toggle anytime from the
  tray menu
- **No server, no telemetry** — talks directly to your chosen provider's API over HTTPS

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (free)
- An API key for at least one supported provider — a free
  [Google Gemini API key](https://aistudio.google.com/apikey) is the easiest to get started
  with; [OpenAI](https://platform.openai.com/api-keys) and
  [Anthropic Claude](https://console.anthropic.com/) keys are also supported (paid).

## Setup

1. **Install AutoHotkey v2** — download from [autohotkey.com](https://www.autohotkey.com/),
   run the installer with default options.
2. **Get an API key** — for the free option, sign in at
   [aistudio.google.com/apikey](https://aistudio.google.com/apikey) with any Google account,
   click **Create API key**. No credit card required.
3. **Run the script** — double-click `AI_Rewrite.ahk`.
4. A setup window asks you to pick a provider and paste its key — fill in the one(s) you
   have, click **Save**.
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
| `Ctrl+Alt+A` | **Custom instruction** — opens a small popup, type any instruction (e.g. *"translate to Spanish"*, *"make it sound like a pirate"*, *"turn into bullet points"*), click **Apply** |

A small notification confirms each step (copying → sending → done), so you can see
exactly what's happening if something goes wrong.

## Choosing an AI provider

AI Rewrite supports three providers — **Google Gemini**, **OpenAI**, and **Anthropic
Claude**. Only one is "active" at a time; that's the one the hotkeys use. Right-click the
tray icon → **AI Provider & Keys...** to:

- switch the active provider,
- add or update the API key for any of the three,
- see the currently active provider at the top of the tray menu (e.g. *"AI Rewrite —
  running (Google Gemini)"*).

Changes apply **immediately** — no restart required. You only need a key for the provider
you actually use; the others can be left blank. To override the default model for a
provider (e.g. use a different Gemini or GPT model), edit `config.ini` next to the script/exe
and set `gemini_model`, `openai_model`, or `anthropic_model` under `[settings]`.

## Compiling to a standalone .exe

**Recommended: use the build script** — see [`installer/build.ps1`](../installer/build.ps1),
which compiles this script (plus the git commit tool) into `installer/dist/AI_Rewrite.exe`
and bundles both into a single `AI-Rewrite-Setup.exe`, with no prompts:
```powershell
installer/build.ps1
```
Because provider/key changes apply live via the tray menu (see above), you only need to
re-run the build — and reinstall/replace the exe — when the `.ahk` **code** itself changes,
not for everyday settings changes.

**Alternative: right-click → Compile Script.** AutoHotkey scripts run directly without
compilation, but if you'd rather compile ad hoc:

1. Right-click `AI_Rewrite.ahk` → **Compile Script** (added automatically by the
   AutoHotkey installer)
2. This produces `AI_Rewrite.exe` in the same folder
3. Distribute or run that file directly — no `.ahk` or AutoHotkey installation needed
   on the machine running the compiled exe

> **First time only:** if you see *"Ahk2Exe Error — No default Base file specified"*, the
> compiler doesn't yet know which AutoHotkey interpreter to embed. Open
> `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe` directly, set **Base File** to
> `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`, and click **Save**. Right-click →
> Compile Script will then work without prompting. (`installer/build.ps1` above sidesteps
> this entirely by passing the base file explicitly every time.)

## Running on startup

On first run, AI Rewrite automatically adds itself to Windows startup (same as the
installer's default) — after a reboot or logout/login, it's running again with no manual
relaunch needed. To check or change this later:

- Right-click the tray icon → **Start with Windows** to toggle it on/off (a checkmark
  shows the current state). Takes effect immediately, no restart required.

If you'd rather do it manually instead:

1. Press `Win+R`, type `shell:startup`, press Enter
2. Copy `AI_Rewrite.ahk` (or the compiled `.exe`) into the folder that opens
3. It now launches automatically on every login

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Nothing happens on hotkey press | Make sure text is actually selected (highlighted) before pressing the hotkey |
| "No text selected" every time | Confirm the target app is the focused window when you press the hotkey; try `Ctrl+A` first as a test |
| API error notification | Re-check your key via **AI Provider & Keys...**; you may have hit that provider's rate/quota limit, or a key rejected with HTTP 401/403 is wrong or expired |
| Hotkey doesn't work in a specific app | That app may be running as Administrator — right-click `AI_Rewrite.ahk`/`.exe` → **Run as administrator** (Windows blocks lower-privilege apps from sending keystrokes to elevated ones) |
| Custom instruction (`Ctrl+Alt+A`) pastes into the wrong window | The popup steals focus from your original app; the script reactivates it automatically before pasting, but very slow-to-refocus apps may occasionally need a manual click back into them first |
| You updated/rebuilt the app but still see old behavior or an old error message | AutoHotkey doesn't hot-reload — an already-running instance keeps executing the code it started with. Right-click the tray icon → **Reload (apply an update)** (or Quit and relaunch) to pick up any change to the script/exe on disk |

## How it works

`Send("^c")` simulates a copy of your current selection, the clipboard contents are sent
to the active provider's API (Gemini, OpenAI, or Anthropic) along with an instruction (a
fixed one for the five mode hotkeys, or whatever you type for `Ctrl+Alt+A`), and the
response replaces your clipboard before `Send("^v")` pastes it back in place. Your original
clipboard contents are restored afterward so nothing you had copied is lost.

No text is logged or stored anywhere — it goes directly from your clipboard to the selected
provider's API over HTTPS and back. Since AutoHotkey has no built-in JSON library, requests
and responses are built/parsed by hand-rolled string logic (see `JsonEscape`/
`ExtractJsonString` in the script) rather than a JSON library — if a provider ever changes
its response shape, that's the first place to check.

## Privacy & security

- API keys are stored in a local `config.ini` next to the script/exe — never sent
  anywhere except directly to the provider you chose, over HTTPS.
- `config.ini` is automatically restricted to the current Windows user (via `icacls`)
  every time settings are saved, since it holds plaintext keys — relevant if the machine
  is shared with other accounts.
- No telemetry, no analytics, no relay server — this app talks directly to
  Gemini/OpenAI/Anthropic's own API endpoints and nothing else.
- Your system clipboard is used transiently to move text in and out of the target app
  (the same mechanism any copy/paste action uses); your original clipboard contents are
  restored immediately after each rewrite.
- If you're upgrading from a version before multi-provider support, your existing single
  Gemini key is migrated automatically to the new config format the first time the app
  runs — no action needed.
