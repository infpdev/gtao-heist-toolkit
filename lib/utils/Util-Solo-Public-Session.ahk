#Include "./initHotkeys.ahk"

init()

/**
 * Entry point: registers toggle hotkey, shows tooltip, hooks OnExit cleanup.
 */
init() {

    global SOLO_RULE_NAME := "VaultOps-SoloSession"
    global shouldBlock := false

    try {
        Hotkey("~*" CanonicalToRegistration(toggleHotkey), ToggleBlockGtaUdp, "On")
    } catch as e {
        MsgBox "Failed to register AFK toggle hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

    UpdateTooltip()
    OnExit(CleanUp)
}

ToggleBlockGtaUdp(*) {
    global shouldBlock

    if (shouldBlock)
        UnblockGtaUdp()
    else
        BlockGtaUdp()
}

/**
 * Creates firewall rules blocking all UDP on GTA5.exe/GTA5_Enhanced.exe process. Returns true on success.
 */
BlockGtaUdp() {
    global SOLO_RULE_NAME

    if (GtaNotRunning())
        return

    global shouldBlock := true

    fwPolicy := GetFirewallPolicy()
    if !fwPolicy
        return false

    exePath := GetProcessPath("GTA5.exe")

    if (exePath = "")
        exePath := GetProcessPath("GTA5_Enhanced.exe")

    if (exePath = "") {
        MsgBox(
            "Could not find active GTA process.`nPlease run GTA V or GTA V Enhanced.",
            "Solo Session",
            48
        )
        return false
    }

    try fwPolicy.Rules.Remove(SOLO_RULE_NAME "-IN")

    try fwPolicy.Rules.Remove(SOLO_RULE_NAME "-OUT")

    try {

        ruleIn := ComObject("HNetCfg.FWRule")
        ruleIn.Name := SOLO_RULE_NAME "-IN"
        ruleIn.Description := "VaultOps GTA UDP inbound block"
        ruleIn.Direction := 1
        ruleIn.Action := 0
        ruleIn.Enabled := true
        ruleIn.Protocol := 17
        ruleIn.ApplicationName := exePath
        fwPolicy.Rules.Add(ruleIn)

        ruleOut := ComObject("HNetCfg.FWRule")
        ruleOut.Name := SOLO_RULE_NAME "-OUT"
        ruleOut.Description := "VaultOps GTA UDP outbound block"
        ruleOut.Direction := 2
        ruleOut.Action := 0
        ruleOut.Enabled := true
        ruleOut.Protocol := 17
        ruleOut.ApplicationName := exePath
        fwPolicy.Rules.Add(ruleOut)

        UpdateTooltip()

        return true
    } catch {
        ToolTip()
        return false
    }
}

/**
 * Removes both UDP firewall rules.
 */
UnblockGtaUdp() {
    global SOLO_RULE_NAME
    global shouldBlock := false

    fwPolicy := GetFirewallPolicy()
    if !fwPolicy
        return false

    try fwPolicy.Rules.Remove(SOLO_RULE_NAME "-IN")

    try fwPolicy.Rules.Remove(SOLO_RULE_NAME "-OUT")

    UpdateTooltip()

    return true
}

/**
 * Returns the HNetCfg.FwPolicy2 COM object, or empty string on failure.
 */
GetFirewallPolicy() {
    try {
        return ComObject("HNetCfg.FwPolicy2")
    } catch {
        return ""
    }
}

/**
 * Gets the full exe path of a running process by name via QueryFullProcessImageNameW.
 */
GetProcessPath(processName) {
    pid := ProcessExist(processName)
    if !pid
        return ""

    PROCESS_QUERY_LIMITED_INFORMATION := 0x1000

    hProcess := DllCall(
        "OpenProcess",
        "UInt", PROCESS_QUERY_LIMITED_INFORMATION,
        "Int", false,
        "UInt", pid,
        "Ptr"
    )

    if !hProcess
        return ""

    size := 32767
    buf := Buffer(size * 2, 0)

    success := DllCall(
        "Kernel32\QueryFullProcessImageNameW",
        "Ptr", hProcess,
        "UInt", 0,
        "Ptr", buf,
        "UInt*", &size,
        "Int"
    )

    DllCall("CloseHandle", "Ptr", hProcess)

    return success ? StrGet(buf) : ""
}

UpdateTooltip() {
    global shouldBlock
    BlockedText := "GTA networking blocked. Attempting to switch to solo session`n"
    ToggleText := "Press " . CanonicalToDisplay(toggleHotkey) . " to " (shouldBlock ? "cancel" :
        "switch to solo session")
    TerminateText := "`nPress " . StrTitle(CanonicalToDisplay(terminateKey)) . " to terminate the script"
    ToolTip (shouldBlock ? BlockedText : "") . ToggleText . TerminateText, 0, 0
    MakeAllToolTipsClickThrough(false)
}

Terminate(*) {
    UnblockGtaUdp()
    ExitApp
}

/**
 * OnExit: ensures firewall rules are removed.
 */
CleanUp(*) {
    UnblockGtaUdp()
}
