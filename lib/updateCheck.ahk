#Requires AutoHotkey v2.0
#Include checkResolution.ahk
#Include commonFuncs.ahk

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}

ver := "3.5.0"

MAJOR_UPDATE_REQUIRED := 2
PARTIAL_UPDATE_REQUIRED := 1
NO_UPDATE_REQUIRED := 0
global trimmedVer := ""
global isBeta := false
global isStandaloneScript := isStandalone()
if !IsSet(vaultOps)
    global vaultOps := false

CheckForUpdate()
checkResolution()

CheckForUpdate() {
    global ver
    updateHttpTimeoutMs := 5000

    ShowCenteredToolTip("checking for updates", 17)

    Url :=
        "https://raw.githubusercontent.com/infpdev/gtao-heist-toolkit/refs/heads/main/lib/version.txt?nocache=1"
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
                fetchedNews := "What's new:`n" fetchedNews "`n"

            UPDATE_PRIORITY := VersionCompare(fetchedVersion, ver, fetchedPatch, currentPatch)

            if (UPDATE_PRIORITY != NO_UPDATE_REQUIRED) {
                mjrMsg :=
                    "Update available!`nA new version has been released.`n`nPlease update the app to continue using it.`n`n"
                patchMsg := "Patch " fetchedPatch " released!`n`nYou can skip it, but updating will fix existing bugs.`n`n"

                msg := ver " ➤ " fetchedVersion "`n`n"

                if (UPDATE_PRIORITY = MAJOR_UPDATE_REQUIRED)
                    msg .= mjrMsg . fetchedNews .
                        "Would you like to see the update instructions?`n`ngithub.com/infpdev/gtao-heist-toolkit"
                else if (UPDATE_PRIORITY = PARTIAL_UPDATE_REQUIRED)
                    msg .= patchMsg . fetchedNews
                        . (!isStandaloneScript ? "Would you like to auto-update now?" :
                            "Would you like to see the update instructions?`n`ngithub.com/infpdev/gtao-heist-toolkit")

                result := MsgBox(msg, "Update Check", 0x4) ; 0x4 = Yes/No
                if (result = "Yes") {
                    if (UPDATE_PRIORITY = PARTIAL_UPDATE_REQUIRED && A_IsCompiled)
                        autoUpdate()
                    else
                        Run "https://infpdev.netlify.app?vaultOps=" . (isStandaloneScript ? "3" : "2")
                    ExitApp
                }

                if (UPDATE_PRIORITY = MAJOR_UPDATE_REQUIRED)
                    ExitApp
            }
            else {
                ShowCenteredToolTip("No updates found. Enjoy :)", 17)
                Sleep 1000
                ToolTip("", , , 17)
            }
        }
        else {
            MsgBox("HTTP Error: " Http.Status, "Update Check Failed")
            return
        }

    }
    catch {
        msg := "v" ver "`n`nFailed to check for updates.`n`n"
            . "If you think this is an error, please download the latest version manually.`n`n"
            . "Do you want to see the update instructions?"
        res := MsgBox(msg, "Failed to Check For Updates", "YesNo Default2 T15 " . 0x10)
        if (res = "Yes") {
            Run "https://infpdev.netlify.app?vaultOps=" . (isStandaloneScript ? "3" : "2")
        }
        ExitApp
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

    if (fetchedPatch > currentPatch)
        if (fetchedPatch - currentPatch > 2)
            return MAJOR_UPDATE_REQUIRED
        else
            return PARTIAL_UPDATE_REQUIRED
    return 0
}

GetPatchFromVersion(versionText) {
    parts := StrSplit(Trim(versionText), ".")
    if (parts.Length >= 3)
        return Integer(parts[3])
    return 0
}

autoUpdate() {
    updaterPath := A_ScriptDir "\lib\vaultOpsUpdater.exe"
    if FileExist(updaterPath)
        Run('*RunAs "' updaterPath '" "' A_ScriptFullPath '"', , "Hide")
    else
        MsgBox("Updater executable not found.`n" updaterPath, "Update Check", 48)
    ExitApp
}

isStandalone() {
    return !FileExist(A_ScriptDir "\lib\vaultOpsUpdater.exe")
}
