; ============================================================
; AI Rewrite — Desktop (AutoHotkey v2)
; Works in ANY app: Notepad, WhatsApp, Word, Outlook, browsers, etc.
;
; Select text anywhere, press a hotkey, it's rewritten in place.
; Free, no billing — uses Google Gemini's free API tier.
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
TraySetIcon("shell32.dll", 44)  ; simple built-in "edit" style icon

; ---------------- Config ----------------
ConfigFile := A_ScriptDir . "\config.ini"
ApiKey := IniRead(ConfigFile, "settings", "api_key", "")
Model  := IniRead(ConfigFile, "settings", "model", "gemini-3.1-flash-lite")

if (ApiKey = "") {
    ApiKey := AskForApiKey()
    if (ApiKey = "") {
        MsgBox("No API key entered. The app will exit.", "AI Rewrite", "Iconx")
        ExitApp()
    }
    IniWrite(ApiKey, ConfigFile, "settings", "api_key")
    IniWrite(Model, ConfigFile, "settings", "model")
}

; ---------------- GUI: ask for API key ----------------
AskForApiKey() {
    result := ""
    keyGui := Gui("+AlwaysOnTop", "AI Rewrite — Setup")
    keyGui.SetFont("s10", "Segoe UI")
    keyGui.Add("Text", "w360", "Paste your free Gemini API key below.")
    keyGui.Add("Text", "w360", "Get one at aistudio.google.com/apikey (no credit card needed).")
    editBox := keyGui.Add("Edit", "w360 vApiKeyInput Password")
    saveBtn := keyGui.Add("Button", "w150 Default", "Save && Start")

    saveBtn.OnEvent("Click", (*) => (
        result := editBox.Value,
        keyGui.Destroy()
    ))
    keyGui.OnEvent("Close", (*) => keyGui.Destroy())
    keyGui.Show()

    WinWaitClose(keyGui.Hwnd)
    return result
}

; ---------------- Tray menu ----------------
A_TrayMenu.Delete()
A_TrayMenu.Add("AI Rewrite — running", (*) => "")
A_TrayMenu.Disable("AI Rewrite — running")
A_TrayMenu.Add()
A_TrayMenu.Add("Ctrl+Alt+R — Fix Grammar", (*) => "")
A_TrayMenu.Add("Ctrl+Alt+I — Improve Writing", (*) => "")
A_TrayMenu.Add("Ctrl+Alt+F — Make Formal", (*) => "")
A_TrayMenu.Add("Ctrl+Alt+C — Make Casual", (*) => "")
A_TrayMenu.Add("Ctrl+Alt+S — Make Shorter", (*) => "")
for _, item in ["Ctrl+Alt+R — Fix Grammar", "Ctrl+Alt+I — Improve Writing", "Ctrl+Alt+F — Make Formal", "Ctrl+Alt+C — Make Casual", "Ctrl+Alt+S — Make Shorter"]
    A_TrayMenu.Disable(item)
A_TrayMenu.Add()
A_TrayMenu.Add("Update API Key", (*) => UpdateApiKey())
A_TrayMenu.Add("Quit", (*) => ExitApp())
A_TrayMenu.Default := "AI Rewrite — running"
TraySetIcon()  ; default icon is fine; kept simple/free of custom asset dependencies

UpdateApiKey(*) {
    global ApiKey, ConfigFile, Model
    newKey := AskForApiKey()
    if (newKey != "") {
        ApiKey := newKey
        IniWrite(ApiKey, ConfigFile, "settings", "api_key")
        TrayTip("AI Rewrite", "API key updated.")
    }
}

; ---------------- Core: call Gemini ----------------
CallGemini(instruction, text) {
    global ApiKey, Model
    url := "https://generativelanguage.googleapis.com/v1beta/models/" . Model . ":generateContent"

    ; Build JSON body manually (no external JSON lib needed) — escape quotes/newlines
    fullPrompt := instruction . "`n`nTEXT:`n" . text
    escaped := StrReplace(fullPrompt, "\", "\\")
    escaped := StrReplace(escaped, '"', '\"')
    escaped := StrReplace(escaped, "`r`n", "\n")
    escaped := StrReplace(escaped, "`n", "\n")
    body := '{"contents":[{"role":"user","parts":[{"text":"' . escaped . '"}]}]}'

    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("POST", url, true)
    whr.SetRequestHeader("Content-Type", "application/json")
    whr.SetRequestHeader("x-goog-api-key", ApiKey)
    whr.Send(body)
    whr.WaitForResponse()

    status := whr.Status
    responseText := whr.ResponseText

    if (status != 200) {
        throw Error("API error " . status . ": " . SubStr(responseText, 1, 300))
    }

    ; Extract the text field from the JSON response without a full JSON parser.
    ; Gemini's response shape: {"candidates":[{"content":{"parts":[{"text":"..."}]}}]}
    needle := '"text": "'
    pos := InStr(responseText, needle)
    if (!pos) {
        needle := '"text":"'
        pos := InStr(responseText, needle)
    }
    if (!pos)
        throw Error("Could not parse API response.")

    startPos := pos + StrLen(needle)
    ; find the closing unescaped quote
    endPos := startPos
    loop {
        endPos := InStr(responseText, '"', , endPos)
        if (!endPos)
            throw Error("Could not parse API response (no closing quote).")
        ; count preceding backslashes to know if this quote is escaped
        backslashes := 0
        chk := endPos - 1
        while (chk >= 1 && SubStr(responseText, chk, 1) = "\") {
            backslashes++
            chk--
        }
        if (Mod(backslashes, 2) = 0)
            break
        endPos++
    }

    resultText := SubStr(responseText, startPos, endPos - startPos)
    resultText := StrReplace(resultText, "\n", "`n")
    resultText := StrReplace(resultText, '\"', '"')
    resultText := StrReplace(resultText, "\\", "\")
    return Trim(resultText)
}

; ---------------- Core: rewrite selected text ----------------
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
        rewritten := CallGemini(instruction, selectedText)
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

; ---------------- Hotkeys ----------------
^!r::DoRewrite("Fix all grammar, spelling, and punctuation errors in the following text. Keep the meaning, tone, and length as close to the original as possible. Return ONLY the corrected text with no preamble, no quotes, no explanation.", "Fixing grammar")
^!i::DoRewrite("Improve the clarity, flow, and word choice of the following text while keeping the original meaning and approximate length. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Improving writing")
^!f::DoRewrite("Rewrite the following text in a formal, professional tone suitable for business communication. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Making formal")
^!c::DoRewrite("Rewrite the following text in a casual, friendly, conversational tone. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Making casual")
^!s::DoRewrite("Rewrite the following text to be significantly shorter and more concise, while keeping the key meaning. Return ONLY the rewritten text with no preamble, no quotes, no explanation.", "Making shorter")

TrayTip("AI Rewrite", "Running. Select text anywhere and press Ctrl+Alt+R.")
