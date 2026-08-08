# AI Commit — AI-generated commit messages

Analyzes your **staged** git changes and suggests a [Conventional Commits](https://www.conventionalcommits.org/)
message — run it in place of `git commit -m "..."` when you want help writing the message.

Supports **Google Gemini** (free tier, no credit card), **OpenAI**, and **Anthropic
Claude** — pick whichever provider you have a key for.

## Requirements

- Python 3.8+
- Git
- An API key for at least one supported provider — a free
  [Gemini API key](https://aistudio.google.com/apikey) is the easiest to get started with;
  [OpenAI](https://platform.openai.com/api-keys) and
  [Anthropic Claude](https://console.anthropic.com/) keys are also supported (paid).

## Setup

```bash
cd git-commit-tool
pip install -r requirements.txt
```

Set your API key **once**, either way works:

**Option A — environment variable** (recommended, works across all your repos, and is
never written to disk by this tool):
```bash
# macOS/Linux — add to ~/.bashrc or ~/.zshrc
export GEMINI_API_KEY="your-key-here"      # or OPENAI_API_KEY / ANTHROPIC_API_KEY

# Windows (PowerShell) — add to your profile
setx GEMINI_API_KEY "your-key-here"
```
Optionally also set `AI_COMMIT_PROVIDER` (`gemini` / `openai` / `anthropic`) to pick which
provider to use without being asked or editing the config file.

**Option B — let the script ask you the first time.** It'll ask which provider to use, then
prompt for that provider's key (input is hidden as you type) and save both to
`~/.ai-commit/config.ini`, so you're only asked once. That file is created with
owner-only permissions where the OS supports it (macOS/Linux); on Windows, keep the
usual precautions around who has access to your user profile.

## Usage

```bash
git add <files>
python ai_commit.py
```

You'll see the changed files, then a suggested commit message:

```
Staged changes:
 math_utils.py | 6 ++++++
 1 file changed, 6 insertions(+)

Analyzing diff with Google Gemini (gemini-3.1-flash-lite)...

------------------------------------------------------------
Suggested commit message:
------------------------------------------------------------
feat(math_utils): add subtract and multiply functions

- Extends existing add() with subtract() and multiply()
- No changes to existing function signatures
------------------------------------------------------------

[Enter] commit as-is   [e] edit   [r] regenerate   [q] cancel:
```

- **Enter** → commits immediately with the suggested message
- **e** → edit the message yourself before committing
- **r** → ask the AI to try again (useful if the first attempt misses the point)
- **q** → cancel, nothing is committed

If nothing is staged when you run it, it'll offer to `git add -A` everything first — same
as most AI commit tools — but it never commits without you explicitly confirming.

## Switching providers or updating a key later

Edit `~/.ai-commit/config.ini` directly (it's a plain INI file — `provider`,
`gemini_api_key`, `openai_api_key`, `anthropic_api_key`, and optional
`gemini_model`/`openai_model`/`anthropic_model` overrides all live under `[settings]`), or
just delete the `*_api_key` line for the provider you want to re-enter and run the tool
again — it'll prompt you for a fresh one.

## Making it a shorter command (optional)

### macOS/Linux — add an alias
```bash
# in ~/.bashrc or ~/.zshrc
alias ai-commit="python /path/to/git-commit-tool/ai_commit.py"
```
Then just run `ai-commit` from any git repo.

### Windows — add to PATH or create a wrapper
Create a file `ai-commit.bat` somewhere on your PATH containing:
```bat
@echo off
python "C:\path\to\git-commit-tool\ai_commit.py" %*
```

## How it works

1. Runs `git diff --staged` to get exactly what you're about to commit
2. Sends that diff (trimmed to ~12,000 characters if very large) to your chosen provider
   with instructions to follow the Conventional Commits format
3. Shows you the suggestion — nothing is committed until you confirm

Your diff is sent directly to the provider's own API over HTTPS and nowhere else — there's
no relay server. If your diff contains secrets you haven't caught yet, review the
suggestion carefully before committing — this tool doesn't scan for secrets, it only
writes the message.

## Notes / production edge cases handled

- Only looks at **staged** changes (`git add`ed) — matches how `git commit` itself works.
- Very large diffs are truncated to keep requests fast; for huge changesets, consider
  splitting into smaller commits (usually good practice anyway).
- This tool never commits without your explicit confirmation — pressing Enter, or
  typing `e`/`r`/`q` — a plain run always stops and waits for your input first.
- Git not installed / not on PATH, running outside a git repo, and a corrupted
  `config.ini` are all caught with a clear message instead of a raw traceback.
- Network failures (no connection, timeout, DNS failure) and API errors (bad key, rate
  limit, provider outage) are reported with a specific, actionable message rather than a
  stack trace.
- Non-interactive stdin (e.g. piped input, CI) is handled gracefully — the tool exits
  cleanly instead of hanging or crashing on EOF.
- The `requests` package missing produces a clear "run `pip install`" message instead of
  an `ImportError` traceback.
