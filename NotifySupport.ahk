#Include vendor\Toastify\lib\Toastify.ahk
#Include EmojiText.ahk
#Include AvatarSupport.ahk

; Card gesture state: 0, or the card currently pressed.
NotifyGesture := 0
; Tests inject {x, y, down} here instead of moving the real cursor.
NotifyTestPointer := 0

ParseNotificationPacket(address, size, version := 1) {
    header := version = 2 ? 20 : 16
    if !address || size < header || size > 8192
        throw Error('通知数据长度不符。')
    keyLength := NumGet(address, 0, 'uint')
    titleLength := NumGet(address, 4, 'uint')
    bodyLength := NumGet(address, 8, 'uint')
    avatarLength := version = 2 ? NumGet(address, 16, 'uint') : 0
    if keyLength > 512 || titleLength > 1024 || bodyLength > 4096
        || avatarLength > 2048 || header + keyLength + titleLength + bodyLength + avatarLength != size
        throw Error('通知字段长度不符。')
    return {pid: NumGet(address, 12, 'uint'), version: version,
        key: StrGet(address + header, keyLength, 'UTF-8'),
        title: StrGet(address + header + keyLength, titleLength, 'UTF-8'),
        body: StrGet(address + header + keyLength + titleLength, bodyLength, 'UTF-8'),
        avatar: avatarLength ? StrGet(address + header + keyLength + titleLength + bodyLength, avatarLength, 'UTF-8') : ''}
}

ReceiveNativeNotification(wParam, lParam, *) {
    try {
        if !lParam
            return 0
        magic := NumGet(lParam, 0, 'uptr')
        if magic != 0x574E4331 && magic != 0x574E4332
            return 0
        size := NumGet(lParam, A_PtrSize, 'uint')
        address := NumGet(lParam, 2 * A_PtrSize, 'ptr')
        packet := ParseNotificationPacket(address, size, magic = 0x574E4332 ? 2 : 1)
        name := StrLower(ProcessGetName(packet.pid))
        if name != 'weixin.exe' && name != 'wechat.exe'
            return 0
        ; Copy fields before returning WM_COPYDATA; render on the next turn
        ; so WeChat's native notification callback never waits for animation.
        SetTimer((*) => ShowDockNotification(packet), -1)
        return 1
    } catch {
        return 0
    }
}

InitDockNotifications() {
    static initialized := false
    if initialized
        return
    Toastify.Start('light', 'quarter-left')
    ; White card, hairline border, WeChat green shared by the leading edge
    ; and the countdown. Registered after Start so built-in themes still load.
    ToastTheme.Register('wechat-card', {bg1: 0xFFFFFFFF, bg2: 0xFFFFFFFF,
        fg: 0xFF111114, fgBody: 0xFF4A4A50, accent: 0xFF07C160, rule: 0xFF07C160,
        progress: 0xFF07C160, progressBg: 0x14000000,
        border: 0xFFD9D9DE, borderWidth: 0.67, shadow: 0x14000000})
    ; borderWidth is scaled by DPI and rounded: 0.67 stays one physical pixel
    ; from 100% to 200%.
    Toastify.theme := 'wechat-card'
    ; Explicit app-level slide preference; no Windows setting changes.
    Toastify.reducedMotion := false
    Toastify.hoverPauseEnabled := true
    Toastify.maxToasts := 3
    Toast.progressGracePeriod := 0
    Toast.textRenderer := NotifyDrawEmojiText
    Toastify.SetConfig({width: 360, minHeight: 64, paddingX: 18, paddingY: 14,
        fontName: 'Microsoft YaHei UI', fontSizeTitle: 15, fontSizeBody: 14,
        fontWeightTitle: 'Bold', fontWeightBody: 'Normal', textHint: 5,
        borderRadius: 6, borderWidth: 0, progressHeight: 2, iconSize: 42,
        animDuration: 240, animStyle: 'slide', animEntrance: 'left', animEasing: 'easeOutCubic',
        repoDuration: 200, repoEasing: 'easeOutCubic'})
    ; The library opens on WM_LBUTTONDOWN; replace it with press/release so a
    ; drag never counts as a click.
    OnMessage(Toastify.WM_LBUTTONDOWN, Toastify.__hClick, 0)
    OnMessage(0x0201, NotifyButtonDown)   ; WM_LBUTTONDOWN
    OnMessage(0x0202, NotifyButtonUp)     ; WM_LBUTTONUP
    OnMessage(0x0215, NotifyCaptureLost)  ; WM_CAPTURECHANGED
    initialized := true
}

