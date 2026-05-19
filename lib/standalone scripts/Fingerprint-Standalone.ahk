#Include "../standaloneHelpers.ahk"

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

; class start
; DO NOT REMOVE THE ABOVE LINE - REQUIRED TO AUTOMATE BUILDING OF CLASSES AS STANDALONE SCRIPTS
/**
 * @description Fingerprint solver class.
 * Handles anchor detection, fingerprint group detection, piece matching, and selection
 * for the Diamond Casino fingerprint hack.
 * 
 * ### FLOW:
 * ```text
 * AutoHack()/ManualMode() → findAnchor()/tryOpenCV() → start MainLoop(timer)
 * 
 * MainLoop():
 *   InitDetected()            ; reset detection state
 *   if useOpenCv/highRes:
 *     tryOpenCV()             ; OpenCV anchor → REQ_FINGERPRINT → openCVSelect()
 *     → if OpenCV fails
 *  and fallback is allowed, 
 *  continue with AHK flow
 *   findAnchor()              ; validate UI (loss → timeout/Idle)
 *   DetectAnchorGroup()       ; detect active group (fail → return)
 * 
 *   (manual mode):
 *     Pmatch()                ; detect pieces (per anchorGroup)
 *     updateCounter()         ; count detected pieces
 *     → set handoffPending
 *      (>=4)
 * 
 *   (auto mode):
 *     if !handoffPending:
 *       Pmatch()              ; detect pieces
 *       updateCounter()
 * 
 *     if counter >= 4:
 *       Select()              ; compute + send inputs
 *       clearAll()
 *       → fallback Send "{Tab}"
 * 
 * Destroy()/Idle() → stop + clear state
 * ```
 * 
 * ### Pipeline:
 * OpenCV / Anchor → OpenCV Match/Select OR Group → Match Pieces → Count → Select → Repeat
 */
class FingerprintSolver {

    mode := "idle"
    scrW := A_ScreenWidth
    scrH := A_ScreenHeight

    counter := 0
    delay := 0
    lastSeenPrint := 0
    lastFoundTick := 0
    prevFoundPixel := 0
    lastSeenGroupTick := 0
    ahkFailTimer := 0
    prevPrints := ""

    XP1 := A_ScreenWidth * 0.23
    YP1 := A_ScreenHeight * 0.23
    XP2 := A_ScreenWidth * 0.41
    YP2 := A_ScreenHeight * 0.78
    anchorTolerance := 100
    primaryAnchorTolerance := 30
    baseW := 1920
    scale := 1

    pArr := Map() ; piece index -> slot (0..7)
    anchorGroup := []
    detected := []

    handoffPending := false
    needStatusUpdate := true
    foundAnchor := false
    isBusy := false
    isShuttingDown := false
    autoStarted := false

    lowRes := A_ScreenWidth < 1920

    __New(delay, updateGlobalStatus, prevFoundPixel := 0, folderPath := "", highRes := false, engine :=
        AHK_ENGINE) {
        global folder

        this.delay := delay
        this.prevFoundPixel := prevFoundPixel
        this.folder := folderPath != "" ? folderPath : folder
        this.highRes := highRes
        this.useOpenCv := engine == OPENCV_ENGINE

        SetKeyDelay delay, delay
        this.fnMainLoop := ObjBindMethod(this, "MainLoop")
        this.fnFindAnchor := ObjBindMethod(this, "findAnchor")
        this.fnCheckFalsePositive := ObjBindMethod(this, "CheckFalsePositive")
        this.scale := (this.baseW / this.scrW) ** 0.7

        this.isShuttingDown := false
        this.isBusy := false

        this.Idle()
    }

    /**
     * @callback
     * Sets the key delay for input. Used by the main script to
     * configure the solver's input timing on changes to the delay input in the GUI.
     * 
     * @param {number} delayMs - Delay in milliseconds
     */
    setKeyDelay(delayMs) {
        this.delay := delayMs
    }

