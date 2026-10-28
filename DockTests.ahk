; Integration tests use a temporary test window, never the user's WeChat.
RunTests() {
    global current, Edge, selectedSide, selectedMonitor, pinned
    if FileExist(journal)
        throw Error('请先退出正在收纳的实例后再运行测试，避免覆盖恢复记录。')
    results := []
    Assert(CoversMonitor({x: -1920, y: 0, w: 1920, h: 1080}, -1920, 0, 0, 1080),
        'fullscreen negative monitor coordinates', results)
    Assert(!CoversMonitor({x: 0, y: 0, w: 1920, h: 1040}, 0, 0, 1920, 1080),
        'maximized work area is not fullscreen', results)
    Assert(ComposerBounds({x: 300, y: 400, w: 200, h: 100}, {x: 0, y: 0, w: 600, h: 600}),
        'chat composer lower pane accepted', results)
    Assert(!ComposerBounds({x: 20, y: 20, w: 180, h: 30}, {x: 0, y: 0, w: 600, h: 600}),
        'chat list search rejected', results)
    Assert(IsWeChatMainWindow('Qt51514QWindowIcon', '微信'), 'Qt main window recognition', results)
    Assert(!IsWeChatMainWindow('Qt51514QWindowIcon', '图片查看'), 'Qt secondary title rejected', results)
    Assert(!IsWeChatMainWindow('Qt51514QWindowIcon', '微信', 123), 'Qt owned window rejected', results)
    Assert(!IsWeChatMainWindow('Qt51514QWindowToolSaveBits', '微信'), 'Qt popup class rejected', results)
    Assert(IsWeChatMainWindow('mmui::MainWindow', '微信'), 'existing main class retained', results)
    testKey := 'test-session', testTitle := '通知测试', testBody := '中文消息与 emoji 🙂'
    keyBytes := StrPut(testKey, 'UTF-8') - 1
    titleBytes := StrPut(testTitle, 'UTF-8') - 1
    bodyBytes := StrPut(testBody, 'UTF-8') - 1
    packet := Buffer(16 + keyBytes + titleBytes + bodyBytes + 1, 0)
    NumPut('uint', keyBytes, 'uint', titleBytes, 'uint', bodyBytes, 'uint', 123, packet)
    StrPut(testKey, packet.Ptr + 16, keyBytes + 1, 'UTF-8')
    StrPut(testTitle, packet.Ptr + 16 + keyBytes, titleBytes + 1, 'UTF-8')
    StrPut(testBody, packet.Ptr + 16 + keyBytes + titleBytes, bodyBytes + 1, 'UTF-8')
    parsed := ParseNotificationPacket(packet.Ptr, packet.Size - 1)
    Assert(parsed.key = testKey && parsed.title = testTitle && parsed.body = testBody,
        'native UTF8 notification packet', results)
    rejected := false
    try ParseNotificationPacket(packet.Ptr, packet.Size - 2)
    catch
        rejected := true
    Assert(rejected, 'reject truncated notification packet', results)
    fake := Gui('+Resize', 'WeChat Dock Test Fixture')
    fake.Show('NA x120 y130 w500 h500')
    Edge := Gui('+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale')
    Edge.BackColor := '12A877'
    try {
        original := PhysicalRect(fake.Hwnd)
        search := fake.AddEdit('x20 y20 w180 h30', '')
        composer := fake.AddEdit('x220 y350 w220 h90', '')
        WinActivate('ahk_id ' fake.Hwnd)
        WinWaitActive('ahk_id ' fake.Hwnd,, 2)
        search.Focus()
        Assert(FocusChatComposer(fake.Hwnd, false), 'UIA identifies unique writable composer', results)
        composer.Visible := false
        search.Focus()
        Assert(!FocusChatComposer(fake.Hwnd, false), 'list-only view does not refocus search', results)
        composer.Visible := true
        current := CaptureTarget(fake.Hwnd)
        Assert(ValidTarget(current), 'window identity', results)
        SaveRecovery(current)
        Assert(FileExist(journal), 'recovery journal before move', results)
        current.mode := 'left'
        PrepareDock(current)
        Assert(PhysicalRect(fake.Hwnd).x = current.left, 'left docking', results)
        hideWindow(current)
        Assert(current.hidden && !DllCall('IsWindowVisible', 'ptr', fake.Hwnd), 'hide completes', results)
        Assert(DllCall('IsWindowVisible', 'ptr', Edge.Hwnd), 'restore handle visible', results)
        showWindow(current)
        Assert(!current.hidden && DllCall('IsWindowVisible', 'ptr', fake.Hwnd), 'show completes', results)
        Assert(!DllCall('IsWindowVisible', 'ptr', Edge.Hwnd), 'handle dismissed', results)
        hideWindow(current)
        pinned := false
        OpenFromNotification()
        Assert(!current.hidden && DllCall('IsWindowVisible', 'ptr', fake.Hwnd), 'notification expands window', results)
        Assert(!pinned, 'notification does not pin window', results)
        current.mode := 'right'
        PrepareDock(current)
        r := PhysicalRect(fake.Hwnd)
        Assert(r.x + r.w = current.right, 'right docking', results)
        Assert(!isWindowMove(current), 'docked movement detection', results)
        MovePhysical(fake.Hwnd, current.showX - 100, current.showY)
        Assert(isWindowMove(current), 'manual movement detection', results)
        seq := createArray(-200, 100, 10)
        Assert(seq[1] = -200 && seq[seq.Length] = 100, 'upstream interpolation negative origin', results)
        bad := {id: current.id, pid: current.pid, cls: current.cls, stamp: current.stamp + 1}
        Assert(!ValidTarget(bad), 'reject reused window identity', results)
        hideWindow(current)
        RecoverPrevious()
        r := PhysicalRect(fake.Hwnd)
        Assert(r.x = original.x && r.y = original.y && r.w = original.w && r.h = original.h,
            'crash journal restores original geometry', results)
        Assert(DllCall('IsWindowVisible', 'ptr', fake.Hwnd), 'crash recovery restores visibility', results)
        Assert(!FileExist(journal), 'journal removed only after restore', results)
        current := 0
        BuildPanel()
        Assert(SideControl.Value = 1 && DelayControl.Value = '500', 'panel defaults left and 500ms', results)
        Assert(NotifyModuleButtons.Length = 5, 'notification manager panel controls load', results)
        Panel.Destroy()
        FileAppend('PASS ' results.Length ' checks`n' JoinLines(results), '*', 'UTF-8')
    } catch as e {
        FileAppend('FAIL ' e.Message ' at ' e.Line '`n', '*', 'UTF-8')
        ExitApp(1)
    } finally {
        if IsObject(current)
            Reset()
        fake.Destroy()
        Edge.Destroy()
    }
}

Assert(condition, name, results) {
    if !condition
        throw Error(name)
    results.Push('PASS ' name)
}

JoinLines(lines) {
    text := ''
    for line in lines
        text .= line '`n'
    return text
}