ShowDockNotification(packet) {
    try {
        InitDockNotifications()
        title := packet.title != '' ? packet.title : '微信新消息'
        body := StrReplace(StrReplace(packet.body, '`r`n', ' '), '`n', ' ')
        body := NotifyTextPrefix(body, 60)
        avatar := packet.HasProp('avatar') ? packet.avatar : ''
        avatarSlot := (packet.HasProp('version') && packet.version = 2) || NotifyAvatarUrlAllowed(avatar)
        card := Toastify.Show(title, body, [], {position: 'quarter-left', animEntrance: 'left',
            animStyle: 'slide', duration: 5000, showClose: false, showProgress: true,
            tag: 'wechat:' packet.key, onClick: OpenFromNotification,
            marginX: 16, marginY: 16, spacing: 10, icon: avatarSlot ? 'avatar' : ''})
        if IsObject(card) && avatar != ''
            NotifyLoadAvatar(card, avatar)
        ; Real pointer polling: WM_MOUSELEAVE on layered windows is unreliable
        ; and the library's own fallback sleeps while every card is paused.
        SetTimer(NotifyHoverTick, 40)
        FileAppend(FormatTime(, 'yyyy-MM-dd HH:mm:ss') ' native_pid=' packet.pid ' displayed`n',
            A_ScriptDir '\data\notification.log', 'UTF-8')
        return card
    } catch as e {
        PauseOnError(e)
    }
}

NotifyCursor() {
    static pt := Buffer(8, 0)
    if NotifyTestPointer
        return {x: NotifyTestPointer.x, y: NotifyTestPointer.y}
    ; Same physical coordinate space as the cards (Per-Monitor v2).
    DllCall('SetThreadDpiAwarenessContext', 'ptr', -4, 'ptr')
    DllCall('GetCursorPos', 'ptr', pt)
    return {x: NumGet(pt, 0, 'int'), y: NumGet(pt, 4, 'int')}
}

NotifyHoverTick() {
    if Toastify.toasts.Length + Toastify.exitingToasts.Length = 0 {
        SetTimer(NotifyHoverTick, 0)
        return
    }
    pt := NotifyCursor()
    for card in Toastify.toasts.Clone() {
        if card._dragging || card.animState != 'visible'
            continue
        ; Inclusive bounds, matching Toast.OnMouseLeave's own check.
        inside := pt.x >= card.currentX && pt.x <= card.currentX + card.width
            && pt.y >= card.currentY && pt.y <= card.currentY + card.height
        if inside && !card.hovered {
            card.OnMouseMove(pt.x - card.currentX, pt.y - card.currentY)
        } else if !inside && card.hovered {
            NotifyResume(card)
        }
    }
}

; Same bookkeeping as Toast.OnMouseLeave, without its second cursor read:
; the poll already knows the pointer is outside.
NotifyResume(card) {
    card.hovered := false
    card.closeHovered := false
    if card.progressPaused {
        card.progressPaused := false
        paused := Toastify.__now() - card.progressPauseTime
        card.progressStartTime += paused
        if card.hwnd && Toastify.registry.Has(card.hwnd)
            Toastify.registry[card.hwnd].startTime += Round(paused)
    }
    ; The frame loop suspends while every card is paused; restart it.
    Toastify.__wake()
}

