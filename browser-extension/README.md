# AI Rewrite — Free Grammarly Alternative

Select text on **any website** (Gmail, Google Docs, Twitter/X, LinkedIn, any textbox) →
right-click → **AI Rewrite** → pick a mode → the text is fixed/rewritten **in place**, automatically.

Supports **Google Gemini** (free tier, no credit card), **OpenAI**, and **Anthropic
Claude** — pick whichever provider you have a key for. You can also type a fully custom
instruction instead of using one of the five built-in modes.

## Install (Chrome or Edge) — 2 minutes

1. Clone or download this repo (don't move/delete the `browser-extension` folder after loading — Chrome reads it live from disk).
2. Open `chrome://extensions` (or `edge://extensions` in Edge).
3. Turn on **Developer mode** (top-right toggle).
4. Click **Load unpacked** → select the `browser-extension` folder.
5. Click the new extension icon in your toolbar → pick a provider → paste its API key → **Save**.
   - Easiest to start with: a **free** Gemini key at https://aistudio.google.com/apikey —
     sign in with any Google account, click "Create API key". No credit card needed.
   - OpenAI keys: https://platform.openai.com/api-keys (paid)
   - Anthropic keys: https://console.anthropic.com/ (paid)

## Use it

1. Select any text in a text box, email, doc, or webpage.
2. Right-click → **AI Rewrite** →
   - ✏️ Fix Grammar & Spelling
   - ✨ Improve Writing
   - 👔 Make Formal / Professional
   - 😊 Make Casual / Friendly
   - ✂️ Make Shorter
   - ✍️ **Custom Instruction...** — type any instruction (e.g. *"translate to French"*,
     *"make this sound like a pirate"*, *"turn into bullet points"*) in the popup that
     appears, then press Enter/OK
3. Wait ~1-2 seconds — the selected text is replaced automatically.

## Switching providers or updating keys

Click the extension icon anytime → change the **Active provider** dropdown and/or the
key fields → **Save**. Takes effect on your very next rewrite — no reload needed. Only the
active provider needs a key filled in; leave the others blank.

## Notes / limits

- Works in normal `<textarea>`/`<input>` fields and in `contenteditable` areas (Gmail,
  Docs, most modern editors), including same-origin iframes (e.g. embedded compose
  widgets).
- **Does NOT work inside Notepad, Word desktop app, or other non-browser apps** — browser extensions can only see inside the browser. For true system-wide rewriting (Notepad, Word, any app), see [`desktop-autohotkey/`](../desktop-autohotkey) in this repo.
- Selections over 50,000 characters are rejected with a clear message rather than sent to
  the API (avoids slow, likely-to-fail requests on accidental whole-page selections).
- If a request errors out (bad key, rate limit, network issue, timeout) you'll see a red
  toast explaining what happened — your original text is left untouched.
- Cost: **$0** on Gemini's free tier (roughly 1,500 requests/day on Flash, far more than
  typical personal use). OpenAI/Anthropic are billed per their own pricing if you choose
  to use those instead.

## Privacy & security

- API keys are stored in `chrome.storage.local` — **local to this browser profile only**,
  never synced through Google's account-sync infrastructure, never sent anywhere except
  directly to the provider you choose, over HTTPS.
- No telemetry, no analytics, no relay server — this extension talks directly to
  Gemini/OpenAI/Anthropic's own API endpoints.
- If you're upgrading from a version before 1.1.0, your existing Gemini key is migrated
  automatically from the old synced storage to local storage the first time the extension
  runs, and removed from sync storage afterward.
