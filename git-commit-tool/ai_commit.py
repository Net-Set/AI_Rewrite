#!/usr/bin/env python3
"""
ai-commit — suggests a Conventional Commits message based on your staged changes.

Usage:
    git add <files>
    python ai_commit.py
    (review the suggestion, confirm to commit, edit, or cancel)

Setup:
    pip install requests
    Choose an AI provider — Google Gemini (free tier), OpenAI, or Anthropic Claude — and
    set its API key once via the matching environment variable (GEMINI_API_KEY /
    OPENAI_API_KEY / ANTHROPIC_API_KEY), or just run the script: it'll ask the first time
    and save your choice + key to ~/.ai-commit/config.ini.
"""

import subprocess
import sys
import os
import re
import json
import getpass
import configparser

try:
    import requests
except ImportError:
    print("Error: the 'requests' package is required but not installed.")
    print("Install it with:  pip install -r requirements.txt   (or: pip install requests)")
    sys.exit(1)

CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".ai-commit")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.ini")

# ---- AI providers ----
# To add a new provider: add an entry here, write a call_<provider>(api_key, model,
# full_prompt) function with the same shape (returns the message text, raises RuntimeError
# on failure), and add a branch in call_ai().
PROVIDERS = {
    "gemini": {
        "label": "Google Gemini",
        "default_model": "gemini-3.1-flash-lite",
        "env_var": "GEMINI_API_KEY",
        "key_url": "https://aistudio.google.com/apikey (free, no credit card)",
    },
    "openai": {
        "label": "OpenAI (ChatGPT)",
        "default_model": "gpt-4o-mini",
        "env_var": "OPENAI_API_KEY",
        "key_url": "https://platform.openai.com/api-keys",
    },
    "anthropic": {
        "label": "Anthropic Claude",
        "default_model": "claude-sonnet-4-6",
        "env_var": "ANTHROPIC_API_KEY",
        "key_url": "https://console.anthropic.com/",
    },
}
PROVIDER_IDS = list(PROVIDERS.keys())

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


# ============================================================
# Config file handling
# ============================================================
def get_config():
    config = configparser.ConfigParser()
    if os.path.exists(CONFIG_FILE):
        try:
            config.read(CONFIG_FILE)
        except configparser.Error as e:
            print(f"Warning: couldn't parse {CONFIG_FILE} ({e}) — ignoring it and starting fresh.")
            config = configparser.ConfigParser()
    if "settings" not in config:
        config["settings"] = {}
    migrate_legacy_config(config)
    return config


def migrate_legacy_config(config):
    """Pre-multi-provider configs used bare 'api_key'/'model' fields for Gemini only."""
    settings = config["settings"]
    changed = False
    if "api_key" in settings and "gemini_api_key" not in settings:
        settings["gemini_api_key"] = settings["api_key"]
        del settings["api_key"]
        changed = True
    if "model" in settings and "gemini_model" not in settings:
        settings["gemini_model"] = settings["model"]
        del settings["model"]
        changed = True
    if changed:
        save_config(config)


def save_config(config):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        config.write(f)
    # Best-effort: config.ini holds API keys in plaintext, so keep it readable only by
    # the current user where the OS supports it. No-op/ignorable on Windows.
    try:
        os.chmod(CONFIG_FILE, 0o600)
    except OSError:
        pass


# ============================================================
# Provider / API key selection
# ============================================================
def choose_provider_interactively():
    print("Which AI provider would you like to use?")
    for i, pid in enumerate(PROVIDER_IDS, 1):
        print(f"  {i}. {PROVIDERS[pid]['label']}")
    try:
        choice = input(f"Enter 1-{len(PROVIDER_IDS)} [1]: ").strip()
    except EOFError:
        print("\nNo input available — defaulting to Google Gemini.")
        return "gemini"

    if choice == "":
        return PROVIDER_IDS[0]
    if choice.isdigit() and 1 <= int(choice) <= len(PROVIDER_IDS):
        return PROVIDER_IDS[int(choice) - 1]

    print("Unrecognized choice — defaulting to Google Gemini.")
    return "gemini"


def get_provider(config):
    # AI_COMMIT_PROVIDER lets you override per-shell/CI without touching config.ini.
    env_override = os.environ.get("AI_COMMIT_PROVIDER", "").strip().lower()
    if env_override in PROVIDERS:
        return env_override

    configured = config["settings"].get("provider", "").strip().lower()
    if configured in PROVIDERS:
        return configured

    provider = choose_provider_interactively()
    config["settings"]["provider"] = provider
    save_config(config)
    return provider


def get_api_key(provider, config):
    info = PROVIDERS[provider]

    env_key = os.environ.get(info["env_var"])
    if env_key:
        return env_key

    key_field = f"{provider}_api_key"
    key = config["settings"].get(key_field, "")
    if key:
        return key

    print(f"No {info['label']} API key found.")
    print(f"Get one at: {info['key_url']}")
    try:
        key = getpass.getpass(f"Paste your {info['label']} API key (input hidden): ").strip()
    except EOFError:
        key = ""

    if not key:
        print("No key provided. Exiting.")
        sys.exit(1)

    config["settings"][key_field] = key
    save_config(config)
    return key


def get_model(provider, config):
    return config["settings"].get(f"{provider}_model", PROVIDERS[provider]["default_model"])


# ============================================================
# Git helpers
# ============================================================
def run_git(args, capture=True):
    try:
        if capture:
            return subprocess.run(
                ["git", *args],
                capture_output=True, text=True,
                encoding="utf-8", errors="replace"
            )
        return subprocess.run(["git", *args])
    except FileNotFoundError:
        print("Error: git executable not found. Make sure Git is installed and on your PATH.")
        sys.exit(1)


