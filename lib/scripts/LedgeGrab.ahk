; Toggles the ledge-grab automation
ToggleLedgeGrabInProgress(*) {
    global ledgeGrabInProgress, hackInProgress, hackMode, LedgeGrabRunningSignal

    if (hackInProgress || hackMode != "idle") {
        ShowCenteredToolTip "Cannot use ledge grab while hack is in progress", 17
        SetTimer(() => (ToolTip("", , , 17)), -2000)
        return
    }

    if (DisableLedgeGrabIfGtaNotFocused())
        return

    BlockInput 0

    if (!LedgeGrabRunningSignal && !ledgeGrabInProgress) {

        if (!LastRequestFinished()) {
            ShowCenteredToolTip "Failed to enable ledge grab", 17
            SetTimer(() => (ToolTip("", , , 17)), -2000)
            return
        }
        LedgeGrabRunningSignal := true
        enableLedgeGrabInProgress()
    } else {
        LedgeGrabRunningSignal := false
    }

    ; ledgeGrabInProgress := !ledgeGrabInProgress
    ; ToolTip("", , , 17)
    ; UpdateGlobalStatus(hackInProgress)
    ; if (ledgeGrabInProgress)
    ;     SetTimer LedgeGrab, -1
}

enableLedgeGrabInProgress() {
    global ledgeGrabInProgress
    ledgeGrabInProgress := true
    UpdateGlobalStatus(hackInProgress)
    SetTimer LedgeGrab, -1
}

disableLedgeGrabInProgress() {
    global ledgeGrabInProgress
    BlockInput 0
    ledgeGrabInProgress := false
    UpdateGlobalStatus(hackInProgress)
}

; Entry point for the ledge-grab automation.
; Initiates the ledge-grab sequence and loops until user presses the toggle key again or GTA loses focus.
LedgeGrab() {
    global ledgeGrabKey, ledgeGrabEnabled, ledgeGrabInProgress, hackInProgress, earlyExit := true

    if (!ledgeGrabEnabled)
        return

    SendMode "Event"
    SetKeyDelay 100, 50

    Send("{" ledgeGrabKey "}")

    Sleep 100
    DisableInput()

    Send '{Up 2}'

    SleepIfBlack()

    if (!ledgeGrabEnabled || !ledgeGrabInProgress)
        return

    Sleep 500
    SendInput '{W down}'
    Sleep 500
    Send '{Space}'
    SendInput '{W up}'
    Sleep 200

    InitLedgeGrab()
}

; Initializes the ledge-grab sequence by sending the necessary key inputs to get the cursor over the camera app
InitLedgeGrab() {
    global earlyExit := false

    Send '{Up 2}'

    SleepIfBlack()

    EnableInput()

    Send '{Backspace}'

    if (!ledgeGrabEnabled || !ledgeGrabInProgress)
        return

    Sleep 500
    Send '{Down}'
    Sleep 100
    Send '{Left}'
    Sleep 100

    LoopArrowUp()
}

; Toggles the camera app in order to carry the ledge-grab glitch
LoopArrowUp() {
    global ledgeGrabEnabled, ledgeGrabInProgress

    while ledgeGrabEnabled {

        if (DisableLedgeGrabIfGtaNotFocused())
            break

        Send '{Enter}'
        SleepIfBlack()

        Sleep 100
        Send '{Backspace}'

        if (!ledgeGrabInProgress)
            return

        Sleep 1500
    }
}

