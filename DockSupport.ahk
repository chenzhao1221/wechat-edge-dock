; WeChat-specific safeguards and controls for the upstream WinAutoHide v2 engine.
PhysicalRect(hwnd) {
    DPI.SetThreadAwarenessContext(-4)
    rect := Buffer(16)
    if !DllCall('GetWindowRect', 'ptr', hwnd, 'ptr', rect)
        throw OSError()
    return {x: NumGet(rect, 0, 'int'), y: NumGet(rect, 4, 'int'),
        w: NumGet(rect, 8, 'int') - NumGet(rect, 0, 'int'),
        h: NumGet(rect, 12, 'int') - NumGet(rect, 4, 'int')}
}

MovePhysical(hwnd, x, y, w := 0, h := 0) {
    DPI.SetThreadAwarenessContext(-4)
    flags := 0x14 | (w = 0 ? 1 : 0)
    if !DllCall('SetWindowPos', 'ptr', hwnd, 'ptr', 0, 'int', x, 'int', y,
        'int', w, 'int', h, 'uint', flags)
        throw OSError()
}

Inside(x, y, r) => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h

ProcessStamp(pid) {
    process := DllCall('OpenProcess', 'uint', 0x1000, 'int', false, 'uint', pid, 'ptr')
    if !process
        throw OSError()
    try {
        times := Buffer(32)
        if !DllCall('GetProcessTimes', 'ptr', process, 'ptr', times,
            'ptr', times.Ptr + 8, 'ptr', times.Ptr + 16, 'ptr', times.Ptr + 24)
            throw OSError()
        return NumGet(times, 0, 'int64')
    } finally {
        DllCall('CloseHandle', 'ptr', process)
    }
}

ValidTarget(window) {
    try return DllCall('IsWindow', 'ptr', window.id) && WinGetPID('ahk_id ' window.id) = window.pid
        && WinGetClass('ahk_id ' window.id) = window.cls && ProcessStamp(window.pid) = window.stamp
    catch
        return false
}

IsWeChatMainWindow(cls, title, owner := 0) {
    if cls = 'mmui::MainWindow' || cls = 'WeChatMainWndForPC'
        return true
    ; Qt reuses this class for secondary windows. Require the main title and no owner.
    return RegExMatch(cls, '^Qt\d+QWindowIcon$') && !owner
        && (title = '微信' || title = 'Weixin' || title = 'WeChat')
}

FindWeChat() {
    result := []
    for exe in ['Weixin.exe', 'WeChat.exe'] {
        for hwnd in WinGetList('ahk_exe ' exe) {
            cls := WinGetClass('ahk_id ' hwnd)
            if !IsWeChatMainWindow(cls, WinGetTitle('ahk_id ' hwnd), DllCall('GetWindow', 'ptr', hwnd, 'uint', 4, 'ptr'))
                continue
            r := PhysicalRect(hwnd)
            if r.w >= 250 && r.h >= 250
                result.Push(hwnd)
        }
    }
    if result.Length > 1
        throw Error('检测到多个微信主窗口；原型暂不自动选择账号，请仅保留一个主窗口。')
    return result.Length ? result[1] : 0
}

CaptureTarget(hwnd) {
    placement := Buffer(44, 0)
    NumPut('uint', 44, placement)
    if !DllCall('GetWindowPlacement', 'ptr', hwnd, 'ptr', placement)
        throw OSError()
    pid := WinGetPID('ahk_id ' hwnd)
    return {id: hwnd, pid: pid, cls: WinGetClass('ahk_id ' hwnd), stamp: ProcessStamp(pid),
        placement: placement, wasVisible: DllCall('IsWindowVisible', 'ptr', hwnd),
        monitor: selectedMonitor, mode: selectedSide, hidden: false}
}

PrepareDock(window) {
    DPI.SetThreadAwarenessContext(-4)
    window.monitor := Min(Max(window.monitor, 1), MonitorGetCount())
    MonitorGetWorkArea(window.monitor, &l, &t, &r, &b)
    rect := PhysicalRect(window.id)
    window.w := Min(rect.w, r - l)
    window.h := Min(rect.h, b - t)
    window.left := l, window.right := r, window.top := t, window.bottom := b
    window.showX := window.mode = 'left' ? l : r - window.w
    window.showY := Max(t, Min(rect.y, b - window.h))
    window.hideX := window.mode = 'left' ? l - window.w : r
    MovePhysical(window.id, window.showX, window.showY, window.w, window.h)
}

InternalEdge(window) {
    x := window.mode = 'left' ? window.left - 1 : window.right
    Loop MonitorGetCount() {
        if A_Index = window.monitor
            continue
        MonitorGet(A_Index, &l, &t, &r, &b)
        if x >= l && x < r && Max(t, window.top) < Min(b, window.bottom)
            return true
    }
    return false
}

PlaceEdge(window) {
    if ForegroundFullscreen(window) {
        Edge.Hide()
        return
    }
    Edge.Show('NA w7 h172')
    r := EdgeRect(window)
    MovePhysical(Edge.Hwnd, r.x, r.y, r.w, r.h)
    WinSetAlwaysOnTop(1, 'ahk_id ' Edge.Hwnd)
}

