#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#NoTrayIcon
global ver
ver:=2

url := "https://script.google.com/macros/s/AKfycbxUOucgWvvz3V4FYGqxrgrHfLVtJlYZ6re5ATaEMhGczKCQ095g3VtWXo1BSyRRGDmIfQ/exec"
try {
    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", url, false)
    http.Send()
}
catch
{
    ; Silent fail
}


ExitApp
