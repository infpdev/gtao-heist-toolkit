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
    UpdateModeInstrText() {
        global instrMode, txtModeInstr
        hotKeyTextMode := ""
        if IsSet(txtModeInstr)
            txtModeInstr.Text := instrMode hotKeyTextMode
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
        global picHeistToggle, txtHeistLabel, txtCasinoLabel, txtCayoLabel, txtHeistInstr
        if !IsSet(picHeistToggle) || !picHeistToggle
            return
        global txtEnableScriptsInfo

        if enabled {
            picHeistToggle.Visible := true
            picHeistToggle.Opt("BackgroundTrans")
            picHeistToggle.OnEvent("Click", ToggleHeistMode)
            if IsSet(txtHeistLabel)
                txtHeistLabel.Visible := true
            if IsSet(txtCasinoLabel)
                txtCasinoLabel.Visible := true
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
            if IsSet(txtCasinoLabel)
                txtCasinoLabel.Visible := false
            if IsSet(txtCayoLabel)
                txtCayoLabel.Visible := false
            if IsSet(txtHeistInstr)
                txtHeistInstr.Visible := false
            if IsSet(txtEnableScriptsInfo)
                txtEnableScriptsInfo.Visible := true
        }
    }

}
; ⏐==========================================================================================================⏐
