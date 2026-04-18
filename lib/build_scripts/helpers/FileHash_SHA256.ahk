#Requires AutoHotkey v2.0
; Minimal SHA-256 file hashing for AHK v2
; Ported from Crypt.ahk v1

GetFileHash_SHA256(filePath) {
    ; Windows Crypto API constants
    PROV_RSA_AES := 24
    CRYPT_VERIFYCONTEXT := 0xF0000000
    CALG_SHA_256 := 0x0000800C
    HP_HASHVAL := 0x0002
    HP_HASHSIZE := 0x0004

    ; Acquire context
    hCryptProv := 0
    if !DllCall("Advapi32\CryptAcquireContextW", "Ptr*", hCryptProv, "Uint", 0, "Uint", 0, "Uint", PROV_RSA_AES, "UInt",
        CRYPT_VERIFYCONTEXT) {
        MsgBox("CryptAcquireContextW failed", "Error", 48)
        return ""
    }

    ; Create hash object for SHA-256
    hHash := 0
    if !DllCall("Advapi32\CryptCreateHash", "Ptr", hCryptProv, "Uint", CALG_SHA_256, "Uint", 0, "Uint", 0, "Ptr*",
        hHash) {
        DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)
        MsgBox("CryptCreateHash failed", "Error", 48)
        return ""
    }

    ; Open file
    try {
        f := FileOpen(filePath, "r", "CP0")
    } catch as err {
        DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
        DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)
        MsgBox("Cannot open file: " filePath, "Error", 48)
        return ""
    }

    ; Hash file in chunks
    BUFF_SIZE := 1024 * 1024  ; 1 MB chunks
    readBuf := Buffer(BUFF_SIZE, 0)

    while (bytesRead := f.RawRead(readBuf, BUFF_SIZE)) > 0 {
        if !DllCall("Advapi32\CryptHashData", "Ptr", hHash, "Ptr", readBuf, "Uint", bytesRead, "Uint", 0) {
            f.Close()
            DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
            DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)
            MsgBox("CryptHashData failed", "Error", 48)
            return ""
        }
    }
    f.Close()

    ; Get hash size
    hashLenBuf := Buffer(4, 0)
    if !DllCall("Advapi32\CryptGetHashParam", "Ptr", hHash, "Uint", HP_HASHSIZE, "Ptr", hashLenBuf, "Uint*", dwHashLen :=
        4, "UInt", 0) {
        DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
        DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)
        MsgBox("CryptGetHashParam (size) failed", "Error", 48)
        return ""
    }

    hashLen := NumGet(hashLenBuf, 0, "UInt")

    ; Get hash value
    pbHash := Buffer(hashLen, 0)
    if !DllCall("Advapi32\CryptGetHashParam", "Ptr", hHash, "Uint", HP_HASHVAL, "Ptr", pbHash, "Uint*", hashLen, "UInt",
        0) {
        DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
        DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)
        MsgBox("CryptGetHashParam (value) failed", "Error", 48)
        return ""
    }

    ; Convert to hex string
    hashResult := BufferToHex(pbHash, hashLen)

    ; Cleanup
    DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
    DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)

    return hashResult
}

BufferToHex(buf, len) {
    hex := ""
    loop len {
        byte := NumGet(buf, A_Index - 1, "UChar")
        hex .= Format("{:02x}", byte)
    }
    return hex
}
