#Requires AutoHotkey v2.0
; Minimal SHA-256 file hashing for AHK v2
; Ported from Crypt.ahk v1

GetFileHash_SHA256(filePath) {
    if !FileExist(filePath) {
        MsgBox("Cannot open file: " filePath, "Error", 48)
        return ""
    }

    static bcryptLoaded := DllCall("LoadLibrary", "Str", "bcrypt.dll", "Ptr")
    static hAlg := 0
    static hashSize := 0
    static objSize := 0

    ; Init algorithm provider once
    if (!hAlg) {
        status := DllCall("bcrypt\BCryptOpenAlgorithmProvider"
            , "Ptr*", &hAlg
            , "WStr", "SHA256"
            , "Ptr", 0
            , "UInt", 0
            , "UInt")

        if (status != 0) {
            MsgBox("BCryptOpenAlgorithmProvider failed`nStatus: " status, "Error", 48)
            return ""
        }

        ; Get object length
        objSizeBuf := Buffer(4, 0)
        bytesOut := 0
        status := DllCall("bcrypt\BCryptGetProperty"
            , "Ptr", hAlg
            , "WStr", "ObjectLength"
            , "Ptr", objSizeBuf.Ptr
            , "UInt", 4
            , "UInt*", &bytesOut
            , "UInt", 0
            , "UInt")

        if (status != 0) {
            MsgBox("BCryptGetProperty(ObjectLength) failed`nStatus: " status, "Error", 48)
            return ""
        }
        objSize := NumGet(objSizeBuf, 0, "UInt")

        ; Get hash digest length
        hashSizeBuf := Buffer(4, 0)
        bytesOut := 0
        status := DllCall("bcrypt\BCryptGetProperty"
            , "Ptr", hAlg
            , "WStr", "HashDigestLength"
            , "Ptr", hashSizeBuf.Ptr
            , "UInt", 4
            , "UInt*", &bytesOut
            , "UInt", 0
            , "UInt")

        if (status != 0) {
            MsgBox("BCryptGetProperty(HashDigestLength) failed`nStatus: " status, "Error", 48)
            return ""
        }
        hashSize := NumGet(hashSizeBuf, 0, "UInt")
    }

    ; Create fresh hash object per file
    hashObject := Buffer(objSize, 0)
    hHash := 0

    status := DllCall("bcrypt\BCryptCreateHash"
        , "Ptr", hAlg
        , "Ptr*", &hHash
        , "Ptr", hashObject.Ptr
        , "UInt", hashObject.Size
        , "Ptr", 0
        , "UInt", 0
        , "UInt", 0
        , "UInt")

    if (status != 0) {
        MsgBox("BCryptCreateHash failed`nStatus: " status, "Error", 48)
        return ""
    }

    try {
        f := FileOpen(filePath, "r")
    } catch {
        MsgBox("Cannot open file: " filePath, "Error", 48)
        return ""
    }

    BUFF_SIZE := 1024 * 1024
    readBuf := Buffer(BUFF_SIZE)

    while (bytesRead := f.RawRead(readBuf, BUFF_SIZE)) > 0 {
        status := DllCall("bcrypt\BCryptHashData"
            , "Ptr", hHash
            , "Ptr", readBuf.Ptr
            , "UInt", bytesRead
            , "UInt", 0
            , "UInt")

        if (status != 0) {
            f.Close()
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
            MsgBox("BCryptHashData failed`nStatus: " status, "Error", 48)
            return ""
        }
    }
    f.Close()

    hashBuffer := Buffer(hashSize, 0)

    status := DllCall("bcrypt\BCryptFinishHash"
        , "Ptr", hHash
        , "Ptr", hashBuffer.Ptr
        , "UInt", hashSize
        , "UInt", 0
        , "UInt")

    DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)

    if (status != 0) {
        MsgBox("BCryptFinishHash failed`nStatus: " status, "Error", 48)
        return ""
    }

    return BufferToHex(hashBuffer, hashSize)
}

BufferToHex(buf, len) {
    hex := ""
    loop len {
        hex .= Format("{:02x}", NumGet(buf, A_Index - 1, "UChar"))
    }
    return hex
}
