# WeChat Edge Dock

A personal Windows WeChat adaptation of [windwhim/winautohidev2](https://github.com/windwhim/winautohidev2): edge docking, hover reveal, fullscreen edge-handle suppression, and optional local notification cards.

Download the Windows x64 ZIP from [Releases](https://github.com/chenzhao1221/wechat-edge-dock/releases), extract it and run `启动微信收纳.cmd`. First launch downloads official AutoHotkey v2.0.31 and verifies SHA256. Neither the runtime nor WeChat DLLs are bundled.

Defaults: left edge, 500ms retract delay, 7×172px handle. Green cards are centered at one-quarter of the usable screen height, slide in from the left, expire after five seconds, pause on hover, and support left-swipe dismissal.

v0.2.0 adds monochrome Unicode emoji and contact avatars. Chinese keeps its original font while emoji use Segoe UI Emoji. Avatars load asynchronously from WeChat image CDNs and use a bounded local cache, with a placeholder on failure. Message-image and custom-sticker previews are not included.

To upgrade from v0.1.0, exit WeChat, start the new dock, click the notification-module installation button, and reopen WeChat. Updating scripts alone does not enable contact avatars. Original backups and the supported pre-existing anti-revoke patch are preserved.

Docking uses Windows APIs. The optional notification bridge **modifies Weixin.dll**, requires a tested matching DLL fingerprint, and preserves a verified full backup. Install/restore requires exiting WeChat. The bridge requires Windows App Runtime 2 x64. It does not add anti-revoke functionality, read chat databases, or upload messages.

v0.2.0 is a preview primarily tested with Windows 11 and WeChat 4.1.9.30. Real notifications, avatars and ordinary emoji were user-verified after reinstalling the updated notification module on 2026-10-28. Mixed DPI, multiple monitors, games and composer focus need additional real-world validation. Unknown DLL fingerprints are not installed automatically.

See the [Chinese guide](README.md), [development guide](docs/DEVELOPMENT.md) and [third-party notices](THIRD_PARTY_NOTICES.md). No blanket MIT license is asserted for this derivative.
