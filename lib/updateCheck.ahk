#Requires AutoHotkey v2.0
#Include checkResolution.ahk
#Include pureCommonFuncs.ahk
#Include validateFiles.ahk

CoordMode "ToolTip", "Screen"

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}

global ver := "4.69.99"
global isBeta := false

MAJOR_UPDATE_REQUIRED := 3
PARTIAL_BUT_MANDATORY := 2
PARTIAL_UPDATE_REQUIRED := 1
NO_UPDATE_REQUIRED := 0
global trimmedVer := ""
global isStandaloneScript := isStandalone()
isNoSaveStandalone := isStandaloneScript && InStr(A_ScriptName, "NoSave")
if !IsSet(vaultOps)
    global vaultOps := false

if (!isNoSaveStandalone)
    validataFiles(dir)

CheckForUpdate()
checkResolution()

CheckForUpdate() {
    global ver, iniFile
    static updateHttpTimeoutMs := 1000

    disableUpdates := false
    if (IsSet(iniFile) && iniFile) {
        disableUpdates := IniRead(iniFile, "Options", "DisableUpdates", "0")
    }

    ShowCenteredToolTip "checking for updates"

    raw := "https://raw.githubusercontent.com/infpdev/gtao-heist-toolkit/main/lib/version.txt"
    Url := raw "?nocache=1"
    Http := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        Http.Open("GET", Url, false)
        Http.SetTimeouts(updateHttpTimeoutMs, updateHttpTimeoutMs, updateHttpTimeoutMs, updateHttpTimeoutMs)
        Http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        Http.Send()
        if (Http.Status >= 200 && Http.Status < 300) {
            result := Trim(Http.ResponseText)
            lines := StrSplit(result, "`n")
            fetchedVersion := Trim(lines[1])
            currentPatch := GetPatchFromVersion(ver)
            fetchedPatch := GetPatchFromVersion(fetchedVersion)

            fetchedNews := ""
            loop (lines.Length) {
                if (A_Index > 1)
                    fetchedNews .= Trim(lines[A_Index]) "`n"
            }
            if (fetchedNews != "")
                fetchedNews := "What's new:`n`n" fetchedNews "`n"

            UPDATE_PRIORITY := VersionCompare(fetchedVersion, ver, fetchedPatch, currentPatch)

            if (UPDATE_PRIORITY != NO_UPDATE_REQUIRED) {
                mjrMsg :=
                    "Update available!`nA new version has been released.`n`nPlease update the app to continue using it.`n`n"
                patchVer := "Patch " fetchedPatch " released!`n`n"
                patchMsg := patchVer . "You can skip it, but updating will fix existing bugs.`n`n"
                updInstrMsg :=
                    "Would you like to see the update instructions?`n`ngithub.com/infpdev/gtao-heist-toolkit"

                msg := ver " ➤ " fetchedVersion "`n`n"

                if (UPDATE_PRIORITY = MAJOR_UPDATE_REQUIRED)
                    msg .= mjrMsg . fetchedNews . updInstrMsg
                else if (UPDATE_PRIORITY = PARTIAL_UPDATE_REQUIRED)
                    msg .= patchMsg . fetchedNews
                        . (!isNoSaveStandalone ? "Would you like to auto-update now?" : updInstrMsg)
                else if (UPDATE_PRIORITY = PARTIAL_BUT_MANDATORY)
                    msg .= patchVer . "This update is required to continue using the app.`n`n" . fetchedNews
                        . (!isNoSaveStandalone ? "Would you like to auto-update now?" : updInstrMsg)

                if (disableUpdates) {

                    ShowCenteredToolTip "v" fetchedVersion " available • updates disabled"

                    Sleep 2000

                    ShowCenteredToolTip "Running outdated builds may cause issues"

                    Sleep 1000

                    ToolTip "", , , 10

                    return
                }

                result := MsgBox(msg, "Update Check", 0x4) ; 0x4 = Yes/No
                if (result = "Yes") {
                    if ((UPDATE_PRIORITY = PARTIAL_UPDATE_REQUIRED || UPDATE_PRIORITY = PARTIAL_BUT_MANDATORY) &&
                    A_IsCompiled && !isNoSaveStandalone)
                        autoUpdate()
                    else
                        Run "https://infpdev.netlify.app?vaultOps=" . (isNoSaveStandalone || isStandaloneScript ? "3" :
                            "2")
                    ExitApp
                }

                if (UPDATE_PRIORITY = MAJOR_UPDATE_REQUIRED || UPDATE_PRIORITY = PARTIAL_BUT_MANDATORY)
                    ExitApp
            }
            else {
                ShowCenteredToolTip("No updates found. Enjoy :)")
                SetTimer(() => ToolTip("", , , 10), -1000)
            }
        }
        else {
            MsgBox("HTTP Error: " Http.Status, "Update Check Failed")
            return
        }

    }
    catch as err {
        if (disableUpdates) {
            ShowCenteredToolTip "Failed to check for updates • updates disabled"
            Sleep 2000
            ToolTip "", , , 10
            return
        }

        ShowCenteredToolTip "Failed to check for updates: " err.Message
        Sleep 2000
        ToolTip "", , , 10
        return
        ; msg := "v" ver "`n`nFailed to check for updates.`n`n"
        ;     . "If you think this is an error, please download the latest version manually.`n`n"
        ;     . "Do you want to see the update instructions?"
        ; res := MsgBox(msg, "Failed to Check For Updates", "YesNo Default2 T15 " . 0x10)
        ; if (res = "Yes") {
        ;     Run "https://infpdev.netlify.app?vaultOps=" . (isNoSaveStandalone ? "3" : "2")
        ; }
        ; ExitApp
    }
}

VersionCompare(fetched, current, fetchedPatch, currentPatch) {
    global trimmedVer
    fetched := StrSplit(fetched, ".")
    current := StrSplit(current, ".")
    trimmedVer := current[1] "." current[2]

    loop 2 {
        n1 := fetched[A_Index] ? fetched[A_Index] : 0
        n2 := current[A_Index] ? current[A_Index] : 0
        if (n1 > n2) {
            return MAJOR_UPDATE_REQUIRED
        }
        else if (n1 < n2)
            return NO_UPDATE_REQUIRED
    }

    if (fetchedPatch > currentPatch) {
        if (fetchedPatch - currentPatch > 1)
            return PARTIAL_BUT_MANDATORY
        else
            return PARTIAL_UPDATE_REQUIRED
    }
    return 0
}

GetPatchFromVersion(versionText) {
    parts := StrSplit(Trim(versionText), ".")
    if (parts.Length >= 3)
        return Integer(parts[3])
    return 0
}

autoUpdate() {
    global isStandaloneScript
    updaterPath := isStandaloneScript
        ? A_ScriptDir "\lib\standaloneUpdater.exe"
            : A_ScriptDir "\lib\vaultOpsUpdater.exe"
    if FileExist(updaterPath)
        Run('*RunAs "' updaterPath '" "' A_ScriptFullPath '"', , "Hide")
    else
        MsgBox("Updater executable not found.`n" updaterPath, "Update Check", 48)
    ExitApp
}

isStandalone() {
    return !FileExist(A_ScriptDir "\lib\vaultOpsUpdater.exe")
}