    /**
     * Sets the engine to use for detection.
     * 1 for OpenCV, 0 for AHK.
     * @param engine 
     */
    setEngine(engine) {
        this.ahkFailTimer := 0
        this.lastSeenGroupTick := 0
        this.useOpenCv := engine == OPENCV_ENGINE
    }

    /**
     * Sets the solver to idle mode, clears tooltips and resets the state.
     */
    Idle() {
        this.isShuttingDown := false
        this.clearAll()
        this.pArr := Map()
        this.handoffPending := false
        this.isBusy := false
        this.anchorTolerance := 50
        this.mode := "idle"
        this.lastSeenPrint := 0
        this.lastFoundTick := 0
        this.lastSeenGroupTick := 0
        this.ahkFailTimer := 0
        this.InitDetected()
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        updateGlobalStatus(false, false, , "CasinoFingerprint.Idle()")
    }

    Destroy() {
        this.isShuttingDown := true
        this.mode := "idle"
        this.foundAnchor := false
        this.isBusy := false
        this.handoffPending := false
        this.needStatusUpdate := true
        this.counter := 0
        this.lastSeenPrint := 0
        this.lastFoundTick := 0
        this.lastSeenGroupTick := 0
        this.ahkFailTimer := 0
        this.pArr := Map()
        this.detected := []
        this.anchorGroup := []

        ; stop timer
        try SetTimer this.fnMainLoop, 0
        try SetTimer this.fnCheckFalsePositive, 0

        ; clear ALL tooltips
        this.clearAll()
    }

    /**
     * Starts manual mode with the given anchor pixel coordinates, bypassing the initial anchor search.
     * Used by the main script to immediately start manual mode
     * when the main script auto-detects one of the anchor pixels.
     * @param {object} anchorPixelCoords - Anchor pixel coordinates
     */
    autoStartManual(anchorPixelCoords) {
        if (this.isShuttingDown)
            return

        this.autoStarted := true
        this.prevFoundPixel := anchorPixelCoords
        this.ManualMode(true)

        ; SetTimer this.fnCheckFalsePositive, 0
        SetTimer this.fnCheckFalsePositive, -5000
    }

    /**
     * Checks for false positives and resets if anchor is lost during auto-start.
     */
    CheckFalsePositive() {
        if (this.isShuttingDown || this.mode != "manual" || !this.autoStarted)
            return

        if (!this.foundAnchor) {
            ResetHackMode()
            this.Idle()
        }
    }

    /**
     * Starts / switches to manual mode and starts the main loop timer.
     */
    ManualMode(autoStarted := false) {
        if (this.autoStarted && !autoStarted)
            this.autoStarted := false

        if (this.isShuttingDown)
            return

        this.lastFoundTick := 0

        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        this.mode := "manual"

        updateGlobalStatus(this.foundAnchor, , , "CasinoFingerprint.ManualMode()")

        this.findAnchor()
        this.MainLoop()
        SetTimer this.fnMainLoop, 500

    }

    /**
     * Starts / switches to auto mode and starts the main loop timer.
     */
    AutoHack() {
        if (this.autoStarted)
            this.autoStarted := false

        if (this.isShuttingDown)
            return

        this.lastFoundTick := 0

        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        this.mode := "auto"

        updateGlobalStatus(this.foundAnchor, , , "CasinoFingerprint.AutoHack()")

        this.findAnchor()
        this.MainLoop()
        SetTimer this.fnMainLoop, 200

    }

