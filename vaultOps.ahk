#Requires AutoHotkey v2.0

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
global vaultOps := true

; --- IMPORTS SECTION ---
; common imports
#Include <updateCheck>
#Include <initHotkeys>

; vaultOps scripts
#Include <scripts\CasinoFingerprint>
#Include <scripts\CasinoKeypad>
#Include <scripts\ElRubio>
#Include <scripts\NoSave>
#Include <commonFuncs>

; GUI imports
#Include <gui\hotkeyHelpers>
#Include <gui\windowHelpers>
#Include <gui\tooltipsHelpers>
#Include <gui\anchorDetection>
#Include <gui\instructionFieldHelpers>

if debug {
    ToolTip "In Debug mode", 0, 0, 20
    sleep 100
    Hotkey("F2", (*) => Reload())
    Hotkey("F3", (*) => ExitApp())
}

global fnManualHotkey := ManualHotkey, fnAutoHackHotkey := AutoHackHotkey, fnResetHotkey := ResetScriptsHotkey,
    fnToggleNoSave := ToggleNoSaveStatus, fnToggleScripts := ToggleScriptsEnabled

; ⏐===========================================================================================================⏐
; ⏐==================================== Casino Script Instance Management ====================================⏐
; ⏐===========================================================================================================⏐
{

    /**
     * Creates or destroys the current heist instance based on user settings and anchor detection.
     * - If scripts are disabled, destroys any existing instance.
     * - Otherwise, creates the appropriate solver instance for the current heist and mode.
     * 
     * Side effects: Updates global heistInstance.
     */
    CreateHeistInstance() {
        global fingerprintMode, heistInstance, scriptsEnabled, delay, heist, hackMode, pgUpSent, txtPgUpLabel

        hackMode := "idle"

        if (!scriptsEnabled) {
            if (heistInstance) {
                try heistInstance.Destroy()
                heistInstance := ""
            }
            return
        }

        ; Lifecycle safety: prevent overlapping solver instances/timers
        ; when CreateHeistInstance is called repeatedly during anchor-driven switches.
        if (heistInstance) {
            try heistInstance.Destroy()
            heistInstance := ""
        }

        if (heist == CAYO_PERICO) {
            heistInstance := ElRubioSolver(delay, ResetHackMode, UpdateGlobalStatus, cachedRubioAnchor)

        } else if (heist == DIAMOND_CASINO) {
            pgUpSent := false ; Reset PgUp sent status when switching to casino
            txtPgUpLabel.Opt("cWhite")
            if (fingerprintMode) {
                heistInstance := FingerprintSolver(delay, ResetHackMode, UpdateGlobalStatus, cachedFingerprintAnchor)
            } else {
                heistInstance := KeypadSolver(delay, ResetHackMode, UpdateGlobalStatus, cachedKeypadAnchor)
            }

        }

    }

    /**
     * Destroys the current heist instance (if any) and creates a new one based on current settings.
     * Used for switching between fingerprint/keypad modes or heists.
     * 
     * Side effects: Updates global heistInstance.
     */
    SwitchCasinoInstance() {
        global fingerprintMode, heistInstance, scriptsEnabled
        if (heistInstance) {
            try heistInstance.Destroy()
            heistInstance := ""
        }
        if (scriptsEnabled) {
            CreateHeistInstance()
        }
    }

}
; ⏐==========================================================================================================⏐

