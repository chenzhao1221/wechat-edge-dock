#Requires AutoHotkey v2.0
#SingleInstance Ignore
#Include Array.ahk
#Include DPI.ahk
#Include DockSupport.ahk
#Include DockInteraction.ahk
#Include NotifySupport.ahk
#Include NotifyInstaller.ahk
; Local WeChat adaptation of windwhim/winautohidev2, b449935.
SetWinDelay(5)
DetectHiddenWindows(true)
CoordMode('Mouse', 'Screen')
DPI.SetThreadAwarenessContext(-4)
hiddenWindowList := []
suspendWindowList := []
current := 0
pinned := false
outsideSince := 0
hoverSince := 0
graceUntil := 0
hideDelay := 500
selectedMonitor := MonitorGetPrimary()
selectedSide := 'left'
moving := false
paused := false
testMode := A_Args.Length && A_Args[1] = '--self-test'
diagnosticMode := A_Args.Length && A_Args[1] = '--diagnose'
DirCreate(A_ScriptDir '\data')
journal := A_ScriptDir '\data\recovery.ini'
OnExit(Cleanup)
if diagnosticMode {
    Diagnose()
    ExitApp()
}
if testMode {
    RunTests()
    ExitApp()
}
instanceMutex := DllCall('CreateMutexW', 'ptr', 0, 'int', false, 'str', 'Local\WeChatDock_WinAutoHideV2', 'ptr')
if !instanceMutex || A_LastError = 183 {
    MsgBox('微信窗口收纳已经运行，请从系统托盘打开控制面板。')
    ExitApp()
}
RecoverPrevious()
BuildPanel()
OnMessage(0x8571, OpenFromNotification)
OnMessage(0x4A, ReceiveNativeNotification)
SetTimer(WatchCursor, 80)
SetTimer(CheckMonitors, 1500)
RegisterShortcut('^!w', Rescue)
RegisterShortcut('^!p', TogglePin)
; Avoid overriding Ctrl+Left/Right used for normal text editing.
RegisterShortcut('^!Left', (*) => AttachSide('left'))
RegisterShortcut('^!Right', (*) => AttachSide('right'))
return

Reset(*) {
    global current, hiddenWindowList, suspendWindowList, moving
    moving := true
    try {
        if IsObject(current) && ValidTarget(current)
            RestorePlacement(current)
        current := 0
        hiddenWindowList := []
        suspendWindowList := []
        if IsSet(Edge)
            Edge.Hide()
        if FileExist(journal)
            FileDelete(journal)
        SetStatus('已停止收纳，原位置已恢复。')
    } finally {
        moving := false
    }
}

WatchCursor() {
    global outsideSince, hoverSince, graceUntil, current, moving
    if moving || paused || !IsObject(current)
        return
    try {
        DPI.SetThreadAwarenessContext(-4)
        window := current
        if !ValidTarget(window) {
            Reset()
            SetStatus('微信窗口已关闭；打开微信后可重新接管。')
            return
        }
        MouseGetPos(&mx, &my, &under)
        if window.hidden {
            if DllCall('IsWindowVisible', 'ptr', window.id) {
                MovePhysical(window.id, window.showX, window.showY)
                window.hidden := false
                Edge.Hide()
                graceUntil := A_TickCount + 1500
                return
            }
            if !DllCall('IsWindowVisible', 'ptr', Edge.Hwnd)
                PlaceEdge(window)
            r := EdgeRect(window)
            if Inside(mx, my, r) {
                if !hoverSince
                    hoverSince := A_TickCount
                if A_TickCount - hoverSince >= 160
                    showWindow(window, true)
            } else
                hoverSince := 0
            return
        }
        if pinned || A_TickCount < graceUntil || GetKeyState('LButton', 'P') || GetKeyState('RButton', 'P') {
            outsideSince := 0
            return
        }
        if WinGetMinMax('ahk_id ' window.id) != 0 || !DllCall('IsWindowVisible', 'ptr', window.id) {
            outsideSince := 0
            return
        }
        r := PhysicalRect(window.id)
        if isWindowMove(window) {
            outsideSince := 0
            ; Drag away = floating; drag near another edge = dock there.
            Loop MonitorGetCount() {
                MonitorGetWorkArea(A_Index, &l, &t, &rr, &b)
                if Max(r.y, t) >= Min(r.y + r.h, b)
                    continue
                if Abs(r.x - l) <= 18 || Abs(r.x + r.w - rr) <= 18 {
                    window.monitor := A_Index
                    window.mode := Abs(r.x - l) <= 18 ? 'left' : 'right'
                    PrepareDock(window)
                    MovePhysical(window.id, window.showX, window.showY)
                    graceUntil := A_TickCount + 1500
                    return
                }
            }
            return
        }
        if Inside(mx, my, r) || under = Panel.Hwnd || IsOwned(WinExist('A'), window.id) || WinExist('ahk_class #32768') {
            outsideSince := 0
            return
        }
        if !outsideSince
            outsideSince := A_TickCount
        if A_TickCount - outsideSince >= hideDelay
            hideWindow(window)
    } catch as e {
        PauseOnError(e)
    }
}

