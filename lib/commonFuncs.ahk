; Global variable for cache file path, used in LoadCache and SaveCache functions

if (IsSet(dir)) {
    cacheFile := dir "\zAnchorCache.ini"
} else {
    cacheFile := A_ScriptDir "\zAnchorCache.ini"
}

/**
 * @description Loads cached anchor coordinates from anchorCache.ini into global cache variables.
 * Creates the cache file with zero defaults when it does not exist.
 * @returns {boolean} True when load flow completes.
 */
LoadCache() {
    global cachedFingerprintAnchor, cachedKeypadAnchor, cachedRubioAnchor

    ; cacheFile := A_ScriptDir "\zAnchorCache.ini"
    if !FileExist(cacheFile) {
        FileAppend(
            "[fingerprint]`nx=0`ny=0`n`n"
            . "[keypad]`nx=0`ny=0`n`n"
            . "[rubio]`nx=0`ny=0`n",
            cacheFile,
            "UTF-8-RAW"
        )
    }

    cachedFingerprintAnchor := ReadCachedAnchor(cacheFile, "fingerprint")
    cachedKeypadAnchor := ReadCachedAnchor(cacheFile, "keypad")
    cachedRubioAnchor := ReadCachedAnchor(cacheFile, "rubio")
    return true
}

/**
 * @description Persists current cached anchor objects to anchorCache.ini.
 * @returns {boolean} False when required globals are not initialized or cache file is missing; otherwise true.
 */
SaveCache() {
    global cachedFingerprintAnchor, cachedKeypadAnchor, cachedRubioAnchor

    ; cacheFile := A_ScriptDir "\zAnchorCache.ini"
    if !FileExist(cacheFile) || !IsSet(cachedFingerprintAnchor) || !IsSet(cachedKeypadAnchor) || !IsSet(
        cachedRubioAnchor)
        return false

    WriteCachedAnchor(cacheFile, "fingerprint", cachedFingerprintAnchor)
    WriteCachedAnchor(cacheFile, "keypad", cachedKeypadAnchor)
    WriteCachedAnchor(cacheFile, "rubio", cachedRubioAnchor)
    return true
}

; Delete cache in case of errors
DeleteCache() {
    global cacheFile
    if FileExist(cacheFile) {
        FileDelete(cacheFile)
    }
}

KillGta() {
    killed := false
    if pid := ProcessExist("GTA5.exe") {
        ProcessClose(pid)
        killed := true
    }
    else if pid := ProcessExist("GTA5_Enhanced.exe") {
        killed := true
        ProcessClose(pid)
    }

    if (noSave)
        ToggleNoSaveStatus()

    if (killed) {
        ShowCenteredToolTip("GTA5 killed", 17)
    } else {
        ShowCenteredToolTip("GTA5 not running", 17)
        SetTimer(() => ToolTip("", , , 17), -2000)
    }

}
