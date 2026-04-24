#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetWorkingDir A_ScriptDir
SetKeyDelay 0
SetWinDelay 0
SetBatchLines := -1
SetControlDelay 0
SetTitleMatchMode 2

#Include "../initHotkeys.ahk"
#Include "../commonFuncs.ahk"
global noSaveActive := false

global firstFirewallCheckDone := false
global NOSAVE_RULE_NAME := "123456"
global NOSAVE_REMOTE_IP := "192.81.241.171"

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please run it again with the correct privileges.",
            "Error", 48
    }
    ExitApp
}

UpdateTooltip() {
    global noSaveActive
    status := noSaveActive ? "NoSave: enabled" : "NoSave: disabled"
    key := (noSaveActive ? "Press " noSaveKey " to disable" : "Press " noSaveKey " to enable") (
        "`nExit: " terminateKey
    )
    ToolTip(status "`n" key, A_ScreenWidth, 0, 20)
}

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

init()

init() {
    isFirewallEnabled()
    UpdateTooltip()

    try Hotkey("~*" CanonicalToRegistration(noSaveKey), ToggleNoSaveMode, "On")
    try Hotkey("~*" CanonicalToRegistration(terminateKey), (*) => ExitApp(), "On")
}

; =================================================================================================⏐
; ================================== Shared functions start here ==================================⏐
; =================================================================================================⏐
{
    global forMode := ""

    OnExit(AppExit)

    ; Returns the Windows Firewall policy COM object, or empty string on failure.
    GetFirewallPolicy() {
        try {
            return ComObject("HNetCfg.FwPolicy2")
        } catch {
            return ""
        }
    }

    EnableNoSaveMode(*) {
        global NOSAVE_RULE_NAME, NOSAVE_REMOTE_IP, forMode
        fwPolicy := GetFirewallPolicy()
        if !fwPolicy {
            IniWrite(false, iniFile, "Options", "NoSave")
            return false
        }

        try fwPolicy.Rules.Remove(NOSAVE_RULE_NAME)

        try {
            rule := ComObject("HNetCfg.FWRule")
            rule.Name := NOSAVE_RULE_NAME
            rule.Description := "VaultOps NoSave outbound block rule"
            rule.Direction := 2
            rule.Action := 0
            rule.Enabled := true
            rule.Protocol := 256
            rule.RemoteAddresses := NOSAVE_REMOTE_IP
            fwPolicy.Rules.Add(rule)
        } catch {
            IniWrite(false, iniFile, "Options", "NoSave")
            return false
        }

        enabled := IsNoSaveRuleActive()
        if (enabled) {
            ShowCenteredToolTip("NoSave enabled [Works]", 17)
            SetTimer () => clearNoSaveToolTip("enabled"), -2000
            forMode := "enabled"
        }
        IniWrite(enabled, iniFile, "Options", "NoSave")
        return enabled

    }

    ; Removes the NoSave firewall rule and returns true when it is gone.
    DisableNoSaveMode(*) {
        global NOSAVE_RULE_NAME, forMode
        fwPolicy := GetFirewallPolicy()
        if !fwPolicy {
            IniWrite(true, iniFile, "Options", "NoSave")
            return false
        }

        try fwPolicy.Rules.Remove(NOSAVE_RULE_NAME)

        disabled := !IsNoSaveRuleActive()
        if (disabled) {
            ShowCenteredToolTip("NoSave disabled", 17)
            SetTimer () => clearNoSaveToolTip("disabled"), -2000
            forMode := "disabled"
        }

        if FileExist(iniFile)
            IniWrite(!disabled, iniFile, "Options", "NoSave")
        return disabled

    }

    ; Returns true when every active Windows Firewall profile is enabled.
    IsFirewallOnActiveProfile() {
        fwPolicy := GetFirewallPolicy()
        if !fwPolicy
            return false

        try {
            activeMask := fwPolicy.CurrentProfileTypes
            for profileType in [1, 2, 4] {
                if (activeMask & profileType) {
                    if !fwPolicy.FirewallEnabled(profileType)
                        return false
                }
            }
            return true
        } catch {
            return false
        }
    }

    ; Ensures the firewall is enabled for the active profile(s).
    isFirewallEnabled() {
        global firstFirewallCheckDone
        if IsFirewallOnActiveProfile() {
            if (!firstFirewallCheckDone) {
                ShowCenteredToolTip("Firewall check passed :]", 17)
                SetTimer () => ToolTip("", , , 17), -2000
            }
            firstFirewallCheckDone := true
            return true ; Already on, do nothing
        }

        fwPolicy := GetFirewallPolicy()
        if fwPolicy {
            try {
                activeMask := fwPolicy.CurrentProfileTypes
                for profileType in [1, 2, 4] {
                    if (activeMask & profileType)
                        fwPolicy.FirewallEnabled[profileType] := true
                }
            }
        }

        Sleep 300
        if IsFirewallOnActiveProfile() {
            if (!firstFirewallCheckDone)
                ShowCenteredToolTip("Firewall check passed :]", 17)
            SetTimer () => ToolTip("", , , 17), -2000
            firstFirewallCheckDone := true
            return true

        }
        firstFirewallCheckDone := false
        MsgBox "Windows Firewall appears to be inactive!`nPlease enable it for proper operation.", "FIREWALL WARNING",
            48
        return false
    }

    ; Returns true when the NoSave rule exists.
    IsNoSaveRuleActive() {
        global NOSAVE_RULE_NAME, NOSAVE_REMOTE_IP
        fwPolicy := GetFirewallPolicy()
        if !fwPolicy
            return false

        try {
            rule := fwPolicy.Rules.Item(NOSAVE_RULE_NAME)
            if (rule.Direction != 2 || rule.Action != 0 || !rule.Enabled)
                return false
            if !InStr(rule.RemoteAddresses, NOSAVE_REMOTE_IP)
                return false
            return true
        }
        return false
    }

    clearNoSaveToolTip(localMode) {
        if (forMode == localMode)
            ToolTip("", , , 17)
    }

    ; Cleans up the NoSave rule on exit.
    AppExit(*) {
        if FileExist(iniFile) {
            DisableNoSaveMode()
            IniWrite(0, iniFile, "Options", "scriptsEnabled")
        }
        ToolTip("", , , 17)
    }

}
