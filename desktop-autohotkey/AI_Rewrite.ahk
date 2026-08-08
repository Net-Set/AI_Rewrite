; ============================================================
; AI Rewrite — Desktop (AutoHotkey v2)
; Works in ANY app: Notepad, WhatsApp, Word, Outlook, browsers, etc.
;
; Select text anywhere, press a hotkey, it's rewritten in place.
; Supports multiple AI providers (Google Gemini, OpenAI, Anthropic
; Claude) — switch providers or update keys anytime from the tray
; menu, no restart required.
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
TraySetIcon("shell32.dll", 44)  ; simple built-in "edit" style icon

; ---------------- Provider registry ----------------
; Adding a new provider later means: add its id here, add a Call<Provider>()
; function following the same shape, and add a case to CallProvider().
PROVIDER_IDS := ["gemini", "openai", "anthropic"]
PROVIDER_LABELS := Map(
    "gemini", "Google Gemini",
    "openai", "OpenAI (ChatGPT)",
    "anthropic", "Anthropic Claude"
)
DEFAULT_MODELS := Map(
    "gemini", "gemini-3.1-flash-lite",
    "openai", "gpt-4o-mini",
    "anthropic", "claude-sonnet-4-6"
)

; Shortcut used to auto-launch on login, so the app survives a Windows restart
; without the user having to manually reopen it. Works whether this is the raw
; .ahk script (launched via the AutoHotkey file association) or the compiled .exe.
STARTUP_SHORTCUT := A_Startup . "\AI Rewrite.lnk"

; ---------------- Config ----------------
ConfigFile := A_ScriptDir . "\config.ini"

Provider := IniRead(ConfigFile, "settings", "provider", "gemini")
if !PROVIDER_LABELS.Has(Provider)
    Provider := "gemini"  ; unknown/corrupted value in config.ini — fall back safely

ApiKeys := Map()
Models := Map()
for pid in PROVIDER_IDS {
    ApiKeys[pid] := IniRead(ConfigFile, "settings", pid . "_api_key", "")
    Models[pid]  := IniRead(ConfigFile, "settings", pid . "_model", DEFAULT_MODELS[pid])
}

; ---- Migrate legacy single-provider config (pre-multi-provider versions of this script) ----
legacyKey := IniRead(ConfigFile, "settings", "api_key", "")
if (legacyKey != "" && ApiKeys["gemini"] = "") {
    ApiKeys["gemini"] := legacyKey
    legacyModel := IniRead(ConfigFile, "settings", "model", "")
    if (legacyModel != "")
        Models["gemini"] := legacyModel
    SaveSettings()
}

; ---- First-run / sanity check: make sure the active provider actually has a key ----
hasAnyKey := false
for pid in PROVIDER_IDS {
    if (ApiKeys[pid] != "")
        hasAnyKey := true
}

