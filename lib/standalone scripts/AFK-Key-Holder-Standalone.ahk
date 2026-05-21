#Requires AutoHotkey v2.0
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
global afkKeyReg := ""
global afkToggleKeyReg := "Backspace"
global terminateKeyReg := CanonicalToRegistration(terminateKey)

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please run it again with the correct privileges.",
            "Error", 48
    }
    ExitApp
}

if (afkKey = "")
    afkKey := PromptForAfkKey()

RegisterAfkHotkey()
FocusGtaIfRunning()
SetTimer(WatchGtaWindow, 10000)
OnExit(Cleanup)

PromptForAfkKey() {
    global iniFile

    prompt := InputBox(
        "Enter the key to hold down.`nExample: W`nLeave blank to cancel.",
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
    } catch {
        MsgBox "Failed to register AFK toggle hotkey. Please check your settings.", "Hotkey Registration Failed", 48
        ExitApp
    }

    try {
        Hotkey("!" afkKeyReg, ChangeAfkKey, "On")
    } catch {
        MsgBox "Failed to register AFK key change hotkey. Please check your settings.", "Hotkey Registration Failed",
            48
        ExitApp
    }

    try {
        Hotkey("~*" terminateKeyReg, Terminate, "On")
    } catch {
        MsgBox "Failed to register Terminate hotkey. Please check your settings.", "Hotkey Registration Failed", 48
        ExitApp
    }

    UpdateAfkTooltip()
}

UnregisterAfkHotkey() {
    global afkKeyReg, afkToggleKeyReg, terminateKeyReg

    if (afkKeyReg = "")
        return

    try Hotkey("~*" afkToggleKeyReg, ToggleAfkHold, "Off")
    try Hotkey("!" afkKeyReg, ChangeAfkKey, "Off")
    try Hotkey("~*" terminateKeyReg, Terminate, "Off")
}

ChangeAfkKey(*) {
    global iniFile, afkHolding

    if (afkHolding)
        StopAfkHold()

    IniDelete(iniFile, "Other", "afkKey")
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
    global afkKeyReg, afkHolding

    if !FocusGtaIfRunning() {
        MsgBox "GTA is not running, so the AFK hold cannot start yet.", "AFK Helper", 48
        UpdateAfkTooltip()
        return
    }

    try {
        Send "{" afkKeyReg " down}"
        afkHolding := true
    } catch {
        afkHolding := false
        MsgBox "Failed to hold key.", "AFK Helper", 48
    }

    afkHolding := true
    UpdateAfkTooltip()
}

StopAfkHold(*) {
    global afkKeyReg, afkHolding

    try Send "{" afkKeyReg " up}"
    afkHolding := false
    UpdateAfkTooltip()
}

WatchGtaWindow(*) {
    UpdateAfkTooltip()

    if !isGtaFocused() {
        if (afkHolding) {
            StopAfkHold()
        }
    }
}

FocusGtaIfRunning() {
    UpdateAfkTooltip()

    if (hwnd := getGtaHwnd()) {
        try {
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 2
        }
        UpdateAfkTooltip()
        return true
    }

    UpdateAfkTooltip()
    return false
}

Terminate(*) {
    ExitApp
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

isGtaFocused() {
    return WinActive("ahk_exe GTA5.exe") || WinActive("ahk_exe GTA5_Enhanced.exe")
}

UpdateAfkTooltip() {
    global afkHolding, afkKeyReg

    keyLabel := StrTitle(GetAfkDisplayKey())
    terminateLabel := StrTitle(GetKeyName(terminateKeyReg))
    toggleText := "Press Backspace to " (afkHolding ? "stop" : "start") " sending " keyLabel
    changeText := "Press ALT+" keyLabel " to change key"
    terminateText := "Press " terminateLabel " to exit"
    ToolTip toggleText "`n" changeText "`n" terminateText, 0, 0, 17
    MakeAllToolTipsClickThrough(false)
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
