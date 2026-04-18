/**
 * @description Calculate text width and show tooltip centered on screen or at specified Y coordinate
 * @param {string} text - The tooltip text to display
 * @param {number} [id=10] - Tooltip ID for managing multiple tooltips (must be 1-20)
 * @param {number} [y=0] - Y coordinate (0 = top of screen, custom value = center at that Y)
 * @returns {void}
 * @example
 * ShowCenteredToolTip("Build complete!", 1, 20)
 */
ShowCenteredToolTip(text, id := 10, y := 0) {
    ; Measure text width to center tooltip
    hdc := DllCall("GetDC", "ptr", 0)

    ; Create font (adjust if needed)
    hfont := DllCall("GetStockObject", "int", 0)  ; DEFAULT_GUI_FONT
    DllCall("SelectObject", "ptr", hdc, "ptr", hfont)

    ; Measure text using Buffer (AHK v2.0)
    size := Buffer(8)
    DllCall("GetTextExtentPoint32", "ptr", hdc, "str", text, "int", StrLen(text), "ptr", size)
    width := NumGet(size, 0, "int")

    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

    ; Center horizontally, position Y at parameter or top
    centerX := (A_ScreenWidth // 2) - (width // 2)
    centerY := y > 0 ? y : 0

    ToolTip(text, centerX, centerY, id)
}

; Makes all ToolTips click-through to avoid interfering with user interaction, especially when status is displayed
/**
 * @description Make all tooltip windows click-through (transparent to mouse) and optionally adjusts opacity
 * @param {boolean} isIdle - If true, reduces opacity to 180 for idle state; otherwise uses provided opacity
 * @param {number} [opacity=230] - Opacity value (0-255), clamped automatically
 * @returns {void}
 * @note Applied globally to all tooltips_class32 windows owned by the process
 * @example
 * MakeAllToolTipsClickThrough(false, 200)  ; Make tooltips click-through at 200 opacity
 */
MakeAllToolTipsClickThrough(isIdle, opacity := 230) {
    alpha := Integer(opacity) ? opacity : 255
    alpha := Max(0, Min(255, alpha))

    if (isIdle)
        alpha := 180

    ; Apply style/opacity to every tooltip window currently owned by the process.
    hwnd := 0
    while (hwnd := DllCall("FindWindowEx", "ptr", 0, "ptr", hwnd, "str", "tooltips_class32", "ptr", 0, "ptr")) {
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        exStyle |= 0x20 | 0x80000 ; WS_EX_TRANSPARENT | WS_EX_LAYERED
        DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr", exStyle)
        DllCall("SetLayeredWindowAttributes", "ptr", hwnd, "uint", 0, "uchar", alpha, "uint", 0x2) ; LWA_ALPHA
        ; DllCall("SetWindowPos", "ptr", hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13) ; broken
    }
}

; Converts an AHK hotkey string (e.g. "^+a") to a more user-friendly display format (e.g. "Ctrl+Shift+A")
/**
 * @description Convert AutoHotkey hotkey notation to human-readable display format
 * @param {string} ahkValue - AHK hotkey string (e.g. "^+a", "!LMB", "#+e")
 * @returns {string} Display-friendly hotkey (e.g. "Ctrl+Shift+A")
 * @note Modifiers: ^ = Ctrl, + = Shift, ! = Alt. Returns empty string for invalid input.
 * @example
 * display := AHKToDisplayHotkey("^+a")  ; Returns "Ctrl+Shift+A"
 * display := AHKToDisplayHotkey("!LMB") ; Returns "Alt+LMB"
 */
AHKToDisplayHotkey(ahkValue) {
    value := Trim(ahkValue)
    if (value = "")
        return ""

    mods := ""
    idx := 1
    while (idx <= StrLen(value)) {
        ch := SubStr(value, idx, 1)
        if (ch = "^") {
            mods .= "Ctrl+"
            idx++
            continue
        }
        if (ch = "+") {
            mods .= "Shift+"
            idx++
            continue
        }
        if (ch = "!") {
            mods .= "Alt+"
            idx++
            continue
        }
        break
    }
    return mods SubStr(value, idx)
}
