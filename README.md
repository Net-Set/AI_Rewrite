<div align="center">

# ✨ AI Rewrite

**A free, open-source Grammarly alternative — bring your own AI.**

Fix grammar, rewrite tone, and polish your writing anywhere: in your browser, in Notepad, in WhatsApp, in Word — anywhere you can select text. Works with **Google Gemini** (free), **OpenAI**, or **Anthropic Claude** — your choice.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Chrome%20%7C%20Edge-blue)](#)
[![Cost](https://img.shields.io/badge/cost-%240%20with%20Gemini-brightgreen)](#)
[![Latest release](https://img.shields.io/github/v/release/Net-Set/AI_Rewrite?label=download)](https://github.com/Net-Set/AI_Rewrite/releases/latest)

</div>

---

## Download (Windows, no setup required)

Don't want to clone the repo or install AutoHotkey/Python yourself? Grab the prebuilt
installer from the **[latest release](https://github.com/Net-Set/AI_Rewrite/releases/latest)**:

- **`AI-Rewrite-Setup.exe`** — installs both the desktop app and the git commit tool,
  with Start Menu shortcuts, an optional startup entry, and an uninstaller. Recommended
  for most Windows users.
- **`AI_Rewrite.exe`** — the desktop rewrite tool by itself, no installer, just run it.
- **`ai-commit.exe`** — the git commit tool by itself, no installer, no Python required.

These are the same source you see in this repo, compiled via
[`installer/build.ps1`](./installer/build.ps1) — nothing hidden. If you'd rather build
them yourself (or verify that), see that script and the per-component READMEs linked
below. The browser extension isn't distributed as a download — it's loaded directly from
source (see Option A below), since that's how unpacked Chrome/Edge extensions work.

## Why this exists

Grammarly is great, but it's a subscription product with a paid tier gating most useful
features. **AI Rewrite** does the same core job — select text, get it corrected or
rewritten — for **$0**, using [Google Gemini's free API tier](https://aistudio.google.com/apikey)
(no credit card required). If you'd rather use a model you already pay for, OpenAI and
Anthropic Claude are supported too — swap providers anytime, no code changes needed.

There are three independent components in this repo — install whichever you need:

| | [`browser-extension/`](./browser-extension) | [`desktop-autohotkey/`](./desktop-autohotkey) | [`git-commit-tool/`](./git-commit-tool) |
|---|---|---|---|
| **Does** | Rewrites selected text in the page | Rewrites selected text in any app | Writes your git commit messages |
| **Works in** | Any website (Gmail, Docs, Twitter, LinkedIn) | **Any** Windows app (Notepad, Word, WhatsApp, Discord, browsers) | Any git repo, from the terminal |
| **How you trigger it** | Right-click selected text | Global hotkey (`Ctrl+Alt+R`, etc.) | Run `ai-commit` in place of `git commit` |
| **Install** | Load unpacked in Chrome/Edge | Install AutoHotkey v2, run the script | `pip install -r requirements.txt` |

Prefer a one-click Windows setup for the desktop app + git tool together? See
[`installer/`](./installer) — `installer/build.ps1` produces a single `AI-Rewrite-Setup.exe`.

## Features

- ✏️ **Fix Grammar & Spelling** — corrects errors, keeps your voice
- ✨ **Improve Writing** — clarity and flow, same meaning
- 👔 **Make Formal** — professional tone for work
- 😊 **Make Casual** — friendly, conversational tone
- ✂️ **Make Shorter** — trims to the essential point
- ✍️ **Custom instruction** — type your own request instead ("translate to Spanish", "turn into bullet points," anything)
- 🔀 **Bring your own AI** — Google Gemini, OpenAI, or Anthropic Claude; switch anytime, no restart needed
- 🆓 **$0 cost with Gemini** — its free tier covers ~1,500 requests/day, no credit card required
- 🔒 **Your key, your data** — API keys stay on your machine, sent only to the provider you chose, never through a server of ours

## Quick start

### Option A — Browser extension (Chrome / Edge)

```
1. Get a free key: https://aistudio.google.com/apikey
2. chrome://extensions → enable Developer mode → Load unpacked → select browser-extension/
3. Click the extension icon → choose a provider → paste your key → Save
4. Select text on any page → right-click → AI Rewrite
```

Full instructions: [`browser-extension/README.md`](./browser-extension/README.md)

### Option B — Desktop app (Windows, works in any app)

```
1. Install AutoHotkey v2: https://www.autohotkey.com/
2. Get a free key: https://aistudio.google.com/apikey
3. Double-click desktop-autohotkey/AI_Rewrite.ahk
4. Pick a provider and paste your key in the setup window → Save
5. Select text anywhere → press Ctrl+Alt+R
```

Full instructions: [`desktop-autohotkey/README.md`](./desktop-autohotkey/README.md)

### Option C — AI commit messages (any OS with Python)

```
1. cd git-commit-tool && pip install -r requirements.txt
2. git add <files>
3. python ai_commit.py
```

Full instructions: [`git-commit-tool/README.md`](./git-commit-tool/README.md)

## Hotkeys / menu options (browser + desktop)

| Action | Browser (right-click menu) | Desktop (hotkey) |
|---|---|---|
| Fix Grammar & Spelling | ✏️ Fix Grammar & Spelling | `Ctrl+Alt+R` |
| Improve Writing | ✨ Improve Writing | `Ctrl+Alt+I` |
| Make Formal | 👔 Make Formal / Professional | `Ctrl+Alt+F` |
| Make Casual | 😊 Make Casual / Friendly | `Ctrl+Alt+C` |
| Make Shorter | ✂️ Make Shorter | `Ctrl+Alt+S` |
| Custom instruction | ✍️ Custom Instruction... | `Ctrl+Alt+A` |

## How it works

Both rewrite tools follow the same simple flow:

1. You select text and trigger the tool (right-click or hotkey)
2. The tool copies your selection
3. It sends the text + an instruction (e.g. "fix grammar," or whatever you typed for a
   custom instruction) to your chosen provider's API
4. The corrected text comes back and replaces your original selection

No text is stored, logged, or sent anywhere except directly to the provider you selected,
over HTTPS. There is no backend server run by this project — every request goes straight
from your machine to Google's, OpenAI's, or Anthropic's API.

## FAQ

**Is this really free?**
With Google Gemini, yes — its free tier covers generous daily usage (~1,500 requests/day
on Flash models) with no credit card required. OpenAI and Anthropic are optional
alternatives if you already have a paid account with them; they're billed by that provider
directly, not by this project (which never touches your money either way).

**Why isn't there a right-click menu in the desktop version?**
Windows doesn't allow third-party apps to add entries into other apps' native
right-click menus (Notepad's, Word's, etc.) — that's an OS-level restriction, not a
limitation of this tool. A global hotkey is the standard, reliable workaround.

**Does this work on Mac or Linux?**
The browser extension works on any OS Chrome/Edge supports. The desktop app currently
targets Windows only (AutoHotkey is Windows-native). A Mac version would need a
different toolchain (e.g. Hammerspoon) — contributions welcome.

**Is my API key safe?**
It's stored locally on your machine only — `chrome.storage.local` for the browser
extension (never Chrome's account-synced storage), or a local `config.ini` for the desktop
app and git commit tool — and only ever sent directly to the provider you chose
(Google, OpenAI, or Anthropic). It never passes through any server of ours — there is no
"ours," this is a fully client-side tool.

**Can I use more than one provider at once?**
Not simultaneously per request, but you can add keys for all three and switch which one is
"active" anytime (tray menu on desktop, extension popup in the browser) — changes apply
immediately, no restart required.

## Roadmap / ideas

- [ ] Firefox support for the browser extension
- [ ] macOS desktop version
- [ ] Additional providers (e.g. Groq, OpenRouter — both offer free tiers)
- [ ] Inline diff preview before replacing text

Contributions and PRs welcome — see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## License

MIT © [Somil Merugawar](https://github.com/) — see [`LICENSE`](./LICENSE) for details.