; ⏐==========================================================================================================⏐
; ⏐===================================== Hotkeys / Management Functions =====================================⏐
; ⏐==========================================================================================================⏐
{

    ; Unregisters all hotkeys or a specific hotkey if provided. Used when toggling scripts on/off and for cleanup on exit
    UnregisterHotkeys(unregKey := "") {
        global manualKey, autoHackKey, resetKey
        global prevManualKey := "", prevAutoHackKey := "", prevResetKey := ""
        SafeHotkeyUnregister(key) {
            if (key != "" && IsSet(key)) {
                try {
                    Hotkey("~*" key, "Off") ; disable
                }
            }
        }

        if (unregKey) {
            SafeHotkeyUnregister(unregKey)
            return
        }

        SafeHotkeyUnregister(manualKey)
        SafeHotkeyUnregister(autoHackKey)
        SafeHotkeyUnregister(resetKey)
    }

    ; Registers hotkeys based on current settings. If scripts are disabled, only registers toggle hotkeys.
    ; Also updates status tooltip to reflect changes
    TryRegisterHotkeys() {
        global manualKey, autoHackKey, resetKey, noSaveKey, toggleScriptsKey, scriptsEnabled
        static regNoSaveKey := "", regToggleScriptsKey := "", regManualKey := "", regAutoHackKey := "",
            regResetKey := ""

        if (regNoSaveKey && regNoSaveKey != noSaveKey)
            Hotkey("~*" regNoSaveKey, fnToggleNoSave, "Off")
        if (regToggleScriptsKey && regToggleScriptsKey != toggleScriptsKey)
            Hotkey("~*" regToggleScriptsKey, fnToggleScripts, "Off")

        if (noSaveKey) {
            Hotkey("~*" noSaveKey, fnToggleNoSave, "On")
            regNoSaveKey := noSaveKey
        }
        if (toggleScriptsKey) {
            Hotkey("~*" toggleScriptsKey, fnToggleScripts, "On")
            regToggleScriptsKey := toggleScriptsKey
        }

        if (!scriptsEnabled) {
            if (regManualKey)
                Hotkey("~*" regManualKey, fnManualHotkey, "Off")
            if (regAutoHackKey)
                Hotkey("~*" regAutoHackKey, fnAutoHackHotkey, "Off")
            if (regResetKey)
                Hotkey("~*" regResetKey, fnResetHotkey, "Off")
            regManualKey := ""
            regAutoHackKey := ""
            regResetKey := ""
            UnregisterHotkeys()
            UpdateGlobalStatus(hackInProgress)
            return
        }

        if (regManualKey && regManualKey != manualKey)
            Hotkey("~*" regManualKey, fnManualHotkey, "Off")
        if (regAutoHackKey && regAutoHackKey != autoHackKey)
            Hotkey("~*" regAutoHackKey, fnAutoHackHotkey, "Off")
        if (regResetKey && regResetKey != resetKey)
            Hotkey("~*" regResetKey, fnResetHotkey, "Off")

        if (manualKey) {
            Hotkey("~*" manualKey, fnManualHotkey, "On")
            regManualKey := manualKey
        }
        if (autoHackKey) {
            Hotkey("~*" autoHackKey, fnAutoHackHotkey, "On")
            regAutoHackKey := autoHackKey
        }
        if (resetKey) {
            Hotkey("~*" resetKey, fnResetHotkey, "On")
            regResetKey := resetKey
        }

        if (heist == CAYO_PERICO)
            TryRegisterPgUpHotkey()

        UpdateGlobalStatus(hackInProgress)
    }

    ManualHotkey(*) {
        global fingerprintMode, heistInstance, hackMode, heist
        hackMode := "manual"
        if (IsObject(heistInstance)) {
            if (heist == CAYO_PERICO)
                heistInstance.switchToManual()
            else if (heist == DIAMOND_CASINO) {
                if (fingerprintMode)
                    heistInstance.ManualMode()
                else
                    heistInstance.switchToManual()
            }

            UpdateGlobalStatus(hackInProgress)

        } else {
            ToolTip "Manual hotkey triggered!"
            SetTimer () => ToolTip(), -700
        }
    }

    AutoHackHotkey(*) {
        global fingerprintMode, heistInstance, hackMode, heist
        hackMode := "auto"
        if (IsObject(heistInstance)) {
            if (heist == CAYO_PERICO)
                heistInstance.Hack()
            else if (heist == DIAMOND_CASINO) {
                if (fingerprintMode)
                    heistInstance.AutoHack()
                else
                    heistInstance.switchToAuto()
            }

            UpdateGlobalStatus(hackInProgress)

        } else {
            ToolTip "AutoHack hotkey triggered!"
            SetTimer () => ToolTip(), -700
        }
    }

    ResetScriptsHotkey(*) {
        global hackMode, hackInProgress
        hackMode := "idle"
        hackInProgress := false
        SetTimer(findAnchorsAndCreateInstance, 1000) ; Restart anchor detection timer
        if (IsObject(heistInstance))
            if (heistInstance) {
                try heistInstance.Destroy()
                ToolTip "Resetting script", scrW, 0, 20
                sleep 500
                CreateHeistInstance()
            }
            else {
                ToolTip "Reset hotkey triggered!"
                SetTimer () => ToolTip(), -700
            }

    }
}
; ⏐==========================================================================================================⏐

