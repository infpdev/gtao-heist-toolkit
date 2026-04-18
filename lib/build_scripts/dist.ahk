; dist.ahk - Distribution script for vaultOps
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir
#Include .\virusTotalScan.ahk

; Development mode flag (set to false for release builds)
global configFile := ".\build_options.ini"

isDev := IniRead(configFile, "Dist", "isDev", 0)

; Get absolute path to parent directory
parentDir := DirGetParent(A_ScriptDir)

baseExe := "AHK_BASE\AutoHotkeyUX.exe"
AHK2EXEPath := "AHK2EXE\Ahk2Exe.exe"
isccExe := "Inno Setup 6\ISCC.exe"
issScript := ".\inno_setup.iss"
iconPath := ".\gta.ico"
rarExe := "C:\Program Files\WinRAR\WinRAR.exe"

; Check and extract build files if needed before validating paths
ExtractBuildFilesIfNeeded()


RequireExistingFile(baseExe, "AutoHotkey base executable")
RequireExistingFile(AHK2EXEPath, "Ahk2Exe")
RequireExistingFile(isccExe, "Inno Setup compiler")
RequireExistingFile(issScript, "Inno Setup script")
RequireExistingFile(iconPath, "Project icon")

buildOpts := buildGUI(isDev)
if !IsObject(buildOpts)
    ExitApp

compileStandalone := buildOpts.compileStandalone
packageBuilds := buildOpts.packageBuilds
useOriginalClasses := buildOpts.useOriginalClasses
scanVirusTotal := buildOpts.scanVirusTotal

if (compileStandalone && packageBuilds && !FileExist(rarExe)) {
    MsgBox "WinRAR.exe was not found, please select the correct path.", "Error", 48

    pickedRar := FileSelect(1, , "Select WinRAR.exe", "Executables (*.exe)")
    if (pickedRar = "" || !FileExist(pickedRar)) {
        MsgBox "WinRAR.exe was not found and no valid file was selected.", "Error", 48
        ExitApp
    }
    rarExe := pickedRar
}

; === Main build function ===

buildVaultOps()

buildVaultOps() {
    global parentDir, compileStandalone, packageBuilds, useOriginalClasses, scanVirusTotal, baseExe, AHK2EXEPath,
        iconPath, isccExe,
        issScript
    quotedBase := '"' baseExe '"'
    inFile := parentDir "\vaultOps.ahk"
    outFile := parentDir "\vaultOps.exe"
    vaultOpsInstaller := parentDir "\dist\vaultOps-Setup.exe"

    cmd := '"' AHK2EXEPath '" /in "' inFile '" /out "' outFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase
    innoCmd := '"' isccExe '" "' issScript '"'

    ; delete old package if it exists
    if DirExist(parentDir "\dist") {
        try DirDelete(parentDir "\dist", true)
    }

    sleep 20

    ; === Compile standalone scripts if option is selected ===
    if (compileStandalone)
        createStandalonePackages(quotedBase, parentDir, packageBuilds, useOriginalClasses)

    ; === Compile and package the main vaultOps executable ===
    RunWait cmd, , "Hide"
    RunWait innoCmd, , "Hide"

    if RequireExistingFile(vaultOpsInstaller, "Installer") {
        ShowCenteredToolTip "Distribution build and Inno Setup installer complete!"
        sleep 1000
        ; Scan with VirusTotal if option selected
        if (scanVirusTotal) {
            ShowCenteredToolTip "Scanning vaultOps.exe with VirusTotal..."
            RunScan(vaultOpsInstaller)
        }

        OpenFolderAsUser(parentDir "\dist")

    } else {
        ShowCenteredToolTip "Build complete but installer not found!"
    }
    sleep 2000

    ; Compile this script to .exe if not already compiled
    if !A_IsCompiled {
        AHK2EXEPath := "AHK2EXE\Ahk2Exe.exe"
        baseExe := "AHK_BASE\AutoHotkeyUX.exe"

        if FileExist(AHK2EXEPath) && FileExist(baseExe) {
            scriptPath := A_ScriptFullPath
            exePath := A_ScriptDir "\compile_scripts.exe"
            quotedBase := '"' baseExe '"'

            cmd := '"' AHK2EXEPath '" /in "' scriptPath '" /out "' exePath '" /compress 0 /base ' quotedBase
            RunWait cmd, , "Hide"

            if FileExist(exePath) {
                ShowCenteredToolTip "compiled dist.ahk"
            }
        }
    }

    sleep 2000
    ExitApp
}

