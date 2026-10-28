; Window activation and metadata-only UI Automation. Never reads names or text values.
EdgeRect(window) => {x: window.mode = 'left' ? window.left : window.right - 7,
    y: window.showY + Max(0, (window.h - 172) // 2), w: 7, h: 172}

ActivateWeChatInput(hwnd) {
    try {
        WinActivate('ahk_id ' hwnd)
        ; Delay until activation/layout settles; do not steal focus back after Alt+Tab.
        SetTimer(() => FocusChatComposer(hwnd), -180)
    }
}

ComposerBounds(candidate, window) => candidate.w >= 80 && candidate.h >= 20
    && candidate.x >= window.x + window.w * 0.25
    && candidate.y >= window.y + window.h * 0.55
    && candidate.x + candidate.w <= window.x + window.w + 2
    && candidate.y + candidate.h <= window.y + window.h + 2

FocusChatComposer(hwnd, requireActive := true) {
    if requireActive && !WinActive('ahk_id ' hwnd)
        return false
    try {
        static automation := ComObject('{FF48DBA4-60EF-4201-AA87-54103EEF594E}',
            '{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}')
        ComCall(6, automation, 'ptr', hwnd, 'ptr*', &rootPtr := 0)
        root := ComValue(13, rootPtr, 1)
        ComCall(21, automation, 'ptr*', &conditionPtr := 0) ; CreateTrueCondition
        condition := ComValue(13, conditionPtr, 1)
        ComCall(6, root, 'int', 4, 'ptr', condition, 'ptr*', &arrayPtr := 0)
        elements := ComValue(13, arrayPtr, 1)
        ComCall(3, elements, 'int*', &count := 0)
        ; Refuse unexpectedly large provider trees rather than stalling the dock loop.
        if count > 500
            return false
        bounds := PhysicalRect(hwnd), matches := []
        Loop count {
            ComCall(4, elements, 'int', A_Index - 1, 'ptr*', &elementPtr := 0)
            element := ComValue(13, elementPtr, 1)
            kind := UiaScalar(element, 30003)
            if kind != 50004 && kind != 50030 ; Edit / Document
                continue
            if !UiaScalar(element, 30009) || !UiaScalar(element, 30010)
                || UiaScalar(element, 30022) || UiaScalar(element, 30019)
                || !UiaScalar(element, 30043) || UiaScalar(element, 30046)
                continue
            if ComposerBounds(UiaBounds(element), bounds)
                matches.Push(element)
        }
        if matches.Length != 1 || (requireActive && !WinActive('ahk_id ' hwnd))
            return false
        ComCall(3, matches[1]) ; SetFocus, no click, keystroke, or text read
        return true
    } catch as e {
        ; Some Qt versions do not expose the composer. Keep restored window focus.
        if testMode
            FileAppend('UIA fixture: ' e.Message ' line=' e.Line '`n', '*', 'UTF-8')
        return false
    }
}

UiaScalar(element, property) {
    value := Buffer(24, 0)
    ComCall(10, element, 'int', property, 'ptr', value)
    try {
        type := NumGet(value, 0, 'ushort')
        if type = 11
            return NumGet(value, 8, 'short') != 0
        if type = 3
            return NumGet(value, 8, 'int')
        throw Error('Unsupported UI metadata')
    } finally {
        DllCall('OleAut32\VariantClear', 'ptr', value)
    }
}

UiaBounds(element) {
    value := Buffer(24, 0)
    ComCall(10, element, 'int', 30001, 'ptr', value)
    try {
        if NumGet(value, 0, 'ushort') != 0x2005
            throw Error('Missing UI bounds')
        array := NumGet(value, 8, 'ptr'), numbers := []
        Loop 4 {
            index := Buffer(4), number := Buffer(8)
            NumPut('int', A_Index - 1, index)
            if DllCall('OleAut32\SafeArrayGetElement', 'ptr', array, 'ptr', index, 'ptr', number, 'int') < 0
                throw Error('Invalid UI bounds')
            numbers.Push(NumGet(number, 0, 'double'))
        }
        return {x: numbers[1], y: numbers[2], w: numbers[3], h: numbers[4]}
    } finally {
        DllCall('OleAut32\VariantClear', 'ptr', value)
    }
}
