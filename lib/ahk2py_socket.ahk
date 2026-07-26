#Requires AutoHotkey v2.0

global pyProc := 0
global pythonExe := "pyw.exe"
isVaultOpsAhk := A_ScriptName = "vaultOps.ahk"

if (A_LineFile = A_ScriptFullPath) {
    global scriptPath := A_ScriptDir "\py_helpers\OpenCV_Engine.py"
} else {
    if (!A_IsCompiled && !isVaultOpsAhk && IsSet(isStandaloneScript) && isStandaloneScript) {
        ; If running uncompiled in a standalone context (e.g. from VaultOps Toolkit), use parent dir for helper path
        global scriptPath := A_ScriptDir "\..\py_helpers\OpenCV_Engine.py"
    }
    else
        global scriptPath := A_ScriptDir "\lib\py_helpers\OpenCV_Engine.py"
}

global useCompiledExe := false
global isShuttingDown := false
global ocvCallInProgress := false

; Request type constants so callers do not need to repeat raw strings.
class OpenCVCmd {
    ; Returns the positions of the fingerprints.
    static FINGERPRINT := "get_fingerprint"

    ; Returns the positions of the keypad, or -1 if not found or only a partial match.
    static KEYPAD := "get_keypad"

    ; Returns the clicks needed to solve Cayo Perico, or 0 if not found.
    static CAYO := "get_cayo"

    ; Returns the type of puzzle, e.g. "fingerprint", "keypad", "cayo", or 0.
    static DETECT_ANCHOR := "detect_anchor"

    ; Returns 1 if the current puzzle is a Diamond Casino fingerprint puzzle, otherwise 0.
    static FINGERPRINT_ANCHOR := "fpAnchor"

    ; Returns 1 if the current puzzle is a Diamond Casino keypad puzzle, otherwise 0.
    static KEYPAD_ANCHOR := "kpAnchor"

    ; Returns 1 if the current puzzle is a Cayo Perico fingerprint puzzle, otherwise 0.
    static CAYO_ANCHOR := "cayoAnchor"

    ; Returns the row of the keypad ring position, or -1 if not found.
    static DETECT_RING := "detect_ring"

    /**
     * Returns 1 if the specified keypad column is currently selected, otherwise 0.
     * @param col 1-based index of the column to check.
     */
    static IS_COLUMN_SELECTED := "is_column_selected"

    ; Returns 1 if a black area is detected in the fingerprint puzzle, otherwise 0.
    ; Used for false-positive reduction.
    static BLACK_FINGERPRINT := "is_black_area_present_fingerprint"

    ; Returns 1 if a black area is detected in the keypad puzzle, otherwise 0.
    ; Used for false-positive reduction.
    static BLACK_KEYPAD := "is_black_area_present_keypad"

    ; Returns 1 if a black area is detected in the Cayo Perico puzzle, otherwise 0.
    ; Used for false-positive reduction.
    static BLACK_CAYO := "is_black_area_present_cayo"

    ; Returns 1 if a black area is detected during the ledge-grab sequence, otherwise 0.
    static BLACK_LEDGE_GRAB := "is_black_area_present_ledge_grab"

    ; Helper ping request used to keep the OpenCV engine alive while the host is running.
    static HEARTBEAT := "heartbeat"

    ; Requests the OpenCV engine to terminate gracefully.
    static STOP := "STOP"

    ; Error code returned when anything goes wrong.
    static ERRMSG := "ErrNoResponse"
}

; =========================
; STARTUP / DETECTION
; =========================

; Check for a compiled helper exe in `lib/` and switch to it if present.
; Returns true when compiled exe was found and selected.
DetectCompiledExe() {
    exePath := A_ScriptDir "\lib\OpenCV_Engine.exe"
    if (FileExist(exePath)) {
        global useCompiledExe := true
        global scriptPath := exePath
        return true
    }
    return false
}

initPython() {
    DetectCompiledExe()
    StartPython()
}

; Start the Python helper process (or compiled exe). Initializes environment and
; stores the process object in `pyProc` for later communication/termination.
StartPython() {
    global pyProc, pythonExe, scriptPath, useCompiledExe, isShuttingDown

    if (isShuttingDown && IsSet(ShowCenteredToolTip)) {
        ShowCenteredToolTip "Not starting helper since script is exiting.", 15
        sleep 1000
    }

    if (pyProc || isShuttingDown)
        return

    if (!FileExist(scriptPath)) {
        if (IsSet(ShowCenteredToolTip))
            MsgBox "OpenCV helper not found at:`n`n" scriptPath "`n`nPlease ensure the file exists and try again.",
                "Error",
                16
        ExitApp
    }

    shell := ComObject("WScript.Shell")
    shell.Environment("Process")["PYTHONIOENCODING"] := "utf-8"

    if (useCompiledExe) {
        ; Run compiled exe directly
        cmd := '"' scriptPath '"'
    } else {
        ; Run OpenCV_Engine.py via pythonw.exe
        cmd := Format('"{1}" -u "{2}"', pythonExe, scriptPath)
    }

    pyProc := shell.Exec(cmd)
    SetTimer(() => HeartbeatOpenCV(), 1000)
}