    tryOpenCV() {
        if (!this.useOpenCv)
            return false

        try {
            this.foundAnchor := Integer(GetResFromOpenCV(ANCHOR_FINGERPRINT))
            ; ShowCenteredToolTip this.foundAnchor
            if (!this.foundAnchor || this.foundAnchor == ERRMSG) {
                this.foundAnchor := false
                this.needStatusUpdate := true
                this.prevFoundPixel := 0
                return false
            } else {
                this.lastFoundTick := A_TickCount
                if (debug)
                    ToolTip "[class (fp) | opencv] Fingerprint anchor found!", 0, 0, 18
            }

            positions := GetResFromOpenCV(REQ_FINGERPRINT)
            if (positions != -1) {
                if (this.autoStarted)
                    this.autoStarted := false

                if (this.needStatusUpdate && this.foundAnchor) {
                    UpdateGlobalStatus(true, , , "CasinoFingerprint.tryOpenCV()")
                    this.needStatusUpdate := false
                }

                if (positions == 100) {
                    this.markPrints(this.prevPrints, "")
                    if (debug)
                        ShowCenteredToolTip "All prints already selected", 17
                    return true
                } else {
                    if (debug)
                        ShowCenteredToolTip "OpenCV detected pieces: " positions, 17
                }

                this.markPrints(this.prevPrints, positions)

                if (this.mode == "auto")
                    this.openCVSelect(positions)

                return true
            } else {
                this.pArr := Map()
                this.clearAll()
            }

            this.needStatusUpdate := true
            return false
        } catch {
            return false
        }
    }

    /**
     * @hotloop
     * Unified loop for both auto and manual keypad solving.
     * Only runs the detection logic for the current mode.
     * Should be called by a timer, does NOT handle timer setup or mode switching.
     */
    MainLoop() {

        if (this.isShuttingDown || this.mode == "idle")
            return

        if (this.mode != "manual" && !isGtaFocused(true))
            ResetHackMode()

        if (this.isBusy) {
            ; Skip overlapping timer ticks while a previous iteration is still running.
            return
        }
        this.isBusy := true

        this.checkTimeout()

        ; Try OpenCV detection if enabled, fallback to AHK only if highRes is false, since AHK is not supported
        ; on higher resolutions.
        cvWorked := this.tryOpenCV()

        if (cvWorked) {
            this.isBusy := false
            return
        }

        if (this.highRes) {
            ; OpenCV failed, but fallback is not allowed
            this.isBusy := false
            return
        } else {
            if (debug)
                ShowCenteredToolTip "Using AHK detection", 17
        }

        try {
            if (!(this.mode == "auto" && this.handoffPending)) {
                this.InitDetected()
            } else {
                if (this.handoffPending && this.pArr.Count == 4) {

                    if (debug) {
                        ToolTip "Auto handoff triggered! Detected pieces: " this.pArr.Count, 50, 50, 19
                        ; Sleep 1000
                    }

                    this.Select()
                    this.clearAll()
                    Sleep 10
                    if (this.counter == 0)
                        Send "{Tab}"

                    this.handoffPending := false
                    this.isBusy := false
                    return
                }
            }

            this.foundAnchor := (this.findAnchor() != false)
            if (!this.foundAnchor) {
                this.isBusy := false
                return
            }

            localAnchor := this.DetectAnchorGroup()
            if (localAnchor.Length == 0 && !this.useOpenCv) {

                if (this.lastSeenGroupTick) {
                    fallbackTimer := Integer((A_TickCount - this.lastSeenGroupTick) / 1000)
                    if (fallbackTimer >= 7) {
                        if (!isGtaFocused(true)) {
                            ResetHackMode()
                            return
                        }
                        this.ahkFailTimer := 0
                        this.prevPrints := ""
                        UseOpenCVEngineCallback()
                    }

                    if (debug)
                        ShowCenteredToolTip "Switching to OpenCV in " Integer(7 - fallbackTimer) " seconds", 19, 50

                } else {
                    if (!this.ahkFailTimer && this.lastFoundTick)
                        this.ahkFailTimer := A_TickCount
                    fallbackTimer := Integer((A_TickCount - this.ahkFailTimer) / 1000)
                    if (fallbackTimer >= 7) {
                        if (!isGtaFocused(true)) {
                            ResetHackMode()
                            return
                        }
                        this.ahkFailTimer := 0
                        this.prevPrints := ""
                        UseOpenCVEngineCallback()
                    }

                    if (debug)
                        ShowCenteredToolTip "Switching to OpenCV in " Integer(7 - fallbackTimer) " seconds", 19, 50

                }
            }

            if (this.anchorGroup.Length == 0 && localAnchor.Length == 0) {
                this.isBusy := false
                return
            }

            this.ahkFailTimer := 0
            this.lastSeenGroupTick := A_TickCount

            if (this.autoStarted)
                this.autoStarted := false

            if (this.mode == "manual") {

                for _, n in this.anchorGroup {
                    this.Pmatch(n, this.XP1, this.YP1, this.XP2, this.YP2)
                }
                this.updateCounter()
                if (this.counter >= 4)
                    this.handoffPending := true
                else
                    this.handoffPending := false

            } else {

                if (!this.handoffPending) {
                    this.counter := 0
                    this.pArr := Map()
                    for _, n in this.anchorGroup {
                        this.Pmatch(n, this.XP1, this.YP1, this.XP2, this.YP2)
                    }
                    this.updateCounter()
                } else {
                    this.handoffPending := false
                }
                if (this.counter >= 4) {
                    this.Select()
                    this.clearAll()
                    Sleep 10
                    if (this.counter == 0) {
                        Send "{Tab}"
                    }
                }
            }
        } catch as err {
            MsgBox err.Message "`n`n" err.Stack
        }
        finally {
            this.isBusy := false
        }
    }