; ⏐==========================================================================================================⏐
; ⏐============================================ Common Functions ============================================⏐
; ⏐==========================================================================================================⏐
{

    ; Helper function to update INI file
    ; values for settings changes. Used by
    ; various toggle functions to persist user preferences.
    UpdateIni(section, key, value) {
        global iniFile
        IniWrite(value, iniFile, section, key)
    }

    /**
     * Resets the hack mode to idle, clears tooltips, and restarts anchor detection if scripts are enabled.
     * Used for cleanup on exit or when the user triggers a reset.
     * 
     * Side effects: Updates hackMode, tooltips, and anchor detection timer.
     */
    ResetHackMode() {
        global hackMode
        hackMode := "idle"

        clearAllToolTips(scriptsEnabled)
        UpdateGlobalStatus(false)
        if (scriptsEnabled) {
            SetTimer () => (
                SetTimer(findAnchorsAndCreateInstance, 1000)
            ), debug ? -5000 : -10000
        }

    }

    ; Updates the 20th ToolTip with current hack status, mode, and hotkey info.
    ; Called by heist instances to reflect changes in state
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
        global hackMode, fingerprintMode, scriptsEnabled, noSave, manualKey, autoHackKey, resetKey, hackInProgress,
            heist, sendPgUpKey, pgUpSent

        readableNoSaveKey := StrLen(noSaveKey) > 1 ? AHKToDisplayHotkey(noSaveKey) : noSaveKey
        readableScriptsKey := StrLen(toggleScriptsKey) > 1 ? AHKToDisplayHotkey(toggleScriptsKey) : toggleScriptsKey
        readableSendPgUpKey := StrLen(sendPgUpKey) > 1 ? AHKToDisplayHotkey(sendPgUpKey) : sendPgUpKey
        readableManualKey := StrLen(manualKey) > 1 ? AHKToDisplayHotkey(manualKey) : manualKey
        readableAutoHackKey := StrLen(autoHackKey) > 1 ? AHKToDisplayHotkey(autoHackKey) : autoHackKey
        readableResetKey := StrLen(resetKey) > 1 ? AHKToDisplayHotkey(resetKey) : resetKey

        if (pgUpSent)
            return ; Don't update status while PgUp is being sent to avoid tooltip interference

        ; noSaveText := noSave ? "NoSave enabled" : "NoSave disabled"
        noSaveText := "Press " readableNoSaveKey " to " (noSave ? "disable" : "enable") " NoSave"
        earlyReturn := false

        if (!scriptsEnabled) {
            status := "Scripts disabled`n" noSaveText
            earlyReturn := true
            ToolTip(status, scrW, 0, 20)
        }

        if (isTimingOut) {
            earlyReturn := true
            status := "Timeout in " timeoutProgress "s"
            ToolTip(status, scrW, 0, 20)
        }

        if (earlyReturn) {
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
                    ; hackStatus .= (hackMode == "manual" ? "`nSend PgUp: " sendPgUpKey : "")
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
                    ; hackStatus .= (hackMode == "manual" ? "`nSend PgUp: " sendPgUpKey : "")
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
        keys := (heist == CAYO_PERICO && hackMode != "auto" ? "Send PgUp: " readableSendPgUpKey "`n" :
            "")

        keys .= (hackMode == "manual" ? indicator : "") "Manual: " readableManualKey "`n" (hackMode == "auto" ?
            indicator : "") "Auto: " readableAutoHackKey "`nReset: " readableResetKey

        ToolTip(hackStatus "`n" noSaveText "`n" keys, scrW, 0, 20)

        MakeAllToolTipsClickThrough(hackMode == "idle")
    }

}
; ⏐==========================================================================================================⏐

