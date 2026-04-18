global folder := A_ScriptDir "\" A_ScreenWidth "x" A_ScreenHeight "\"
if !FileExist(folder "1.bmp")
    global folder := A_ScriptDir "\..\..\" A_ScreenWidth "x" A_ScreenHeight "\"

if !FileExist(folder "1.bmp") {
    ToolTip("Unsuported Resolution", A_ScreenWidth // 2 - 20, 0, 20)
    Sleep 4000
    ToolTip("Exiting script", A_ScreenWidth // 2 - 20, 0, 20)
    Sleep 4000
    ExitApp
}

global iniFile := "settings.ini"
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
        . "; === Below are the vaultOps hotkeys.. Ignore if your script is standalone === `n"
        . "[ToolHotkeys]`n"
        . "NoSave=]`n"
        . "ToggleScripts=[`n"
        . "; Send the PgUp key, used for the Cayo Perico heist.`n"
        . "; Can be set to any key or mouse button based on the notation reference above.`n"
        . "SendPgUp=LButton`n`n"
        . "[Hotkeys]`n"
        . "; Enter manual mode for fingerprint/keypad.`n"
        . "Manual=m`n"
        . "; Instantly solve fingerprint/keypad (auto mode).`n"
        . "AutoHack=h`n"
        . "; Reset the script's progress and state.`n"
        . "Reset=r`n"
        . "; Terminate the script completely (For standalone scripts only).`n"
        . "Terminate=t`n",
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
 * to trigger the replay glitch.
 */
global noSaveKey := IniRead(iniFile, "ToolHotkeys", "NoSave", "]")

/** @vaultOps
 *  Hotkey to toggle the main scripts on/off
 */
global toggleScriptsKey := IniRead(iniFile, "ToolHotkeys", "ToggleScripts", "[")

/** @vaultOps
 *  Hotkey to send the PgUp key (Cayo Perico only)
 */
global sendPgUpKey := IniRead(iniFile, "ToolHotkeys", "SendPgUp", "LButton")

; Delay (in ms) between key-presses, can be adjusted in the GUI (if using vaultOps)
; or directly in the INI file. Lower values will speed up the hack but may cause it
; to be less reliable, especially on slower computers.
global delay := IniRead(iniFile, "Options", "Delay", 40)

; Hotkey to trigger manual mode for either of the modes.
global manualKey := IniRead(iniFile, "Hotkeys", "Manual", "m")

; Hotkey to trigger auto mode for either of the modes, to instantly solve the puzzle.
global autoHackKey := IniRead(iniFile, "Hotkeys", "AutoHack", "h")

; Hotkey to reset the script's state and progress, useful if something gets stuck or goes wrong.
global resetKey := IniRead(iniFile, "Hotkeys", "Reset", "r")

; Hotkey to terminate the script completely (For standalone scripts only).
global terminateKey := IniRead(iniFile, "Hotkeys", "Terminate", "t")

global debug := !A_IsCompiled