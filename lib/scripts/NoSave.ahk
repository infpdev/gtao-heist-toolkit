#Requires AutoHotkey v2.0

global firstFirewallCheckDone := false

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please run it again with the correct privileges.",
            "Error", 48
    }
    ExitApp
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
    IniWrite(enabled, iniFile, "Options", "NoSave")
    return enabled

}

DisableNoSaveMode(*) {
    RunWait('netsh advfirewall firewall delete rule name="123456"', , "Hide")
    disabled := !IsNoSaveRuleActive()
    if (disabled) {
        ShowCenteredToolTip("NoSave disabled", 17)
        SetTimer () => ToolTip("", , , 17), -2000 ; Clear tooltip after 2 second
    }
    IniWrite(!disabled, iniFile, "Options", "NoSave")
    return disabled

}

; Removes the firewall rule '123456' if it exists,
; effectively disabling NoSave mode. This is called on script exit to
; ensure the rule doesn't persist.
AppExit(*) {
    DisableNoSaveMode()
    ToolTip("", , , 17) ; Clear any existing tooltips
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
