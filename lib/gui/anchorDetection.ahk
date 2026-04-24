/**
 * Searches for anchor images (fingerprint, keypad, El Rubio) on the screen to determine the current puzzle state.
 * Uses cached anchor positions for faster search, falls back to full region if not found.
 * 
 * Returns:
 *   - {mode: "fingerprint"|"keypad"|"cayo", x, y} if found
 *   - "error" if both fingerprint and keypad are found (should not happen)
 *   - false if nothing found
 * 
 * Side effects: Updates cached anchor globals.
 */
foundAnchor() {
    global cachedFingerprintAnchor, cachedKeypadAnchor, folder, scrW, scrH, debug, cachedRubioAnchor
    static fp_x1 := 0.76 * A_ScreenWidth
    static fp_y1 := 0.22 * A_ScreenHeight
    static fp_x2 := 0.8 * A_ScreenWidth
    static fp_y2 := 0.55 * A_ScreenHeight

    static kp_x1 := 0.53 * A_ScreenWidth
    static kp_y1 := 0.12 * A_ScreenHeight
    static kp_x2 := 0.73 * A_ScreenWidth
    static kp_y2 := 0.17 * A_ScreenHeight

    static rb_x1 := A_ScreenWidth * 0.48
    static rb_y1 := A_ScreenHeight * 0.1
    static rb_x2 := A_ScreenWidth * 0.815
    static rb_y2 := A_ScreenHeight * 0.295

    static tolerance := "*" 20 " "
    static rubioAnchorTolerance := "*" 10 " "

    localSearchSize := 20
    fpFound := false, kpFound := false, elFound := false
    fpPx := 0, fpPy := 0, kpPx := 0, kpPy := 0, elPx := 0, elPy := 0

    ; Fingerprint: try cached area first, then fallback to full fingerprint area.
    if (debug) {
        ToolTip "Searching for fingerprint anchor", 0, 0, 18
        ToolTip "⇲", fp_x1, fp_y1, 15 ; Debug: show search area
        ToolTip "⇱", fp_x2, fp_y2, 16 ; Debug: show search area
        ; Sleep 300
    }
    if (IsObject(cachedFingerprintAnchor) && cachedFingerprintAnchor.x && cachedFingerprintAnchor.y) {
        cx := cachedFingerprintAnchor.x, cy := cachedFingerprintAnchor.y
        x1 := Max(cx - localSearchSize, 0)
        y1 := Max(cy - localSearchSize, 0)
        x2 := Min(cx + localSearchSize, scrW)
        y2 := Min(cy + localSearchSize, scrH)
        fpFound := ImageSearch(&fpPx, &fpPy, x1, y1, x2, y2, tolerance folder "anchor.png")
    }
    if (!fpFound)
        fpFound := ImageSearch(&fpPx, &fpPy, fp_x1, fp_y1, fp_x2, fp_y2, tolerance folder "anchor.png")

    ; Keypad: try cached area first, then fallback to full keypad area.
    if (debug) {
        ToolTip "Searching for keypad anchor", 0, 0, 18
        ToolTip "⇲", kp_x1, kp_y1, 15 ; Debug: show search area
        ToolTip "⇱", kp_x2, kp_y2, 16 ; Debug: show search area
        ; Sleep 300
    }
    if (IsObject(cachedKeypadAnchor) && cachedKeypadAnchor.x && cachedKeypadAnchor.y) {
        cx := cachedKeypadAnchor.x, cy := cachedKeypadAnchor.y
        x1 := Max(cx - localSearchSize, 0)
        y1 := Max(cy - localSearchSize, 0)
        x2 := Min(cx + localSearchSize, scrW)
        y2 := Min(cy + localSearchSize, scrH)
        kpFound := ImageSearch(&kpPx, &kpPy, x1, y1, x2, y2, tolerance folder "anchor.png")
    }
    if (!kpFound)
        kpFound := ImageSearch(&kpPx, &kpPy, kp_x1, kp_y1, kp_x2, kp_y2, tolerance folder "anchor.png")

    ; El Rubio: try cached area first, then fallback to full region.
    if (debug) {
        ToolTip "Searching for El Rubio anchor", 0, 0, 18
        ToolTip "⇲", rb_x1, rb_y1, 15 ; Debug: show search area
        ToolTip "⇱", rb_x2, rb_y2, 16 ; Debug: show search area
        ; Sleep 300
    }

    if (IsObject(cachedRubioAnchor) && cachedRubioAnchor.x && cachedRubioAnchor.y) {
        cx := cachedRubioAnchor.x, cy := cachedRubioAnchor.y
        x1 := Max(cx - localSearchSize, 0)
        y1 := Max(cy - localSearchSize, 0)
        x2 := Min(cx + localSearchSize, scrW)
        y2 := Min(cy + localSearchSize, scrH)
        elFound := ImageSearch(&elPx, &elPy, x1, y1, x2, y2, rubioAnchorTolerance folder "elAnchor.png")
    }
    if (!elFound)
        elFound := ImageSearch(&elPx, &elPy, rb_x1, rb_y1, rb_x2, rb_y2, rubioAnchorTolerance folder "elAnchor.png"
        )

    if (fpFound && kpFound)
        return "error"

    if (kpFound) {
        if (debug) {
            ToolTip "Keypad anchor found!", kpPx + 10, kpPy + 10, 18
        }
        cachedKeypadAnchor := { x: kpPx, y: kpPy }
        return { mode: "keypad", x: kpPx, y: kpPy }
    }

    if (fpFound) {
        if (debug) {
            ToolTip "Fingerprint anchor found!", fpPx + 10, fpPy + 10, 18
        }
        cachedFingerprintAnchor := { x: fpPx, y: fpPy }
        return { mode: "fingerprint", x: fpPx, y: fpPy }
    }

    if (elFound) {
        if (debug) {
            ToolTip "El Rubio anchor found!", elPx + 10, elPy + 10, 18
        }
        cachedRubioAnchor := { x: elPx, y: elPy }
        return { mode: "cayo", x: elPx, y: elPy }
    }

    if (debug) {
        ToolTip "No anchors found", 0, 0, 18
    }
    return false

}