    checkTimeout() {
        if (this.isShuttingDown || this.mode == "idle")
            return

        static timeoutMs := 5000
        if (this.lastFoundTick != 0 && !this.foundAnchor) {
            this.clearAll()
            timeLeft := Integer((timeoutMs - (A_TickCount - this.lastFoundTick)) / 1000) + 1
            updateGlobalStatus(false, true, timeLeft, "CasinoFingerprint.checkTimeout()")
            this.needStatusUpdate := true
            if (A_TickCount - this.lastFoundTick > timeoutMs) {
                ResetHackMode()
                this.Idle()
            }
        }
    }

    /**
     * Attempts to locate the anchor image on screen, using a cached pixel if available for faster search.
     * Updates foundAnchor and prevFoundPixel state.
     * @returns {Object|false} Anchor pixel coordinates if found, otherwise false.
     */
    findAnchor() {
        global cachedFingerprintAnchor

        static x1 := A_ScreenWidth * 0.74
        static y1 := A_ScreenHeight * 0.22
        static x2 := A_ScreenWidth * 0.8
        static y2 := A_ScreenHeight * 0.25

        if (this.highRes)
            return false

        if (this.isShuttingDown || this.mode == "idle") {
            this.foundAnchor := false
            return false
        }

        static lastFoundAnchor := 0
        ToolTip "", , , 18

        if (A_TickCount - lastFoundAnchor < 2000 && this.foundAnchor) {
            return true
        }
        lastFoundAnchor := A_TickCount

        localSearchSize := 20
        fpFound := false
        fpPx := 0, fpPy := 0

        try {
            ;  try cached pixel area first (ImageSearch in a small region around cached pixel)
            if (IsObject(this.prevFoundPixel) && this.prevFoundPixel.x && this.prevFoundPixel.y) {
                cx := this.prevFoundPixel.x, cy := this.prevFoundPixel.y
                sx1 := Max(cx - localSearchSize, 0)
                sy1 := Max(cy - localSearchSize, 0)
                sx2 := Min(cx + localSearchSize, x2)
                sy2 := Min(cy + localSearchSize, y2)

                if (sx1 <= sx2 && sy1 <= sy2) {
                    fpFound := ImageSearch(&fpPx, &fpPy, sx1, sy1, sx2, sy2, "*" this.primaryAnchorTolerance " " this.folder "anchor.png"
                    )
                }
                if (fpFound && debug) {
                    ToolTip "Fingerprint anchor (cached)!", fpPx + 10, fpPy, 18
                }
            }
        } catch {
            cachedFingerprintAnchor := 0 ; Reset cache on error to prevent repeated failures
        }

        ; if not found, scan the full region (ImageSearch)
        if (!fpFound) {
            fpFound := ImageSearch(&fpPx, &fpPy, x1, y1, x2, y2, "*" this.primaryAnchorTolerance " " this.folder "anchor.png"
            )
            if (fpFound && debug) {
                ToolTip "[class] Fingerprint anchor found!", fpPx + 10, fpPy, 18
            }
        }

        if (fpFound) {
            this.prevFoundPixel := { x: fpPx, y: fpPy }
            cachedFingerprintAnchor := this.prevFoundPixel
            this.foundAnchor := true
            this.lastFoundTick := A_TickCount
            return { x: fpPx, y: fpPy }
        } else {
            this.prevFoundPixel := 0
            cachedFingerprintAnchor := 0
            this.foundAnchor := 0
            if (debug) {
                ToolTip "No anchors found (fp)", 0, 0, 18
                ; Sleep 500
            }
            return false
        }
    }

