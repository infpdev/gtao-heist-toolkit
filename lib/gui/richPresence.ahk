global currentActivity := ""

class RichPresenceCmd {
    static DISABLE := "DISABLE"
    static CLEAR := "CLEAR"
    static IDLE := "IDLE"
    static NO_SAVE := "NO_SAVE"
    static FINGERPRINT := "FINGERPRINT"
    static KEYPAD := "KEYPAD"
    static CAYO_FINGERPRINT := "CAYO_FINGERPRINT"
    static LEDGE_GRAB := "LEDGE_GRAB"
}

; DISCORD_EXE := "ahk_exe Discord.exe"
DISCORD_NOT_RUNNING := "DiscordNotRunning"

IsDiscordRunning() {
    return ProcessExist("Discord.exe")
}

; Enable rich presence and write to ini file
EnableRichPresence() {
    global iniFile, richPresenceEnabled

    RPCTutorialShown := IniRead(iniFile, "Options", "RPCTutorialShown", false)
    if (!RPCTutorialShown) {
        shouldEnableRPC := ShowRPCTutorialPrompt()
        IniWrite(1, iniFile, "Options", "RPCTutorialShown")
        if (!shouldEnableRPC) {
            if (richPresenceEnabled) {
                ToggleRichPresence()
            }
            return false
        }
    }

    if (!IsDiscordRunning()) {
        MsgBox "Discord is not running. Please start Discord to enable rich presence.", "Error", 16
        return
    }

    try IniWrite(1, iniFile, "Options", "richPresence")
    richPresenceEnabled := true
    UpdateCurrentActivity()
}

; Disable rich presence and write to ini file
DisableRichPresence(shouldClearActivity := true) {
    global richPresenceEnabled, currentActivity
    global iniFile

    if (shouldClearActivity)
        SetActivity(RichPresenceCmd.DISABLE)
    richPresenceEnabled := false
    try IniWrite(0, iniFile, "Options", "richPresence")
}

/**
 * @description Updates the current rich presence activity based on the current state of the application.<br>
 * Priority: NoSave > Solver > LedgeGrab > Clear
 */
UpdateCurrentActivity() {
    global hackMode, noSave, scriptsEnabled, heist, fingerprintMode, debug

    if (!richPresenceEnabled)
        return

    if (!debug && !isGtaRunning()) {
        ClearRichPresence()
        return
    }

    if (noSave) {
        SetActivity(RichPresenceCmd.NO_SAVE)
        return
    }
    else if (scriptsEnabled) {
        if (hackMode = "idle") {
            SetActivity(RichPresenceCmd.IDLE)
        }
        else if (heist = DCH_OR_KORTZ) {
            ; MsgBox fingerprintMode
            if (fingerprintMode) {
                ; MsgBox "Setting Rich Presence to Fingerprint Mode"
                SetActivity(RichPresenceCmd.FINGERPRINT)
            }
            else {
                SetActivity(RichPresenceCmd.KEYPAD)
            }
        } else if (heist = CAYO_PERICO) {
            SetActivity(RichPresenceCmd.CAYO_FINGERPRINT)
        }
        return
    }
    else if (ledgeGrabInProgress) {
        SetActivity(RichPresenceCmd.LEDGE_GRAB)
    } else {
        ClearRichPresence()
    }
}

; Sets the current rich presence activity to the specified type.
SetActivity(type) {
    static shownWarning := false
    global richPresenceEnabled, currentActivity

    if (richPresenceEnabled && !isShuttingDown) {

        if (!LastDiscordCallFinished())
            return

        previousActivity := currentActivity
        currentActivity := type
        ; MsgBox "Previous Activity: " previousActivity "`nCurrent Activity: " currentActivity
        if (previousActivity != currentActivity) {
            res := SetDiscordActivity(type)
            if (res != "OK" && debug) {
                if (res = DISCORD_NOT_RUNNING && !shownWarning) {
                    ShowCenteredToolTip "Discord is not running. Please start Discord to show rich presence activity",
                        17
                    shownWarning := true
                    SetTimer(() => ToolTip("", 0, 0, 17), -2000)
                    return
                }
                else if (res != DISCORD_NOT_RUNNING) {
                    ShowCenteredToolTip "Failed to set Discord rich presence activity: " res, 17
                }
                SetTimer(() => ToolTip("", 0, 0, 17), -2000)
            }

            shownWarning := false
            return res
        }
    }
}

; Clears the current rich presence activity.
ClearRichPresence() {
    global currentActivity, richPresenceEnabled
    if (currentActivity = "")
        return

    currentActivity := ""

    if (richPresenceEnabled)
        res := SetActivity(RichPresenceCmd.CLEAR)
}

ShowNoSaveActivity() {
    SetActivity(RichPresenceCmd.NO_SAVE)
}

ShowFingerprintActivity() {
    SetActivity(RichPresenceCmd.FINGERPRINT)
}

ShowKeypadActivity() {
    SetActivity(RichPresenceCmd.KEYPAD)
}

ShowCayoFingerprintActivity() {
    SetActivity(RichPresenceCmd.CAYO_FINGERPRINT)
}

ShowLedgeGrabActivity() {
    SetActivity(RichPresenceCmd.LEDGE_GRAB)
}

; Shows the RPC tutorial prompt and returns true if the user wants to watch it, false otherwise.
ShowRPCTutorialPrompt() {
    g := Gui("+AlwaysOnTop -Caption", "Discord Tutorial")
    g.SetFont("s10", "Segoe UI")
    if (IsSet(guiApp)) {
        guiApp.Minimize()
    }
    g.MarginX := 15
    g.MarginY := 15

    g.AddText("w360",
        "Discord Rich Presence was added in v4.69.69.`n`n"
        . "Would you like to know how to use it?`n`n"
        . "This prompt will only be shown once."
    )

    btnWatch := g.AddButton("xm w170 h30", "Yes")
    btnSkip := g.AddButton("x+10 w170 h30", "No, I already know it")

    result := ""

    btnWatch.OnEvent("Click", (*) => (
        result := 0,
        g.Destroy()
    ))

    btnSkip.OnEvent("Click", (*) => (
        result := 1,
        g.Destroy()
    ))

    g.OnEvent("Close", (*) => (
        result := 1,
        g.Destroy()
    ))

    g.Show("AutoSize Center")

    WinWaitClose("ahk_id " g.Hwnd)

    if (result = 0) {
        Run("https://infpdev.netlify.app?vaultOps=5")
    }

    return result
}
