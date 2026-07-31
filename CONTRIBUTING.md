# Contributing to AI Rewrite

Thanks for considering a contribution — this is a small personal-tool-turned-open-source
project, so contributions of any size are welcome.

## Ways to help

- **Bug reports** — open an issue with steps to reproduce, your OS/browser version, and
  any error messages (screenshots welcome).
- **Feature requests** — check the Roadmap in the main [README](./README.md) first;
  open an issue to discuss before building something large.
- **Pull requests** — small, focused PRs are easiest to review. For anything big
  (new platform support, major refactors), please open an issue first to discuss the approach.

## Development setup

### Browser extension
No build step — it's plain HTML/CSS/JS. Load `browser-extension/` as an unpacked
extension in `chrome://extensions` (Developer mode → Load unpacked) and reload the
extension after each change.

### Desktop (AutoHotkey)
Install [AutoHotkey v2](https://www.autohotkey.com/), edit `desktop-autohotkey/AI_Rewrite.ahk`
directly, and re-run the script to test changes. No compilation needed during development.

## Code style

- Keep functions small and commented — this codebase is meant to be readable by
  non-experts who want to understand or modify how their own writing tool works.
- No new dependencies without discussion — part of the point of this project is staying
  lightweight and free of paid services.

## Reporting security issues

If you find a security issue (e.g. a way the API key could leak), please open an issue
marked `security` rather than a public PR with the exploit details, so it can be fixed
before being made public.
