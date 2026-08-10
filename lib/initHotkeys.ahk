#Include sharedCanonicalHelpers.ahk
#Include pureCommonFuncs.ahk

; VaultOps app data directory and settings backup path
global AppDataDir := A_AppData "\vaultOps"
global settingsBackup := AppDataDir "\zSettings.ini"

if !HasVaultOpsMarkers(DirGetParent(A_ScriptDir))
    global dir := A_ScriptDir
else
    global dir := DirGetParent(A_ScriptDir)
global iniFile := dir "\zSettings.ini"

EnsureSettingsFile()

; =============================== Boolean Flags ===============================

/** @vaultOps
 *  Boolean state for noSave mode, can be toggled with the assigned hotkey<br>
 * Resets to false on exit.
 */
global noSave := 0

/** @vaultOps
 *  Boolean state for whether the main scripts are enabled, can be toggled with the assigned hotkey<br>
 * Resets to false on exit.
 */
global scriptsEnabled := 0

/** @vaultOps
 *  String state that represents the casino mode based on the value of `heist`
 */
global DCH_OR_KORTZ := 1

/** @vaultOps
 *  String state that represents the cayo perico heist based on the value of `heist`
 */
global CAYO_PERICO := 0

/** @vaultOps
 *  Boolean state that represents the AHK detection (0)
 */
global AHK_ENGINE := 0

/** @vaultOps
 *  Boolean state that represents the OpenCV detection (1)
 */
global OPENCV_ENGINE := 1

; Used to prevent OpenCV callbacks from running while the script is exiting
global isShuttingDown := false

; =============================== Ini variables ===============================

/**
 * Set the Tooltip anchor position.
 * 1 = Top Left, 2 = Middle Left, 3 = Bottom Left
 * 4 = Top Right, 5 = Middle Right, 6 = Bottom Right
 * 4 is the default position (Top Right)
 */
global toolTipPos := Integer(IniRead(iniFile, "Options", "ToolTipPos", "4"))

/**
 * Vertical offset (in pixels) applied to the tooltip from the selected anchor position<br>
 * Negative values move the tooltip upward<br>
 * Positive values move the tooltip downward<br>
 * Zero is the default position, which is the exact anchor position
 */
global tooltipYOffset := Integer(IniRead(iniFile, "Options", "ToolTipYOffset", "0"))

; Boolean state for whether the NoSave tooltip is enabled, can be toggled in the GUI
global noSaveTooltip := Integer(IniRead(iniFile, "Options", "NoSaveTooltip", 1))

/** Boolean state for whether ledge grab automation is enabled, can be toggled in the GUI
 */
global ledgeGrabEnabled := Integer(IniRead(iniFile, "Options", "ledgeGrab", 0))

/** Hotkey to toggle the ledge grab automation.
 * (vk51sc010 - physical key is Q)
 */
global ledgeGrabKey := NormalizeHotkeyValue(IniRead(iniFile, "Hotkeys", "LedgeGrab", "vk51sc010"),
"LedgeGrab", "Hotkeys")

/** @vaultOps
 *  Boolean state for the casino mode, 1 for casino, 0 for Cayo Perico.
 */
global heist := IniRead(iniFile, "Options", "heist", 1)

/** @vaultOps
 *  Boolean state that determines the type of hack, 1 for fingerprint hacking, 0 for keypad.
 */
global fingerprintMode := IniRead(iniFile, "Options", "FingerprintMode", 1)

/** @vaultOps
 *  Boolean state that determines the anchor detection engine, 1 for OpenCV, 0 for legacy AHK detection.
 * OpenCV by default.
 */
global engine := IniRead(iniFile, "Options", "Engine", 1)

/** @vaultOps
 *  Boolean state that determines whether rich presence is enabled, 1 for enabled, 0 for disabled.
 */
global richPresenceEnabled := IniRead(iniFile, "Options", "richPresence", 0)

/** @vaultOps
 * Hotkey to toggle noSave mode which prevents the script from saving progress, useful during heists
 * to trigger the replay glitch.<br>
 * (vkDDsc01B - physical key is Right Bracket "]")
 */
global noSaveKey := NormalizeHotkeyValue(IniRead(iniFile, "ToolHotkeys", "NoSave", "vkDDsc01B"), "NoSave",
"ToolHotkeys")