/**
 * Polls for anchor images and switches modes/instances accordingly.
 * If an anchor is found, switches to the correct mode and creates the instance.
 * If not found, disables further polling.
 * 
 * Side effects: Updates global anchorFound, hackMode, creates heist instance.
 */
findAnchorsAndCreateInstance() {
    global anchorFound, hackMode, fingerprintMode, scriptsEnabled, heistInstance
    if (hackMode != "idle" || !scriptsEnabled) {
        SetTimer(findAnchorsAndCreateInstance, 0)
        anchorFound := false
        return
    }
    anchor := foundAnchor()
    if (IsObject(anchor) && anchor.mode == "fingerprint") {
        anchorFound := true
        if (heist != DIAMOND_CASINO)
            ToggleHeistMode() ; Switch to Diamond Casino if not already in it
        if (!fingerprintMode)
            ToggleFingerprintMode() ; Switch to fingerprint mode if not already in it
    } else if (IsObject(anchor) && anchor.mode == "keypad") {
        anchorFound := true
        if (heist != DIAMOND_CASINO)
            ToggleHeistMode() ; Switch to Diamond Casino if not already in it
        if (fingerprintMode)
            ToggleFingerprintMode() ; Switch to keypad mode if not already in it
    } else if (IsObject(anchor) && anchor.mode == "cayo") {
        anchorFound := true
        if (heist != CAYO_PERICO)
            ToggleHeistMode() ; Switch to Cayo Perico if not already in it

    } else {
        anchorFound := false
        return
    }

    if (!IsObject(heistInstance))
        CreateHeistInstance()

    hackMode := (heist == DIAMOND_CASINO ? "manual" : "auto") ; Default to manual mode when anchor is found
    SetTimer(() => (IsObject(heistInstance) ? heistInstance.autoStartManual(anchor) : ""), -100) ; Start manual mode on the exact switched instance
    SetTimer(findAnchorsAndCreateInstance, 0) ; Stop anchor detection timer
}