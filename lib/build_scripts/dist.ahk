; dist.ahk - Distribution script for vaultOps
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir
CoordMode "ToolTip", "Screen"

#Include helpers\virusTotalScan.ahk

; Development mode flag (set to false for release builds)
global configFile := ".\build_options.ini"
global debug := true

isDev := IniRead(configFile, "Dist", "isDev", 0)

; Get absolute path to parent directory
parentDir := DirGetParent(A_ScriptDir)

baseExe := "AHK_BASE\AutoHotkeyUX.exe"
AHK2EXEPath := "AHK2EXE\Ahk2Exe.exe"
isccExe := "Inno Setup 6\ISCC.exe"
issScript := ".\inno_setup.iss"
iconPath := ".\vaultOps.ico"
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
shouldBuildOpenCVEngine := buildOpts.buildOpenCVEngine
shouldBuildDiscordRPC := buildOpts.buildDiscordRPC
compileStandalone := buildOpts.compileStandalone
packageStandalone := buildOpts.packageBuilds
useOriginalClasses := buildOpts.useOriginalClasses
scanVirusTotal := buildOpts.scanVirusTotal

if (compileStandalone && packageStandalone && !FileExist(rarExe)) {
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
    global parentDir, buildVaultOpsExe, shouldBuildOpenCVEngine, shouldBuildDiscordRPC, packageStandalone,
        useOriginalClasses, scanVirusTotal, baseExe, AHK2EXEPath, iconPath, isccExe, issScript
    quotedBase := '"' baseExe '"'
    inFile := parentDir "\vaultOps.ahk"
    outFile := parentDir "\vaultOps.exe"
    updaterInFile := parentDir "\lib\autoUpdate.ahk"
    updaterOutFile := parentDir "\lib\vaultOpsUpdater.exe"
    vaultOpsInstaller := parentDir "\dist\vaultOps-Setup.exe"

    vaultOpsCmd := '"' AHK2EXEPath '" /in "' inFile '" /out "' outFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase
    updaterCmd := '"' AHK2EXEPath '" /in "' updaterInFile '" /out "' updaterOutFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase
    innoCmd := '"' isccExe '" "' issScript '"'

    sleep 20

    if (buildVaultOpsExe) {
        ; Build the OpenCV helper exe only when requested.

        ; delete old package if it exists
        try DirDelete(parentDir "\dist", true)

        if (shouldBuildOpenCVEngine) {
            BuildOpenCVEngine(parentDir)
        } else {
            RequireExistingFile(parentDir "\lib\py_helpers\OpenCV_Engine.exe", "Existing OpenCV helper")
            ShowCenteredToolTip "Using existing OpenCV_Engine.exe"
            sleep 700
        }

        if (shouldBuildDiscordRPC) {
            BuildDiscordRPC(parentDir)
        } else {
            RequireExistingFile(parentDir "\lib\py_helpers\DiscordRPC.exe", "Existing DiscordRPC helper")
            ShowCenteredToolTip "Using existing DiscordRPC.exe"
            sleep 700
        }

        ; === Compile and package the main vaultOps executable ===
        ToolTip "", , , 1
        ShowCenteredToolTip "Packaging vaultOps"
        RunWait vaultOpsCmd, , "Hide"
        BloatExe(outFile, 1500)
        RunWait updaterCmd, , "Hide"
        RunWait innoCmd, , "Hide"

        if RequireExistingFile(vaultOpsInstaller, "Installer") {
            ; cleanup intermediate build files
            try FileDelete(outFile)
            try FileDelete(updaterOutFile)

            ShowCenteredToolTip "Distribution build and Inno Setup installer complete!"
            ; Scan with VirusTotal if option selected
            if (scanVirusTotal) {
                sleep 1000
                ShowCenteredToolTip "Scanning vaultOps.exe with VirusTotal..."
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

    if (compileStandalone)
        createStandalonePackages(quotedBase, parentDir, packageStandalone, useOriginalClasses, buildVaultOpsExe)

    UpdateSizesOfEachScript()
    if (scanVirusTotal)
        RunScan(vaultOpsInstaller)

    FocusOrOpenFolder(parentDir "\dist")

    ; Compile this script to .exe if not already compiled
    if !A_IsCompiled {
        AHK2EXEPath := "AHK2EXE\Ahk2Exe.exe"
        baseExe := "AHK_BASE\AutoHotkeyUX.exe"

        if FileExist(AHK2EXEPath) && FileExist(baseExe) {
            scriptPath := A_ScriptFullPath
            exePath := A_ScriptDir "\compile_scripts.exe"
            quotedBase := '"' baseExe '"'

            distCmd := '"' AHK2EXEPath '" /in "' scriptPath '" /out "' exePath '" /compress 0 /base ' quotedBase
            RunWait distCmd, , "Hide"

            if FileExist(exePath) {
                ShowCenteredToolTip "compiled dist.ahk"
            }
        }
    }
    sleep 2000
    ExitApp
}

UpdateSizesOfEachScript() {
    distDir := parentDir "\dist"
    targetSizes := Map()

    if (buildVaultOpsExe)
        targetSizes.Set(distDir "\vaultOps-Setup.exe", 56320)

    if (packageStandalone)
        targetSizes.Set(distDir "\vaultOps-Standalone-Pack.exe", 48128)

    if (compileStandalone) {
        targetSizes.Set(distDir "\NoSave-Standalone.exe", 1500)
        targetSizes.Set(distDir "\Util-AFK-Key-Holder.exe", 1500)
        targetSizes.Set(distDir "\Util-Solo-Public-Session.exe", 1500)
        targetSizes.Set(distDir "\Util-TriggerBot.exe", 1500)
    }

    for exePath, targetKB in targetSizes {
        if !FileExist(exePath)
            continue

        BloatExe(exePath, targetKB)
    }
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
    venvPython := projectRoot "\.venv\Scripts\python.exe"
    venvActivate := projectRoot "\.venv\Scripts\Activate.ps1"

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
    try FileDelete(builtExe)

    if !FileExist(outputFile) {
        MsgBox "OpenCV_Engine.exe was not copied into the py_helpers folder.", "Error", 48
        ExitApp
    }
}

BuildDiscordRPC(parentDir) {
    global iconPath

    pyHelpersDir := parentDir "\lib\py_helpers"
    sourceFile := pyHelpersDir "\DiscordRPC.py"
    outputFile := pyHelpersDir "\DiscordRPC.exe"
    buildDir := pyHelpersDir "\nuitka_build"
    builtExe := buildDir "\DiscordRPC.exe"

    RequireExistingFile(sourceFile, "Discord RPC helper")

    ; Prefer a project-local venv
    projectRoot := DirGetParent(parentDir)
    venvPython := projectRoot "\.venv\Scripts\python.exe"

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

    if !DirExist(buildDir)
        try DirCreate(buildDir)

    ShowCenteredToolTip "Compiling DiscordRPC.py with Nuitka..."

    quotedPython := '"' pythonExe '"'

    nuitkaCmd := quotedPython
        . ' -m nuitka'
        . ' --onefile'
        . ' --windows-console-mode=disable'
        . ' --assume-yes-for-downloads'
        ; . ' --report="' buildDir '\DiscordRPC-report.xml"'
        ; . ' --report-diffable'
        ; . ' --disable-plugin=multiprocessing'
        . ' --nofollow-import-to=tkinter'
        . ' --nofollow-import-to=matplotlib'
        . ' --nofollow-import-to=scipy'
        . ' --nofollow-import-to=pytest'
        . ' --nofollow-import-to=unittest'
        . ' --windows-icon-from-ico="' iconPath '"'
        . ' --output-filename="DiscordRPC.exe"'
        . ' --output-dir="' buildDir '"'
        . ' "' sourceFile '"'

    RunWait nuitkaCmd, , "Hide"

    Sleep 3000

    if !FileExist(builtExe) {
        MsgBox "Nuitka finished but DiscordRPC.exe was not created.`n`nCommand:`n" nuitkaCmd,
            "Error",
            48
        ExitApp
    }

    FileCopy builtExe, outputFile, true

    try DirDelete(buildDir "\nuitka_temp", true)
    try FileDelete(builtExe)

    if !FileExist(outputFile) {
        MsgBox "DiscordRPC.exe was not copied into the py_helpers folder.",
            "Error",
            48
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
    utilsDir := parentDir "\lib\utils"

    distFolder := parentDir "\dist\"
    distStandaloneDir := distFolder "standalone"
    bundleFile := distFolder "vaultOps-Standalone-Pack.exe"
    standaloneExtractionFolder := "vaultOps-Standalone-Pack"
    standaloneUpdaterInFile := parentDir "\lib\standaloneUpdate.ahk"
    standaloneUpdaterOutFile := parentDir "\lib\standaloneUpdater.exe"

    standaloneUpdaterCmd := '"' AHK2EXEPath '" /in "' standaloneUpdaterInFile '" /out "' standaloneUpdaterOutFile '" /icon "' iconPath '" /compress 0 /base ' quotedBase

    imageFolders := ["1366x768", "1600x900", "1920x1080"]

    standaloneClassMap := Map(
        "Standalone-Fingerprint.ahk", parentDir "\lib\scripts\Fingerprint.ahk",
        "Standalone-Keypad.ahk", parentDir "\lib\scripts\Keypad.ahk",
        "Standalone-ElRubio.ahk", parentDir "\lib\scripts\ElRubio.ahk"
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

    ShowCenteredToolTip "Compiling standalone updater"
    if (compileStandalone)
        RunWait standaloneUpdaterCmd, , "Hide"

    if (FileExist(rarExe)) {

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

            exeName := StrReplace(scriptName, "Standalone-", "")
            exeName := StrReplace(exeName, ".ahk", "-Standalone.exe")
            outExe := distStandaloneDir "\" exeName

            scriptToCompile := script
            tempScript := ""

            if (useOriginalClasses && standaloneClassMap.Has(scriptName)) {

                originalScript := standaloneClassMap[scriptName]
                tempPath := standaloneDir "\temp_" scriptName

                ToolTip "Preparing " scriptName "...", 0, 0, 1

                try {
                    CreateTempScriptWithReplacedInclude(script, originalScript, tempPath)

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

            BloatExe(outExe, 1500)

            ; track compiled exe
            compiledExeList.Push(exeName)
        }

        utilRenameMap := Map(
            "Util-TB.ahk", "Util-TriggerBot.exe"
        )

        loop files, utilsDir "\Util-*.ahk", "F" {

            script := A_LoopFilePath

            SplitPath script, &scriptName

            if utilRenameMap.Has(scriptName)
                exeName := utilRenameMap[scriptName]
            else
                exeName := StrReplace(scriptName, ".ahk", ".exe")

            ShowCenteredToolTip "Compiling: " exeName

            outExe := distFolder "\" exeName

            cmd := '"' AHK2EXEPath '" /in "' script '" /out "' outExe '" /icon "' iconPath '" /compress 0 /base ' quotedBase

            RunWait cmd, , "Hide"

            ShowCenteredToolTip "Compiled: " exeName

            ; copy directly to dist root
            ; try FileCopy(
            ;     outExe,
            ;     distFolder exeName,
            ;     true
            ; )

            ; don't add to compiledExeList
        }

        ; stop here if packaging disabled
        if (!packageBuilds) {
            ShowCenteredToolTip "Standalone compile complete."
            return
        }

        try FileCopy(
            iconPath,
            distStandaloneDir "\vaultOps.ico",
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
        rarCmd := '"' rarExe '" a -r -sfx -iicon"' distStandaloneDir '\vaultOps.ico" "' bundleFile '" ' exeStr ' "lib\OpenCV_Engine.exe" "lib\standaloneUpdater.exe"' imgStr ' -z"bundle.txt"'

        RunWait rarCmd, , "Hide"

        SetWorkingDir(A_ScriptDir)

        ToolTip "Standalone bundle created", 0, 0, 1

        ; cleanup temporary standalone staging folder
        try DirDelete(distStandaloneDir, true)
        try FileDelete(standaloneUpdaterOutFile)

        ShowCenteredToolTip "Standalone bundle packaging complete."

        sleep 1000

    } else {

        MsgBox(
            "WinRAR not found at: " rarExe,
            "Error"
        )
    }
}

BloatExe(exePath, targetKB) {
    if !FileExist(exePath)
        throw Error("File not found: " exePath)

    SplitPath exePath, &scriptName

    ShowCenteredToolTip "Bloating " scriptName " to " targetKB " KB"

    targetBytes := targetKB * 1024
    currentBytes := FileGetSize(exePath)

    if (currentBytes >= targetBytes) {
        MsgBox scriptName " is already " (currentBytes // 1024) " KB. Couldn't bloat to " targetKB " KB.",
        "Info", 64
        return false
    }

    bytesToAdd := targetBytes - currentBytes

    file := FileOpen(exePath, "a")
    if !file
        throw Error("Failed to open file.")

    file.Pos := file.Length

    ; Write in 64 KB chunks.
    chunk := Buffer(65536, 0)

    while (bytesToAdd > 0) {
        writeSize := Min(bytesToAdd, chunk.Size)
        file.RawWrite(chunk, writeSize)
        bytesToAdd -= writeSize
    }

    file.Close()
    return true
}

buildGUI(isDev := false) {
    global parentDir
    dlg := Gui("-DPIScale", "Build options")
    dlg.SetFont("s" GetScaledFontSize(10))

    dlg.AddText("xm+9 ym", "Choose build options:")
    existingOpenCVHelper := parentDir "\lib\py_helpers\OpenCV_Engine.exe"
    hasExistingOpenCV := FileExist(existingOpenCVHelper) != ""
    existingDiscordRPCHelper := parentDir "\lib\py_helpers\DiscordRPC.exe"
    hasExistingDiscordRPC := FileExist(existingDiscordRPCHelper) != ""

    ; ==== VaultOps build options ====
    dlg.AddGroupBox("xm yp+25 w360 h50", "Build vaultOps.exe")
    rBuildYes := dlg.AddRadio("xp+14 yp+23 Group ", "Yes")
    rBuildNo := dlg.AddRadio("x+60 yp Checked", "No")

    ; ==== OpenCV helper build options ====
    dlg.AddGroupBox("xm y+12 w360 h50", "Build OpenCV_Engine.exe")
    rOpenCVYes := dlg.AddRadio("xp+14 yp+23 Group" (hasExistingOpenCV ? "" : " Checked"), "Yes")
    rOpenCVNo := dlg.AddRadio("x+80 yp" (hasExistingOpenCV ? " Checked" : ""), "No (use existing exe)")

    ; ==== DiscordRPC build options ====
    dlg.AddGroupBox("xm y+12 w360 h50", "Build DiscordRPC.exe")
    rDiscordYes := dlg.AddRadio("xp+14 yp+23 Group" (hasExistingDiscordRPC ? "" : " Checked"), "Yes")
    rDiscordNo := dlg.AddRadio("x+80 yp" (hasExistingDiscordRPC ? " Checked" : ""), "No (use existing exe)")

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

    ; rScanYes.OnEvent("Click", validateApiKey)

    ValidateOpenCVReuse(showWarning := false) {
        hasExistingOpenCV := FileExist(existingOpenCVHelper)

        if (rOpenCVNo.Value == 1 && !hasExistingOpenCV) {
            if (showWarning) {
                MsgBox "OpenCV_Engine.exe was not found at:`n" existingOpenCVHelper
                    . "`n`nThe existing-exe option is disabled. Build OpenCV_Engine.exe has been forced to Yes.",
                    "Warning", 48
            }

            rOpenCVNo.Enabled := false
            rOpenCVYes.Value := 1
            rOpenCVNo.Value := 0
            return
        }

        rOpenCVNo.Enabled := hasExistingOpenCV
        if !hasExistingOpenCV {
            rOpenCVYes.Value := 1
            rOpenCVNo.Value := 0
        }
    }

    ValidateDiscordRPCReuse(showWarning := false) {
        hasExistingDiscordRPC := FileExist(existingDiscordRPCHelper)

        if (rDiscordNo.Value == 1 && !hasExistingDiscordRPC) {
            if (showWarning) {
                MsgBox "DiscordRPC.exe was not found at:`n" existingDiscordRPCHelper
                    . "`n`nThe existing-exe option is disabled. Build DiscordRPC.exe has been forced to Yes.",
                    "Warning", 48
            }

            rDiscordNo.Enabled := false
            rDiscordYes.Value := 1
            rDiscordNo.Value := 0
            return
        }

        rDiscordNo.Enabled := hasExistingDiscordRPC
        if !hasExistingDiscordRPC {
            rDiscordYes.Value := 1
            rDiscordNo.Value := 0
        }
    }

    UpdateOpenCVBuildOptions(showWarning := false) {
        enabled := (rBuildYes.Value == 1)

        rOpenCVYes.Enabled := enabled
        rOpenCVNo.Enabled := enabled

        if !enabled {
            return
        }

        ValidateOpenCVReuse(showWarning)
    }

    UpdateDiscordRPCBuildOptions(showWarning := false) {
        enabled := (rBuildYes.Value == 1)

        rDiscordYes.Enabled := enabled
        rDiscordNo.Enabled := enabled

        if !enabled {
            return
        }

        ValidateDiscordRPCReuse(showWarning)
    }

    rOpenCVNo.OnEvent("Click", (*) => ValidateOpenCVReuse(true))
    rDiscordNo.OnEvent("Click", (*) => ValidateDiscordRPCReuse(true))

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
        UpdateOpenCVBuildOptions()
        UpdateDiscordRPCBuildOptions()
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
            buildOpenCVEngine: rOpenCVYes.Value == 1,
            buildDiscordRPC: rDiscordYes.Value == 1,
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

CreateTempScriptWithReplacedInclude(standaloneScript, originalScript, tempPath) {
    if !FileExist(standaloneScript)
        throw Error("Standalone script not found: " standaloneScript)

    if !FileExist(originalScript)
        throw Error("Original script not found: " originalScript)

    standaloneContent := FileRead(standaloneScript)
    originalContent := FileRead(originalScript)

    includeLine := ""
    for _, line in StrSplit(standaloneContent, "`n", "`r") {
        trimmedLine := Trim(line)
        ; MsgBox trimmedLine
        if (SubStr(trimmedLine, 1, StrLen('#Include classes\')) = '#Include classes\') {
            includeLine := trimmedLine
            break
        }
    }

    if (includeLine = "")
        throw Error("Class include not found in standalone script: " standaloneScript)

    count := 0

    replacedContent := StrReplace(
        standaloneContent,
        includeLine,
        originalContent,
        ,
        &count,
        1
    )

    try FileDelete(tempPath)
    FileAppend(replacedContent, tempPath)

    return true
}

; --- Helper functions for temp file creation ---
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

RequireExistingFile(path, label) {
    if !FileExist(path)
        throw Error(label " not found: " path)
    return true
}

OpenFolderAsUser(path) {
    ; Opens folder as the current (non-elevated) user, even if script is admin
    DllCall("shell32\ShellExecuteW", "ptr", 0, "wstr", "open", "wstr", "explorer.exe", "wstr", '"' path '"', "ptr",
        0,
        "int", 1)
}

F2:: Reload