#Requires AutoHotkey v2.0

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}

SendMode("Event")
SetWorkingDir A_ScriptDir
CoordMode "ToolTip", "Screen"
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
#SingleInstance Force
SetTitleMatchMode 2
SetControlDelay 1
SetWinDelay 100
SetMouseDelay -1
SetBatchLines := -1
global vaultOps := true

; --- IMPORTS SECTION ---
; common imports
#Include <updateCheck>
#Include <initHotkeys>
#Include <ahk2py_socket>
#Include <ahk2dc_socket>
#Include <commonFuncs>

; vaultOps scripts
#Include <scripts\Fingerprint>
#Include <scripts\Keypad>
#Include <scripts\ElRubio>
#Include <scripts\NoSave>
#Include <scripts\LedgeGrab>

; GUI imports
#Include <gui\richPresence>
#Include <gui\hotkeyHelpers>
#Include <gui\windowHelpers>
#Include <gui\tooltipsHelpers>
#Include <gui\anchorDetection>
#Include <gui\instructionFieldHelpers>

if debug {
    CustomTooltip "In Debug mode", 0, 0, 20
    sleep 100
    Hotkey("F2 Up", ReloadVaultOps)
    Hotkey("F3 Up", (*) => ExitApp())
}

global reloading := false

ReloadVaultOps(*) {
    global reloading := true
    ShowCenteredToolTip "Reloading vaultOps", 15
    Reload()
}

global fnManualHotkey := ManualHotkey, fnAutoHackHotkey := AutoHackHotkey, fnResetHotkey := ResetScriptsHotkey,
    fnToggleNoSave := ToggleNoSaveStatus, fnToggleScripts := ToggleScriptsEnabled, fnToggleLedgeGrab :=
    ToggleLedgeGrabInProgress

