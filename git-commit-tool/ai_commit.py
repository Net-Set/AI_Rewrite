#!/usr/bin/env python3
"""
ai-commit — suggests a Conventional Commits message based on your staged changes.

Usage:
    git add <files>
    python ai_commit.py
    (review the suggestion, confirm to commit, edit, or cancel)

Setup:
    pip install requests
    Set your Gemini API key once via the GEMINI_API_KEY environment variable,
    or in a config file at ~/.ai-commit/config.ini (created automatically on first run).
"""

import subprocess
import sys
import os
import configparser
import requests

CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".ai-commit")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.ini")

MODEL = "gemini-3.1-flash-lite"

COMMIT_INSTRUCTION = """You are an expert software engineer writing a git commit message.
Analyze the following staged diff and write a single Conventional Commits message.

Rules:
- Format: <type>(<optional scope>): <short summary>
- Allowed types: feat, fix, docs, style, refactor, perf, test, chore, build, ci
- Summary line: imperative mood, under 72 characters, no trailing period
- If the change is non-trivial, add a blank line then 1-3 bullet points explaining WHAT changed and WHY
- Do NOT include the diff itself, markdown code fences, or any preamble/explanation
- Return ONLY the commit message text, nothing else
"""


def get_config():
    config = configparser.ConfigParser()
    if os.path.exists(CONFIG_FILE):
        config.read(CONFIG_FILE)
    if "settings" not in config:
        config["settings"] = {}
    return config


def save_config(config):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        config.write(f)


def get_api_key():
    # Priority: environment variable > config file > prompt
    env_key = os.environ.get("GEMINI_API_KEY")
    if env_key:
        return env_key

    config = get_config()
    key = config["settings"].get("api_key", "")
    if key:
        return key

    print("No Gemini API key found.")
    print("Get a free one at: https://aistudio.google.com/apikey")
    key = input("Paste your Gemini API key: ").strip()
    if not key:
        print("No key provided. Exiting.")
        sys.exit(1)

    config["settings"]["api_key"] = key
    save_config(config)
    return key


def get_staged_diff():
    result = subprocess.run(
        ["git", "diff", "--staged"],
        capture_output=True, text=True,
        encoding="utf-8", errors="replace"
    )
    if result.returncode != 0:
        print("Error running git diff — are you inside a git repository?")
        print(result.stderr)
        sys.exit(1)
    return result.stdout


def get_staged_file_summary():
    result = subprocess.run(
        ["git", "diff", "--staged", "--stat"],
        capture_output=True, text=True,
        encoding="utf-8", errors="replace"
    )
    return result.stdout.strip()


def call_gemini(api_key, diff_text):
    # Guard against extremely large diffs — trim to keep the request fast and cheap
    max_chars = 12000
    truncated = len(diff_text) > max_chars
    diff_for_prompt = diff_text[:max_chars]

    prompt = COMMIT_INSTRUCTION
    if truncated:
        prompt += "\n(Note: diff was truncated for length — base the message on what's shown.)\n"

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    headers = {"Content-Type": "application/json", "x-goog-api-key": api_key}
    body = {
        "contents": [
            {"role": "user", "parts": [{"text": f"{prompt}\n\nDIFF:\n{diff_for_prompt}"}]}
        ]
    }

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    if not resp.ok:
        raise RuntimeError(f"API error {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError):
        raise RuntimeError("No text returned from API.")


def has_any_changes():
    """Check if there's anything at all to work with — staged, unstaged, or untracked."""
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True, text=True,
        encoding="utf-8", errors="replace"
    )
    return bool(result.stdout and result.stdout.strip())


def stage_everything():
    result = subprocess.run(["git", "add", "-A"])
    return result.returncode == 0


def do_commit(message):
    result = subprocess.run(["git", "commit", "-m", message])
    return result.returncode == 0


def main():
    diff = get_staged_diff()
    if diff is None:
        print("Error: could not read git diff output. Is git installed and on your PATH?")
        sys.exit(1)

    if not diff.strip():
        # Nothing staged yet — auto-stage everything if there's anything to stage
        if not has_any_changes():
            print("No changes found — working tree is clean.")
            sys.exit(0)
        print("Nothing staged yet — staging all changes automatically (git add -A)...")
        if not stage_everything():
            print("Error: 'git add -A' failed — check git output above.")
            sys.exit(1)
        diff = get_staged_diff()
        if not diff or not diff.strip():
            print("Still nothing staged after 'git add -A' — nothing to commit.")
            sys.exit(0)

    summary = get_staged_file_summary()
    print("Staged changes:")
    print(summary)
    print()

    api_key = get_api_key()

    print("Analyzing diff and generating commit message...\n")
    try:
        message = call_gemini(api_key, diff)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

    while True:
        print("-" * 60)
        print("Suggested commit message:")
        print("-" * 60)
        print(message)
        print("-" * 60)
        choice = input("\n[Enter] commit as-is   [e] edit   [r] regenerate   [q] cancel: ").strip().lower()

        if choice == "":
            if do_commit(message):
                print("Committed.")
            else:
                print("Commit failed — check git output above.")
            break
        elif choice == "e":
            print("\nEdit the message below.")
            print("Type your message (multiple lines OK). Press Enter on an empty line TWICE to finish:\n")
            lines = []
            blank_count = 0
            while True:
                line = input()
                if line == "":
                    blank_count += 1
                    if blank_count >= 2 and lines:
                        break
                    # allow a single blank line as an intentional paragraph break
                    if lines:
                        lines.append(line)
                    continue
                blank_count = 0
                lines.append(line)
            edited = "\n".join(lines).strip()
            if edited:
                message = edited
            continue
        elif choice == "r":
            print("\nRegenerating...\n")
            try:
                message = call_gemini(api_key, diff)
            except Exception as e:
                print(f"Error: {e}")
            continue
        elif choice == "q":
            print("Cancelled — nothing committed.")
            break
        else:
            print("Unrecognized option, try again.")


if __name__ == "__main__":
    main()