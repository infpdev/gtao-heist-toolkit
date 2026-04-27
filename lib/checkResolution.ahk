if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}
checkResolution() {
    supportedResolutions := [[1366, 768], [1600, 900], [1920, 1080]]
    nearestRes := supportedResolutions[1]
    bestDiff := Abs(A_ScreenWidth - nearestRes[1])
    for _, res in supportedResolutions {
        diff := Abs(A_ScreenWidth - res[1])
        if (diff < bestDiff) {
            bestDiff := diff
            nearestRes := res
        }
    }

    targetW := nearestRes[1]
    targetH := nearestRes[2]

    ; parent folder
    global dir := DirGetParent(A_ScriptDir)
    if (dir = "")
        dir := A_ScriptDir

    ; folder for resolution-specific templates
    global folder := dir "\" targetW "x" targetH "\"

    if (targetW != A_ScreenWidth || targetH != A_ScreenHeight) {
        global unsupportedResolution := true
        MsgBox(
            "Your current resolution is not officially supported.`n`n"
            . "The solvers may not work correctly at this resolution.`n`n"
            . "Using nearest supported templates: " targetW "x" targetH ".`n`n"
            . "NoSave can still be used normally.",
            "Unsupported Resolution",
            "Icon!"
        )
    } else {
        global unsupportedResolution := false
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

HasVaultOpsMarkers(basePath) {
    hasExe := FileExist(basePath "\vaultOps.exe") != ""
    has1920 := InStr(FileExist(basePath "\1920x1080"), "D")
    has1600 := InStr(FileExist(basePath "\1600x900"), "D")
    has1366 := InStr(FileExist(basePath "\1366x768"), "D")
    return hasExe || has1920 || has1600 || has1366
}
