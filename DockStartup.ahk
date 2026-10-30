; Per-user Startup shortcut: no administrator rights or registry edits required.
StartupPath() => A_Startup '\WeChatEdgeDock.lnk'

StartupEnabled(path := '') {
    path := path = '' ? StartupPath() : path
    if !FileExist(path)
        return false
    try {
        FileGetShortcut(path, &target, &workingDir, &args)
        return StrLower(target) = StrLower(A_AhkPath)
            && args = '"' A_ScriptFullPath '" --startup'
    }
    return false
}

SetStartup(enabled, path := '') {
    path := path = '' ? StartupPath() : path
    if enabled {
        FileCreateShortcut(A_AhkPath, path, A_ScriptDir,
            '"' A_ScriptFullPath '" --startup', '微信窗口收纳')
        if !StartupEnabled(path)
            throw Error('开机自启快捷方式验证失败。')
    } else if FileExist(path)
        FileDelete(path)
}

StartupChanged(control, *) {
    try {
        SetStartup(!!control.Value)
        SetStatus(control.Value ? '已开启开机自启，登录后在托盘运行。' : '已关闭开机自启。')
    } catch as e {
        control.Value := StartupEnabled()
        SetStatus('开机自启设置失败：' e.Message)
    }
}

AttachedToTray(notify := true) {
    Panel.Hide()
    if notify
        TrayTip('微信已贴边收纳，鼠标移到屏幕边缘即可展开。双击托盘图标可打开面板。',
            '微信窗口收纳', 1)
}
