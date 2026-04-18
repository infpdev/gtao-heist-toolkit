#Requires AutoHotkey v2.0

; Initialized here for static analysis across includes; real control assignment happens in Init().
global inputPgUp := ""

; ⏐==========================================================================================================⏐
; ⏐====================================== UI Input Management Functions =====================================⏐
; ⏐==========================================================================================================⏐
{

    ; =============== Unfocus handlers ===============

    AttachUnfocusHandlers(field, prevValue, saveBtn) {
        global unfocusField, unfocusPrevValue, unfocusSaveBtn, sendPgUpKey, pgUpDisabled
        unfocusField := field
        unfocusPrevValue := prevValue
        unfocusSaveBtn := saveBtn
        ; Temporarily unregister PgUp hotkeys if LButton to prevent clicks from triggering PgUp
        if (sendPgUpKey == "LButton")
        ; UnregisterPgUpHotkey()
            pgUpDisabled := true
        OnMessage(0x100, EscUnfocusHandler)
        OnMessage(0x104, EscUnfocusHandler)
        OnMessage(0x101, KeyUpUnfocusHandler)
        OnMessage(0x105, KeyUpUnfocusHandler)
        OnMessage(0x201, MouseDownUnfocusHandler)

    }

    KeyUpUnfocusHandler(wParam, lParam, msg, hwnd) {
        global hotkeyCaptureField, hotkeyCaptureKeyName
        if !hotkeyCaptureField
            return
        if !IsCustomHotkeyField(hotkeyCaptureField)
            return

        vk := wParam + 0
        if IsModifierVK(vk) {
            mods := GetActiveModifiersDisplay()
            if (mods != "") {
                hotkeyCaptureField.Text := mods
                ; SetEditCaretToEnd(hotkeyCaptureField)
            }
        }
        AutoSaveKeybind(hotkeyCaptureField, hotkeyCaptureKeyName)
    }

    EscUnfocusHandler(wParam, lParam, msg, hwnd) {
        global unfocusField, unfocusPrevValue, settingsGroup, hotkeyCaptureField, hotkeyCaptureKeyName
        if !unfocusField
            return

        if HandleCustomHotkeyKeyDown(wParam, lParam, msg, hwnd)
            return 0

        vk := Format("{:X}", wParam)
        if (vk = "1B") {
            if (unfocusField && unfocusPrevValue != "")
                unfocusField.Text := unfocusPrevValue
            try bar.Focus()
            unfocusField := ""
            unfocusPrevValue := ""
            OnMessage(0x100, EscUnfocusHandler, 0)
            OnMessage(0x104, EscUnfocusHandler, 0)
            OnMessage(0x101, KeyUpUnfocusHandler, 0)
            OnMessage(0x105, KeyUpUnfocusHandler, 0)
            OnMessage(0x201, MouseDownUnfocusHandler, 0)
            hotkeyCaptureField := ""
            hotkeyCaptureKeyName := ""
            return 0
        }
    }

    MouseDownUnfocusHandler(wParam, lParam, msg, hwnd) {
        global guiApp, unfocusField, unfocusPrevValue, unfocusSaveBtn
        global inputManual, inputAuto, inputReset, inputDelay, inputNoSave, inputToggleScripts

        if !unfocusField
            return

        MouseGetPos &mx, &my, &win
        ctrl := GuiCtrlFromPoint(guiApp, mx, my)

        ; Only unfocus if click is outside the relevant controls
        if (ctrl != unfocusField && ctrl != inputManual && ctrl != inputAuto && ctrl != inputReset && ctrl !=
            inputDelay &&
            ctrl != inputNoSave && ctrl != inputToggleScripts) {
            DelayedCleanup()
        }
    }

    ; =============== Custom hotkey (modifiers) field logic ===============

    ; Checks if the given virtual key code corresponds
    ; to a modifier key. Used to prevent allowing modifier
    ; keys as standalone hotkeys.
    IsModifierVK(vk) {
        return vk = 0x10 || vk = 0x11 || vk = 0x12 || vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
            || vk = 0xA4 || vk = 0xA5
    }

    ; Checks if any modifier keys (Ctrl, Shift, Alt)
    ; are currently pressed. Used to prevent triggering
    ; hotkeys while the user is in the middle of entering a key combination.
    IsAnyModifierPressed() {
        return GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P") || GetKeyState("Alt", "P")
    }

    IsCustomHotkeyField(field) {
        global inputManual, inputAuto, inputReset, inputNoSave, inputToggleScripts, inputPgUp
        return field = inputManual || field = inputAuto || field = inputReset
            || field = inputNoSave || field = inputToggleScripts || field = inputPgUp
    }

    BeginCustomHotkeyEdit(field, keyName, currentAHKValue) {
        global hotkeyCaptureField, hotkeyCaptureKeyName
        display := AHKToDisplayHotkey(currentAHKValue)
        hotkeyCaptureField := field
        hotkeyCaptureKeyName := keyName
        field.Text := display
        AttachUnfocusHandlers(field, display, 0)
        field.Focus()
        ; SetEditCaretToEnd(field)
    }

    HandleCustomHotkeyKeyDown(wParam, lParam, msg, hwnd) {
        global hotkeyCaptureField, hotkeyCaptureKeyName
        if !hotkeyCaptureField
            return false
        if !IsCustomHotkeyField(hotkeyCaptureField)
            return false

        vk := wParam + 0

        ; Let Esc continue to the dedicated unfocus logic.
        if (vk = 0x1B)
            return false

        ; Keep normal tab navigation behavior.
        if (vk = 0x09)
            return false

        if IsModifierVK(vk) {
            hotkeyCaptureField.Text := GetActiveModifiersDisplay()
            ; SetEditCaretToEnd(hotkeyCaptureField)
            AutoSaveKeybind(hotkeyCaptureField, hotkeyCaptureKeyName)
            return true
        }

        keyName := GetKeyName("vk" Format("{:02X}", vk))
        if (keyName = "")
            return true

        display := GetActiveModifiersDisplay() keyName
        hotkeyCaptureField.Text := display
        ; SetEditCaretToEnd(hotkeyCaptureField)
        AutoSaveKeybind(hotkeyCaptureField, hotkeyCaptureKeyName)
        return true
    }

    ; ============== Hotkey saving logic ===============

    AutoSaveKeybind(field, keyName) {
        global autoSaveTimers
        static delayMs := 500

        ; Prevent saving while temporarily disabled to avoid conflicts with PgUp as LButton
        ; tends to send PgUp even though it's disabled, so this prevents saving when that happens.
        if (pgUpDisabled && pgUpSent)
            return

        ; Cancel previous timer for this field
        if autoSaveTimers.HasOwnProp(keyName) {
            SetTimer(autoSaveTimers[keyName], 0)
        }

        ; Create a new closure for this key
        timerFunc := () => SaveKeybindWhenIdle(field, keyName)
        autoSaveTimers[keyName] := timerFunc
        SetTimer(timerFunc, -delayMs)
    }

    SaveKeybindWhenIdle(field, keyName) {
        global autoSaveTimers

        if IsAnyModifierPressed() {
            if autoSaveTimers.HasOwnProp(keyName)
                SetTimer(autoSaveTimers[keyName], -100)
            return
        }

        SaveKeybind(field, keyName, 0)
    }

    SaveKeybind(field, keyName, btn) {
        global unfocusField, unfocusPrevValue, unfocusSaveBtn, iniFile, settingsGroup, hotkeyCaptureField,
            hotkeyCaptureKeyName
        global manualKey, autoHackKey, resetKey
        global prevManualKey, prevAutoHackKey, prevResetKey
        prevKey := ""

        switch keyName {
            case "Manual":
                prevKey := manualKey
            case "AutoHack":
                prevKey := autoHackKey
            case "Reset":
                prevKey := resetKey
            case "NoSave":
                global noSaveKey
                prevKey := noSaveKey
            case "ToggleScripts":
                global toggleScriptsKey
                prevKey := toggleScriptsKey
            case "SendPgUp":
                global sendPgUpKey
                prevKey := sendPgUpKey
        }

        val := DisplayToAHKHotkey(field.Text)

        if (val = "") {
            ; Revert when user input is empty or modifier-only.
            val := prevKey
            field.Text := AHKToDisplayHotkey(prevKey)
            field.Focus()
            ; SetEditCaretToEnd(field)
        }

        switch keyName {
            case "Manual":
                prevManualKey := manualKey
                manualKey := val
                UpdateManualInstrText()
            case "AutoHack":
                prevAutoHackKey := autoHackKey
                autoHackKey := val
                UpdateAutoInstrText()
            case "Reset":
                prevResetKey := resetKey
                resetKey := val
                UpdateResetInstrText()
            case "NoSave":
                noSaveKey := val
                UpdateNoSaveInstrText()
            case "ToggleScripts":
                toggleScriptsKey := val
                UpdateScriptsInstrText()
            case "SendPgUp":
                sendPgUpKey := val
                UpdatePgUpInstrText()
                TryRegisterPgUpHotkey(prevKey)
        }

        toolOnlyHotkey := (keyName == "NoSave" || keyName == "ToggleScripts" || keyName == "SendPgUp")
        section := toolOnlyHotkey ? "ToolHotkeys" : "Hotkeys"
        IniWrite(val, iniFile, section, keyName)
        sleep 100
        unfocusField := ""
        unfocusPrevValue := ""
        unfocusSaveBtn := ""
        OnMessage(0x201, MouseDownUnfocusHandler, 0)
        OnMessage(0x100, EscUnfocusHandler, 0)
        OnMessage(0x104, EscUnfocusHandler, 0)
        OnMessage(0x101, KeyUpUnfocusHandler, 0)
        OnMessage(0x105, KeyUpUnfocusHandler, 0)
        hotkeyCaptureField := ""
        hotkeyCaptureKeyName := ""
        try bar.Focus()
        TryRegisterHotkeys() ; Update hotkeys after saving
    }

    AutoSaveDelay(field) {
        static delayMs := 1000
        static timerFunc := 0
        ; Cancel previous timer for this field (debounce)
        if (timerFunc) {
            SetTimer(timerFunc, 0)
        }
        timerFunc := () => SaveDelay(field)
        SetTimer(timerFunc, -delayMs)
    }

    SaveDelay(field) {
        global unfocusField, unfocusPrevValue, unfocusSaveBtn, iniFile, settingsGroup, heistInstance, delay,
            hotkeyCaptureField, hotkeyCaptureKeyName
        val := field.Text
        ; Clamp value only after user is done typing
        if !IsInteger(val) || val < 30 || val > 200 {
            if (val = "" || !IsInteger(val))
                val := 30
            else if (val < 30)
                val := 30
            else if (val > 200)
                val := 200
            field.Text := val
            field.Focus()
            ; SetEditCaretToEnd(field)
        }
        IniWrite(val, iniFile, "Options", "Delay")
        delay := val
        if (heistInstance && IsObject(heistInstance) && heistInstance.setKeyDelay) {
            heistInstance.setKeyDelay(val)
        }

        sleep 100
        unfocusField := ""
        unfocusPrevValue := ""
        unfocusSaveBtn := ""
        OnMessage(0x201, MouseDownUnfocusHandler, 0)
        OnMessage(0x100, EscUnfocusHandler, 0)
        OnMessage(0x104, EscUnfocusHandler, 0)
        OnMessage(0x101, KeyUpUnfocusHandler, 0)
        OnMessage(0x105, KeyUpUnfocusHandler, 0)
        try bar.Focus()
    }

    DelayedCleanup() {
        global settingsGroup, unfocusField, unfocusPrevValue, unfocusSaveBtn, hotkeyCaptureField,
            hotkeyCaptureKeyName, sendPgUpKey, pgUpDisabled
        if !unfocusField
            return
        unfocusField.Text := unfocusPrevValue
        try bar.Focus()
        unfocusField := ""
        unfocusPrevValue := ""
        unfocusSaveBtn := ""
        OnMessage(0x201, MouseDownUnfocusHandler, 0)
        OnMessage(0x100, EscUnfocusHandler, 0)
        OnMessage(0x104, EscUnfocusHandler, 0)
        OnMessage(0x101, KeyUpUnfocusHandler, 0)
        OnMessage(0x105, KeyUpUnfocusHandler, 0)
        hotkeyCaptureField := ""
        hotkeyCaptureKeyName := ""
        ; Re-register PgUp hotkeys if LButton after input is unfocused
        if (sendPgUpKey == "LButton")
        ; TryRegisterPgUpHotkey()
            pgUpDisabled := false
    }

    ; ============== Hotkey / visual format functions ===============

    ; AHKToDisplayHotkey() moved to commonFuncs for use in multiple places.

    ; Converts a user-friendly hotkey string (e.g. "Ctrl+Shift+A") back to AHK format (e.g. "^+a"). Returns an empty string if the input is invalid.
    DisplayToAHKHotkey(displayValue) {
        value := Trim(displayValue)
        if (value = "")
            return ""

        if (SubStr(value, -1) = "+")
            return "" ; Partial modifier input only.

        tokens := StrSplit(value, "+")
        if (tokens.Length = 0)
            return ""

        key := Trim(tokens[tokens.Length])
        if (key = "")
            return ""

        if RegExMatch(key, "i)^(ctrl|control|shift|alt)$")
            return "" ; Modifier-only input is invalid.

        mods := ""
        loop (tokens.Length - 1) {
            t := Trim(tokens[A_Index])
            if (t = "")
                continue
            if RegExMatch(t, "i)^(ctrl|control)$") {
                if !InStr(mods, "^")
                    mods .= "^"
                continue
            }
            if RegExMatch(t, "i)^shift$") {
                if !InStr(mods, "+")
                    mods .= "+"
                continue
            }
            if RegExMatch(t, "i)^alt$") {
                if !InStr(mods, "!")
                    mods .= "!"
                continue
            }
            return ""
        }
        return mods key
    }

    ; Gets a display string of currently active modifiers
    ; (e.g. "Ctrl+Shift+"), used for showing the user what
    ; modifiers they are currently holding while they enter a hotkey.
    ; If includePlus is false, the returned string will not have a
    ; trailing plus sign (e.g. "Ctrl+Shift").
    GetActiveModifiersDisplay(includePlus := true) {
        parts := []
        if GetKeyState("Ctrl", "P")
            parts.Push("Ctrl")
        if GetKeyState("Shift", "P")
            parts.Push("Shift")
        if GetKeyState("Alt", "P")
            parts.Push("Alt")

        if (parts.Length = 0)
            return ""

        out := ""
        for _, name in parts
            out .= name "+"
        return includePlus ? out : SubStr(out, 1, -1)
    }

}

