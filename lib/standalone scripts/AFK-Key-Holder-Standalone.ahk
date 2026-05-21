#Requires AutoHotkey v2.0

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please run it again with the correct privileges.",
            "Error", 48
    }
    ExitApp
}

#SingleInstance Force
#UseHook true
SendMode "Event"
SetWorkingDir A_ScriptDir
SetKeyDelay 0, 0
SetWinDelay 0
SetControlDelay 0
SetTitleMatchMode 2

#Include "../initHotkeys.ahk"

global afkHolding := false
global terminateTimer := 2000 ; Time the terminate key must be held to exit, in milliseconds
global lastTerminateHeld := 0
global lastAntiAfkSent := 0
global afkKeyReg := ""
global afkToggleKeyReg := CanonicalToRegistration("vk08sc00E") ; Backspace key for toggling AFK hold
global terminateKeyReg := CanonicalToRegistration(terminateKey)
global reloadKeyReg := CanonicalToRegistration(resetKey)

if (afkDelay != "" && afkDelay >= 0)
    global recallDelay := afkDelay * 1000
else {
    IniWrite(60, iniFile, "Other", "afkDelay") ; Default to 1 minute
    try PersistSettingsToAppData()
    global recallDelay := 1000 * 60 ; 1 minute between anti-afk key sends, in milliseconds
}

; recallDelay := 10000 ; 10 seconds for testing

if (afkKey = "")
    afkKey := PromptForAfkKey()

RegisterAfkHotkey()
FocusGtaIfRunning()
OnExit(Cleanup)

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

    IniWrite(newKey, iniFile, "Other", "afkKey")
    try PersistSettingsToAppData()
    return newKey
}

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

    try {
        Hotkey("~*" reloadKeyReg, ReloadScript, "On")
    } catch as e {
        MsgBox "Failed to register Reload hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

    try {
        Hotkey("~*" terminateKeyReg, Terminate, "On")
    } catch as e {
        MsgBox "Failed to register Terminate hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

    UpdateAfkTooltip()
}

UnregisterAfkHotkey() {
    global afkKeyReg, afkToggleKeyReg, terminateKeyReg, reloadKeyReg

    if (afkKeyReg = "")
        return

    send "{" afkKeyReg " up}"

    try Hotkey("~*" afkToggleKeyReg, ToggleAfkHold, "Off")
    try Hotkey("!" afkKeyReg, ChangeAfkKey, "Off")
    try Hotkey("~*" reloadKeyReg, Reload, "Off")
    try Hotkey("~*" terminateKeyReg, Terminate, "Off")
}

ChangeAfkKey(*) {
    global iniFile, afkHolding

    if (afkHolding)
        StopAfkHold()

    IniWrite("", iniFile, "Other", "afkKey")
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

    afkHolding := true
    UpdateAfkTooltip()
    SetTimer SendAfkKeyOnce, 0
    SendAfkKeyOnce()
}

StopAfkHold(*) {
    global afkHolding, recallDelay, afkKeyReg
    if (recallDelay = 0)
        Send "{" afkKeyReg " up}"

    afkHolding := false
    ; MsgBox afkHolding
    UpdateAfkTooltip()
}

SendAfkKeyOnce(*) {
    global afkKeyReg, afkHolding, recallDelay

    if !afkHolding
        return

    TerminateHelper(lastTerminateHeld)

    gtaHwnd := getGtaHwnd()
    if !gtaHwnd {
        afkHolding := false
        ShowCenteredToolTip "GTA not detected. Script can only be used when GTA is running.", 17
        sleep 5000
        UpdateAfkTooltip()
        ; SetTimer SendAfkKeyOnce, -recallDelay
        return
    }

    ShowCountDown(5000)

    if !afkHolding {
        UpdateAfkTooltip()
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
            ShowCenteredToolTip "Triggered Anti-AFK", 17

            DllCall("mouse_event", "UInt", 0x0001, "Int", Random(-500, 500), "Int", 0, "UInt", 0, "UPtr", 0)
            Send "{" afkKeyReg "}"
        } else {
            Send "{" afkKeyReg " down}"
        }

        global lastAntiAfkSent := A_TickCount

        UpdateAfkTooltip()
    } catch {
        MsgBox "Failed to send AFK key.", "AFK Helper", 48
    }

    if !gtaIsCurrent && previousHwnd && WinExist("ahk_id " previousHwnd) {
        ; Don't restore desktop focus
        if (prevClass != "Progman" && prevClass != "WorkerW") {
            try WinActivate "ahk_id " previousHwnd
        }
    }

    ; SetTimer(() => ShowCountDown(5000), -(recallDelay - 5000))

    if (recallDelay > 5000)
        SetTimer SendAfkKeyOnce, -(recallDelay - 5000)
    else
        SetTimer SendAfkKeyOnce, -recallDelay
}