    /**
     * Scans for anchor group images and updates the anchorGroup property if found.
     * Handles timeout and status updates if no anchor is found within the allowed time.
     * @returns {Array} The detected anchor group or empty array if not found.
     */
    DetectAnchorGroup() {
        static lastFoundPrintGroup := 0

        static x1 := 0.5 * A_ScreenWidth
        static y1 := 0.1 * A_ScreenHeight
        static x2 := 0.7 * A_ScreenWidth
        static y2 := 0.35 * A_ScreenHeight

        this.anchorGroup := []
        static timeoutMs := 10000

        if (A_TickCount - lastFoundPrintGroup < 2000 && this.anchorGroup.Length > 0 || !this.foundAnchor) {
            return this.anchorGroup
        }

        lastFoundPrintGroup := A_TickCount

        modeText := this.mode == "idle" ? "Fingerprint script idle" : this.mode == "manual" ? "Manual mode" :
            "Hacking"

        anchorFiles := [
            [this.folder "1-4.png", [1, 2, 3, 4]],
            [this.folder "5-8.png", [5, 6, 7, 8]],
            [this.folder "9-12.png", [9, 10, 11, 12]],
            [this.folder "13-16.png", [13, 14, 15, 16]]
        ]

        for i, pair in anchorFiles {
            file := pair[1]
            group := pair[2]
            try {
                if ImageSearch(&Px, &Py, x1, y1, x2, y2, "*" this.anchorTolerance " " file) {

                    if (this.needStatusUpdate && this.foundAnchor) { ; update status only on first found print to avoid excessive updates
                        updateGlobalStatus(true, , , "CasinoFingerprint.DetectAnchorGroup()")
                        this.needStatusUpdate := false
                    }

                    this.lastSeenPrint := i
                    ToolTip("Found fingerprint " i, Round(x1 + ((x2 - x1) / 2) - (this.scrW * 0.04)), Round(
                        this.scrH / 2), 17)
                    this.anchorGroup := group
                    return group
                }
                else {
                    if (debug) {
                        ToolTip "⇲", x1, y1, 15 ; Debug: show search area top-left "." arrow / area
                        ToolTip "⇱", x2, y2, 16 ; Debug: show search area bottom-right "." arrow / area
                    }
                }
            } catch {
            }
        }
        return []
    }

    /**
     * Performs ImageSearch for a given fingerprint piece N in the specified region.
     * If found, increments counter and records the position.
     * @param {Integer} N - Piece number
     * @param {Number} XP1, YP1, XP2, YP2 - Search rectangle coordinates
     */
    Pmatch(N, XP1, YP1, XP2, YP2) {
        ; Guard: check all coordinates and N are numbers
        ; if !(IsNumber(XP1) && IsNumber(YP1) && IsNumber(XP2) && IsNumber(YP2) && IsNumber(N)) {
        ;     ToolTip("Invalid coordinates or N: " XP1 "," YP1 "," XP2 "," YP2 "," N, 100, 100, 18)
        ;     return
        ; }

        if ImageSearch(&FoundX, &FoundY, XP1, YP1, XP2, YP2, "*50 " this.folder N ".bmp"
        ) {
            try this.detected[N] := true
            this.Pos(FoundX, FoundY, N)
        } else {
            try this.detected[N] := false
            if this.pArr.Has(N)
                this.pArr.Delete(N)
            ToolTip("", , , N)
        }
    }

