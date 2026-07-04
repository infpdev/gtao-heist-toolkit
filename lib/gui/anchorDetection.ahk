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
    global cachedFingerprintAnchor, cachedKeypadAnchor, folder, scrW, scrH, debug, cachedRubioAnchor,
        engine, OPENCV_ENGINE, AHK_ENGINE, ledgeGrabInProgress
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
    static rb_x2 := A_ScreenWidth * 0.59
    static rb_y2 := A_ScreenHeight * 0.11

    static tolerance := "*" 20 " "
    static rubioAnchorTolerance := "*" 10 " "

    if (ledgeGrabInProgress)
        return 0

    localSearchSize := 20
    fpFound := false, kpFound := false, elFound := false
    fpPx := 0, fpPy := 0, kpPx := 0, kpPy := 0, elPx := 0, elPy := 0

    ; Fingerprint: try cached area first, then fallback to full fingerprint area.
    if (debug) {
        CustomTooltip "Searching for fingerprint anchor", 0, 0, 18
        ToolTip "⇲", fp_x1, fp_y1, 15 ; Debug: show search area
        ToolTip "⇱", fp_x2, fp_y2, 16 ; Debug: show search area
        ; Sleep 300
    }
    try {
        if (IsObject(cachedFingerprintAnchor) && cachedFingerprintAnchor.x && cachedFingerprintAnchor.y) {
            cx := cachedFingerprintAnchor.x, cy := cachedFingerprintAnchor.y
            x1 := Max(cx - localSearchSize, 0)
            y1 := Max(cy - localSearchSize, 0)
            x2 := Min(cx + localSearchSize, scrW)
            y2 := Min(cy + localSearchSize, scrH)
            fpFound := ImageSearch(&fpPx, &fpPy, x1, y1, x2, y2, tolerance folder "anchor.png")
        }
    } catch {
        cachedFingerprintAnchor := 0 ; Reset cache on error to prevent repeated failures
    }

    if (!fpFound)
        fpFound := ImageSearch(&fpPx, &fpPy, fp_x1, fp_y1, fp_x2, fp_y2, tolerance folder "anchor.png")

    if (fpFound)
        fpFound := is_black_area_present_fingerprint() ; Verify black area for fingerprint to prevent false positives

    ; Keypad: try cached area first, then fallback to full keypad area.
    if (debug) {
        CustomTooltip "Searching for keypad anchor", 0, 0, 18
        ToolTip "⇲", kp_x1, kp_y1, 15 ; Debug: show search area
        ToolTip "⇱", kp_x2, kp_y2, 16 ; Debug: show search area
        ; Sleep 300
    }
    try {
        if (IsObject(cachedKeypadAnchor) && cachedKeypadAnchor.x && cachedKeypadAnchor.y) {
            cx := cachedKeypadAnchor.x, cy := cachedKeypadAnchor.y
            x1 := Max(cx - localSearchSize, 0)
            y1 := Max(cy - localSearchSize, 0)
            x2 := Min(cx + localSearchSize, scrW)
            y2 := Min(cy + localSearchSize, scrH)
            kpFound := ImageSearch(&kpPx, &kpPy, x1, y1, x2, y2, tolerance folder "anchor.png")
        }
    } catch {
        cachedKeypadAnchor := 0 ; Reset cache on error to prevent repeated failures
    }

    if (!kpFound)
        kpFound := ImageSearch(&kpPx, &kpPy, kp_x1, kp_y1, kp_x2, kp_y2, tolerance folder "anchor.png")

    if (kpFound)
        kpFound := is_black_area_present_keypad() ; Verify black area for keypad to prevent false positives

    ; El Rubio: try cached area first, then fallback to full region.
    if (debug) {
        CustomTooltip "Searching for El Rubio anchor", 0, 0, 18
        ; ToolTip "⇲", rb_x1, rb_y1, 15 ; Debug: show search area
        ; ToolTip "⇱", rb_x2, rb_y2, 16 ; Debug: show search area
        ; Sleep 300
    }

    try {
        if (IsObject(cachedRubioAnchor) && cachedRubioAnchor.x && cachedRubioAnchor.y) {
            cx := cachedRubioAnchor.x, cy := cachedRubioAnchor.y
            x1 := Max(cx - localSearchSize, 0)
            y1 := Max(cy - localSearchSize, 0)
            x2 := Min(cx + localSearchSize, scrW)
            y2 := Min(cy + localSearchSize, scrH)
            elFound := ImageSearch(&elPx, &elPy, x1, y1, x2, y2, rubioAnchorTolerance folder "elAnchor.png")
        }
    } catch {
        cachedRubioAnchor := 0 ; Reset cache on error to prevent repeated failures
    }

    if (!elFound)
        elFound := ImageSearch(&elPx, &elPy, rb_x1, rb_y1, rb_x2, rb_y2, rubioAnchorTolerance folder "elAnchor.png"
        )

    if (elFound)
        elFound := is_black_area_present_cayo() ; Verify black area for El Rubio to prevent false positives

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
        CustomTooltip "No anchors found (auto-detect)", 0, 0, 18
    }
    return false

}

