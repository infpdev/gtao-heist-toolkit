#Include updateCheck.ahk
#Include initHotkeys.ahk
#Include commonFuncs.ahk
#Include scripts\NoSave.ahk
#Include sharedCanonicalHelpers.ahk
#Include ahk2py_socket.ahk
#Include scripts\LedgeGrab.ahk

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
global fingerprintMode := true, debug := !A_IsCompiled
global heist := DCH_OR_KORTZ
global engine := OPENCV_ENGINE
global pgUpSent := false
global ledgeGrabEnabled := true, ledgeGrabInProgress := false, LedgeGrabRunningSignal := false

global cachedFingerprintAnchor := 0, cachedKeypadAnchor := 0, cachedRubioAnchor := 0

global readableNoSaveKey := CanonicalToDisplay(noSaveKey)
global readableScriptsKey := CanonicalToDisplay(toggleScriptsKey)
global readableSendPgUpKey := CanonicalToDisplay(sendPgUpKey)
global readableManualKey := CanonicalToDisplay(manualKey)
global readableAutoHackKey := CanonicalToDisplay(autoHackKey)
global readableResetKey := CanonicalToDisplay(resetKey)
global readableLedgeGrabKey := CanonicalToDisplay(ledgeGrabKey)

FocusGtaIfRunning()

; Register hotkeys with error handling.
try {
    Hotkey "~*" CanonicalToRegistration(noSaveKey), ToggleNoSaveStatus
} catch {
    MsgBox "Failed to register NoSave hotkey. Please check your settings.", "Hotkey Registration Failed", 48
}
try {
    Hotkey "~*" CanonicalToRegistration(resetKey), resetSolver
} catch {
    MsgBox "Failed to register Reset hotkey. Please check your settings.", "Hotkey Registration Failed", 48
}
try {
    Hotkey "~*" CanonicalToRegistration(terminateKey), ExitScript
} catch {
    MsgBox "Failed to register Terminate hotkey. Please check your settings.", "Hotkey Registration Failed", 48
}
try {
    if (debug) {
        Hotkey("F2 Up", (*) => Reload(), "On")
        Hotkey("F3 Up", (*) => ExitApp(), "On")
    }
} catch {
    MsgBox "Failed to register debug hotkeys. Please check your settings.", "Hotkey Registration Failed", 48
}

RegisterLedgeGrabHotkey(true)

LoadCache()
initPython()

SetTimer(() => (isFirewallEnabled()), -100)

; --- Common Functions ---

/**
 * Destroys the current heist instance (if any) and creates a new one based on current settings.
 * Used for switching between fingerprint/keypad modes or heists.
 * 
 * Side effects: Updates global heistInstance.
 */
resetSolver(*) {
    global fingerprintMode, heistInstance, scriptsEnabled, hackMode

    hackMode := "idle"
    clearAllToolTips()

    if (heistInstance) {
        try heistInstance.Destroy()
        heistInstance := ""
    }

    if (ledgeGrabInProgress) {
        ToggleLedgeGrabInProgress()
    }

    CreateHeistInstance()
}

ExitScript(*) {
    if (IsObject(heistinstance))
        heistinstance.Destroy()

    if (ledgeGrabInProgress) {
        ToggleLedgeGrabInProgress()
    }

    OnExitCleanup()
    ExitApp
}

OnExit(OnExitCleanup)

OnExitCleanup(*) {
    global isShuttingDown := true
    ShowCenteredToolTip "Terminating " A_ScriptName, 15
    try SaveCache()
    try PersistSettingsToAppData()
    try StopPython()
}