AttachSide(side, *) {
    global selectedSide
    selectedSide := side
    AttachWeChat()
}

AttachWeChat(*) {
    global current, paused, graceUntil, outsideSince
    try {
        hwnd := FindWeChat()
        if !hwnd
            throw Error('未找到微信主窗口，请从微信托盘打开主窗口后重试。')
        if IsObject(current) && current.id = hwnd {
            showWindow(current)
            current.monitor := selectedMonitor
            current.mode := selectedSide
            PrepareDock(current)
            MovePhysical(hwnd, current.showX, current.showY)
        } else {
            Reset()
            current := CaptureTarget(hwnd)
            SaveRecovery(current)
            WinRestore('ahk_id ' hwnd)
            PrepareDock(current)
            MovePhysical(hwnd, current.showX, current.showY)
            DllCall('ShowWindow', 'ptr', hwnd, 'int', 4)
            pushTo(hiddenWindowList, current)
            pushTo(suspendWindowList, current)
        }
        paused := false
        outsideSince := 0
        graceUntil := A_TickCount + 1500
        SetStatus('已接管微信；鼠标离开后收起，悬停绿色边条展开。')
    } catch as e {
        PauseOnError(e)
    }
}

hideWindow(window) {
    global moving, outsideSince
    if !ValidTarget(window)
        return
    moving := true
    try {
        if !InternalEdge(window)
            winSmoothMove(window.hideX, window.showY, 'ahk_id ' window.id)
        DllCall('ShowWindow', 'ptr', window.id, 'int', 0)
        window.hidden := true
        PlaceEdge(window)
        pushTo(hiddenWindowList, window)
        idx := suspendWindowList.Find((v) => v.id = window.id)
        if idx > 0
            suspendWindowList.RemoveAt(idx)
        outsideSince := 0
    } finally {
        moving := false
    }
}

showWindow(window, activate := false) {
    global moving, graceUntil, hoverSince, outsideSince
    if !ValidTarget(window)
        return
    moving := true
    try {
        if window.hidden {
            if InternalEdge(window)
                MovePhysical(window.id, window.showX, window.showY)
            else
                MovePhysical(window.id, window.hideX, window.showY)
            DllCall('ShowWindow', 'ptr', window.id, 'int', 4)
            if !InternalEdge(window)
                winSmoothMove(window.showX, window.showY, 'ahk_id ' window.id)
        } else {
            if WinGetMinMax('ahk_id ' window.id) = -1
                WinRestore('ahk_id ' window.id)
            DllCall('ShowWindow', 'ptr', window.id, 'int', 4)
        }
        DllCall('SetWindowPos', 'ptr', window.id, 'ptr', 0, 'int', 0, 'int', 0,
            'int', 0, 'int', 0, 'uint', 0x13)
        window.hidden := false
        Edge.Hide()
        pushTo(suspendWindowList, window)
        graceUntil := A_TickCount + 1500
        hoverSince := 0
        outsideSince := 0
        if activate
            ActivateWeChatInput(window.id)
    } finally {
        moving := false
    }
}

isWindowMove(window) {
    r := PhysicalRect(window.id)
    return Abs(r.x - window.showX) > 3 || Abs(r.y - window.showY) > 3
        || Abs(r.w - window.w) > 3 || Abs(r.h - window.h) > 3
}

; 列表不允许存在相同的窗口
pushTo(array,value){
	if array.Find((v) => (v.id =value.id)) <= 0{
		array.push(value)
	}
}
;从a到b的数组
createArray(a, b,length) {
	; Calculate the step to divide the range into length parts
    arr := []
    step := (b - a) / (length-1)  
    value := a
    Loop length {
        arr.Push(Round(value))
        value += step  ; Increase each value by step
    }
    arr.Push(b)
    return arr
}
; 平滑移动
winSmoothMove(newX,newY,windowText){
	r := PhysicalRect(WinExist(windowText))
	X := r.x
	arr := createArray(X,NewX,10)
	for i,v in arr{
		MovePhysical(WinExist(windowText), v, newY)
		Sleep(12)
	}
}

