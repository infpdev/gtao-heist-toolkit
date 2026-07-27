; =========================
; INIT
; =========================

global rpcProc := 0
global pythonExe := "pyw.exe"
global useCompiledExe := false
global isShuttingDown := false
global rpcCallInProgress := false

global REQ_HEARTBEAT_RPC := "HEARTBEAT"

isVaultOpsAhk := A_ScriptName = "vaultOps.ahk"

if (A_LineFile = A_ScriptFullPath) {
    global rpcScriptPath := A_ScriptDir "\py_helpers\DiscordRPC.py"
} else {
    if (!A_IsCompiled && !isVaultOpsAhk && IsSet(isStandaloneScript) && isStandaloneScript)
        global rpcScriptPath := A_ScriptDir "\..\py_helpers\DiscordRPC.py"
    else
        global rpcScriptPath := A_ScriptDir "\lib\py_helpers\DiscordRPC.py"
}

DetectCompiledRPCExe() {
    exePath := A_ScriptDir "\lib\DiscordRPC.exe"

    if (FileExist(exePath)) {
        global useCompiledExe := true
        global rpcScriptPath := exePath
        return true
    }

    return false
}

; =========================
; STARTUP
; =========================

HeartbeatDiscordRPC(*) {
    static failCount := 0
    global rpcProc

    if (!IsObject(rpcProc) || rpcCallInProgress)
        return

    res := CallDiscordRPC(Map(
        "request_type", REQ_HEARTBEAT_RPC
    ), true)

    if (res != "OK") {
        failCount++
        if (failCount > 3) {
            MsgBox "Discord RPC heartbeat failed 3 times. Restarting Discord RPC.", "Error", 16
            RestartDiscordRPC()
            failCount := 0
        }
    }
}

StartDiscordRPC() {
    global rpcProc, isShuttingDown

    if (rpcProc || isShuttingDown)
        return

    DetectCompiledRPCExe()

    if (!FileExist(rpcScriptPath)) {
        MsgBox "DiscordRPC not found:`n`n" rpcScriptPath, "Error", 16
        if (richPresenceEnabled)
            ToggleRichPresence()
        return
    }

    shell := ComObject("WScript.Shell")
    shell.Environment("Process")["PYTHONIOENCODING"] := "utf-8"

    if (useCompiledExe)
        cmd := '"' rpcScriptPath '"'
    else
        cmd := Format('"{1}" -u "{2}"', pythonExe, rpcScriptPath)

    rpcProc := shell.Exec(cmd)
    SetTimer HeartbeatDiscordRPC, 1234
}

StopDiscordRPC(*) {
    global rpcProc

    SetTimer HeartbeatDiscordRPC, 0

    if (IsObject(rpcProc))
        CallDiscordRPC(Map("request_type", "STOP"), false, true)

    rpcProc := 0
}

KillDiscordRPC() {
    global rpcProc
    SetTimer HeartbeatDiscordRPC, 0
    pid := 0
    try pid := rpcProc.ProcessID
    catch {
        rpcProc := 0
        return
    }

    rpcProc := 0
    if pid
        try ProcessClose(pid)

}

RestartDiscordRPC() {
    StopDiscordRPC()
    Sleep 50
    StartDiscordRPC()
}

; =========================
; CORE CALL
; =========================

LastDiscordCallFinished(timeout := 1000) {
    global rpcCallInProgress

    ToolTip("", , , 10)
    start := A_TickCount
    while (rpcCallInProgress) {
        if (A_TickCount - start > timeout) {
            ShowCenteredToolTip "Timeout waiting for last Discord RPC call to finish"
            SetTimer(() => ToolTip("", , , 10), -2000)
            return false
        }
        Sleep 100
    }
    ; ShowCenteredToolTip "Helper is ready for new requests", 15, 500
    return true
}

CallDiscordRPC(params, waitForResponse := true, killCall := false) {
    global rpcProc, rpcCallInProgress

    if (!IsObject(rpcProc))
        StartDiscordRPC()

    if (!killCall && (rpcCallInProgress || isShuttingDown))
        return ""

    rpcCallInProgress := true
    try {
        req := "{"

        first := true

        for key, value in params {
            if (!first)
                req .= ","

            if (Type(value) = "String") {
                safe := StrReplace(value, '"', '\"')
                req .= '"' key '":"' safe '"'
            } else {
                req .= '"' key '":' value
            }

            first := false
        }

        req .= "}"

        try {
            rpcProc.StdIn.WriteLine(req)
        } catch {
            if (isShuttingDown)
                return "RPC_SHUTDOWN"

            RestartDiscordRPC()
            rpcCallInProgress := false

            try rpcProc.StdIn.WriteLine(req)
            catch as err {
                ShowCenteredToolTip "Failed to write to Discord RPC process: " err.Message, 17
                Sleep 500
                return "RPC_ERROR: " err.Message
            }
        }

        if (!waitForResponse) {
            rpcCallInProgress := false
            return ""
        }

        ; optional acknowledgement
        start := A_TickCount

        while (A_TickCount - start < 1000) {
            if (!rpcProc.StdOut.AtEndOfStream)
                return rpcProc.StdOut.ReadLine()

            Sleep 10
        }
        rpcCallInProgress := false
        return "RPC_TIMEOUT"
    } catch as err {
        ShowCenteredToolTip "Error in CallDiscordRPC: " err.Message
        Sleep 500
        ToolTip("", , , 10)
    }
    finally {
        rpcCallInProgress := false
        ; RestartDiscordRPC()
    }
    return "RPC_TIMEOUT"

}

; =========================
; PUBLIC
; =========================

SetDiscordActivity(type, shouldWait := true) {
    return CallDiscordRPC(Map(
        "request_type", type
    ), shouldWait)
}