ResetHackMode(*) {
    resetSolver()
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
UpdateGlobalStatus(isHacking, isTimingOut := false, timeoutProgress := 0, force := false, *) {
    static previousStatus := ""
    static unsupportedResolutionText := unsupportedResolution ? "(Unsupported resolution)`n" : ""

    global hackInProgress, readableNoSaveKey, readableScriptsKey, readableSendPgUpKey, readableManualKey,
        readableAutoHackKey, readableResetKey, pgUpSent, unsupportedResolution

    pos := getToolTipPos(toolTipPos)
    x := pos.x
    y := pos.y

    if (pgUpSent)
        return ; Don't update status while PgUp is being sent to avoid tooltip interference

    noSaveText := "Press " readableNoSaveKey " to " (noSave ? "disable" : "enable") " NoSave"

    ledgeGrabText := ledgeGrabEnabled ? "Press " readableLedgeGrabKey " to " (ledgeGrabInProgress ? "stop" :
        "initiate") " Ledge Grab" : "Ledge grab disabled"

    if (isTimingOut) {
        status := "Timeout in " timeoutProgress "s"
        CustomTooltip(status, x, y, 20)
        MakeAllToolTipsClickThrough(hackMode == "idle")
        return
    }

    if (hackMode == "idle") {
        if (heist == DCH_OR_KORTZ) {
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
            else if (heist == DCH_OR_KORTZ) {
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
            else if (heist == DCH_OR_KORTZ) {
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

    aggregatedStatus := unsupportedResolutionText . hackStatus "`n" noSaveText "`n" ledgeGrabText "`n" keys

    if (force || aggregatedStatus != previousStatus) { ; Only update tooltip if status has changed to reduce flickering
        previousStatus := aggregatedStatus
        CustomTooltip(aggregatedStatus, x, y, 20)

        MakeAllToolTipsClickThrough(hackMode == "idle")
    }

}

; Callback for using the OpenCV engine, used by solvers to switch
; to OpenCV mode when AHK detection fails for more than 2 consecutive attempts.
UseOpenCVEngineCallback() {
    ToggleEngineMode("", "", OpenCV_ENGINE)
}

ToggleEngineMode(params := "", info := "", to := "") {
    global engine, iniFile, hackInProgress, heistinstance

    if (to == AHK_ENGINE) {
        engine := AHK_ENGINE
    } else if (to == OpenCV_ENGINE) {
        engine := OpenCV_ENGINE
    } else
        engine := !engine

    if (heistinstance && heistInstance != "") {
        heistInstance.setEngine(engine)
    }

    IniWrite(engine, iniFile, "Options", "Engine")
    UpdateGlobalStatus(hackInProgress)
}

ToggleNoSaveStatus(*) {
    global noSave
    if (!isFirewallEnabled(true)) {
        MsgBox "Cannot toggle NoSave mode because the firewall is not accessible."
            . "Please check your firewall settings and try again.",
            "Firewall Access Error", 48
        return
    }

    isNoSaveEnabled := noSave
    if (isNoSaveEnabled) {
        if (DisableNoSaveMode())
            noSave := false
        else
            MsgBox "Failed to disable NoSave mode. Please check your firewall settings and try again.",
                "FIREWALL WARNING", 48
    } else {
        if (EnableNoSaveMode())
            noSave := true
        else
            MsgBox "Failed to enable NoSave mode. Please ensure you have the necessary permissions and that your firewall supports the required rules.",
                "FIREWALL WARNING", 48
    }

    UpdateGlobalStatus(hackInProgress)

}

clearAllToolTips() {
    loop 19
        CustomTooltip "", , , A_Index
}

PgUpDown(*) {
    global pgUpSent, sendPgUpKey
    pos := getToolTipPos(toolTipPos)
    x := pos.x
    y := pos.y

    if !isGtaFocused(, true) {
        CustomTooltip "[PgUp] GTA not focused", x, y, 20
        return
    }

    if (sendPgUpKey == "LButton") {
        if (!GetKeyState("RButton", "P")) {
            pgUpSent := true
            Send "{PgUp down}"
            CustomTooltip "PgUp pressed (LMB)", x, y, 20
        }
        ; If RButton is pressed, do nothing (block PgUp)
        return
    }

    pgUpSent := true
    Send "{PgUp down}"
    CustomTooltip "PgUp pressed (" sendPgUpKey ")", x, y, 20

}

PgUpUp(*) {
    global pgUpSent, hackInProgress

    if !pgUpSent {
        UpdateGlobalStatus(hackInProgress, , , true)
        return
    }

    Send "{PgUp up}"
    pgUpSent := false
    UpdateGlobalStatus(hackInProgress, , , true)
}

; Toggle debug mode with Alt+F12.
ToggleDebugChord(*) {
    global debug
    if (!IsSet(debug))
        debug := false

    debug := !debug

    if (debug) {
        Hotkey("F2 Up", (*) => Reload(), "On")
        Hotkey("F3 Up", (*) => ExitApp(), "On")
        ShowCenteredToolTip "Debug mode enabled", 17
        sleep 1000
    } else {
        try Hotkey("F2 Up", "Off")
        try Hotkey("F3 Up", "Off")
        ShowCenteredToolTip "Debug mode disabled", 17
        sleep 1000
    }

    SetTimer(() => (debug ? CustomTooltip("", , , 17) : clearAllToolTips()), -1200)
}

Hotkey("!F10", ToggleDebugChord)