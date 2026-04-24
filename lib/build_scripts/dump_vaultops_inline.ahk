#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

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

parentDir := DirGetParent(A_ScriptDir)
sourceFile := parentDir "\vaultOps.ahk"
outDir := parentDir "\dist\dump"
inlineDumpFile := outDir "\vaultOps.inlined.ahk"
compiledExe := outDir "\vaultOps.dump.exe"

ahk2exe := A_ScriptDir "\AHK2EXE\Ahk2Exe.exe"
baseExe := A_ScriptDir "\AHK_BASE\AutoHotkeyUX.exe"

if !FileExist(sourceFile)
    Fail("Source file not found: " sourceFile)
if !FileExist(ahk2exe)
    Fail("Ahk2Exe not found: " ahk2exe)
if !FileExist(baseExe)
    Fail("Base executable not found: " baseExe)

if !DirExist(outDir)
    DirCreate(outDir)

seen := Map()
inlineText := ExpandIncludes(sourceFile, parentDir, seen)
FileDeleteSafe(inlineDumpFile)
FileAppend(inlineText, inlineDumpFile, "UTF-8-RAW")

quotedBase := '"' baseExe '"'
cmd := '"' ahk2exe '" /in "' sourceFile '" /out "' compiledExe '" /compress 0 /base ' quotedBase
RunWait(cmd, A_ScriptDir, "Hide")

if !FileExist(compiledExe)
    Fail("Compilation failed. EXE not created: " compiledExe)

MsgBox("Done.`n`nCompiled: " compiledExe "`nDumped: " inlineDumpFile, "vaultOps dump helper", "Iconi")
ExitApp

ExpandIncludes(filePath, projectRoot, seen) {
    full := NormalizePath(filePath)
    if seen.Has(full)
        return ""
    seen[full] := true

    text := FileRead(full, "UTF-8")
    lines := StrSplit(text, "`n", "`r")

    out := "; ===== BEGIN: " full " =====`n"
    for line in lines {
        if RegExMatch(line, "i)^\s*#Include\s+(.+)$", &m) {
            includeRaw := Trim(m[1])
            includePath := ResolveInclude(includeRaw, full, projectRoot)
            if (includePath = "") {
                out .= line "`n"
                continue
            }
            out .= ExpandIncludes(includePath, projectRoot, seen)
            continue
        }
        out .= line "`n"
    }
    out .= "; ===== END: " full " =====`n`n"
    return out
}

ResolveInclude(includeRaw, currentFile, projectRoot) {
    token := Trim(includeRaw)

    if (SubStr(token, 1, 1) = "<" && SubStr(token, -1) = ">")
        token := SubStr(token, 2, -1)
    else if ((SubStr(token, 1, 1) = '"' && SubStr(token, -1) = '"')
    || (SubStr(token, 1, 1) = "'" && SubStr(token, -1) = "'"))
        token := SubStr(token, 2, -1)

    token := StrReplace(token, "/", "\")
    currentDir := DirGetParent(currentFile)

    candidates := []
    candidates.Push(currentDir "\" token)
    candidates.Push(currentDir "\" token ".ahk")
    candidates.Push(projectRoot "\" token)
    candidates.Push(projectRoot "\" token ".ahk")
    candidates.Push(projectRoot "\lib\" token)
    candidates.Push(projectRoot "\lib\" token ".ahk")

    for candidate in candidates {
        normalized := NormalizePath(candidate)
        if FileExist(normalized)
            return normalized
    }
    return ""
}

NormalizePath(path) {
    return RegExReplace(path, "\\+", "\\")
}

FileDeleteSafe(path) {
    try {
        if FileExist(path)
            FileDelete(path)
    }
}

Fail(msg) {
    MsgBox(msg, "vaultOps dump helper", "Iconx")
    ExitApp(1)
}
