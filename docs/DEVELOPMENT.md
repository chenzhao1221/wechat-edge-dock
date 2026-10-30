# 开发与验证

## 结构

- `winautohidev2.ahk`：主入口、窗口状态与动画。
- `DockSupport.ahk` / `DockInteraction.ahk`：面板、恢复、边条几何和焦点。
- `DockStartup.ahk`：当前用户启动快捷方式、静默托盘启动、接管完成提示。
- `NotifySupport.ahk`：WM_COPYDATA、通知、手势和悬停。
- `EmojiText.ahk` / `AvatarSupport.ahk`：普通 emoji 字体与组合边界；头像异步下载、缓存及回退。
- `NotifyInstaller.ahk`：异步安装面板。
- `notify-tools/Manage-Notification.ps1`：指纹、完整备份、补丁输出验证和原子替换。
- `notify-tools/source/`：BetterWX 通知模块的 Rust 抽取与适配。
- `vendor/Toastify/`：含本地修改的卡片库。
- `data/`：运行时状态，不发布、不入库。

面板标题也是 DLL 查找收纳程序的 IPC 地址，修改名称时需要同步 Rust 端。IPC 有长度和来源进程检查，但不是用于抵御同一用户下恶意进程的安全边界。

V1 魔数 `0x574E4331`，16 字节头包含 key/title/body 长度和 PID。V2 魔数 `0x574E4332`，20 字节头追加 avatar 长度；正文后追加头像 URL，限 2048 字节，整包不超过 8192。接收端兼容 V1，V2 发送端在字段限长处避免切断 UTF-8。头像取自 ContactService::GetContactSmallHeadUrl；已核对 4.1.9.30 的输出和用户名参数位置。卡片显示和网络请求均在原生回调返回之后执行。

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

运行时缺失则先从官方获取；每次测试建立独立目录，不复制真实 data/。窗口、IPC、焦点元数据、全屏隐藏外观但触边有效、面板和启动快捷方式检查，加通知位置/悬停/动画测试及 emoji/头像夹具。私有测试桌面可能没有前台窗口，全屏夹具向检测函数传入真实合成窗口句柄；自启夹具仅写测试目录，不修改用户启动文件夹。头像网络结果采用合成响应验证字节写入和缓存；不能据此宣称真实联系人头像已验收。只操作合成窗口。

可另用 `tests/Installer.ps1 -FixtureRoot <本地夹具目录>` 测试原版、受支持防撤回基线及旧通知版的安装/恢复。夹具文件不入库、不上传。过程使用局部进程查询 mock，目标始终是临时副本；不能直接针对正在使用的微信安装目录测试。

## 打包

```powershell
.\scripts\Package.ps1 -Version 0.3.0
```

产物位于 dist/，包含工具源码和许可，不包含 AutoHotkey 运行时、微信 DLL 或 data/。GitHub 自动下载的源码包与发行 ZIP 不同；发行 ZIP 已附带补丁工具，源码开发者可自行重建。

## 验证边界

已验证隔离窗口测试、补丁扫描、官方/防撤回副本的安装与恢复、未知指纹拒绝、备份配对、旧试验版升级。2026-10-28 用户在本机重新安装头像版通知模块后确认真实通知、联系人头像和普通 emoji 均正常。最初曾反馈通知不弹，重新安装后恢复；未据此确定最初失败的具体原因。

多屏、混合 DPI、游戏全屏、当前微信布局的真实输入焦点、文件选择与 UAC 仍需要实机反馈。预览版不保证其他微信版本可用。