    /**
     * Converts found image coordinates to normalized ratios, 
     * to determine the position of the detected print.
     * 
     * Also displays debug ToolTips for visual feedback.
     * @param {Number} FoundX - Found X coordinate
     * @param {Number} FoundY - Found Y coordinate
     * @param {Integer} N - Piece number
     */
    Pos(FoundX, FoundY, N) {
        FoundX := FoundX / this.scrW
        FoundY := FoundY / this.scrH
        ; debug := false

        slot := ""

        if (FoundX >= 0.24 && FoundX <= 0.3) {
            if (FoundY >= 0.24 && FoundY <= 0.37)
                slot := 0
            else if (FoundY >= 0.37 && FoundY <= 0.5)
                slot := 2
            else if (FoundY >= 0.51 && FoundY <= 0.63)
                slot := 4
            else if (FoundY >= 0.64)
                slot := 6
        }
        else if (FoundX >= 0.305 && FoundX <= 0.4) {
            if (FoundY >= 0.24 && FoundY <= 0.32)
                slot := 1
            else if (FoundY >= 0.33 && FoundY <= 0.5)
                slot := 3
            else if (FoundY >= 0.51 && FoundY <= 0.63)
                slot := 5
            else if (FoundY >= 0.64)
                slot := 7
        }

        if (slot != "") {
            this.markPrint(slot, N)
            this.pArr[N] := slot
        } else if this.pArr.Has(N) {
            this.pArr.Delete(N)
        }

        if (debug)
            ToolTip "Tracked pieces: " this.pArr.Count, 50, 50, 19
    }

    markPrint(slot, N) {
        ; debug := false

        static slots := [{ x: 0.227, y: 0.293, arrow: "▶" }, { x: 0.389, y: 0.293, arrow: "◀" }, { x: 0.227, y: 0.426,
            arrow: "▶" }, { x: 0.389, y: 0.426, arrow: "◀" }, { x: 0.227, y: 0.561, arrow: "▶" }, { x: 0.389, y: 0.561,
                arrow: "◀" }, { x: 0.227, y: 0.695, arrow: "▶" }, { x: 0.389, y: 0.695, arrow: "◀" }
        ]

        slotData := slots[slot + 1]

        xOffset := N < 10 ? 0 : this.Adjust(-0.003, 0.9)

        lowResOffset := this.Adjust(-0.003, 1)
        lowResX := this.Adjust(0.2, 0.9) + lowResOffset

        if (A_ScreenWidth == 1366)
            lowResX := this.Adjust((N > 10 && !debug) ? 0.175 : 0.177, 0.9)

        tTipX := slotData.x * this.scrW

        ; apply low-res adjustment only to left-side arrows
        if (Mod(slot, 2) == 0)
            tTipX := ((this.lowRes ? lowResX : slotData.x) + (debug ? xOffset : 0.004)) * this.scrW

        tTipY := slotData.y * this.scrH

        text := debug
            ? (slotData.arrow == "▶"
                ? N " " slotData.arrow
                    : slotData.arrow " " N)
                : slotData.arrow

        ToolTip(text, tTipX, tTipY, N)
    }

    markPrints(prevArr, currArr) {
        if (prevArr == currArr)
            return

        this.prevPrints := currArr

        prevArr := StrSplit(prevArr, ",")
        currArr := StrSplit(currArr, ",")

        ; build lookup map for current values
        currMap := Map()
        for _, val in currArr {
            if (val != "")
                currMap[val] := true
        }

        ; remove marks that no longer exist
        for _, val in prevArr {
            if (val != "" && !currMap.Has(val)) {
                ToolTip("", , , val)
            }
        }

        ; add current marks
        for _, val in currArr {
            if (val != "") {
                slot := val - 1
                this.markPrint(slot, val)
            }
        }
    }

