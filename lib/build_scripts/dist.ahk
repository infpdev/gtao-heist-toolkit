; dist.ahk - Distribution script for vaultOps
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir
#Include .\virusTotalScan.ahk
#Include ..\commonFuncs.ahk

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

buildVaultOpsExe := buildOpts.buildVaultOps
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
    global parentDir, buildVaultOpsExe, compileStandalone, packageBuilds, useOriginalClasses, scanVirusTotal,
        baseExe, AHK2EXEPath, iconPath, isccExe, issScript
    quotedBase := '"' baseExe '"'
    inFile := parentDir "\vaultOps.ahk"
    outFile := parentDir "\vaultOps.exe"
    updaterInFile := parentDir "\lib\autoUpdate.ahk"
    updaterOutFile := parentDir "\lib\vaultOpsUpdater.exe"
    standaloneUpdaterInFile := parentDir "\lib\standaloneUpdate.ahk"
    standaloneUpdaterOutFile := parentDir "\lib\standaloneUpdater.exe"
    vaultOpsInstaller := parentDir "\dist\vaultOps-Setup.exe"

    cmd := '"' AHK2EXEPath '" /in "' inFile '" /out "' outFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase
    updaterCmd := '"' AHK2EXEPath '" /in "' updaterInFile '" /out "' updaterOutFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase
    standaloneUpdaterCmd := '"' AHK2EXEPath '" /in "' standaloneUpdaterInFile '" /out "' standaloneUpdaterOutFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase
    innoCmd := '"' isccExe '" "' issScript '"'

    sleep 20

    if (buildVaultOpsExe) {
        ; Build the OpenCV helper exe that the compiled app loads from lib/.

        ; delete old package if it exists
        try DirDelete(parentDir "\dist", true)

        BuildOpenCVEngine(parentDir)

        ; === Compile and package the main vaultOps executable ===
        ToolTip "", , , 1
        ShowCenteredToolTip "Packaging vaultOps"
        RunWait cmd, , "Hide"
        RunWait updaterCmd, , "Hide"
        RunWait innoCmd, , "Hide"

        if RequireExistingFile(vaultOpsInstaller, "Installer") {
            ShowCenteredToolTip "Distribution build and Inno Setup installer complete!"
            ; Scan with VirusTotal if option selected
            if (scanVirusTotal) {
                sleep 1000
                ShowCenteredToolTip "Scanning vaultOps.exe with VirusTotal..."
                RunScan(vaultOpsInstaller)
            }
        } else {
            ShowCenteredToolTip "Build complete but installer not found!"
        }
        sleep 2000
    } else {
        RequireExistingFile(parentDir "\lib\py_helpers\OpenCV_Engine.exe", "Existing OpenCV helper")
        ShowCenteredToolTip "Skipping vaultOps build; reusing existing OpenCV helper and standalone assets."
        SetTimer () => (ToolTip("", , , 10)), -1000
    }

    ShowCenteredToolTip "Compiling standalone updater"
    if (compileStandalone)
        RunWait standaloneUpdaterCmd, , "Hide"

    if (compileStandalone)
        createStandalonePackages(quotedBase, parentDir, packageBuilds, useOriginalClasses, buildVaultOpsExe)

    OpenFolderAsUser(parentDir "\dist")

    ; Compile this script to .exe if not already compiled
    ; if !A_IsCompiled {
    ;     AHK2EXEPath := "AHK2EXE\Ahk2Exe.exe"
    ;     baseExe := "AHK_BASE\AutoHotkeyUX.exe"

    ;     if FileExist(AHK2EXEPath) && FileExist(baseExe) {
    ;         scriptPath := A_ScriptFullPath
    ;         exePath := A_ScriptDir "\compile_scripts.exe"
    ;         quotedBase := '"' baseExe '"'

    ;         cmd := '"' AHK2EXEPath '" /in "' scriptPath '" /out "' exePath '" /compress 0 /base ' quotedBase
    ;         RunWait cmd, , "Hide"

    ;         if FileExist(exePath) {
    ;             ShowCenteredToolTip "compiled dist.ahk"
    ;         }
    ;     }
    ; }
    sleep 2000
    ExitApp
}

