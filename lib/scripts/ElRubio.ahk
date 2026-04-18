; class start
; DO NOT REMOVE THE ABOVE LINE - REQUIRED TO AUTOMATE BUILDING OF CLASSES AS STANDALONE SCRIPTS
/**
 * @description El Rubio solver class.
 * Handles anchor detection, fingerprint grouping, traversal, and solving in the Cayo Perico heist.
 * 
 * ### FLOW:
 * ```text
 * Hack() → findAnchor() → start MainLoop(timer)
 * 
 * MainLoop():
 *   findAnchor()          ; validate UI (loss → ResetState)
 *   getFingerprintGroup() ; detect print (fail → return)
 *   obviousReturn()       ; guard (invalid state → return)
 *   FindElRing()          ; get current row (fail → return)
 * 
 *   findPrintInRow()      ; traverse (align segment)
 *     isPrintInRow()      ; cached → fallback search
 * 
 *   Solve() / Send Down   ; solve or skip row
 *   moveToRow(nextRow)    ; advance
 * 
 *   if all solved → ResetState()
 * 
 * Destroy()/Idle() → stop + clear state
 * ```
 * 
 * ### Pipeline:
 * Anchor → Row → Print Group → Print in Row → Solve → Next Row
 */
class ElRubioSolver {

    folder := A_ScriptDir "\" A_ScreenWidth "x" A_ScreenHeight "\"
    mode := "idle"
    scrW := A_ScreenWidth
    scrH := A_ScreenHeight

    counter := 0
    delay := 0
    lastSeenPrint := 0
    lastFoundTick := 0
    prevFoundPixel := 0
    cachedCursorRow := 0

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
    shouldAbort := false

    lowRes := (A_ScreenWidth == 1366 && A_ScreenHeight == 768) || (A_ScreenWidth == 1600 && A_ScreenHeight == 900)

    __New(delay, resetHackMode, updateGlobalStatus, prevFoundPixel := 0, folderPath := "") {
        SetKeyDelay delay, delay
        this.delay := delay
        this.prevFoundPixel := prevFoundPixel
        this.fnMainLoop := ObjBindMethod(this, "MainLoop")
        this.fnFindAnchor := ObjBindMethod(this, "findAnchor")
        this.fnCheckFalsePositive := ObjBindMethod(this, "CheckFalsePositive")
        this.scale := (this.baseW / this.scrW) ** 0.7

        this.folder := folderPath != "" ? folderPath : this.folder

        this.Idle()
    }

