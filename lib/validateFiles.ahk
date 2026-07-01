validataFiles(dir, isCompiled := A_IsCompiled) {
    appDir := dir

    ShowCenteredToolTip "Validating files"

    if (
        !InStr(FileExist(appDir "\1366x768"), "D") ||
        !InStr(FileExist(appDir "\1600x900"), "D") ||
        !InStr(FileExist(appDir "\1920x1080"), "D")
    ) {
        MsgBox(
            "Missing resolution folders. Please ensure the following folders exist in the application directory:`n`n" .
            "1366x768`n" .
            "1600x900`n" .
            "1920x1080", "Missing Resolution Folders", 16)
        ExitApp()
    }

    if (isCompiled && !FileExist(appDir "\lib\OpenCV_Engine.exe")) {
        isInExclusion := IsVaultOpsExcluded(dir)

        if (isInExclusion) {
            MsgBox(
                "OpenCV_Engine.exe is missing. This may be caused by antivirus software on your PC.`n`n"
                .
                "Please restore the file from quarantine or add this folder to the exclusion list of your antivirus software, then run the installer again to restore the missing files.",
                "Missing OpenCV Engine",
                16
            )
        } else {

            result := MsgBox(
                "OpenCV_Engine.exe is missing, which is usually caused by Windows Security or another antivirus quarantining the file.`n`n"
                . "Would you like " (isStandaloneScript ? "to automatically add the standalone folder" :
                    "VaultOps to add its installation folder") " to the Windows Security exclusion list?`n`n"
                . "Administrator permission will be required.",
                "Missing OpenCV Engine",
                "YesNo Icon!"
            )

            if (result = "Yes") {
                if (AddVaultOpsExclusion(dir)) {
                    vaultOpsUpdater := appDir "\lib\vaultOpsUpdater.exe"
                    standaloneUpdater := appDir "\lib\standaloneUpdater.exe"
                    if (FileExist(standaloneUpdater) || FileExist(vaultOpsUpdater)) {
                        res := MsgBox(
                            (isStandaloneScript ? "The standalone folder" : "VaultOps") " has been added to the Windows Security exclusion list.`n`n"
                            .
                            "Would you like to run the updater to restore the missing files now?",
                            "Exclusion Added",
                            "YesNo Icon!"
                        )

                        if (res = "Yes") {
                            try {
                                Run('*RunAs "' (FileExist(standaloneUpdater) ? standaloneUpdater : vaultOpsUpdater) '"'
                                )
                            } catch {
                                MsgBox(
                                    "Failed to launch the updater.`n`n"
                                    . "Please run the installer again to restore the missing files.",
                                    "Failed to Launch Updater",
                                    16
                                )
                            }
                        }
                    }
                    else {
                        MsgBox(
                            (isStandaloneScript ? "The standalone folder" : "VaultOps") " has been added to the Windows Security exclusion list.`n`n"
                            .
                            "Please run the installer again to restore the missing files and try again.",
                            "Exclusion Added",
                            64
                        )
                    }
                } else {
                    MsgBox(
                        "Failed to add " (isStandaloneScript ? "the standalone folder" : "VaultOps") " to the Windows Security exclusion list.`n`n"
                        . "Please ensure you have administrator permission and try again.",
                        "Exclusion Failed",
                        16
                    )
                }

            }
        }

        ExitApp()
    }

}

IsVaultOpsExcluded(dir) {
    static tmp := A_Temp "\mpref.txt"

    vaultPath := dir

    if FileExist(tmp)
        FileDelete(tmp)

    cmd := A_ComSpec
        . ' /c powershell -NoProfile -WindowStyle Hidden -Command '
        . '"(Get-MpPreference).ExclusionPath | Out-File -Encoding utf8 '
        . "'" tmp "'"
        . '"'

    RunWait(cmd, , "Hide")

    if !FileExist(tmp)
        return false

    output := FileRead(tmp)
    FileDelete(tmp)

    return InStr(output, vaultPath)
}

AddVaultOpsExclusion(dir) {
    vaultPath := dir

    ShowCenteredToolTip "Adding " (isStandaloneScript ? "the standalone folder" : "VaultOps") " to Windows Security exclusion list"

    cmd := A_ComSpec
        . ' /c powershell -NoProfile -WindowStyle Hidden -Command '
        . '"Add-MpPreference -ExclusionPath '
        . "'" vaultPath "'"
        . '"'
    RunWait(cmd, , "Hide")

    return IsVaultOpsExcluded(dir)
}
