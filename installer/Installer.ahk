; ============================================================
; AI Rewrite — Unified Setup (AutoHotkey v2)
; Bundles AI_Rewrite.exe (desktop rewrite tool) and ai-commit.exe
; (AI git commit tool) into a single self-contained installer.
;
; CLI flags (combinable, order doesn't matter, case-insensitive):
;   /uninstall        Remove a previous install (shows a confirmation prompt).
;   /S or /silent      No GUI: installs both components to the default folder
;                      with the startup entry on and no API key configured
;                      (add one later from either app's tray menu). Exits 0 on
;                      success, 1 on failure — for unattended installers, e.g.
;                      a Microsoft Store "unpackaged Win32 app" submission.
;   /uninstall /S      Silent uninstall: same removal, no prompts.
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
TraySetIcon("shell32.dll", 44)

AppName := "AI Rewrite"
AppVersion := "1.1.0"
Publisher := "Somil Merugawar"
UninstallRegKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\AIRewrite"
StartMenuFolder := A_Programs . "\AI Rewrite"

uninstallFlag := false
silentFlag := false
for arg in A_Args {
    argLower := StrLower(arg)
    if (argLower = "/uninstall")
        uninstallFlag := true
    else if (argLower = "/s" or argLower = "/silent")
        silentFlag := true
}

if (uninstallFlag) {
    RunUninstall(silentFlag)
    ExitApp()
}

if (silentFlag) {
    RunSilentInstall()   ; exits the process itself
}

RunInstaller()

; ================= INSTALL WIZARD =================
RunInstaller() {
    defaultDir := EnvGet("LocalAppData") . "\Programs\AI Rewrite"

    mainGui := Gui("+AlwaysOnTop", AppName . " — Setup")
    mainGui.SetFont("s10", "Segoe UI")
    mainGui.Add("Text", "w440", "Choose what to install:")

    cbRewrite := mainGui.Add("Checkbox", "w440 Checked", "AI Rewrite — rewrite/fix selected text anywhere with a hotkey")
    cbStartup := mainGui.Add("Checkbox", "w420", "    Launch AI Rewrite automatically when Windows starts")
    cbStartup.Value := true
    cbCommit := mainGui.Add("Checkbox", "w440 Checked", "AI Commit — adds an 'ai-commit' command for AI-written git commit messages")

    mainGui.Add("Text", "w440", "Install folder:")
    dirEdit := mainGui.Add("Edit", "w350", defaultDir)
    browseBtn := mainGui.Add("Button", "w80 x+10 yp-2", "Browse...")

    mainGui.Add("Text", "w440", "Gemini API key (optional — you can also set this up later in either app):")
    keyEdit := mainGui.Add("Edit", "w440 Password")
    mainGui.Add("Text", "w440 cGray", "Get a free key at aistudio.google.com/apikey — no credit card needed.")
    mainGui.Add("Text", "w440 cGray", "AI Rewrite also supports OpenAI and Anthropic Claude — add those later from its tray menu.")

    statusText := mainGui.Add("Text", "w440 cRed", "")

    installBtn := mainGui.Add("Button", "w150 Default", "Install")
    cancelBtn := mainGui.Add("Button", "w100 x+10", "Cancel")

    browseBtn.OnEvent("Click", BrowseFolder)
    installBtn.OnEvent("Click", DoInstall)
    cancelBtn.OnEvent("Click", (*) => ExitApp())
    mainGui.OnEvent("Close", (*) => ExitApp())
    mainGui.Show()

    BrowseFolder(*) {
        chosen := DirSelect(dirEdit.Value, , "Choose install folder")
        if (chosen != "")
            dirEdit.Value := chosen
    }

    DoInstall(*) {
        installDir := Trim(dirEdit.Value)
        if (installDir = "") {
            statusText.Text := "Please choose an install folder."
            return
        }
        if (!cbRewrite.Value && !cbCommit.Value) {
            statusText.Text := "Select at least one component to install."
            return
        }

        installBtn.Enabled := false
        cancelBtn.Enabled := false
        statusText.Text := "Installing..."

        try {
            PerformInstall(installDir, cbRewrite.Value, cbCommit.Value, cbStartup.Value, Trim(keyEdit.Value))
        } catch as e {
            statusText.Text := "Install failed: " . e.Message
            installBtn.Enabled := true
            cancelBtn.Enabled := true
            return
        }

        launchAfter := cbRewrite.Value
        mainGui.Destroy()
        ShowFinishScreen(installDir, launchAfter)
    }
}

; Shared by the GUI wizard (DoInstall) and the silent install path
; (RunSilentInstall) so the two never drift out of sync.
PerformInstall(installDir, installRewrite, installCommit, launchAtStartup, apiKey) {
    DirCreate(installDir)

    if (installRewrite) {
        FileInstall("dist\AI_Rewrite.exe", installDir . "\AI_Rewrite.exe", true)
        if (apiKey != "") {
            IniWrite("gemini", installDir . "\config.ini", "settings", "provider")
            IniWrite(apiKey, installDir . "\config.ini", "settings", "gemini_api_key")
            IniWrite("gemini-3.1-flash-lite", installDir . "\config.ini", "settings", "gemini_model")
            ; Best-effort: restrict the plaintext-key config file to the current user only.
            try RunWait('icacls "' . installDir . '\config.ini" /inheritance:r /grant:r "' . A_UserName . '":F /q', , "Hide")
        }
        DirCreate(StartMenuFolder)
        FileCreateShortcut(installDir . "\AI_Rewrite.exe", StartMenuFolder . "\AI Rewrite.lnk")
        if (launchAtStartup)
            FileCreateShortcut(installDir . "\AI_Rewrite.exe", A_Startup . "\AI Rewrite.lnk")
    }

    if (installCommit) {
        FileInstall("dist\ai-commit.exe", installDir . "\ai-commit.exe", true)
        if (apiKey != "") {
            aiCommitConfigDir := EnvGet("UserProfile") . "\.ai-commit"
            DirCreate(aiCommitConfigDir)
            aiCommitConfigFile := aiCommitConfigDir . "\config.ini"
            IniWrite("gemini", aiCommitConfigFile, "settings", "provider")
            IniWrite(apiKey, aiCommitConfigFile, "settings", "gemini_api_key")
            ; Best-effort: restrict the plaintext-key config file to the current user only.
            try RunWait('icacls "' . aiCommitConfigFile . '" /inheritance:r /grant:r "' . A_UserName . '":F /q', , "Hide")
        }
        AddToUserPath(installDir)
    }

    FileCopy(A_ScriptFullPath, installDir . "\Uninstall.exe", true)
    DirCreate(StartMenuFolder)
    FileCreateShortcut(installDir . "\Uninstall.exe", StartMenuFolder . "\Uninstall AI Rewrite.lnk", , "/uninstall")
    WriteUninstallRegistry(installDir)
}

; ================= SILENT INSTALL (unattended — e.g. Store submissions) =================
; Installs both components to the default folder with the startup entry on and
; no API key (there's no GUI to type one into — set it later from either app's
; tray menu / settings). No windows, no prompts. Exits 0 on success, 1 on
; failure so an automated installer can detect the outcome.
RunSilentInstall() {
    installDir := EnvGet("LocalAppData") . "\Programs\AI Rewrite"
    try {
        PerformInstall(installDir, true, true, true, "")
    } catch {
        ExitApp(1)
    }
    ExitApp(0)
}

ShowFinishScreen(installDir, offerLaunch) {
    doneGui := Gui("+AlwaysOnTop", AppName . " — Setup")
    doneGui.SetFont("s10", "Segoe UI")
    doneGui.Add("Text", "w380", "Installation complete.")
    doneGui.Add("Text", "w380", "Installed to: " . installDir)

    launchCb := doneGui.Add("Checkbox", "w380", "Launch AI Rewrite now")
    launchCb.Value := true
    launchCb.Visible := offerLaunch

    finishBtn := doneGui.Add("Button", "w150 Default", "Finish")
    finishBtn.OnEvent("Click", FinishClick)
    doneGui.OnEvent("Close", (*) => ExitApp())
    doneGui.Show()

    FinishClick(*) {
        if (offerLaunch && launchCb.Value)
            Run('"' . installDir . '\AI_Rewrite.exe"')
        doneGui.Destroy()
        ExitApp()
    }
}

WriteUninstallRegistry(installDir) {
    RegWrite(AppName, "REG_SZ", UninstallRegKey, "DisplayName")
    RegWrite('"' . installDir . '\Uninstall.exe" /uninstall', "REG_SZ", UninstallRegKey, "UninstallString")
    RegWrite(installDir, "REG_SZ", UninstallRegKey, "InstallLocation")
    RegWrite(installDir . "\Uninstall.exe", "REG_SZ", UninstallRegKey, "DisplayIcon")
    RegWrite(Publisher, "REG_SZ", UninstallRegKey, "Publisher")
    RegWrite(AppVersion, "REG_SZ", UninstallRegKey, "DisplayVersion")
    RegWrite(1, "REG_DWORD", UninstallRegKey, "NoModify")
    RegWrite(1, "REG_DWORD", UninstallRegKey, "NoRepair")
}

AddToUserPath(dir) {
    currentPath := RegRead("HKCU\Environment", "Path", "")
    for p in StrSplit(currentPath, ";") {
        if (Trim(p) = dir)
            return
    }
    newPath := (currentPath = "") ? dir : currentPath . ";" . dir
    RegWrite(newPath, "REG_EXPAND_SZ", "HKCU\Environment", "Path")
    BroadcastEnvChange()
}

RemoveFromUserPath(dir) {
    currentPath := RegRead("HKCU\Environment", "Path", "")
    newParts := []
    for p in StrSplit(currentPath, ";") {
        if (Trim(p) != dir && Trim(p) != "")
            newParts.Push(p)
    }
    newPath := ""
    for i, p in newParts
        newPath .= (i = 1 ? "" : ";") . p
    RegWrite(newPath, "REG_EXPAND_SZ", "HKCU\Environment", "Path")
    BroadcastEnvChange()
}

BroadcastEnvChange() {
    DllCall("SendMessageTimeout", "ptr", 0xFFFF, "uint", 0x1A, "ptr", 0, "str", "Environment", "uint", 0x2, "uint", 5000, "ptr*", 0)
}

; ================= UNINSTALL =================
RunUninstall(silent := false) {
    installDir := A_ScriptDir

    if (!silent) {
        result := MsgBox(
            AppName . " will be removed, including its Start Menu shortcuts, startup entry, and PATH entry.`n`nContinue?",
            AppName . " — Uninstall",
            "YesNo Icon!"
        )
        if (result != "Yes")
            return
    }

    try ProcessClose("AI_Rewrite.exe")

    try DirDelete(StartMenuFolder, true)
    try FileDelete(A_Startup . "\AI Rewrite.lnk")
    try RemoveFromUserPath(installDir)
    try RegDeleteKey(UninstallRegKey)

    if (!silent)
        MsgBox(AppName . " has been uninstalled.", AppName, "IconI")

    ; This exe is running from inside installDir, so it can't delete itself or
    ; its own folder directly. Hand off to a detached cmd that waits for this
    ; process to exit, then removes the folder.
    Run('cmd /c "timeout /t 2 /nobreak >nul & rmdir /s /q ""' . installDir . '"""', , "Hide")
    ExitApp()
}
