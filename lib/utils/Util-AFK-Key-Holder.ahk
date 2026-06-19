#Include "./initHotkeys.ahk"
#UseHook true

init()

/**
 * Entry point: sets SendMode, registers all hotkeys, reads/prompts for afkKey, shows tooltip, hooks OnExit.
 */
init() {
    global afkKey, iniFile

    SendMode "Event"
    SetWorkingDir A_ScriptDir
    SetKeyDelay 0, 0
    SetWinDelay 0
    SetControlDelay 0

    global afkHolding := false
    ; global terminateTimer := 2000 ; Time the terminate key must be held to exit, in milliseconds
    ; global lastTerminateHeld := 0
    global lastAntiAfkSent := 0
    global afkKeyReg := ""
    global afkToggleKeyReg := CanonicalToRegistration(toggleHotkey)
    global terminateKeyReg := CanonicalToRegistration(terminateKey)

    if (afkDelay != "" && afkDelay >= 0)
        global recallDelay := afkDelay * 1000
    else {
        IniWrite(60, iniFile, "Utility", "afkDelay") ; Default to 1 minute
        try PersistSettingsToAppData()
        global recallDelay := 1000 * 60 ; 1 minute between anti-afk key sends, in milliseconds
    }

    ; recallDelay := 10000 ; 10 seconds for testing

    if (afkKey = "")
        afkKey := PromptForAfkKey()

    RegisterAfkHotkey()
    UpdateTooltip()
    OnExit(Cleanup)

}

/**
 * Shows InputBox for the key to hold; validates it isn't the terminate hotkey; saves to INI + AppData.
 */
PromptForAfkKey() {
    global iniFile

    prompt := InputBox(
        "Enter the key to hold down.`nExample: W`nLeave blank to cancel and exit.`nCancel to exit script.",
        "AFK Key",
        "w360 h170"
    )

    if (prompt.Result = "Cancel")
        ExitApp

    newKey := Trim(prompt.Value)
    if (newKey = "")
        ExitApp

    if (!IsCanonicalHotkey(newKey))
        newKey := DisplayToCanonical(newKey)

    ; MsgBox newKey "`n" terminateKey
    if (GetKeyName(CanonicalToRegistration(newKey)) = GetKeyName(terminateKeyReg)) {
        MsgBox "The AFK key cannot be the same as the Terminate hotkey.", "AFK Helper", 48
        return PromptForAfkKey()
    }
    else if (newKey = "") {
        MsgBox "Please enter a valid key or key name.", "AFK Helper", 48
        return PromptForAfkKey()
    }

    IniWrite(newKey, iniFile, "Utility", "afkKey")
    try PersistSettingsToAppData()
    return newKey
}

/**
 * Clears stored afkKey from INI, reloads the script to re-prompt the user.
 */
ChangeAfkKey(*) {
    global iniFile, afkHolding

    if (!isGtaFocused(false)) {
        ShowCenteredToolTip("GTA must be focused to change the AFK key", 1)
        SetTimer UpdateTooltip, -5000
        return
    }

    if (afkHolding)
        StopAfkHold()

    IniWrite("", iniFile, "Utility", "afkKey")
    try PersistSettingsToAppData()
    Reload()
}

ToggleAfkHold(*) {
    global afkHolding

    if (afkHolding)
        StopAfkHold()
    else
        StartAfkHold()
}

StartAfkHold(*) {
    global afkHolding

    if (GtaNotRunning())
        return

    afkHolding := true
    UpdateTooltip()
    SetTimer SendAfkKeyOnce, 0
    SendAfkKeyOnce()
}

StopAfkHold(*) {
    global afkHolding, recallDelay, afkKeyReg
    if (recallDelay = 0)
        Send "{" afkKeyReg " up}"

    if (!isGtaFocused(false)) {
        ShowCenteredToolTip("GTA must be focused to disable the script", 1)
        SetTimer UpdateTooltip, -5000
        return
    }

    afkHolding := false
    ; MsgBox afkHolding
    UpdateTooltip()
}

/**
 * Timer callback: activates GTA window, moves mouse, sends the AFK key, restores previous window.
 * Re-schedules itself at recallDelay - 5000ms for countdown window.
 */
SendAfkKeyOnce(*) {
    global afkKeyReg, afkHolding, recallDelay

    if !afkHolding
        return

    ; TerminateHelper(lastTerminateHeld)

    gtaHwnd := getGtaHwnd()

    ShowCountDown(5000)

    if !afkHolding {
        UpdateTooltip()
        return
    }

    previousHwnd := WinExist("A")
    prevClass := WinGetClass("ahk_id " previousHwnd)
    gtaIsCurrent := (previousHwnd = gtaHwnd)

    if !gtaIsCurrent {
        try {
            WinActivate "ahk_id " gtaHwnd
            WinWaitActive "ahk_id " gtaHwnd, , 2
        } catch {
            SetTimer SendAfkKeyOnce, -recallDelay
            return
        }
    }

    SetKeyDelay 40, 1000

    try {
        if (recallDelay != 0) {
            ShowCenteredToolTip "Triggered Anti-AFK", 1

            DllCall("mouse_event", "UInt", 0x0001, "Int", Random(-500, 500), "Int", 0, "UInt", 0, "UPtr", 0)
            Send "{" afkKeyReg "}"
        } else {
            Send "{" afkKeyReg " down}"
        }

        global lastAntiAfkSent := A_TickCount

        UpdateTooltip()
    } catch {
        MsgBox "Failed to send AFK key.", "AFK Helper", 48
    }

    if !gtaIsCurrent && previousHwnd && WinExist("ahk_id " previousHwnd) {
        ; Don't restore desktop focus
        if (prevClass != "Progman" && prevClass != "WorkerW") {
            try WinActivate "ahk_id " previousHwnd
        }
    }

    if (recallDelay > 5000)
        SetTimer SendAfkKeyOnce, -(recallDelay - 5000)
    else
        SetTimer SendAfkKeyOnce, -recallDelay
}

