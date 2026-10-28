; Only avatar URLs supplied by WeChat are considered; no database/file scanning.
NotifyAvatarJobs := Map()
NotifyAvatarFailures := Map()

; Generic illustration used only by the explicitly labelled local test button.
NotifyDemoAvatar() {
    folder := A_ScriptDir '\data\avatars'
    DirCreate(folder)
    path := folder '\demo-avatar.png'
    if !FileExist(path) {
        bitmap := Gdip_CreateBitmap(64, 64), graphics := Gdip_GraphicsFromImage(bitmap)
        Gdip_GraphicsClear(graphics, 0xFF07C160)
        brush := Gdip_BrushCreateSolid(0xFFFFFFFF)
        Gdip_FillEllipse(graphics, brush, 20, 10, 24, 24)
        Gdip_FillEllipse(graphics, brush, 10, 38, 44, 40)
        Gdip_DeleteBrush(brush), Gdip_DeleteGraphics(graphics)
        Gdip_SaveBitmapToFile(bitmap, path), Gdip_DisposeImage(bitmap)
    }
    return path
}

NotifyAvatarUrlAllowed(url) => StrLen(url) <= 2048
    && RegExMatch(url, 'i)^https?://(?:[a-z0-9-]+\.)*(?:qlogo\.cn|qpic\.cn)/[^\s]*$')

NotifyAvatarKey(url) {
    input := Buffer(StrPut(url, 'UTF-8'))
    size := StrPut(url, input, 'UTF-8') - 1
    hash := Buffer(32), length := 32
    if !DllCall('Crypt32\CryptHashCertificate2', 'str', 'SHA256', 'uint', 0,
        'ptr', 0, 'ptr', input, 'uint', size, 'ptr', hash, 'uint*', &length)
        throw OSError()
    out := ''
    Loop 32
        out .= Format('{:02x}', NumGet(hash, A_Index - 1, 'uchar'))
    return out
}

NotifyLoadAvatar(card, url) {
    url := RegExReplace(url, 'i)^http://', 'https://')
    if !NotifyAvatarUrlAllowed(url)
        return false
    try {
        key := NotifyAvatarKey(url)
        folder := A_ScriptDir '\data\avatars'
        DirCreate(folder)
        path := folder '\' key '.img'
        if FileExist(path) && DateDiff(A_Now, FileGetTime(path, 'M'), 'Days') < 7 {
            if card.SetAvatar(path)
                return true
        }
        if NotifyAvatarFailures.Has(key) && A_TickCount - NotifyAvatarFailures[key] < 60000
            return false
        if NotifyAvatarJobs.Has(key) {
            NotifyAvatarJobs[key].cards.Push(card)
            return true
        }
        if NotifyAvatarJobs.Count >= 4
            return false
        request := ComObject('WinHttp.WinHttpRequest.5.1')
        request.SetTimeouts(1500, 1500, 1500, 3000)
        request.Open('GET', url, true)
        request.Option[6] := false ; no redirect to unvalidated hosts
        request.SetAutoLogonPolicy(2)
        request.SetRequestHeader('User-Agent', 'WeChatEdgeDock/0.2')
        request.Send()
        NotifyAvatarJobs[key] := {request: request, path: path, cards: [card], start: A_TickCount}
        SetTimer(NotifyAvatarPoll, 80)
        return true
    } catch {
        return false
    }
}

NotifyAvatarPoll() {
    for key, job in NotifyAvatarJobs.Clone() {
        complete := false
        try {
            if A_TickCount - job.start > 5000 {
                job.request.Abort()
                throw Error('Avatar timeout')
            }
            if !job.request.WaitForResponse(0)
                continue
            complete := true
            if job.request.Status != 200
                throw Error('Avatar HTTP status')
            type := job.request.GetResponseHeader('Content-Type')
            if !RegExMatch(type, 'i)^image/(jpeg|png|gif|bmp|x-ms-bmp)(?:;|$)')
                throw Error('Unsupported avatar type')
            bytes := job.request.ResponseBody
            size := bytes.MaxIndex(1) - bytes.MinIndex(1) + 1
            if size < 1 || size > 2 * 1024 * 1024
                throw Error('Avatar size limit')
            temp := job.path '.tmp'
            file := FileOpen(temp, 'w')
            array := ComObjValue(bytes)
            if DllCall('OleAut32\SafeArrayAccessData', 'ptr', array, 'ptr*', &data := 0, 'int') < 0
                throw Error('Avatar buffer unavailable')
            try file.RawWrite(data, size)
            finally {
                DllCall('OleAut32\SafeArrayUnaccessData', 'ptr', array)
                file.Close()
            }
            ; Validate through GDI+ before accepting a cache entry.
            bitmap := Gdip_CreateBitmapFromFile(temp)
            if !bitmap
                throw Error('Invalid avatar image')
            imageW := Gdip_GetImageWidth(bitmap), imageH := Gdip_GetImageHeight(bitmap)
            Gdip_DisposeImage(bitmap)
            if imageW < 1 || imageH < 1 || imageW > 1024 || imageH > 1024
                throw Error('Avatar dimensions limit')
            FileMove(temp, job.path, true)
            for card in job.cards
                if card.hwnd && DllCall('IsWindow', 'ptr', card.hwnd)
                    card.SetAvatar(job.path)
        } catch {
            complete := true
            if NotifyAvatarFailures.Count >= 128
                NotifyAvatarFailures.Clear()
            NotifyAvatarFailures[key] := A_TickCount
            if FileExist(job.path '.tmp')
                FileDelete(job.path '.tmp')
        }
        if complete
            NotifyAvatarJobs.Delete(key)
    }
    if !NotifyAvatarJobs.Count {
        SetTimer(NotifyAvatarPoll, 0)
        NotifyPruneAvatars()
    }
}

NotifyPruneAvatars() {
    entries := []
    Loop Files A_ScriptDir '\data\avatars\*.img', 'F'
        entries.Push({path: A_LoopFileFullPath, time: A_LoopFileTimeModified})
    ; Keep at most 100 hashed image entries. Never touch other local files.
    while entries.Length > 100 {
        oldest := 1
        for index, entry in entries
            if entry.time < entries[oldest].time
                oldest := index
        try FileDelete(entries[oldest].path)
        entries.RemoveAt(oldest)
    }
}