; Helper function that waits until the screen is no longer black, or until a timeout occurs.
SleepIfBlack() {
    global ledgeGrabInProgress, LedgeGrabRunningSignal
    static centerX := A_ScreenWidth // 2
    static centerY := A_ScreenHeight // 2
    static timeoutMs := 3000

    blackFoundOnce := false

    startTime := A_TickCount

    while true {

        if (!LedgeGrabRunningSignal) {
            ShowCenteredToolTip "Finishing up ledge grab sequence", 17
        }

        if (A_TickCount - startTime > timeoutMs) {
            ; MsgBox "Failed here"
            ledgeGrabInProgress := false
            LedgeGrabRunningSignal := false
            BlockInput 0
            ToolTip("", , , 17)
            UpdateGlobalStatus(hackInProgress)
            break
        }

        ; sleep while the screen is black
        if (GetResFromOpenCV(REQ_LEDGE_GRAB_BLACK) = 1) {
            blackFoundOnce := true
            startTime += 100 ; extend timeout by 0.1 second for each black frame detected
            Sleep 100
            continue
        }

        if blackFoundOnce
            break ; screen is no longer black
        Sleep 500
    }
    if (!LedgeGrabRunningSignal) {
        LastRequestFinished()
        if (!earlyExit)
            ShowCenteredToolTip "Ledge grab sequence completed", 17
        else
            ShowCenteredToolTip "Ledge grab sequence interrupted", 17
        SetTimer(() => (ToolTip("", , , 17)), -2000)
        disableLedgeGrabInProgress()
    }

    return
}

/**
 * @description Registers or unregisters the ledge-grab hotkey based on the current state.
 * @param {boolean} shouldRegister - True to register, false to unregister.
 * @param {string} [unregisterKey=""] - Optional key to unregister if different from the global ledgeGrabKey.
 * @returns {boolean} True if registration/unregistration was successful, false otherwise.
 */
RegisterLedgeGrabHotkey(shouldRegister := true, unregisterKey := "") {
    global ledgeGrabEnabled, ledgeGrabKey
    if (ledgeGrabEnabled && ledgeGrabKey) {
        if (shouldRegister) {
            try Hotkey(CanonicalToRegistration(ledgeGrabKey), ToggleLedgeGrabInProgress, "On")
            catch {
                MsgBox "Failed to register ledge grab hotkey: " . ledgeGrabKey, "Ledge Grab Hotkey Registration Failed",
                    48
            }
            return true
        } else {
            if (unregisterKey == "")
                unregisterKey := ledgeGrabKey
            try Hotkey(CanonicalToRegistration(unregisterKey), "Off")
            return true
        }
    }

}

; Disables user input and shows a tooltip indicating that inputs are disabled for ledge-grab initiation.
DisableInput() {
    BlockInput 1
    ShowCenteredToolTip "Inputs disabled. Please wait till the script initiates ledge grab", 17
}

; Re-enables user input and shows a tooltip indicating that inputs are re-enabled after ledge-grab initiation.
EnableInput() {
    BlockInput 0

    if (LedgeGrabRunningSignal) {
        ShowCenteredToolTip "Inputs re-enabled. You can now move to the desired position", 17
        SetTimer(() => (ToolTip("", , , 17)), -5000)
    }
}

; Disables ledge-grab automation if GTA is not the focused window.
; Sends the key in order to not consume the ledge-grab key press when GTA is not focused.
DisableLedgeGrabIfGtaNotFocused() {
    static shownWarning := false
    global ledgeGrabInProgress, ledgeGrabEnabled
    if (!isGtaFocused(true, true)) {
        Send("{" ledgeGrabKey "}")
        BlockInput 0

        ledgeGrabInProgress := false
        LedgeGrabRunningSignal := false
        if (ledgeGrabEnabled && IsSet(ToggleLedgeGrabEnabled)) {
            ToggleLedgeGrabEnabled()
            if (!shownWarning)
                ShowCenteredToolTip "Ledge grab disabled [GTA not focused]", 17
            shownWarning := true
        } else {
            if (!shownWarning)
                ShowCenteredToolTip "Cannot initiate ledge grab [GTA not focused]", 17
            shownWarning := true
        }
        UpdateGlobalStatus(hackInProgress)
        SetTimer(() => (ToolTip("", , , 17)), -2000)
        return true
    }
    shownWarning := false
    return false
}
