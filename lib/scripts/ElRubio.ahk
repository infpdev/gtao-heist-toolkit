; class start
; DO NOT REMOVE THE ABOVE LINE - REQUIRED TO AUTOMATE BUILDING OF CLASSES AS STANDALONE SCRIPTS
/**
 * @description El Rubio solver class.
 * Handles anchor detection, fingerprint grouping, traversal, and solving in the Cayo Perico heist.
 * 
 * ### FLOW:
 * ```text
 * Hack()/ManualMode() → findAnchor()/tryOpenCV() → start MainLoop(timer)
 * 
 * MainLoop():
 *   findAnchor()              ; validate UI / anchor (loss → ResetState)
 *   if useOpenCv/highRes:
 *     tryOpenCV()             ; OpenCV anchor → REQ_CAYO → solveOpenCV()/showOpenCVClicks()
 *     → if OpenCV fails and 
 *   fallback is allowed, 
 *   continue with AHK flow
 * 
 *   getFingerprintGroup()     ; detect print (fail → return)
 *   obviousReturn()           ; guard (invalid state → return)
 *   FindElRing()              ; get current row (fail → return)
 * 
 *   findPrintInRow()          ; traverse (align segment)
 *     isPrintInRow()          ; cached → fallback search
 * 
 *   Solve() / Send Down       ; solve or skip row
 *   moveToRow(nextRow)        ; advance
 * 
 *   if all solved → ResetState()
 * 
 * Destroy()/Idle() → stop + clear state
 * ```
 * 
 * ### Pipeline:
 * OpenCV / Anchor → Solve (OpenCV) / Row → Print Group → Print in Row → Solve → Next Row
 */
class ElRubioSolver {

    mode := "idle"
    scrW := A_ScreenWidth
    scrH := A_ScreenHeight

    counter := 0
    delay := 0
    lastSeenPrint := 0
    lastFoundTick := 0
    prevFoundPixel := 0
    cachedCursorRow := 0
    prevClicks := ""

    x1 := A_ScreenWidth * 0.27
    y1 := A_ScreenHeight * 0.33
    x2 := A_ScreenWidth * 0.38
    y2 := A_ScreenHeight * 0.88

    printTolerance := 100 * (1080 / A_ScreenHeight) ** 0.7
    primaryAnchorTolerance := 10
    baseW := 1920
    scale := 1

    traversed := Map()
    solved := Map()

    needStatusUpdate := true
    foundAnchor := false
    isBusy := false
    isChangingPrint := false
    isShuttingDown := false
    highRes := false
    useOpenCv := false
    shouldAbort := false
    autoStarted := false

    lowRes := (A_ScreenWidth == 1366 && A_ScreenHeight == 768) || (A_ScreenWidth == 1600 && A_ScreenHeight == 900)

    __New(delay, resetHackMode, updateGlobalStatus, prevFoundPixel := 0, folderPath := "", highRes := false, engine :=
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

        this.Idle()
    }

    /**
     * Sets the key delay for input. Used by the main script to configure the solver's input timing.
     * @param {number} delayMs - Delay in milliseconds
     * @returns {void}
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
        this.useOpenCv := engine == OPENCV_ENGINE
    }

    /**
     * Sets the solver to idle mode, clears tooltips and resets the state.
     * @returns {void}
     */
    Idle() {
        this.isShuttingDown := false
        this.clearAll()
        this.traversed.Clear()
        this.solved.Clear()
        this.mode := "idle"
        this.isBusy := false
        this.lastSeenPrint := 0
        this.prevClicks := ""
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        updateGlobalStatus(false)
    }

    /**
     * Cleans up solver state, tooltips, and timers. Call before deleting instance or switching heist.
     * @returns {void}
     */
    Destroy() {
        this.isShuttingDown := true
        this.shouldAbort := true
        this.mode := "idle"
        this.traversed.Clear()
        this.solved.Clear()
        this.lastSeenPrint := 0
        this.lastFoundTick := 0
        this.foundAnchor := false
        this.isBusy := false
        this.isChangingPrint := false
        try SetTimer this.fnMainLoop, 0
        try SetTimer this.fnCheckFalsePositive, 0
        if (debug)
            ToolTip "El Rubio solver destroyed", 0, 0, 18
        this.clearAll()
        ResetHackMode()
    }

