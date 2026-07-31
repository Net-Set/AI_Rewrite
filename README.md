<div align="center">

# ✨ AI Rewrite

**A free, open-source Grammarly alternative — powered by Google Gemini.**

Fix grammar, rewrite tone, and polish your writing anywhere: in your browser, in Notepad, in WhatsApp, in Word — anywhere you can select text.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Chrome%20%7C%20Edge-blue)](#)
[![Cost](https://img.shields.io/badge/cost-%240%20forever-brightgreen)](#)

</div>

---

## Why this exists

Grammarly is great, but it's a subscription product with a paid tier gating most useful
features. **AI Rewrite** does the same core job — select text, get it corrected or
rewritten — for **$0**, using [Google Gemini's free API tier](https://aistudio.google.com/apikey)
(no credit card required).

There are two independent components in this repo — install either, or both:

| | [`browser-extension/`](./browser-extension) | [`desktop-autohotkey/`](./desktop-autohotkey) |
|---|---|---|
| **Works in** | Any website (Gmail, Docs, Twitter, LinkedIn) | **Any** Windows app (Notepad, Word, WhatsApp, Discord, browsers) |
| **How you trigger it** | Right-click selected text | Global hotkey (`Ctrl+Alt+R`, etc.) |
| **Install** | Load unpacked in Chrome/Edge | Install AutoHotkey v2, run the script |
| **Best for** | Browser-only workflows | System-wide use |

## Features

- ✏️ **Fix Grammar & Spelling** — corrects errors, keeps your voice
- ✨ **Improve Writing** — clarity and flow, same meaning
- 👔 **Make Formal** — professional tone for work
- 😊 **Make Casual** — friendly, conversational tone
- ✂️ **Make Shorter** — trims to the essential point
- 🆓 **$0 cost** — runs on Gemini's free tier (~1,500 requests/day)
- 🔒 **Your key, your data** — API key stored locally, never sent anywhere but Google's API

## Quick start

### Option A — Browser extension (Chrome / Edge)

```
1. Get a free key: https://aistudio.google.com/apikey
2. chrome://extensions → enable Developer mode → Load unpacked → select browser-extension/
3. Click the extension icon → paste your key → Save
4. Select text on any page → right-click → AI Rewrite
```

Full instructions: [`browser-extension/README.md`](./browser-extension/README.md)

### Option B — Desktop app (Windows, works in any app)

```
1. Install AutoHotkey v2: https://www.autohotkey.com/
2. Get a free key: https://aistudio.google.com/apikey
3. Double-click desktop-autohotkey/AI_Rewrite.ahk
4. Paste your key in the popup → Save & Start
5. Select text anywhere → press Ctrl+Alt+R
```

Full instructions: [`desktop-autohotkey/README.md`](./desktop-autohotkey/README.md)

## Hotkeys / menu options (both versions)

| Action | Browser (right-click menu) | Desktop (hotkey) |
|---|---|---|
| Fix Grammar & Spelling | ✏️ Fix Grammar & Spelling | `Ctrl+Alt+R` |
| Improve Writing | ✨ Improve Writing | `Ctrl+Alt+I` |
| Make Formal | 👔 Make Formal / Professional | `Ctrl+Alt+F` |
| Make Casual | 😊 Make Casual / Friendly | `Ctrl+Alt+C` |
| Make Shorter | ✂️ Make Shorter | `Ctrl+Alt+S` |

## How it works

Both tools follow the same simple flow:

1. You select text and trigger the tool (right-click or hotkey)
2. The tool copies your selection
3. It sends the text + an instruction (e.g. "fix grammar") to the **Gemini API**
4. The corrected text comes back and replaces your original selection

No text is stored, logged, or sent anywhere except directly to Google's Gemini API over HTTPS.

## FAQ

**Is this really free?**
Yes. Google's Gemini API free tier covers generous daily usage (~1,500 requests/day on
Flash models) with no credit card required. You provide your own key.

**Why isn't there a right-click menu in the desktop version?**
Windows doesn't allow third-party apps to add entries into other apps' native
right-click menus (Notepad's, Word's, etc.) — that's an OS-level restriction, not a
limitation of this tool. A global hotkey is the standard, reliable workaround.

**Does this work on Mac or Linux?**
The browser extension works on any OS Chrome/Edge supports. The desktop app currently
targets Windows only (AutoHotkey is Windows-native). A Mac version would need a
different toolchain (e.g. Hammerspoon) — contributions welcome.

**Is my API key safe?**
It's stored locally on your machine (in Chrome's synced storage, or a local
`config.ini` for the desktop app) and only ever sent to `generativelanguage.googleapis.com`.
It never passes through any server of ours — there is no "ours," this is a fully
client-side tool.

## Roadmap / ideas

- [ ] Firefox support for the browser extension
- [ ] macOS desktop version
- [ ] Custom user-defined rewrite modes
- [ ] Inline diff preview before replacing text

Contributions and PRs welcome — see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## License

MIT © [Somil Merugawar](https://github.com/) — see [`LICENSE`](./LICENSE) for details.
