#Include "../standaloneHelpers.ahk"

global fingerprintMode := 0

init() {
    try Hotkey("~*" CanonicalToRegistration(autoHackKey), standalone_switch_to_auto, "On")
    try Hotkey("~*" CanonicalToRegistration(manualKey), standalone_switch_to_manual, "On")

    standalone_switch_to_auto(*) {
        global hackMode := "auto"
        UpdateGlobalStatus(hackInProgress)
        keypad.switchToAuto()
    }

    standalone_switch_to_manual(*) {
        global hackMode := "manual"
        UpdateGlobalStatus(hackInProgress)
        keypad.switchToManual()
    }

    keypad := KeypadSolver(delay, ResetHackMode, UpdateGlobalStatus, cachedKeypadAnchor, folder)
}

init()

; class start
; DO NOT REMOVE THE ABOVE LINE - REQUIRED TO AUTOMATE BUILDING OF CLASSES AS STANDALONE SCRIPTS
/**
 * @description Keypad solver class.
 * Handles anchor detection, grid detection, stabilization, and column selection for
 * the Diamond Casino keypad hack.
 * 
 * ### FLOW:
 * ```text
 * switchToAuto()/switchToManual() → findAnchor() → start MainLoop(timer) 
 * 
 * MainLoop():
 *   validateAnchor()         ; ensure UI valid (loss → Idle/reset)
 *   
 *   if not stabilized:
 *     GridDetect()           ; detect all columns/rows (multi-pass)
 *     StabilizationCheck()   ; wait until grid stable (2s)
 * 
 *   else:
 *     (AUTO)   ringDetected_AutoSelect() → detect ring → SelectCurrentCol()
 *     (MANUAL) isCurrentColSelected()    ; wait for user selection
 * 
 *       SelectCurrentCol()  → move (Up/Down) + Enter
 *       → isColSelected() → confirm via ScanColumnImage()
 * 
 *    if all columns done → ResetState()
 * 
 * Destroy()/Idle() → stop + clear state 
 * ```
 * 
 * ### Pipeline:
 * Anchor → GridDetect → Stabilize → Detect Ring → Select → Repeat
 */
class KeypadSolver {
    needStatusUpdate := true

    keyImgPath := ""
    mode := "idle"
    scrH := A_ScreenHeight
    scrW := A_ScreenWidth

    lastDetectionTime := 0

    baseX := 0
    baseY := 0
    spacing := 0
    searchRadiusX := 0
    searchRadiusY := 0
    circleRadius := 0
    anchorLastSeen := 0
    prevFoundPixel := 0
    prevRingRow := 0
    delay := 0

    timeOut := 10000
    primaryAnchorTolerance := 10
    gridTolerance := 50

    colsCount := 6
    rowsCount := 5
    cols := Map()
    colDetectCount := Map()

    stabilized := false
    handoffPending := false
    gridFilledOnce := false
    foundAnchor := false
    isBusy := false
    isShuttingDown := false

    baseX_ratio := 0.26
    baseY_ratio := 0.33
    base_x1_imgSearch := 0.2375
    base_y1_imgSearch := 0.275
    base_x2_imgSearch := 0.29
    base_y2_imgSearch := 0.769