    /**
     * Starts manual mode with the given anchor pixel coordinates, bypassing the initial anchor search.
     * For this class, this func immediately starts auto-selecting since there is no "manual mode" feature.
     * Called when the main script auto-detects one of the anchor pixels.
     * @param {object} anchorPixelCoords - Anchor pixel coordinates
     */
    autoStartManual(anchorPixelCoords) {
        this.autoStarted := true
        if (this.isShuttingDown)
            return
        this.autoStarted := true
        this.prevFoundPixel := anchorPixelCoords
        this.foundAnchor := true
        this.Hack(true)

        SetTimer () => (this.CheckFalsePositive()), -5000
    }

    /**
     * Checks for false positives and resets if anchor is lost during auto-start.
     */
    CheckFalsePositive() {
        if (this.isShuttingDown || this.mode != "auto" || !this.autoStarted)
            return
        if (!this.foundAnchor) {
            ResetHackMode()
            this.Idle()
        }
    }

    /**
     * Switches solver to manual mode. For this class, manual mode does nothing except allow PgUp hotkey.
     */
    SwitchToManual() {
        if (this.autoStarted)
            this.autoStarted := false

        if (this.mode == "manual")
            return
        this.ResetState()
        this.foundAnchor := false
        this.mode := "manual"
        SetTimer this.fnMainLoop, 0
        this.findAnchor()
        this.getFingerprintGroup()
        SetTimer this.fnMainLoop, 500
        updateGlobalStatus(false)
    }

    /**
     * Main entrypoint: starts the automated solve loop. Call to begin solving.
     */
    Hack(autoStart := false, *) {
        if (this.autoStarted && !autoStart)
            this.autoStarted := false

        if (this.isShuttingDown)
            return
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        this.mode := "auto"
        this.isChangingPrint := false
        this.lastFoundTick := 0
        updateGlobalStatus(this.foundAnchor)
        this.findAnchor()
        SetTimer this.fnMainLoop, 200
    }

    /**
     * Attempts to detect fingerprints using OpenCV methods.
     * Returns true if OpenCV detection succeeded and handled the detection logic, false otherwise.
     * @returns {boolean}
     */
    tryOpenCV() {
        if (!this.useOpenCv)
            return false

        try {
            this.foundAnchor := GetResFromOpenCV(ANCHOR_CAYO)
            ; MsgBox this.foundAnchor
            if (!this.foundAnchor || this.foundAnchor == ERRMSG) {
                this.foundAnchor := false
                this.needStatusUpdate := true
                this.prevFoundPixel := 0
                this.needStatusUpdate := true
                this.prevClicks := ""
                return false
            }
            this.lastFoundTick := A_TickCount

            res := GetResFromOpenCV(REQ_CAYO)
            if (res = ERRMSG || res = "" || !res) {
                return false
            }

            if (this.needStatusUpdate) {
                updateGlobalStatus(true)
                this.needStatusUpdate := false
            }

            cayoResult := this.parseOpenCayoResult(res)
            if (!IsObject(cayoResult))
                return false

            cursorRow := cayoResult.row
            clicks := cayoResult.clicks

            if (this.mode == "auto")
                this.solveOpenCV(cursorRow, clicks)
            else {
                ; manually show a tooltip showing the number of clicks (left or right) based on the result.
                if (cayoResult.clicksKey != this.prevClicks) {
                    this.prevClicks := cayoResult.clicksKey
                    this.showOpenCVClicks(clicks)
                }
            }
            this.autoStarted := false ; Reset autoStarted flag since it can't be a false positive if we got a valid OpenCV result
            return true
        } catch {
            return false
        }
    }

