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

    CreateHeistInstance()

}

CreateHeistInstance() {
    rubio := ElRubioSolver(delay, UpdateGlobalStatus, cachedRubioAnchor, folder, higherRes,
        OPENCV_ENGINE)

    global heistinstance := rubio
}

init()