/** @vaultOps
 *  Hotkey to toggle the main scripts on/off <br>
 * (vkDBsc01A - physical key is Left Bracket "[")
 */
global toggleScriptsKey := NormalizeHotkeyValue(IniRead(iniFile, "ToolHotkeys", "ToggleScripts", "vkDBsc01A"),
"ToggleScripts",
"ToolHotkeys")

; Delay (in ms) between key-presses, can be adjusted in the GUI (if using vaultOps)
; or directly in the INI file. Lower values will speed up the hack but may cause it
; to be less reliable, especially on slower computers.
global delay := IniRead(iniFile, "Options", "Delay", 40)

; Hotkey to trigger manual mode for either of the modes.
; (vk4Dsc032 - physical M key)
global manualKey := NormalizeHotkeyValue(IniRead(iniFile, "Hotkeys", "Manual", "vk4Dsc032"), "Manual", "Hotkeys")

; Hotkey to trigger auto mode for either of the modes, to instantly solve the puzzle.
; (vk48sc023 - physical H key)
global autoHackKey := NormalizeHotkeyValue(IniRead(iniFile, "Hotkeys", "AutoHack", "vk48sc023"), "AutoHack", "Hotkeys")

; Hotkey to reset the script's state and progress, useful if something gets stuck or goes wrong.
; (vk52sc013 - physical R key)
global resetKey := NormalizeHotkeyValue(IniRead(iniFile, "Hotkeys", "Reset", "vk52sc013"), "Reset", "Hotkeys")

; Hotkey to terminate the script completely (For standalone scripts only).
; (vk54sc014 - physical T key)
global terminateKey := NormalizeHotkeyValue(IniRead(iniFile, "Hotkeys", "Terminate", "vk54sc014"), "Terminate",
"Hotkeys")

global debug := !A_IsCompiled

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
        . "; === vaultOps options.. Ignore if your script is standalone === `n"
        . "[Options]`n"
        . "heist=1`n"
        . "ledgeGrab=0`n"
        . "FingerprintMode=1`n"
        . "Engine=1`n"
        . "richPresence=0`n"
        . "Delay=40`n`n"
        . "; ToolTip position: 1=Top Left, 2=Middle Left, 3=Bottom Left, 4=Top Right, 5=Middle Right, 6=Bottom Right`n"
        . "ToolTipPos=4`n"
        . "; Vertical offset (in pixels) applied to the tooltip from the selected anchor position`n"
        . "ToolTipYOffset=0`n"
        . "; Shows a green NoSave tooltip while NoSave is enabled.`n"
        . "NoSaveTooltip=1`n`n"
        . "; ---------------------------`n"
        . "; The hotkeys are in canonical format: vkHHscSSS (e.g., vkDDsc01B for Right Bracket key)`n"
        . "; Please use the vaultOps GUI to change these hotkeys,`n"
        . "; or refer to the documentation for how to customize them in the INI file.`n"
        . "; The default hotkeys are mentioned above each setting for reference.`n"
        . "; ---------------------------`n`n"
        . "; Below are the vaultOps hotkeys.. Ignore if your script is standalone`n"
        . "[ToolHotkeys]`n`n"
        . "; (vkDDsc01B) Physical key: ] (Right Bracket)`n"
        . "NoSave=vkDDsc01B`n`n"
        . "; (vkDBsc01A) Physical key: [ (Left Bracket)`n"
        . "ToggleScripts=vkDBsc01A`n`n"
        . "[Hotkeys]`n`n"
        . "; Enter manual mode for fingerprint/keypad.`n"
        . "; (vk4Dsc032) Physical key: M`n"
        . "Manual=vk4Dsc032`n`n"
        . "; Instantly solve fingerprint/keypad (auto mode).`n"
        . "; (vk48sc023) Physical key: H`n"
        . "AutoHack=vk48sc023`n`n"
        . '; In-game keybind used to "Take Cover"`n'
        . "; (vk51sc010) Physical key: Q`n"
        . "LedgeGrab=vk51sc010`n`n"
        . "; Reset the script's progress and state.`n"
        . "; (vk52sc013) Physical key: R`n"
        . "Reset=vk52sc013`n`n"
        . "; Terminate the script completely (For standalone scripts only).`n"
        . "; (vk54sc014) Physical key: T`n"
        . "Terminate=vk54sc014`n`n",
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
