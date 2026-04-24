; ⏐==========================================================================================================⏐
; ⏐=================================== CANONICAL HOTKEY FORMAT HELPERS =======================================⏐
; ⏐==========================================================================================================⏐
{
    /**
     * @description Detects if a hotkey value is in canonical format (vk/sc based)
     * @param {string} value - Hotkey value to check
     * @returns {boolean} True if canonical format detected
     */
    IsCanonicalHotkey(value) {
        value := Trim(value)
        if (value = "")
            return false

        idx := 1
        while (idx <= StrLen(value)) {
            ch := SubStr(value, idx, 1)
            if (ch = "^" || ch = "+" || ch = "!") {
                idx++
                continue
            }
            break
        }

        keyPart := SubStr(value, idx)
        if (keyPart = "")
            return false

        if RegExMatch(keyPart, "^(vk[0-9A-Fa-f]{2}|sc[0-9A-Fa-f]{3})") {
            return true
        }

        if RegExMatch(keyPart, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$"
        ) {
            return true
        }

        return false
    }

    ; Converts a user-friendly display string back to canonical format
    ; Examples: "Ctrl+Shift+A" → "^+vk41sc030", "Alt+LButton" → "!LButton"
    ; Returns empty string if input is invalid.
    DisplayToCanonical(displayValue) {
        display := Trim(displayValue)
        if (display = "")
            return ""

        if (SubStr(display, -1) = "+")
            return ""

        tokens := StrSplit(display, "+")
        if (tokens.Length = 0)
            return ""

        key := Trim(tokens[tokens.Length])
        if (key = "")
            return ""

        if RegExMatch(key, "i)^(ctrl|control|shift|alt)$")
            return ""

        mods := ""
        loop (tokens.Length - 1) {
            t := Trim(tokens[A_Index])
            if (t = "")
                continue
            if RegExMatch(t, "i)^(ctrl|control)$") {
                if !InStr(mods, "^")
                    mods .= "^"
                continue
            }
            if RegExMatch(t, "i)^shift$") {
                if !InStr(mods, "+")
                    mods .= "+"
                continue
            }
            if RegExMatch(t, "i)^alt$") {
                if !InStr(mods, "!")
                    mods .= "!"
                continue
            }
            return ""
        }

        if RegExMatch(key, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$") {
            return mods key
        }

        vkCode := GetKeyVK(key)
        scCode := GetKeySC(key)

        if (vkCode = 0 || scCode = 0)
            return ""

        vkStr := Format("vk{:02X}", vkCode)
        scStr := Format("sc{:03X}", scCode)

        return mods vkStr scStr
    }

    CanonicalToRegistration(canonical) {
        canonical := Trim(canonical)
        if (canonical = "")
            return ""

        mods := ""
        idx := 1
        while (idx <= StrLen(canonical)) {
            ch := SubStr(canonical, idx, 1)
            if (ch = "^" || ch = "+" || ch = "!") {
                mods .= ch
                idx++
                continue
            }
            break
        }

        keyPart := SubStr(canonical, idx)
        if RegExMatch(keyPart, "^vk[0-9A-Fa-f]{2}sc([0-9A-Fa-f]{3})$", &m)
            return mods "sc" m[1]
        return mods keyPart
    }

    ; Helper function: Normalize hotkey value from INI (convert legacy AHK to canonical)
    NormalizeHotkeyValue(iniValue, keyName, section) {
        global iniFile

        iniValue := Trim(iniValue)
        if (iniValue = "")
            return iniValue

        if IsCanonicalHotkey(iniValue)
            return iniValue

        ; Try to convert legacy AHK format to canonical
        canonical := LegacyAHKToCanonical(iniValue)
        if (canonical != "") {
            ; Conversion succeeded, write back to INI
            IniWrite(canonical, iniFile, section, keyName)
            return canonical
        }

        ; Conversion failed, return original and mark for user action
        ; (Will be handled by registration error handling in TryRegisterHotkeys)
        return iniValue
    }

}

; ⏐==========================================================================================================⏐
; ⏐======================================= LEGACY HOTKEY HANDLING ===========================================⏐
; ⏐==========================================================================================================⏐
{

    ; Converts legacy AHK format (^+a) to canonical format (^+vk41sc030)
    ; Used for migration of old INI values to canonical format
    LegacyAHKToCanonical(ahkValue) {
        ahkValue := Trim(ahkValue)
        if (ahkValue = "")
            return ""

        ; If already canonical, return as-is
        if IsCanonicalHotkey(ahkValue)
            return ahkValue

        mods := ""
        idx := 1
        while (idx <= StrLen(ahkValue)) {
            ch := SubStr(ahkValue, idx, 1)
            if (ch = "^" || ch = "+" || ch = "!") {
                mods .= ch
                idx++
                continue
            }
            break
        }

        keyPart := SubStr(ahkValue, idx)
        if (keyPart = "")
            return ""

        ; Handle mouse buttons (already canonical format)
        if RegExMatch(keyPart, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$"
        ) {
            return mods keyPart
        }

        ; Convert key name to vk/sc
        vkCode := GetKeyVK(keyPart)
        scCode := GetKeySC(keyPart)

        if (vkCode = 0 || scCode = 0)
            return ""  ; Invalid key

        vkStr := Format("vk{:02X}", vkCode)
        scStr := Format("sc{:03X}", scCode)

        return mods vkStr scStr
    }

}

; ⏐==========================================================================================================⏐
; ⏐====================================== VIRTUAL KEY CODE HELPERS ==========================================⏐
; ⏐==========================================================================================================⏐
{

    ; Gets the virtual key code from a key name
    GetKeyVK(keyName) {
        ; Mouse buttons have fixed codes
        switch keyName {
            case "LButton": return 0x01
            case "RButton": return 0x02
            case "MButton": return 0x04
            case "XButton1": return 0x05
            case "XButton2": return 0x06
        }

        try {
            loop 255 {
                vk := A_Index
                if (GetKeyName(Format("vk{:02X}", vk)) = keyName)
                    return vk
            }
        }

        return 0
    }

    ; Gets the scan code from a key name
    GetKeySC(keyName) {
        ; Mouse buttons don't have scan codes
        switch keyName {
            case "LButton", "RButton", "MButton", "XButton1", "XButton2": return 0
        }

        try {
            loop 128 {
                sc := A_Index - 1
                if (GetKeyName(Format("sc{:03X}", sc)) = keyName)
                    return sc
            }
        }

        return 0
    }
}