Terminate(*) {
    static showedWarning := false
    global terminateKeyReg, afkHolding
    ; global lastTerminateHeld := A_TickCount

    if (isGtaFocused(false) || !afkHolding) {
        ExitApp
    }
    else {
        if (showedWarning)
            return

        ShowCenteredToolTip "GTA must be focused to terminate the script", 1

        SetTimer(() => (ToolTip()
        UpdateTooltip()), -5000)
        showedWarning := true
    }
}

/**
 * While terminate key is held, counts down via tooltip; exits script after terminateTimer (2s).
 */
; TerminateHelper(startedAt) {
;     global terminateKeyReg

;     while (GetKeyState(terminateKeyReg, "P")) {
;         UpdateTooltip(startedAt)
;         if (A_TickCount - startedAt > terminateTimer) {
;             ExitApp
;         }
;         Sleep 100
;     }
; }

/**
 * Shows a 1s-per-step countdown tooltip before next anti-AFK trigger (only if recallDelay > 5500ms).
 */
ShowCountDown(counterMs) {
    global afkHolding, lastAntiAfkSent, recallDelay

    if (!afkHolding || recallDelay <= 5500)
        return

    seconds := Ceil(counterMs / 1000)

    loop seconds {

        ; TerminateHelper(lastTerminateHeld)

        if (!afkHolding || A_TickCount - lastAntiAfkSent < 2000) {
            ; Anti-AFK was triggered again, stop countdown
            return
        }

        remaining := seconds - A_Index + 1
        ShowCenteredToolTip "Triggering Anti-AFK in " remaining, 1

        if (remaining != 0)
            Sleep 1000

    }
}

/**
 * Wires toggle (toggleHotkey), change-key (Alt+afkKey), and terminate hotkeys.
 */
RegisterAfkHotkey() {
    global afkKey, afkKeyReg, afkToggleKeyReg, terminateKeyReg

    afkKeyReg := CanonicalToRegistration(afkKey)
    if (afkKeyReg = "") {
        MsgBox "The AFK key setting is invalid.", "AFK Helper", 48
        ExitApp
    }

    try {
        Hotkey("~*" afkToggleKeyReg, ToggleAfkHold, "On")
    } catch as e {
        MsgBox "Failed to register AFK toggle hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

    try {
        Hotkey("!" afkKeyReg, ChangeAfkKey, "On")
    } catch as e {
        MsgBox "Failed to register AFK key change hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

}

GetAfkDisplayKey() {
    global afkKey, afkKeyReg

    if (afkKeyReg = "")
        return afkKey != "" ? afkKey : "key"

    if (IsCanonicalHotkey(afkKey))
        return GetKeyName(CanonicalToRegistration(afkKey))

    if (afkKey != "")
        return GetKeyName(CanonicalToRegistration(afkKey))

    return GetKeyName(afkKeyReg)
}

/**
 * Shows status tooltip: toggle/change-key/terminate instructions, or termination countdown.
 */
UpdateTooltip(terminationStart := 0) {
    global afkHolding, afkKeyReg, terminateKeyReg

    keyLabel := StrTitle(GetAfkDisplayKey())
    terminateLabel := StrTitle(GetKeyName(terminateKeyReg))
    toggleText := "Press " . CanonicalToDisplay(toggleHotkey) . " to " (afkHolding ? "stop" : "start") " sending " keyLabel
    changeText := "Press ALT+" keyLabel " to change key"
    terminateText := "Press " terminateLabel " to exit"
    ToolTip toggleText "`n" changeText "`n" terminateText, 0, 0
    MakeAllToolTipsClickThrough(false)
}

/**
 * OnExit: unregisters hotkeys, releases held key.
 */
Cleanup(*) {
    global afkHolding
    ; try UnregisterAfkHotkey()
    if (afkHolding)
        StopAfkHold()
}

/**
 * Releases held key, disables all hotkeys.
 */
UnregisterAfkHotkey() {
    global afkKeyReg, afkToggleKeyReg, terminateKeyReg

    if (afkKeyReg = "")
        return

    send "{" afkKeyReg " up}"

    try Hotkey("~*" afkToggleKeyReg, ToggleAfkHold, "Off")
    try Hotkey("!" afkKeyReg, ChangeAfkKey, "Off")
    try Hotkey("~*" terminateKeyReg, Terminate, "Off")
}

; Reset(*) {
;     global resetKeyReg, resetTimer
;     global lastResetKeyHeld := A_TickCount

;     resetHelper(lastResetKeyHeld)
; }

; resetHelper(startedAt) {
;     global resetKeyReg, resetTimer

;     while (GetKeyState(resetKeyReg, "P")) {
;         UpdateTooltip(startedAt)
;         if (A_TickCount - startedAt > resetTimer) {
;             ExitApp
;         }
;         Sleep 100
;     }

;     UpdateTooltip()

; }