IsOwned(hwnd, owner) {
    Loop 16 {
        hwnd := DllCall('GetWindow', 'ptr', hwnd, 'uint', 4, 'ptr')
        if !hwnd
            return false
        if hwnd = owner
            return true
    }
    return false
}

RegisterShortcut(key, action) {
    try Hotkey(key, action)
    catch as e
        SetStatus('快捷键 ' key ' 注册失败，可使用托盘恢复：' e.Message)
}

SaveRecovery(window) {
    hex := ''
    Loop 44
        hex .= Format('{:02X}', NumGet(window.placement, A_Index - 1, 'uchar'))
    temp := journal '.tmp'
    if FileExist(temp)
        FileDelete(temp)
    for key in ['id', 'pid', 'cls', 'stamp', 'wasVisible']
        IniWrite(window.%key%, temp, 'Window', key)
    IniWrite(hex, temp, 'Window', 'placement')
    FileMove(temp, journal, true)
}

RestorePlacement(window) {
    if !DllCall('SetWindowPlacement', 'ptr', window.id, 'ptr', window.placement)
        throw OSError()
    DllCall('ShowWindow', 'ptr', window.id, 'int', window.wasVisible ? 8 : 0)
    ; If a screen was unplugged, move the normal restored window back to safety.
    if window.wasVisible && WinGetMinMax('ahk_id ' window.id) = 0 {
        rect := PhysicalRect(window.id)
        visible := false
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            if Max(rect.x, l) + 80 < Min(rect.x + rect.w, r)
                && Max(rect.y, t) + 40 < Min(rect.y + rect.h, b)
                visible := true
        }
        if !visible {
            MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
            MovePhysical(window.id, l + 20, t + 20)
        }
    }
}

RecoverPrevious() {
    if !FileExist(journal)
        return
    window := {}
    for key in ['id', 'pid', 'cls', 'stamp', 'wasVisible']
        window.%key% := IniRead(journal, 'Window', key)
    hex := IniRead(journal, 'Window', 'placement')
    if StrLen(hex) != 88
        throw Error('恢复记录损坏，请保留 data/recovery.ini 以便排查。')
    window.placement := Buffer(44)
    Loop 44
        NumPut('uchar', Integer('0x' SubStr(hex, A_Index * 2 - 1, 2)), window.placement, A_Index - 1)
    if ValidTarget(window)
        RestorePlacement(window)
    FileDelete(journal)
}

OpenFromNotification(*) {
    global graceUntil, outsideSince
    try {
        if IsObject(current) && ValidTarget(current) {
            showWindow(current)
            hwnd := current.id
        } else {
            hwnd := FindWeChat()
            if !hwnd
                return
            WinShow('ahk_id ' hwnd)
            if WinGetMinMax('ahk_id ' hwnd) = -1
                WinRestore('ahk_id ' hwnd)
        }
        outsideSince := 0
        graceUntil := A_TickCount + 1500
        ActivateWeChatInput(hwnd)
        ; Keep the user's pin state. Notification clicks only expand WeChat.
    } catch as e {
        PauseOnError(e)
    }
}

Rescue(*) {
    global pinned, paused
    paused := false
    if IsObject(current) {
        pinned := true
        PinControl.Value := 1
        showWindow(current)
        ; A manual move or display change must not leave rescue off-screen.
        PrepareDock(current)
        MovePhysical(current.id, current.showX, current.showY)
    }
    Panel.Show()
    SetStatus('微信已恢复并锁定。取消图钉后恢复自动收起。')
}

TogglePin(*) {
    global pinned
    pinned := !pinned
    PinControl.Value := pinned
    if pinned && IsObject(current)
        showWindow(current)
}

PinChanged(control, *) {
    global pinned
    pinned := !!control.Value
    if pinned && IsObject(current)
        showWindow(current)
}

