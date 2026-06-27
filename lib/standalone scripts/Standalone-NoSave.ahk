#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ../initHotkeys.ahk
#Include ../updateCheck.ahk

global noSaveActive := false

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
    key := (noSaveActive ? "Press " CanonicalToDisplay(noSaveKey) " to disable"
        : "Press " CanonicalToDisplay(noSaveKey) " to enable") (
            "`nExit: " CanonicalToDisplay(terminateKey)
    )
    ToolTip(status "`n" key, A_ScreenWidth, 0, 20)

    MakeAllToolTipsClickThrough(false)
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

OnExit(PersistSettingsToAppData)

init()

init() {
    isFirewallEnabled()
    UpdateTooltip()

    FocusGtaIfRunning()

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
            ; IniWrite(false, iniFile, "Options", "NoSave") ; Not needed, main app stores it in memory.
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
            ; IniWrite(false, iniFile, "Options", "NoSave") ; Not needed, main app stores it in memory.
            errMsg()
            return false
        }

        enabled := IsNoSaveRuleActive(fwPolicy)
        if (enabled) {
            ShowCenteredToolTip("NoSave enabled [Works]", 17)

            try isRockstarServerBlocked()

            SetTimer () => clearNoSaveToolTip("enabled"), -2000
            forMode := "enabled"
            return true
        } else {
            errMsg()
            return false
        }
        ; IniWrite(enabled, iniFile, "Options", "NoSave") ; Not needed, main app stores it in memory.

        errMsg() {
            MsgBox "Failed to enable NoSave mode. Please ensure you have the necessary permissions and that your firewall supports the required rules.",
                "FIREWALL WARNING", 48
        }

        isRockstarServerBlocked() {
            ip := NOSAVE_REMOTE_IP

            ; Create ICMP handle
            hPort := DllCall("Icmp.dll\IcmpCreateFile", "Ptr")
            if (!hPort)
                return false

            ; Convert IP string -> uint
            addr := DllCall("Ws2_32\inet_addr", "AStr", ip, "UInt")

            ; Reply buffer
            replySize := 1024
            replyBuf := Buffer(replySize, 0)

            ; Send ICMP echo
            result := DllCall(
                "Icmp.dll\IcmpSendEcho",
                "Ptr", hPort,
                "UInt", addr,
                "Ptr", 0,
                "UShort", 0,
                "Ptr", 0,
                "Ptr", replyBuf,
                "UInt", replySize,
                "UInt", 1000,
                "UInt"
            )

            ; Read returned status code from ICMP_ECHO_REPLY
            ; Status is at offset 4
            status := NumGet(replyBuf, 4, "UInt")

            DllCall("Icmp.dll\IcmpCloseHandle", "Ptr", hPort)

            ; 11050 = IP_GENERAL_FAILURE
            ; Means Windows/network stack blocked locally
            if (status = 11050)
                return true

            ; anything else = traffic probably escaped
            MsgBox(
                "Warning: VaultOps detected that NoSave may not be working correctly.`n`n"
                .
                "This is usually caused by third-party antivirus or firewall apps overriding Windows Firewall settings."
                .
                "`n`nIf you use apps like Kaspersky, BitDefender, SimpleWall, etc., try temporarily disabling them or checking their firewall settings."
                .
                "`n`nYou can verify whether NoSave is working by pressing Alt + F4 in GTA Online."
                .
                "`nIf the game does not show a 'Save Failed' message, then NoSave is likely not active."
                , "FIREWALL WARNING", 48
            )
        }

    }

    ; Removes the NoSave firewall rule and returns true when it is gone.
    DisableNoSaveMode(*) {
        global NOSAVE_RULE_NAME, forMode
        fwPolicy := GetFirewallPolicy()
        if !fwPolicy {
            ; IniWrite(true, iniFile, "Options", "NoSave") ; Not needed, main app stores it in memory.
            return false
        }

        try fwPolicy.Rules.Remove(NOSAVE_RULE_NAME)

        disabled := !IsNoSaveRuleActive(fwPolicy)
        if (disabled) {
            ShowCenteredToolTip("NoSave disabled", 17)
            SetTimer () => clearNoSaveToolTip("disabled"), -2000
            forMode := "disabled"
            return true
        } else {
            errMsg()
            return false
        }

        errMsg() {
            MsgBox "Failed to disable NoSave mode. Please check your firewall settings and try again.",
                "FIREWALL WARNING", 48
        }

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
    isFirewallEnabled(isJustAToggle := false) {
        fwPolicy := GetFirewallPolicy()
        if IsFirewallOnActiveProfile() {
            if (!isJustAToggle) {
                ShowCenteredToolTip("Firewall check passed :]", 17)
                SetTimer () => ToolTip("", , , 17), -2000
                CleanupLegacyDuplicateRules()
            }
            return true ; Already on, do nothing
        }

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
            ShowCenteredToolTip("Firewall check passed :]", 17)
            SetTimer () => ToolTip("", , , 17), -2000

            return true

        }

        MsgBox "Windows Firewall appears to be inactive!`nPlease enable it for proper operation.",
            "FIREWALL WARNING",
            48
        return false
    }

    ; Returns true when the NoSave rule exists.
    IsNoSaveRuleActive(fwPolicy) {
        global NOSAVE_RULE_NAME, NOSAVE_REMOTE_IP
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

    ; Optional cleanup: finds rules blocking the same IP as ours (legacy/faulty/conflicting).
    ; Only removes if user explicitly chooses to. Safe to remove this entire function without side effects.
    CleanupLegacyDuplicateRules() {
        global NOSAVE_RULE_NAME, NOSAVE_REMOTE_IP
        fwPolicy := GetFirewallPolicy()
        if !fwPolicy
            return

        conflictingRules := []
        try for r in fwPolicy.Rules {
            try {
                ; Find rules that reference our IP but are NOT our canonical rule description
                if InStr(r.RemoteAddresses, NOSAVE_REMOTE_IP)
                    conflictingRules.Push(r.Name)
            } catch {

            }
        }

        if (conflictingRules.Length = 0)
            return

        ; Found other rules blocking the same IP
        msg := "Found conflicting firewall rules blocking " NOSAVE_REMOTE_IP ".`n`n"
        msg .= "These rules might cause issues while joining sessions:`n`n"
        for ruleName in conflictingRules {
            msg .= " - " ruleName "`n"
        }
        msg .= "`nDo you want to remove the conflicting rules?"
        choice := MsgBox(msg, "Conflicting Firewall Rules Found", 0x4 " " 0x30) ; Yes/No, Question
        if (choice != "Yes")
            return

        for ruleName in conflictingRules {
            try fwPolicy.Rules.Remove(ruleName)
        }
    }

    clearNoSaveToolTip(localMode) {
        if (forMode == localMode)
            ToolTip("", , , 17)
    }

    ; Cleans up the NoSave rule on exit.
    AppExit(*) {
        if FileExist(iniFile) {
            DisableNoSaveMode()
        }
        ToolTip("", , , 17)
    }

}
