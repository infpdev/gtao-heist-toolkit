; Sends a key press/release event using the native Windows API
SendKeyNative(key, down := true, gtaHwnd := 0) {
    SendKeyBD(key, down)
}

; Sends a key press/release event using keybd_event
SendKeyBD(key, down) {
    vk := GetKeyVK(key)
    sc := GetKeySC(key)
    flags := down ? 0 : 0x2
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", flags, "Ptr", 0)
}

global KB_HookHandle := 0
global KB_CallbackFunc := 0
global ALLOWED_KEY := ""

; Block all keyboard input except one specific key
; keyVKSC: The key to allow (in VKSC format, e.g., "vk4Bsc03B" for 'k')
BlockKeyboardExcept(state, keyVKSC := "") {
    global KB_HookHandle, KB_CallbackFunc, ALLOWED_KEY

    if (state) {
        if (KB_HookHandle)
            return

        ALLOWED_KEY := keyVKSC
        KB_CallbackFunc := CallbackCreate(KeyboardProc, "F", 3)
        hMod := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
        KB_HookHandle := DllCall("SetWindowsHookEx"
            , "Int", 13  ; WH_KEYBOARD_LL
            , "Ptr", KB_CallbackFunc
            , "Ptr", hMod
            , "UInt", 0
            , "Ptr")
    } else {
        if (KB_HookHandle) {
            DllCall("UnhookWindowsHookEx", "Ptr", KB_HookHandle)
            CallbackFree(KB_CallbackFunc)
            KB_HookHandle := 0
            ALLOWED_KEY := ""
        }
    }
}

KeyboardProc(nCode, wParam, lParam) {
    global ALLOWED_KEY
    static LLKHF_INJECTED := 0x10

    if (nCode >= 0) {
        flags := NumGet(lParam, 8, "UInt")
        isInjected := (flags & LLKHF_INJECTED) ? true : false

        ; Get the virtual key code and scan code
        vkCode := NumGet(lParam, 0, "UInt")
        scanCode := NumGet(lParam, 4, "UInt")

        vksc := Format("vk{:02X}sc{:03X}", vkCode, scanCode & 0xFF)

        ; ShowCenteredToolTip "Key pressed: " vksc " Allowed: " ALLOWED_KEY, 17
        if (vksc = ALLOWED_KEY) {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
            ; return SendEvent("{" vksc "}")
        }

        if (isInjected) {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
        }

        ; Block everything else (both physical and injected)
        return 1
    }

    return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
}
