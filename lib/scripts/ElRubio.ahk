; class start
; DO NOT REMOVE THE ABOVE LINE - REQUIRED TO AUTOMATE BUILDING OF CLASSES AS STANDALONE SCRIPTS
/**
 * @description El Rubio solver class.
 * OpenCV-only solver for the Cayo Perico fingerprint puzzle.
 * 
 * Flow:
 * Hack()/autoStartManual() -> timer loop -> OpenCV anchor check -> REQ_CAYO solve payload
 */
class ElRubioSolver {
    mode := "idle"
    scrW := A_ScreenWidth
    scrH := A_ScreenHeight

    delay := 0
    prevFoundPixel := 0
    lastSeenTick := 0
    lastSeenGroupTick := 0
    prevClicks := ""

    needStatusUpdate := true
    foundAnchor := false
    isBusy := false
    isShuttingDown := false
    autoStarted := false
    useOpenCv := true

    __New(delay, updateGlobalStatus, prevFoundPixel := 0, folderPath := "", highRes := false, engine := OPENCV_ENGINE) {
        global folder

        this.delay := delay
        this.prevFoundPixel := prevFoundPixel
        this.folder := folderPath != "" ? folderPath : folder
        this.useOpenCv := true

        this.fnMainLoop := ObjBindMethod(this, "MainLoop")
        this.fnCheckFalsePositive := ObjBindMethod(this, "CheckFalsePositive")

        this.Idle()
    }

    /**
     * Sets the key delay for input.
     * @param {number} delayMs - Delay in milliseconds
     */
    setKeyDelay(delayMs) {
        this.delay := delayMs
    }

    /**
     * Kept for interface compatibility. This solver always uses OpenCV.
     */
    setEngine(engine) {
        this.useOpenCv := true
    }

    /**
     * Sets the solver to idle mode, clears tooltips and resets the state.
     */
    Idle() {
        this.isShuttingDown := false
        this.clearAll()
        this.mode := "idle"
        this.isBusy := false
        this.foundAnchor := false
        this.needStatusUpdate := true
        this.lastSeenTick := 0
        this.lastSeenGroupTick := 0
        this.prevClicks := ""
        this.autoStarted := false
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        updateGlobalStatus(false, , , "ElRubioSolver.Idle()")
    }

    /**
     * Cleans up solver state, tooltips, and timers.
     */
    Destroy() {
        this.isShuttingDown := true
        this.mode := "idle"
        this.foundAnchor := false
        this.isBusy := false
        this.autoStarted := false
        try SetTimer this.fnMainLoop, 0
        try SetTimer this.fnCheckFalsePositive, 0
        this.clearAll()
    }

    /**
     * Starts the solver from an externally detected anchor.
     * Kept for compatibility with the main script.
     */
    autoStartManual(anchorPixelCoords) {
        if (this.isShuttingDown)
            return

        this.autoStarted := true
        this.prevFoundPixel := anchorPixelCoords
        this.foundAnchor := true
        this.Hack(true)
        SetTimer () => (this.CheckFalsePositive()), -5000
    }

    /**
     * Resets if the anchor vanishes during auto-start.
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
     * Manual mode is retained only for interface compatibility.
     */
    SwitchToManual() {
        if (this.autoStarted)
            this.autoStarted := false

        if (this.mode == "manual")
            return

        this.prevClicks := ""
        this.clearAll()

        this.mode := "manual"
        SetTimer this.fnMainLoop, 0
        SetTimer this.fnMainLoop, 200
        updateGlobalStatus(false, , , "ElRubioSolver.SwitchToManual()")
    }

    /**
     * Main entrypoint: starts the automated solve loop.
     */
    Hack(autoStart := false, *) {
        if (this.autoStarted && !autoStart)
            this.autoStarted := false

        if (this.isShuttingDown)
            return

        SetTimer this.fnMainLoop, 0
        SetTimer this.fnCheckFalsePositive, 0
        this.mode := "auto"
        this.lastSeenTick := 0
        this.lastSeenGroupTick := 0
        updateGlobalStatus(this.foundAnchor, , , "ElRubioSolver.Hack()")
        SetTimer this.fnMainLoop, 200
    }

    /**
     * Main solver loop. OpenCV-only flow.
     */
    MainLoop() {

        if (!isGtaFocused(true))
            ResetHackMode()

        if (this.isBusy || this.isShuttingDown)
            return

        this.isBusy := true
        try {
            this.checkTimeout()
            this.tryOpenCV()
        } finally {
            this.isBusy := false
        }
    }

