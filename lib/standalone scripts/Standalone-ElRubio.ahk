#Include ../standaloneHelpers.ahk
#Include classes\Class-Rubio.ahk

global heist := CAYO_PERICO

init() {
    global heistinstance

    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")
    pgUpReg := CanonicalToRegistration(sendPgUpKey)
    try Hotkey("~" pgUpReg, PgUpDown, "On")
    try Hotkey("~" pgUpReg " up", PgUpUp, "On")

    standalone_switch_to_auto(*) {
        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip(), -2000
            return
        }

        global hackMode := "auto"
        UpdateGlobalStatus(hackInProgress)
        heistinstance.Hack()
    }

    standalone_switch_to_manual(*) {
        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip(), -2000
            return
        }

        global hackMode := "manual"
        UpdateGlobalStatus(hackInProgress)
        heistinstance.SwitchToManual()
        return
    }

    CreateHeistInstance()

}

CreateHeistInstance() {
    rubio := ElRubioSolver(delay, UpdateGlobalStatus, cachedRubioAnchor, folder, higherRes,
        OPENCV_ENGINE)

    global heistinstance := rubio
}

init()