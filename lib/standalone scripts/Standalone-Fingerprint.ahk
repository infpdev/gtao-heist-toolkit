#Include "../standaloneHelpers.ahk"
#Include "classes\Class-CasinoFP.ahk"

init() {
    global heistinstance

    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")

    standalone_switch_to_auto(*) {
        global hackMode := "auto", heistinstance
        UpdateGlobalStatus(hackInProgress)
        heistinstance.AutoHack()
    }

    standalone_switch_to_manual(*) {
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