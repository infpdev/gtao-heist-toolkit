#Requires AutoHotkey v2.0

; Gets the screen scaling factor
; (e.g. 1.25 for 125% scaling) to allow for
; proper positioning of GUI elements on screens
; with different DPI settings. (Unused)
GetScreenScaling() {
    hDC := DllCall("GetDC", "ptr", 0, "ptr")
    dpi := DllCall("GetDeviceCaps", "ptr", hDC, "int", 88) ; LOGPIXELSX
    DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)
    percent := Round(dpi / 96 * 100) ; 96 DPI = 100%
    return percent / 100
}

; Returns the Hwnd of a control, or 0 if it's missing / not a control.
; Some GUI controls are optional per mode (e.g. the engine toggle is skipped
; when running in higherRes / OpenCV-only mode), so hover logic must never
; assume they exist.
SafeCtrlHwnd(ctrl) {
    return IsObject(ctrl) && ctrl.HasProp("Hwnd") ? ctrl.Hwnd : 0
}

; Forces a window to the foreground,
; even if the script is running as admin
ForceForeground(guiApp) {
    if !guiApp.Hwnd
        return false

    try DllCall("ShowWindow", "ptr", guiApp.Hwnd, "int", 9) ; SW_RESTORE
    try DllCall("BringWindowToTop", "ptr", guiApp.Hwnd)
    try WinActivate("ahk_id " guiApp.Hwnd)
    try DllCall("SetForegroundWindow", "ptr", guiApp.Hwnd)

    try bar.Focus()

    return WinActive("ahk_id " guiApp.Hwnd)
}

; Center the gui since it's captionless
CenterGui(guiApp, width, height, scale := 1, yOffset := 0) {

    x := Round((A_ScreenWidth - width) / 2)
    y := Round((A_ScreenHeight - height) / 2 + yOffset)

    guiApp.Move(x, y, width, height)
}

GuiApp_OnActivate(wParam, *) {
    global bar

    if !wParam
        return

    try bar.Focus()
    SetTimer(FocusGuiBar, -10)
}

FocusGuiBar(*) {
    global bar

    try bar.Focus()
}

; Used to bypass unfocus of edit fields when the mouse clicks on input fields
GuiCtrlFromPoint(gui, x, y) {
    for ctrl in gui {
        if !ctrl.Visible
            continue
        cX := cY := cW := cH := 0
        try ctrl.GetPos(&cX, &cY, &cW, &cH)
        if (x >= cX && x < cX + cW && y >= cY && y < cY + cH)
            return ctrl
    }
    return 0
}

; Used to set rounded corners on a GUI, requires DllCalls
SetRoundedCorners(hwnd, w, h, r) {
    hRgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", r, "int", r, "ptr"
    )
    DllCall("SetWindowRgn", "ptr", hwnd, "ptr", hRgn, "int", true)
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    static errorShown := false
    static hCursorHand := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr")
    static hCursorDrag := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32646, "Ptr")
    static hCursorArrow := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr")
    static hCursorIBeam := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32513, "Ptr")

    global picFingerprintToggle, picScriptsEnabled, picNoSave, picLedgeGrabEnabled, picHeistToggle, picEngineToggle,
        picRichPresenceEnabled
    global inputManual, inputAuto, inputReset, inputDelay, inputNoSave,
        inputToggleScripts, inputLedgeGrabAutomation

    mouseOverHwnd := wParam

    try {
        switch mouseOverHwnd {
            case SafeCtrlHwnd(killBtn):
                ToolTip("Kill GTA V", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(xBtn):
                ToolTip("Terminate", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(dragBtn):
                ToolTip("Click to Center App`nHold to Drag App", , , 19)
                DllCall("SetCursor", "Ptr", hCursorDrag)
                return True

            case SafeCtrlHwnd(mnmzBtn):
                ToolTip("Minimize", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(picRichPresenceEnabled):
                ToolTip((richPresenceEnabled ? "Disable" : "Enable") " Discord Rich Presence", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True

            case SafeCtrlHwnd(picFingerprintToggle),
            SafeCtrlHwnd(picScriptsEnabled),
            SafeCtrlHwnd(picNoSave),
            SafeCtrlHwnd(picLedgeGrabEnabled),
            SafeCtrlHwnd(picHeistToggle),
            SafeCtrlHwnd(picEngineToggle):
                ToolTip("", , , 19)
                DllCall("SetCursor", "Ptr", hCursorHand)
                return True
            case SafeCtrlHwnd(inputManual),
            SafeCtrlHwnd(inputAuto),
            SafeCtrlHwnd(inputReset),
            SafeCtrlHwnd(inputDelay),
            SafeCtrlHwnd(inputNoSave),
            SafeCtrlHwnd(inputToggleScripts),
            SafeCtrlHwnd(inputLedgeGrabAutomation):
                ToolTip("", , , 19)
                DllCall("SetCursor", "Ptr", hCursorIBeam)
                return True
            default:
                ToolTip("", , , 19)
                DllCall("SetCursor", "Ptr", hCursorArrow)
                return False
        }
    } catch as e {
        if !errorShown {
            errorShown := true
            MsgBox("Error in OnSetCursor: " e.Message)
        }
    }
}

StartDrag(*) {
    holdStart := A_TickCount

    while (A_TickCount - holdStart < 200) {
        if !GetKeyState("LButton", "P") {
            CenterGui(guiApp, width, height)
            ToolTip("", , , 19)
            return
        }
        Sleep 10
    }

    ; 200 ms elapsed
    if GetKeyState("LButton", "P")
        PostMessage(0xA1, 2, , , guiApp.Hwnd)
}