; ⏐==========================================================================================================⏐
; ⏐=========================================== UI Toggle Functions ==========================================⏐
; ⏐==========================================================================================================⏐
{
    ToggleScriptsEnabled(*) {
        global scriptsEnabled, picScriptsEnabled, iniFile, heistInstance, noSave, hackMode, pgUpSent := false
        global txtPgUpLabel

        txtPgUpLabel.Opt("cWhite")

        hackMode := "idle"
        scriptsEnabled := !scriptsEnabled
        clearAllToolTips(scriptsEnabled)
        if (scriptsEnabled) {
            findAnchorsAndCreateInstance()
            SetTimer(findAnchorsAndCreateInstance, 1000)
        } else {
            SetTimer(findAnchorsAndCreateInstance, 0)
        }
        SetHeistToggleBtnVisibility(scriptsEnabled)
        SetModeToggleBtnVisibility((heist == DIAMOND_CASINO) && scriptsEnabled)
        TryRegisterHotkeys()
        picScriptsEnabled.Value := scriptsEnabled ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
        IniWrite(scriptsEnabled, iniFile, "Options", "scriptsEnabled")
        CreateHeistInstance()
        UpdateGlobalStatus(scriptsEnabled && hackInProgress)

    }

    ToggleNoSaveStatus(*) {
        global noSave, picNoSave, iniFile, scriptsEnabled
        noSave := !noSave
        if (noSave && !isFirewallEnabled()) {
            noSave := false
        }
        UpdateGlobalStatus(hackInProgress)

        picNoSave.Value := noSave ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
        noSave ? EnableNoSaveMode() : DisableNoSaveMode()

        if (noSave) {
            if (!EnableNoSaveMode()) {
                noSave := false
                UpdateGlobalStatus(hackInProgress)
                picNoSave.Value := noSave ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"

                MsgBox "Failed to enable NoSave mode. Please ensure you have the necessary permissions and that your firewall supports the required rules.",
                    "FIREWALL WARNING", 48

            }
        } else {
            if (!DisableNoSaveMode()) {
                noSave := true
                UpdateGlobalStatus(hackInProgress)
                picNoSave.Value := noSave ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"

                MsgBox "Failed to disable NoSave mode. Please check your firewall settings and try again.",
                    "FIREWALL WARNING", 48
            }
        }
        ; IniWrite(noSave, iniFile, "Options", "NoSave") moved to NoSave.ahk so that it owns the
        ; state change and persistence of the NoSave setting, ensuring consistency even if the firewall rule changes outside of this toggle function.

    }

    ToggleHeistMode(*) {
        global heist, picHeistToggle, txtCasinoLabel, txtCayoLabel, DIAMOND_CASINO, CAYO_PERICO, scriptsEnabled
        global txtModeLabel, txtFingerprintLabel, picFingerprintToggle, txtKeypadLabel, txtModeInstr, hackInProgress
        heist := (heist == DIAMOND_CASINO) ? CAYO_PERICO : DIAMOND_CASINO
        picHeistToggle.Value := (heist == DIAMOND_CASINO) ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png"
        txtCasinoLabel.Opt("c" (heist == DIAMOND_CASINO ? "c648f64" : "White"))
        txtCayoLabel.Opt("c" (heist == CAYO_PERICO ? "c648f64" : "White"))
        SetModeToggleBtnVisibility((heist == DIAMOND_CASINO) && scriptsEnabled)
        UpdateGlobalStatus(hackInProgress)
        IniWrite(heist, iniFile, "Options", "heist")
        SwitchCasinoInstance()
    }

    ToggleFingerprintMode(ctrl := "", info := "") {
        global fingerprintMode, picFingerprintToggle, iniFile, hackInProgress, hackMode, txtFingerprintLabel,
            txtKeypadLabel
        fingerprintMode := !fingerprintMode
        hackInProgress := false
        picFingerprintToggle.Value := fingerprintMode ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png"

        txtFingerprintLabel.Opt("c" (fingerprintMode ? "c648f64" : "White"))
        txtKeypadLabel.Opt("c" (!fingerprintMode ? "c648f64" : "White"))

        UpdateGlobalStatus(false)
        SwitchCasinoInstance() ; Switch instance on mode toggle
        IniWrite(fingerprintMode, iniFile, "Options", "FingerprintMode")
    }

    SetModeToggleBtnVisibility(enabled) {
        global picFingerprintToggle, txtModeLabel, txtFingerprintLabel, txtKeypadLabel, txtModeInstr, txtPgUpLabel,
            inputPgUp, txtPgUpInstr
        if !IsSet(picFingerprintToggle) || !picFingerprintToggle
            return
        global heist

        if IsSet(txtPgUpLabel) && IsSet(inputPgUp) && IsSet(txtPgUpInstr) {
            show := (heist == CAYO_PERICO) && scriptsEnabled
            txtPgUpLabel.Visible := show
            inputPgUp.Visible := show
            txtPgUpInstr.Visible := show
            if show {
                TryRegisterPgUpHotkey()
            } else {
                UnregisterPgUpHotkey()
            }
        }

        if enabled {
            picFingerprintToggle.Visible := true
            picFingerprintToggle.Opt("BackgroundTrans")
            picFingerprintToggle.OnEvent("Click", ToggleFingerprintMode)
            if IsSet(txtModeLabel)
                txtModeLabel.Visible := true
            if IsSet(txtFingerprintLabel)
                txtFingerprintLabel.Visible := true
            if IsSet(txtKeypadLabel)
                txtKeypadLabel.Visible := true
            if IsSet(txtModeInstr)
                txtModeInstr.Visible := true

        } else {
            picFingerprintToggle.Visible := false
            picFingerprintToggle.OnEvent("Click", ToggleFingerprintMode, 0) ; Remove listener
            if IsSet(txtModeLabel)
                txtModeLabel.Visible := false
            if IsSet(txtFingerprintLabel)
                txtFingerprintLabel.Visible := false
            if IsSet(txtKeypadLabel)
                txtKeypadLabel.Visible := false
            if IsSet(txtModeInstr)
                txtModeInstr.Visible := false
        }
    }
}
; ⏐==========================================================================================================⏐