; --- Standalone script packaging using WinRAR SFX ---
createStandalonePackages(quotedBase, parentDir, packageBuilds := true, useOriginalClasses := false) {
    global rarExe, AHK2EXEPath, iconPath
    standaloneDir := parentDir "\lib\standalone scripts"
    distStandaloneDir := parentDir "\dist\standalone"
    imageFolders := ["1366x768", "1600x900", "1920x1080"]

    ; Explicit mapping: standalone script filename => original script path
    standaloneClassMap := Map(
        "Fingerprint-Standalone.ahk", parentDir "\lib\scripts\CasinoFingerprint.ahk",
        "Keypad-Standalone.ahk", parentDir "\lib\scripts\CasinoKeypad.ahk",
        "ElRubio-Standalone.ahk", parentDir "\lib\scripts\ElRubio.ahk"
    )

    if !DirExist(distStandaloneDir)
        DirCreate(distStandaloneDir)

    if (!packageBuilds || FileExist(rarExe)) {
        ; Clean up any leftover temp files from previous builds before starting
        loop files, standaloneDir "\temp_*.ahk", "F" {
            try FileDelete(A_LoopFilePath)
        }

        ; Copy image folders into dist/standalone regardless of packaging, since both compiled and SFX versions need them
        for _, folder in imageFolders {
            src := parentDir "\" folder
            dest := distStandaloneDir "\" folder
            if DirExist(src) {
                DirCopy(src, dest, true)
            }
        }

        loop files, standaloneDir "\\*Standalone*.ahk", "F" {
            script := A_LoopFilePath

            SplitPath script, &scriptName
            exeName := StrReplace(scriptName, ".ahk", ".exe")
            outExe := distStandaloneDir "\\" exeName

            ; Determine which script to compile: temp version (if mapped AND useOriginalClasses) or original
            scriptToCompile := script
            tempScript := ""

            if (useOriginalClasses && standaloneClassMap.Has(scriptName)) {
                originalScript := standaloneClassMap[scriptName]
                tempPath := standaloneDir "\temp_" scriptName

                ToolTip "Preparing " scriptName " with latest class...", 0, 0, 1
                try {
                    CreateTempScriptWithReplacedClass(script, originalScript, tempPath, parentDir)
                    scriptToCompile := tempPath
                    tempScript := tempPath  ; Track for cleanup after compilation
                } catch as err {
                    MsgBox "ERROR: Failed to prepare " scriptName ": " err.Message, "Error", 48
                    sleep 2000
                    continue
                }
                ; msgBox "Waiting for review"
            }

            ; Compile the script (either standalone original or temp with replaced class)
            cmd := '"' AHK2EXEPath '" /in "' scriptToCompile '" /out "' outExe '" /icon "' iconPath '" /compress 0  /base ' quotedBase
            ToolTip "Compiling: " exeName, 0, 0, 1
            RunWait cmd, , "Hide"
            ToolTip "Compiled: " exeName, 0, 0, 1

            ; Cleanup temp file if one was created
            if (tempScript != "") {
                try FileDelete(tempScript)
            }

            if InStr(script, "NoSave")
                continue

            if (!packageBuilds)
                continue

            ; Prepare SFX comment
            sfxComment :=
                (
                    "; The comment below contains SFX script commands`n"
                    "Path=.\" StrReplace(exeName, ".exe", "") "`n"
                    "Silent=1`n"
                    "SavePath`n"
                    "Overwrite=1`n"
                    "Icon=gta.ico`n"
                    "; End of SFX script commands"
                )
            sfxCommentPath := distStandaloneDir "\\package.txt"
            FileAppend(sfxComment, sfxCommentPath)

            imgStr := ""
            for _, folder in imageFolders
                imgStr .= ' "' folder '"'

            SetWorkingDir(distStandaloneDir)
            sfxName := StrReplace(exeName, ".exe", "-SFX.exe")
            ToolTip "Packaging SFX: " exeName, 0, 0, 1
            rarCmd := '"' rarExe '" a -r -sfx "' sfxName '" "' exeName '"' imgStr ' -z"package.txt"'
            RunWait rarCmd, , "Hide"
            ToolTip "SFX created: " exeName, 0, 0, 1
            SetWorkingDir(A_ScriptDir)
            try FileDelete(sfxCommentPath)
            try FileDelete(outExe) ; Delete the compiled exe after packaging

        }

        ; Delete the copied image folders from dist/standalone if
        ; packaging was done, since the SFX packages contain the images and we don't need duplicates
        if (packageBuilds) {
            for _, folder in imageFolders {
                dest := distStandaloneDir "\" folder
                if DirExist(dest) {
                    DirDelete(dest, true)
                }
            }
            ToolTip "Standalone SFX packaging complete.", A_ScreenWidth // 2 - 60, 0, 1
        } else {
            ToolTip "Standalone compile complete (SFX packaging skipped).", A_ScreenWidth // 2 - 90, 0, 1
        }
        sleep 1000
    } else {
        MsgBox("WinRAR not found at: " rarExe, "Error")
    }
}