/**
 * Uses OpenCV to search for anchors, which is more reliable but slower than AHK's ImageSearch.
 * Only called if AHK search fails to find any anchors.
 * 
 * Returns:
 *   - {mode: "fingerprint"|"keypad"|"cayo", x, y} if found
 *   - 0 if not found or on error
 * 
 * Side effects: None
 */
foundAnchorOpenCV() {
    global ledgeGrabInProgress
    if (ledgeGrabInProgress)
        return 0

    puzzle := GetResFromOpenCV(REQ_ALL_ANCHORS)
    if (puzzle) {
        ; MsgBox puzzle
        return { mode: puzzle, x: 0, y: 0 }
    }
    else if (puzzle = ERRMSG) {
        ShowCenteredToolTip "ERR AT anchorDetection.ahk (line 169)", 15
        return 0
    }

}

/**
 * Polls for anchor images and switches modes/instances accordingly.
 * If an anchor is found, switches to the correct mode and creates the instance.
 * If not found, disables further polling.
 * 
 * Side effects: Updates global anchorFound, hackMode, creates heist instance.
 */
findAnchorsAndCreateInstance() {
    global anchorFound, hackMode, fingerprintMode, scriptsEnabled, heistInstance, ledgeGrabInProgress
    if (hackMode != "idle" || !scriptsEnabled) {
        SetTimer(findAnchorsAndCreateInstance, 0)
        anchorFound := false
        return
    }

    if (!isGtaFocused(true) || ledgeGrabInProgress)
        return

    anchor := (engine == AHK_ENGINE)
        ? foundAnchor()
        : foundAnchorOpenCV()

    if (!anchor && engine == AHK_ENGINE) ; If AHK engine fails to find an anchor, try OpenCV before giving up
        anchor := foundAnchorOpenCV()

    if (!anchor) {
        if (debug)
            ShowCenteredToolTip "No anchors found", 17
        anchorFound := false

        return
    } else {
        if (debug) {
            ShowCenteredToolTip "Anchor found: " anchor.mode (engine == OPENCV_ENGINE ? " (OpenCV)" : ""), 17
            sleep 500
        }

    }

    anchorFound := true

    if (IsObject(anchor) && anchor.mode == "fingerprint") {
        if (heist != DIAMOND_CASINO)
            ToggleHeistMode() ; Switch to Diamond Casino if not already in it
        if (!fingerprintMode)
            ToggleFingerprintMode() ; Switch to fingerprint mode if not already in it
    } else if (IsObject(anchor) && anchor.mode == "keypad") {
        if (heist != DIAMOND_CASINO)
            ToggleHeistMode() ; Switch to Diamond Casino if not already in it
        if (fingerprintMode)
            ToggleFingerprintMode() ; Switch to keypad mode if not already in it
    } else if (IsObject(anchor) && anchor.mode == "cayo") {
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

/**
 * Return true if the fingerprint anchor black-area is PRESENT.
 * Searches for blackAnchor.png in the region: 1606, 806, 1891, 943 (normalized: 0.837, 0.746, 0.985, 0.873)
 * 
 * Returns:
 *   true if blackAnchor.png is found (black area present)
 *   false if not found
 */
is_black_area_present_fingerprint() {
    global folder, scrW, scrH
    static black_x1 := 0.86 * A_ScreenWidth
    static black_y1 := 0.43 * A_ScreenHeight
    static black_x2 := 0.98 * A_ScreenWidth
    static black_y2 := 0.88 * A_ScreenHeight

    static black_x1_alt := 0.05 * A_ScreenWidth
    static black_y1_alt := 0.55 * A_ScreenHeight
    static black_x2_alt := 0.17 * A_ScreenWidth
    static black_y2_alt := 0.8 * A_ScreenHeight

    static tolerance := "*" 10 " "

    found := ImageSearch(&px, &py, black_x1, black_y1, black_x2, black_y2, tolerance folder "blackAnchor.png")
    if (!found)
        found := ImageSearch(&px, &py, black_x1_alt, black_y1_alt, black_x2_alt, black_y2_alt, tolerance folder "blackAnchor.png"
        )

    if (debug)
        ShowCenteredToolTip "Fingerprint: " found, 15
    return found
}

/**
 * Return true if the keypad anchor black-area is PRESENT.
 * Searches for blackAnchor.png in the region: 1606, 806, 1891, 943 (normalized: 0.837, 0.746, 0.985, 0.873)
 * 
 * Returns:
 *   true if blackAnchor.png is found (black area present)
 *   false if not found
 */
is_black_area_present_keypad() {
    global folder, scrW, scrH
    static black_x1 := 0.86 * A_ScreenWidth
    static black_y1 := 0.43 * A_ScreenHeight
    static black_x2 := 0.98 * A_ScreenWidth
    static black_y2 := 0.88 * A_ScreenHeight

    static black_x1_alt := 0.05 * A_ScreenWidth
    static black_y1_alt := 0.55 * A_ScreenHeight
    static black_x2_alt := 0.17 * A_ScreenWidth
    static black_y2_alt := 0.8 * A_ScreenHeight

    static tolerance := "*" 10 " "

    found := ImageSearch(&px, &py, black_x1, black_y1, black_x2, black_y2, tolerance folder "blackAnchor.png")
    if (!found)
        found := ImageSearch(&px, &py, black_x1_alt, black_y1_alt, black_x2_alt, black_y2_alt, tolerance folder "blackAnchor.png"
        )

    if (debug)
        ShowCenteredToolTip "Keypad: " found, 15
    return found
}

/**
 * Return true if the cayo anchor black-area is PRESENT.
 * Searches for blackAnchor.png in the region: 1605, 329, 1898, 783 (normalized: 0.836, 0.305, 0.989, 0.725)
 * 
 * Returns:
 *   true if blackAnchor.png is found (black area present)
 *   false if not found
 */
is_black_area_present_cayo() {
    global folder, scrW, scrH
    static black_x1 := 0.836 * A_ScreenWidth
    static black_y1 := 0.305 * A_ScreenHeight
    static black_x2 := 0.989 * A_ScreenWidth
    static black_y2 := 0.725 * A_ScreenHeight

    static tolerance := "*" 10 " "

    found := ImageSearch(&px, &py, black_x1, black_y1, black_x2, black_y2, tolerance folder "elBlackAnchor.png")
    if (debug)
        ShowCenteredToolTip "Cayo: " found, 15
    return found
}

; Unused funcs
{

    getAnchorType() {
        global OPENCV_ENGINE, AHK_ENGINE, engine, debug
        if (engine == AHK_ENGINE) {
            anchor := foundAnchor()
            if (anchor && !shouldCreateInstance(anchor.mode)) {
                openCVShouldCreateInstance := shouldCreateInstance(anchor.mode, OPENCV_ENGINE)
                if (openCVShouldCreateInstance) {
                    ToggleEngineMode(, , OPENCV_ENGINE) ; Switch to OpenCV engine if AHK detects an anchor but
                    ; fails to find the black region
                    if (debug) {
                        ShowCenteredToolTip "Switching to OpenCV engine for anchor detection", 15
                        sleep 500
                    }
                } else
                    return anchor
            }

            if (!anchor) {
                anchor := foundAnchorOpenCV()

                if (IsObject(anchor) && anchor.mode) {
                    ToggleEngineMode(, , OPENCV_ENGINE) ; Switch to OpenCV engine if it detects an anchor that AHK did not find
                    if (debug) {
                        ShowCenteredToolTip "Switching to OpenCV engine for anchor detection", 15
                        sleep 500
                    }
                }
            }

        }
        else {
            anchor := foundAnchorOpenCV()
            return anchor
        }

        if (anchor && !shouldCreateInstance(anchor.mode)) {
            return anchor
        }
    }

    shouldCreateInstance(forType := "", engineOverride := "") {
        global heistInstance, fingerprintMode, higherRes, heist

        if (forType == "")
            return false

        if (engineOverride != "")
            tempEngine := engineOverride
        else
            tempEngine := engine

        ; MsgBox forType

        temp_heist := (forType == "cayo" ? CAYO_PERICO : DIAMOND_CASINO)
        temp_fingerprintMode := (forType == "fingerprint" ? 1 : 0)

        try {
            if (tempEngine == AHK_ENGINE) {
                if (temp_heist == DIAMOND_CASINO) {
                    if (temp_fingerprintMode) {
                        return is_black_area_present_fingerprint()
                    } else {
                        return is_black_area_present_keypad()
                    }
                    return false

                } else if (temp_heist == CAYO_PERICO) {
                    return is_black_area_present_cayo()
                }
            }
            else if (tempEngine == OPENCV_ENGINE || higherRes) {
                ; return true ; OpenCV now handles both detection and black area verification for all modes
                if (temp_heist == DIAMOND_CASINO) {
                    if (temp_fingerprintMode) {
                        res := GetResFromOpenCV(REQ_BLACK_FP)
                        if (debug)
                            ShowCenteredToolTip "Fingerprint(Opencv): " res, 15
                        return res
                    } else {
                        res := GetResFromOpenCV(REQ_BLACK_KP)
                        if (debug)
                            ShowCenteredToolTip "Keypad(Opencv): " res, 15
                        return res
                    }

                } else {
                    if (temp_heist == CAYO_PERICO) {
                        res := GetResFromOpenCV(REQ_BLACK_CAYO)
                        if (debug)
                            ShowCenteredToolTip "Cayo(Opencv): " res, 15
                        return res
                    }
                }
            }
        }
    }

}