; ⏐==========================================================================================================⏐
; ⏐============================================= Initialization =============================================⏐
; ⏐==========================================================================================================⏐
Init() {
    ; ===========Hotkeys===========
    global manualKey, autoHackKey, resetKey, noSaveKey, toggleScriptsKey, sendPgUpKey

    ; ========= GUI objects =========
    global Title := "vaultOps"
    global guiApp, picNoSave, xBtn, settingsGroup
    global picFingerprintToggle, picScriptsEnabled, picHeistToggle
    global inputManual := "", inputAuto := "", inputReset := ""
    global inputDelay := "", inputNoSave := "", inputToggleScripts := "", inputPgUp := ""

    ; Text labels
    global txtHeistLabel, txtCasinoLabel, txtCayoLabel, txtPgUpLabel,
        txtModeLabel, txtFingerprintLabel, txtKeypadLabel, txtEnableScriptsInfo

    ; Instruction text variables (global scope)
    global instrNoSave := "Lets you do the replay glitch in heists / missions.",
        instrScripts := "Enable scripts and show the toggle-mode button.",
        instrMode := "Switch between Fingerprint and Keypad script modes (Usually handled by the script).",
        instrManual := "Let the script find the prints without selecting them automatically.",
        instrAuto := "Automatically hack the fingerprints / keypad.",
        instrReset := "Resets the current script's progress. Use in case of errors.",
        instrPgUp := "Lets you use the plasma cutters during the heist."
    ; Instruction text control variables (global scope)
    global txtNoSaveInstr := "", txtScriptsInstr := "", txtModeInstr := "",
        txtManualInstr := "", txtAutoInstr := "", txtResetInstr := "",
        txtPgUpInstr := "", txtHeistInstr := "", txtAutoInstr := "", txtDelayInstr := ""

    ; ======== Boolean flags and state variables ========
    global noSave, scriptsEnabled, fingerprintMode, hackMode, heist, delay, iniFile
    global anchorFound := false, pgUpSent := false, hackInProgress := false, pgUpDisabled := false, isUnreleased,
        cachedFingerprintAnchor := 0, cachedKeypadAnchor := 0, cachedRubioAnchor := 0,
        hackMode := "idle", heistInstance := "", autoSaveTimers := Map(),
        hotkeyCaptureField := "", hotkeyCaptureKeyName := ""

    ; ======= GUI Styling and dimension variables =======
    global width := 950, height := (A_ScreenHeight // 2), borderRadius := 20
    global scrW := A_ScreenWidth, scrH := A_ScreenHeight
    global topbarW, topbarH, btnW, titleW, bar, scale := 1.0

    ; ======= Resource folder path (for images, etc.) ========
    global folder := A_ScriptDir "\" scrW "x" scrH "\"
    global staticFolder := A_ScriptDir "\lib\static\"

    ; ======= Parent GUI creation =======
    guiApp := Gui("-Caption -DPIScale", Title)
    guiApp.BackColor := "222222"
    overallFontSize := (scrW * 11 / 1920) / GetScreenScaling()
    guiApp.SetFont("s" overallFontSize / GetScreenScaling() " cWhite")

    ; ======= Top bar =======
    topbarH := 30 / scale, btnW := 17 / scale
    topbarW := width, titleW := topbarW - btnW

    bar := guiApp.AddText("xm y0 w" titleW " h" topbarH " c648f64 Background222222 Left 0x200",
        "vaultOps ● Heist toolkit by .dev17 " (isUnreleased ? "(Unreleased)" : "(v" trimmedVer ")"))
    xBtn := guiApp.AddPicture("x" ((width - btnW - 15 / scale) / scale) " y" 10 / scale " w" btnW " h" btnW " +0x4",
    staticFolder "\minimize.png")
    xBtn.OnEvent("Click", (*) => (guiApp.Minimize()))

    ; ======= Group styling =======
    leftPadding := 40 / scale
    groupY := topbarH / scale
    groupH := (height - topbarH - leftPadding) / scale
    groupW := (width - leftPadding) / scale

    ; ======= Labels / fields styling =======
    numSettings := 7 ; Updated for Heist row
    labelW := 140 / scale
    fieldW := 90 / scale
    instrW := groupW - labelW - fieldW - 120 / scale
    rowH := (groupH - 65 / scale) / numSettings

    xLabel := 40 / scale
    xField := xLabel + labelW + 30 / scale
    xField2 := xField - 40 / scale
    xInstr := xField + fieldW + 50 / scale
    heistX := xField - 85 / scale
    y := groupY + 30 / scale
    adjustmentYOffset := 4 / scale

    settingsGroup := guiApp.AddGroupBox("x" leftPadding / (2 * scale) " y" groupY " w" groupW " h" groupH,
    "Settings")

    ; ⏐===================================================================================⏐
    ; ⏐===== Row format: Label > Toggle / Field > Instruction Text > Event listeners =====⏐
    ; ⏐===================================================================================⏐

    ; ⏐===================================================================================⏐
    ; ⏐======================== ROW 1: NoSave toggle and keybind =========================⏐
    ; ⏐===================================================================================⏐
    {

        ; Nosave label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Enable NoSave:")
        ; Nosave toggle
        picNoSave := guiApp.AddPicture("x" xField2 " y" (y - adjustmentYOffset / 2) " w" 20 / scale " h" 20 / scale " +0x4",
        noSave ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png")
        ; Nosave hotkey field
        inputNoSave := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", AHKToDisplayHotkey(noSaveKey))
        ; Nosave instruction text
        txtNoSaveInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")
        ; Nosave event listeners
        picNoSave.OnEvent("Click", ToggleNoSaveStatus)
        inputNoSave.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputNoSave, "NoSave", noSaveKey))
        inputNoSave.OnEvent("Change", (*) => AutoSaveKeybind(inputNoSave, "NoSave"))

        UpdateNoSaveInstrText()
        y += rowH
    }

    ; ⏐===================================================================================⏐
    ; ⏐======================== ROW 2: Scripts toggle and keybind ========================⏐
    ; ⏐===================================================================================⏐
    {
        ; Scripts label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Enable Scripts:")
        ; Scripts toggle
        picScriptsEnabled := guiApp.AddPicture("x" xField2 " y" (y - adjustmentYOffset / 2) " w" 20 / scale " h" 20 /
        scale " +0x4",
        scriptsEnabled ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png")
        ; Scripts hotkey field
        inputToggleScripts := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", AHKToDisplayHotkey(toggleScriptsKey))
        ; Scripts instruction text
        txtScriptsInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")
        ; Scripts event listeners
        picScriptsEnabled.OnEvent("Click", ToggleScriptsEnabled)
        inputToggleScripts.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputToggleScripts, "ToggleScripts",
            toggleScriptsKey))
        inputToggleScripts.OnEvent("Change", (*) => AutoSaveKeybind(inputToggleScripts, "ToggleScripts"))

        UpdateScriptsInstrText()
        y += rowH
    }

    ; ⏐===================================================================================⏐
    ; ⏐=============================== ROW 3: Heist Toggle ===============================⏐
    ; ⏐===================================================================================⏐
    {
        ; Heist label 1
        txtHeistLabel := guiApp.AddText("x" xLabel " y" y " w" labelW, "Heist:")
        txtCasinoLabel := guiApp.AddText("x" (heistX + 20 / scale) " y" y " c" (heist == DIAMOND_CASINO ?
            "c648f64" :
                "White"),
        "Casino")
        ; Heist toggle
        picHeistToggle := guiApp.AddPicture("x" (heistX + 75 / scale) " y" (y - 2) " w" 40 / scale " h" 22 /
        scale " +0x4", heist == DIAMOND_CASINO ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png")
        ; Heist label 2
        txtCayoLabel := guiApp.AddText("x" (heistX + 125 / scale) " y" y " c" (heist == CAYO_PERICO ? "c648f64" :
            "White"), "Cayo Perico")
        ; Heist instruction text
        txtHeistInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9",
            "Switch between Casino and Cayo Perico heists (Usually handled by the script).")
        ; Heist event listener
        picHeistToggle.OnEvent("Click", ToggleHeistMode)
        y += rowH

        ; --- Info Text: Enable scripts to toggle heist and mode ---
        txtEnableScriptsInfo := guiApp.AddText("x" xLabel " y" (y - rowH / 2) " w" ((instrW * 3 / 4) + 15) " BackgroundTrans Center cA9A9A9",
        "Enable scripts to toggle heist and mode")
        txtEnableScriptsInfo.Opt("BackgroundTrans")
        txtEnableScriptsInfo.Visible := false
    }

    ; ⏐========================================================================================================⏐
    ; ⏐======================== ROW 4: Mode Options (Fingerprint / Keypad / Send PgUp) ========================⏐
    ; ⏐========================================================================================================⏐
    {
        modeX := xLabel, modeY := y, modeW := labelW, fingerprintX := (xField - 85 / scale)
        ; --- Casino mode options ---
        ; Mode label (row header)
        txtModeLabel := guiApp.AddText("x" xLabel " y" y " w" labelW, "Mode:")
        ; Fingerprint mode label
        txtFingerprintLabel := guiApp.AddText("x" fingerprintX " y" y
            " c" (fingerprintMode ? "c648f64" : "White"), "Fingerprint")
        ; Fingerprint mode toggle
        picFingerprintToggle := guiApp.AddPicture("x" (fingerprintX + 75 / scale) " y" (y - 2) " w" 40 / scale " h" 22 /
        scale " +0x4", fingerprintMode ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png")
        txtKeypadLabel := guiApp.AddText("x" (fingerprintX + 125 / scale) " y" y
        ; Keypad mode label
        " c" (!fingerprintMode ? "c648f64" : "White"), "Keypad")
        ; Mode instruction text
        txtModeInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")

        ; --- Cayo Perico options ---
        ; label
        txtPgUpLabel := guiApp.AddText("x" xLabel " y" y " w" labelW, "Send PgUp keybind:")
        ; hotkey field to send PgUp
        inputPgUp := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", AHKToDisplayHotkey(sendPgUpKey))
        ; instruction text
        txtPgUpInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")

        ; Casino / Cayo options event listeners
        picFingerprintToggle.OnEvent("Click", ToggleFingerprintMode)
        inputPgUp.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputPgUp, "SendPgUp", sendPgUpKey))
        inputPgUp.OnEvent("Change", (*) => AutoSaveKeybind(inputPgUp, "SendPgUp"))
        UpdateModeInstrText()
        UpdatePgUpInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐===========================ROW 5: Manual Keybind =========================⏐
    ; ⏐==========================================================================⏐
    {
        ; Manual keybind label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Manual keybind:")
        ; Manual keybind field
        inputManual := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", AHKToDisplayHotkey(manualKey))
        ; Manual keybind instruction text
        txtManualInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")
        ; Manual keybind event listeners
        inputManual.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputManual, "Manual", manualKey))
        inputManual.OnEvent("Change", (*) => AutoSaveKeybind(inputManual, "Manual"))
        UpdateManualInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐========================= ROW 6: AutoHack Keybind ========================⏐
    ; ⏐==========================================================================⏐
    {
        ; AutoHack keybind label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Auto hack keybind:")
        ; AutoHack keybind field
        inputAuto := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", AHKToDisplayHotkey(autoHackKey))
        ; AutoHack keybind instruction text
        txtAutoInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")
        ; AutoHack keybind event listeners
        inputAuto.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputAuto, "AutoHack", autoHackKey))
        inputAuto.OnEvent("Change", (*) => AutoSaveKeybind(inputAuto, "AutoHack"))
        UpdateAutoInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐========================== ROW 7: Reset Keybind ==========================⏐
    ; ⏐==========================================================================⏐
    {
        ; Reset keybind label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Reset script keybind:")
        ; Reset keybind field
        inputReset := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", AHKToDisplayHotkey(resetKey))
        ; Reset keybind instruction text
        txtResetInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9", "")
        ; Reset keybind event listeners
        inputReset.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputReset, "Reset", resetKey))
        inputReset.OnEvent("Change", (*) => AutoSaveKeybind(inputReset, "Reset"))
        UpdateResetInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐=============================== ROW 8: Delay =============================⏐
    ; ⏐==========================================================================⏐
    {
        ; Delay label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Delay:")
        ; Delay field
        inputDelay := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", delay)
        ; Delay instruction text
        txtDelayInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9",
            "Adjusts the speed of key-sending for automation (30-200 ms). 40ms is usually preferred.")
        ; Delay event listeners
        inputDelay.OnEvent("Focus", (*) => (
            AttachUnfocusHandlers(inputDelay, delay, 0),
            SetTimer(() => (
                inputDelay.Focus()
            ), -10)
        ))
        inputDelay.OnEvent("Change", (*) => AutoSaveDelay(inputDelay))
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐============================ Link and Tray Menu ==========================⏐
    ; ⏐==========================================================================⏐
    {
        ; Link to GitHub repo for issues and suggestions
        ; linkArea := guiApp.AddGroupBox("x" xLabel " y" (height / scale - 40 / scale) " w" (groupW - 2 * xLabel) " h" 30 /
        ; scale " cA9A9A9")
        linkText := guiApp.Add("Link", "xp y" (height / scale - (height / scale - (groupY + groupH)) /
        (1.5 / scale) " w" groupW " c8484db center"),
        'For bugs / suggestions: <a href="https://github.com/infpdev/gtao-heist-toolkit">github.com/infpdev</a>')
        linkText.SetFont("s" 10 / scale " bold")
        ; linkText.Opt("BackgroundTrans")
        ; linkText.OnEvent("Click", (*) => Run("https://github.com/infpdev/gtao-heist-toolkit"))

        ; Tray menu setup
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Show", (*) => (
            guiApp.Show(),
            ForceForeground(guiApp),
            SetTimer(() => ForceForeground(guiApp), -100)
        ))
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        A_TrayMenu.Default := ("Exit")
        A_TrayMenu.ClickCount := 1
    }

    ; ====================== Finalize GUI setup ======================
    OnMessage(0x0006, GuiApp_OnActivate) ; 0x0006 = WM_ACTIVATE
    SetRoundedCorners(guiApp.Hwnd, width, height, borderRadius)
    SetHeistToggleBtnVisibility(scriptsEnabled)
    SetModeToggleBtnVisibility((heist == DIAMOND_CASINO) && scriptsEnabled)

    if (noSave && !isFirewallEnabled())
        ToggleNoSaveStatus()

    TryRegisterHotkeys()

    ; Show and focus the GUI
    guiApp.Opt("+Caption")

    isFirewallEnabled()

    ForceForeground(guiApp)
    CenterGui(guiApp, width, height, scale)

    if (!scriptsEnabled)
        UpdateGlobalStatus(false)
    else {
        ; findAnchorsAndCreateInstance()
        SetTimer(findAnchorsAndCreateInstance, 1000)
        CreateHeistInstance()
    }
}

; SetTimer(() => (Init()), -1000)
Init()