buildGUI(isDev := false) {
    dlg := Gui("-DPIScale", "Build options")
    dlg.SetFont("s10")

    dlg.AddText("xm+9 ym", "Choose build options:")

    dlg.AddGroupBox("xm yp w360 h50", "Compile and package vaultOps")
    rStandaloneYes := dlg.AddRadio("xp+14 yp+23 Checked Disabled", "Yes")

    dlg.AddGroupBox("xm y+12 w360 h50", "Scan with VirusTotal")
    rScanYes := dlg.AddRadio("xp+14 yp+23 Group", "Yes")
    rScanNo := dlg.AddRadio("x+80 yp Checked", "No")

    apiKey := ""

    validateApiKey(*) {
        dlg.Hide()
        apiKey := LoadOrPromptAPIKey()
        if (!apiKey) {
            MsgBox "VirusTotal API key is required to enable scanning. Please obtain an API key from https://www.virustotal.com/ and try again.",
                "Error", 48
            rScanYes.Value := 0
            rScanNo.Value := 1
        }
        dlg.Show()
    }

    rScanYes.OnEvent("Click", validateApiKey)

    dlg.AddGroupBox("xm y+12 w360 h50", "Compile standalone scripts")
    rStandaloneYes := dlg.AddRadio("xp+14 yp+23  Group", "Yes")
    rStandaloneNo := dlg.AddRadio("x+80 yp Checked ", "No")

    ; Package standalone option (only for dev mode)
    packageGroupBox := ""
    if (isDev) {
        dlg.AddGroupBox("xm y+12 w360 h50", "Package standalone scripts (installer + SFX)")
        rPackageYes := dlg.AddRadio("xp+14 yp+23 Group", "Yes")
        rPackageNo := dlg.AddRadio("x+80 yp Checked", "No")
    } else {
        rPackageYes := ""
        rPackageNo := ""
    }

    dlg.AddGroupBox("xm y+12 w360 r2 Wrap",
        "Replace classes with originals (create temp) or use standalone as-is (While compiling standalone scripts)")
    rClassYes := dlg.AddRadio("xp+14 yp+42 Checked Group", "Yes (create temp)")
    rClassNo := dlg.AddRadio("x+80 yp ", "No (as-is)")

    UpdatePackageOptions(*) {
        enabled := (rStandaloneYes.Value == 1)
        if (isDev && rPackageYes != "") {
            rPackageYes.Enabled := enabled
            rPackageNo.Enabled := enabled
        }
        rClassYes.Enabled := enabled
        rClassNo.Enabled := enabled
        if (!enabled) {
            if (isDev && rPackageYes != "") {
                rPackageYes.Value := 0
                rPackageNo.Value := 1
            }
            rClassYes.Value := 1
            rClassNo.Value := 0
        }
    }

    rStandaloneYes.OnEvent("Click", UpdatePackageOptions)
    rStandaloneNo.OnEvent("Click", UpdatePackageOptions)
    UpdatePackageOptions()

    btnOk := dlg.AddButton("x85 y+17 w90 Default", "OK")
    btnCancel := dlg.AddButton("x+10 w90", "Cancel")

    selected := ""
    btnOk.OnEvent("Click", (*) => (
        selected := {
            compileStandalone: rStandaloneYes.Value == 1,
            packageBuilds: isDev && rPackageYes != "" ? (rPackageYes.Value == 1 && rStandaloneYes.Value == 1) : false,
            useOriginalClasses: rClassYes.Value == 1,
            scanVirusTotal: rScanYes.Value == 1,
        },
        dlg.Destroy()
    ))
    btnCancel.OnEvent("Click", (*) => (
        selected := false,
        dlg.Destroy()
    ))
    dlg.OnEvent("Close", (*) => (
        selected := false,
        dlg.Destroy()
    ))

    dlg.Show("AutoSize Center")
    WinWaitClose("ahk_id " dlg.Hwnd)

    return selected
}

