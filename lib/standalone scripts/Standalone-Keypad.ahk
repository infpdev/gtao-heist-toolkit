#Include "../standaloneHelpers.ahk"
#Include "classes\Class-CasinoKP.ahk"

global fingerprintMode := 0

init() {
    global heistinstance
    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")

    standalone_switch_to_auto(*) {
        global hackMode := "auto"
        UpdateGlobalStatus(hackInProgress)
        heistinstance.switchToAuto()
    }

    standalone_switch_to_manual(*) {
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