; ⏐==========================================================================================================⏐
; ⏐============================================= Initialization =============================================⏐
; ⏐==========================================================================================================⏐
Init() {
    ; ===========Hotkeys===========
    global manualKey, autoHackKey, resetKey, noSaveKey, toggleScriptsKey, ledgeGrabKey

    global readableNoSaveKey := CanonicalToDisplay(noSaveKey)
    global readableScriptsKey := CanonicalToDisplay(toggleScriptsKey)
    global readableLedgeGrabKey := CanonicalToDisplay(ledgeGrabKey)
    global readableManualKey := CanonicalToDisplay(manualKey)
    global readableAutoHackKey := CanonicalToDisplay(autoHackKey)
    global readableResetKey := CanonicalToDisplay(resetKey)

    ; ========= GUI objects =========
    global Title := "vaultOps"
    global guiApp, mnmzBtn, xBtn, killBtn, dragBtn, settingsGroup
    global picFingerprintToggle, picScriptsEnabled, picNoSave, picLedgeGrabEnabled, picHeistToggle, picEngineToggle,
        picRichPresenceEnabled
    global inputManual, inputAuto, inputReset, inputDelay, inputNoSave,
        inputToggleScripts, inputLedgeGrabAutomation

    ; Text labels
    global txtHeistLabel, txtCasinoKortzLabel, txtCayoLabel, txtCayoOptionLabel,
        txtModeLabel, txtFingerprintLabel, txtKeypadLabel, txtEnableScriptsInfo, inputLedgeGrabText,
        txtEngineLabel, txtAHKLabel, txtOpenCVLabel

    ; Instruction text variables (global scope)
    global instrNoSave := "Lets you do the replay glitch in heists / missions.",
        instrScripts := "Enable the scripts to show the heist, engine, and mode toggle buttons.",
        instrLedgeGrab := "Automate the ledge grab glitch.",
        instrMode := "Switch between Fingerprint and Keypad script modes (Usually handled by the script).",
        instrAHKEngine := "Legacy AHK detection. Battle-tested and reliable (Auto-switched if required).",
        instrOpenCVEngine := "OpenCV detection. Works on all resolutions, with AHK fallback.",
        instrOpenCVOnly := "OpenCV only (fallback to AHK unsupported).",
        instrManual := "Let the script find the prints without selecting them automatically.",
        instrAuto := "Automatically hack the fingerprints / keypad.",
        instrReset := "Resets the current script's progress. Use in case of errors."

    ; Instruction text control variables (global scope)
    global txtNoSaveInstr := "", txtScriptsInstr := "", txtLedgeGrabInstr := "", txtModeInstr := "",
        txtManualInstr := "", txtAutoInstr := "", txtResetInstr := "",
        txtHeistInstr := "", txtAutoInstr := "", txtDelayInstr := "",
        txtEngineInstr := "", picEngineToggle := "", txtAHKInstr := "", txtOpenCVInstr := ""

    ; ======== Boolean flags and state variables ========
    global noSave, scriptsEnabled, ledgeGrabEnabled, fingerprintMode, engine, hackMode, heist,
        delay, iniFile, debug, isBeta
    global anchorFound := false, hackInProgress := false,
        ledgeGrabInProgress := false, LedgeGrabRunningSignal := false,
        cachedFingerprintAnchor := 0, cachedKeypadAnchor := 0, cachedRubioAnchor := 0,
        hackMode := "idle", heistInstance := "", autoSaveTimers := Map(),
        hotkeyCaptureField := "", hotkeyCaptureKeyName := ""

    ; ======= GUI Styling and dimension variables =======
    global width := 960, height := 540, borderRadius := 20
    global scrW := A_ScreenWidth, scrH := A_ScreenHeight
    global topbarW, topbarH, btnW, titleW, bar, scale := 1.0

    ; ======= Resource folder path (for images, etc.) ========
    global folder, unsupportedResolution, higherRes
    global staticFolder := A_ScriptDir "\lib\static\"

    ; ==== TEMP DEBUG BUILD ====
    ; higherRes := true
    ; debug := true

    ; ======= Parent GUI creation =======
    guiApp := Gui("-Caption -DPIScale", Title)
    guiApp.BackColor := "222222"
    overallFontSize := 11
    guiApp.SetFont("s" overallFontSize " cWhite")

    ; ======= Top bar =======
    topbarH := 30 / scale, btnW := 22 / scale
    topbarW := width, titleW := topbarW - btnW

    bar := guiApp.AddText("xm y0 w" titleW " h" topbarH " c648f64 Background222222 Left 0x200",
        "vaultOps ● Heist toolkit by .dev17 " (isBeta ? "(v" ver " beta)" : "(v" ver ")"))

    if (unsupportedResolution)
        guiApp.AddText("xm y0 w" titleW " h" topbarH " Center cff0000 BackgroundTrans 0x200",
            "*App running in unsupported resolution mode")

    picRichPresenceEnabled := guiApp.AddPicture("x" ((width - btnW - 150 / scale) / scale) " y" 7 / scale " w" btnW *
    1.1 " h" btnW * 1.1 " +0x4",
    staticFolder (richPresenceEnabled ? "\discord.png" : "\discordMuted.png"))
    picRichPresenceEnabled.OnEvent("Click", ToggleRichPresence)

    ; Kill GTA button
    killBtn := guiApp.AddPicture("x" ((width - btnW - 120 / scale) / scale) " y" 7 / scale " w" btnW " h" btnW " +0x4",
    staticFolder "\kill_gta.png")
    killBtn.OnEvent("Click", (*) => (KillGta()))

    guiApp.AddPicture("x" ((width - btnW - 87 / scale) / scale) " y" 7 / scale " w" 3 " h" btnW " +0x4",
    staticFolder "\separator.png")

    ; Close button
    xBtn := guiApp.AddPicture("x" ((width - btnW - 71 / scale) / scale) " y" 7 / scale " w" btnW " h" btnW " +0x4",
    staticFolder "\exit.png")
    xBtn.OnEvent("Click", (*) => (ExitApp()))

    dragBtn := guiApp.AddPicture("x" ((width - btnW - 40 / scale) / scale) " y" 7 / scale " w" btnW " h" btnW + 2 " +0x4",
    staticFolder "\drag.png")
    dragBtn.OnEvent("Click", StartDrag)

    ; Minimize button
    mnmzBtn := guiApp.AddPicture("x" ((width - btnW - 10 / scale) / scale) " y" 7 / scale " w" btnW " h" btnW " +0x4",
    staticFolder "\minimize.png")
    mnmzBtn.OnEvent("Click", (*) => (
        ToolTip("", , , 19)
        guiApp.Minimize()))

    ; ======= Group styling =======
    leftPadding := 40 / scale
    groupY := topbarH / scale
    groupH := (height - topbarH - leftPadding) / scale
    groupW := (width - leftPadding) / scale

    ; ======= Labels / fields styling =======
    numSettings := 9 ; Includes Engine and mode rows
    labelW := 140 / scale
    fieldW := 90 / scale
    rowH := (groupH - 65 / scale) / numSettings

    xLabel := 40 / scale
    xField := xLabel + labelW + 55 / scale
    xField2 := xField - 40 / scale
    xInstr := xField + fieldW + 75 / scale
    instrW := groupW - xInstr + leftPadding * 0.2
    toggleX := xField - 87 / scale
    y := groupY + 30 / scale
    toggleStartY := y + rowH * 3
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
        " Center Background222222 cWhite", CanonicalToDisplay(noSaveKey))
        ; Nosave instruction text
        txtNoSaveInstr := guiApp.AddLink("x" xInstr " y" y " w" instrW " cA9A9A9", "")
        ; Nosave event listeners
        picNoSave.OnEvent("Click", ToggleNoSaveStatus)
        inputNoSave.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputNoSave, "NoSave", noSaveKey))
        inputNoSave.OnEvent("Change", (*) => AutoSaveKeybind(inputNoSave, "NoSave"))

        UpdateNoSaveInstrText()
        y += rowH
    }

    ; ⏐===================================================================================⏐
    ; ⏐============================ ROW 2: Toggle Ledge-Grab =============================⏐
    ; ⏐===================================================================================⏐
    {
        ; Ledge-Grab label
        ledgeGrabInstrOffset := 20 / scale
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Enable Ledge Grab:")
        ; Ledge-Grab toggle
        picLedgeGrabEnabled := guiApp.AddPicture("x" xField2 " y" (y - adjustmentYOffset / 2) " w" 20 / scale " h" 20 /
        scale " +0x4",
        ledgeGrabEnabled ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png")
        ; Ledge-Grab hotkey field
        inputLedgeGrabText := guiApp.AddText("x" xField " y" y, "Cover Key:")
        inputLedgeGrabAutomation := guiApp.AddEdit("x+15 y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", CanonicalToDisplay(ledgeGrabKey))
        ; Ledge-Grab instruction text
        txtLedgeGrabInstr := guiApp.AddText("x" xInstr + ledgeGrabInstrOffset " y" y " w" instrW " cA9A9A9 BackgroundTrans",
            "")
        ; Ledge-Grab event listeners
        picLedgeGrabEnabled.OnEvent("Click", ToggleLedgeGrabEnabled)
        inputLedgeGrabAutomation.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputLedgeGrabAutomation,
            "LedgeGrab",
            ledgeGrabKey))
        inputLedgeGrabAutomation.OnEvent("Change", (*) => AutoSaveKeybind(inputLedgeGrabAutomation, "LedgeGrab"))

        inputLedgeGrabAutomation.Visible := ledgeGrabEnabled
        UpdateLedgeGrabInstrText(xInstr, ledgeGrabInstrOffset)
        y += rowH
    }

    ; ⏐===================================================================================⏐
    ; ⏐======================== ROW 3: Scripts toggle and keybind ========================⏐
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
        " Center Background222222 cWhite", CanonicalToDisplay(toggleScriptsKey))
        ; Scripts instruction text
        txtScriptsInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans", "")
        ; Scripts event listeners
        picScriptsEnabled.OnEvent("Click", ToggleScriptsEnabled)
        inputToggleScripts.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputToggleScripts, "ToggleScripts",
            toggleScriptsKey))
        inputToggleScripts.OnEvent("Change", (*) => AutoSaveKeybind(inputToggleScripts, "ToggleScripts"))

        UpdateScriptsInstrText()
        y += rowH
    }

    ; ⏐===================================================================================⏐
    ; ⏐===================== ROW 4: Engine Selection (AHK / OpenCV) ======================⏐
    ; ⏐===================================================================================⏐
    {
        engineX := toggleX - 5

        y := toggleStartY
        txtEngineLabel := guiApp.AddText("x" xLabel " y" y " w" labelW, "Engine:")

        if (higherRes) {
            engine := OpenCV_ENGINE
            txtOpenCVLabel := guiApp.AddText(
                "x" (engineX + 70 / scale) " y" y " c648f64",
                "OpenCV"
            )
        } else {
            txtAHKLabel := guiApp.AddText(
                "x" (engineX + 35 / scale) " y" y " c" (engine == AHK_ENGINE ? "c648f64" : "White"),
                "AHK"
            )

            picEngineToggle := guiApp.AddPicture(
                "x" (engineX + 75 / scale) " y" (y - 2) " w" 40 / scale " h" 22 / scale " +0x4",
                engine == AHK_ENGINE ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png"
            )

            txtOpenCVLabel := guiApp.AddText(
                "x" (engineX + 130 / scale) " y" y " c" (engine != AHK_ENGINE ? "c648f64" : "White"),
                "OpenCV"
            )
            picEngineToggle.OnEvent("Click", ToggleEngineMode)

        }
        txtEngineInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans", "")

        UpdateEngineInstrText()
        y += rowH
    }

    ; ⏐===================================================================================⏐
    ; ⏐=============================== ROW 5: Heist Toggle ===============================⏐
    ; ⏐===================================================================================⏐
    {
        heistX := toggleX - 5
        ; Heist label 1
        txtHeistLabel := guiApp.AddText("x" xLabel " y" y " w" labelW, "Heist:")
        txtCayoLabel := guiApp.AddText("x" (heistX - 10 / scale) " y" y " c" (heist == CAYO_PERICO ? "c648f64" :
            "White"), "Cayo Perico")
        ; Heist toggle
        picHeistToggle := guiApp.AddPicture("x" (heistX + 75 / scale) " y" (y - 2) " w" 40 / scale " h" 22 /
        scale " +0x4", heist == DCH_OR_KORTZ ? staticFolder "\toggleFlipped.png" : staticFolder "\toggle.png")
        ; Heist label 2
        txtCasinoKortzLabel := guiApp.AddText("x" (heistX + 123 / scale) " y" y " c"
        (heist == DCH_OR_KORTZ ? "c648f64" : "White"), "DC / Kortz")

        ; Heist instruction text
        txtHeistInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans",
            "Switch between Cayo Perico and Casino / Kortz heists (Usually handled by the script).")
        ; Heist event listener
        picHeistToggle.OnEvent("Click", ToggleHeistMode)
        y += rowH

        ; --- Info Text: Enable scripts to toggle heist and mode ---
        txtEnableScriptsInfo := guiApp.AddText("x" xLabel + 25 " yp h20 w" ((instrW * 3 / 4) + 15) " BackgroundTrans Center cA9A9A9",
        "Enable scripts to toggle heist, engine, and mode")
        txtEnableScriptsInfo.SetFont("s12")
        txtEnableScriptsInfo.Opt("BackgroundTrans")
        txtEnableScriptsInfo.Visible := false
    }

    ; ⏐========================================================================================================⏐
    ; ⏐============================== ROW 6: Mode Options (Fingerprint / Keypad) ==============================⏐
    ; ⏐========================================================================================================⏐
    {
        fingerprintX := toggleX - 5, modeY := y, modeW := labelW
        ; --- Casino / Kortz mode options ---
        ; Mode label (row header)
        txtModeLabel := guiApp.AddText("x" xLabel " y" y " w" labelW, "Mode:")
        ; Fingerprint mode label
        txtFingerprintLabel := guiApp.AddText("x" fingerprintX " y" y
            " c" (fingerprintMode ? "c648f64" : "White"), "Fingerprint")
        ; Fingerprint mode toggle
        picFingerprintToggle := guiApp.AddPicture("x" (fingerprintX + 75 / scale) " y"
        (y - 2) " w" 40 / scale " h" 22 / scale " +0x4",
        fingerprintMode ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png")
        txtKeypadLabel := guiApp.AddText("x" (fingerprintX + 134 / scale) " y" y
        ; Keypad mode label
        " c" (!fingerprintMode ? "c648f64" : "White"), "Keypad")
        ; Mode instruction text
        txtModeInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans", "")

        ; --- Cayo Perico options ---
        txtCayoOptionLabel := guiApp.AddText("x" xLabel - 30 " yp-5 h20 w" ((instrW * 3 / 4) + 15) " BackgroundTrans Center cA9A9A9",
        "Switch to Casino / Kortz to toggle mode")
        txtCayoOptionLabel.SetFont("s12")

        ; Casino / Cayo options event listeners
        picFingerprintToggle.OnEvent("Click", ToggleFingerprintMode)
        UpdateModeInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐===========================ROW 7: Manual Keybind =========================⏐
    ; ⏐==========================================================================⏐
    {
        ; Manual keybind label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Manual keybind:")
        ; Manual keybind field
        inputManual := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", CanonicalToDisplay(manualKey))
        ; Manual keybind instruction text
        txtManualInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans", "")
        ; Manual keybind event listeners
        inputManual.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputManual, "Manual", manualKey))
        inputManual.OnEvent("Change", (*) => AutoSaveKeybind(inputManual, "Manual"))
        UpdateManualInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐========================= ROW 8: AutoHack Keybind ========================⏐
    ; ⏐==========================================================================⏐
    {
        ; AutoHack keybind label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Auto hack keybind:")
        ; AutoHack keybind field
        inputAuto := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", CanonicalToDisplay(autoHackKey))
        ; AutoHack keybind instruction text
        txtAutoInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans", "")
        ; AutoHack keybind event listeners
        inputAuto.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputAuto, "AutoHack", autoHackKey))
        inputAuto.OnEvent("Change", (*) => AutoSaveKeybind(inputAuto, "AutoHack"))
        UpdateAutoInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐========================== ROW 9: Reset Keybind ==========================⏐
    ; ⏐==========================================================================⏐
    {
        ; Reset keybind label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Reset script keybind:")
        ; Reset keybind field
        inputReset := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", CanonicalToDisplay(resetKey))
        ; Reset keybind instruction text
        txtResetInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans", "")
        ; Reset keybind event listeners
        inputReset.OnEvent("Focus", (*) => BeginCustomHotkeyEdit(inputReset, "Reset", resetKey))
        inputReset.OnEvent("Change", (*) => AutoSaveKeybind(inputReset, "Reset"))
        UpdateResetInstrText()
        y += rowH
    }

    ; ⏐==========================================================================⏐
    ; ⏐=============================== ROW 10: Delay =============================⏐
    ; ⏐==========================================================================⏐
    {
        ; Delay label
        guiApp.AddText("x" xLabel " y" y " w" labelW, "Delay:")
        ; Delay field
        inputDelay := guiApp.AddEdit("x" xField " y" (y - adjustmentYOffset) " w" fieldW
        " Center Background222222 cWhite", delay)
        ; Delay instruction text
        txtDelayInstr := guiApp.AddText("x" xInstr " y" y " w" instrW " cA9A9A9 BackgroundTrans",
            "Adjusts the speed of key-sending for automation (30-200 ms). 40ms is usually preferred")
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
    ; ⏐================================== Links =================================⏐
    ; ⏐==========================================================================⏐
    {
        ; Link to GitHub repo for issues and suggestions
        linkText := guiApp.Add("Link", "xp-55 y" (height / scale - (height / scale - (groupY + groupH)) /
        (1.5 / scale) " w" groupW " c8484db center"),
        'For bugs / suggestions: <a href="https://infpdev.netlify.app?vaultOps=1">github.com/infpdev</a>')
        linkText.SetFont("s" 10 / scale " bold")

        ; Tray menu setup
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Show", (*) => (
            guiApp.Show(),
            CenterGui(guiApp, width, height),
            ForceForeground(guiApp),
            SetTimer(() => ForceForeground(guiApp), -100)
        ))
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        A_TrayMenu.Default := ("Show")
        A_TrayMenu.ClickCount := 1
    }

    ; ====================== Finalize GUI setup ======================
    OnMessage(0x0006, GuiApp_OnActivate)
    OnMessage(0x0020, OnSetCursor)

    SetRoundedCorners(guiApp.Hwnd, width, height, borderRadius)
    SetHeistToggleBtnVisibility(false)
    SetEngineToggleBtnVisibility(false)
    SetModeToggleBtnVisibility(false)

    LoadCache()

    isFirewallEnabled()

    TryRegisterHotkeys()

    if (ledgeGrabEnabled)
        try Hotkey(CanonicalToRegistration(ledgeGrabKey), ToggleLedgeGrabInProgress, "On")

    ; Show and focus the GUI
    guiApp.Opt("+Caption")

    if (richPresenceEnabled && IsDiscordRunning())
        EnableRichPresence()

    ForceForeground(guiApp)

    guiApp.Opt("-Caption")
    CenterGui(guiApp, width, height, scale)

    FocusGtaIfRunning()

    UpdateGlobalStatus(false)

}

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
        global fingerprintMode, heistInstance, scriptsEnabled, delay, heist,
            hackMode, txtCayoOptionLabel, engine, higherRes

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
            heistInstance := ElRubioSolver(delay, UpdateGlobalStatus, cachedRubioAnchor, "", higherRes,
                engine)

        } else if (heist == DCH_OR_KORTZ) {
            if (fingerprintMode) {
                heistInstance := FingerprintSolver(delay, UpdateGlobalStatus,
                    cachedFingerprintAnchor, "", higherRes, engine)
            } else {
                heistInstance := KeypadSolver(delay, UpdateGlobalStatus, cachedKeypadAnchor, "",
                    higherRes, engine)
            }

        }

    }

    /**
     * Destroys the current heist instance (if any) and creates a new one based on current settings.
     * Used for switching between fingerprint/keypad modes or heists.
     * 
     * Side effects: Updates global heistInstance.
     */
    SwitchHeistInstance() {
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
    ; Also updates status tooltip to reflect changes.
    TryRegisterHotkeys() {
        global manualKey, autoHackKey, resetKey, noSaveKey, toggleScriptsKey, scriptsEnabled, ledgeGrabKey,
            ledgeGrabEnabled
        static regNoSaveKey := "", regToggleScriptsKey := "", regManualKey := "",
            regAutoHackKey := "", regResetKey := "", regLedgeGrabKey := ""

        ; Helper function to safely register a hotkey value as-is.
        RegisterHotkeyWithFallback(hotkeyValue, hotkeyFunc, existingValue := "") {
            if (hotkeyValue = "")
                return true
            finalFormat := CanonicalToRegistration(hotkeyValue)

            ; Unregister old key if different
            if (existingValue != "" && existingValue != hotkeyValue) {
                try {
                    Hotkey("~*" CanonicalToRegistration(existingValue), hotkeyFunc, "Off")
                }
            }

            ; Try to register the hotkey
            try {
                Hotkey("~*" finalFormat, hotkeyFunc, "On")
                return true
            } catch as err {
                MsgBox "Failed to register hotkey '" finalFormat "':`n" err.What "`n`nPlease check your hotkey settings.",
                    "Hotkey Registration Failed", 48
                return false
            }
        }

        ; Unregister old NoSave/ToggleScripts keys if they changed
        if (regNoSaveKey && regNoSaveKey != noSaveKey) {
            try Hotkey("~*" CanonicalToRegistration(regNoSaveKey), fnToggleNoSave, "Off")
        }
        if (regToggleScriptsKey && regToggleScriptsKey != toggleScriptsKey) {
            try Hotkey("~*" CanonicalToRegistration(regToggleScriptsKey), fnToggleScripts, "Off")
        }
        if (regLedgeGrabKey && regLedgeGrabKey != ledgeGrabKey)
            try RegisterLedgeGrabHotkey(false, regLedgeGrabKey)

        ; Register NoSave and ToggleScripts (always active)
        if (noSaveKey) {
            if RegisterHotkeyWithFallback(noSaveKey, fnToggleNoSave, regNoSaveKey)
                regNoSaveKey := noSaveKey
        }
        if (toggleScriptsKey) {
            if RegisterHotkeyWithFallback(toggleScriptsKey, fnToggleScripts, regToggleScriptsKey)
                regToggleScriptsKey := toggleScriptsKey
        }

        if (ledgeGrabEnabled && ledgeGrabKey) {
            if RegisterLedgeGrabHotkey(true)
                regLedgeGrabKey := ledgeGrabKey
        }

        ; If scripts are disabled, unregister all manual/auto/reset hotkeys
        if (!scriptsEnabled) {
            if (regManualKey) {
                try Hotkey("~*" CanonicalToRegistration(regManualKey), fnManualHotkey, "Off")
            }
            if (regAutoHackKey) {
                try Hotkey("~*" CanonicalToRegistration(regAutoHackKey), fnAutoHackHotkey, "Off")
            }
            if (regResetKey) {
                try Hotkey("~*" CanonicalToRegistration(regResetKey), fnResetHotkey, "Off")
            }
            regManualKey := ""
            regAutoHackKey := ""
            regResetKey := ""
            UnregisterHotkeys()
            UpdateGlobalStatus(hackInProgress)
            return
        }

        ; Unregister old Manual/Auto/Reset keys if they changed
        if (regManualKey && regManualKey != manualKey) {
            try Hotkey("~*" CanonicalToRegistration(regManualKey), fnManualHotkey, "Off")
        }
        if (regAutoHackKey && regAutoHackKey != autoHackKey) {
            try Hotkey("~*" CanonicalToRegistration(regAutoHackKey), fnAutoHackHotkey, "Off")
        }
        if (regResetKey && regResetKey != resetKey) {
            try Hotkey("~*" CanonicalToRegistration(regResetKey), fnResetHotkey, "Off")
        }

        ; Register Manual/Auto/Reset hotkeys
        if (manualKey) {
            if RegisterHotkeyWithFallback(manualKey, fnManualHotkey, regManualKey)
                regManualKey := manualKey
        }
        if (autoHackKey) {
            if RegisterHotkeyWithFallback(autoHackKey, fnAutoHackHotkey, regAutoHackKey)
                regAutoHackKey := autoHackKey
        }
        if (resetKey) {
            if RegisterHotkeyWithFallback(resetKey, fnResetHotkey, regResetKey)
                regResetKey := resetKey
        }

        UpdateGlobalStatus(hackInProgress)
    }

    ManualHotkey(*) {
        global fingerprintMode, heistInstance, hackMode, heist

        if (cannotUseScriptsWhenGtaNotFocused(, scriptsEnabled)) {
            return
        }

        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip("", , , 17), -2000
            return
        }

        hackMode := "manual"
        if (IsObject(heistInstance)) {
            if (heist == CAYO_PERICO)
                heistInstance.switchToManual()
            else if (heist == DCH_OR_KORTZ) {
                heistInstance.switchToManual()
            }

            UpdateGlobalStatus(hackInProgress)

        } else {
            CustomTooltip "Manual hotkey triggered!"
            SetTimer () => CustomTooltip(), -700
        }
    }

    AutoHackHotkey(*) {
        global fingerprintMode, heistInstance, hackMode, heist

        if (cannotUseScriptsWhenGtaNotFocused(, scriptsEnabled)) {
            return
        }

        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip("", , , 17), -2000
            return
        }

        hackMode := "auto"
        if (IsObject(heistInstance)) {
            if (heist == CAYO_PERICO)
                heistInstance.SwitchToAuto()
            else if (heist == DCH_OR_KORTZ) {
                if (fingerprintMode)
                    heistInstance.SwitchToAuto()
                else
                    heistInstance.switchToAuto()
            }

            UpdateGlobalStatus(hackInProgress)

        } else {
            CustomTooltip "AutoHack hotkey triggered!"
            SetTimer () => CustomTooltip(), -700
        }
    }

    ResetScriptsHotkey(*) {
        global hackMode, hackInProgress

        if (cannotUseScriptsWhenGtaNotFocused(, scriptsEnabled)) {
            return
        }

        hackMode := "idle"
        hackInProgress := false
        SetTimer(findAnchorsAndCreateInstance, 0) ; Restart anchor detection timer
        if (IsObject(heistInstance)) {
            if (heistInstance) {
                CustomTooltip "Resetting script", scrW, 0, 20
                try heistInstance.Destroy()
                sleep 500
                CreateHeistInstance()
                UpdateGlobalStatus(false, , , , true)
            }
            else {
                CustomTooltip "Reset hotkey triggered!"
                SetTimer () => CustomTooltip(), -700
            }
        }

        if (ledgeGrabInProgress) {
            ToggleLedgeGrabInProgress()
        }

        SetTimer(findAnchorsAndCreateInstance, 500) ; Restart anchor detection timer

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

        SwitchHeistInstance() ; Restart the heist instance to reset state
        clearAllToolTips(0)
        UpdateGlobalStatus(false)
        if (scriptsEnabled) {
            SetTimer () => (
                SetTimer(findAnchorsAndCreateInstance, 500)
            ), -5000
        }

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
    UpdateGlobalStatus(isHacking, isTimingOut := false, timeoutProgress := 0, caller := "", force := false, *) {
        static previousStatus := ""
        static unsupportedResolutionText := unsupportedResolution ? "(Unsupported resolution)`n" : ""

        pos := getToolTipPos(toolTipPos)
        x := pos.x
        y := pos.y

        global hackMode, fingerprintMode, scriptsEnabled, ledgeGrabEnabled, noSave, manualKey, noSaveKey, ledgeGrabKey,
            autoHackKey, resetKey, hackInProgress, heist, unsupportedResolution,
            ledgeGrabInProgress

        global readableAutoHackKey, readableManualKey, readableResetKey,
            readableNoSaveKey, readableLedgeGrabKey, readableScriptsKey

        ; noSaveText := noSave ? "NoSave enabled" : "NoSave disabled"
        noSaveText := "Press " readableNoSaveKey " to " (noSave ? "disable" : "enable") " NoSave"

        ledgeGrabText := ledgeGrabEnabled ? "Press " readableLedgeGrabKey " to " (ledgeGrabInProgress ? "stop" :
            "initiate") " Ledge Grab" : "Ledge Grab disabled"

        earlyReturn := false

        if (caller && debug)
            ShowCenteredToolTip "Called by: " caller, 10, 25

        if (!scriptsEnabled) {
            status := "Scripts disabled`n" noSaveText "`n" ledgeGrabText
            earlyReturn := true
            CustomTooltip(unsupportedResolutionText . status, x, y, 20)
        }

        if (isTimingOut) {
            earlyReturn := true
            status := "Timeout in " timeoutProgress "s"
            CustomTooltip(status, x, y, 20)
        }

        if (earlyReturn) {
            MakeAllToolTipsClickThrough(hackMode == "idle" && !noSave)
            UpdateCurrentActivity()
            return
        }

        if (hackMode == "idle") {
            hackStatus := "Auto detection active`n"
            if (heist == DCH_OR_KORTZ) {
                hackStatus .= fingerprintMode ? "Fingerprint mode (idle)" : "Keypad mode (idle)"
            } else if (heist == CAYO_PERICO) {
                hackStatus .= "El Rubio mode (idle)"
            } else {
                hackStatus .= "Unknown mode (idle)"
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

        keys := (hackMode == "manual" ? indicator : "") "Manual: " readableManualKey "`n" (hackMode == "auto" ?
            indicator : "") "Auto: " readableAutoHackKey "`nReset: " readableResetKey

        aggregatedStatus := unsupportedResolutionText . hackStatus "`n" noSaveText "`n" ledgeGrabText "`n" keys

        if (aggregatedStatus != previousStatus || force) { ; Only update tooltip if status has changed to reduce flickering
            previousStatus := aggregatedStatus
            pos := getToolTipPos(toolTipPos)
            x := pos.x
            y := pos.y
            CustomTooltip(aggregatedStatus, x, y, 20)

            MakeAllToolTipsClickThrough(hackMode == "idle" && !noSave)
        }
        UpdateCurrentActivity()
    }

}
; ⏐==========================================================================================================⏐

; ⏐==========================================================================================================⏐
; ⏐=========================================== UI Toggle Functions ==========================================⏐
; ⏐==========================================================================================================⏐
{

    ToggleRichPresence(*) {
        global richPresenceEnabled, iniFile, picRichPresenceEnabled, lastRPCError

        if (richPresenceEnabled)
            DisableRichPresence()
        else {
            if (!lastRPCError || (lastRPCError && A_TickCount - lastRPCError > 30000)) {
                lastRPCError := 0
                EnableRichPresence()
            } else {
                MsgBox "Cannot enable Discord Rich Presence due to a recent error. Please try again in "
                    . Round((30000 - (A_TickCount - lastRPCError)) / 1000)
                    . " seconds.", "Discord RPC Error", 48
                return
            }
        }

        picRichPresenceEnabled.Value := richPresenceEnabled ? staticFolder "\discord.png" : staticFolder "\discordMuted.png"
    }

    /**
     * Toggles the solver scripts on/off, updates the UI elements, and registers/unregisters the associated hotkeys.
     * If GTA is not focused, shows a warning and does not toggle scripts.
     */
    ToggleScriptsEnabled(*) {
        static showedWarning := false
        global scriptsEnabled, picScriptsEnabled, iniFile, heistInstance, noSave, hackMode, hackInProgress

        if (!scriptsEnabled && cannotUseScriptsWhenGtaNotFocused(true, scriptsEnabled)) {
            if (!showedWarning) {
                ShowCenteredToolTip "Toggle Script Hotkey Inactive [GTA Not Focused]", 1
                SetTimer(() => CustomTooltip(), -5000)
                showedWarning := true
            }
            return
        }

        showedWarning := false

        hackMode := "idle"
        hackInProgress := false
        scriptsEnabled := !scriptsEnabled
        clearAllToolTips(scriptsEnabled)
        if (scriptsEnabled) {
            ; findAnchorsAndCreateInstance()
            SetTimer(findAnchorsAndCreateInstance, 500)
        } else {
            SetTimer(findAnchorsAndCreateInstance, 0)
        }
        SetHeistToggleBtnVisibility(scriptsEnabled)
        SetEngineToggleBtnVisibility(scriptsEnabled)
        SetModeToggleBtnVisibility((heist == DCH_OR_KORTZ) && scriptsEnabled)
        TryRegisterHotkeys()
        picScriptsEnabled.Value := scriptsEnabled ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
        ; IniWrite(scriptsEnabled, iniFile, "Options", "scriptsEnabled") ; Not required anymore since it's reset on every launch.
        CreateHeistInstance()
        UpdateGlobalStatus(scriptsEnabled && hackInProgress, , , , true)

    }

    ; Toggles the ledge-grab feature on/off, updates the UI elements, and registers/unregisters the associated hotkey.
    ToggleLedgeGrabEnabled(*) {
        global ledgeGrabEnabled, iniFile, picLedgeGrabEnabled, txtLedgeGrabInstr, inputLedgeGrabText,
            hackInProgress,
            ledgeGrabInProgress
        ledgeGrabEnabled := !ledgeGrabEnabled
        ledgeGrabInProgress := false
        BlockInput 0

        if (ledgeGrabEnabled)
            FocusGtaIfRunning()

        RegisterLedgeGrabHotkey(ledgeGrabEnabled)

        inputLedgeGrabAutomation.Visible := ledgeGrabEnabled
        picLedgeGrabEnabled.Value := ledgeGrabEnabled ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
        UpdateLedgeGrabInstrText()
        IniWrite(ledgeGrabEnabled, iniFile, "Options", "ledgeGrab")
        UpdateGlobalStatus(hackInProgress)
    }

    ToggleNoSaveStatus(*) {
        global noSave, picNoSave, iniFile, scriptsEnabled

        if (cannotToggleNoSaveWhenGtaNotFocused(noSave)) {
            return
        }

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
        } else {
            if (EnableNoSaveMode())
                noSave := true
        }

        UpdateGlobalStatus(hackInProgress)

        picNoSave.Value := noSave ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
    }

    ToggleHeistMode(*) {
        global heist, picHeistToggle, txtCasinoKortzLabel, txtCayoLabel, DCH_OR_KORTZ, CAYO_PERICO, scriptsEnabled
        global txtModeLabel, txtFingerprintLabel, txtKeypadLabel, txtModeInstr, hackInProgress
        heist := (heist == DCH_OR_KORTZ) ? CAYO_PERICO : DCH_OR_KORTZ
        picHeistToggle.Value := (heist == DCH_OR_KORTZ) ? staticFolder "\toggleFlipped.png" : staticFolder "\toggle.png"
        txtCasinoKortzLabel.Opt("c" (heist == DCH_OR_KORTZ ? "c648f64" : "White"))
        txtCayoLabel.Opt("c" (heist == CAYO_PERICO ? "c648f64" : "White"))
        SetModeToggleBtnVisibility((heist == DCH_OR_KORTZ) && scriptsEnabled)
        UpdateGlobalStatus(hackInProgress)
        IniWrite(heist, iniFile, "Options", "heist")
        SwitchHeistInstance()
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
        SwitchHeistInstance() ; Switch instance on mode toggle
        IniWrite(fingerprintMode, iniFile, "Options", "FingerprintMode")
    }

    /**
     * Toggles between AHK and OpenCV engine modes, 
     * updates the toggle button and labels, and sets the engine mode in the current heist instance if it exists.
     */
    ToggleEngineMode(params := "", info := "", to := "") {
        global engine, picEngineToggle, iniFile, txtAHKLabel, txtOpenCVLabel, txtEngineLabel, hackInProgress,
            heistInstance
        if (to == AHK_ENGINE) {
            engine := AHK_ENGINE
        } else if (to == OPENCV_ENGINE) {
            engine := OPENCV_ENGINE
        } else
            engine := !engine

        picEngineToggle.Value := engine == AHK_ENGINE ? staticFolder "\toggle.png" : staticFolder "\toggleFlipped.png"
        txtAHKLabel.Opt("c" (engine == AHK_ENGINE ? "c648f64" : "White"))
        txtOpenCVLabel.Opt("c" (engine != AHK_ENGINE ? "c648f64" : "White"))

        if (heistinstance && heistInstance != "") {
            heistInstance.setEngine(engine)
        }
        clearAllToolTips(1)

        UpdateEngineInstrText()

        IniWrite(engine, iniFile, "Options", "Engine")
        UpdateGlobalStatus(hackInProgress)
    }

    ; Callback for using the OpenCV engine, used by solvers to switch
    ; to OpenCV mode when AHK detection fails several times
    UseOpenCVEngineCallback() {
        ToggleEngineMode("", "", OpenCV_ENGINE)
    }

    SetModeToggleBtnVisibility(enabled) {
        global picFingerprintToggle, txtModeLabel, txtFingerprintLabel, txtKeypadLabel, txtModeInstr
        if !IsSet(picFingerprintToggle) || !picFingerprintToggle
            return
        global heist

        if IsSet(txtCayoOptionLabel) {
            show := (heist == CAYO_PERICO) && scriptsEnabled
            txtCayoOptionLabel.Visible := show
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

CleanUpVaultOps(*) {
    global isShuttingDown := true, reloading
    clearAllToolTips(1)
    if (reloading) {
        ShowCenteredToolTip "Reloading vaultOps"
    } else {
        ShowCenteredToolTip "Exiting vaultOps"
    }
    try SaveCache()
    try PersistSettingsToAppData()
    ClearRichPresence()
    try StopDiscordRPC()
    try StopPython()
}

initPython()
StartDiscordRPC()
Init()

OnExit(CleanUpVaultOps)