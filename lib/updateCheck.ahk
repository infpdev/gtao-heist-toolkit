#Requires AutoHotkey v2.0

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}

ver := "3.0.0"
global strippedVer := ""
global isUnreleased := false
if !IsSet(vaultOps)
    global vaultOps := false

CheckForUpdate() {
    global ver
    updateHttpTimeoutMs := 5000

    ShowCenteredToolTip("checking for updates", 17)

    Url := "https://pastebin.com/raw/syS1Bk5d"
    Http := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        Http.SetTimeouts(updateHttpTimeoutMs, updateHttpTimeoutMs, updateHttpTimeoutMs, updateHttpTimeoutMs)
        Http.Open("GET", Url, false)
        Http.Send()
        if (Http.Status = 200) {
            result := Trim(Http.ResponseText)
            if (VersionCompare(result, ver) == 1) {
                msg := ver " ➤ " result "`n`n"
                    .
                    "Update available!`nA new version has been released.`n`nWould you like to open the GitHub page?`n`ngithub.com/infpdev/gtao-heist-toolkit"
                result := MsgBox(msg, "Update Check", 0x4) ; 0x4 = Yes/No
                if (result = "Yes") {
                    Run "https://github.com/infpdev/gtao-heist-toolkit"
                }
                ExitApp
            } else {
                ShowCenteredToolTip("No updates found. Enjoy :)", 17)
                Sleep 1000
                ToolTip("", , , 17)
            }
        }
    } catch {
        msg := "v" ver "`n`nNo Internet: You need an internet connection to play GTAO.`n`n"
            . "If you think this is an error, please download the latest version manually.`n`n"
            . "Do you want to open the GitHub page to download it?"
        res := MsgBox(msg, "Failed to Check For Updates", "YesNo Default2 T15 " . 0x10)
        if (res = "Yes") {
            Run "https://github.com/infpdev/gtao-heist-toolkit"
        }
        ExitApp
    }
}

VersionCompare(fetched, current) {
    global isUnreleased, strippedVer
    fetched := StrSplit(fetched, ".")
    current := StrSplit(current, ".")
    ; Set isUnreleased to true if patch (third) value is not 0
    isUnreleased := (current[1] == 0 || (current.Length >= 3 && current[3] != 0))
    strippedVer := current[1] "." current[2]

    loop 2 {
        n1 := fetched[A_Index] ? fetched[A_Index] : 0
        n2 := current[A_Index] ? current[A_Index] : 0
        if (n1 > n2)
            return 1
        else if (n1 < n2)
            return -1
    }
    return 0
}

CheckForUpdate()