BuildOpenCVEngine(parentDir) {
    global iconPath
    pyHelpersDir := parentDir "\lib\py_helpers"
    sourceFile := pyHelpersDir "\OpenCV_Engine.py"
    outputFile := pyHelpersDir "\OpenCV_Engine.exe"
    buildDir := pyHelpersDir "\nuitka_build"
    builtExe := buildDir "\OpenCV_Engine.exe"

    RequireExistingFile(sourceFile, "OpenCV engine helper")

    ; Prefer a project-local venv at the repository root (.venv-helper) so Nuitka
    ; freezes only the locally installed packages. Fall back to system Python.
    projectRoot := DirGetParent(parentDir)
    venvPython := projectRoot "\.venv-helper\Scripts\python.exe"
    venvActivate := projectRoot "\.venv-helper\Scripts\Activate.ps1"

    if FileExist(venvPython) {
        pythonExe := venvPython
        ShowCenteredToolTip "Using project venv for Nuitka build"
    } else {
        pythonExe := FindPythonExe()
        if (pythonExe = "") {
            MsgBox "No Python executable was found for the Nuitka build step. Please ensure Python is installed or on PATH.",
                "Error", 48
            ExitApp
        }
    }

    try CleanOldNuitkaTempFolders()

    if FileExist(outputFile)
        try FileDelete(outputFile)

    ; if DirExist(buildDir)
    ;     try DirDelete(buildDir, true)

    if !DirExist(buildDir)
        try DirCreate(buildDir)

    ShowCenteredToolTip "Compiling OpenCV_Engine.py with Nuitka..."

    quotedPython := '"' pythonExe '"'
    quotedBuildDir := '"' buildDir '"'
    nuitkaCmd := quotedPython ' -m nuitka --onefile --windows-console-mode=disable --assume-yes-for-downloads '
        . '--nofollow-import-to=PIL.ImageShow '
        . '--nofollow-import-to=PIL.ImageTk '
        . '--nofollow-import-to=PIL.ImageWin '
        . '--nofollow-import-to=PIL._avif '
        . '--nofollow-import-to=PIL._webp '
        . '--nofollow-import-to=PIL.*ImagePlugin '
        . '--nofollow-import-to=PIL.*StubImagePlugin '
        .
        '--nofollow-import-to=tkinter --nofollow-import-to=matplotlib --nofollow-import-to=scipy --nofollow-import-to=pytest --nofollow-import-to=unittest '
        . '--nofollow-import-to=email --nofollow-import-to=http --nofollow-import-to=urllib '
        . '--nofollow-import-to=numpy.ma --nofollow-import-to=numpy.random --nofollow-import-to=numpy.fft '
        . '--nofollow-import-to=numpy.polynomial --nofollow-import-to=numpy.matlib '
        . '--nofollow-import-to=numpy.rec --nofollow-import-to=numpy.char '
        . '--nofollow-import-to=numpy.f2py --nofollow-import-to=numpy.testing '
        . '--nofollow-import-to=cv2.aruco --nofollow-import-to=cv2.barcode --nofollow-import-to=cv2.cuda '
        . '--nofollow-import-to=cv2.detail --nofollow-import-to=cv2.dnn --nofollow-import-to=cv2.fisheye '
        . '--nofollow-import-to=cv2.flann --nofollow-import-to=cv2.gapi --nofollow-import-to=cv2.instr '
        . '--nofollow-import-to=cv2.mat_wrapper --nofollow-import-to=cv2.ml --nofollow-import-to=cv2.ocl '
        . '--nofollow-import-to=cv2.ogl --nofollow-import-to=cv2.parallel --nofollow-import-to=cv2.samples '
        .
        '--nofollow-import-to=cv2.segmentation --nofollow-import-to=cv2.typing --nofollow-import-to=cv2.videoio_registry '
        . '--windows-icon-from-ico="' iconPath '" --output-filename="OpenCV_Engine.exe" --output-dir="' buildDir '" "' sourceFile '"'

    RunWait nuitkaCmd, , "Hide"

    ; RunWait nuitkaCmd

    sleep 3000

    if !FileExist(builtExe) {
        MsgBox "Nuitka finished but OpenCV_Engine.exe was not created.`n`nCommand:`n" nuitkaCmd, "Error", 48
        ExitApp
    }

    FileCopy builtExe, outputFile, true

    try DirDelete(buildDir "\nuitka_temp", true)

    if !FileExist(outputFile) {
        MsgBox "OpenCV_Engine.exe was not copied into the py_helpers folder.", "Error", 48
        ExitApp
    }
}

