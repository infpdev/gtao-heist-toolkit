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

global unsupportedResolution := false
global higherRes := false
global wideScreen := false

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

iniFile := dir "\zSettings.ini"
if (FileExist(iniFile)) {
    global disableWarningFlag := IniRead(iniFile, "Options", "DisableResolutionWarning", "0")
}

checkResolution() {
    global unsupportedResolution, higherRes, wideScreen, targetW, targetH, iniFile, engine

    ; Check if exact match
    isExactMatch := false
    for _, res in supportedResolutions {
        if (A_ScreenWidth = res[1] && A_ScreenHeight = res[2]) {
            isExactMatch := true
            break
        }
    }

    if (isExactMatch) {
        unsupportedResolution := false
        higherRes := false
        return
    }

    ; Check aspect ratio (16:9 ≈ 1.777...)
    aspectRatio := A_ScreenWidth / A_ScreenHeight
    is16to9 := (aspectRatio > 1.75 && aspectRatio < 1.80)
    ; Check for ultrawide 21:9 aspect ratio (~2.333...)
    is21to9 := (aspectRatio > 2.05 && aspectRatio < 2.4)

    wideScreen := is21to9

    if ((is16to9 || is21to9) && (A_ScreenWidth > 1920 || wideScreen)) {
        ; Higher resolution 16:9 screen - use fallback to nearest supported
        unsupportedResolution := false
        higherRes := true
        engine := OPENCV_ENGINE
        if (wideScreen)
            ShowResolutionWarning(targetW, targetH, iniFile, true)
        return
    }

    ; Not exact match, not 16:9 and higher - unsupported
    if (!is16to9 && !is21to9) {
        unsupportedResolution := true
        higherRes := false
    }

    ShowResolutionWarning(targetW, targetH, iniFile)
    return
}

ShowResolutionWarning(targetW, targetH, iniFile, wideScreen := false) {
    global disableWarningFlag

    if (disableWarningFlag = "1")
        return

    warningGui := Gui("-DPIScale")
    warningGui.SetFont("s10")
    warningGui.Title := "Unsupported Resolution"

    if (wideScreen) {
        warningText :=
            "⚠️ Ultrawide (21:9) support is experimental.`nIf you encounter any issues, please report them on GitHub.`n`n"
    } else {
        warningText := "Your current resolution is not officially supported.`n`n"
            . "The solvers may not work correctly at this resolution.`n`n"
            . "If you still wish to use the solvers:`n"
            . "• Switch to a 16:9 or 21:9 aspect ratio resolution`n"
            . "• Set the game to Borderless Fullscreen`n"
            . "• Use the toolkit normally`n`n"
            . "For now, using nearest supported templates: " targetW "x" targetH ".`n`n"
            . "NoSave can still be used normally.`n`n"
    }

    warningGui.AddText(, warningText)

    chkDontShow := warningGui.AddCheckbox("-TabStop", "Do not show this again")
    doNotShowWarning := 0
    chkDontShow.OnEvent("Click", (*) => (
        doNotShowWarning := chkDontShow.Value ? 1 : 0
    ))

    warningGui.AddButton("x250 w80 Default", "OK").OnEvent("Click", (*) => (
        warningGui.Destroy()
    ))

    warningGui.Show("W600 Center")

    WinWaitClose("ahk_id " warningGui.Hwnd)

    if (doNotShowWarning) {
        disableWarning(iniFile)
    }
}

disableWarning(iniFile) {
    if (FileExist(iniFile))
        IniWrite(1, iniFile, "Options", "DisableResolutionWarning")
}
