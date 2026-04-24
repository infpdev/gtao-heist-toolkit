#Requires AutoHotkey v2.0
#Include commonFuncs.ahk

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}

ver := "3.2.0"
MAJOR_UPDATE_REQUIRED := 2
PARTIAL_UPDATE_REQUIRED := 1
NO_UPDATE_REQUIRED := 0
global trimmedVer := ""
global isUnreleased := false
if !IsSet(vaultOps)
    global vaultOps := false

CheckForUpdate() {
    global ver
    updateHttpTimeoutMs := 5000

    ShowCenteredToolTip("checking for updates", 17)

    Url := "https://raw.githubusercontent.com/infpdev/gtao-heist-toolkit/main/lib/version.txt?nocache=1"
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

            fetchedNews := ""
            loop (lines.Length) {
                if (A_Index > 1)
                    fetchedNews .= Trim(lines[A_Index]) "`n"
            }
            if (fetchedNews != "")
                fetchedNews := "What's new:`n" fetchedNews "`n"

            UPDATE_PRIORITY := VersionCompare(fetchedVersion, ver)

            if (UPDATE_PRIORITY != NO_UPDATE_REQUIRED) {
                msg := ver " ➤ " fetchedVersion "`n`n"
                    . (UPDATE_PRIORITY == MAJOR_UPDATE_REQUIRED ?
                        "Update available!`nA new version has been released.`n`nPlease update the app to continue using it.`n`n"
                        . fetchedNews
                        . "Would you like to see the update instructions?`n`ngithub.com/infpdev/gtao-heist-toolkit"
                            :
                            "Update available!`nA new version has been released.`n`nPlease update the app to stop seeing this message.`n`n"
                            . fetchedNews
                            . "Would you like to see the update instructions?`n`ngithub.com/infpdev/gtao-heist-toolkit"
                    )
                result := MsgBox(msg, "Update Check", 0x4) ; 0x4 = Yes/No
                if (result = "Yes") {
                    Run "https://github.com/infpdev/gtao-heist-toolkit/blob/main/HOW-TO-UPDATE.md"
                }

                if (UPDATE_PRIORITY = MAJOR_UPDATE_REQUIRED)
                    ExitApp
            } else {
                ShowCenteredToolTip("No updates found. Enjoy :)", 17)
                Sleep 1000
                ToolTip("", , , 17)
            }
        } else {
            MsgBox("HTTP Error: " Http.Status, "Update Check Failed")
            return
        }

    } catch {
        msg := "v" ver "`n`nFailed to check for updates.`n`n"
            . "If you think this is an error, please download the latest version manually.`n`n"
            . "Do you want to see the update instructions?"
        res := MsgBox(msg, "Failed to Check For Updates", "YesNo Default2 T15 " . 0x10)
        if (res = "Yes") {
            Run "https://github.com/infpdev/gtao-heist-toolkit/blob/main/HOW-TO-UPDATE.md"
        }
        ExitApp
    }
}

VersionCompare(fetched, current) {
    global isUnreleased, trimmedVer
    fetched := StrSplit(fetched, ".")
    current := StrSplit(current, ".")
    ; Set isUnreleased to true if patch (third) value is not 0
    isUnreleased := (current[1] == 0 || (current.Length >= 3 && current[3] != 0))
    trimmedVer := current[1] "." current[2]

    loop 2 {
        n1 := fetched[A_Index] ? fetched[A_Index] : 0
        n2 := current[A_Index] ? current[A_Index] : 0
        if (n1 > n2) {
            if A_Index = 2 {
                if (n1 - n2 > 1)
                    return MAJOR_UPDATE_REQUIRED
                else
                    return PARTIAL_UPDATE_REQUIRED
            }
            return MAJOR_UPDATE_REQUIRED
        }
        else if (n1 < n2)
            return NO_UPDATE_REQUIRED
    }
    return 0
}

CheckForUpdate()