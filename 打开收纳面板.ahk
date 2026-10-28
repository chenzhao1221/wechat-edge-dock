#Requires AutoHotkey v2.0
#SingleInstance Off
DetectHiddenWindows(true)
SetTitleMatchMode(3)
panel := WinExist('微信窗口收纳 · WinAutoHide 分支 ahk_exe AutoHotkey64.exe')
if panel {
    WinShow('ahk_id ' panel)
    if WinGetMinMax('ahk_id ' panel) = -1
        WinRestore('ahk_id ' panel)
    WinActivate('ahk_id ' panel)
} else {
    Run('"' A_ScriptDir '\AutoHotkey64.exe" "' A_ScriptDir '\AutoHotkey64.ahk"', A_ScriptDir)
}
ExitApp()