; Restart the helper process (stop then start). Useful after timeouts.
RestartPython(err := "") {
    static errCount := 0
    errCount++
    MsgBox "An error occured. Restarting OpenCV helper.`n`n" . err

    if (errCount > 3) {
        MsgBox "OpenCV helper has failed to restart multiple times. Exiting script."
        ExitApp
    }

    StopPython()
    Sleep 50
    StartPython()
}

; Stop the helper process if running and clear the `pyProc` handle.
StopPython(*) {
    CallPython("STOP", , false, true)
}

; Wait for the last request to finish (or timeout) before returning. Returns true if finished, false if timed out.
LastRequestFinished(timeout := 2000) {
    global ocvCallInProgress

    ToolTip , , , 15
    start := A_TickCount
    while (ocvCallInProgress) {
        if (A_TickCount - start > timeout)
            return false
        Sleep 10
    }
    ; ShowCenteredToolTip "Helper is ready for new requests", 15, 500
    return true
}

; =========================
; CORE CALL
; =========================

; Send a JSON request to the helper process and wait (short timeout) for reply.
; Returns the raw response line or empty string on timeout/failure.
CallPython(puzzleType, params := 0, waitForResponse := true, killCall := false) {
    global pyProc, ocvCallInProgress, wasGtaFocused

    if (ocvCallInProgress && !killCall) {
        ; Prevent flooding the helper with requests if one is already in progress
        return ""
    }

    if (!pyProc) {
        initPython()
    }

    ; send request
    req := '{"type":"' puzzleType '"'

    if IsObject(params) {
        for key, value in params {
            if (Type(value) = "String") {
                safeVal := StrReplace(value, '"', '\"')
                req .= ',"' key '":"' safeVal '"'
            } else {
                req .= ',"' key '":' value
            }
        }
    }

    req .= ',"wasGtaFocused":' (wasGtaFocused ? "true" : "false")
    req .= "}"

    if (!IsObject(pyProc)) {
        ocvCallInProgress := false
        RestartPython()
        return ""
    }

    ocvCallInProgress := true
    try {
        pyProc.StdIn.WriteLine(req)
    } catch as err {
        ocvCallInProgress := false
        ; MsgBox("Err @204")
        RestartPython(err.Message)
        return ""
    }

    if (!waitForResponse) {
        ocvCallInProgress := false
        return ""
    }

    ; wait for response (timeout)
    start := A_TickCount
    try {
        while (A_TickCount - start < 1000) {
            if (!pyProc.StdOut.AtEndOfStream) {
                line := pyProc.StdOut.ReadLine()
                ocvCallInProgress := false
                return line
            }
            Sleep 10
        }
    } finally {
        ocvCallInProgress := false
    }

    ; timeout → restart python
    RestartPython()
    return ""
}

; =========================
; PUBLIC
; =========================

; High-level wrapper that sends a request and returns the helper's response.
GetResFromOpenCV(type, params := 0) {
    result := CallPython(type, params)

    if (result = "")
        return OpenCVCmd.ERRMSG ; fallback trigger

    return result
}

HeartbeatOpenCV(*) {
    global pyProc, ocvCallInProgress, isShuttingDown

    if (isShuttingDown || !IsObject(pyProc) || ocvCallInProgress)
        return

    try CallPython(OpenCVCmd.HEARTBEAT, , false) ; fire-and-forget heartbeat to keep helper alive
}

; =========================
; DEBUG HOTKEYS
; =========================
; {

;     ^F1:: {
;         res := GetResFromOpenCV(REQ_FINGERPRINT)
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }

;     ^F2:: {
;         res := GetResFromOpenCV(REQ_ALL_ANCHORS)
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }

;     ^1:: {
;         res := GetResFromOpenCV(REQ_BLACK_KP)
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }
;     ^F3:: {
;         res := GetResFromOpenCV(REQ_DETECT_RING)
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }

;     ^F4:: {
;         res := GetResFromOpenCV(REQ_IS_COLUMN_SELECTED, Map("col", 2))
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }

;     ^F5:: {
;         res := GetResFromOpenCV(REQ_KEYPAD)
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }

;     ^F6:: {
;         res := GetResFromOpenCV(REQ_CAYO)
;         ToolTip res
;         Sleep 3000
;         ToolTip
;     }

;     ^F7:: Reload()
; }
