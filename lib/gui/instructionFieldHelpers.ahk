#Requires AutoHotkey v2.0

; ⏐==========================================================================================================⏐
; ⏐================================================ UI FUNCS ================================================⏐
; ⏐==========================================================================================================⏐
{

    UpdatePgUpInstrText() {
        global txtPgUpInstr, sendPgUpKey
        hotKeyTextPgUp := " Hold " CanonicalToDisplay(sendPgUpKey) " to test PgUp."
        if IsSet(txtPgUpInstr)
            txtPgUpInstr.Text := "Lets you use the plasma cutters during the heist." hotKeyTextPgUp
    }

    UpdateNoSaveInstrText() {
        global instrNoSave, noSaveKey, txtNoSaveInstr
        hotKeyTextNoSave := " Press " CanonicalToDisplay(noSaveKey) " to toggle."
        if IsSet(txtNoSaveInstr)
            txtNoSaveInstr.Text := instrNoSave hotKeyTextNoSave
    }

    UpdateScriptsInstrText() {
        global instrScripts, toggleScriptsKey, txtScriptsInstr
        hotKeyTextScripts := " Press " CanonicalToDisplay(toggleScriptsKey) " to toggle."
        if IsSet(txtScriptsInstr)
            txtScriptsInstr.Text := instrScripts hotKeyTextScripts
    }

    UpdateLedgeGrabInstrText(pos := 0, offset := 0) {
        static instrPos := 0, instrOffset := 0
        global instrLedgeGrab, ledgeGrabKey, txtLedgeGrabInstr, inputLedgeGrabText

        if (pos != 0)
            instrPos := pos
        if (offset != 0)
            instrOffset := offset

        if (!ledgeGrabEnabled) {
            inputLedgeGrabText.Visible := false
            hotKeyTextLedgeGrab := " Enable to allow automation."
            finalText := instrLedgeGrab hotKeyTextLedgeGrab
            txtLedgeGrabInstr.Move(instrPos)
        } else {
            inputLedgeGrabText.Visible := true
            enabledInstrText := "Ledge grab automation enabled."
            hotKeyTextLedgeGrab := " Press " CanonicalToDisplay(ledgeGrabKey) " in game to automate ledge-grab."
            finalText := enabledInstrText hotKeyTextLedgeGrab
            txtLedgeGrabInstr.Move(instrPos + instrOffset)

        }

        if IsSet(txtLedgeGrabInstr)
            txtLedgeGrabInstr.Text := finalText
    }

    UpdateModeInstrText() {
        global instrMode, txtModeInstr
        hotKeyTextMode := ""
        if IsSet(txtModeInstr)
            txtModeInstr.Text := instrMode hotKeyTextMode
    }

    UpdateEngineInstrText() {
        global instrAHKEngine, instrOpenCVEngine, txtEngineInstr, higherRes, instrOpenCVOnly
        if IsSet(txtEngineInstr) {
            if (higherRes)
                txtEngineInstr.Text := instrOpenCVOnly
            else
                txtEngineInstr.Text := engine == AHK_ENGINE ? instrAHKEngine : instrOpenCVEngine
        }
    }

    UpdateManualInstrText() {
        global instrManual, manualKey, txtManualInstr
        hotKeyTextManual := " Press " CanonicalToDisplay(manualKey) " to trigger."
        if IsSet(txtManualInstr)
            txtManualInstr.Text := instrManual hotKeyTextManual
    }

    UpdateAutoInstrText() {
        global instrAuto, autoHackKey, txtAutoInstr
        hotKeyTextAuto := " Press " CanonicalToDisplay(autoHackKey) " to trigger."
        if IsSet(txtAutoInstr)
            txtAutoInstr.Text := instrAuto hotKeyTextAuto
    }

    UpdateResetInstrText() {
        global instrReset, resetKey, txtResetInstr
        hotKeyTextReset := " Press " CanonicalToDisplay(resetKey) " to trigger."
        if IsSet(txtResetInstr)
            txtResetInstr.Text := instrReset hotKeyTextReset
    }

    SetHeistToggleBtnVisibility(enabled) {
        global picHeistToggle, txtHeistLabel, txtCasinoKortzLabel, txtCayoLabel, txtHeistInstr
        if !IsSet(picHeistToggle) || !picHeistToggle
            return
        global txtEnableScriptsInfo

        if enabled {
            picHeistToggle.Visible := true
            picHeistToggle.Opt("BackgroundTrans")
            picHeistToggle.OnEvent("Click", ToggleHeistMode)
            if IsSet(txtHeistLabel)
                txtHeistLabel.Visible := true
            if IsSet(txtCasinoKortzLabel)
                txtCasinoKortzLabel.Visible := true
            if IsSet(txtCayoLabel)
                txtCayoLabel.Visible := true
            if IsSet(txtHeistInstr)
                txtHeistInstr.Visible := true
            if IsSet(txtEnableScriptsInfo)
                txtEnableScriptsInfo.Visible := false

        } else {
            picHeistToggle.Visible := false
            picHeistToggle.OnEvent("Click", ToggleHeistMode, 0)
            if IsSet(txtHeistLabel)
                txtHeistLabel.Visible := false
            if IsSet(txtCasinoKortzLabel)
                txtCasinoKortzLabel.Visible := false
            if IsSet(txtCayoLabel)
                txtCayoLabel.Visible := false
            if IsSet(txtHeistInstr)
                txtHeistInstr.Visible := false
            if IsSet(txtEnableScriptsInfo)
                txtEnableScriptsInfo.Visible := true
        }
    }

    SetEngineToggleBtnVisibility(enabled) {
        global picEngineToggle, txtEngineLabel, txtAHKLabel, txtOpenCVLabel, txtEngineInstr

        if enabled {
            if (IsSet(picEngineToggle) && picEngineToggle) {
                picEngineToggle.Visible := true
                picEngineToggle.Opt("BackgroundTrans")
                picEngineToggle.OnEvent("Click", ToggleEngineMode)
            }
            if IsSet(txtEngineLabel)
                txtEngineLabel.Visible := true
            if IsSet(txtAHKLabel)
                txtAHKLabel.Visible := true
            if IsSet(txtOpenCVLabel)
                txtOpenCVLabel.Visible := true
            if IsSet(txtEngineInstr)
                txtEngineInstr.Visible := true
        } else {
            if (IsSet(picEngineToggle) && picEngineToggle) {
                picEngineToggle.Visible := false
                picEngineToggle.OnEvent("Click", ToggleEngineMode, 0)
            }
            if IsSet(txtEngineLabel)
                txtEngineLabel.Visible := false
            if IsSet(txtAHKLabel)
                txtAHKLabel.Visible := false
            if IsSet(txtOpenCVLabel)
                txtOpenCVLabel.Visible := false
            if IsSet(txtEngineInstr)
                txtEngineInstr.Visible := false
        }
    }

}
; ⏐==========================================================================================================⏐