    /**
     * Selects the detected fingerprint positions by sending the appropriate key presses.
     * The logic is based on the relative positions of the detected prints to optimize the number of key presses.
     * It assumes that the prints are arranged in a grid and that the order of selection can
     * be determined by sorting the detected positions and comparing their indices.
     * @returns void
     */
    Select() {
        SetKeyDelay(this.delay, this.delay)

        positions := []
        seen := Map()
        for _, slot in this.pArr {
            if !seen.Has(slot) {
                seen[slot] := true
                positions.Push(slot)
            }
        }
        this.SortArray(positions)

        prev := 0
        for index, val in positions {
            if (this.mode == "manual") {
                ; Rebuild manual selection state each tick so auto handoff
                ; does not reuse accumulated positions from prior iterations.
                this.pArr := Map()
                return
            }
            ; Sleep 10
            times := val - prev
            ; ToolTip "Sending Down " times " times`npArr length: " this.pArr.Length, 50, 50, 19
            ; sleep 200
            if (Mod(times, 2) == 0) {
                times := times / 2
                if (times != 0) {
                    times := Floor(times)
                    Send "{Down " times "}"
                }
            } else {
                ; Sleep 10
                Send "{Right}"
                times := Floor(times / 2)
                if (times != 0) {
                    Send "{Down " times "}"
                }
            }

            Sleep 10
            Send "{Enter}"
            this.counter := this.counter - 1

            prev := val
        }
    }

    ; ===== OPENCV-SPECIFIC LOGIC =====

    openCVSelect(positions) {
        if (this.mode != "auto" || positions == "")
            return

        SetKeyDelay(this.delay, this.delay)
        ; MsgBox(positions)

        arr := StrSplit(positions, ",")

        if (arr.Length != 4)
            return

        prev := 0
        for _, val in arr {
            val := Integer(val) - 1  ; convert to 0–7

            times := val - prev

            if (Mod(times, 2) == 0) {
                times := times / 2
                if (times != 0)
                    Send "{Down " Floor(times) "}"
            } else {
                Send "{Right}"
                times := Floor(times / 2)
                if (times != 0)
                    Send "{Down " times "}"
            }

            Sleep 10
            Send "{Enter}"

            prev := val
        }

        Sleep 10
        Send "{Tab}"
        this.clearAll()
    }

    ; ===== HELPERS =====

    /**
     * Initializes the detected array to all false. 
     * Should be called at the start of each main loop iteration to reset the state for accurate detection and status updates.
     */
    InitDetected() {
        this.detected := []
        if this.pArr.Count > 4
            this.pArr := Map()
        loop 16
            this.detected.Push(false)
    }

    /**
     * Counts the number of true values in the detected array and updates the counter property.
     * Used to keep track of how many fingerprint pieces have been detected in the current loop iteration.
     * @returns {number} The count of detected pieces
     */
    updateCounter() {
        count := 0
        for _, v in this.detected
            if v
                count++
        this.counter := count
        return count
    }

    ; Sorts pArr based on the detected postions to determine the order of selection.
    SortArray(arr) {
        for i, _ in arr {
            for j, _ in arr {
                if (j < arr.Length && arr[j] > arr[j + 1]) {
                    temp := arr[j]
                    arr[j] := arr[j + 1]
                    arr[j + 1] := temp
                }
            }
        }

    }

    ; Adjust a value by the scale factor.
    ; Used to adjust offsets for smaller resolutions to avoid overlapping of tooltips over the prints.
    Adjust(val, strength := 1) {
        return val + (val * (this.scale - 1) * strength)
    }

    /**
     * Clears all tooltips (1 to 19)
     */
    clearAll() {
        this.anchorGroup := []
        loop 19
            ToolTip("", , , A_Index)
    }

}
