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

; Forces a window to the foreground,
; even if the script is running as admin
ForceForeground(guiApp) {
    if !guiApp.Hwnd
        return false

    try DllCall("ShowWindow", "ptr", guiApp.Hwnd, "int", 9) ; SW_RESTORE
    try DllCall("BringWindowToTop", "ptr", guiApp.Hwnd)
    try WinActivate("ahk_id " guiApp.Hwnd)
    try DllCall("SetForegroundWindow", "ptr", guiApp.Hwnd)

    guiApp.Opt("-Caption")
    return WinActive("ahk_id " guiApp.Hwnd)
}

; Center the gui since it's captionless
CenterGui(guiApp, width, height, scale := 1, yOffset := 0) {
    s := (IsNumber(scale) && scale > 0) ? scale : 1

    screenW := SysGet(78) / s
    screenH := SysGet(79) / s

    x := Round((screenW - width) / 2)
    y := Round((screenH - height) / 2 + yOffset)

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