    __New(delay, resetHackMode, updateGlobalStatus, prevFoundPixel, folderPath := "") {
        global

        this.delay := delay
        this.folder := folderPath != "" ? folderPath : this.folder
        this.prevFoundPixel := prevFoundPixel

        SetKeyDelay(delay, delay)
        this.searchRadiusX := Round(this.scrW * 0.015) ; ~30px at 1920 width
        this.searchRadiusY := Round(this.scrH * 0.015) ; ~30px at 1080 height
        this.spacing := Round(this.scrW * (108 / 1920)) ; Scale spacing based on 1920 width
        this.circleRadius := Round(this.scrW * (84 / 1920)) ; Scale circle radius based on 1920 width
        this.keyImgPath := this.folder "key.png"
        this.baseX := Round(this.scrW * this.baseX_ratio)
        this.baseY := Round(this.scrH * this.baseY_ratio)
        this.baseXImg := Round(this.scrW * this.base_x1_imgSearch)
        this.baseYImg := Round(this.scrH * this.base_y1_imgSearch)
        this.fnMainLoop := this.MainLoop.Bind(this)
        this.fnCheckFalsePositive := this.CheckFalsePositive.Bind(this)

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
     * Sets the solver to idle mode, clears tooltips and resets the state.
     */
    Idle() {
        this.mode := "idle"
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        this.prevRingRow := 1

        loop 18
            ToolTip("", , , A_Index)
        updateGlobalStatus(false) ; ToolTip replacement
        this.stabilized := false
        this.gridFilledOnce := false
        this.lastDetectionTime := 0
        this.cols := Map()
    }

    Destroy() {
        ;  reset internal state
        this.cols := Map()
        this.mode := "idle"
        this.stabilized := false
        this.gridFilledOnce := false
        this.handoffPending := false
        this.foundAnchor := false
        this.anchorLastSeen := 0
        this.isShuttingDown := true

        ;  stop timer (critical)
        try SetTimer this.fnMainLoop, 0
        try SetTimer this.fnCheckFalsePositive, 0

        loop 19
            ToolTip("", , , A_Index)
    }

    /**
     * Checks for false positives and resets if anchor is lost during auto-start.
     */
    CheckFalsePositive() {
        if (this.isShuttingDown || this.mode != "manual")
            return

        if (!this.foundAnchor) {
            ResetHackMode()
            this.Idle()
        }
    }

    /**
     * Starts manual mode with the given anchor pixel coordinates, bypassing the initial anchor search.
     * Used by the main script to immediately start manual mode
     * when the main script auto-detects one of the anchor pixels.
     * @param {object} anchorPixelCoords - Anchor pixel coordinates
     */
    autoStartManual(anchorPixelCoords) {
        this.prevFoundPixel := anchorPixelCoords
        this.switchToManual()

        SetTimer this.fnCheckFalsePositive, 0
        SetTimer this.fnCheckFalsePositive, -5000
    }

    /**
     * Switches solver to auto mode, finds anchor, and starts main loop timer. 
     * Used by the auto mode hotkey.
     */
    switchToAuto(*) {
        if (this.mode == "auto")
            return

        SetTimer this.fnCheckFalsePositive, 0
        this.mode := "auto"
        SetTimer this.fnMainLoop, 0
        updateGlobalStatus(this.foundAnchor)

        this.findAnchor() ; Immediate anchor check before starting timers

        this.handoffPending := true
        SetTimer this.fnMainLoop, 100

    }

    /**
     * Switches solver to manual mode, finds anchor, and starts main loop timer.
     * Used by the manual mode hotkey.
     */
    switchToManual(*) {
        if (this.mode == "manual")
            return

        SetTimer this.fnCheckFalsePositive, 0
        this.mode := "manual"
        SetTimer this.fnMainLoop, 0
        updateGlobalStatus(this.foundAnchor)

        this.findAnchor() ; Immediate anchor check before starting timers

        this.handoffPending := true
        SetTimer this.fnMainLoop, 200

    }

    /**
     * @hotloop
     * Unified loop for both auto and manual keypad solving.
     * Only runs the detection logic for the current mode.
     * Should be called by a timer, does NOT handle timer setup or mode switching.
     */
    MainLoop() {

        if (this.isBusy || this.isShuttingDown) {
            ; Skip overlapping timer ticks while a previous iteration is still running.
            return
        }

        this.isBusy := true
        try {
            this.validateAnchor()

            this.checkTimeout()

            if (this.mode == "idle" || !this.foundAnchor)
                return

            if (this.mode == "manual") {
                if (this.handoffPending) {
                    this.ShowRingMap("", true) ; Switch mapping tooltip to show manual selection guidance during handoff
                    this.handoffPending := false
                }

                if (!this.stabilized) {
                    this.GridDetect()
                    this.StabilizationCheck()
                } else {
                    this.isCurrentColSelected()
                }

            } else if (this.mode == "auto") {

                if (!this.stabilized) {
                    this.GridDetect()
                    this.StabilizationCheck()
                } else {
                    this.ringDetected_AutoSelect()
                }
            }
        } finally {
            this.isBusy := false
        }
    }

    /**
     * Validates the presence of the anchor and updates the global status accordingly.
     * If the anchor is lost for 10s, resets the hack mode and returns to idle.
     * @returns {boolean}
     */
    validateAnchor(*) {

        if (this.mode == "idle")
            return false

        if this.findAnchor() {
            if (this.needStatusUpdate) {
                updateGlobalStatus(true)

                this.needStatusUpdate := false
            }
            this.anchorLastSeen := A_TickCount
            return true
        }

        ; Anchor lookup missed this tick: mark as lost now so timeout logic
        ; can consistently represent the real state.
        this.foundAnchor := false

        if (this.anchorLastSeen == 0) {
            return false

        }
        return false
    }

    checkTimeout() {
        if (this.mode == "idle" || this.foundAnchor)  ; Timeout status should only display while anchor is currently lost.
            return

        if (this.anchorLastSeen != 0) {
            timeLeft := Integer((this.timeOut - (A_TickCount - this.anchorLastSeen)) / 1000) + 1
            updateGlobalStatus(false, true, timeLeft) ; Inform the main script about the anchor loss and remaining time before reset
            this.needStatusUpdate := true
            if (this.anchorLastSeen != 0 && (A_TickCount - this.anchorLastSeen > this.timeOut)) {
                ResetHackMode()
                this.Idle()
                this.anchorLastSeen := 0
            }
        }

        return
    }

    /**
     * Checks if all columns are detected and stable for 2 seconds.
     * If so, marks the grid as stabilized and triggers auto-hack or manual selection loop.
     */
    StabilizationCheck() {
        if this.stabilized
            return

        allDetected := true
        loop this.colsCount {
            col := A_Index
            if !this.cols.Has(col) || !this.cols[col].HasOwnProp("row") {
                allDetected := false
                break
            }
        }
        if !allDetected
            return
        if (A_TickCount - this.lastDetectionTime > 2000) {

            this.showMapIfStabilized()

            if this.ringDetected_AutoSelect() {
                this.stabilized := true
                this.handoffPending := true
                this.showKeys()
            }
            if (debug)
                ToolTip "Stabilized? " this.stabilized, this.scrW / 2, 10, 19

        }
    }

    /**
     * Finds the keypad anchor using image search, with fallback to cached pixel.
     * Found anchor coordinates are stored in this.prevFoundPixel for future quick searches.
     * Uses a two-pass search strategy: first checks a small area around the last known anchor position,
     * then falls back to searching the entire expected region if not found.
     * @returns {object|boolean} Anchor coordinates if found, false otherwise
     */
    findAnchor() {
        global cachedKeypadAnchor

        ToolTip "", , , 18
        static lastCalled := 0
        if (A_TickCount - lastCalled < 1000 && this.foundAnchor) {
            return this.prevFoundPixel
        }

        lastCalled := A_TickCount

        static x1 := A_ScreenWidth * 0.5
        static y1 := A_ScreenHeight * 0.1
        static x2 := A_ScreenWidth * 0.73
        static y2 := A_ScreenHeight * 0.17

        localSearchSize := 20
        kpFound := false
        kpPx := 0, kpPy := 0

        ;  try cached pixel area first (ImageSearch in a small region around cached pixel)
        if (IsObject(this.prevFoundPixel) && this.prevFoundPixel.x && this.prevFoundPixel.y) {
            cx := this.prevFoundPixel.x, cy := this.prevFoundPixel.y
            sx1 := Max(cx - localSearchSize, 0)
            sy1 := Max(cy - localSearchSize, 0)

            kpFound := ImageSearch(&kpPx, &kpPy, sx1, sy1, x2, y2, "*" this.primaryAnchorTolerance " " this.folder "anchor.png"
            )
            if (kpFound && debug) {
                ToolTip "Keypad anchor (cached)!", kpPx + 10, kpPy, 18
            }
        }

        ; if not found, scan the full region (ImageSearch)
        if (!kpFound) {
            kpFound := ImageSearch(&kpPx, &kpPy, x1, y1, x2, y2, "*" this.primaryAnchorTolerance " " this.folder "anchor.png"
            )
            if (kpFound && debug) {
                ToolTip "[class] Keypad anchor found!", kpPx + 10, kpPy, 18
            }
        }

        if (kpFound) {
            this.prevFoundPixel := { x: kpPx, y: kpPy }
            cachedKeypadAnchor := { x: kpPx, y: kpPy }
            this.foundAnchor := true
            return { x: kpPx, y: kpPy }
        } else {
            this.prevFoundPixel := 0
            this.foundAnchor := 0
            if (debug) {
                ToolTip "No anchors found", 0, 0, 18
                ; Sleep 500
            }
            return false
        }
    }

    /**
     * @hotloop
     * Detects all columns and their rows using image search.
     * Iterates over all columns and attempts multiple passes per column for robust detection.
     * Updates this.cols and this.colDetectCount.
     */
    GridDetect() {
        if (this.stabilized || this.mode == "idle")
            return

        newDetection := false
        col_spacing_ratio := 108 / 1920
        base_x1 := this.baseXImg
        base_y1 := this.baseYImg
        base_x2 := Round(this.scrW * this.base_x2_imgSearch)
        base_y2 := Round(this.scrH * this.base_y2_imgSearch)
        col_spacing := Round(this.scrW * col_spacing_ratio)

        loop this.colsCount {
            if (this.stabilized || this.mode == "idle" || this.mode == "" || this.isShuttingDown)
                return

            col := A_Index
            x1 := base_x1 + (col - 1) * col_spacing
            x2 := base_x2 + (col - 1) * col_spacing
            y1 := base_y1
            y2 := base_y2
            found := false
            if !this.colDetectCount.Has(col)
                this.colDetectCount[col] := 0
            prevRow := this.cols.Has(col) && this.cols[col].HasOwnProp("row") ? this.cols[col].row : ""
            singlePassWhenStable := (this.colDetectCount[col] >= 3) ? 1 : 0
            if (debug)
                ToolTip "passes for col " col ": " this.colDetectCount[col], this.scrW / 2, 10, 19

            attempt := 1
            while (!found && (this.colDetectCount[col] < 4 || singlePassWhenStable > 0)) {
                if (this.stabilized || this.mode == "idle" || !this.foundAnchor || this.isShuttingDown)
                    return
                if (this.colDetectCount[col] >= 3)
                    singlePassWhenStable := 0
                if attempt = 2 {
                    x1a := Max(x1 - 10, 0)
                    x2a := Min(x2 + 10, this.scrW)
                    y1a := Max(y1 - 10, 0)
                    y2a := Min(y2 + 10, this.scrH)
                } else if attempt = 3 {
                    xOff := Random(-15, 15)
                    yOff := Random(-15, 15)
                    x1a := Max(x1 + xOff, 0)
                    x2a := Min(x2 + xOff, this.scrW)
                    y1a := Max(y1 + yOff, 0)
                    y2a := Min(y2 + yOff, this.scrH)
                } else {
                    x1a := x1, x2a := x2, y1a := y1, y2a := y2
                }
                if (debug)
                    ToolTip "Col " col ": Searching", this.baseXImg + (col - 1) * this.spacing, this.baseYImg - 20,
                    col

                foundImg := ImageSearch(&fx, &fy, x1a, y1a, x2a, y2a, "*" this.gridTolerance " " this.keyImgPath)
                if foundImg {
                    row := Round((fy - this.baseY) / this.spacing) + 1
                    prev := this.cols.Has(col) ? this.cols[col] : ""
                    prevRow := prev && prev.HasOwnProp("row") ? prev.row : ""
                    detected := { x: fx, y: fy, row: row, type: "key" }
                    if (!prev or prev.x != detected.x or prev.y != detected.y or prev.row != detected.row) {
                        newDetection := true
                        this.colDetectCount[col] := this.colDetectCount[col] + 1
                    }
                    this.cols[col] := detected
                    found := true
                    x := this.baseXImg + (col - 1) * (this.spacing) + (this.circleRadius / 2)
                    y := this.baseYImg + (row - 1) * (this.spacing)
                    ToolTip "⛛", x - (10 * ((1920 / this.scrW) ** 0.5)), y - (18 * ((1080 / this.scrH) ** 0.8)),
                    col
                }
                attempt++
                if attempt > 3 {
                    attempt := 1
                    break
                }
            }
        }

        allDetected := true
        loop this.colsCount {
            col := A_Index
            if !this.cols.Has(col) || !this.cols[col].HasOwnProp("row") {
                allDetected := false
                break
            }
        }

        if allDetected {
            this.gridFilledOnce := true
            if newDetection {
                this.lastDetectionTime := A_TickCount
            }
        }
    }

    /**
     * Uses image search to detect if a column is selected.
     * @param {number} col - Column index
     * @returns {object|boolean} Detection result with x, y, row, and type if found; false otherwise
     */
    ScanColumnImage(col) {
        base_x1 := this.baseXImg
        center_x := base_x1 + (col - 1) * this.spacing + (this.spacing // 2)
        x1 := center_x - Round(this.spacing / 2)
        x2 := center_x + Round(this.spacing / 2)
        base_y1 := this.baseYImg
        y1 := base_y1
        y2 := base_y1 + (this.rowsCount * this.spacing)
        foundImg := ImageSearch(&fx, &fy, x1, y1, x2, y2, "*" this.gridTolerance " " this.keyImgPath)
        if foundImg {
            row := Round((fy - this.baseY) / this.spacing) + 1
            row := Min(this.rowsCount, Max(1, row))
            return { x: fx, y: fy, row: row, type: "key" }
        }
        return false
    }

    /**
     * Detects the ring for smart selection. Selects the key based on the detected ring position if in auto mode.
     * Shows the mapping tooltip based on the mode.
     * @param {boolean} [force=false] - Forces mapping tooltip update.
     * @returns {boolean}
     */
    ringDetected_AutoSelect(force := false) {
        static baseX := this.scrW * 0.2336, baseY := this.scrH * 0.3073
        found := false
        ringRow := ""
        ringCol := ""
        minDist := 1e9
        minDistCol := 1e9
        pxFound := false
        px := 0, py := 0

        ; Only scan the first two columns present in the cols map (sorted by key)
        colKeys := []
        count := 0
        for col in this.cols {
            colKeys.Push(col)
            count++
            if (count >= 2)
                break
        }
        scanCols := colKeys.Length ? colKeys : [1, 2]
        if (scanCols.Length = 0) {
            ; If no cols present, fallback to first two grid columns
            scanCols := [1, 2]
        }

        for idx, cIdx in scanCols {
            cx := baseX + (cIdx - 1) * this.spacing
            for row, rIdx in [1, 2, 3, 4, 5] {
                cy := baseY + (rIdx - 1) * this.spacing
                color := PixelGetColor(cx, cy, "RGB")
                r := (color >> 16) & 0xFF
                g := (color >> 8) & 0xFF
                b := color & 0xFF
                if (debug)
                    ToolTip r " " g " " b, cx + 10, cy, 18
                ; Check if pixel is non-black/non-dark (any channel > 40)
                if (r > 40 || g > 40 || b > 40) {
                    cy2 := cy + 5
                    color2 := PixelGetColor(cx, cy2, "RGB")
                    r2 := (color2 >> 16) & 0xFF
                    g2 := (color2 >> 8) & 0xFF
                    b2 := color2 & 0xFF
                    if (debug)
                        ToolTip r2 " " g2 " " b2, cx + 10, cy2, 18
                    if (r2 > 40 || g2 > 40 || b2 > 40) {
                        cy3 := cy2 + 5
                        color3 := PixelGetColor(cx, cy3, "RGB")
                        r3 := (color3 >> 16) & 0xFF
                        g3 := (color3 >> 8) & 0xFF
                        b3 := color3 & 0xFF
                        if (r3 > 40 || g3 > 40 || b3 > 40) {
                            ; Found a vertical stack, treat as ring
                            pxFound := true
                            px := cx
                            py := cy
                            ; Find closest row/col
                            dist := Abs(py - cy)
                            if dist < minDist {
                                minDist := dist
                                ringRow := rIdx
                            }
                            distCol := Abs(px - cx)
                            if distCol < minDistCol {
                                minDistCol := distCol
                                ringCol := cIdx
                            }
                            found := true
                            break
                        }
                    }
                }
            }
            if found
                break
        }
        if found {
            this.prevRingRow := ringRow
            ; Update state and select col as in RingDetect
            if (force || ringRow != "" || ringCol != "") {
                if (this.mode == "auto")
                    this.ShowRingMap(ringRow)
                else
                    this.ShowRingMap("", true)

                if (debug)
                    ToolTip "Ring: Row " ringRow ", Col " ringCol, px, py, 18

                if (this.cols.Has(ringCol) && this.mode == "auto")
                    this.SelectCurrentCol(ringCol, ringRow)

            }
            return true
        } else {
            if (debug)
                ToolTip "No ring stack found (color)", 50, 100, 18
            return false
        }
    }

    /**
     * Selects the key for the current column using the detected ring position.
     * @param {number} col - Column index
     * @param {number} ringRow - Row index of the detected ring
     */
    SelectCurrentCol(col, ringRow) {
        SetKeyDelay(this.delay, this.delay)

        if !this.cols.Has(col) {
            MsgBox "error in selectCurrentCol"
            sleep 1000
            return
        }

        c := this.cols[col]
        if !c.HasOwnProp("row") {
            MsgBox "error in selectCurrentCol"
            sleep 1000
            return
        }
        from := ringRow
        to := c.row
        if (from != to) {
            upSteps := Mod(from - to + this.rowsCount, this.rowsCount)
            downSteps := Mod(to - from + this.rowsCount, this.rowsCount)
            if upSteps <= downSteps {
                ; key := "{Up}"
                num := upSteps
                key := "{Up " num "}"
            } else {
                ; key := "{Down}"
                num := downSteps
                key := "{Down " num "}"
            }
            ; loop num {
            ;     Send key
            ;     Sleep 50
            ; }
            if (debug) {
                ToolTip "Sending " key, 0, 0, 18
            }
            SendEvent(key)

        }
        Sleep this.delay
        SendEvent("{Enter}")
        start := A_TickCount
        found := false
        while (A_TickCount - start < 2000) {
            if !this.cols.Has(col)
                return
            if this.isColSelected(col) {
                found := true
                return
            }
            Sleep 10
        }
        if found
            return

    }

    ; ===== HELPERS =====

    /**
     * Checks if the key in the current column is selected and updates the guidance tooltip for manual mode if so.
     */
    isCurrentColSelected() {
        if !(this.mode == "manual") {
            return
        }

        for col in this.cols {
            if (this.isColSelected(col))
                this.ShowRingMap("", true) ; Update tooltip to show manual selection guidance after a column is selected
            break
        }
    }

    /**
     * Checks if a column is selected and handles state update.
     * Used by both auto and manual modes.
     * @param {number} col - Column index
     * @returns {boolean}
     */
    isColSelected(col) {
        if !this.cols.Has(col)
            return false
        c := this.cols[col]
        found := false
        detected := this.ScanColumnImage(col)
        if detected {
            found := true
            if (debug)
                sleep 100
        }

        if found {
            ToolTip "", , , col
            if (this.cols.Has(col))
                this.cols.Delete(col)
            if (this.cols.Count = 0 || col == 6) {
                this.ResetState()
            }
            return true
        }
        return false
    }

    /**
     * Shows arrows over the detected key positions. Mainly for the manual mode.
     * 
     * (DebugDisplay)
     */
    showKeys() {
        shown := false
        for col, c in this.cols {
            ; x := this.baseX + this.spacing * (col - 1)
            ; y := this.baseY + this.spacing * (c.row - 1)
            ; x := c.x
            x := this.baseXImg + (col - 1) * (this.spacing) + (this.circleRadius / 2)
            y := this.baseYImg + (c.row - 1) * (this.spacing)
            ToolTip "⛛", x - (10 * ((1920 / this.scrW) ** 0.5)), y - (18 * ((1080 / this.scrH) ** 0.8)), col
            ; debug middot / arrow / selection indicator
            shown := true
        }
    }

    showMapIfStabilized() {
        ; Show initial ring map on stabilization before any selection
        if (!this.cols.Has(6))
            return

        if (this.mode == "auto")
            this.ShowRingMap(this.prevRingRow)
        else
            this.ShowRingMap("", true)
    }

    /**
     * Shows the ring map tooltip based on the detected ring position for auto-mode and static row-col 
     * map for manual mode.
     * @param {number|string} [ringRow] - Map for auto-mode if present, omit for manual mode.
     * @param {boolean} [forManual=false] - Show map for manual mode.
     */
    ShowRingMap(ringRow := "", forManual := false) {
        if (!this.cols.Has(6))
            return
        out := ""
        if (!forManual && ringRow = "") {
            out := "No ring detected."
            ToolTip out, this.scrW * 0.105, this.scrH / 2, 17
            return
        }

        for col in this.cols {
            c := this.cols[col]
            if !c.HasOwnProp("row")
                continue
            if (forManual) {
                out .= "Col " col ": Row " c.row "`n"
                continue
            }
            diff := c.row - ringRow
            dir := diff >= 0 ? "Down" : "Up"
            out .= "Col " col ": " dir " " Abs(diff) "`n"
        }
        if (out = "")
            out := "No mapping found."
        ToolTip out, this.scrW * 0.105, (this.scrH * 0.4), 17
    }

    /**
     * Resets solver state and restarts the main loop timer.
     * 
     * Called when all columns are selected.
     */
    ResetState(*) {
        SetTimer this.fnMainLoop, 0
        loop 19
            ToolTip("", , , A_Index)
        this.stabilized := false
        this.gridFilledOnce := false
        this.lastDetectionTime := 0
        this.handoffPending := false
        this.cols := Map()
        this.colDetectCount := Map()
        this.needStatusUpdate := true
        ; ToolTip "Resetting state", this.scrW / 2, 10, 19
        Sleep 2500
        SetTimer this.fnMainLoop, 100
    }
}
