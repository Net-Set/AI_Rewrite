# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

AI Rewrite is a free, open-source Grammarly alternative. It has **three independent,
unbundled components** that share a pattern (send selected text + an instruction to an AI
provider, replace the text with the response) but have no shared code, build system, or
dependencies between them. All three support multiple AI providers — **Google Gemini**
(free tier, the easiest default), **OpenAI**, and **Anthropic Claude** — selectable
per-component; only one provider is "active" at a time per install, switchable without a
restart.

| Component | Language/runtime | Purpose |
|---|---|---|
| [`browser-extension/`](browser-extension) | Plain JS, Manifest V3 | Right-click-to-rewrite in any browser textbox |
| [`desktop-autohotkey/`](desktop-autohotkey) | AutoHotkey v2 | System-wide hotkey rewrite in any Windows app |
| [`git-commit-tool/`](git-commit-tool) | Python 3.8+ | AI-generated Conventional Commits messages |
| [`installer/`](installer) | AutoHotkey v2 + PyInstaller | Builds/bundles the desktop app + git tool into one Windows installer exe |

There is no root-level package manager, build tool, or test suite — each component is
developed and run independently, as described below.

## Commands

### Browser extension
No build step (plain HTML/CSS/JS, Manifest V3). To test changes:
```
chrome://extensions → Developer mode → Load unpacked → select browser-extension/
```
Reload the extension from `chrome://extensions` after every change (background service
worker and content script are not hot-reloaded).

