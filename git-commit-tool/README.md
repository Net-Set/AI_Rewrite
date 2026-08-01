# AI Commit — AI-generated commit messages

Analyzes your **staged** git changes and suggests a [Conventional Commits](https://www.conventionalcommits.org/)
message — run it in place of `git commit -m "..."` when you want help writing the message.

Free, runs on [Google Gemini's free API tier](https://aistudio.google.com/apikey) — no
credit card, no cost.

## Requirements

- Python 3.8+
- Git
- A free [Gemini API key](https://aistudio.google.com/apikey)

## Setup

```bash
cd git-commit-tool
pip install -r requirements.txt
```

Set your API key **once**, either way works:

**Option A — environment variable** (recommended, works across all your repos):
```bash
# macOS/Linux — add to ~/.bashrc or ~/.zshrc
export GEMINI_API_KEY="your-key-here"

# Windows (PowerShell) — add to your profile
setx GEMINI_API_KEY "your-key-here"
```

**Option B — let the script ask you the first time.** It'll save the key to
`~/.ai-commit/config.ini` so you're only asked once.

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

Analyzing diff and generating commit message...

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
- **r** → ask Gemini to try again (useful if the first attempt misses the point)
- **q** → cancel, nothing is committed

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
2. Sends that diff (trimmed to ~12,000 characters if very large) to Gemini with
   instructions to follow the Conventional Commits format
3. Shows you the suggestion — nothing is committed until you confirm

Your diff is sent directly to Google's Gemini API over HTTPS and nowhere else. If your
diff contains secrets you haven't caught yet, review the suggestion carefully before
committing — this tool doesn't scan for secrets, it only writes the message.

## Notes

- Only looks at **staged** changes (`git add`ed) — matches how `git commit` itself works.
- Very large diffs are truncated to keep requests fast; for huge changesets, consider
  splitting into smaller commits (usually good practice anyway).
- This tool never commits without your explicit confirmation — pressing Enter, or
  typing `e`/`r`/`q` — a plain run always stops and waits for your input first.
