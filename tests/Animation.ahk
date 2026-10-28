#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\NotifySupport.ahk
DirCreate(A_ScriptDir '\data')
try {
    started := A_TickCount
    TestDockNotification()
    Check(Toastify.toasts.Length = 1, 'notification created')
    card := Toastify.toasts[1]
    Check(card.duration = 5000, 'five second duration')
    hwnd := card.hwnd
    Sleep(650)
    Check(card.position = 'quarter-left' && card.resolvedEntrance = 'left', 'quarter height and left entrance')
    wa := ToastDPI.WorkArea(card.targetX, card.targetY)
    Check(Abs(card.targetY + card.height / 2 - (wa.y + Round(wa.h * 0.25))) <= 2, 'quarter-height center')
    Check(card.animState = 'visible', 'entrance settles')
    Check(Abs(card.currentX - card.targetX) < 2, 'entrance reaches target')
    card.OnMouseMove(20, 30)
    Check(card.hovered && card.progressPaused, 'hover pauses countdown')
    card.OnMouseLeave()
    Check(!card.progressPaused, 'leave resumes countdown')
    while DllCall('IsWindow', 'ptr', hwnd) && A_TickCount - started < 7500
        Sleep(50)
    Check(!DllCall('IsWindow', 'ptr', hwnd), 'notification exits')
    Check(A_TickCount - started >= 5000 && A_TickCount - started < 7000, 'expiry timing')
    ExitApp(0)
} catch as e {
    FileAppend('FAIL ' e.Message ' line=' e.Line '`n', '*', 'UTF-8')
    ExitApp(1)
}
Check(value, name) {
    if !value
        throw Error(name)
    FileAppend('PASS ' name '`n', '*', 'UTF-8')
}
OpenFromNotification(*) {
}
PauseOnError(e) {
    throw e
}