def get_staged_diff():
    result = run_git(["diff", "--staged"])
    if result.returncode != 0:
        print("Error running git diff — are you inside a git repository?")
        print(result.stderr)
        sys.exit(1)
    return result.stdout


def get_staged_file_summary():
    result = run_git(["diff", "--staged", "--stat"])
    return result.stdout.strip()


def has_any_changes():
    """Check if there's anything at all to work with — staged, unstaged, or untracked."""
    result = run_git(["status", "--porcelain"])
    return bool(result.stdout and result.stdout.strip())


def stage_everything():
    result = run_git(["add", "-A"], capture=False)
    return result.returncode == 0


def do_commit(message):
    result = run_git(["commit", "-m", message], capture=False)
    return result.returncode == 0


# ============================================================
# AI provider calls
# ============================================================
def extract_error_message(body_text):
    """Every provider nests the actual human-readable explanation at error.message in its
    JSON error body — pull that out instead of showing the raw JSON blob."""
    try:
        return json.loads(body_text).get("error", {}).get("message")
    except (ValueError, AttributeError):
        return None


def friendly_api_error(label, status_code, body_text):
    message = extract_error_message(body_text)

    if status_code == 429:
        base = f"{label} rate limit hit — wait a moment and try again."
    elif status_code in (401, 403):
        base = f"{label} rejected the API key (HTTP {status_code}). Delete the *_api_key line for it in ~/.ai-commit/config.ini to be re-prompted."
    elif message and re.search(r"credit|balance|quota|billing", message, re.IGNORECASE):
        base = f"{label} account issue (HTTP {status_code}) — this is a billing/quota problem on your account, not a bug."
    else:
        base = f"{label} API error {status_code}."

    return f"{base} {message}" if message else f"{base} {body_text[:300]}"


def call_gemini(api_key, model, full_prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    headers = {"Content-Type": "application/json", "x-goog-api-key": api_key}
    body = {"contents": [{"role": "user", "parts": [{"text": full_prompt}]}]}

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    if not resp.ok:
        raise RuntimeError(friendly_api_error("Gemini", resp.status_code, resp.text))

    data = resp.json()
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError):
        block_reason = data.get("promptFeedback", {}).get("blockReason")
        if block_reason:
            raise RuntimeError(f"Gemini blocked the response ({block_reason}).")
        raise RuntimeError("No text returned from Gemini.")


def call_openai(api_key, model, full_prompt):
    url = "https://api.openai.com/v1/chat/completions"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}
    body = {"model": model, "messages": [{"role": "user", "content": full_prompt}]}

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    if not resp.ok:
        raise RuntimeError(friendly_api_error("OpenAI", resp.status_code, resp.text))

    data = resp.json()
    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError):
        raise RuntimeError("No text returned from OpenAI.")


def call_anthropic(api_key, model, full_prompt):
    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
    body = {"model": model, "max_tokens": 4096, "messages": [{"role": "user", "content": full_prompt}]}

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    if not resp.ok:
        raise RuntimeError(friendly_api_error("Anthropic", resp.status_code, resp.text))

    data = resp.json()
    try:
        return data["content"][0]["text"].strip()
    except (KeyError, IndexError):
        raise RuntimeError("No text returned from Anthropic.")


def call_ai(provider, model, api_key, diff_text):
    # Guard against extremely large diffs — trim to keep the request fast and cheap
    max_chars = 12000
    truncated = len(diff_text) > max_chars
    diff_for_prompt = diff_text[:max_chars]

    prompt = COMMIT_INSTRUCTION
    if truncated:
        prompt += "\n(Note: diff was truncated for length — base the message on what's shown.)\n"

    full_prompt = f"{prompt}\n\nDIFF:\n{diff_for_prompt}"

    try:
        if provider == "gemini":
            return call_gemini(api_key, model, full_prompt)
        elif provider == "openai":
            return call_openai(api_key, model, full_prompt)
        elif provider == "anthropic":
            return call_anthropic(api_key, model, full_prompt)
        else:
            raise RuntimeError(f"Unknown provider: {provider}")
    except requests.exceptions.Timeout:
        raise RuntimeError(f"{PROVIDERS[provider]['label']} request timed out — check your connection and try again.")
    except requests.exceptions.ConnectionError:
        raise RuntimeError(f"Couldn't reach {PROVIDERS[provider]['label']} — check your internet connection.")
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Network error talking to {PROVIDERS[provider]['label']}: {e}")


# ============================================================
# Main
# ============================================================
def main():
    diff = get_staged_diff()

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

    config = get_config()
    provider = get_provider(config)
    api_key = get_api_key(provider, config)
    model = get_model(provider, config)

    print(f"Analyzing diff with {PROVIDERS[provider]['label']} ({model})...\n")
    try:
        message = call_ai(provider, model, api_key, diff)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

    while True:
        print("-" * 60)
        print("Suggested commit message:")
        print("-" * 60)
        print(message)
        print("-" * 60)
        try:
            choice = input("\n[Enter] commit as-is   [e] edit   [r] regenerate   [q] cancel: ").strip().lower()
        except EOFError:
            print("\nNo input available — cancelling, nothing committed.")
            break

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
            try:
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
            except EOFError:
                pass  # fall through with whatever was typed before input closed
            edited = "\n".join(lines).strip()
            if edited:
                message = edited
            continue
        elif choice == "r":
            print("\nRegenerating...\n")
            try:
                message = call_ai(provider, model, api_key, diff)
            except Exception as e:
                print(f"Error: {e}")
            continue
        elif choice == "q":
            print("Cancelled — nothing committed.")
            break
        else:
            print("Unrecognized option, try again.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelled — nothing committed.")
        sys.exit(130)
