# Project rules

- AHK v2 app. winautohidev2.ahk is the entry point; the panel title is also the native IPC address. Change both sides together.
- DockSupport.ahk: panel/identity/recovery. DockInteraction.ahk: edge geometry/focus. NotifySupport.ahk: cards/IPC. NotifyInstaller.ahk: async installer UI.
- notify-tools/Manage-Notification.ps1 owns hashes, backups and atomic replacement. Keep binary, source and expected hashes synchronized.
- Never ship Weixin.dll, backups, personal paths, data/, logs or credentials. Never test against installed WeChat DLLs.
- Never kill the user's dock or WeChat. scripts/Run-Tests.ps1 uses isolated windows/copies.
- Restore retains the original anti-revoke state. Code-scan success alone never authorizes unknown fingerprints.
- No message sending, content logging or database reads. Focus detection uses UIA metadata only.
- Preserve component licenses; do not label the whole repository MIT.
- See docs/DEVELOPMENT.md for build, tests, packaging and limitations.