CleanOldNuitkaTempFolders() {
    tempDir := A_Temp

    loop files tempDir "\onefile_*", "D" {
        try {
            ; Skip folders modified within last 10 minutes
            ageMinutes := DateDiff(A_Now, FileGetTime(A_LoopFileFullPath, "M"), "Minutes")

            if (ageMinutes > 10)
                DirDelete(A_LoopFileFullPath, true)
        }
    }
}

FindPythonExe() {
    localAppData := EnvGet("LocalAppData")
    candidates := [
        localAppData "\Programs\Python\Python313\python.exe",
        localAppData "\Programs\Python\Python312\python.exe",
        localAppData "\Programs\Python\Python311\python.exe",
        localAppData "\Programs\Python\Python310\python.exe",
        localAppData "\Programs\Python\Python39\python.exe",
        localAppData "\Programs\Python\Python38\python.exe"
    ]

    for _, candidate in candidates {
        if FileExist(candidate)
            return candidate
    }

    return "python"
}

; --- Standalone script packaging using WinRAR SFX ---
createStandalonePackages(quotedBase, parentDir, packageBuilds := true, useOriginalClasses := false, buildVaultOpsExe :=
    true) {
    global rarExe, AHK2EXEPath, iconPath

    standaloneDir := parentDir "\lib\standalone scripts"
    distFolder := parentDir "\dist\"
    distStandaloneDir := distFolder "standalone"
    bundleFile := distFolder "vaultOps-Standalone-Pack.exe"
    standaloneExtractionFolder := "vaultOps-Standalone-Pack"

    imageFolders := ["1366x768", "1600x900", "1920x1080"]

    standaloneClassMap := Map(
        "Fingerprint-Standalone.ahk", parentDir "\lib\scripts\CasinoFingerprint.ahk",
        "Keypad-Standalone.ahk", parentDir "\lib\scripts\CasinoKeypad.ahk",
        "ElRubio-Standalone.ahk", parentDir "\lib\scripts\ElRubio.ahk"
    )

    if !DirExist(distStandaloneDir)
        DirCreate(distStandaloneDir)
    else {
        try DirDelete(distStandaloneDir, true)
        DirCreate(distStandaloneDir)
    }

    if (DirExist(distFolder standaloneExtractionFolder))
        try DirDelete(distFolder standaloneExtractionFolder, true)

    ; Clean previous bundle
    if FileExist(bundleFile)
        try FileDelete(bundleFile)

    if (!packageBuilds || FileExist(rarExe)) {

        ; cleanup temp ahks
        loop files, standaloneDir "\temp_*.ahk", "F" {
            try FileDelete(A_LoopFilePath)
        }

        ; shared OpenCV helper
        ocvSource := parentDir "\lib\py_helpers\OpenCV_Engine.exe"
        standaloneUpdaterSource := parentDir "\lib\standaloneUpdater.exe"
        ocvDestDir := distStandaloneDir "\lib"

        if FileExist(ocvSource) {

            if !DirExist(ocvDestDir)
                DirCreate(ocvDestDir)

            try FileCopy(
                ocvSource,
                ocvDestDir "\OpenCV_Engine.exe",
                true
            )
        }

        if FileExist(standaloneUpdaterSource) {
            if !DirExist(ocvDestDir)
                DirCreate(ocvDestDir)

            try FileCopy(
                standaloneUpdaterSource,
                ocvDestDir "\standaloneUpdater.exe",
                true
            )
        }

        ; copy image folders once
        for _, folder in imageFolders {
            src := parentDir "\" folder
            dest := distStandaloneDir "\" folder

            if DirExist(src)
                DirCopy(src, dest, true)
        }

        compiledExeList := []

        ; compile standalone scripts
        loop files, standaloneDir "\\*Standalone*.ahk", "F" {

            script := A_LoopFilePath

            SplitPath script, &scriptName

            exeName := StrReplace(scriptName, ".ahk", ".exe")
            outExe := distStandaloneDir "\" exeName

            scriptToCompile := script
            tempScript := ""

            if (useOriginalClasses && standaloneClassMap.Has(scriptName)) {

                originalScript := standaloneClassMap[scriptName]
                tempPath := standaloneDir "\temp_" scriptName

                ToolTip "Preparing " scriptName "...", 0, 0, 1

                try {
                    CreateTempScriptWithReplacedClass(
                        script,
                        originalScript,
                        tempPath,
                        parentDir
                    )

                    scriptToCompile := tempPath
                    tempScript := tempPath

                } catch as err {

                    MsgBox(
                        "ERROR: Failed to prepare "
                        scriptName
                        ": "
                        err.Message,
                        "Error",
                        48
                    )

                    continue
                }
            }

            cmd := '"' AHK2EXEPath '" /in "' scriptToCompile '" /out "' outExe '" /icon "' iconPath '" /compress 0 /base ' quotedBase

            ToolTip "Compiling: " exeName, 0, 0, 1

            RunWait cmd, , "Hide"

            ToolTip "Compiled: " exeName, 0, 0, 1

            if (tempScript != "")
                try FileDelete(tempScript)

            if RegExMatch(scriptName, "i)(NoSave|AFK-)") {

                try FileCopy(
                    outExe,
                    distFolder exeName,
                    true
                )

                continue
            }

            ; track compiled exe
            compiledExeList.Push(exeName)
        }

        ; stop here if packaging disabled
        if (!packageBuilds) {
            ShowCenteredToolTip "Standalone compile complete."
            return
        }

        try FileCopy(
            iconPath,
            distStandaloneDir "\gta.ico",
            true
        )

        ; build ONE combined SFX
        sfxComment :=
            (
                "; The comment below contains SFX script commands`n"
                "Path=.\" standaloneExtractionFolder "`n"
                "Silent=1`n"
                "SavePath`n"
                "Overwrite=1`n"
                "; End of SFX script commands"
            )

        sfxCommentPath := distStandaloneDir "\bundle.txt"

        try FileDelete(sfxCommentPath)
        FileAppend(sfxComment, sfxCommentPath)

        ; explicit exe list
        exeStr := ""

        for _, exeName in compiledExeList
            exeStr .= ' "' exeName '"'

        ; image folders
        imgStr := ""

        for _, folder in imageFolders
            imgStr .= ' "' folder '"'

        SetWorkingDir(distStandaloneDir)

        ToolTip "Packaging standalone bundle...", 0, 0, 1

        ; IMPORTANT:
        ; NO *.exe
        ; NO recursive lib packaging madness
        rarCmd := '"' rarExe '" a -r -sfx -iicon"' distStandaloneDir '\gta.ico" "' bundleFile '" ' exeStr ' "lib\OpenCV_Engine.exe" "lib\standaloneUpdater.exe"' imgStr ' -z"bundle.txt"'

        RunWait rarCmd, , "Hide"

        SetWorkingDir(A_ScriptDir)

        ToolTip "Standalone bundle created", 0, 0, 1

        ; cleanup temporary standalone staging folder
        try DirDelete(distStandaloneDir, true)

        ShowCenteredToolTip "Standalone bundle packaging complete."

        sleep 1000

    } else {

        MsgBox(
            "WinRAR not found at: " rarExe,
            "Error"
        )
    }
}

