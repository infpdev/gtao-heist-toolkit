; =============================================================================
; ShowMiscSettings - Displays a secondary GUI for miscellaneous options
; =============================================================================
ShowMiscSettings(*) {
    global iniFile, staticFolder, scale, width, height, borderRadius, guiApp, noSaveTooltip, toolTipYOffset, toolTipPos
    static miscGuiPtr := 0

    global miscSettingsOpened := true

    if (miscGuiPtr && IsObject(miscGui)) {
        DisplayMiscGui(miscGui, width, height)
        return
    }

    global xBtnMisc := 0, btnReturnToVaultOps := 0, changesMadeInMiscSettings := false
    global topLeft := 0, topRight := 0, midLeft := 0, midRight := 0, bottomLeft := 0, bottomRight := 0
    global arrowUp := 0, arrowDown := 0, offsetYValue := 0
    global noSaveTooltipToggle := 0, debugToggle := 0

    ; ======== GUI dimensions and scaling ========
    dpiScale := 1.0
    guiW := width / dpiScale
    guiH := height / dpiScale
    margin := 20 / dpiScale
    overallFontSize := GetScaledFontSize(11)

    ; ======== Create the GUI ========
    global miscGui := Gui("-Caption -DPIScale +Owner" guiApp.Hwnd, "zSettings Editor")
    miscGuiPtr := miscGui
    miscGui.BackColor := "222222"
    miscGui.SetFont("s" overallFontSize " cWhite", "Yu Gothic UI")

    ; ======== Title bar ========
    titleBarH := 30 / scale
    btnW := 22 / scale
    titleW := guiW - btnW * 2 - margin * 2
    miscGui.AddText("xm y0 w" titleW " h" titleBarH " c648f64 Background222222 Left 0x200",
        "zSettings Editor")

    ; Close button
    xBtnMisc := miscGui.AddPicture("x" (guiW - btnW - 10) " y" 7 " w" btnW " h" btnW " +0x4",
    staticFolder "\exit.png")
    xBtnMisc.OnEvent("Click", DestroyMiscSettings)

    ; ======== Group box ========
    numSettings := 3
    returnBtnW := 332 / scale
    returnBtnH := 67 / scale

    rowH := (height - returnBtnH) / (numSettings + 1) - margin * 2

    groupX := margin
    groupY := titleBarH
    groupW := guiW - margin * 2
    gridScale := 2.0
    global gridWindowHeight := 45
    global gridWindowGap := 5
    gridHeight := (gridWindowHeight * 3 + gridWindowGap * 2 - gridWindowHeight / gridScale) / gridScale
    groupH := gridHeight + numSettings * rowH + 40 + margin * 2

    miscGui.AddGroupBox("x" groupX " y" groupY " w" groupW " h" groupH,
        "zSettings Options")

    ; ⏐===================================================================================⏐
    ; ⏐============================ Setting 1: Tooltip Corner ============================⏐
    ; ⏐===================================================================================⏐
    iniKey := "ToolTipPos"
    instrTooltipCorner := "Choose the corner of the screen for the main VaultOps tooltip."

    rowY := groupY + 25 + margin / 2
    labelW := 200 / scale
    labelX := groupX + 15 / scale
    btnX := labelX + labelW + 20
    instrX := btnX + 150 / scale
    instrW := (groupX + groupW - 10 / scale) - instrX

    ; Corner Label - centered vertically to grid
    y := rowY + (gridHeight / 2) - (overallFontSize / 2)
    miscGui.AddText("x" labelX " y" y " w" labelW " cWhite",
        "VaultOps Tooltip Corner")

    ; Corner instruction text
    miscGui.AddText("x" instrX " y" y " w" instrW " cA9A9A9 BackgroundTrans",
        instrTooltipCorner)

    toolTipGrid(btnX, rowY, gridScale, staticFolder)

    ; ⏐===================================================================================⏐
    ; ⏐======================== Setting 2: Tooltip Vertical Offset =======================⏐
    ; ⏐===================================================================================⏐
    instrTooltipYOffset := "Adjust the vertical offset (in pixels) of the tooltips from the selected corner."

    y += rowH + (rowH / 2) - (overallFontSize / 2)

    ; Tooltip offset Label
    miscGui.AddText("x" labelX " y" y " w" labelW " cWhite", "Tooltip Vertical Offset :")

    offsetYValue := miscGui.AddText("x" (labelW - 5) " y" y " w" 50 " cWhite", "")
    offsetYValue.SetFont("s" overallFontSize + 3 " cA9A9A9 bold", "Arial")

    updateOffsetYLabel()

    ; Arrow buttons (up/down)
    arrowSize := 25 / scale
    arrowX := btnX + 17
    arrowY := y - (arrowSize / 2) + (overallFontSize / 2)

    ; Up arrow
    arrowUp := miscGui.AddPicture(
        "x" arrowX " y" arrowY " w" arrowSize " h" arrowSize " +0x4",
        staticFolder "\arr_up.png"
    )
    arrowUp.OnEvent("Click", (*) => AdjustTooltipYOffset(-5))

    ; Down arrow (inverted)
    arrowDown := miscGui.AddPicture(
        "x" (arrowX + arrowSize + 5 / scale) " y" arrowY " w" arrowSize " h" arrowSize " +0x4",
        staticFolder "\arr_down.png"
    )
    arrowDown.OnEvent("Click", (*) => AdjustTooltipYOffset(5))

    ; Tooltip offset instruction text
    miscGui.AddText("x" instrX " y" y " w" instrW " cA9A9A9 BackgroundTrans",
        instrTooltipYOffset)

    ; ⏐===================================================================================⏐
    ; ⏐======================== Setting 3: Custom NoSave Tooltip =========================⏐
    ; ⏐===================================================================================⏐
    instrNoSaveTooltip := "Shows an always-on-top tooltip while NoSave is enabled."

    y += rowH - (overallFontSize / 2)

    ; NoSave tooltip Label
    miscGui.AddText("x" labelX " y" y " w" labelW " cWhite", "Show NoSave Tooltip")
    noSaveTooltipToggle := miscGui.AddPicture("x" btnX + 30 " y" y - 5 " w" 30 " h" 30 " +0x4",
        noSaveTooltip ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png")

    noSaveTooltipToggle.OnEvent("Click", ToggleNosaveTooltip)

    miscGui.AddText("x" instrX " y" y " w" instrW " cA9A9A9 BackgroundTrans",
        instrNoSaveTooltip)

    ; ⏐===================================================================================⏐
    ; ⏐============================ Setting 4: Debug Toggle ==============================⏐
    ; ⏐===================================================================================⏐
    instrDebugToggle := "Enable or disable debug mode. (Can also be toggled using ALT + F10.)"

    y += rowH - (overallFontSize / 2)

    ; Debug toggle Label
    miscGui.AddText("x" labelX " y" y " w" labelW " cWhite", "Debug Mode")
    debugToggle := miscGui.AddPicture("x" btnX + 30 " y" y - 5 " w" 30 " h" 30 " +0x4",
        debug ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png")

    debugToggle.OnEvent("Click", ToggleDebugMode)

    ToggleDebugMode(*) {
        nextDebugValue := !debug
        debugToggle.Value := nextDebugValue ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
        ToggleDebugChord()
    }

    miscGui.AddText("x" instrX " y" y " w" instrW " cA9A9A9 BackgroundTrans",
        instrDebugToggle)

    ; ⏐===================================================================================⏐
    ; ⏐=============================== Return to VaultOps ================================⏐
    ; ⏐===================================================================================⏐
    btnY := height - margin * 1.5 - returnBtnH
    btnX := (guiW - returnBtnW) / 2

    btnReturnToVaultOps := miscGui.AddPicture(
        "x" btnX " y" btnY " w" returnBtnW " h" returnBtnH " +0x4",
        staticFolder "\exitMisc.png"
    )

    btnReturnToVaultOps.OnEvent("Click", DestroyMiscSettings)

    DestroyMiscSettings(*) {
        global miscSettingsOpened, xBtnMisc, miscGui
        miscSettingsOpened := false
        miscGui.Hide()
        if (changesMadeInMiscSettings)
            try PersistSettingsToAppData()

    }

    ; ======== Show ========
    DisplayMiscGui(miscGui, guiW, guiH)
    makeGridCornerSemiTrans(corners[toolTipPos])
    SetRoundedCorners(miscGui.Hwnd, guiW, guiH, borderRadius)
}

DisplayMiscGui(miscGui, guiW, guiH) {
    global guiApp

    guiApp.GetPos(&x, &y, &vaultW, &vaultH)

    miscX := Round(x + (vaultW - guiW) / 2)
    miscY := Round(y + (vaultH - guiH) / 2)

    miscGui.Show("x" miscX " y" miscY " w" Round(guiW) " h" Round(guiH))
}

; Create a grid of clickable corner options for the tooltip position
toolTipGrid(StartX, startY, gridScale, staticFolder) {
    global topLeft, topRight, midLeft, midRight, bottomLeft, bottomRight

    ; ToolTip position: 1=Top Left, 2=Middle Left, 3=Bottom Left, 4=Top Right, 5=Middle Right, 6=Bottom Right

    imgW := 80 / gridScale
    imgH := gridWindowHeight / gridScale
    midH := imgH / gridScale
    gap := gridWindowGap
    window := staticFolder "\window.png"

    topY := startY
    ; Top left
    topLeft := miscGui.AddPicture(
        "x" StartX " y" topY " w" imgW " h" imgH " +0x100",
        window
    )
    topLeft.OnEvent("Click", (*) => ChangeCorner(1))

    ; Top right
    topRight := miscGui.AddPicture(
        "x" (StartX + imgW + gap) " y" topY " w" imgW " h" imgH " +0x100",
        window
    )
    topRight.OnEvent("Click", (*) => ChangeCorner(4))

    ; Mid left
    midY := topY + imgH + gap
    midLeft := miscGui.AddPicture(
        "x" StartX " y" midY " w" imgW " h" midH " +0x100",
        window
    )
    midLeft.OnEvent("Click", (*) => ChangeCorner(2))

    ; Mid right
    midRight := miscGui.AddPicture(
        "x" (StartX + imgW + gap) " y" midY " w" imgW " h" midH " +0x100",
        window
    )
    midRight.OnEvent("Click", (*) => ChangeCorner(5))

    ; bottom left
    bottomY := midY + midH + gap
    bottomLeft := miscGui.AddPicture(
        "x" StartX " y" bottomY " w" imgW " h" imgH " +0x100",
        window
    )
    bottomLeft.OnEvent("Click", (*) => ChangeCorner(3))

    ; bottom right
    bottomRight := miscGui.AddPicture(
        "x" (StartX + imgW + gap) " y" bottomY " w" imgW " h" imgH " +0x100",
        window
    )
    bottomRight.OnEvent("Click", (*) => ChangeCorner(6))

    global corners := Map(
        1, topLeft,
        2, midLeft,
        3, bottomLeft,
        4, topRight,
        5, midRight,
        6, bottomRight
    )
}

; ToggleMiscSetting - Toggles a checkbox picture and updates its state
ToggleMiscSetting(pic, *) {
    global staticFolder
    pic.State := !pic.State
    pic.Value := pic.State ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"
}

; SaveMiscSetting - Saves a single misc setting to the INI file
SaveMiscSetting(pic, iniFile) {
    ; IniWrite(pic.State, iniFile, "Options", pic.IniKey)
}

IsCurrentCorner(corner) {
    global toolTipPos
    return (corner = toolTipPos)
}

; ⏐============================ 1: Tooltip Corner Func ============================⏐

; Changes
ChangeCorner(corner) {
    static prevClickedCorner := 0
    global toolTipPos, iniFile, hackInProgress, toolTipPos, corners
    global changesMadeInMiscSettings := true

    if (!prevClickedCorner)
        prevClickedCorner := toolTipPos

    clickedCorner := corner

    if (corner = toolTipPos)
        return

    if (prevClickedCorner != clickedCorner && prevClickedCorner != 0)
        WinSetTransparent(255, corners[prevClickedCorner])

    makeGridCornerSemiTrans(corners[clickedCorner])
    prevClickedCorner := clickedCorner

    toolTipPos := corner
    IniWrite(corner, iniFile, "Options", "ToolTipPos")
    UpdateGlobalStatus(hackInProgress, , , , true)
}

; ⏐============================ 2: Tooltip Vertical Offset Func ============================⏐

; Adjusts the vertical offset of the tooltip and updates the INI file
AdjustTooltipYOffset(offset) {
    global changesMadeInMiscSettings := true

    if (alreadyAtLimits(offset))
        return

    if (GetKeyState("LButton", "P")) {
        while (GetKeyState("LButton", "P")) {
            Sleep 100
            SetTooltipYOffset(offset)
            if (alreadyAtLimits(offset))
                break
        }
    } else
        SetTooltipYOffset(offset)

    IniWrite(toolTipYOffset, iniFile, "Options", "ToolTipYOffset")

}

; ⏐============================ 3: Custom NoSave Tooltip Func ============================⏐

; Toggle the NoSave tooltip setting and update the INI file
ToggleNosaveTooltip(*) {
    global changesMadeInMiscSettings := true
    global noSaveTooltip, noSave, noSaveTooltipToggle, staticFolder, iniFile

    noSaveTooltip := !noSaveTooltip

    noSaveTooltipToggle.Value := noSaveTooltip ? staticFolder "\checkboxFilled.png" : staticFolder "\checkboxEmpty.png"

    ShowNoSaveTooltip(noSave, true)
    IniWrite(noSaveTooltip, iniFile, "Options", "NoSaveTooltip")
}

; ⏐======================================================================⏐
; ⏐============================ Helper Funcs ============================⏐
; ⏐======================================================================⏐

; SetTooltipYOffset - Adjusts the vertical offset of the tooltip and updates the INI file
SetTooltipYOffset(offset) {
    global iniFile, hackInProgress, toolTipYOffset, toolTipPos

    toolTipYOffset += offset

    ; Clamp the offset so it doesn't go beyond the screen bounds
    ; ToolTip position: 1=Top Left, 2=Middle Left, 3=Bottom Left, 4=Top Right, 5=Middle Right, 6=Bottom Right
    if (toolTipPos != 2 && toolTipPos != 5) {
        if (toolTipPos = 1 || toolTipPos = 4)
            toolTipYOffset := Max(0, Min(100, toolTipYOffset))
        else if (toolTipPos = 3 || toolTipPos = 6)
            toolTipYOffset := Max(-200, Min(0, toolTipYOffset))
        else
            toolTipYOffset := Max(-100, Min(100, toolTipYOffset))
    }

    updateOffsetYLabel()

    UpdateGlobalStatus(hackInProgress, , , , true)
}

; Makes a grid's corner pic semi-transparent
makeGridCornerSemiTrans(cornerPic) {
    WinSetTransparent(180, cornerPic)
}

; Update the offsetYValue label to reflect the current tooltip Y offset
updateOffsetYLabel(*) {
    global offsetYValue, toolTipYOffset
    offsetYValue.Text := toolTipYOffset
}

; Checks if the tooltip offset is already at its limits for the given corner position
alreadyAtLimits(offset) {
    global toolTipPos, toolTipYOffset

    if (toolTipPos = 1 || toolTipPos = 4)
        return (offset > 0 && toolTipYOffset >= 100)
        || (offset < 0 && toolTipYOffset <= 0)
    else if (toolTipPos = 2 || toolTipPos = 5)
        return (offset > 0 && toolTipYOffset >= 100)
        || (offset < 0 && toolTipYOffset <= -100)
    else if (toolTipPos = 3 || toolTipPos = 6)
        return (offset > 0 && toolTipYOffset >= A_ScreenHeight)
        || (offset < 0 && toolTipYOffset <= -200)

    return false
}

OnSetCursorMiscSettings(mouseOverHwnd) {
    static errorShown := false

    global xBtnMisc, btnReturnToVaultOps
    global topLeft, topRight, midLeft, midRight, bottomLeft, bottomRight
    global arrowUp, arrowDown, noSaveTooltipToggle, debugToggle

    try {
        switch mouseOverHwnd {

            case SafeCtrlHwnd(xBtnMisc), SafeCtrlHwnd(btnReturnToVaultOps):
                ToolTip("Return to VaultOps", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

                ; ToolTip position: 1=Top Left, 2=Middle Left, 3=Bottom Left, 4=Top Right, 5=Middle Right, 6=Bottom Right
            case SafeCtrlHwnd(topLeft):
                ToolTip(IsCurrentCorner(1) ? "Current Corner" : "Top Left", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(topRight):
                ToolTip(IsCurrentCorner(4) ? "Current Corner" : "Top Right", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(midLeft):
                ToolTip(IsCurrentCorner(2) ? "Current Corner" : "Center Left", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(midRight):
                ToolTip(IsCurrentCorner(5) ? "Current Corner" : "Center Right", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(bottomLeft):
                ToolTip(IsCurrentCorner(3) ? "Current Corner" : "Bottom Left", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(bottomRight):
                ToolTip(IsCurrentCorner(6) ? "Current Corner" : "Bottom Right", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(arrowUp):
                ToolTip("Move Tooltip Up", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(arrowDown):
                ToolTip("Move Tooltip Down", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(noSaveTooltipToggle):
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(debugToggle):
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            default:
                ToolTip("", , , 19)
                DllCall("SetCursor", "Ptr", hCursorArrow)
                return False
        }
    } catch as e {
        if (InStr(e.Message, "destroyed")) {
            global miscSettingsOpened := false
            ToolTip("", , , 19)
            DllCall("SetCursor", "Ptr", hCursorArrow)
            return False
        }

        if !errorShown {
            errorShown := true
            MsgBox("Error in OnSetCursorMiscSettings: " e.Message)
        }
    }
}