CreateTempScriptWithReplacedClass(standaloneScript, originalScript, tempPath, parentDir) {
    ; Read the standalone template
    if !FileExist(standaloneScript)
        throw Error("Standalone script not found: " standaloneScript)

    standaloneContent := FileRead(standaloneScript)

    ; Extract the class from the original script (from "; class start" marker onwards)
    newClass := ExtractClassFromScript(originalScript)

    ; Find where the class starts in the standalone
    markerPos := InStr(standaloneContent, "; class start")
    if (markerPos = 0)
        throw Error("Marker '; class start' not found in standalone: " standaloneScript)

    ; Everything before "; class start" + the new class from original
    beforeClass := SubStr(standaloneContent, 1, markerPos - 1)
    mergedContent := beforeClass . newClass

    FileAppend(mergedContent, tempPath)

    return true
}

; --- Helper functions for class extraction and temp file creation ---
ExtractBuildFilesIfNeeded() {
    requiredFolders := ["AHK_BASE", "AHK2EXE", "Inno Setup 6"]
    buildFilesZip := A_ScriptDir "\build_files.zip"

    ; Check if any folder is missing
    folderMissing := false
    for _, folder in requiredFolders {
        if !DirExist(A_ScriptDir "\" folder) {
            folderMissing := true
            break
        }
    }

    ; If missing and ZIP exists, extract it
    if (folderMissing && FileExist(buildFilesZip)) {
        ToolTip("Extracting build files...", A_ScreenWidth // 2 - 100, 0, 1)

        psCmd := "Expand-Archive -Path '" buildFilesZip "' -DestinationPath '" A_ScriptDir "' -Force"
        RunWait(A_ComSpec ' /C powershell -Command "' psCmd '"', , "Hide")

        ShowCenteredToolTip "Build files extracted successfully!"
        sleep 1500
        ToolTip()  ; Clear tooltip
    } else if (folderMissing && !FileExist(buildFilesZip)) {
        MsgBox(
            "Build files not found.`n`nPlease ensure one of the following:`n - All build folders (AHK_BASE, AHK2EXE, Inno Setup 6) are in: " A_ScriptDir "`n - OR build_files.zip is in: " A_ScriptDir,
            "Error", 48)
        ExitApp
    }
}

ExtractClassFromScript(filePath) {
    ; Read the original script and extract everything from "; class start" marker onwards
    if !FileExist(filePath)
        throw Error("Source script not found: " filePath)

    content := FileRead(filePath)
    markerPos := InStr(content, "; class start")

    if (markerPos = 0)
        throw Error("Marker '; class start' not found in: " filePath)

    ; Return from "; class start" to end of file
    return SubStr(content, markerPos)
}

RequireExistingFile(path, label) {
    if !FileExist(path)
        throw Error(label " not found: " path)
    return true
}

DirGetParent(path) {
    currentPath := path
    loop 10 {  ; Reasonable limit to prevent infinite loops
        SplitPath currentPath, &folderName, &parentPath
        ; Check if current folder is _src
        if (folderName = "_src") {
            return currentPath
        }
        ; If no parent or we've reached root, use fallback
        if (!parentPath || parentPath = currentPath) {
            ; Fallback: go up two levels from original path
            SplitPath path, , &parent1
            SplitPath parent1, , &parent2
            return parent2 ? parent2 : path
        }
        currentPath := parentPath
    }
    ; If loop limit reached, use fallback
    SplitPath path, , &parent1
    SplitPath parent1, , &parent2
    return parent2 ? parent2 : path
}

OpenFolderAsUser(path) {
    ; Opens folder as the current (non-elevated) user, even if script is admin
    DllCall("shell32\ShellExecuteW", "ptr", 0, "wstr", "open", "wstr", "explorer.exe", "wstr", '"' path '"', "ptr",
        0,
        "int", 1)
}

ShowCenteredToolTip(text, y := 0) {
    ; Measure text width to center tooltip
    hdc := DllCall("GetDC", "ptr", 0)

    ; Create font (adjust if needed)
    hfont := DllCall("GetStockObject", "int", 0)  ; DEFAULT_GUI_FONT
    DllCall("SelectObject", "ptr", hdc, "ptr", hfont)

    ; Measure text using Buffer (AHK v2.0)
    size := Buffer(8)
    DllCall("GetTextExtentPoint32", "ptr", hdc, "str", text, "int", StrLen(text), "ptr", size)
    width := NumGet(size, 0, "int")

    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

    ; Center horizontally, position Y at parameter or top
    centerX := (A_ScreenWidth // 2) - (width // 2)
    centerY := y > 0 ? y : 0

    ToolTip(text, centerX, centerY, 1)
}

F2:: Reload