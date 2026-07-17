#Include ../standaloneHelpers.ahk
#Include classes\Class-KP.ahk

global fingerprintMode := 0

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

        global hackMode := "auto"
        UpdateGlobalStatus(hackInProgress)
        heistinstance.switchToAuto()
    }

    standalone_switch_to_manual(*) {
        if (ledgeGrabInProgress) {
            ShowCenteredToolTip "Cannot use solvers while ledge grab is in progress", 17
            SetTimer () => ToolTip(), -2000
            return
        }

        global hackMode := "manual"
        UpdateGlobalStatus(hackInProgress)
        heistinstance.switchToManual()
    }

    CreateHeistInstance()
}

CreateHeistInstance() {
    keypad := KeypadSolver(delay, UpdateGlobalStatus, cachedKeypadAnchor, folder, higherRes,
        OPENCV_ENGINE)

    global heistinstance := keypad
}

init()