    /**
     * Main solver loop. Called by timer, not usually called directly.
     * Flow: Finds the anchor and print group, then solves the puzzle row-by-row.
     * If the anchor is lost, starts a timeout and waits for it to be found again before resuming.
     * If the anchor is not found within the timeout, resets the state and waits for the next anchor detection to resume solving.
     */
    MainLoop() {
        static maxRows := 8
        static AltImage := 2
        forAlt := false

        if (this.isShuttingDown && debug) {
            if (debug)
                ToolTip "MainLoop: Shutting down, exiting loop", 0, 0, 18
            Sleep 1000
            return
        }

        if (this.isBusy)
            return
        this.isBusy := true

        this.checkTimeout()

        try {
            ; Try OpenCV detection if enabled, fallback to AHK only if highRes is false
            cvWorked := this.tryOpenCV()

            if (cvWorked) {
                this.isBusy := false
                return
            }

            if (this.highRes) {
                ; OpenCV failed, but fallback is not allowed
                this.isBusy := false
                return
            }

            this.findAnchor()

            fpGroupID := this.getFingerprintGroup()
            if (!this.foundAnchor || !fpGroupID || this.isChangingPrint) {
                this.isBusy := false
                return
            }

            if (this.obviousReturn()) {
                this.isBusy := false
                return
            }

            this.autoStarted := false ; Reset autoStarted flag since we got a valid anchor
            ;  and print group, so it can't be a false positive
            row := this.FindElRing()
            if (row = -1) {
                this.isBusy := false
                return
            }

            ; STEP 1: TRAVERSE (only if needed)
            if !this.traversed.Has(row) {
                print := this.findPrintInRow(row, fpGroupID)
                if (print) {
                    this.traversed[row] := true
                    ; if print is alt image, set forAlt to true for the solve step
                    if (print == AltImage) {
                        forAlt := true
                    } else {
                        forAlt := false
                    }
                } else {
                    ; couldn't align yet → try next tick
                    this.isBusy := false
                    return
                }

            }

            ; STEP 2: SOLVE (same row)

            isCorrect := (!forAlt && row == 1) || (forAlt && row == 5)

            if (!isCorrect && !this.solved.Has(row) && this.traversed.Has(row)) {

                if this.Solve(row, fpGroupID, forAlt) {
                    this.solved[row] := true
                } else {
                    ToolTip "Solve failed row " row, 0, 200, 19
                    this.isBusy := false
                    return
                }
            } else {
                if (debug) {
                    ToolTip "skipped row 1", 0, 0, 18
                    sleep 100
                }
                Send "{Down}"
                sleep 10
            }

            ; STEP 3: MOVE NEXT
            nextRow := row + 1
            if (nextRow > maxRows)
                nextRow := 1

            this.moveToRow(nextRow)

            if (this.solved.Count >= 8)
                this.ResetState()

        } finally {
            this.isBusy := false
        }
    }

    checkTimeout() {
        if (!this.foundAnchor && this.lastFoundTick != 0 && (this.mode == "auto" || this.useOpenCv || this.highRes)) {
            this.clearAll()
            this.needStatusUpdate := true
            timeLeft := Integer((10000 - (A_TickCount - this.lastFoundTick)) / 1000) + 1
            updateGlobalStatus(false, true, timeLeft)
            if (A_TickCount - this.lastFoundTick > 10000) {
                ResetHackMode()
                this.Idle()
            }
        }

    }

    /**
     * Searches for the El Rubio anchor image on screen. Updates state and returns anchor position if found.
     * @returns {object|boolean} {x, y} if found, false otherwise.
     */
    findAnchor() {
        global cachedRubioAnchor

        static timeoutMs := 10000
        static lastCalled := 0

        static localSearchSize := 20

        static x1 := A_ScreenWidth * 0.48
        static y1 := A_ScreenHeight * 0.1
        static x2 := A_ScreenWidth * 0.59
        static y2 := A_ScreenHeight * 0.11

        if (this.highRes) {
            ; For high res, we rely on OpenCV and skip the AHK image search entirely
            return
        }

        now := A_TickCount
        if (now - lastCalled < 1000 && this.prevFoundPixel && !this.isChangingPrint) {
            return this.prevFoundPixel
        }

        lastCalled := now

        elFound := false
        fpPx := 0, fpPy := 0

        try {
            ; Always try prevFoundPixel region first if available
            if (IsObject(this.prevFoundPixel) && this.prevFoundPixel.x != 0 && this.prevFoundPixel.y != 0) {
                cx := this.prevFoundPixel.x, cy := this.prevFoundPixel.y
                sx1 := Max(cx - localSearchSize, 0)
                sy1 := Max(cy - localSearchSize, 0)
                sx2 := Min(cx + localSearchSize, x2)
                sy2 := Min(cy + localSearchSize, y2)

                if (sx1 <= sx2 && sy1 <= sy2) {
                    elFound := ImageSearch(&fpPx, &fpPy, sx1, sy1, sx2, sy2, "*" this.primaryAnchorTolerance " " this.folder "elAnchor.png"
                    )
                }
            }
        } catch {
            cachedRubioAnchor := 0 ; Reset cache on error to prevent repeated failures
        }

        ; If not found, fall back to full region
        if (!elFound) {
            elFound := ImageSearch(&fpPx, &fpPy, x1, y1, x2, y2, "*" this.primaryAnchorTolerance " " this.folder "elAnchor.png"
            )
        }

        if (elFound) {
            if (debug) {
                ToolTip("EL RUBIO ANCHOR", fpPx + 100, fpPy, 18)
            }

            if (this.needStatusUpdate) {
                updateGlobalStatus(true)
                this.needStatusUpdate := false
            }

            this.prevFoundPixel := { x: fpPx, y: fpPy }
            cachedRubioAnchor := { x: fpPx, y: fpPy }
            this.foundAnchor := true
            this.lastFoundTick := A_TickCount
            this.isChangingPrint := false

            return { x: fpPx, y: fpPy }
        } else {
            cachedRubioAnchor := 0
            this.prevFoundPixel := 0
            this.foundAnchor := 0
            if (debug) {
                ToolTip "EL RUBIO anchor not found", 0, 0, 18
            }

            if (this.lastSeenPrint != 0 && this.lastFoundTick != 0) {
                if (debug)
                    ToolTip "EL RUBIO anchor lost! Last seen print group: " this.lastSeenPrint, 0, 0, 18
                if (!this.isChangingPrint)
                    this.ResetState()
                this.isChangingPrint := true
                this.needStatusUpdate := true

            }

            return false
        }
    }