; ── Press-and-swipe-left to dismiss; a press without travel opens WeChat ──
NotifyButtonDown(wParam, lParam, msg, hwnd) {
    global NotifyGesture
    card := Toastify.__toastByHwnd(hwnd)
    if !card
        return
    if NotifyGesture || card.animState != 'visible'
        return 0
    pt := NotifyCursor()
    if !card.hovered
        card.OnMouseMove(pt.x - card.currentX, pt.y - card.currentY)
    NotifyGesture := {card: card, hwnd: hwnd, x: pt.x, y: pt.y, cardX: card.currentX,
        offset: 0, dragging: false, lastX: pt.x, lastT: A_TickCount, velocity: 0}
    DllCall('SetCapture', 'ptr', hwnd)
    DllCall('Winmm.dll\timeBeginPeriod', 'uint', 2)
    SetTimer(NotifyDragTick, 8)
    return 0
}

NotifyDragTick() {
    global NotifyGesture
    g := NotifyGesture
    if !g
        return SetTimer(NotifyDragTick, 0)
    down := NotifyTestPointer ? NotifyTestPointer.down : GetKeyState('LButton', 'P')
    if !down                          ; release was swallowed: finish anyway
        return NotifyFinishGesture(false)
    card := g.card
    pt := NotifyCursor()
    dx := pt.x - g.x
    if !g.dragging {
        slop := 6 * card.dpiFactor
        if Abs(dx) < slop && Abs(pt.y - g.y) < slop
            return
        g.dragging := true
        card._dragging := true
        card.repoActive := false
    }
    ; Left follows the pointer 1:1; right gets a short rubber band.
    g.offset := dx < 0 ? dx : Min(dx * 0.2, 10 * card.dpiFactor)
    elapsed := A_TickCount - g.lastT
    if elapsed > 0 {
        g.velocity := 0.6 * g.velocity + 0.4 * (pt.x - g.lastX) / elapsed
        g.lastX := pt.x, g.lastT := A_TickCount
    }
    card.currentX := Round(g.cardX + g.offset)
    card.Draw()
}

NotifyButtonUp(wParam, lParam, msg, hwnd) {
    global NotifyGesture
    if !NotifyGesture || NotifyGesture.hwnd != hwnd
        return
    NotifyFinishGesture(true, lParam)
    return 0
}

NotifyCaptureLost(wParam, lParam, msg, hwnd) {
    global NotifyGesture
    if NotifyGesture && NotifyGesture.hwnd = hwnd
        NotifyFinishGesture(false)
}

NotifyFinishGesture(released, lParam := 0) {
    global NotifyGesture
    g := NotifyGesture
    if !g
        return
    NotifyGesture := 0                 ; before ReleaseCapture (it re-enters)
    SetTimer(NotifyDragTick, 0)
    DllCall('Winmm.dll\timeEndPeriod', 'uint', 2)
    DllCall('ReleaseCapture')
    card := g.card
    if !g.dragging {
        if released {
            x := (lParam << 48) >> 48, y := (lParam << 32) >> 48
            try card.OnClick(x, y)
        }
        return
    }
    d := card.dpiFactor
    card._dragging := false
    flick := g.velocity < -0.8 * d && g.offset < -24 * d
    if g.offset < -0.3 * card.width || flick {
        card.userInitiatedExit := true
        card.hovered := false
        card.progressPaused := false
        card.StartExit()               ; continues left from the current position
    } else {
        card.repoStartX := card.currentX, card.repoStartY := card.currentY
        card.repoTargetX := card.targetX, card.repoTargetY := card.targetY
        card.repoStartTime := A_TickCount
        card.repoActive := true
    }
    Toastify.__wake()
    ; Hover polling decides whether the countdown resumes after the gesture.
}

TestDockNotification(*) {
    card := ShowDockNotification({pid: 0, key: 'local-test', title: '微信通知测试',
        body: '你好 😀 ❤️ 👍🏽，悬停暂停；左滑收起，单击展开微信。'})
    if IsObject(card) {
        card.icon := 'avatar'
        card.Invalidate()
        card.SetAvatar(NotifyDemoAvatar())
    }
}
