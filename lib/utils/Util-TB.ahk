#Include "./initHotkeys.ahk"

init()

/**
 * Entry point: sets CoordMode, reads saved RGB target from INI, registers toggle + calibrate hotkeys.
 */
init() {

    SendMode "Event"
    CoordMode "Pixel", "Screen"
    CoordMode "ToolTip", "Screen"
    global TriggerBotEnabled := false
    global isCalibrating := false

    global centerX := A_ScreenWidth // 2
    global centerY := A_ScreenHeight // 2

    global targetR := IniRead(iniFile, "Utility", "targetR", 210)
    global targetG := IniRead(iniFile, "Utility", "targetG", 110)
    global targetB := IniRead(iniFile, "Utility", "targetB", 104)

    global resetTimer := 2000 ; Time the reset key must be held to exit, in milliseconds
    global lastResetKeyHeld := 0
    global resetKeyReg := CanonicalToRegistration(resetKey)

    try {
        Hotkey("~*" CanonicalToRegistration(toggleHotkey), ToggleTriggerBot, "On")
    } catch as e {
        MsgBox "Failed to register toggle hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

    try {
        Hotkey("!~*" CanonicalToRegistration(toggleHotkey), CalibrateRedPixel, "On")
    } catch as e {
        MsgBox "Failed to register Calibrate hotkey:`n" e.Message, "Hotkey Registration Failed", 48
        ExitApp
    }

    UpdateTooltip()
}

ToggleTriggerBot(*) {
    global TriggerBotEnabled, isCalibrating
    if TriggerBotEnabled {
        DisableTriggerBot()
    } else {
        EnableTriggerBot()
    }
}

/**
 * Enters calibration mode: polls center pixel at 25ms, captures RGB when red detected, saves to INI, enables triggerbot.
 */
CalibrateRedPixel(*) {
    global TriggerBotEnabled, isCalibrating
    DisableTriggerBot()

    if (!isGtaFocusedForUtilities())
        return

    isCalibrating := true
    SetTimer TriggerBot, 0
    SetTimer CalibrateSearchPixel, 25
    UpdateTooltip()
}

EnableTriggerBot() {
    global TriggerBotEnabled, isCalibrating

    if (!isGtaFocusedForUtilities())
        return

    if TriggerBotEnabled
        return

    TriggerBotEnabled := true
    isCalibrating := false
    UpdateTooltip()
    SetTimer TriggerBot, 1
    SetTimer CalibrateSearchPixel, 0
}

DisableTriggerBot() {
    global TriggerBotEnabled, isCalibrating
    TriggerBotEnabled := false
    isCalibrating := false
    SetTimer TriggerBot, 0
    SetTimer CalibrateSearchPixel, 0
    UpdateTooltip()
}

/**
 * Main 1ms loop: reads pixel at screen center, clicks LMB if IsTargetRed().
 */
TriggerBot() {
    global TriggerBotEnabled, targetR, targetG, targetB

    if !TriggerBotEnabled
        return

    centerX := A_ScreenWidth // 2
    centerY := A_ScreenHeight // 2
    color := PixelGetColor(centerX, centerY, "RGB")
    if IsTargetRed(color, targetR, targetG, targetB) {
        SetKeyDelay -1
        Send "{LButton}"
    }
}

/**
 * Calibration loop (25ms): reads center pixel, saves RGB and enables triggerbot when red found.
 */
CalibrateSearchPixel() {
    global isCalibrating, targetR, targetG, targetB

    if !isCalibrating
        return

    color := PixelGetColor(centerX, centerY, "RGB")
    if IsTargetRed(color, targetR, targetG, targetB) {
        isCalibrating := false
        SetTimer CalibrateSearchPixel, 0
        ; MsgBox "Old Pixel: " . Format("{}, {}, {}", targetR, targetG, targetB) . "`nNew Pixel: " . Format(
        ;     "R: {}, G: {}, B: {}", (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF) .
        ; "`n calibrated successfully!"
        ; . " calibrated successfully!"
        targetR := (color >> 16) & 0xFF
        targetG := (color >> 8) & 0xFF
        targetB := color & 0xFF
        savePixels()
        EnableTriggerBot()
        UpdateTooltip()
        return
    }
}

/**
 * Returns true if pixel R > G+15, R > B+15, and all channels within 35 of saved target.
 */
IsTargetRed(color, red, green, blue) {
    pixelR := (color >> 16) & 0xFF
    pixelG := (color >> 8) & 0xFF
    pixelB := color & 0xFF

    return pixelR > pixelG + 15
        && pixelR > pixelB + 15
        && Abs(pixelR - red) <= 35
        && Abs(pixelG - green) <= 35
        && Abs(pixelB - blue) <= 35
}

savePixels() {
    global targetR, targetG, targetB
    IniWrite(targetR, iniFile, "Utility", "targetR")
    IniWrite(targetG, iniFile, "Utility", "targetG")
    IniWrite(targetB, iniFile, "Utility", "targetB")
    PersistSettingsToAppData()
}

/**
 * Shows status tooltip: triggerbot on/off, toggle/calibrate/terminate instructions, or countdown.
 */
UpdateTooltip() {
    pos := getToolTipPos(toolTipPos)
    x := pos.x
    y := pos.y + tooltipYOffset

    CaliberatingText := "Finding red pixel near center..."
    if (isCalibrating) {
        CustomTooltip CaliberatingText, x, y
        MakeAllToolTipsClickThrough(false)
        return
    }

    TriggerbotStatus := "Triggerbot " (TriggerBotEnabled ? "ON" : "OFF")
    ToggleText := "Press " . CanonicalToDisplay(toggleHotkey) . " to " (TriggerBotEnabled ? "disable" : "enable") .
    " triggerbot"
    CaliberateText := "Press Alt + " . CanonicalToDisplay(toggleHotkey) . " to calibrate the red pixel"
    TerminateText := "Press " . StrTitle(CanonicalToDisplay(terminateKey)) . " to terminate the script"

    CustomTooltip TriggerbotStatus "`n" ToggleText "`n" CaliberateText "`n" TerminateText, x, y

    MakeAllToolTipsClickThrough(false)

}

Terminate(*) {
    ExitApp
}
