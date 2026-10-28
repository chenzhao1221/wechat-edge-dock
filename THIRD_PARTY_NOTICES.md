# 第三方来源与本地修改

| 组件 | 来源 / 基线 | 许可与说明 |
| --- | --- | --- |
| 收纳底座、插值与列表 | [windwhim/winautohidev2](https://github.com/windwhim/winautohidev2)，`b44993546b5ee0d67c5219d15ba87dc919bc9c1b` | 上游未明确声明许可，保留历史及来源，不重新标为 MIT |
| Array.ahk、DPI.ahk | [Descolada/AHK-v2-libraries](https://github.com/Descolada/AHK-v2-libraries) | MIT，见 `licenses/Descolada-MIT.txt`，保留文件内来源注释 |
| 通知补丁核心 | [zetaloop/BetterWX](https://github.com/zetaloop/BetterWX)，`c2a4d9001709e2fcf8e8b5d547dcf6485506cc7a` | Unlicense，见 `notify-tools/LICENSE` |
| 通知卡片 | [skeletorflet/AHKv2-Toastification](https://github.com/skeletorflet/AHKv2-Toastification)，`c2d5611a6eb6e4b7f51cb1bc77a6f33e9efac2f3` | MIT，见 `vendor/Toastify/LICENSE` |
| GDI+ 辅助库 | Toastify 所附 [buliasz/AHKv2-Gdip](https://github.com/buliasz/AHKv2-Gdip)，文件标记 v1.62 | 保留原来源，未发现独立明确许可；不以 Toastify 的 MIT 替代其原有状态 |
| AutoHotkey v2.0.31 | [官方发布](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.31) | GPL-2.0；不附带运行时，首次启动按用户操作从官方获取，许可见 `AutoHotkey-LICENSE.txt` |
| Rust 依赖 | `notify-tools/source/Cargo.lock` | 许可副本见 `licenses/rust/`，包含 iced-x86、object、memchr、rustc-hash、windows 等 |

WinAutoHide 前身 [scavin/winautohide](https://github.com/scavin/winautohide) 标明原作者 BoD@JRAF.org 并有公共领域声明；这不替代 v2 新增代码各自的授权说明。

本项目新增或适配微信主窗口识别、感应条、恢复记录、全屏避让、输入焦点、通知 IPC、手势、悬停与文字渲染，以及备份安装面板。不包含新增防撤回功能，不分发微信客户端文件。

Toastify 本地修改涉及 Toastify.ahk 的 1/4 高度布局、Toast.ahk 的拖动/续计时/文字渲染、Config.ahk 的 textHint 配置。作者注释和版权信息保留。
