#Include "sharedCanonicalHelpers.ahk"

global iniFile := "zSettings.ini"
if !FileExist(iniFile) {
    FileAppend(
        "; ---------------------------`n"
        . "; Hotkey notation reference:`n"
        . "; ^ = Ctrl   → e.g. ^h means Ctrl + H`n"
        . "; ! = Alt    → e.g. !h means Alt + H`n"
        . "; + = Shift  → e.g. +h means Shift + H`n"
        . "; # = Win    → e.g. #h means Win + H`n; `n"
        . "; LButton / RButton / MButton for mouse buttons`n"
        . "; ---------------------------`n`n"
        . "; === vaultOps Options.. Ignore if your script is standalone === `n"
        . "[Options]`n"
        . "NoSave=0`n"
        . "scriptsEnabled=0`n"
        . "heist=1`n"
        . "FingerprintMode=1`n"
        . "Delay=40`n`n"
        . "; ---------------------------`n"
        . "; The hotkeys are in canonical format: vkHHscSSS (e.g., vkDDsc01B for Right Bracket key)`n"
        . "; Please use the vaultOps GUI to change these hotkeys,`n"
        . "; or refer to the documentation for how to customize them in the INI file. `n"
        . "; The default hotkeys are mentioned above each setting for reference. `n"
        . "; ---------------------------`n`n"
        . "; Below are the vaultOps hotkeys.. Ignore if your script is standalone `n"
        . "[ToolHotkeys]`n`n"
        . "; (vkDDsc01B) Physical key: ] (Right Bracket)`n"
        . "NoSave=vkDDsc01B`n`n"
        . "; (vkDBsc01A) Physical key: [ (Left Bracket)`n"
        . "ToggleScripts=vkDBsc01A`n`n"
        . "; Send the PgUp key, used for the Cayo Perico heist.`n"
        . "; Can be set to any key or mouse button based on the notation reference above.`n"
        . "SendPgUp=LButton`n`n"
        . "[Hotkeys]`n`n"
        . "; Enter manual mode for fingerprint/keypad.`n"
        . "; (vk4Dsc032) Physical key: M`n"
        . "Manual=vk4Dsc032`n`n"
        . "; Instantly solve fingerprint/keypad (auto mode).`n"
        . "; (vk48sc023) Physical key: H`n"
        . "AutoHack=vk48sc023`n`n"
        . "; Reset the script's progress and state.`n"
        . "; (vk52sc013) Physical key: R`n"
        . "Reset=vk52sc013`n`n"
        . "; Terminate the script completely (For standalone scripts only).`n"
        . "; (vk54sc014) Physical key: T`n"
        . "Terminate=vk54sc014`n",
        iniFile
    )
}
/** @vaultOps
 *  Boolean state for noSave mode, can be toggled with the assigned hotkey
 */
global noSave := IniRead(iniFile, "Options", "NoSave", 0)

/** @vaultOps
 *  Boolean state for whether the main scripts are enabled, can be toggled with the assigned hotkey
 */
global scriptsEnabled := IniRead(iniFile, "Options", "scriptsEnabled", 0)

/** @vaultOps
 *  Boolean state for the casino mode, 1 for casino, 0 for Cayo Perico.
 */
global heist := IniRead(iniFile, "Options", "heist", 1)

/** @vaultOps
 *  String state that represents the casino mode based on the value of `heist`
 */
global DIAMOND_CASINO := 1

/** @vaultOps
 *  String state that represents the cayo perico heist based on the value of `heist`
 */
global CAYO_PERICO := 0

/** @vaultOps
 *  Boolean state that determines the type of hack, 1 for fingerprint hacking, 0 for keypad.
 */
global fingerprintMode := IniRead(iniFile, "Options", "FingerprintMode", 1)

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

/** @vaultOps
 *  Hotkey to send the PgUp key (Cayo Perico only)
 */
global sendPgUpKey := NormalizeHotkeyValue(IniRead(iniFile, "ToolHotkeys", "SendPgUp", "LButton"), "SendPgUp",
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