buildGUI(isDev := false) {
    dlg := Gui("-DPIScale", "Build options")
    dlg.SetFont("s10")

    dlg.AddText("xm+9 ym", "Choose build options:")

    ; ==== VaultOps build options ====
    dlg.AddGroupBox("xm yp+25 w360 h50", "Build vaultOps.exe")
    rBuildYes := dlg.AddRadio("xp+14 yp+23 Group ", "Yes")
    rBuildNo := dlg.AddRadio("x+60 yp Checked", "No (reuse existing OpenCV helper)")

    ; ==== VirusTotal scan option ====
    dlg.AddGroupBox("xm y+12 w360 h50", "Scan with VirusTotal")
    rScanYes := dlg.AddRadio("xp+14 yp+23 Group Checked", "Yes")
    rScanNo := dlg.AddRadio("x+80 yp", "No")

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

    ; ==== Standalone build and packaging options ====
    dlg.AddGroupBox("xm y+12 w360 h50", "Compile standalone scripts")
    rStandaloneYes := dlg.AddRadio("xp+14 yp+23 Group Checked", "Yes")
    rStandaloneNo := dlg.AddRadio("x+80 yp", "No")

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
        } else {
            rPackageYes.Value := 1
            rPackageNo.Value := 0
        }
    }

    UpdateFastBuildPreset(*) {
        if (rBuildNo.Value == 1) {
            rScanYes.Enabled := false
            rScanNo.Enabled := false
            rScanYes.Value := 0
            rScanNo.Value := 1
            rStandaloneYes.Value := 1
            rStandaloneNo.Value := 0
            if (isDev && rPackageYes != "") {
                rPackageYes.Value := 1
                rPackageNo.Value := 0
            }
        } else {
            rScanYes.Enabled := true
            rScanNo.Enabled := true
            rScanYes.Value := 1
            rScanNo.Value := 0
        }
        UpdatePackageOptions()
    }

    rStandaloneYes.OnEvent("Click", UpdatePackageOptions)
    rStandaloneNo.OnEvent("Click", UpdatePackageOptions)
    rBuildYes.OnEvent("Click", UpdateFastBuildPreset)
    rBuildNo.OnEvent("Click", UpdateFastBuildPreset)
    UpdatePackageOptions()
    UpdateFastBuildPreset()

    btnOk := dlg.AddButton("x85 y+17 w90 Default", "OK")
    btnCancel := dlg.AddButton("x+10 w90", "Cancel")

    btnOk.Focus()

    selected := ""
    btnOk.OnEvent("Click", (*) => (
        selected := {
            buildVaultOps: rBuildYes.Value == 1,
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
        ShowCenteredToolTip("Extracting build files...")

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

; ShowCenteredToolTip(text, y := 0) {
;     ; Measure text width to center tooltip
;     hdc := DllCall("GetDC", "ptr", 0)

;     ; Create font (adjust if needed)
;     hfont := DllCall("GetStockObject", "int", 0)  ; DEFAULT_GUI_FONT
;     DllCall("SelectObject", "ptr", hdc, "ptr", hfont)

;     ; Measure text using Buffer (AHK v2.0)
;     size := Buffer(8)
;     DllCall("GetTextExtentPoint32", "ptr", hdc, "str", text, "int", StrLen(text), "ptr", size)
;     width := NumGet(size, 0, "int")

;     DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

;     ; Center horizontally, position Y at parameter or top
;     centerX := (A_ScreenWidth // 2) - (width // 2)
;     centerY := y > 0 ? y : 0

;     ToolTip(text, centerX, centerY, 1)
; }

F2:: Reload