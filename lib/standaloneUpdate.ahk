#Requires AutoHotkey v2.0

global updaterName := "standaloneUpdater.exe"
global updaterTempDir := A_Temp "\vaultOpsUpdate"
global updaterTempExe := updaterTempDir "\" updaterName

relaunchAsAdmin()

currentExePath := A_Args.Length >= 1 ? A_Args[1] : ""
global directUpdate := A_Args.Length >= 2 ? A_Args[2] = "1" : false

if (currentExePath = "" && FileExist(A_ScriptDir "\OpenCV_Engine.exe")) {
    directUpdate := true
    SplitPath(A_ScriptFullPath, , &libDir)
    SplitPath(libDir, , &currentExePath)
}

if (!IsRunningFromTempUpdater()) {
    BootstrapUpdaterToTemp(currentExePath)
    ExitApp
}

if (!directUpdate && (currentExePath = "" || !FileExist(currentExePath))) {
    MsgBox(
        "Standalone executable not found.`nTry:`n1. Putting the updater next to the standalone exe.`n2. Making sure the standalone bundle extracted correctly.",
        "Auto Update", 48)
    ExitApp
}

PerformUpdate(currentExePath)
ExitApp

PerformUpdate(currentExePath) {
    if (directUpdate) {
        currentDir := currentExePath
        SplitPath(currentDir, , &targetDir)
        currentExeName := ""
    } else {
        SplitPath(currentExePath, &currentExeName, &currentDir)
        SplitPath(currentDir, , &targetDir)
    }

    ToolTip("Updating standalone pack", A_ScreenWidth / 2 - 70, 0, 17)

    downloadUrl :=
        "https://github.com/infpdev/gtao-heist-toolkit/releases/latest/download/vaultOps-Standalone-Pack.exe"
    setupName := "vaultOps-Standalone-Pack.exe"

    tempDir := updaterTempDir
    tempSetupPath := tempDir "\" setupName

    try {
        if (!DirExist(tempDir))
            DirCreate(tempDir)

        ; Download the standalone SFX bundle.
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", downloadUrl, false)
        http.SetTimeouts(10000, 10000, 10000, 10000)
        http.Send()

        if (http.Status < 200 || http.Status >= 300) {
            MsgBox("Failed to download the standalone bundle. HTTP Status: " http.Status, "Auto Update", 48)
            ExitApp
        }

        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(http.ResponseBody)
        stream.SaveToFile(tempSetupPath, 2)
        stream.Close()

        if !FileExist(tempSetupPath) {
            res := MsgBox(
                "Failed to download the standalone bundle. Please try updating manually by downloading the latest release from GitHub.`n`nWould you like to open the download page?",
                "Auto Update", 0x4)
            if (res = "Yes")
                Run "https://infpdev.netlify.app?vaultOps=3"
            ExitApp
        }

        RunWait('"' tempSetupPath '" -y -o+ -inul -d"' currentDir '"')

        sleep 1000 ; Wait a moment for the file system to catch up after extraction

        standaloneFolder := "vaultOps-Standalone-Pack"
        extractedExe := targetDir "\" standaloneFolder "\" currentExeName

        if FileExist(extractedExe) {
            Run('"' extractedExe '"')
            ExitApp
        }

        ; Fallback: open extracted folder if the original standalone name no longer exists

        Run('explorer.exe "' currentDir '"')

        if (directUpdate) {
            MsgBox("Standalone pack updated successfully", "Auto Update", 64)
        } else {
            MsgBox(
                "The standalone package was updated successfully, but the previous standalone executable could not be found automatically.`n`n"
                . "Please launch the desired standalone manually from the extracted folder.",
                "Auto Update",
                48
            )
        }

        ExitApp

    } catch as err {
        MsgBox("Failed to update standalone bundle.`n" err.Message, "Auto Update", 48)
        return false
    }
}

IsRunningFromTempUpdater() {
    SplitPath(A_ScriptFullPath, , &scriptDir)
    return scriptDir = updaterTempDir
}

BootstrapUpdaterToTemp(currentExePath) {
    if DirExist(updaterTempDir) {
        try DirDelete(updaterTempDir, true)
    }
    DirCreate(updaterTempDir)
    FileCopy(A_ScriptFullPath, updaterTempExe, true)

    runCmd := '"' updaterTempExe '" "' currentExePath '" "' directUpdate '"'
    Run(runCmd)
}

relaunchAsAdmin() {
    if A_IsAdmin
        return

    args := ""
    for _, arg in A_Args
        args .= ' "' StrReplace(arg, '"', '""') '"'

    try Run('*RunAs "' A_ScriptFullPath '"' args)
    if (A_LastError != 0) {
        MsgBox "This script requires administrator privileges! Please click YES when prompted.",
            "Error", 48
    }
    ExitApp
}
