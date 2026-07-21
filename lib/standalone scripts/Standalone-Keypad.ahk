#Include ../standaloneHelpers.ahk
#Include classes\Class-KP.ahk

global fingerprintMode := 0

init() {
    global heistinstance
    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")

    CreateHeistInstance()
}

CreateHeistInstance() {
    keypad := KeypadSolver(delay, UpdateGlobalStatus, cachedKeypadAnchor, folder, higherRes,
        OPENCV_ENGINE)

    global heistinstance := keypad
}

init()