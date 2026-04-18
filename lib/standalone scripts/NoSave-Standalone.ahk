#Requires AutoHotkey v2.0

#Include "../initHotkeys.ahk"
#Include "../commonFuncs.ahk"

#SingleInstance Ignore
SendMode "Input"
SetWorkingDir A_ScriptDir
SetKeyDelay 0
SetWinDelay 0
SetBatchLines := -1
SetControlDelay 0
SetTitleMatchMode 2

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please run it again with the correct privileges.",
            "Error", 48
    }
    ExitApp
}

global firstFirewallCheckDone := false, noSaveActive := false

UpdateTooltip() {
    global noSaveActive
    status := noSaveActive ? "NoSave: enabled" : "NoSave: disabled"
    key := (noSaveActive ? "Press " noSaveKey " to disable" : "Press " noSaveKey " to enable") (
        "`nExit: " terminateKey
    )
    ToolTip(status "`n" key, A_ScreenWidth, 0, 20)
}

init() {
    isFirewallEnabled()
    UpdateTooltip()
    Hotkey("~*" noSaveKey, ToggleNoSaveMode, "On")
    Hotkey("~*" terminateKey, (*) => ExitApp(), "On")
}

init()

ToggleNoSaveMode(*) {
    global noSaveActive

    if noSaveActive {
        if DisableNoSaveMode() {
            noSaveActive := false
        }
    } else {
        if EnableNoSaveMode() {
            noSaveActive := true
        }
    }
    UpdateTooltip()
}

OnExit(AppExit)

; ========== Shared functions start here =========

EnableNoSaveMode(*) {
    RunWait('netsh advfirewall firewall add rule name="123456" dir=out action=block remoteip="192.81.241.171"', ,
        "Hide")
    enabled := IsNoSaveRuleActive()
    if (enabled) {
        ShowCenteredToolTip("NoSave enabled [Works]", 17)
        SetTimer () => ToolTip("", , , 17), -2000 ; Clear tooltip after 2 second
    }
    return enabled

}

DisableNoSaveMode(*) {
    RunWait('netsh advfirewall firewall delete rule name="123456"', , "Hide")
    disabled := !IsNoSaveRuleActive()
    if (disabled) {
        ShowCenteredToolTip("NoSave disabled", 17)
        SetTimer () => ToolTip("", , , 17), -2000 ; Clear tooltip after 2 second
    }
    return disabled

}

AppExit(*) {
    RunWait('netsh advfirewall firewall delete rule name="123456"', , "Hide")
}

IsFirewallOnActiveProfile() {
    ; Returns true if Windows Firewall is ON for the active profile only
    result := ''
    try {
        outFile := A_Temp "\fwstatus.txt"
        cmd := '"' A_ComSpec '" /c netsh advfirewall show currentprofile > "' outFile '"'
        RunWait(cmd, , "Hide")
        if !FileExist(outFile) {
            MsgBox "Output file not created."
            return false
        }
        result := FileRead(outFile)
    } catch {
        MsgBox "Exception: " A_LastError
        return false
    }
    ; MsgBox result ; Uncomment to debug output
    ; MsgBox result
    ; Try a more robust regex: match 'State' followed by any non-newline, then 'ON' (handles tabs, colons, spaces)
    found := RegExMatch(result, "State\s*[:]?\s*ON")
    ; Debug: show what was matched
    ; MsgBox "RegExMatch found: " found
    return found ? true : false
}

; --- Firewall check at startup ---
; First check if firewall is already on, if not, try to enable it. If it still isn't on, show a warning message.
isFirewallEnabled() {
    global firstFirewallCheckDone
    if IsFirewallOnActiveProfile() {
        if (!firstFirewallCheckDone)
            ShowCenteredToolTip("Firewall check passed :]", 17)
        SetTimer () => ToolTip("", , , 17), -2000 ; Clear tooltip after 2 second
        firstFirewallCheckDone := true
        return true ; Already on, do nothing
    }
    ; Try to enable firewall for active profile
    RunWait 'netsh advfirewall set currentprofile state on', , "Hide"
    Sleep 500
    if IsFirewallOnActiveProfile() {
        if (!firstFirewallCheckDone)
            ShowCenteredToolTip("Firewall check passed :]", 17)
        SetTimer () => ToolTip("", , , 17), -2000 ; Clear tooltip after 2 second
        firstFirewallCheckDone := true
        return true

    }
    firstFirewallCheckDone := false
    MsgBox "Windows Firewall appears to be inactive!`nPlease enable it for proper operation.", "FIREWALL WARNING",
        48
    return false
}

; Checks if the firewall rule '123456' exists. Returns true if it exists, false otherwise. Shows a debug tooltip with the result.
IsNoSaveRuleActive() {
    ruleName := "123456"
    outFile := A_Temp "\fw_rule_status.txt"
    cmd := '"' A_ComSpec '" /c netsh advfirewall firewall show rule name="' ruleName '" > "' outFile '"'
    RunWait(cmd, , "Hide")
    if !FileExist(outFile) {
        return false
    }
    result := FileRead(outFile)
    found := InStr(result, ruleName)
    return found ? true : false
}
