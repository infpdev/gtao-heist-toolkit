#NoEnv
ver:=3
CheckForUpdate() {
	global ver
    Url := "https://pastebin.com/raw/DYsmy7fD"
    Http := ComObjCreate("WinHttp.WinHttpRequest.5.1")

    try {
        Http.Open("GET", Url, false)
        Http.Send()

        if (Http.Status = 200) {
            result := Trim(Http.ResponseText)
            if (result > ver) {
                MsgBox, 0, Update Check, Update available. Check the description for the new version :)`n- dev
		exitapp
            } else {
                screenCenterX := A_ScreenWidth // 2 -80
                Tooltip, No updates found. Enjoy :), %screenCenterX%, 0, 17
                            }
        }
    } catch {
        ; No internet or request failed – silently skip
    }
}
CheckForUpdate()
Sleep, 1000

if FileExist("Update.exe")
{
    Run, Update.exe
}
else
{
    MsgBox, 0, Error, You removed Update.exe! Please restore it!
Exitapp
}


originalName := "Casinjo by dev XD.exe" ; Change this to your intended exe name

if (A_IsCompiled) {
    if (A_ScriptName != originalName) {
	clipboard := "Casinjo by dev XD"
        MsgBox, This script has been renamed! Change it back to Casinjo by dev XD! File name has been copied to your clipboard, simply Ctrl + V it!
        ExitApp
    }
}



if !FileExist("hotkeys.ini") {
    FileAppend, 
(
; ---------------------------
; Hotkey notation reference:
; ^ = Ctrl   → e.g. ^h means Ctrl + H
; ! = Alt    → e.g. !h means Alt + H
; + = Shift  → e.g. +h means Shift + H
; # = Win    → e.g. #h means Win + H
; ---------------------------

[Hotkeys]

Hack=h
Terminate=t
Reload=r

;27 May 2025: New hotkey
;Use this key if you want to manually select the prints.. Useful when the script selects wrong prints.. Simply press m (or the key you choose) instead of r to go into manual mode..
Manual=m
), hotkeys.ini
}



SendMode, Event
SetWorkingDir %A_ScriptDir%
CoordMode, ToolTip, Screen
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
#SingleInstance Force

SetTitleMatchMode 2
#WinActivateForce
SetControlDelay 1
SetWinDelay 0
SetMouseDelay -1
SetBatchLines -1

;Commented the section below to debug for legacy-window bugs

;IniRead, key1, hotkeys.ini, Hotkeys, Reload, r
;Hotkey, %key1%, DoReload

;IniRead, key2, hotkeys.ini, Hotkeys, Terminate, t
;Hotkey, %key2%, DoExitApp

;IniRead, matchKey, hotkeys.ini, Hotkeys, Hack, h
;Hotkey, %matchKey%, DoMatch

;IniRead, manual, hotkeys.ini, Hotkeys, Manual, m
;Hotkey, %manual%, ToggleManual



; ==================================
; Legacy/E&E-safe hotkeys using low-level hooks
; ==================================

; Reload
IniRead, key1, hotkeys.ini, Hotkeys, Reload, r
Hotkey, ~*%key1%, DoReload

; Terminate
IniRead, key2, hotkeys.ini, Hotkeys, Terminate, t
Hotkey, ~*%key2%, DoExitApp

; Hack
IniRead, matchKey, hotkeys.ini, Hotkeys, Hack, h
Hotkey, ~*%matchKey%, DoMatch

; Manual
IniRead, manual, hotkeys.ini, Hotkeys, Manual, m
Hotkey, ~*%manual%, ToggleManual






XP1 := A_ScreenWidth / 6
YP1 := A_ScreenHeight / 6
XP2 := A_ScreenWidth / 2
YP2 := A_ScreenHeight - (A_ScreenHeight / 6)

XK1 := A_ScreenWidth / 6
YK1 := A_ScreenHeight / 6
XK2 := A_ScreenWidth - (A_ScreenWidth / 3)
YK2 := A_ScreenHeight - (A_ScreenHeight / 6)

X := A_ScreenWidth / 2
Y := A_ScreenHeight / 6
Z := A_ScreenWidth - (A_ScreenWidth / 4)

counter := 0
pArr := []
cur := 0
iter := 0
man=0

IfNotExist, %A_ScriptDir%\%A_ScreenWidth%x%A_ScreenHeight%\1.bmp
{
ToolTip , Unsuported Resolution, 0, 0, 17
Sleep, 4000
ToolTip , Exiting script, 0, 0, 17
Sleep, 4000
Exitapp
}



;^R::Reload

;^T::Exitapp



SetTimer, IdleTip, 4800  ; Call IdleTip every 5000 ms (5 seconds)


IdleTip:
	ToolTip, Script idle, 0, 0, 17
return  ; End of timer subroutine




DoMatch:
	man=0
	SetTimer, HackLoop, 100  ; Run the hack loop every 100ms
	SetTimer, ManualLoop, Off
	return

ToggleManual:
	man := !man
	if(man==0)
	{
		Reload
	}
 	SetTimer, ManualLoop, 100
	SetTimer, HackLoop, Off
	return

HackLoop:
	SetTimer, IdleTip, Off  ; Stop idle tooltip from showing
	SetTimer, Hack, 4800  ; Call IdleTip every 5000 ms (5 seconds)
	SetTimer, ManualMode, Off
	ToolTip, Hacking, 0, 0, 17
	global cur
	global pArr
	global counter
	counter =0
	global iter
	pArr := []
	cur := 0
	if(iter>1){
		iter :=0
		Reload
	}
	Pmatch(1, XP1, YP1, XP2, YP2)
	Pmatch(2, XP1, YP1, XP2, YP2)
	Pmatch(3, XP1, YP1, XP2, YP2)
	Pmatch(4, XP1, YP1, XP2, YP2)
	Pmatch(5, XP1, YP1, XP2, YP2)
	Pmatch(6, XP1, YP1, XP2, YP2)
	Pmatch(7, XP1, YP1, XP2, YP2)
	Pmatch(8, XP1, YP1, XP2, YP2)
	Pmatch(9, XP1, YP1, XP2, YP2)
	Pmatch(10, XP1, YP1, XP2, YP2)
	Pmatch(11, XP1, YP1, XP2, YP2)
	Pmatch(12, XP1, YP1, XP2, YP2)
	Pmatch(13, XP1, YP1, XP2, YP2)
	Pmatch(14, XP1, YP1, XP2, YP2)
	Pmatch(15, XP1, YP1, XP2, YP2)
	Pmatch(16, XP1, YP1, XP2, YP2)
	if(counter!=0){
		Sleep, 200
		Select()
		Send {Tab}
		if(counter==0)
		iter+=1
	}
	Hack:
	ToolTip, Hacking, 0, 0, 17

return


ManualLoop:
	ToolTip, Manual mode, 0, 0, 17
	SetTimer, ManualMode, 4000
	SetTimer, IdleTip, Off
	SetTimer, Hack, Off
	iter=0
	
	Pmatch(1, XP1, YP1, XP2, YP2)
	Pmatch(2, XP1, YP1, XP2, YP2)
	Pmatch(3, XP1, YP1, XP2, YP2)
	Pmatch(4, XP1, YP1, XP2, YP2)
	Pmatch(5, XP1, YP1, XP2, YP2)
	Pmatch(6, XP1, YP1, XP2, YP2)
	Pmatch(7, XP1, YP1, XP2, YP2)
	Pmatch(8, XP1, YP1, XP2, YP2)
	Pmatch(9, XP1, YP1, XP2, YP2)
	Pmatch(10, XP1, YP1, XP2, YP2)
	Pmatch(11, XP1, YP1, XP2, YP2)
	Pmatch(12, XP1, YP1, XP2, YP2)
	Pmatch(13, XP1, YP1, XP2, YP2)
	Pmatch(14, XP1, YP1, XP2, YP2)
	Pmatch(15, XP1, YP1, XP2, YP2)
	Pmatch(16, XP1, YP1, XP2, YP2)

	ManualMode:
	ToolTip, Manual mode, 0, 0, 17
	Sleep, 100
Return




DoExitApp:
ExitApp
return


DoReload:
Reload
return

Pmatch(N, XP1, YP1, XP2, YP2)
{
	ImageSearch, FoundX, FoundY, %XP1%, %YP1%, %XP2%, %YP2%, *50 %A_ScriptDir%\%A_ScreenWidth%x%A_ScreenHeight%\%N%.bmp
        If ErrorLevel = 0 
	{
         ToolTip, %N%, FoundX, FoundY - 20, %N%
	global counter
	counter += 1
	Pos(FoundX, FoundY)
	}
	Else
	{
	ToolTip ,, FoundX, FoundY,%N%
	
	}
}

Pos(FoundX, FoundY)
{
	global pArr
	if (FoundX >= 470 && FoundX <= 510) {
		if (FoundY >= 250 && FoundY <= 310) {
			pArr.Push(0)
		}
		else if (FoundY >= 400 && FoundY <= 450) {
			pArr.Push(2)
		}
		else if (FoundY >= 550 && FoundY <= 600) {
			pArr.Push(4)
		}
		else if (FoundY >= 700) {
			pArr.Push(6)
		}
	}
	else if (FoundX >= 600 && FoundX <= 650) {
		if (FoundY >= 250 && FoundY <= 310) {
			pArr.Push(1)
		}
		else if (FoundY >= 400 && FoundY <= 450) {
			pArr.Push(3)
		}
		else if (FoundY >= 550 && FoundY <= 600) {
			pArr.Push(5)
		}
		else if (FoundY >= 700) {
			pArr.Push(7)
		}
	}
}


Select()
{
	global counter
	global pArr
    ; Sort the array manually
    SortArray(pArr)

    prev := 0
    for index, val in pArr
    {
	Sleep, 10
        times := val - prev
	SetKeyDelay 40, 40
	if(times==0){
		Sleep, 10
	}
	else if(Mod(times, 2)==0){
	times := times/2
		if(times!=0){
		times := Floor(times)
			Send {Down %times%}
		}
		
	}
	else{
		Sleep, 10
		SetKeyDelay 40, 40
		Send {Right}

		times := Floor(times/2)
		if(times!=0){
		Send {Down %times%}
		}
	}
        SetKeyDelay 40, 40
	SendEvent {Enter}
	counter:= counter-1
        prev := val
    }
}




SortArray(arr)
{
    Loop % arr.MaxIndex()
    {
        Loop % arr.MaxIndex() - A_Index
        {
            i := A_Index
            if (arr[i] > arr[i+1])
            {
                temp := arr[i]
                arr[i] := arr[i+1]
                arr[i+1] := temp
            }
        }
    }
}



Clear(S)
{
	ToolTip ,, FoundX, FoundY,%S%
}