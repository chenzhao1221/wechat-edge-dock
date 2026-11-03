# WeChat Edge Dock

**English** · [简体中文](README.md)

A personal Windows WeChat adaptation of [windwhim/winautohidev2](https://github.com/windwhim/winautohidev2):
edge docking, hover reveal, a topmost edge handle, and optional local notification cards.
Currently a **v0.3.0 preview**, primarily tested on Windows 11 with WeChat 4.1.9.30.

v0.3.0 adds optional per-user login startup, automatic tray collapse with a system notice after
a successful attach, and fullscreen handling that hides only the handle's appearance while
retaining coordinate-based hover activation. The notification module is unchanged from v0.2.0;
existing avatar-module users only need to update the dock scripts.

v0.2.0 adds monochrome Unicode emoji and contact avatars. Real notifications, avatars and
ordinary emoji were user-verified on 2026-10-28 after reinstalling the notification module.
Message-image and custom-sticker previews are not included.

The panel UI is in Chinese, matching the app it docks.

## Download and run

1. Download the Windows x64 ZIP from [Releases](https://github.com/chenzhao1221/wechat-edge-dock/releases)
   and extract it to a fixed directory.
2. Double-click `启动微信收纳.cmd`. First launch downloads official AutoHotkey v2.0.31 from its
   GitHub releases and verifies the SHA256 — an internet connection is required, but nothing is
   installed system-wide. You can also place `AutoHotkey64.exe` v2.0.31 in the project root
   yourself.
3. Open the main window from the tray icon and click "接管微信并贴边" (*take over WeChat and dock
   it*). The panel then collapses to the tray and shows a system notice. Default edge is left,
   and it retracts 500 ms after the pointer leaves.
4. Hover the green handle for about 160 ms to expand. The handle is 7 × 172 physical pixels.

Neither the repository nor the ZIP bundles WeChat DLLs, chat data or the AutoHotkey runtime.

## Features

- Dock left or right, choose the monitor, pin the panel open. Drag it off the edge to float,
  drag it back to re-attach.
- Expanding activates WeChat. When the accessibility API can identify a unique chat composer,
  focus moves there automatically; with only a list, or an ambiguous result, the original focus
  is kept.
- The handle stays topmost. When an app on the same screen goes fullscreen, only the green bar is
  hidden — hover at the same coordinates still expands. The bar returns on exiting fullscreen.
  Ordinary maximized windows do not hide it.
- Optional login startup, off by default; when on, the panel starts silently into the tray at
  sign-in. After a successful attach the panel collapses to the tray and shows a system notice.
- Optional notification cards sit at **one quarter** of the usable screen height, slide in from
  the left and slide back after 5 seconds; hovering pauses them, leaving resumes, a left drag or
  left fling dismisses, a short drag springs back.
- Cards use WeChat green `#07C160` and have no close button. Clicking one only expands WeChat —
  it does not pin the window or jump to the conversation.
- Chinese text keeps its original font; emoji use Segoe UI Emoji separately. Truncation preserves
  common skin tones, ZWJ sequences and flag combinations, but not every complex emoji cluster.
- Avatars use the URL supplied by WeChat's callback: asynchronous loading, caching, rounded
  corners, and a placeholder on failure. Only the designated WeChat image CDN is contacted; legacy
  HTTP URLs are upgraded to HTTPS and redirects are not followed.
- Normal exit restores the pre-attach state. After an abnormal exit, the next launch verifies the
  window identity and attempts recovery.

## Keyboard shortcuts

| Action | Effect |
| --- | --- |
| Ctrl+Alt+W | Restore WeChat, re-dock it to the chosen edge, lock it, and open the panel |
| Ctrl+Alt+P | Toggle pin |
| Ctrl+Alt+← / → | Take over and dock to the left / right |
| Close the panel | Keeps running in the tray |
| Tray menu "退出并恢复微信" | Restore the window and stop docking |

## Optional native notification bridge

**Docking works through Windows window APIs; the native notification module modifies
`Weixin.dll`.** If you don't need notifications, docking alone is enough.

The panel can select WeChat, check status, test DLL code compatibility, install the module, and
restore the pre-install version.

- Matching is by full SHA256 fingerprint, not by directory version number. The current profile
  comes from official WeChat 4.1.9.30 plus one baseline that already had an anti-revoke patch;
  other versions match if the DLL is byte-identical.
- Code detection analyses target functions, references and patch ranges on a temporary copy. An
  unknown fingerprint is reported as "not yet tested" even when the structure matches — it is
  never replaced outright.
- Detection can run while WeChat is running; install, update and restore require all WeChat
  processes to exit normally first. The panel itself may stay open. Writing may need a system
  permission confirmation.
- A full backup is written next to the DLL as `Weixin.dll.before-notify.bak`; existing backups with
  different contents are not overwritten, and restore verifies that backup and patch belong
  together.
- A supported anti-revoke patch already present in the file is preserved. This project does not
  add anti-revoke functionality.
- The module requires **Windows App Runtime 2 x64**. If it's missing, install it per
  [Microsoft's instructions](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads) —
  it is not the same as AutoHotkey's runtime.

Notification content reaches the dock only as local window messages. Chat databases are not read
and nothing is uploaded; logs record neither conversation names nor message bodies. Release builds
drop the DLL diagnostic file writes used during development.

Avatars are fetched from WeChat's image CDN without browser credentials. The cache holds only
images named by URL hash under `data/avatars/`, keeps them for 7 days and at most 100 files, and
records no avatar URLs. Being offline does not affect text notifications. The test button uses a
generic placeholder avatar labelled "微信通知测试".

To upgrade from v0.1.0 or an older experimental module: exit WeChat normally, start the new dock,
click "安装通知模块" in the panel, then reopen WeChat. Updating only the dock scripts keeps
old-style text notifications working but does not enable real contact avatars, and the original
restore backup is never overwritten.

## Data and limitations

Local settings, restore records and logs live in `data/`. While WeChat is docked, do not delete
that directory or the restore records — use "退出并恢复微信" first.

- Login startup is a shortcut in the current user's Startup folder; moving the program directory
  means re-ticking the option. It does not auto-attach WeChat, and with multiple main windows it
  refuses to guess an account.
- Single-monitor paths and isolated-window tests are verified. Mixed DPI, dual monitors, game
  fullscreen and other layouts still need more real-machine feedback.
- Composer focus depends on UI Automation metadata. On failure the window is only activated — no
  simulated clicks or synthetic keystrokes.
- Exclusive-fullscreen games may prevent desktop windows from expanding or activating; this still
  needs real-machine validation. In fullscreen the program hides only the green bar and does not
  pause coordinate-based hover detection.
- WeChat upgrades: re-run detection. Never copy an old DLL over a new version.

## Development and credits

[Development and tests](docs/DEVELOPMENT.md) ·
[Third-party notices](THIRD_PARTY_NOTICES.md) · [Changelog](CHANGELOG.md) · [中文](README.md)

The docking base comes from WinAutoHide v2, the notification patch is adapted from code extracted
from BetterWX, and the animation comes from AHKv2-Toastification. Author credits and upstream
history are preserved. This derivative is not blanket-licensed as MIT — see the individual license
files for each part.
