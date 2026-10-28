; Version-gated helper runs out of process; panel stays responsive during hashing/patching.
NotifyInstallJob := 0

BuildNotifyInstaller() {
    global NotifyPathControl, NotifyModuleStatus, NotifyModuleButtons
    Panel.AddText('xm y+18 w450', '原生通知模块 · 按 DLL 指纹匹配，不限制目录版本号')
    NotifyPathControl := Panel.AddEdit('xm w340 ReadOnly', FindNotificationDll())
    pick := Panel.AddButton('x+10 w100', '选择微信…')
    pick.OnEvent('Click', SelectNotificationDll)
    NotifyModuleStatus := Panel.AddText('xm y+8 w450 h42', '状态：请选择微信程序或 Weixin.dll，然后检查状态。')
    check := Panel.AddButton('xm w140', '检查模块状态')
    install := Panel.AddButton('x+10 w140', '安装通知模块')
    restore := Panel.AddButton('x+10 w150', '恢复安装前版本')
    NotifyModuleButtons := [pick, check, install, restore]
    check.OnEvent('Click', (*) => StartNotificationManager('Status'))
    verify := Panel.AddButton('xm y+8 w450', '检测 DLL 代码兼容性（不修改原文件）')
    verify.OnEvent('Click', (*) => StartNotificationManager('Verify'))
    NotifyModuleButtons.Push(verify)
    install.OnEvent('Click', (*) => StartNotificationManager('Install'))
    restore.OnEvent('Click', (*) => StartNotificationManager('Restore'))
    Panel.AddText('xm y+8 w450', '安装 / 恢复需先正常退出微信，可能弹出系统权限确认。`n安装前完整备份；恢复保留备份中的原有补丁。')
    if NotifyPathControl.Value != ''
        SetTimer((*) => StartNotificationManager('Status'), -300)
}

FindNotificationDll() {
    saved := IniRead(A_ScriptDir '\data\notification.ini', 'Module', 'Dll', '')
    if saved != '' && FileExist(saved)
        return saved
    for exe in ['Weixin.exe', 'WeChat.exe'] {
        for hwnd in WinGetList('ahk_exe ' exe) {
            try {
                path := ResolveNotificationDll(WinGetProcessPath('ahk_id ' hwnd))
                if path != ''
                    return path
            }
        }
    }
    return ''
}

ResolveNotificationDll(path) {
    SplitPath(path, &name, &directory)
    if StrLower(name) = 'weixin.dll'
        return path
    if FileExist(directory '\Weixin.dll')
        return directory '\Weixin.dll'
    ; Prefer the executable's own version; never hardcode a version directory.
    try {
        version := FileGetVersion(path)
        if FileExist(directory '\' version '\Weixin.dll')
            return directory '\' version '\Weixin.dll'
    }
    newest := '', newestVersion := '0'
    Loop Files directory '\*', 'D' {
        version := A_LoopFileName
        if RegExMatch(version, '^\d+(\.\d+)+$')
            && FileExist(A_LoopFileFullPath '\Weixin.dll') && VerCompare(version, newestVersion) > 0 {
            newest := A_LoopFileFullPath '\Weixin.dll'
            newestVersion := version
        }
    }
    return newest
}

SelectNotificationDll(*) {
    path := FileSelect(3, NotifyPathControl.Value, '选择微信 Weixin.exe 或 Weixin.dll', '微信程序或模块 (*.exe; *.dll)')
    if path = ''
        return
    dll := ResolveNotificationDll(path)
    if dll = '' {
        NotifyModuleStatus.Text := '未找到对应 Weixin.dll，请直接选择微信版本目录内的 Weixin.dll。'
        return
    }
    NotifyPathControl.Value := dll
    IniWrite(dll, A_ScriptDir '\data\notification.ini', 'Module', 'Dll')
    StartNotificationManager('Status')
}

StartNotificationManager(action) {
    global NotifyInstallJob
    if IsObject(NotifyInstallJob)
        return
    path := NotifyPathControl.Value
    if path = '' || !FileExist(path) {
        NotifyModuleStatus.Text := '请先选择微信程序或 Weixin.dll。'
        return
    }
    if (action = 'Install' || action = 'Restore') && (ProcessExist('Weixin.exe') || ProcessExist('WeChat.exe')) {
        NotifyModuleStatus.Text := '请先从微信托盘正常退出微信，再点击安装或恢复；收纳面板可以保持运行。'
        return
    }
    helper := A_ScriptDir '\notify-tools\Manage-Notification.ps1'
    result := A_ScriptDir '\data\module-result-' A_TickCount '.ini'
    q(s) => '"' s '"'
    command := (q(A_WinDir '\System32\WindowsPowerShell\v1.0\powershell.exe')
        ' -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ' q(helper)
        ' -Action ' action ' -TargetFile ' q(path) ' -ResultFile ' q(result))
    for button in NotifyModuleButtons
        button.Enabled := false
    NotifyModuleStatus.Text := '正在' (action = 'Status' ? '检查状态' : action = 'Verify' ? '检测 DLL 代码结构' : action = 'Install' ? '备份并安装' : '恢复备份') '…'
    try {
        Run((action = 'Status' || action = 'Verify' ? '' : '*RunAs ') command, A_ScriptDir, 'Hide', &pid)
        NotifyInstallJob := {file: result, pid: pid, start: A_TickCount}
        SetTimer(PollNotificationManager, 150)
    } catch as e {
        for button in NotifyModuleButtons
            button.Enabled := true
        NotifyModuleStatus.Text := '未执行操作：' e.Message
    }
}

PollNotificationManager() {
    global NotifyInstallJob
    job := NotifyInstallJob
    if !IsObject(job)
        return
    if FileExist(job.file) {
        state := IniRead(job.file, 'Result', 'State', 'Error')
        backup := IniRead(job.file, 'Result', 'Backup', '')
        message := IniRead(job.file, 'Result', 'Message', '')
        switch state {
            case 'Installed': text := '已安装通知模块，DLL 指纹已匹配' (backup != '' ? '；恢复备份可用。' : '；缺少可用恢复备份。')
            case 'UpdateAvailable': text := '检测到旧试验通知模块，可点击“安装通知模块”更新；原备份保留。'
            case 'NotInstalled': text := 'DLL 指纹匹配：可安装 / 已恢复安装前版本。'
            case 'Unsupported': text := '此 DLL 不在已验证的支持范围内，未修改文件。'
            case 'Compatible': text := '检测通过：代码结构及补丁结果均匹配已验证版本，可以安装。'
            case 'ScanOnly': text := '代码结构匹配，但此 DLL 尚未实测，暂不开放一键替换。'
            case 'Incompatible': text := '代码结构不匹配：未找到完整补丁目标，不能安装。'
            default: text := '操作失败：' message
        }
        NotifyModuleStatus.Text := text
        FileDelete(job.file)
    } else if A_TickCount - job.start < 180000 && (!job.pid || ProcessExist(job.pid)) {
        return
    } else {
        NotifyModuleStatus.Text := '操作未返回结果，请重新检查状态；备份不会被自动删除。'
    }
    SetTimer(PollNotificationManager, 0)
    NotifyInstallJob := 0
    for button in NotifyModuleButtons
        button.Enabled := true
}
