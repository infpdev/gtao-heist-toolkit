#Include initHotkeys.ahk
#Include updateCheck.ahk
#Include commonFuncs.ahk
#Include scripts\NoSave.ahk

SendMode("Event")
SetWorkingDir A_ScriptDir
CoordMode "ToolTip", "Screen"
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
#SingleInstance Force
SetTitleMatchMode 2
SetControlDelay 1
SetWinDelay 0
SetMouseDelay -1
SetBatchLines := -1

global scrW := A_ScreenWidth, scrH := A_ScreenHeight
global hackMode := "idle", hackInProgress := false
global fingerprintMode := true, debug := false
global heist := DIAMOND_CASINO
global pgUpSent := false

global readableNoSaveKey := StrLen(noSaveKey) > 1 ? AHKToDisplayHotkey(noSaveKey) : noSaveKey
global readableScriptsKey := StrLen(toggleScriptsKey) > 1 ? AHKToDisplayHotkey(toggleScriptsKey) : toggleScriptsKey
global readableSendPgUpKey := StrLen(sendPgUpKey) > 1 ? AHKToDisplayHotkey(sendPgUpKey) : sendPgUpKey
global readableManualKey := StrLen(manualKey) > 1 ? AHKToDisplayHotkey(manualKey) : manualKey
global readableAutoHackKey := StrLen(autoHackKey) > 1 ? AHKToDisplayHotkey(autoHackKey) : autoHackKey
global readableResetKey := StrLen(resetKey) > 1 ? AHKToDisplayHotkey(resetKey) : resetKey

Hotkey "~*" noSaveKey, ToggleNoSaveStatus
Hotkey "~*" resetKey, ReloadScript
Hotkey "~*" terminateKey, ExitScript

SetTimer(() => (isFirewallEnabled()), -3000)

F2:: Reload

; --- Common Functions ---

ReloadScript(*) {
    Reload
}

ExitScript(*) {
    ExitApp
}

ResetHackMode() {
    global hackMode
    hackMode := "idle"
    clearAllToolTips()
}

/**
 * Updates the status tooltip with current hack state, mode, and hotkey info.
 * Called by heist instances to reflect changes in state.
 * 
 * @param {bool} isHacking - Whether a hack is currently in progress
 * @param {bool} isTimingOut - Whether a timeout is active (optional)
 * @param {int} timeoutProgress - Seconds remaining in timeout (optional)
 * 
 * Side effects: Updates tooltip and calls MakeAllToolTipsClickThrough().
 */
UpdateGlobalStatus(isHacking, isTimingOut := false, timeoutProgress := 0, *) {
    global hackInProgress, readableNoSaveKey, readableScriptsKey, readableSendPgUpKey, readableManualKey,
        readableAutoHackKey, readableResetKey, pgUpSent

    if (pgUpSent)
        return ; Don't update status while PgUp is being sent to avoid tooltip interference

    noSaveText := "Press " readableNoSaveKey " to " (noSave ? "disable" : "enable") " NoSave"

    if (isTimingOut) {
        status := "Timeout in " timeoutProgress "s"
        ToolTip(status, scrW, 0, 20)
        MakeAllToolTipsClickThrough(hackMode == "idle")
        return
    }

    if (hackMode == "idle") {
        if (heist == DIAMOND_CASINO) {
            hackStatus := fingerprintMode ? "Fingerprint mode (idle)" : "Keypad mode (idle)"
        } else if (heist == CAYO_PERICO) {
            hackStatus := "El Rubio mode (idle)"
        } else {
            hackStatus := "Unknown mode (idle)"
        }
    } else {
        if (isHacking) {
            if (heist == CAYO_PERICO) {
                hackStatus := "El Rubio mode "
                hackStatus .= (hackMode == "manual") ? "(Manual)" : "(Hacking)"
                hackInProgress := true
            }
            else if (heist == DIAMOND_CASINO) {
                hackStatus := (fingerprintMode ? "Fingerprint mode " : "Keypad mode ")
                hackStatus .= (hackMode == "manual") ? "(Manual)" : "(Hacking)"
                hackInProgress := true
            } else {
                hackStatus := "Unknown mode (hacking)"
            }
        } else {
            if (heist == CAYO_PERICO) {
                hackStatus := "El Rubio mode " (hackMode == "manual" ? "(Manual)" : "(Auto)")
            }
            else if (heist == DIAMOND_CASINO) {
                hackStatus := "Waiting for " (fingerprintMode ? "fingerprint" : "keypad") " " ((hackMode ==
                    "manual") ?
                    "(Manual)" : "(Auto)")
                hackInProgress := false
            } else {
                hackStatus := "Unknown mode (waiting)"
            }
        }
    }
    indicator := "🟢 "
    keys := (heist == CAYO_PERICO ? "Send PgUp: " readableSendPgUpKey "`n" :
        "")

    keys .= (hackMode == "manual" ? indicator : "") "Manual: " readableManualKey "`n" (hackMode == "auto" ? indicator :
        "") "Auto: " readableAutoHackKey "`nReset: " readableResetKey

    ToolTip(hackStatus "`n" noSaveText "`n" keys, scrW, 0, 20)

    MakeAllToolTipsClickThrough(hackMode == "idle")
}

ToggleNoSaveStatus(*) {
    global noSave
    noSave := !noSave

    if (noSave && !isFirewallEnabled()) {
        noSave := false
    }
    UpdateGlobalStatus(hackInProgress)

    noSave ? EnableNoSaveMode() : DisableNoSaveMode()

    if (noSave && !IsNoSaveRuleActive()) {
        noSave := false
        UpdateGlobalStatus(hackInProgress)

        MsgBox "Failed to enable NoSave mode. Please ensure you have the necessary permissions and that your firewall supports the required rules.",
            "FIREWALL WARNING", 48

    } else {
        if (!noSave && IsNoSaveRuleActive()) {
            noSave := true
            UpdateGlobalStatus(hackInProgress)

            MsgBox "Failed to disable NoSave mode. Please check your firewall settings and try again.",
                "FIREWALL WARNING", 48
        }
    }

    IniWrite(noSave, iniFile, "Options", "NoSave")

}

clearAllToolTips() {
    loop 19
        ToolTip "", , , A_Index
}

isGtaFocused() {
    return WinActive("Grand Theft Auto")
}

PgUpDown(*) {
    global pgUpSent, sendPgUpKey
    if !isGtaFocused() {
        ToolTip "[PgUp] GTA not focused", scrW, 0, 20
        return
    }

    if (sendPgUpKey == "LButton") {
        if (!GetKeyState("RButton", "P")) {
            pgUpSent := true
            Send "{PgUp down}"
            ToolTip "PgUp pressed (LMB)", scrW, 0, 20
        }
        ; If RButton is pressed, do nothing (block PgUp)
        return
    }

    pgUpSent := true
    Send "{PgUp down}"
    ToolTip "PgUp pressed (" sendPgUpKey ")", scrW, 0, 20

}

PgUpUp(*) {
    global pgUpSent, hackInProgress

    if !pgUpSent {
        UpdateGlobalStatus(hackInProgress)
        return
    }

    Send "{PgUp up}"
    pgUpSent := false
    UpdateGlobalStatus(hackInProgress)
}
