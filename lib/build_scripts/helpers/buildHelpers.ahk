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

    ToolTip(text, centerX, centerY, id)
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

HasVaultOpsMarkers(basePath) {
    hasExe := FileExist(basePath "\vaultOps.exe") != ""
    has1920 := InStr(FileExist(basePath "\1920x1080"), "D")
    has1600 := InStr(FileExist(basePath "\1600x900"), "D")
    has1366 := InStr(FileExist(basePath "\1366x768"), "D")
    return hasExe || has1920 || has1600 || has1366
}