    /**
     * Cleans up solver state, tooltips, and timers. Call before deleting instance or switching heist.
     * @returns {void}
     */
    Destroy() {
        this.isShuttingDown := true
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
     * Sets the key delay for input. Used by the main script to configure the solver's input timing.
     * @param {number} delayMs - Delay in milliseconds
     * @returns {void}
     */
    setKeyDelay(delayMs) {
        this.delay := delayMs
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
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        updateGlobalStatus(false)
    }

    /**
     * Clears all tooltips (1 to 19).
     */
    clearAll() {
        this.fpGroup := []
        loop 19
            ToolTip("", , , A_Index)
    }

    /**
     * Starts manual mode with the given anchor pixel coordinates, bypassing the initial anchor search.
     * For this class, this func immediately starts auto-selecting since there is no "manual mode" feature.
     * Called when the main script auto-detects one of the anchor pixels.
     * @param {object} anchorPixelCoords - Anchor pixel coordinates
     */
    autoStartManual(anchorPixelCoords) {
        if (this.isShuttingDown)
            return
        this.prevFoundPixel := anchorPixelCoords
        this.foundAnchor := true
        this.Hack()

        SetTimer () => (this.CheckFalsePositive()), -5000
    }

    /**
     * Checks for false positives and resets if anchor is lost during auto-start.
     */
    CheckFalsePositive() {
        if (this.isShuttingDown || this.mode != "auto")
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
        if (this.mode == "manual")
            return
        this.ResetState()
        this.foundAnchor := false
        this.mode := "manual"
        SetTimer this.fnMainLoop, 0
        this.findAnchor()
        this.getFingerprintGroup()
        this.MainLoop()
        SetTimer this.fnMainLoop, 500
        updateGlobalStatus(hackInProgress)
    }

    /**
     * Main entrypoint: starts the automated solve loop. Call to begin solving.
     */
    Hack(*) {
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
            this.findAnchor()

            fpGroupID := this.getFingerprintGroup()
            if (!this.foundAnchor || !fpGroupID || this.isChangingPrint) {
                return
            }

            if (this.obviousReturn()) {
                this.isBusy := false
                return
            }
            row := this.FindElRing()
            if (row = -1)
                return

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

    ; Moves cursor to the given row index (1-8) using the shortest path (circular). Only sends input if needed.
    /**
     * Moves cursor to the given row index (1-8) using the shortest path (circular). Only sends input if needed.
     * @param {number} targetRow - Target row index (1-8)
     * @returns {void}
     */
    moveToRow(targetRow) {

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
        if this.obviousReturn()
            return false
        maxTries := 16
        tries := 0
        while (tries < maxTries) {
            if (this.shouldAbort)
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

        if (this.obviousReturn())
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

        ; Try cached position first (same row + print), up to 8 misses before full fallback
        ; if (IsObject(cachedPrint)
        ; && cachedPrint.row = row
        ; && cachedPrint.fp = fpGroupID
        ; && failCount < 8) {
        ;     localRadius := 5
        ;     sx1 := Max(Round(cachedPrint.x - localRadius), Round(x1))
        ;     sy1 := Max(Round(cachedPrint.y - localRadius), Round(y1))
        ;     sx2 := Min(Round(cachedPrint.x + localRadius), Round(x2))
        ;     sy2 := Min(Round(cachedPrint.y + localRadius), Round(y2))

        ;     try {
        ;         if ImageSearch(&Px, &Py, sx1, sy1, sx2, sy2, "*" this.printTolerance " " file) {
        ;             if (debug) {
        ;                 ToolTip "Found print (cached) " fpGroupID " in row " row, Px + 20, Py - 50, 18
        ;                 sleep 100
        ;             }
        ;             cachedPrint := { x: Px, y: Py, row: row, fp: fpGroupID }
        ;             failCount := 0
        ;             return true
        ;         } else {
        ;             failCount += 1
        ;         }
        ;     }
        ; }

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
     * Returns true if the solver should exit early due to state (anchor lost, changing print, not auto, or shutting down).
     * @returns {boolean}
     */
    obviousReturn() {
        return (!this.foundAnchor || this.isChangingPrint || this.mode != "auto" || this.isShuttingDown)
    }

    /**
     * Attempts to solve the given row by sending the correct number of right/left key presses to align, then sends down to move to the next row.
     * @param {number} row - Row index (1-8)
     * @param {number} fpGroupID - Fingerprint group ID
     * @returns {boolean} True if solved, false otherwise.
     */
    Solve(row, fpGroupID, withRespectToAlt := false) {
        SetKeyDelay(this.delay, this.delay)

        if (this.obviousReturn())
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

    ; Detects which fingerprint group is currently visible (internal helper).
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

        if (!this.foundAnchor)
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
     * Searches for the El Rubio anchor image on screen. Updates state and returns anchor position if found.
     * @returns {object|boolean} {x, y} if found, false otherwise.
     */
    findAnchor() {
        static timeoutMs := 10000
        static lastCalled := 0

        static x1 := A_ScreenWidth * 0.48
        static y1 := A_ScreenHeight * 0.1
        static x2 := A_ScreenWidth * 0.59
        static y2 := A_ScreenHeight * 0.11
        static localSearchSize := 5

        now := A_TickCount
        if (now - lastCalled < 1000 && this.prevFoundPixel && !this.isChangingPrint) {
            return this.prevFoundPixel
        }

        lastCalled := now

        elFound := false
        fpPx := 0, fpPy := 0

        ; Always try prevFoundPixel region first if available
        if (this.prevFoundPixel && this.prevFoundPixel.x != 0 && this.prevFoundPixel.y != 0) {
            cx := this.prevFoundPixel.x, cy := this.prevFoundPixel.y
            sx1 := Max(cx - localSearchSize, 0)
            sy1 := Max(cy - localSearchSize, 0)
            sx2 := Min(cx + localSearchSize, this.scrW)
            sy2 := Min(cy + localSearchSize, this.scrH)
            elFound := ImageSearch(&fpPx, &fpPy, sx1, sy1, sx2, sy2, "*" this.primaryAnchorTolerance " " this.folder "elAnchor.png"
            )
        }

        ; If not found, fall back to full region
        if (!elFound) {
            elFound := ImageSearch(&fpPx, &fpPy, x1, y1, x2, y2, "*" this.primaryAnchorTolerance " " this.folder "elAnchor.png"
            )
        }
        ; ToolTip ".", x1, y1 - 20, 11
        ; ToolTip ".", x2, y2 + 20, 12
        if (elFound) {
            if (debug) {
                ToolTip("EL RUBIO ANCHOR", fpPx + 2, fpPy, 18)
            }

            if (this.needStatusUpdate) {
                updateGlobalStatus(true)
                this.needStatusUpdate := false
            }
            this.prevFoundPixel := { x: fpPx, y: fpPy }
            this.foundAnchor := true
            this.lastFoundTick := A_TickCount
            this.isChangingPrint := false

            return { x: fpPx, y: fpPy }
        } else {
            this.prevFoundPixel := false
            this.foundAnchor := false
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

    checkTimeout() {
        if (!this.foundAnchor && this.lastFoundTick != 0 && this.mode == "auto") {
            timeLeft := Integer((10000 - (A_TickCount - this.lastFoundTick)) / 1000) + 1
            updateGlobalStatus(false, true, timeLeft)
            if (A_TickCount - this.lastFoundTick > 10000) {
                ResetHackMode()
                this.Idle()
            }
        }

    }

    /**
     * Searches for the El Rubio ring on screen and returns the detected row index (1-8), or -1 if not found.
     * @returns {number} Integer row index (1-8) or -1.
     */
    FindElRing() {
        static x1 := A_ScreenWidth * 0.199
        static y1 := A_ScreenHeight * 0.323
        static x2 := A_ScreenWidth * 0.202
        static y2 := A_ScreenHeight * 0.891

        fx := 0, fy := 0
        if !ImageSearch(&fx, &fy, x1, y1, x2, y2, "*50 " this.folder "elRing.png")
            return -1
        row := this.Pos(fx, fy, -1)
        this.cachedCursorRow := row
        return row
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

}