FocusGtaIfRunning() {
    if (hwnd := getGtaHwnd()) {
        try {
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 2
        }
        UpdateAfkTooltip()
    }
}

ReloadScript(*) {
    Reload
}

Terminate(*) {
    global terminateKeyReg, terminateTimer
    global lastTerminateHeld := A_TickCount

    TerminateHelper(lastTerminateHeld)

    UpdateAfkTooltip()
    ; ExitApp
}

TerminateHelper(startedAt) {
    global terminateKeyReg, terminateTimer

    while (GetKeyState(terminateKeyReg, "P")) {
        UpdateAfkTooltip(startedAt)
        if (A_TickCount - startedAt > terminateTimer) {
            ExitApp
        }
        Sleep 100
    }
}

Cleanup(*) {
    global afkHolding
    try UnregisterAfkHotkey()
    if (afkHolding)
        StopAfkHold()
}

getGtaHwnd() {
    static gtaMatchers := [
        "ahk_exe GTA5_Enhanced.exe",
        "ahk_exe GTA5_Enhanced",
        "ahk_exe GTA5.exe",
        "ahk_exe GTA5"
    ]

    for matcher in gtaMatchers {
        if hwnd := WinExist(matcher)
            return hwnd
    }

    return 0
}

UpdateAfkTooltip(terminationStart := 0) {
    global afkHolding, afkKeyReg, terminateKeyReg, terminateTimer

    if (terminationStart > 0) {

        ToolTip "Terminating script in " .
            (Integer(terminateTimer / 1000) -
            Floor((A_TickCount - terminationStart) / 1000))
            . "s`nRelease the key to cancel.", 0, 0, 17

        MakeAllToolTipsClickThrough(false)
        return
    }

    keyLabel := StrTitle(GetAfkDisplayKey())
    terminateLabel := StrTitle(GetKeyName(terminateKeyReg))
    resetKeyLabel := StrTitle(GetKeyName(reloadKeyReg))
    toggleText := "Press Backspace to " (afkHolding ? "stop" : "start") " sending " keyLabel
    changeText := "Press ALT+" keyLabel " to change key"
    resetText := "Press " resetKeyLabel " to reload script"
    terminateText := "Hold " terminateLabel " for " . Integer(terminateTimer / 1000) . "s to exit"
    ToolTip toggleText "`n" changeText "`n" resetText "`n" terminateText, 0, 0, 17
    MakeAllToolTipsClickThrough(false)
}

ShowCountDown(counterMs) {
    global afkHolding, lastAntiAfkSent, lastTerminateHeld, recallDelay

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
        ShowCenteredToolTip "Triggering Anti-AFK in " remaining, 17

        if (remaining != 0)
            Sleep 1000

    }
}

MakeAllToolTipsClickThrough(isIdle, opacity := 230) {
    alpha := Integer(opacity) ? opacity : 255
    alpha := Max(0, Min(255, alpha))

    if (isIdle)
        alpha := 180

    hwnd := 0
    while (hwnd := DllCall("FindWindowEx", "ptr", 0, "ptr", hwnd, "str", "tooltips_class32", "ptr", 0, "ptr")) {
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        exStyle |= 0x20 | 0x80000
        DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr", exStyle)
        DllCall("SetLayeredWindowAttributes", "ptr", hwnd, "uint", 0, "uchar", alpha, "uint", 0x2)
    }
}

ShowCenteredToolTip(text, id := 10, y := 0) {
    ; Measure text width to center tooltip
    hdc := DllCall("GetDC", "ptr", 0)

    ; Create font (adjust if needed)
    hfont := DllCall("GetStockObject", "int", 0)  ; DEFAULT_GUI_FONT
    DllCall("SelectObject", "ptr", hdc, "ptr", hfont)

    size := Buffer(8)
    DllCall("GetTextExtentPoint32", "ptr", hdc, "str", text, "int", StrLen(text), "ptr", size)
    width := NumGet(size, 0, "int")

    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

    ; Center horizontally, position Y at parameter or top
    centerX := (A_ScreenWidth // 2) - 0.9 * (width // 2)  ; Adjust for slight visual centering
    centerY := y > 0 ? y : 0

    ToolTip(text, centerX, centerY, id)
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
