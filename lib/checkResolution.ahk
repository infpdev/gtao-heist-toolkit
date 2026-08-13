if (!IsSet(OPENCV_ENGINE))
    global OPENCV_ENGINE := 1

global unsupportedResolution := false
global higherRes := false
global canUseAHKEngine := false

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
if (FileExist(iniFile))
    global disableWarningFlag := IniRead(iniFile, "Options", "DisableResolutionWarning", 0)
else
    global disableWarningFlag := 0

checkResolution() {
    global unsupportedResolution, higherRes, targetW, targetH, iniFile, engine, canUseAHKEngine

    ; Check if exact match
    isExactMatch := false
    for _, res in supportedResolutions {
        if (A_ScreenWidth = res[1] && A_ScreenHeight = res[2]) {
            isExactMatch := true
            break
        }
    }

    if (isExactMatch) {
        canUseAHKEngine := true
        unsupportedResolution := false
        higherRes := false
        return
    }

    aspectRatio := A_ScreenWidth / A_ScreenHeight

    ; Check aspect ratio (16:9 ≈ 1.777...)
    is16to9 := (aspectRatio > 1.75 && aspectRatio < 1.80)

    ; Check for 16:10 aspect ratio (~1.6)
    is16to10 := (aspectRatio > 1.58 && aspectRatio < 1.63)

    ; Check for ultrawide 21:9 aspect ratio (~2.333...)
    is21to9 := (aspectRatio > 2.05 && aspectRatio < 2.4)

    if (is16to10 && A_ScreenWidth >= 1900) {
        unsupportedResolution := false
        higherRes := true
        engine := OPENCV_ENGINE
        return
    }

    if ((is16to9 || is21to9) && (A_ScreenWidth > 1920)) {
        ; Higher resolution 16:9 / 21:9 screen - use OpenCV
        unsupportedResolution := false
        higherRes := true
        engine := OPENCV_ENGINE
        return
    }

    ; Unsupported resolution - still try OpenCV as the robust fallback
    unsupportedResolution := true
    higherRes := false
    engine := OPENCV_ENGINE

    ShowResolutionWarning(iniFile)
    return
}

ShowResolutionWarning(iniFile) {
    global disableWarningFlag

    if (disableWarningFlag = "1")
        return

    warningGui := Gui("-DPIScale")
    warningGui.SetFont("s10")
    warningGui.Title := "Unsupported Resolution"

    warningText := "Your current resolution is not officially supported.`n`n"
        . "The solvers may not work correctly at this resolution.`n`n"
        . "If you still wish to use the solvers:`n"
        . "• Switch to a 16:9, 16:10 or 21:9 aspect ratio resolution`n"
        . "• Set the game to Borderless Fullscreen`n"
        . "• Use the toolkit normally`n`n"
        . "The OpenCV engine will be used as a fallback.`n`n"
        . "NoSave can still be used normally.`n`n"

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