; =============== PgUp hotkey management ===============
TryRegisterPgUpHotkey(oldKey := "") {
    global sendPgUpKey, heist, scriptsEnabled, txtPgUpLabel
    pgUpSent := false
    txtPgUpLabel.Opt("cWhite")
    UnregisterPgUpHotkey(oldKey)
    if (heist == CAYO_PERICO && sendPgUpKey && scriptsEnabled) {
        Hotkey("~" sendPgUpKey, PgUpDown, "On")
        Hotkey("~" sendPgUpKey " up", PgUpUp, "On")
    }
}

isGtaFocused() {
    global guiApp
    return (WinActive("Grand Theft Auto") || WinActive("ahk_id " guiApp.Hwnd))
}

PgUpDown(*) {
    global txtPgUpLabel, pgUpSent, sendPgUpKey

    if (pgUpDisabled || pgUpSent)
        return

    if !isGtaFocused()
        return

    if (sendPgUpKey == "LButton") {
        if (!GetKeyState("RButton", "P")) {
            pgUpSent := true
            Send "{PgUp down}"
            txtPgUpLabel.Opt("c648f64")
            ToolTip "PgUp pressed (LMB)", scrW, 0, 20
        }
        ; If RButton is pressed, do nothing (block PgUp)
        return
    }

    ; For all other keys, always send PgUp
    txtPgUpLabel.Opt("c648f64")
    pgUpSent := true
    Send "{PgUp down}"
    ToolTip "PgUp pressed (" sendPgUpKey ")", scrW, 0, 20
}

PgUpUp(*) {
    global txtPgUpLabel, pgUpSent
    txtPgUpLabel.Opt("cWhite")

    if (!pgUpSent)
        return

    Send "{PgUp up}"
    pgUpSent := false
    UpdateGlobalStatus(hackInProgress)

}

UnregisterPgUpHotkey(keyToRemove := "") {
    global sendPgUpKey
    key := (keyToRemove != "") ? keyToRemove : sendPgUpKey
    if key {
        Hotkey("~" key, PgUpDown, "Off")
        Hotkey("~" key " up", PgUpUp, "Off")
    }
}
; ⏐==========================================================================================================⏐