if (!hasAnyKey) {
    if (!ShowSettingsGui(true)) {
        ExitApp()
    }
    ; First run successfully configured — auto-enable "start with Windows" by default
    ; (matches the installer's default) so a reboot doesn't require manually relaunching.
    if (!IsStartupEnabled()) {
        try FileCreateShortcut(A_ScriptFullPath, STARTUP_SHORTCUT, A_ScriptDir)
    }
} else if (ApiKeys[Provider] = "") {
    ; Selected provider has no key even though a different one does — fall back to
    ; whichever provider is actually configured instead of failing on every hotkey.
    for pid in PROVIDER_IDS {
        if (ApiKeys[pid] != "") {
            Provider := pid
            break
        }
    }
    SaveSettings()
}

; ---------------- Tray menu ----------------
RebuildTrayMenu()

; ============================================================
; GUI: first-run / settings — provider picker + API keys
; ============================================================
ShowSettingsGui(firstRun := false) {
    global Provider, ApiKeys, PROVIDER_IDS, PROVIDER_LABELS

    saved := false
    providerLabelsList := []
    for pid in PROVIDER_IDS
        providerLabelsList.Push(PROVIDER_LABELS[pid])
    currentIndex := IndexOf(PROVIDER_IDS, Provider)
    if (currentIndex = 0)
        currentIndex := 1

    sGui := Gui("+AlwaysOnTop", firstRun ? "AI Rewrite — Setup" : "AI Rewrite — AI Provider & Keys")
    sGui.SetFont("s10", "Segoe UI")

    if (firstRun) {
        sGui.Add("Text", "w440", "Welcome! Pick an AI provider and paste its API key below.")
        sGui.Add("Text", "w440", "You can add the others later and switch anytime from the tray menu — no restart needed.")
    }

    sGui.Add("Text", "w440 y+12", "Active provider (used by all rewrite hotkeys):")
    providerDDL := sGui.Add("DropDownList", "w440 vProviderInput Choose" . currentIndex, providerLabelsList)

    sGui.Add("Text", "xm w440 y+16", "Google Gemini API key   —   free at aistudio.google.com/apikey")
    geminiEdit := sGui.Add("Edit", "w440 vGeminiKeyInput Password")
    geminiEdit.Value := ApiKeys["gemini"]

    sGui.Add("Text", "w440", "OpenAI API key   —   platform.openai.com/api-keys")
    openaiEdit := sGui.Add("Edit", "w440 vOpenAIKeyInput Password")
    openaiEdit.Value := ApiKeys["openai"]

    sGui.Add("Text", "w440", "Anthropic (Claude) API key   —   console.anthropic.com")
    anthropicEdit := sGui.Add("Edit", "w440 vAnthropicKeyInput Password")
    anthropicEdit.Value := ApiKeys["anthropic"]

    sGui.Add("Text", "w440 cGray y+8", "Leave a key blank if you don't use that provider. Only the active provider needs one.")
    sGui.Add("Text", "w440 cGray", "Advanced: to override the default model per provider, edit config.ini (<provider>_model).")

    saveBtn := sGui.Add("Button", "w215 Default y+14", "Save")
    cancelBtn := sGui.Add("Button", "w215 x+10", firstRun ? "Cancel (exit)" : "Cancel")

    saveBtn.OnEvent("Click", (*) => (
        Provider := PROVIDER_IDS[providerDDL.Value],
        ApiKeys["gemini"] := Trim(geminiEdit.Value),
        ApiKeys["openai"] := Trim(openaiEdit.Value),
        ApiKeys["anthropic"] := Trim(anthropicEdit.Value),
        saved := true,
        sGui.Destroy()
    ))
    cancelBtn.OnEvent("Click", (*) => sGui.Destroy())
    sGui.OnEvent("Close", (*) => sGui.Destroy())

    sGui.Show()
    WinWaitClose(sGui.Hwnd)

    if (!saved)
        return false

    if (ApiKeys[Provider] = "") {
        MsgBox("You selected " . PROVIDER_LABELS[Provider] . " as the active provider but didn't enter a key for it.`n`nPlease enter a key for the active provider (or pick a different one).", "AI Rewrite", "Iconx")
        return ShowSettingsGui(firstRun)
    }

    SaveSettings()
    TrayTip("AI Rewrite", "Settings saved — now using " . PROVIDER_LABELS[Provider] . ". No restart needed.")
    return true
}

; Opens the settings GUI from the tray menu and refreshes the menu header afterward
; (it shows the active provider name).
OpenSettings(*) {
    if (ShowSettingsGui(false))
        RebuildTrayMenu()
}

IndexOf(arr, val) {
    for i, v in arr {
        if (v = val)
            return i
    }
    return 0
}

SaveSettings() {
    global ConfigFile, Provider, ApiKeys, Models, PROVIDER_IDS
    IniWrite(Provider, ConfigFile, "settings", "provider")
    for pid in PROVIDER_IDS {
        IniWrite(ApiKeys[pid], ConfigFile, "settings", pid . "_api_key")
        IniWrite(Models[pid], ConfigFile, "settings", pid . "_model")
    }
    RestrictConfigFilePermissions()
}

; Best-effort: config.ini holds API keys in plaintext, so restrict it to the current user
; only — relevant on shared/multi-user machines. Silently does nothing if icacls isn't
; available or the call fails; never blocks saving settings on this.
RestrictConfigFilePermissions() {
    global ConfigFile
    try RunWait('icacls "' . ConfigFile . '" /inheritance:r /grant:r "' . A_UserName . '":F /q', , "Hide")
}

; ============================================================
; GUI: custom instruction popup (used by Ctrl+Alt+A)
; ============================================================
AskForCustomInstruction() {
    result := ""
    cGui := Gui("+AlwaysOnTop", "AI Rewrite — Custom Instruction")
    cGui.SetFont("s10", "Segoe UI")
    cGui.Add("Text", "w400", "Selected text captured. Type an instruction for how to rewrite it:")
    cGui.Add("Text", "w400 cGray", 'e.g. "Translate to Spanish", "Make it sound like a pirate", "Turn into bullet points"')
    editBox := cGui.Add("Edit", "w400 vInstructionInput")
    applyBtn := cGui.Add("Button", "w195 Default y+12", "Apply")
    cancelBtn := cGui.Add("Button", "w195 x+10", "Cancel")

    applyBtn.OnEvent("Click", (*) => (
        result := editBox.Value,
        cGui.Destroy()
    ))
    cancelBtn.OnEvent("Click", (*) => (
        result := "",
        cGui.Destroy()
    ))
    cGui.OnEvent("Close", (*) => (result := "", cGui.Destroy()))

    cGui.Show()
    editBox.Focus()
    WinWaitClose(cGui.Hwnd)

    return Trim(result)
}

; ============================================================
; Auto-start on Windows login (survives a system restart with no manual relaunch)
; ============================================================
IsStartupEnabled() {
    global STARTUP_SHORTCUT
    return FileExist(STARTUP_SHORTCUT) ? true : false
}

ToggleStartup(*) {
    global STARTUP_SHORTCUT
    if (IsStartupEnabled()) {
        try FileDelete(STARTUP_SHORTCUT)
        TrayTip("AI Rewrite", "Removed from Windows startup — you'll need to launch it manually next time.")
    } else {
        try {
            FileCreateShortcut(A_ScriptFullPath, STARTUP_SHORTCUT, A_ScriptDir)
            TrayTip("AI Rewrite", "AI Rewrite will now start automatically the next time you log in.")
        } catch as e {
            TrayTip("AI Rewrite — Error", "Couldn't enable startup: " . e.Message, 3)
        }
    }
    RebuildTrayMenu()
}

; ============================================================
; Tray menu
; ============================================================
RebuildTrayMenu() {
    global Provider, PROVIDER_LABELS

    A_TrayMenu.Delete()
    header := "AI Rewrite — running (" . PROVIDER_LABELS[Provider] . ")"
    A_TrayMenu.Add(header, (*) => "")
    A_TrayMenu.Disable(header)
    A_TrayMenu.Add()

    hotkeyLines := [
        "Ctrl+Alt+R — Fix Grammar",
        "Ctrl+Alt+I — Improve Writing",
        "Ctrl+Alt+F — Make Formal",
        "Ctrl+Alt+C — Make Casual",
        "Ctrl+Alt+S — Make Shorter",
        "Ctrl+Alt+A — Custom Instruction..."
    ]
    for _, item in hotkeyLines {
        A_TrayMenu.Add(item, (*) => "")
        A_TrayMenu.Disable(item)
    }

    A_TrayMenu.Add()
    A_TrayMenu.Add("AI Provider && Keys...", (*) => OpenSettings())

    startupLabel := "Start with Windows"
    A_TrayMenu.Add(startupLabel, (*) => ToggleStartup())
    if (IsStartupEnabled())
        A_TrayMenu.Check(startupLabel)
    else
        A_TrayMenu.Uncheck(startupLabel)

    A_TrayMenu.Add()
    ; AHK doesn't hot-reload — code/config-schema changes to the script or exe on disk
    ; don't affect an already-running instance. Reload restarts the process from the
    ; current file, picking up any update without a manual quit + relaunch.
    A_TrayMenu.Add("Reload (apply an update)", (*) => Reload())
    A_TrayMenu.Add("Quit", (*) => ExitApp())
    A_TrayMenu.Default := header
    TraySetIcon()  ; default icon is fine; kept simple/free of custom asset dependencies
}

; ============================================================
; Shared HTTP helper — one place to handle network failures/timeouts
; for all providers.
; ============================================================
HttpPost(url, headersMap, body) {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.SetTimeouts(10000, 10000, 15000, 30000)  ; resolve, connect, send, receive (ms)
        whr.Open("POST", url, true)
        for name, value in headersMap
            whr.SetRequestHeader(name, value)
        whr.Send(body)
        whr.WaitForResponse()
    } catch as e {
        throw Error("Network error — could not reach the API. Check your internet connection. (" . e.Message . ")")
    }
    return { status: whr.Status, text: whr.ResponseText }
}

