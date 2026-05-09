if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}

if (!IsSet(OPENCV_ENGINE))
    global OPENCV_ENGINE := 1

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

    ; Check if exact match
    isExactMatch := false
    for _, res in supportedResolutions {
        if (A_ScreenWidth = res[1] && A_ScreenHeight = res[2]) {
            isExactMatch := true
            break
        }
    }

    if (isExactMatch) {
        global unsupportedResolution := false
        global higherRes := false
        return
    }

    ; Check aspect ratio (16:9 ≈ 1.777...)
    aspectRatio := A_ScreenWidth / A_ScreenHeight
    is16to9 := (aspectRatio > 1.75 && aspectRatio < 1.80)

    if (is16to9 && A_ScreenWidth > 1920) {
        ; Higher resolution 16:9 screen - use fallback to nearest supported
        global unsupportedResolution := false
        global higherRes := true
        global engine := OPENCV_ENGINE
        return
    }

    ; Not exact match, not 16:9 and higher - unsupported
    global unsupportedResolution := true
    global higherRes := false

    iniFile := dir "\zSettings.ini"
    if (FileExist(iniFile)) {
        disableWarningFlag := IniRead(iniFile, "Options", "DisableResolutionWarning", "0")
        if (disableWarningFlag = "1") {
            return
        }
    }
    res := ShowResolutionWarning(targetW, targetH, iniFile)
    if (res = "Yes") {
        Run("https://github.com/infpdev/gtao-heist-toolkit#standalone-solvers")
        ExitApp
    } else
        return
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

ShowResolutionWarning(targetW, targetH, iniFile) {
    warningGui := Gui("-DPIScale")
    warningGui.SetFont("s10")
    warningGui.Title := "Unsupported Resolution"

    warningGui.AddText(, "Your current resolution is not officially supported.`n`n"
        . "The solvers may not work correctly at this resolution.`n`n"
        . "If you still wish to use the solvers:`n"
        . "• Switch to a supported resolution`n"
        . "• Set the game to Borderless Fullscreen`n"
        . "• Use the toolkit normally`n`n"
        . "For now, using nearest supported templates: " targetW "x" targetH ".`n`n"
        . "NoSave can still be used normally.`n`n"
        . "You may also prefer using the NoSave Standalone script if you do not plan to use the solvers.`n`n"
        . "Do you want to open the download page for the NoSave Standalone script instead?`n")

    chkDontShow := warningGui.AddCheckbox("-TabStop", "Do not show this again")
    doNotShowWarning := 0, buttonResult := "No" ; Default to "No"
    chkDontShow.OnEvent("Click", (*) => (
        doNotShowWarning := chkDontShow.Value ? 1 : 0
    ))

    warningGui.AddButton("x200 w80", "Yes").OnEvent("Click", (*) => (
        buttonResult := "Yes",
        warningGui.Destroy()
    ))
    warningGui.AddButton("x290 yp w80 Default", "No").OnEvent("Click", (*) => (
        buttonResult := "No",
        warningGui.Destroy()
    ))

    warningGui.Show("W600 Center")

    WinWaitClose("ahk_id " warningGui.Hwnd)

    if (doNotShowWarning) {
        disableWarning(iniFile)
    }

    return buttonResult
}

disableWarning(iniFile) {
    if (FileExist(iniFile))
        IniWrite(1, iniFile, "Options", "DisableResolutionWarning")
}
