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

; Enable rich presence and write to ini file
EnableRichPresence() {
    global iniFile, richPresenceEnabled
    IniWrite(1, iniFile, "Options", "richPresence")
    richPresenceEnabled := true
    UpdateCurrentActivity()
    StartDiscordRPC()

}

; Disable rich presence and write to ini file
DisableRichPresence() {
    global richPresenceEnabled, currentActivity
    global iniFile

    richPresenceEnabled := false
    currentActivity := ""
    IniWrite(0, iniFile, "Options", "richPresence")
    LastDiscordCallFinished()
    KillDiscordRPC()

}

/**
 * @description Updates the current rich presence activity based on the current state of the application.<br>
 * Priority: NoSave > Solver > LedgeGrab > Clear
 */
UpdateCurrentActivity() {
    global hackMode, noSave, scriptsEnabled, heist, fingerprintMode

    if (!richPresenceEnabled)
        return

    if (!isGtaRunning()) {
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
    global richPresenceEnabled, currentActivity

    if (richPresenceEnabled && !isShuttingDown) {

        if (!LastDiscordCallFinished())
            return

        previousActivity := currentActivity
        currentActivity := type
        ; MsgBox "Previous Activity: " previousActivity "`nCurrent Activity: " currentActivity
        if (previousActivity != currentActivity) {
            res := SetDiscordActivity(type)
            if (res != "OK") {
                ShowCenteredToolTip "Failed to set Discord rich presence activity: " res, 17
                Sleep 500
                ToolTip("", 0, 0, 17)
            }
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
        SetActivity(RichPresenceCmd.CLEAR)
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