    /**
     * Detects which fingerprint group is currently visible (internal helper).
     * @returns {number|boolean} Group index if found, false otherwise.
     */
    getFingerprintGroup() {
        static lastCalled := 0

        static x1 := 0.57 * A_ScreenWidth
        static y1 := 0.324 * A_ScreenHeight
        static x2 := 0.715 * A_ScreenWidth
        static y2 := 0.42 * A_ScreenHeight

        if (!this.foundAnchor || this.highRes)
            return false

        now := A_TickCount
        if (now - lastCalled < 2000 && this.lastSeenPrint) {
            return this.lastSeenPrint
        }

        this.fpGroup := []
        lastCalled := now
        foundPrint := 0
        Px := 0, Py := 0

        if (debug) {
            ToolTip "⇲", x1, y1 - 20, 1
            ToolTip "⇱", x2, y2 + 20, 1
        }

        loop 7 {
            idx := A_Index
            file := this.folder "rPrint" idx ".png"
            try {
                if ImageSearch(&Px, &Py, x1, y1, x2, y2, "*" this.printTolerance " " file) {
                    foundPrint := idx
                    this.lastSeenPrint := idx

                    this.shouldAbort := false

                    ToolTip("Found Fingerprint print " idx, (x1 + x2) / 2 - 20, this.scrH // 2, 16)

                    this.fpGroup := idx
                    this.isChangingPrint := false
                    return idx
                }
            } catch {
            }
        }
        this.shouldAbort := true
        return false
    }

    /**
     * Attempts to solve the given row by sending the correct number of right/left key presses to align, then sends down to move to the next row.
     * @param {number} row - Row index (1-8)
     * @param {number} fpGroupID - Fingerprint group ID
     * @returns {boolean} True if solved, false otherwise.
     */
    Solve(row, fpGroupID, withRespectToAlt := false) {
        SetKeyDelay(this.delay, this.delay)

        if (this.obviousReturn() || this.highRes)
            return false

        if (!this.traversed.Has(row)) {
            ToolTip "Cannot solve row " row " without traversing first!", 0, 0, 19
            sleep 1000
            return false
        }

        ; Step 1: Move to correct segment using smart clicks (circular)
        base := withRespectToAlt ? 5 : 1
        offset := Mod(row - base + 8, 8)

        if (offset <= 4) {
            if (offset > 0)
                Send "{Right " offset "}"
        } else {
            Send "{Left " (8 - offset) "}"
        }

        Sleep 10
        Send "{Down}"
        sleep 10

        return true
    }

    ; ===== OPENCV-SPECIFIC LOGIC =====

    /**
     * Solves the fingerprint puzzle using OpenCV detection results.
     * @param cursorRow {number} The current cursor row.
     * @param clicks {array} The list of clicks to apply.
     */
    solveOpenCV(cursorRow, clicks) {
        SetKeyDelay(this.delay, this.delay)

        if (this.obviousReturn())
            return

        ; move current cursor to row 1 first
        if (cursorRow > 1)
            Send "{Up " (cursorRow - 1) "}"

        Sleep 10

        for row, offset in clicks {
            if (this.obviousReturn())
                return

            ; apply rotation
            if (offset > 0) {
                Send "{Right " offset "}"
            }
            else if (offset < 0) {
                Send "{Left " Abs(offset) "}"
            }

            Sleep 10

            ; move next row (except last)
            if (row < clicks.Length) {
                Send "{Down}"
                Sleep 10
            }
        }
    }

    /**
     * Parses the OpenCV Cayo response into row/click data.
     * Expected JSON shape: {"row": <number>, "clicks": [<numbers>...]}
     * @param {string} res - Raw response from the helper
     * @returns {object|false}
     */
    parseOpenCayoResult(res) {
        try {
            if !RegExMatch(res, '"row"\s*:\s*(-?\d+)', &rowMatch)
                return false

            if !RegExMatch(res, '"clicks"\s*:\s*\[(.*?)\]', &clicksMatch)
                return false

            clicks := []
            rawClicks := Trim(clicksMatch[1])
            if (rawClicks != "") {
                for _, v in StrSplit(rawClicks, ",") {
                    v := Trim(v)
                    if (v = "")
                        continue
                    clicks.Push(Integer(v))
                }
            }

            if (clicks.Length != 8)
                return false

            clicksKey := ""
            for _, v in clicks
                clicksKey .= v ","

            return { row: Integer(rowMatch[1]), clicks: clicks, clicksKey: clicksKey }
        } catch {
            return false
        }
    }

    ; ===== HELPERS =====

    /**
     * Searches for the El Rubio ring on screen and returns the detected row index (1-8), or -1 if not found.
     * @returns {number} Integer row index (1-8) or -1.
     */
    FindElRing() {
        static x1 := A_ScreenWidth * 0.199
        static y1 := A_ScreenHeight * 0.323
        static x2 := A_ScreenWidth * 0.202
        static y2 := A_ScreenHeight * 0.891

        if (this.highRes) {
            ; For high res, we rely on OpenCV and skip the AHK image search entirely
            return
        }

        fx := 0, fy := 0
        if !ImageSearch(&fx, &fy, x1, y1, x2, y2, "*50 " this.folder "elRing.png")
            return -1
        row := this.Pos(fx, fy, -1)
        this.cachedCursorRow := row
        return row
    }

    /**
     * Moves cursor to the given row index (1-8) using the shortest path (circular). Only sends input if needed.
     * @param {number} targetRow - Target row index (1-8)
     * @returns {void}
     */
    moveToRow(targetRow) {

        if (this.highRes) {
            ; For high res, we rely on OpenCV and skip the AHK image search entirely
            return
        }

        SetKeyDelay(this.delay, this.delay)
        currentRow := this.FindElRing()
        if (currentRow == -1 || this.obviousReturn())
            return

        maxRows := 8

        ; forward distance (Down)
        downSteps := Mod(targetRow - currentRow + maxRows, maxRows)

        ; backward distance (Up)
        upSteps := Mod(currentRow - targetRow + maxRows, maxRows)

        if (downSteps <= upSteps) {
            if (downSteps > 0)
                Send "{Down " downSteps "}"
        } else {
            if (upSteps > 0)
                Send "{Up " upSteps "}"
        }

        Sleep 10
    }

    /**
     * Attempts to find the print in the given row.
     * If not found, sends right key up to 16 times to try to find it in the next segment, then gives up until next tick.
     * @param {number} row - Row index (1-8)
     * @param {number} fpGroupID - Fingerprint group ID
     * @returns {boolean} True if found, false otherwise.
     */
    findPrintInRow(row, fpGroupID) {
        static AltImage := 2

        SetKeyDelay(this.delay, this.delay)
        if this.obviousReturn() || this.highRes
            return false
        maxTries := 16
        tries := 0
        while (tries < maxTries) {
            if (this.obviousReturn())
                return false
            if (debug)
                ToolTip "IN ROW " row " TRY " tries, (this.scrW / 2) - 20, 0, 19
            print := this.isPrintInRow(fpGroupID, row)
            if (print) {
                if (debug)
                    ToolTip "", , , 19
                if (print == AltImage) {
                    return 2
                }
                else {
                    return true
                }
            }
            Send "{Right}"
            Sleep 10
            tries++
        }
        return false
    }

    /**
     * Checks if the print is present in the given row by searching for the print image in the row's region.
     * Uses a simple static cache to check the last found position first for faster detection, with a fallback to searching the entire row region if the cache check fails.
     * @param {number} fpGroupID - Fingerprint group ID
     * @param {number} row - Row index (1-8)
     * @returns {boolean} True if found, false otherwise.
     */
    isPrintInRow(fpGroupID, row) {
        static cachedPrint := false, failCount := 0

        if (this.obviousReturn() || this.highRes)
            return false

        totalRects := 8
        yRadius := (15 / 1080) * this.scrH
        baseY := this.y1
        gapH := 10 / 1080 * this.scrH
        rectH := (65 / 1080) * this.scrH

        y1 := baseY + (row - 1) * (rectH + gapH) - yRadius
        y2 := y1 + rectH + yRadius
        x1 := this.x1
        x2 := this.x2
        Px := 0, Py := 0

        file := this.folder "r" fpGroupID ".png"
        file2 := this.folder "r" fpGroupID "a.png"
        altFileExists := FileExist(file2)

        ; Fallback to full region
        if (debug) {
            ToolTip "row " row "⇲", x1, y1 - 20, 11
            ToolTip "⇱ row " row, x2, y2 + 20, 12
        }
        if ImageSearch(&Px, &Py, x1, y1, x2, y2, "*" this.printTolerance " " file) {
            if (debug) {
                ToolTip "Found print " fpGroupID " in row " row, Px + 20, Py - 50, 18
                sleep 100
            }
            cachedPrint := { x: Px, y: Py, row: row, fp: fpGroupID }
            failCount := 0
            return true
        } else {
            if altFileExists && ImageSearch(&Px, &Py, x1, y1, x2, y2, "*" this.printTolerance " " file2) {
                if (debug) {
                    ToolTip "Found print alt " fpGroupID " in row " row, Px + 20, Py - 50, 18
                    sleep 100
                }
                failCount := 0
                return 2
            }
            if (failCount >= 8)
                failCount := 0
        }
        return false
    }

    /**
     * Calculates the row index for a given Y coordinate (internal helper).
     * @param {number} FoundX - X coordinate
     * @param {number} FoundY - Y coordinate
     * @param {number} N - Not used (for compatibility)
     * @returns {number} Row index (1-8) or -1 if not in region.
     */
    Pos(FoundX, FoundY, N) {
        static totalRects := 8
        static baseY := 0.323
        static endY := 0.891
        static gapH := 10 / 1080
        static rectH := 65 / 1080

        FoundYr := FoundY / this.scrH
        regionH := endY - baseY

        idx := -1
        loop totalRects {
            n := A_Index - 1
            top := baseY + n * (rectH + gapH)
            bottom := top + rectH

            if (FoundYr >= top && FoundYr < bottom) {
                idx := n
                break
            }
        }
        if (idx = -1)
            return -1

        tTipX := this.scrW * 0.201
        tTipY := this.scrH * (baseY + idx * (rectH + gapH) + rectH / 2)
        idx += 1
        ToolTip("◎", tTipX + 2, tTipY, 15)
        return idx
    }

    /**
     * Displays OpenCV click positions on the screen.
     * @param clicks 
     */
    showOpenCVClicks(clicks) {
        static baseY := 0.323
        static gapH := 10 / 1080
        static rectH := 65 / 1080

        x := this.scrW * 0.15

        ; clear old tooltips
        loop 8
            ToolTip("", , , A_Index)

        for row, offset in clicks {
            if (this.isShuttingDown)
                return

            y := this.scrH * (baseY + (row - 1) * (rectH + gapH) + rectH / 2)

            if (offset > 0) {
                txt := offset " Right"
            }
            else if (offset < 0) {
                txt := Abs(offset) " Left"
            }
            else {
                txt := "Aligned"
            }

            ToolTip(
                txt,
                x,
                y,
                row
            )
        }
        if (this.isShuttingDown)
            this.clearAll()
    }

    /**
     * Returns true if the solver should exit early due to state (anchor lost, changing print, not auto, or shutting down).
     * @returns {boolean}
     */
    obviousReturn() {
        return (!this.foundAnchor || this.isChangingPrint || this.mode != "auto" || this.isShuttingDown)
    }

    /**
     * Resets solver state, tooltips, and caches. Called when all rows are solved or anchor is lost.
     * @returns {void}
     */
    ResetState() {
        this.clearAll()
        if (debug)
            ToolTip "All rows solved / lost anchor", 0, 0, 18
        this.traversed.Clear()
        this.solved.Clear()
        this.foundAnchor := false
        this.needStatusUpdate := true
        this.prevClicks := ""
    }

    /**
     * Clears all tooltips (1 to 19).
     */
    clearAll() {
        this.fpGroup := []
        loop 19
            ToolTip("", , , A_Index)
    }
}
