# 开发与验证

## 结构

- `winautohidev2.ahk`：主入口、窗口状态与动画。
- `DockSupport.ahk` / `DockInteraction.ahk`：面板、恢复、全屏和焦点。
- `NotifySupport.ahk`：WM_COPYDATA、通知、手势和悬停。
- `NotifyInstaller.ahk`：异步安装面板。
- `notify-tools/Manage-Notification.ps1`：指纹、完整备份、补丁输出验证和原子替换。
- `notify-tools/source/`：BetterWX 通知模块的 Rust 抽取与适配。
- `vendor/Toastify/`：含本地修改的卡片库。
- `data/`：运行时状态，不发布、不入库。

面板标题也是 DLL 查找收纳程序的 IPC 地址，修改名称时需要同步 Rust 端。IPC 有长度和来源进程检查，但不是用于抵御同一用户下恶意进程的安全边界。

## 构建模块

Windows x64、支持 Rust 2024 edition 的 Rust 工具链：

```powershell
.\scripts\Build-Module.ps1
```

源码变更后必须同步工具 SHA256 与各个已验证输入对应的输出 SHA256；修改二进制但未更新指纹会被拒绝。打包发布的工具路径已重映射，禁用 DLL 开发诊断文件写入。旧试验模块可从完整原始备份生成新补丁再更新，不把旧补丁当作原始备份。

## 测试

```powershell
.\scripts\Run-Tests.ps1
```

运行时缺失则先从官方获取；每次测试建立独立目录，不复制真实 data/。32 项窗口、IPC、焦点元数据和面板检查，加通知位置/悬停/动画测试。只操作合成窗口。

可另用 `tests/Installer.ps1 -FixtureRoot <本地夹具目录>` 测试原版、受支持防撤回基线及旧通知版的安装/恢复。夹具文件不入库、不上传。过程使用局部进程查询 mock，目标始终是临时副本；不能直接针对正在使用的微信安装目录测试。

## 打包

```powershell
.\scripts\Package.ps1 -Version 0.1.0
```

产物位于 dist/，包含工具源码和许可，不包含 AutoHotkey 运行时、微信 DLL 或 data/。GitHub 自动下载的源码包与发行 ZIP 不同；发行 ZIP 已附带补丁工具，源码开发者可自行重建。

## 验证边界

已验证隔离窗口测试、补丁扫描、官方/防撤回副本的安装与恢复、未知指纹拒绝、备份配对、旧试验版升级。通知来源和前端交互曾在本地微信验证；清理诊断写入后的模块不宣称完成新一轮真实消息验收。

多屏、混合 DPI、游戏全屏、当前微信布局的真实输入焦点、文件选择与 UAC 仍需要实机反馈。预览版不保证其他微信版本可用。
