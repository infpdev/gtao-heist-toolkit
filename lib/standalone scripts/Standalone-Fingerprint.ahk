#Include ../standaloneHelpers.ahk
#Include classes\Class-FP.ahk

init() {
    global heistinstance

    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")

    standalone_switch_to_auto(*) {
        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip(), -2000
            return
        }

        global hackMode := "auto", heistinstance
        UpdateGlobalStatus(hackInProgress)
        heistinstance.AutoHack()
    }

    standalone_switch_to_manual(*) {
        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip(), -2000
            return
        }

        global hackMode := "manual", heistinstance
        UpdateGlobalStatus(hackInProgress)
        heistinstance.ManualMode()
    }

    CreateHeistInstance()

}

CreateHeistInstance() {
    fingerPrint := FingerprintSolver(delay, UpdateGlobalStatus,
        cachedFingerprintAnchor, folder, higherRes, OPENCV_ENGINE)

    global heistinstance := fingerPrint
}

init()