### Desktop AutoHotkey app
Requires [AutoHotkey v2](https://www.autohotkey.com/) installed. No compile step needed
during development — edit `desktop-autohotkey/AI_Rewrite.ahk` and re-run it directly
(double-click, or `AutoHotkey64.exe AI_Rewrite.ahk`) to test.

### Git commit tool (Python)
```bash
cd git-commit-tool
pip install -r requirements.txt   # only dependency: requests
python ai_commit.py               # run against the current repo's staged changes
```
Provider/key selection: set `GEMINI_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` (and
optionally `AI_COMMIT_PROVIDER`) as env vars, or just run it — it prompts once and saves to
`~/.ai-commit/config.ini`.

There is no automated test suite for this component; verify manually by staging a change in
a scratch repo *outside this one* and running the script there — running it inside this repo
would stage/commit against the actual project history. `python -m py_compile ai_commit.py`
is a fast sanity check after editing.

### Installer
`installer/build.ps1` rebuilds all three distributable executables from source into
`installer/dist/`:
```powershell
installer/build.ps1
```
This requires PyInstaller (`pip install pyinstaller`) for `ai-commit.exe`, and AutoHotkey v2's
bundled `Ahk2Exe.exe` compiler (at `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`) for
`AI_Rewrite.exe` and `AI-Rewrite-Setup.exe`. It compiles `git-commit-tool/ai_commit.py` and
`desktop-autohotkey/AI_Rewrite.ahk` into standalone exes, then compiles
`installer/Installer.ahk` (which `FileInstall`-embeds those two exes) into the final setup exe.
Rerun this script after changing `ai_commit.py` or `AI_Rewrite.ahk` if you need the installer
artifacts to reflect those changes — editing the exes in `installer/dist/` directly is pointless,
they're build output.

## Architecture notes

**Common request pattern.** All three components independently implement broadly the same
call per provider: build a prompt as `{instruction}\n\nTEXT:\n{selectedText}` (or `DIFF:` for
the git tool), POST it to that provider's endpoint with the key in the provider's expected
auth header, and extract the response text from the provider-specific JSON shape:
  - **Gemini** — `POST .../v1beta/models/{model}:generateContent`, key in `x-goog-api-key`
    header, text at `candidates[0].content.parts[0].text`.
  - **OpenAI** — `POST https://api.openai.com/v1/chat/completions`, key in
    `Authorization: Bearer {key}`, text at `choices[0].message.content`.
  - **Anthropic** — `POST https://api.anthropic.com/v1/messages`, key in `x-api-key` +
    `anthropic-version` header (browser extension also sends
    `anthropic-dangerous-direct-browser-access: true`, required for direct-from-browser
    calls), text at `content[0].text`.

Each component has its own `call<Provider>()`-per-provider functions plus a dispatcher
(`callProvider`/`CallProvider`/`call_ai`) that picks one based on the user's active-provider
setting — there's no shared constants module, so a new provider or a changed response shape
must be updated in each component independently.

The five rewrite modes (Fix Grammar, Improve Writing, Make Formal, Make Casual, Make
Shorter) and their exact prompt strings are defined **three times** — once per component —
in [`browser-extension/background.js`](browser-extension/background.js) (`MODES` array),
[`desktop-autohotkey/AI_Rewrite.ahk`](desktop-autohotkey/AI_Rewrite.ahk) (hotkey bindings at
the bottom of the file), and implicitly via a different single instruction in
[`git-commit-tool/ai_commit.py`](git-commit-tool/ai_commit.py) (`COMMIT_INSTRUCTION`). When
changing a prompt or adding a mode, update it consistently across whichever files apply.

The browser extension and desktop app also support a **custom, user-typed instruction** at
rewrite time (in addition to the five fixed modes) — `Ctrl+Alt+A` / "Custom Instruction..."
on desktop, the "✍️ Custom Instruction..." context-menu item (via `window.prompt()`) in the
browser extension. The git commit tool has no equivalent since its instruction
(`COMMIT_INSTRUCTION`) isn't a per-run user choice.

**No server, no telemetry.** There is deliberately no backend: each client talks directly to
the chosen provider's endpoint over HTTPS using user-supplied API keys stored locally —
`chrome.storage.local` (browser extension; **not** `chrome.storage.sync`, specifically so
keys never transit Google's account-sync infrastructure), a local `config.ini` next to the
AHK script/exe (desktop), or `~/.ai-commit/config.ini` / `{PROVIDER}_API_KEY` env vars for
the Python tool (env-var keys are never written to disk). Don't introduce a relay/proxy
server or any analytics — it would break the "your key, your data" model the README and
CONTRIBUTING.md promise. All three components auto-migrate a pre-multi-provider config
(single Gemini key) to the new per-provider schema on first run after upgrading.

**Browser extension internals** ([`browser-extension/`](browser-extension)):
- `background.js` (MV3 service worker) owns the context menu, the migration from legacy
  sync storage, and the provider dispatch/fetch calls (with a hard per-request timeout via
  `AbortController`, since a stalled fetch would otherwise leave the page's "Rewriting…"
  toast stuck forever).
- `content.js` tracks the last non-collapsed selection via a `selectionchange` listener
  (needed because the DOM selection is lost once the browser context menu opens on some
  sites), and replaces it in place once `background.js` messages back a result — handling both
  plain `<input>`/`<textarea>` (via `selectionStart`/`selectionEnd`) and `contenteditable`
  ranges (via `Range`, plus a dispatched `input` event so React-based editors like Gmail/Docs
  notice the change, and a caret-repositioning step afterward). Falls back to a clipboard
  copy + toast if the original node was detached from the DOM by the time the API responds
  (e.g. an SPA re-render mid-request). `all_frames: true` in the manifest extends this to
  same-origin iframes (e.g. embedded compose widgets), not just the top frame.
- `popup.html`/`popup.js` is the settings UI (active provider + one key field per provider),
  backed by `chrome.storage.local`.

**Desktop AutoHotkey internals** ([`desktop-autohotkey/AI_Rewrite.ahk`](desktop-autohotkey/AI_Rewrite.ahk)):
Since AHK has no built-in JSON library, request bodies are built via the shared
`JsonEscape()` helper and responses are parsed by the shared `ExtractJsonString()` helper,
which locates the first `"<key>":"..."` occurrence and manually walks backslash-escape state
to find the true closing quote — there is no JSON parser here, so if a provider's response
shape changes, this hand-rolled extraction is the first thing to check. Text
selection/replacement works via simulated `Ctrl+C`/`Ctrl+V` (`Send("^c")` / `Send("^v")`)
rather than any accessibility API, since AHK's job here is to work identically across
arbitrary, unrelated Windows apps; the user's original clipboard contents are saved before
and restored after. All HTTP calls go through a shared `HttpPost()` helper
(`WinHttp.WinHttpRequest.5.1` COM object with explicit timeouts) so network failures produce
one consistent friendly error rather than a raw COM exception. Settings (active provider,
per-provider keys, "start with Windows") are all changeable live from the tray menu with no
restart needed — `ShowSettingsGui()`/`SaveSettings()` mutate the in-memory globals and
persist to `config.ini` in the same step.

**Git commit tool internals** ([`git-commit-tool/ai_commit.py`](git-commit-tool/ai_commit.py)):
Provider config lives in the `PROVIDERS` dict (label, default model, env var name, key URL)
and drives `get_provider()`/`get_api_key()`/`get_model()`, each checking (in order) an
explicit env var override, then `~/.ai-commit/config.ini`, then an interactive prompt —
`getpass.getpass()` for the key specifically, so it's never echoed to the terminal or left
in shell history. `config.ini` is written with `0o600` permissions where the OS supports it
(best-effort; a no-op on Windows). All `subprocess` calls go through a `run_git()` helper
that turns a missing git executable into a clean message instead of an uncaught
`FileNotFoundError`, and all three provider calls are wrapped to turn
`requests.exceptions.*` into friendly, specific messages (timeout / connection / other).

**Installer internals** ([`installer/Installer.ahk`](installer/Installer.ahk)): a single AHK
script serves as both installer and uninstaller, branching on an `/uninstall` CLI arg. It
embeds the prebuilt `dist/AI_Rewrite.exe` and `dist/ai-commit.exe` via `FileInstall` (so those
must exist in `installer/dist/` — produced by `build.ps1` — before compiling the installer
itself), writes a standard `HKCU\...\Uninstall` registry entry, optionally adds a Startup
shortcut and a user PATH entry, and copies itself into the install dir as `Uninstall.exe`. On
uninstall it hands cleanup of its own containing folder off to a detached `cmd /c rmdir` since
a running exe can't delete itself.

## Repo conventions

- **No new dependencies without discussion** — the project's whole value proposition is
  staying free/lightweight (see [CONTRIBUTING.md](CONTRIBUTING.md)). This applies across all
  three components, not just the Python one.
- Keep functions small and commented — the code is meant to be readable by non-experts
  trying to understand or modify their own writing tool, not just contributors.
- Security issues (e.g., a way an API key could leak) should not be fixed via a public PR
  with exploit details — see the "Reporting security issues" section of
  [CONTRIBUTING.md](CONTRIBUTING.md).