    /**
     * Handles timeouts while the anchor is missing.
     */
    checkTimeout() {
        if (this.foundAnchor)
            return

        if (this.lastSeenTick != 0) {
            this.clearAll()
            timeLeft := Integer((10000 - (A_TickCount - this.lastSeenTick)) / 1000) + 1
            updateGlobalStatus(false, true, timeLeft, "ElRubioSolver.checkTimeout()")
            if (A_TickCount - this.lastSeenTick > 10000) {
                ResetHackMode()
                this.Idle()
            }
        }
    }

    /**
     * Attempts to detect the anchor and solve using OpenCV responses.
     * @returns {boolean}
     */
    tryOpenCV() {
        if (!this.useOpenCv)
            return false

        try {
            anchorRes := GetResFromOpenCV(ANCHOR_CAYO)

            this.foundAnchor := (
                anchorRes != ERRMSG
                && anchorRes != "0"
                && anchorRes
            )

            if (!this.foundAnchor) {
                this.foundAnchor := false
                this.prevFoundPixel := 0
                this.needStatusUpdate := true
                this.prevClicks := ""
                return false
            }

            this.lastSeenTick := A_TickCount
            if (debug)
                ToolTip("Rubio Anchor (opencv)", 0, 0, 18)

            res := GetResFromOpenCV(REQ_CAYO)
            if (res = ERRMSG || res = "" || !res)
                return false

            if (this.autoStarted)
                this.autoStarted := false

            if (this.needStatusUpdate && this.foundAnchor) {
                updateGlobalStatus(true, , , "ElRubioSolver.tryOpenCV()")
                this.needStatusUpdate := false
            }

            cayoResult := this.parseOpenCayoResult(res)
            if (!IsObject(cayoResult))
                return false

            if (this.mode == "auto") {
                this.solveOpenCV(cayoResult.row, cayoResult.clicks)
            } else {
                if (cayoResult.clicksKey != this.prevClicks) {
                    this.prevClicks := cayoResult.clicksKey
                    this.showOpenCVClicks(cayoResult.clicks)
                }
            }

            this.autoStarted := false
            return true
        } catch {
            return false
        }
    }

    /**
     * Solves the fingerprint puzzle using OpenCV detection results.
     * @param cursorRow {number} The current cursor row.
     * @param clicks {array} The list of clicks to apply.
     */
    solveOpenCV(cursorRow, clicks) {
        SetKeyDelay(this.delay, this.delay)

        if (this.obviousReturn())
            return

        if (cursorRow > 1)
            Send("{Up " (cursorRow - 1) "}")

        Sleep 10

        for row, offset in clicks {
            if (this.obviousReturn())
                return

            if (offset > 0)
                Send("{Right " offset "}")
            else if (offset < 0)
                Send("{Left " Abs(offset) "}")

            Sleep 10

            if (row < clicks.Length) {
                Send("{Down}")
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

    /**
     * Shows OpenCV click positions on the screen.
     * @param clicks
     */
    showOpenCVClicks(clicks) {
        static baseY := 0.323
        static gapH := 10 / 1080
        static rectH := 65 / 1080

        x := this.scrW * 0.15

        loop 8
            ToolTip("", , , A_Index)

        for row, offset in clicks {
            if (this.isShuttingDown)
                return

            y := this.scrH * (baseY + (row - 1) * (rectH + gapH) + rectH / 2)

            if (offset > 0)
                txt := offset " Right"
            else if (offset < 0)
                txt := Abs(offset) " Left"
            else
                txt := "Aligned"

            ToolTip(txt, x, y, row)
        }

        if (this.isShuttingDown)
            this.clearAll()
    }

    /**
     * Returns true if the solver should exit early due to state.
     */
    obviousReturn() {
        return (!this.foundAnchor || this.mode != "auto" || this.isShuttingDown)
    }

    /**
     * Resets solver state, tooltips, and caches.
     */
    ResetState() {
        this.clearAll()
        if (debug)
            ToolTip "All rows solved / lost anchor", 0, 0, 18
        this.foundAnchor := false
        this.needStatusUpdate := true
        this.prevClicks := ""
        this.autoStarted := false
        this.lastSeenTick := 0
        this.lastSeenGroupTick := 0
    }

    /**
     * Clears all tooltips (1 to 19).
     */
    clearAll() {
        loop 19
            ToolTip("", , , A_Index)
    }
}
