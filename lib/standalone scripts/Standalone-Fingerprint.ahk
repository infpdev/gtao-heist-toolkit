#Include ../standaloneHelpers.ahk
#Include classes\Class-FP.ahk

init() {
    global heistinstance

    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")

    CreateHeistInstance()

}

CreateHeistInstance() {
    fingerPrint := FingerprintSolver(delay, UpdateGlobalStatus,
        cachedFingerprintAnchor, folder, higherRes, OPENCV_ENGINE)

    global heistinstance := fingerPrint
}

init()