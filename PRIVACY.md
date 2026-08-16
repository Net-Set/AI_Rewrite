# Privacy Policy — AI Rewrite

_Last updated: 2026-08-16_

AI Rewrite ("the app," covering the browser extension, the desktop app, and the git
commit tool) is a free, open-source tool with **no backend server and no telemetry**.
This policy explains exactly what happens to your data because there genuinely isn't
much to explain.

## What data is processed

When you trigger a rewrite (or generate a commit message), the app sends:
- the text you selected (or, for the git tool, your staged diff), and
- the instruction for what to do with it (e.g. "fix grammar," or your own custom
  instruction)

directly from your device, over HTTPS, to the AI provider you configured — **Google
Gemini, OpenAI, or Anthropic Claude** — using an API key you supplied yourself. That's
the entire data flow.

## What we do NOT do

- We do not run a server. There is nothing between your device and the AI provider you
  chose — no relay, no proxy, no logging point owned by this project.
- We do not collect analytics, usage statistics, crash reports, or any telemetry.
- We do not see, store, or have access to your text, your API keys, or your usage in
  any form. There is no "our servers" for that data to reach.
- We do not require an account, sign-in, or any personal information to use the app.

## Where your API key is stored

Locally on your own device only:
- Browser extension: `chrome.storage.local` (never Chrome's account-synced storage, so
  it can't transit Google's sync infrastructure)
- Desktop app / git commit tool: a local `config.ini` file next to the app, or an
  environment variable you set yourself

Nothing here is ever transmitted anywhere except directly to the AI provider's API,
authenticated with your key, when you actively trigger a rewrite.

## Third-party processing

The text you submit for rewriting is processed by whichever AI provider you've
selected, under that provider's own privacy policy — not ours, since we never see the
data:
- Google Gemini: https://policies.google.com/privacy
- OpenAI: https://openai.com/policies/privacy-policy
- Anthropic: https://www.anthropic.com/legal/privacy

Review the relevant provider's policy for how they handle data you send to their API.

## Children's privacy

The app is not directed at children and does not knowingly collect data from anyone,
regardless of age — there is no data collection to speak of, as described above.

## Changes to this policy

Any changes will be published in this repository's commit history:
https://github.com/Net-Set/AI_Rewrite/commits/main/PRIVACY.md

## Contact

Questions about this policy: somilsomil25@gmail.com, or open an issue at
https://github.com/Net-Set/AI_Rewrite/issues