BuildPanel() {
    global Panel, Edge, StatusControl, PinControl, ScreenControl, SideControl, DelayControl
    Panel := Gui('', '微信窗口收纳 · WinAutoHide 分支')
    Panel.SetFont('s10', 'Microsoft YaHei UI')
    Panel.AddText('w450', '让现有微信像老版 QQ 一样贴边收放')
    Panel.AddText('w450', '系统窗口收纳 · 原生通知模块可单独安装')
    Panel.AddText('xm y+20', '收纳显示器')
    names := []
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        names.Push('显示器 ' A_Index '  ·  ' (r-l) ' × ' (b-t))
    }
    ScreenControl := Panel.AddDropDownList('w280 Choose' selectedMonitor, names)
    SideControl := Panel.AddDropDownList('x+10 w150 Choose' (selectedSide = 'left' ? 1 : 2), ['屏幕左侧', '屏幕右侧'])
    ScreenControl.OnEvent('Change', ApplySettings)
    SideControl.OnEvent('Change', ApplySettings)
    Panel.AddText('xm y+18', '鼠标离开后延时收起（毫秒）')
    DelayControl := Panel.AddEdit('w100 Number', String(hideDelay))
    Panel.AddUpDown('Range300-10000', hideDelay)
    DelayControl.OnEvent('Change', ApplySettings)
    PinControl := Panel.AddCheckbox('xm y+16', '图钉锁定：保持微信展开')
    PinControl.OnEvent('Click', PinChanged)
    Panel.AddButton('xm y+18 w210 Default', '接管微信并贴边').OnEvent('Click', AttachWeChat)
    Panel.AddButton('x+10 w220', '停止收纳 / 恢复原位置').OnEvent('Click', Reset)
    StatusControl := Panel.AddText('xm y+15 w450 h50', '先打开微信主窗口，然后点击接管。')
    Panel.AddText('xm w450', 'Ctrl+Alt+W：恢复并锁定   Ctrl+Alt+P：切换图钉`nCtrl+Alt+← / →：接管并贴到左侧 / 右侧`n关闭面板后在托盘运行；退出时恢复微信原位置。')
    Panel.AddButton('xm y+12 w210', '窗口诊断').OnEvent('Click', (*) => Diagnose(A_ScriptDir '\data\diagnostic.txt'))
    Panel.AddButton('x+10 w220', '退出并恢复微信').OnEvent('Click', (*) => ExitApp())
    Panel.AddButton('xm y+12 w450', '测试左侧通知（5 秒，可悬停）').OnEvent('Click', TestDockNotification)
    BuildNotifyInstaller()
    Panel.OnEvent('Close', (*) => Panel.Hide())
    Edge := Gui('+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale')
    Edge.BackColor := '12A877'
    A_TrayMenu.Delete()
    A_TrayMenu.Add('打开控制面板', (*) => Panel.Show())
    A_TrayMenu.Add('恢复微信并锁定', Rescue)
    A_TrayMenu.Add('切换图钉', TogglePin)
    A_TrayMenu.Add('停止收纳 / 恢复原位置', Reset)
    A_TrayMenu.Add()
    A_TrayMenu.Add('退出并恢复微信', (*) => ExitApp())
    A_TrayMenu.Default := '打开控制面板'
    A_IconTip := '微信窗口收纳 · Ctrl+Alt+W 恢复'
    Panel.Show()
}

ApplySettings(*) {
    global selectedMonitor, selectedSide, hideDelay
    selectedMonitor := ScreenControl.Value
    selectedSide := SideControl.Value = 1 ? 'left' : 'right'
    if IsNumber(DelayControl.Value)
        hideDelay := Min(10000, Max(300, Number(DelayControl.Value)))
    if IsObject(current) {
        showWindow(current)
        current.monitor := selectedMonitor
        current.mode := selectedSide
        PrepareDock(current)
    }
}

CheckMonitors() {
    static previous := ''
    layout := ''
    DPI.SetThreadAwarenessContext(-4)
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        layout .= l ',' t ',' r ',' b ';'
    }
    if previous != '' && previous != layout {
        if IsObject(current) {
            try {
                showWindow(current)
                PrepareDock(current)
            } catch as e
                PauseOnError(e)
        }
        ScreenControl.Delete()
        names := []
        Loop MonitorGetCount()
            names.Push('显示器 ' A_Index)
        ScreenControl.Add(names)
        ScreenControl.Choose(IsObject(current) ? current.monitor : 1)
        SetStatus('显示器布局已变化，微信已回到可见区域。')
    }
    previous := layout
}

SetStatus(text) {
    if IsSet(StatusControl)
        StatusControl.Text := text
}

PauseOnError(e) {
    global paused
    paused := true
    FileAppend(FormatTime(, 'yyyy-MM-dd HH:mm:ss') ' ' e.Message '`n', A_ScriptDir '\data\dock.log', 'UTF-8')
    SetStatus('已暂停：' e.Message)
    if IsSet(Panel)
        Panel.Show()
}

Cleanup(*) {
    if IsObject(current) {
        try Reset()
        catch as e
            FileAppend('恢复失败，记录保留：' e.Message '`n', A_ScriptDir '\data\dock.log', 'UTF-8')
    }
}

Diagnose(destination := '*') {
    output := 'MonitorCount=' MonitorGetCount() ' Windows=' WinGetList().Length '`n'
    for h in WinGetList() {
        try {
            processName := WinGetProcessName('ahk_id ' h)
            if InStr(processName, 'Wei')
                output .= 'Raw=' h ' exe=' processName ' class=' WinGetClass('ahk_id ' h) '`n'
        }
    }
    for exe in ['Weixin.exe', 'WeChat.exe'] {
        for hwnd in WinGetList('ahk_exe ' exe) {
            cls := WinGetClass('ahk_id ' hwnd)
            if true {
                r := PhysicalRect(hwnd)
                output .= Format('HWND={} Class={} PID={} Visible={} Rect={},{},{},{}`n',
                    hwnd, cls, WinGetPID('ahk_id ' hwnd), DllCall('IsWindowVisible', 'ptr', hwnd), r.x, r.y, r.w, r.h)
            }
        }
    }
    if destination != '*' && FileExist(destination)
        FileDelete(destination)
    FileAppend(output, destination, 'UTF-8')
}

#Include DockTests.ahk
