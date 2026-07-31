# AI Rewrite — Free Grammarly Alternative (Powered by Google Gemini)

Select text on **any website** (Gmail, Google Docs, Twitter/X, LinkedIn, any textbox) →
right-click → **AI Rewrite** → pick a mode → the text is fixed/rewritten **in place**, automatically.

Runs on **Google Gemini's free API tier** — no credit card, no cost.

## Install (Chrome or Edge) — 2 minutes

1. Clone or download this repo (don't move/delete the `browser-extension` folder after loading — Chrome reads it live from disk).
2. Open `chrome://extensions` (or `edge://extensions` in Edge).
3. Turn on **Developer mode** (top-right toggle).
4. Click **Load unpacked** → select the `browser-extension` folder.
5. Click the new extension icon in your toolbar → paste your **free Gemini API key** → **Save**.
   - Get a key at https://aistudio.google.com/apikey — sign in with any Google account, click "Create API key". No credit card needed.

## Use it

1. Select any text in a text box, email, doc, or webpage.
2. Right-click → **AI Rewrite** →
   - ✏️ Fix Grammar & Spelling
   - ✨ Improve Writing
   - 👔 Make Formal / Professional
   - 😊 Make Casual / Friendly
   - ✂️ Make Shorter
3. Wait ~1-2 seconds — the selected text is replaced automatically.

## Notes / limits

- Works in normal `<textarea>`/`<input>` fields and in `contenteditable` areas (Gmail, Docs, most modern editors).
- **Does NOT work inside Notepad, Word desktop app, or other non-browser apps** — browser extensions can only see inside the browser. For true system-wide rewriting (Notepad, Word, any app), see [`desktop-autohotkey/`](../desktop-autohotkey) in this repo.
- Your API key is stored locally in Chrome's synced storage, never sent anywhere except directly to Google's Gemini API.
- Cost: **$0** — Gemini's free tier covers roughly 1,500 requests/day on Flash, far more than typical personal use.