; Escapes a string for embedding inside a JSON string literal.
; AHK has no built-in JSON library, so requests are built by hand — see notes below.
JsonEscape(str) {
    escaped := StrReplace(str, "\", "\\")
    escaped := StrReplace(escaped, '"', '\"')
    escaped := StrReplace(escaped, "`r`n", "\n")
    escaped := StrReplace(escaped, "`n", "\n")
    escaped := StrReplace(escaped, "`t", "\t")
    return escaped
}

; Extracts the value of the first `"key":"..."` occurrence in a JSON response,
; without a full JSON parser. Handles escaped quotes/backslashes inside the value.
; This is the first thing to check if a provider changes its response shape.
ExtractJsonString(json, key) {
    needle := '"' . key . '": "'
    pos := InStr(json, needle)
    if (!pos) {
        needle := '"' . key . '":"'
        pos := InStr(json, needle)
    }
    if (!pos)
        return ""

    startPos := pos + StrLen(needle)
    endPos := startPos
    loop {
        endPos := InStr(json, '"', , endPos)
        if (!endPos)
            return ""
        ; count preceding backslashes to know if this quote is escaped
        backslashes := 0
        chk := endPos - 1
        while (chk >= 1 && SubStr(json, chk, 1) = "\") {
            backslashes++
            chk--
        }
        if (Mod(backslashes, 2) = 0)
            break
        endPos++
    }

    resultText := SubStr(json, startPos, endPos - startPos)
    resultText := StrReplace(resultText, "\n", "`n")
    resultText := StrReplace(resultText, '\"', '"')
    resultText := StrReplace(resultText, "\\", "\")
    return resultText
}

; ============================================================
; Core: dispatch to whichever provider is active
; ============================================================
CallProvider(instruction, text) {
    global Provider
    switch Provider {
        case "gemini":
            return CallGemini(instruction, text)
        case "openai":
            return CallOpenAI(instruction, text)
        case "anthropic":
            return CallAnthropic(instruction, text)
        default:
            throw Error("Unknown provider: " . Provider . ". Open the tray menu → AI Provider & Keys to fix this.")
    }
}

; Builds a clear, human-readable error instead of dumping the provider's raw JSON error
; body — all three providers nest the actual explanation at "message", so pull that out
; via the same hand-rolled extractor used for successful responses.
FriendlyApiError(providerLabel, status, bodyText) {
    message := ExtractJsonString(bodyText, "message")

    if (status = 429)
        base := providerLabel . " rate limit hit — wait a moment and try again."
    else if (status = 401 || status = 403)
        base := providerLabel . " rejected the API key (HTTP " . status . "). Check it via the tray menu → AI Provider & Keys."
    else if (message != "" && RegExMatch(message, "i)credit|balance|quota|billing"))
        base := providerLabel . " account issue (HTTP " . status . ") — this is a billing/quota problem on your account, not a bug in the app."
    else
        base := providerLabel . " API error " . status . "."

    if (message != "")
        return base . " " . message
    return base . " " . SubStr(bodyText, 1, 300)
}

; ---- Google Gemini ----
CallGemini(instruction, text) {
    global ApiKeys, Models
    key := ApiKeys["gemini"]
    if (key = "")
        throw Error("No Gemini API key set. Open the tray menu → AI Provider & Keys to add one.")

    url := "https://generativelanguage.googleapis.com/v1beta/models/" . Models["gemini"] . ":generateContent"
    body := '{"contents":[{"role":"user","parts":[{"text":"' . JsonEscape(instruction . "`n`nTEXT:`n" . text) . '"}]}]}'
    headers := Map("Content-Type", "application/json", "x-goog-api-key", key)

    res := HttpPost(url, headers, body)
    if (res.status != 200)
        throw Error(FriendlyApiError("Gemini", res.status, res.text))

    resultText := ExtractJsonString(res.text, "text")
    if (resultText = "")
        throw Error("Could not parse Gemini's response.")
    return Trim(resultText)
}

; ---- OpenAI (Chat Completions) ----
CallOpenAI(instruction, text) {
    global ApiKeys, Models
    key := ApiKeys["openai"]
    if (key = "")
        throw Error("No OpenAI API key set. Open the tray menu → AI Provider & Keys to add one.")

    url := "https://api.openai.com/v1/chat/completions"
    body := '{"model":"' . Models["openai"] . '","messages":[{"role":"user","content":"' . JsonEscape(instruction . "`n`nTEXT:`n" . text) . '"}]}'
    headers := Map("Content-Type", "application/json", "Authorization", "Bearer " . key)

    res := HttpPost(url, headers, body)
    if (res.status != 200)
        throw Error(FriendlyApiError("OpenAI", res.status, res.text))

    resultText := ExtractJsonString(res.text, "content")
    if (resultText = "")
        throw Error("Could not parse OpenAI's response.")
    return Trim(resultText)
}

; ---- Anthropic Claude (Messages API) ----
CallAnthropic(instruction, text) {
    global ApiKeys, Models
    key := ApiKeys["anthropic"]
    if (key = "")
        throw Error("No Anthropic API key set. Open the tray menu → AI Provider & Keys to add one.")

    url := "https://api.anthropic.com/v1/messages"
    body := '{"model":"' . Models["anthropic"] . '","max_tokens":4096,"messages":[{"role":"user","content":"' . JsonEscape(instruction . "`n`nTEXT:`n" . text) . '"}]}'
    headers := Map("Content-Type", "application/json", "x-api-key", key, "anthropic-version", "2023-06-01")

    res := HttpPost(url, headers, body)
    if (res.status != 200)
        throw Error(FriendlyApiError("Anthropic", res.status, res.text))

    resultText := ExtractJsonString(res.text, "text")
    if (resultText = "")
        throw Error("Could not parse Anthropic's response.")
    return Trim(resultText)
}

; ============================================================
; Core: rewrite selected text with a fixed instruction/mode
; ============================================================
DoRewrite(instruction, label) {
    TrayTip("AI Rewrite", label . "...")

    oldClipboard := ClipboardAll()
    A_Clipboard := ""  ; clear so we can detect whether Ctrl+C actually put something there

    Send("^c")
    if (!ClipWait(1)) {
        TrayTip("AI Rewrite", "No text selected — select text first.", 1)
        A_Clipboard := oldClipboard
        return
    }

    selectedText := A_Clipboard

    try {
        rewritten := CallProvider(instruction, selectedText)
    } catch as e {
        TrayTip("AI Rewrite — Error", e.Message, 3)
        A_Clipboard := oldClipboard
        return
    }

    A_Clipboard := rewritten
    Send("^v")
    TrayTip("AI Rewrite", "Done.")

    Sleep(800)
    A_Clipboard := oldClipboard
}

; ============================================================
; Core: rewrite selected text with a custom, user-typed instruction
; ============================================================
DoCustomRewrite(*) {
    targetHwnd := WinExist("A")  ; remember the focused window before our popup steals focus

    oldClipboard := ClipboardAll()
    A_Clipboard := ""

    Send("^c")
    if (!ClipWait(1)) {
        TrayTip("AI Rewrite", "No text selected — select text first.", 1)
        A_Clipboard := oldClipboard
        return
    }

    selectedText := A_Clipboard

    instruction := AskForCustomInstruction()
    if (instruction = "") {
        A_Clipboard := oldClipboard
        return  ; user cancelled or left it blank
    }

    TrayTip("AI Rewrite", "Applying custom instruction...")

    try {
        rewritten := CallProvider(instruction, selectedText)
    } catch as e {
        TrayTip("AI Rewrite — Error", e.Message, 3)
        A_Clipboard := oldClipboard
        return
    }

    ; The instruction popup took focus away from the original app — reactivate it
    ; before pasting, otherwise Ctrl+V would land in the wrong window.
    if (targetHwnd && WinExist("ahk_id " . targetHwnd))
        WinActivate("ahk_id " . targetHwnd)
    Sleep(100)

    A_Clipboard := rewritten
    Send("^v")
    TrayTip("AI Rewrite", "Done.")

    Sleep(800)
    A_Clipboard := oldClipboard
}

; ---------------- Hotkeys ----------------
; Existing hotkeys are unchanged.
^!r::DoRewrite("Fix all grammar, spelling, and punctuation errors in the following text. Keep the meaning, tone, and length as close to the original as possible. Return ONLY the corrected text with no preamble, no quotes, no explanation.", "Fixing grammar")
^!i::DoRewrite("Improve the clarity, flow, and word choice of the following text while keeping the original meaning and approximate length. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Improving writing")
^!f::DoRewrite("Rewrite the following text in a formal, professional tone suitable for business communication. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Making formal")
^!c::DoRewrite("Rewrite the following text in a casual, friendly, conversational tone. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Making casual")
^!s::DoRewrite("Rewrite the following text to be significantly shorter and more concise, while keeping the key meaning. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Making shorter")
; New: custom, user-typed instruction — captures the current selection first, then asks what to do with it.
^!a::DoCustomRewrite()

TrayTip("AI Rewrite", "Running. Select text anywhere and press Ctrl+Alt+R (or Ctrl+Alt+A for a custom instruction).")
