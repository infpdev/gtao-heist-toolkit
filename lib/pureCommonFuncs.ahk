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
    centerX := (A_ScreenWidth // 2) - 0.9 * (width // 2)  ; Adjust for slight visual centering
    centerY := y > 0 ? y : 0

    CustomTooltip(text, centerX, centerY, id)
}

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

global GTA_ENHANCED_EXE := "ahk_exe GTA5_Enhanced.exe"
global GTA_LEGACY_EXE := "ahk_exe GTA5.exe"

getGtaHwnd() {
    static gtaMatchers := [
        GTA_ENHANCED_EXE,
        "ahk_exe GTA5_Enhanced",
        GTA_LEGACY_EXE,
    ]

    for matcher in gtaMatchers {
        hwnd := WinExist(matcher)
        if hwnd {
            return hwnd
        }
    }

    return 0
}

; Focuses the GTA window if it is running.
FocusGtaIfRunning() {
    if (hwnd := getGtaHwnd()) {
        try {
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 2
        }
    }
}

/**
 * @description Converts canonical hotkey to readable UI label
 * @param {string} canonical - Canonical hotkey format
 * @returns {string} Display-friendly format (e.g., "Ctrl+Shift+A")
 */
CanonicalToDisplay(canonical) {
    canonical := Trim(canonical)
    if (canonical = "")
        return ""

    mods := ""
    idx := 1
    while (idx <= StrLen(canonical)) {
        ch := SubStr(canonical, idx, 1)
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

    keyPart := SubStr(canonical, idx)
    if (keyPart = "")
        return mods != "" ? SubStr(mods, 1, -1) : ""

    if RegExMatch(keyPart, "^vk([0-9A-Fa-f]{2})sc[0-9A-Fa-f]{3}", &match) {
        vkStr := "vk" match[1]
        keyName := StrTitle(GetKeyName(vkStr))
        if (keyName != "")
            return mods keyName
    }

    keyPart := StrTitle(keyPart)
    if RegExMatch(keyPart, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$"
    ) {
        return mods keyPart
    }

    return mods keyPart
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

DirGetParent(path) {
    currentPath := path
    loop 10 {
        SplitPath currentPath, , &parentPath

        ; Find the app root by known markers.
        if (HasVaultOpsMarkers(currentPath)) {
            return currentPath
        }

        if (!parentPath || parentPath = currentPath) {
            SplitPath path, , &parent1
            SplitPath parent1, , &parent2
            return parent2 ? parent2 : path
        }
        currentPath := parentPath
    }
    SplitPath path, , &parent1
    SplitPath parent1, , &parent2
    return parent2 ? parent2 : path
}

; Checks if the given base path contains any of the known VaultOps markers (executable or resolution folders).
; Returns true if any marker is found, false otherwise.
HasVaultOpsMarkers(basePath) {
    hasExe := FileExist(basePath "\vaultOps.exe") != ""
    has1920 := InStr(FileExist(basePath "\1920x1080"), "D")
    has1600 := InStr(FileExist(basePath "\1600x900"), "D")
    has1366 := InStr(FileExist(basePath "\1366x768"), "D")
    return hasExe || has1920 || has1600 || has1366
}

CustomTooltip(text := '', x := 0, y := 0, id := 1) {
    global toolTipPos, tooltipYOffset, toolTipPos
    if (text = '') {
        if (id != 1)
            ToolTip("", x, y, id)
        else
            ToolTip()
        return
    }

    if (IsSet(tooltipYOffset)) {
        y += tooltipYOffset
    }

    if (IsSet(toolTipPos)) {
        if (toolTipPos == 2 || toolTipPos == 5)
            y -= 50
    }

    ToolTip(text, x, y, id)
}

getToolTipPos(pos) {
    x := 0
    y := 0
    switch pos {
        case 1:
            x := 0
            y := 0
        case 2:
            x := 0
            y := A_ScreenHeight // 2
        case 3:
            x := 0
            y := A_ScreenHeight
        case 4:
            x := A_ScreenWidth
            y := 0
        case 5:
            x := A_ScreenWidth
            y := A_ScreenHeight // 2
        case 6:
            x := A_ScreenWidth
            y := A_ScreenHeight
    }
    return { x: x, y: y }
}

FocusOrOpenFolder(folderPath) {
    folderPath := RTrim(folderPath, "\")

    shell := ComObject("Shell.Application")

    for window in shell.Windows {
        try {
            if (window.Document.Folder.Self.Path = folderPath) {
                hwnd := window.HWND

                if WinExist("ahk_id " hwnd) {
                    WinActivate
                    return true
                }
            }
        }
    }

    ; Not already open
    Run('explorer.exe "' folderPath '"')
    return false
}
