#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "ToolTip", "Screen"

#include ../sharedCanonicalHelpers.ahk
#Include ../pureCommonFuncs.ahk

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please run it again with the correct privileges.",
            "Error", 48
    }
    ExitApp
}

global AppDataDir := A_AppData "\vaultOps"
global settingsBackup := AppDataDir "\zUtilSettings.ini"
global dir := A_ScriptDir
global iniFile := dir "\zUtilSettings.ini"
global debug := !A_IsCompiled

EnsureSettingsFile()

/**
 * Set the Tooltip anchor position.
 * 1 = Top Left, 2 = Middle Left, 3 = Bottom Left
 * 4 = Top Right, 5 = Middle Right, 6 = Bottom Right
 * 1 is the default position (Top Left)
 */
global toolTipPos := IniRead(iniFile, "Options", "ToolTipPos", "1")

/**
 * Vertical offset (in pixels) applied to the tooltip from the selected anchor position<br>
 * Negative values move the tooltip upward<br>
 * Positive values move the tooltip downward<br>
 * Zero is the default position, which is the exact anchor position
 */
global tooltipYOffset := IniRead(iniFile, "Options", "ToolTipYOffset", "0")

; Hotkey to reset the script's state and progress, useful if something gets stuck or goes wrong.
; (vk52sc013 - physical R key)
global resetKey := NormalizeHotkeyValue(IniRead(iniFile, "Utility", "Reset", "vk52sc013"), "Reset", "Utility")

; Hotkey to terminate the script completely (For standalone scripts only).
; (vk54sc014 - physical T key)
global terminateKey := NormalizeHotkeyValue(IniRead(iniFile, "Utility", "Terminate", "vk54sc014"), "Terminate",
"Utility")

; Hotkey to toggle utility script functionality
; (vk08sc00E - physical Backspace key)
global toggleHotkey := NormalizeHotkeyValue(IniRead(iniFile, "Utility", "Toggle", "vk08sc00E"), "Toggle", "Utility")

; Hotkey used by the AFK helper script to hold a user-chosen movement key.
global afkKey := NormalizeHotkeyValue(IniRead(iniFile, "Utility", "afkKey", ""), "afkKey", "Utility")

; Delay in seconds for the AFK helper script to send the anti-AFK key, can be set in the INI file.
global afkDelay := IniRead(iniFile, "Utility", "afkDelay", -1)

try {
    Hotkey("~*" CanonicalToRegistration(terminateKey), Terminate, "On")
} catch as e {
    MsgBox "Failed to register Terminate hotkey:`n" e.Message, "Hotkey Registration Failed", 48
    ExitApp
}

FocusGtaIfRunning()

CreateDefaultSettings() {

    FileAppend(
        "; ---------------------------`n"
        . "; Hotkey notation reference:`n"
        . "; ^ = Ctrl   → e.g. ^h means Ctrl + H`n"
        . "; ! = Alt    → e.g. !h means Alt + H`n"
        . "; + = Shift  → e.g. +h means Shift + H`n"
        . "; # = Win    → e.g. #h means Win + H`n; `n"
        . "; LButton / RButton / MButton for mouse buttons`n"
        . "; ---------------------------`n`n"
        . "[Options]`n"
        . "; ToolTip position: 1=Top Left, 2=Middle Left, 3=Bottom Left, 4=Top Right, 5=Middle Right, 6=Bottom Right`n"
        . "ToolTipPos=1`n"
        . "; Vertical offset (in pixels) applied to the tooltip from the selected anchor position`n"
        . "ToolTipYOffset=0`n`n"
        . "; ---------------------------`n"
        . "; The hotkeys are in canonical format: vkHHscSSS (e.g., vkDDsc01B for Right Bracket key)`n"
        . "; Please use the vaultOps GUI to change these hotkeys,`n"
        . "; or refer to the documentation for how to customize them in the INI file.`n"
        . "; The default hotkeys are mentioned above each setting for reference.`n"
        . "; ---------------------------`n`n"
        . "; === Utility Hotkeys ===`n"
        . "[Utility]`n`n"
        . "; Global hotkey to toggle utility scripts.`n"
        . "; (vk08sc00E) Physical key: Backspace`n"
        . "Toggle=vk08sc00E`n`n"
        . "; Reset the script's progress and state.`n"
        . "; (vk52sc013) Physical key: R`n"
        . "Reset=vk52sc013`n`n"
        . "; Terminate the script completely.`n"
        . "; (vk54sc014) Physical key: T`n"
        . "Terminate=vk54sc014`n`n"
        . "; AFK helper key used by the standalone AFK holder script.`n"
        . "; Leave blank to be prompted on first launch.`n"
        . "afkKey="
        . "`n`n; Delay in seconds for the AFK helper script to send the anti-AFK key:`n"
        . "afkDelay=60`n`n"
        . "; Triggerbot pixel values`n"
        . "targetR=193`n"
        . "targetG=79`n"
        . "targetB=79`n",
        iniFile
    )
}

EnsureSettingsFile() {
    global iniFile, AppDataDir, settingsBackup

    ; local file already exists
    if FileExist(iniFile)
        return

    ; restore from AppData backup
    if FileExist(settingsBackup) {
        FileCopy(settingsBackup, iniFile, true)
        return
    }

    ; create fresh defaults
    CreateDefaultSettings()
}

PersistSettingsToAppData(*) {
    global iniFile, AppDataDir, settingsBackup

    try {
        if !DirExist(AppDataDir)
            DirCreate(AppDataDir)

        if FileExist(iniFile)
            FileCopy(iniFile, settingsBackup, true)
    }
}

ReloadScript(*) {
    Reload
}

GtaNotRunning() {
    if !getGtaHwnd() {
        ShowCenteredToolTip "GTA not detected. Script can only be used when GTA is running", 1
        SetTimer UpdateTooltip, -5000
        return true
    }
    return false
}

isGtaFocusedForUtilities(showWarning := true) {
    if (GtaNotRunning()) {
        return false
    }
    gtaActive := (WinActive(GTA_LEGACY_EXE) || WinActive(GTA_ENHANCED_EXE))
    if (!gtaActive && showWarning) {
        ShowCenteredToolTip "GTA is not the active window. Please focus GTA to use this utility", 1
        SetTimer UpdateTooltip, -5000
    }
    return gtaActive
}
