#Requires AutoHotkey v2.0

global updaterName := "vaultOpsUpdater.exe"
global updaterTempDir := A_Temp "\vaultOpsUpdate"
global updaterTempExe := updaterTempDir "\" updaterName

relaunchAsAdmin()

currentExePath := A_Args.Length >= 1 ? A_Args[1] : A_ScriptDir "\..\vaultOps.exe"

if (!IsRunningFromTempUpdater()) {
    BootstrapUpdaterToTemp(currentExePath)
    ExitApp
}

if (!FileExist(currentExePath)) {
    MsgBox(
        "vaultOps.exe not found`nTry:`n1.Changing back the name to vaultOps.exe.`n2.Moving the updater to vaultOps/lib/ folder.",
        "Auto Update", 48)
    ExitApp
}

PerformUpdate(currentExePath)
ExitApp

PerformUpdate(currentExePath) {
    SplitPath(currentExePath, , &targetDir)
    ToolTip("Updating vaultOps", A_ScreenWidth / 2 - 50, 0, 17)

    downloadUrl := "https://github.com/infpdev/gtao-heist-toolkit/releases/latest/download/vaultOps-Setup.exe"
    setupName := "vaultOps-Setup.exe"

    tempDir := updaterTempDir
    tempSetupPath := tempDir "\" setupName

    try {
        if (!DirExist(tempDir))
            DirCreate(tempDir)

        ; Download installer
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", downloadUrl, false)
        http.SetTimeouts(5000, 5000, 5000, 5000)
        http.Send()

        if (http.Status < 200 || http.Status >= 300)
            throw Error("HTTP " http.Status)

        ; Save installer
        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(http.ResponseBody)
        stream.SaveToFile(tempSetupPath, 2)
        stream.Close()

        if !FileExist(tempSetupPath)
            throw Error("Failed to save installer.")

        ; Delete renamed/current exe first after the main app exits.
        loop 120 {
            try {
                if FileExist(currentExePath)
                    FileDelete(currentExePath)

                if !FileExist(currentExePath)
                    break
            } catch {
                Sleep(500)
            }
        }

        if FileExist(currentExePath)
            throw Error("Failed to remove original executable: " currentExePath)

        RunWait('"' tempSetupPath '" /SILENT /DIR="' targetDir '"')
        if !FileExist(targetDir "\vaultOps.exe")
            throw Error("Failed to install updated executable to: " targetDir "\vaultOps.exe")

        Run('"' targetDir "\vaultOps.exe" '"')
        return true

    } catch as err {
        MsgBox("Failed to update.`n" err.Message, "Auto Update", 48)
        return false
    }
}

IsRunningFromTempUpdater() {
    SplitPath(A_ScriptFullPath, , &scriptDir)
    return scriptDir = updaterTempDir
}

BootstrapUpdaterToTemp(currentExePath) {
    if (FileExist(updaterTempDir)) {
        try DirDelete(updaterTempDir, true)
    }
    DirCreate(updaterTempDir)
    FileCopy(A_ScriptFullPath, updaterTempExe, true)

    runCmd := '"' updaterTempExe '" "' currentExePath '"'
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
