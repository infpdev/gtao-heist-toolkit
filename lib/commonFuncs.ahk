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

    hwnd := 0
    while (hwnd := DllCall("FindWindowEx", "ptr", 0, "ptr", hwnd, "str", "tooltips_class32", "ptr", 0, "ptr")) {
        exStyle := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
        exStyle |= 0x20 | 0x80000
        DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr", exStyle)
        DllCall("SetLayeredWindowAttributes", "ptr", hwnd, "uint", 0, "uchar", alpha, "uint", 0x2)
    }
}

global cacheFile := A_ScriptDir "\zAnchorCache.ini" ; Global variable for cache file path, used in LoadCache and SaveCache functions

/**
 * @description Loads cached anchor coordinates from anchorCache.ini into global cache variables.
 * Creates the cache file with zero defaults when it does not exist.
 * @returns {boolean} True when load flow completes.
 */
LoadCache() {
    global cachedFingerprintAnchor, cachedKeypadAnchor, cachedRubioAnchor

    ; cacheFile := A_ScriptDir "\zAnchorCache.ini"
    if !FileExist(cacheFile) {
        FileAppend(
            "[fingerprint]`nx=0`ny=0`n`n"
            . "[keypad]`nx=0`ny=0`n`n"
            . "[rubio]`nx=0`ny=0`n",
            cacheFile,
            "UTF-8-RAW"
        )
    }

    cachedFingerprintAnchor := ReadCachedAnchor(cacheFile, "fingerprint")
    cachedKeypadAnchor := ReadCachedAnchor(cacheFile, "keypad")
    cachedRubioAnchor := ReadCachedAnchor(cacheFile, "rubio")
    return true
}

/**
 * @description Persists current cached anchor objects to anchorCache.ini.
 * @returns {boolean} False when required globals are not initialized or cache file is missing; otherwise true.
 */
SaveCache() {
    global cachedFingerprintAnchor, cachedKeypadAnchor, cachedRubioAnchor

    ; cacheFile := A_ScriptDir "\zAnchorCache.ini"
    if !FileExist(cacheFile) || !IsSet(cachedFingerprintAnchor) || !IsSet(cachedKeypadAnchor) || !IsSet(
        cachedRubioAnchor)
        return false

    WriteCachedAnchor(cacheFile, "fingerprint", cachedFingerprintAnchor)
    WriteCachedAnchor(cacheFile, "keypad", cachedKeypadAnchor)
    WriteCachedAnchor(cacheFile, "rubio", cachedRubioAnchor)
    return true
}

/**
 * @description Reads one anchor section from cache and returns either coordinates object or 0 sentinel.
 * @param {string} cacheFile - Full path to cache ini file.
 * @param {string} section - INI section name (fingerprint/keypad/rubio).
 * @returns {object|number} Object {x, y} for valid values, otherwise 0.
 */
ReadCachedAnchor(cacheFile, section) {
    try {
        x := Trim(IniRead(cacheFile, section, "x", 0))
        y := Trim(IniRead(cacheFile, section, "y", 0))
        if (x = "" || y = "")
            return 0

        xVal := Integer(x)
        yVal := Integer(y)
        if (xVal <= 0 || yVal <= 0)
            return 0

        return { x: xVal, y: yVal }
    } catch {
        return 0
    }
}

/**
 * @description Writes one anchor cache entry as x/y values, or zeros when anchor is invalid.
 * @param {string} cacheFile - Full path to cache ini file.
 * @param {string} section - INI section name (fingerprint/keypad/rubio).
 * @param {object|number} anchor - Anchor object with x/y or falsy/0 to reset values.
 * @returns {void}
 */
WriteCachedAnchor(cacheFile, section, anchor) {
    try {
        if (IsObject(anchor) && anchor.HasOwnProp("x") && anchor.HasOwnProp("y") && anchor.x && anchor.y) {
            IniWrite(anchor.x, cacheFile, section, "x")
            IniWrite(anchor.y, cacheFile, section, "y")
        } else {
            IniWrite(0, cacheFile, section, "x")
            IniWrite(0, cacheFile, section, "y")
        }
    } catch {
    }
}
