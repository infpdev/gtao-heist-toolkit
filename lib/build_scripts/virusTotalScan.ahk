#Requires AutoHotkey v2.0
SetWorkingDir A_ScriptDir
#Include .\helpers\_JXON.ahk
#Include .\helpers\FileHash_SHA256.ahk

global apiKey := ""

; Run scan if script is executed directly (not imported)
if (A_ScriptFullPath = A_LineFile) {
    ShowCenteredToolTip ("Scanning vaultOps.exe", 17)
    RunScan()
}

; === Entry ===
RunScan(filePath := "..\..\dist\vaultOps-Setup.exe") {

    if (!IsSet(apiKey) || apiKey = "") {
        apiKey := LoadOrPromptAPIKey()
        if (!apiKey) {
            MsgBox("VirusTotal API key is required for scanning.", "Error", 48)
            ExitApp
        }
    }

    if !FileExist(filePath != "" ? filePath : "..\..\dist\vaultOps-Setup.exe") {
        MsgBox("File not found: ..\..\dist\vaultOps-Setup.exe")
        ExitApp
    }

    uploadResponse := UploadFile(filePath != "" ? filePath : "..\..\dist\vaultOps-Setup.exe", apiKey)

    obj := Jxon_Load(&uploadResponse)

    if obj.Has("error") {
        if (obj["error"]["code"] = "AlreadySubmittedError") {
            return HandleAlreadySubmitted(filePath, apiKey)
        } else {
            MsgBox("Upload failed:`n" uploadResponse)
            ExitApp
        }
    }

    reportURL := ExtractReportURL(uploadResponse)
    report := PollForCompletion(reportURL, apiKey)
    fileHash := ExtractFileHash(report)

    ; Update README.md with latest VirusTotal link
    UpdateReadmeLink(fileHash)

    Run("https://www.virustotal.com/gui/file/" fileHash)
}

; === HandleAlreadySubmitted ===
HandleAlreadySubmitted(filePath, apiKey) {
    fileHash := ComputeSHA256(filePath)

    MsgBox("File already submitted. Fetching existing report...")

    return PollFileReport(fileHash, apiKey)
}

ComputeSHA256(filePath) {
    sha := GetFileHash_SHA256(filePath)
    MsgBox("Computed SHA256: " sha)
    return sha
}

; === LoadOrPromptAPIKey ===
LoadOrPromptAPIKey() {
    global apiKey
    configFile := ".\build_options.ini"
    apiKey := IniRead(configFile, "VirusTotal", "ApiKey", "")

    if (apiKey != "") {
        return apiKey
    }

    result := InputBox("Enter VirusTotal API key:")
    if (result.Result = "OK" && result.Value != "") {
        IniWrite(result.Value, configFile, "VirusTotal", "ApiKey")
        apiKey := result.Value
        MsgBox "VirusTotal API key validated. Scanning will be enabled.", "Success", 64
        return result.Value
    }

    return false
    ; ExitApp
}

; === UploadFile ===
UploadFile(filePath, apiKey) {
    curlCmd := "curl -s -X POST https://www.virustotal.com/api/v3/files -H `"X-Apikey: " apiKey "`" -F `"file=@" filePath "`""
    outFile := A_Temp "\vt_upload.json"
    RunWait(A_ComSpec " /C " curlCmd " > " outFile, , "Hide")
    response := FileRead(outFile)
    FileDelete(outFile)

    return response
}

; === ExtractReportURL ===
ExtractReportURL(response) {
    obj := Jxon_Load(&response)
    try {
        return obj["data"]["links"]["self"]
    } catch {
        MsgBox("Failed to parse upload response:`n" response)
        ExitApp
    }
}

; === PollForCompletion ===
PollForCompletion(reportURL, apiKey) {
    reportFile := A_Temp "\vt_report.json"

    loop {
        curlCmd := "curl -s -H `"x-apikey: " apiKey "`" " reportURL
        RunWait(A_ComSpec " /C " curlCmd " > " reportFile, , "Hide")

        report := FileRead(reportFile)
        obj := Jxon_Load(&report)

        if (obj["data"]["attributes"]["status"] = "completed")
            break

        Sleep 3000
    }

    FileDelete(reportFile)
    return report
}

; === Find existing report by file hash ===
PollFileReport(fileHash, apiKey) {
    reportFile := A_Temp "\vt_file.json"

    loop {
        url := "https://www.virustotal.com/api/v3/files/" fileHash
        curlCmd := "curl -s -H `"x-apikey: " apiKey "`" " url
        RunWait(A_ComSpec " /C " curlCmd " > " reportFile, , "Hide")

        report := FileRead(reportFile)
        obj := Jxon_Load(&report)

        if obj.Has("data") {
            FileDelete(reportFile)
            return report
        }

        Sleep 3000
    }
}

; === ExtractFileHash ===
ExtractFileHash(report) {
    obj := Jxon_Load(&report)
    try {
        return obj["meta"]["file_info"]["sha256"]
    } catch {
        MsgBox("Failed to extract file hash from report")
        ExitApp
    }
}

; === UpdateReadmeLink ===
UpdateReadmeLink(fileHash) {
    readmeFile := "..\..\README.md"

    if !FileExist(readmeFile) {
        MsgBox("README.md not found at: " readmeFile)
        return
    }

    try {
        ; Read with UTF-8 encoding
        content := FileRead(readmeFile, "UTF-8")

        ; Replace VirusTotal link with new one
        newLink := "https://www.virustotal.com/gui/file/" fileHash
        content := RegExReplace(content, "https://www\.virustotal\.com/gui/file/[A-Fa-f0-9]{64}", newLink)

        ; Write back with UTF-8 encoding, preserving BOM
        FileDelete(readmeFile)
        f := FileOpen(readmeFile, "w", "UTF-8")
        f.Write(content)
        f.Close()

        ShowCenteredToolTip "vaultOps.exe scan completed"
        MsgBox("README.md updated with latest VirusTotal link!", "Success", 64)
    } catch as err {
        MsgBox("Failed to update README.md: " err.Message, "Error", 48)
    }
}
