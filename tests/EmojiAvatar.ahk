#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\NotifySupport.ahk
DirCreate(A_ScriptDir '\data\avatars')
try {
    Check(NotifyGraphemes('A😀👍🏽👨‍👩‍👧‍👦❤️B').Length = 6, 'grapheme clusters preserved')
    Check(NotifyTextPrefix('😀😃😄', 2) = '😀😃…', 'emoji-safe truncation')
    Check(NotifyTextPrefix('👍🏽你好', 1) = '👍🏽…', 'skin tone modifier preserved')
    Check(NotifyIsEmoji('😀') && !NotifyIsEmoji('中文消息'), 'emoji font selection')
    Check(NotifyAvatarUrlAllowed('https://wx.qlogo.cn/test'), 'avatar CDN allowed')
    Check(NotifyAvatarUrlAllowed('http://wx.qlogo.cn/test'), 'legacy URL can upgrade to HTTPS')
    Check(!NotifyAvatarUrlAllowed('https://qlogo.cn.evil.test/test'), 'domain suffix spoof rejected')
    Check(!NotifyAvatarUrlAllowed('file:///C:/test.png') && !NotifyAvatarUrlAllowed('https://127.0.0.1/test'), 'local and arbitrary URLs rejected')
    Check(StrLen(NotifyAvatarKey('https://wx.qlogo.cn/test')) = 64, 'hashed cache key')
    fields := ['key-test', '头像测试😀', '中文与 emoji ❤️ 👍🏽', 'https://wx.qlogo.cn/test']
    sizes := [], total := 20
    for value in fields {
        size := StrPut(value, 'UTF-8') - 1
        sizes.Push(size), total += size
    }
    packet := Buffer(total + 1, 0)
    NumPut('uint', sizes[1], 'uint', sizes[2], 'uint', sizes[3], 'uint', 123, 'uint', sizes[4], packet)
    offset := 20
    for index, value in fields {
        StrPut(value, packet.Ptr + offset, sizes[index] + 1, 'UTF-8')
        offset += sizes[index]
    }
    parsed := ParseNotificationPacket(packet.Ptr, total, 2)
    Check(parsed.avatar = fields[4] && parsed.body = fields[3], 'V2 packet includes avatar and Unicode')
    rejected := false
    NumPut('uint', 2049, packet, 16)
    try ParseNotificationPacket(packet.Ptr, total, 2)
    catch
        rejected := true
    Check(rejected, 'oversized avatar URL rejected')
    InitDockNotifications()
    bitmap := Gdip_CreateBitmap(64, 64), graphics := Gdip_GraphicsFromImage(bitmap)
    Gdip_GraphicsClear(graphics, 0xFF07C160)
    brush := Gdip_BrushCreateSolid(0xFFFFFFFF)
    Gdip_FillEllipse(graphics, brush, 20, 10, 24, 24)
    Gdip_FillEllipse(graphics, brush, 10, 38, 44, 40)
    Gdip_DeleteBrush(brush), Gdip_DeleteGraphics(graphics)
    source := A_ScriptDir '\data\synthetic-avatar.png'
    Gdip_SaveBitmapToFile(bitmap, source), Gdip_DisposeImage(bitmap)
    card := Toastify.Show('头像与 emoji 测试 😀', '你好 ❤️ 👍🏽，中文保持清晰。', [],
        {position: 'quarter-left', duration: 3000, icon: 'avatar', showClose: false})
    Check(card.SetAvatar(source), 'avatar bitmap loaded')
    Check(card._avatarBitmap != 0, 'avatar retained')
    Sleep(600)
    Gdip_SaveBitmapToFile(card.pBitmapCache, A_ScriptDir '\data\emoji-avatar-preview.png')
    pixelBytes := ComObjArray(0x11, FileGetSize(source))
    DllCall('OleAut32\SafeArrayAccessData', 'ptr', ComObjValue(pixelBytes), 'ptr*', &ptr := 0)
    pixelFile := FileOpen(source, 'r')
    pixelFile.RawRead(ptr, pixelFile.Length), pixelFile.Close()
    DllCall('OleAut32\SafeArrayUnaccessData', 'ptr', ComObjValue(pixelBytes))
    cached := A_ScriptDir '\data\avatars\fixture.img'
    NotifyAvatarJobs['fixture'] := {request: AvatarFixtureRequest(pixelBytes), path: cached, cards: [card], start: A_TickCount}
    NotifyAvatarPoll()
    Check(FileExist(cached) && !NotifyAvatarJobs.Has('fixture'), 'async response bytes cached')
    key := NotifyAvatarKey('https://wx.qlogo.cn/test')
    FileCopy(source, A_ScriptDir '\data\avatars\' key '.img', true)
    Check(NotifyLoadAvatar(card, 'https://wx.qlogo.cn/test') && !NotifyAvatarJobs.Count, 'cache hit needs no network')
    card.Destroy()
    Check(card._avatarBitmap = 0, 'avatar bitmap released')
    FileAppend('PASS emoji and avatar fixtures`n', '*', 'UTF-8')
    ExitApp(0)
} catch as e {
    FileAppend('FAIL ' e.Message ' line=' e.Line '`n', '*', 'UTF-8')
    ExitApp(1)
}
class AvatarFixtureRequest {
    Status := 200
    __New(bytes) => this.ResponseBody := bytes
    WaitForResponse(*) => true
    GetResponseHeader(*) => 'image/png'
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
