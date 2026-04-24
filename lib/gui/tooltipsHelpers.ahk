; Clears all tooltips by either calling the
; worker function directly (if scripts are enabled)
; or setting a timer to call it after 1 second
; (if scripts are not enabled).
clearAllToolTips(scriptsEnabled) {
    scriptsEnabled ? clearToolTipsWorker() : SetTimer(clearToolTipsWorker, -1000)
}

clearToolTipsWorker() {
    loop 19
        ToolTip("", 0, 0, A_Index)
}

; MakeAllToolTipsClickThrough(isIdle, opacity := 230) Moved to commonFuncs.ahk
