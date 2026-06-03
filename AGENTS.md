# dart_simple_live — Project Context

## ⚠️ 用户编码偏好（每次必须先看）
- **禁止中间状态变量：** 不要 `bool _xxx = false` ／ `double _xxx = 0.0` 等 `= false` / `= 0.0` 的中间副本变量
- **状态直读权威源：** UI 从源头直读（`player.state.playing` / `player.state.volume`），不建中间缓存
- **纯 null-form 隐藏：** widget 隐藏就是不在图树（`if (condition)`），不用 `Offstage` / `Visibility` / `Opacity(0)` / `Positioned(bottom: -48)` 等"假隐藏"
- **subscription 只触发 setState：** stream subscription 只调 `setState((){})` 不存值
- **例外——UI 交互变量（滑块/拖拽）：** 音量滑块需要 `_volume` 作为滑块自身状态，不是 `player.state.volume` 的副本。
  原因是 `player.stream.volume` 是异步的（platform channel IPC），拖拽过程中无法靠它提供实时视觉反馈。
  规则：交互变量是 UI 控件的自持状态，不是 player state 的拷贝；`_volumeSub` 事件流会双向同步。其他交互控件同理（如拖动条）。
- **`_lastVolume` 例外：** 静音恢复需要保存静音前音量，`_lastVolume` 不是 player.state 的副本，是用户意图的中间态。这个是允许的。

## 触发子进程

当我说 `[子进程]` 时，表示正在派独立 agent 执行任务，不占主对话上下文。
你想强制让我派子 agent，直接说"调用子agent"或"子进程执行"即可。

## 知识保存规范

1. **发现重要信息（修 bug、新坑、关键决策）时** → 对我说 `记一下`，我会追加到 `AGENTS.md`
2. **修改构建/环境/依赖后** → 对我说 `更新agent`，我会同步更新
3. `AGENTS.md` 只在新对话开始时加载，**对话中不会自动更新**
4. 我必须主动把新知识写进 `AGENTS.md`，否则下次对话我会忘记
5. 只有你明确说时才会 commit & push 到 GitHub，不会自动推送

## ⚠️ 不可忘记的规则（每次对话必须先看）

### 抖音子窗口
- **抖音 URL 永远不让主进程解析传给子进程** → 必黑屏。子进程自己调 `DouyinSite().getRoomDetail/getPlayQualites/getPlayUrls`
- **子进程内 `Player()` 必须加 `configuration: PlayerConfiguration(title: ..., logLevel: MPVLogLevel.error)`**，裸 `Player()` 抖音黑屏
- **`_openMiniWindow()` 抖音分支必须用 `Sites.allSites` 单例**（保留用户 cookie），不能 `new DouyinSite()`

### 子进程卡死
- **子进程 `Process.start` 必须加 `mode: ProcessStartMode.detached`**，否则 stdout 管道写满 4KB 死锁
- **`main.dart` 子进程入口加 `CoreLog.enableLog = false`**（双重保险）

### 构建
- 构建前设置 `$env:FLUTTER_VS_INSTALL_PATH` 和 `$env:FLUTTER_VS_MSVC_VERSION`
- Flutter SDK patches 在 `D:\flutter`（`flutter upgrade` 会覆盖）

## Project Overview
- 聚合直播平台 (Bilibili, 斗鱼, 虎牙, 抖音等) 的 Flutter 桌面端
- 两个入口: `simple_live_app/` (Flutter GUI) + `simple_live_console/` (CLI)
- 核心库: `simple_live_core/` (纯 Dart package)
- 当前版本: 1.11.4 (simple_live_app), 1.0.3 (simple_live_core)

## Development Environment

### Installed Locations
| Component | Path | Notes |
|-----------|------|-------|
| Flutter SDK | `D:\flutter` | v3.44.0, stable, Dart 3.12.0 |
| VS BuildTools 2022 | `D:\VS\BuildTools` | "Desktop development with C++" workload, NOT registered with vswhere.exe |
| MSVC | `D:\VS\BuildTools\VC\Tools\MSVC\14.44.35207` | |
| Win10 SDK | `C:\Program Files (x86)\Windows Kits\10` | v10.0.19041.0, cannot be moved to D: |
| NuGet CLI | `D:\tools\nuget.exe` | Downloaded manually, 8.4 MB |
| CMake | `D:\VS\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin` | |
| Output | `D:\simple_live\` | Final .exe + DLLs copied here |

### VS Detection Workaround
VS BuildTools is NOT registered with the Visual Studio Installer, so `vswhere.exe` can't find it.
The Flutter SDK was patched to bypass this — see "Flutter SDK Patches" below.

### Required Environment Variables for Build
```powershell
$env:FLUTTER_VS_INSTALL_PATH = "D:\VS\BuildTools"
$env:FLUTTER_VS_MSVC_VERSION = "14.44.35207"
$env:Path += ";D:\tools"  # for nuget.exe
```

### Build Command
```powershell
$env:FLUTTER_VS_INSTALL_PATH = "D:\VS\BuildTools"
$env:FLUTTER_VS_MSVC_VERSION = "14.44.35207"
$env:Path = "D:\tools;$env:Path"
& "D:\flutter\bin\flutter.bat" build windows --release
```

### After Build
```powershell
Remove-Item -LiteralPath "D:\simple_live" -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Get-ChildItem "simple_live_app\build\windows\x64\runner\Release" | ForEach-Object {
  if ($_.PSIsContainer) {
    Copy-Item -Path $_.FullName -Destination "D:\simple_live\$($_.Name)" -Recurse -Force
  } else {
    Copy-Item -Path $_.FullName -Destination "D:\simple_live\" -Force
  }
}
```
> **注意：** 不能用 `Copy-Item -Path "Release\*" -Destination "D:\simple_live\" -Recurse`（通配符+Recurse 会扁平化 `data\` 目录结构，导致缺少 `data\app.so` 而闪退）。不能用 `xcopy`（PowerShell 下参数不兼容）。必须用上述 `ForEach-Object` 逐项复制。

### Proxy
- SOCKS5 proxy on port 7897, set via `cmd_init.bat` (AutoRun script on cmd startup)
- Proxy can corrupt CMake's built-in file downloads (mpv, ANGLE .7z files)
- cmd_init.bat is now SILENT (no `[Proxy ON]` echo), removing the echo fixed MSBuild `FormatException`
- PowerShell does NOT have the proxy AutoRun — use PowerShell to bypass proxy-related cmd issues

## Build Cache & Cleanup

### Cache Directories
| Cache | Path | Size |
|-------|------|------|
| VS download cache | `C:\Users\Administrator\AppData\Local\Temp\dd_*` | was ~?? |
| Package Cache | `C:\ProgramData\Package Cache` | 466 MB (deleted) |
| Dart Pub cache | `C:\Users\Administrator\AppData\Local\Pub\Cache` | 703 MB (deleted) |
| NuGet cache | `C:\Users\Administrator\AppData\Local\NuGet\Cache` | 56 MB (deleted) |
| NuGet v3 cache | `C:\Users\Administrator\AppData\Local\NuGet\v3-cache` | was ~?? |
| VS download cache (system) | `D:\VS\Cache` | redirected via `_VSSETUP_DOWNLOAD_CACHE= D:\VS\Cache` |

### Flutter SDK Patches
Two files in Flutter SDK were modified to bypass VS registration detection.
**WARNING: `flutter upgrade` will overwrite these changes!**

#### 1. `D:\flutter\packages\flutter_tools\lib\src\windows\visual_studio.dart`
Added env var override at the top of `_bestVisualStudioDetails` getter (line ~436):
```dart
// Allow overriding VS installation via environment variables.
final String? envInstallPath = _platform.environment['FLUTTER_VS_INSTALL_PATH'];
if (envInstallPath != null && _fileSystem.directory(envInstallPath).existsSync()) {
  final String? envMsvcVersion = _platform.environment['FLUTTER_VS_MSVC_VERSION'];
  if (envMsvcVersion != null) {
    return VswhereDetails(
      meetsRequirements: true,
      installationPath: envInstallPath,
      displayName: 'Visual Studio Build Tools 2022 (env override)',
      fullVersion: '17.14.35027.91',
      isComplete: true,
      isLaunchable: true,
      isRebootRequired: false,
      isPrerelease: false,
      catalogDisplayVersion: '17.14.0',
      msvcVersion: envMsvcVersion,
    );
  }
}
```

#### 2. `D:\flutter\packages\flutter_tools\lib\src\windows\build_windows.dart`
Two changes:
- Passed `vsInstallPath: visualStudio.installLocation` to `_runCmakeGeneration()` call (line ~111)
- Added `-DCMAKE_GENERATOR_INSTANCE` and `-T v143` to CMake args in `_runCmakeGeneration()` (line ~205):
```dart
if (vsInstallPath != null) ...<String>[
  '-DCMAKE_GENERATOR_INSTANCE=$vsInstallPath,version=17.14.40.60911',
  '-T',
  'v143',
],
```

**To revert Flutter SDK patches:**
```bash
git -C D:\flutter checkout -- packages\flutter_tools\lib\src\windows\visual_studio.dart
git -C D:\flutter checkout -- packages\flutter_tools\lib\src\windows\build_windows.dart
```

### Git Dependency Workaround
`dart_quickjs` was originally a git dependency in `simple_live_core/pubspec.yaml`. Changed to local path dependency because GitHub's Git executable cannot be found on this machine:
```yaml
# Changed from:
#   dart_quickjs:
#     git:
#       url: https://github.com/xiaoyaocz/dart_quickjs.git
# To local path:
  dart_quickjs:
    path: ./packages/dart_quickjs
```
The git repo was manually cloned to `simple_live_core/packages/dart_quickjs/`.

## Code Changes Made

### 1. KeepAliveWrapper — 关注 Tab 不重置滚动位置
**File:** `simple_live_app/lib/modules/live_room/live_room_page.dart`
**Line:** ~731
**Change:** Wrapped `buildFollowList()` return value with `KeepAliveWrapper`.
- Prevents `PageView` from destroying the follow-list widget when switching tabs
- User confirmed fixed (scrolling position no longer resets)

### 2. 弹幕字体/速度自适应窗口缩放
**Files:**
- `simple_live_app/lib/modules/live_room/player/player_controls.dart` — `buildDanmuView()`
- `simple_live_app/lib/modules/live_room/live_room_controller.dart`

**How it works:**
- `Positioned.fill` 直接作为 Stack 子节点（避免白色遮挡），内部 `Obx(Offstage(Padding(danmakuView)))`
- `DanmakuScreen` 只创建一次（`if (danmakuView == null)`）
- 窗口大小变化触发 `LiveRoomController.didChangeMetrics()` → 200ms 防抖 → `_applyDanmakuScale()`
- `_applyDanmakuScale()` 通过 `windowManager.getBounds()` 获取窗口宽度
- 缩放公式: `scale = (width / 1920).clamp(0.5, 3.0)`
- 字号 = 用户设定 × scale; duration = 用户设定 × scale，clamp 4~20
- 设置页改动字号/速度等自动触发 `ever` 监听器 → 重新调用 `_applyDanmakuScale()`

### 3. 弹幕设置页实时同步
**File:** `simple_live_app/lib/modules/live_room/live_room_controller.dart`
**Change:** 在 `onInit()` 中加 5 个 `ever` 监听器:
```dart
ever(AppSettingsController.instance.danmuSize, (_) => _applyDanmakuScale());
ever(AppSettingsController.instance.danmuSpeed, (_) => _applyDanmakuScale());
ever(AppSettingsController.instance.danmuArea, (_) => _applyDanmakuScale());
ever(AppSettingsController.instance.danmuOpacity, (_) => _applyDanmakuScale());
ever(AppSettingsController.instance.danmuFontWeight, (_) => _applyDanmakuScale());
```

### 5. Bilibili Cookie 自动刷新
**File:** `simple_live_app/lib/services/bilibili_account_service.dart`
**Change:** In `loadUserInfo()`, after successful API response, capture `Set-Cookie` response headers:
```dart
var setCookieHeaders = result.headers["set-cookie"];
```
- Gets all `Set-Cookie` headers (list of strings)
- Parses each cookie's `key=value` pair (before `;`)
- Merges with existing cookies, overwriting stale keys
- Calls `setCookie(merged)` to persist the refreshed cookie
- This keeps the user logged in longer (session cookies get refreshed on each app launch)

### 6. Huya 防反爬标记

**用户说"虎牙坏了"时：**
打开 `simple_live_core/lib/src/huya_site.dart`，搜 `[虎牙参数]` 可以看到所有关键行。
对照 https://github.com/wbt5/real-url 的 `huya.py` 更新。

**共有 5 处 `[虎牙参数]` 位置（类顶部注释覆盖范围）：**
1. `kUserAgent` — 房间页爬虫 UA
2. `HYSDK_UA` — 直播流请求 UA，最常改
3. `tupClient` — Tars RPC 接口地址
4. `tid.sHuYaUA` (getCndTokenInfoEx 内) — RPC 体内 UA
5. 远程配置 URL (获取 play_config.json 的地方)

### 7. 修复 db_service 标签去重 bug

**File:** `simple_live_app/lib/services/db_service.dart:54`
**Bug:** `if (getFollowTagExistByTag(tag) && tag.length > 8)` — 条件应为 `||` 或直接只判断存在，
原代码用 `&&` 导致短标签（<=8字符）永远不命中，每次导入都创建重复标签。
**Fix:** 删掉 `&&` 后的长度判断，只检查是否存在。

### 8. 多窗口弹幕播放器（子进程）

**架构：** 放弃 `desktop_multi_window`（同进程多引擎），改用 `Process.start` 独立进程。

**文件：**
- `main.dart:17-33` — 启动时检查 `SIMPLE_LIVE_MINIPLAYER` 环境变量，存在则直接跑 `MiniPlayerApp`（不初始化 Hive/GetX/服务）
- `windows/mini_player_window.dart` — `MiniPlayerApp` / `MiniPlayerPage` / `MiniPlayerArguments`，自包含的播放器页面
- `modules/live_room/live_room_page.dart:924-1004` — `_openMiniWindow()`，主进程解析流 URL + 弹幕参数，但**抖音除外**（抖音由子进程自己解析 URL，否则黑屏）

**弹幕连接：**
- 子进程**直接**连平台 WebSocket（BiliBiliDanmaku / DouyuDanmaku / HuyaDanmaku / DouyinDanmaku），不经过主进程
- 主进程只传连接参数（roomId、token、serverHost 等）到 `MiniPlayerArguments.danmakuJson`
- 启动窗口期间（~1-2秒）会漏弹幕，连接成功后实时接收

**注意：**
- 子进程是完整 `simple_live_app.exe`，不用 Hive / GetX / dio
- 弹幕默认关闭，标题栏有开关按钮（`_buildDanmakuToggle()`）
- 每个子进程 ~200-400MB RAM，按需使用
- 环境变量 JSON 小于 Windows 32KB 限制

### ⚠️ 子窗口独立原则（不可违反）
- **子窗口和主窗口在 UI 上完全无关** —— 子窗口就是一个独立的新播放器控件
- 二者除了启动时的环境变量 JSON 数据传输外，**不能有任何共享状态**
- **禁止：** 共享 GetX 实例、共享 Dio 单例、共享 Hive 实例、共享任何 Dart 对象
- **禁止：** 子进程读写主进程的内存或文件（`BlockedUsersService` 的 JSON 文件是唯一跨进程存储，且只读不写冲突）
- **允许：** 主进程 `Process.start` 传环境变量 → 子进程 `Platform.environment` 读取
- **允许：** 主进程 `MiniPlayerManager` 记录子进程 PID（用于 cascade 索引分配 + 主窗口关闭时 kill）—— 只跟踪 PID，不传 UI 状态
- **子进程只传 FFI 参数（SetWindowLongPtrW），不传 UI 状态**

### 子窗口标题栏结构（不可忘记）
- **需求：去掉原生 OS 标题栏，保留自定义标题栏**
- 原生 OS 标题栏通过 `SetWindowLongPtrW` 在 `main.dart` 中 `runApp` 之前移除（保留 `WS_THICKFRAME` 可调边框）：
  - **唯一一处：`main.dart` mini-player block 中 `runApp(...)` 之前，`windowManager.setBounds` 之后**
  - 时序：C++ Flutter runner 在 `main()` 运行前已创建好窗口（`FLUTTER_RUNNER_WIN32_WINDOW`），`FindWindowW` 一定找得到，不需要重试
  - **PID 过滤：** `FindWindowW` 是全局窗口搜索（跨进程），必须用 `GetCurrentProcessId` + `GetWindowThreadProcessId` 确认找到的 HWND 属于当前子进程，防止误删主进程标题栏
  - **加上 `SetWindowPos(SWP_FRAMECHANGED)`** 重算 NC 区消掉 31px 空位。此时 swap chain 未创建，不白屏
- `mini_player_window.dart` **没有**移除逻辑（不再需要 `_removeOsTitleBar`）
- ⚠️ **removeMask 必须是 `0x00CB0000` 不是 `0x00CF0000`**：`0x00CF0000` 多包含 `WS_SIZEBOX(0x040000)`，会删除可调边框导致无法拖拽大小
- 自定义标题栏 36px 高，黑渐变背景，`_showControls` 控制显示/隐藏（3 秒无鼠标动作后隐藏）
- 布局：`Stack(渐变 + GestureDetector(左半文字: 拖拽+双击全屏) + Positioned(右半按钮))`
- **文字区用自定义 `GestureDetector` 替代 `DragToMoveArea`**（`behavior: HitTestBehavior.translucent`）：
  - `onPanStart` → `windowManager.startDragging()`（拖拽移动）
  - `onDoubleTap` → `_toggleFullscreen()`（双击全屏，非最大化）
- **禁止用文字区 GestureDetector 包裹按钮** —— 按钮在独立 `Positioned(right:0)` 中，物理上不重叠
- 标题文字用 `widget.args.userName`（主播名），不是 `title`
- 按钮从右到左：关闭 → 最大化/还原 → 最小化 → **浏览器打开** → 置顶 → 弹幕开关 → 字号 +/- → 速度 << >>
- 浏览器按钮（`Icons.open_in_browser`）→ `_openInBrowser()`，按平台构建 web URL（抖音取 `webRid`）
- 关闭按钮点击：`globalMiniPlayer.dispose()` + `windowManager.setPreventClose(false)` + `windowManager.destroy()`
- 全屏：`windowManager.isFullScreen()` + `setFullScreen()`（注意 API 是 camelCase FullScreen 不是 Fullscreen）
- 控件显示策略：`onEnter` 显示 → `onExit` 3 秒后 null-form 移除。不用 `onHover`（MouseRegion onHover 即使只做字段检查也会触发 Flutter 每帧命中测试，多窗口时 CPU 明显升高）
- **ESC 退出全屏已删除：** `Focus(autofocus: true)` 在多子窗口下可能引起 focus scope 抖动导致 CPU 上涨。等找到零 CPU 方案再加回来。
- `_cleanupTimer` 回调中注意 `_isOverlayActive` 为 true 时也应跳过 `setState`（当前写的是 `if (!_isOverlayActive) _showControls = false;` 但 `setState` 仍在外面统一调用）

### 子窗口自定义控件栏 — 轻量级覆盖 + CPU 回归修复（2026-06-02）
- **🔥 CPU 回归根因：`MaterialDesktopVideoControlsTheme` 包裹 `Video` + `controls: MaterialDesktopVideoControls`** 导致每个子窗口 ~11 个 stream subscriptions + `AnimatedOpacity` + 复杂子树，10 个子窗口仅能开 5 个
- **修复方案：** 永久 `controls: null`，完全移除 `MaterialDesktopVideoControlsTheme`。`MaterialDesktopVideoControls` 内部订阅 `playlist` + `buffering` 两个流，无用户交互也会持续触发 `setState`。加上 5 个子控件的额外流订阅，总共 11 个。删除后恢复 10 窗口容量
- **自定义控件栏**（`_buildControlsBar`）：底部 48px 渐变条，包含播放/暂停 + 音量图标 + 音量滑动条
  - 纯 null-form（`if (_showControls)`），hover 才挂载，离开 3 秒后销毁
- **`_volume` 是滑块自身状态（不是 player.state.volume 的副本）：**
  - `player.stream.volume` 是异步的（platform channel IPC），拖拽时不能依赖它提供实时反馈
  - `_volume` 是 Slider widget 的交互变量，`onChanged` 更新 `_volume` + `player.setVolume()` + `setState` 同步
  - `_volumeSub` 在 volume 流变化时写入 `_volume = v` 双向同步
  - 播放/暂停 icon 用 `player.state.playing` 直读（足够快）
- `_showControls` 同时控制**自定义标题栏** + **控件栏**的挂载/销毁
- 显示策略：`onEnter` 显示 → `onHover` 重置 3 秒倒计时（鼠标每动一下延后）→ `onExit` 起 3 秒倒计时 → 倒计时到设 `_showControls=false`（null-form 真移除）
- **DanmakuScreen** 定位 `top: _showControls ? 36 : 0`（避开标题栏），`bottom: _showControls ? 48 : 0`（避开控件栏）
- 鼠标进入时不暂停弹幕（`onEnter` 移除 `pause()`），离开时不恢复（`onExit` 移除 `resume()`）
- 右击弹幕弹出拉黑菜单时 `pause()`，关闭后 `clear() + resume()` 清旧弹幕接实时

## 抖音子窗口修复思路

### 问题1：黑屏
- 抖音 URL 由主进程解析传到子进程 → 黑屏
- 改为子进程自己调 `DouyinSite().getRoomDetail/getPlayQualites/getPlayUrls` → 正常播放
- 原因未明（可能是 URL 过期或格式差异），但屡试不爽
- **另外必须用 `Player(configuration: PlayerConfiguration(title: 'Simple Live Player', logLevel: MPVLogLevel.error))`**，裸 `Player()` 抖音也黑屏

### 问题2：卡死（关主窗口就好）
- **根因：** `Process.start` 默认建 stdout/stderr 管道，子进程 `HttpClient.instance`（Dio 单例）的 `CustomInterceptor` → `CoreLog` → `Logger` → `print()` 写 stdout
- 主进程从不读管道，4KB 缓冲区写满就死锁
- **修复：** `Process.start` 加 `mode: ProcessStartMode.detached`，不连管道
- **双重保险：** `main.dart` 子进程入口加 `CoreLog.enableLog = false`

### 问题3：主进程 cookie 丢失
- `_openMiniWindow()` 中抖音分支误用 `new DouyinSite()` → 没用户 cookie
- **修复：** 用 `Sites.allSites[Constant.kDouyin]!.liveSite` 单例，保留 `DouyinAccountService` 设的 cookie

### 教训
- 抖音 URL **永远不能让主进程解析传到子进程** → 必黑屏
- 子进程只要做 HTTP 请求（Dio），就必须防管道死锁
- `ProcessStartMode.detached` + `CoreLog.enableLog = false` 是标准配置

## Quick Reference for AI

**当用户说"弹幕不显示"时：**
- 主窗口: 检查 `player_controls.dart` 的 `buildDanmuView()` 是否多层嵌套/遮挡
- 子窗口: 弹幕默认关闭（需点标题栏眼睛按钮开启）。如不显示，检查 `_connectDanmaku()` 和 `danmakuJson` 是否有数据

**当用户说"虎牙坏了"时：**
- 打开 `simple_live_core/lib/src/huya_site.dart`，搜 `[虎牙参数]` 更新 UA/Tars 接口

**当用户说"子窗口打不开"时：**
- 检查 `live_room_page.dart:924` 的 `_openMiniWindow()` 中的 stream URL 解析
- 子进程启动时需要 `MediaKit.ensureInitialized()` 在 `main()` 中完成
- `Process.start` 的 `environment` 参数必须包含 `SIMPLE_LIVE_MINIPLAYER` JSON

**当用户说"抖音子窗口黑屏"时：**
- 抖音必须由子进程自己解析流 URL（主进程解析传到子进程就用不了，原因不明但屡试不爽）
- `_openMiniWindow()` 中抖音走单独分支：`_openMiniWindow` 只取 `danmakuJson`，`streamUrl` 留空
- **注意：** 抖音分支必须用 `Sites.allSites` 的单例（保留用户 cookie），不能 `new DouyinSite()`
- `mini_player_window.dart._play()` 检测 `streamUrl.isEmpty && siteId == 'douyin'` 时调用 `_resolveDouyinAndPlay()`
- `_resolveDouyinAndPlay()` 在子进程内调用 `DouyinSite().getRoomDetail/getPlayQualites/getPlayUrls`，然后 `player.open`
- **`mini_player_window.dart` 中 `Player` 必须设 `configuration` 参数（`PlayerConfiguration(title: ..., logLevel: MPVLogLevel.error)`）**，裸 `Player()` 抖音黑屏
- 其他平台（B站/斗鱼/虎牙）：主进程解析 URL 后传给子进程，子进程不重复解析（B站重复解析会卡死）
- 任何时候都不要把抖音URL放到 `streamUrl` 传给子进程——必黑屏

**当用户说"子进程卡死（关主窗口就好）"时：**
- 根因：`Process.start` 默认创建 stdout/stderr 管道，子进程 `HttpClient.instance`（Dio 单例）的 `CustomInterceptor` → `CoreLog` → `Logger` → `print()` 写 stdout
- 主进程从不读管道，4KB 缓冲区写满就死锁
- 关主窗口 → 管道断开 → 子进程解卡
- 修复：`_openMiniWindow()` 中 `Process.start` 加 `mode: ProcessStartMode.detached`，不连管道
- 双重保险：`main.dart` 子进程入口加 `CoreLog.enableLog = false`
- 所有平台都会触发，只是抖音子进程需要 HTTP 请求（Dio 输出日志最多），所以最容易复现

**当构建失败（MSVC/VS）时：**
- 确保设置了 `FLUTTER_VS_INSTALL_PATH` 和 `FLUTTER_VS_MSVC_VERSION`
- 检查 `D:\flutter\` SDK 的 patches 是否还在（`flutter upgrade` 会覆盖）

**安全删除操作：**
1. 删 `simple_live_app/build/`（重建即可）
2. 删 `D:\simple_live\` 下所有文件（重建输出）
3. 删 `simple_live_core/packages/dart_quickjs/`（需要重新 git clone）

## GitHub Repository
- **GitHub 用户:** https://github.com/Shameless404
- **远程仓库:** https://github.com/Shameless404/dart_simple_live.git
- **默认分支:** master
- **注意:** GitHub Personal Access Token 需要 `workflow` 权限才能推送 `.github/workflows/` 下的文件。✅ 已解决。

## SDK Constraints
- Dart SDK constraint: `>=3.0.5 <4.0.0` (app), `>=3.10.0` (core)
- Flutter: 3.44.0
- Key packages: dio ^5.9.0, get ^4.7.3, protobuf ^3.1.0, lottie ^3.3.2, media_kit

## Release & GitHub 操作规范

### Release 操作红牌
- **绝不自行修改 Release 描述**（语言、格式、内容）→ 必须先问用户
- **Release ZIP 文件名必须与 README 链接一致**：`simple_live_v<version>_windows-x64.zip`
- **创建 release 后检查**：`draft` 要发布、描述是否正确、ZIP 可下载

### PowerShell 中文编码
- `ConvertTo-Json` + `Invoke-RestMethod` 会导致中文乱码（PowerShell 5.1 限制）
- 可靠方案：`curl.exe -s -X PATCH ... --data-binary "@file.json"` + 文件用 `[System.Text.Encoding]::ASCII.GetBytes(unicodeEscapedJson)` 写入
- 对中文用 `\uXXXX` 转义再拼 JSON，确保输出纯 ASCII

## 子进程 hardError 修复（最终方案）

### 根因
用户点 X → Flutter 引擎先开始 native shutdown → `MiniPlayerState.dispose()` 跑 `player.dispose()` → mpv 回调发向已销毁的 isolate → hardError。`exit(0)` 也来不及（engine shutdown 先于 `dispose()` 执行）。

### 修复方案
在 `main.dart` 子进程入口加 `window_manager` 拦截 WM_CLOSE：
```dart
await windowManager.ensureInitialized();
await windowManager.setPreventClose(true);
windowManager.addListener(_MiniWindowCloseHandler());
```

`_MiniWindowCloseHandler` 在 `destroy()` 前先 dispose player：
```dart
class _MiniWindowCloseHandler extends WindowListener {
  @override
  void onWindowClose() {
    Future(() async {
      await globalMiniPlayer?.dispose();
      globalMiniPlayer = null;
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    });
  }
}
```

### 全局 player 引用
- 定义在 `mini_player_window.dart`：`Player? globalMiniPlayer;`
- `MiniPlayerPage.initState()` 中赋值：`globalMiniPlayer = player;`
- `MiniPlayerPage.dispose()` 中置 null：`globalMiniPlayer = null;`
- `main.dart` 已 import `mini_player_window.dart`，可直接访问

## canvas_danmaku 空转 CPU 修复
- canvas_danmaku 0.2.7 的 30fps Timer 即使弹幕列表为空也调用 `setState()` → 白烧 CPU
- **修复（pub cache，3 处）：**
  1. `initState()` Timer 回调：4 个列表全空时 `return` 不 `setState`
  2. `resume()` 中创建的 Timer 回调：同上
  3. `_startTick()` while 循环开头：4 个列表全空时 `continue` 跳过 `removeWhere`
- 默认弹幕 OFF 时 `DanmakuScreen` 不在 widget 树，零开销
- 弹幕 ON 但无消息时 Timer 仍跑但 `setState` 被跳过，`_startTick` 循环仅 `Future.delayed(100ms)`

## 子窗口默认状态 — CPU 零额外开销
- **音量：** 初始必须 `player.setVolume(0.0)` —— 默认静音（media_kit范围：0.0-100.0，100.0为最大）
- **播放器：** 永久 `controls: null`（无原生控件子树），仅 mpv 解码
- **弹幕：** 默认关闭（`_danmakuUserEnabled = false`），不在树中。开启后始终在树中
- **标题栏：** 默认不显示，null-form（`if (_showControls)`），鼠标进入才挂载
- **控件栏：** 默认不显示，null-form（`if (_showControls)`），与标题栏同步挂载/销毁
- 所有平台统一：弹幕/标题栏/控件栏默认不在树，无 Timer/Stream 开销

## 置顶 toggle 修复
- `_PinToggleButton.onTap` 必须先 `await windowManager.setAlwaysOnTop(newValue)` 再 `setState`
- `initState` 中加 `_initPinned()` → `windowManager.isAlwaysOnTop()` 读取真实状态
- 控制栏重建时（鼠标离开/再进入）不再复位到 false，始终从真实窗口状态同步

## 子窗口尺寸按宽高比适配
- **方案：** 用 `player.stream.videoParams.firstWhere(dw>0, dh>0)` 零 CPU 等视频尺寸
- 必须在 `player.open()` 前订阅 stream（broadcast 不重放历史，否则错过事件）
- 横屏（aspectRatio ≥ 1）→ 宽度 640，高度按比例缩放
- 竖屏 → 高度 540，宽度按比例缩放
- 处理 `rotate` 90/270 交换 w/h
- Clamp: 280~900 × 200~700

### 9. 关注列表启动时自动刷新
- `follow_user_controller.dart:45`: `onInit()` 中加 `filterData()` ← 读 `FollowService.followList` 到 `pageController.list`
- `follow_user_controller.dart:46`: 加 `updateTagList()` 展示自定义标签
- `follow_user_controller.dart:81-88`: `filterData()` 额外设 `pageEmpty`, `pageError`, `pageLoadding`, `canLoadMore=false`
- `follow_service.dart:57`: `onInit()` 加 `loadData()`（启动时从 Hive 加载）
- `follow_user_page.dart:155`: `firstRefresh: true → false`
- **构建输出位置：** `D:\simple_live\simple_live_app.exe`

### 10. canvas_danmaku 无手势/点击 API
- 整个 widget 被 `IgnorePointer` 包裹，不参与 HitTest
- `DanmakuController` 仅有 CRUD：`pause/resume/clear/addDanmaku/updateOption`
- `DanmakuContentItem` 只有 `text/color/type/selfSend`，无 `userName`
- 弹幕上实现右击/点击 → 必须改 pub cache 源码

### 11. 弹幕拉黑管理（已实现）

**存储：** `blocked_users.json` 在 exe 同目录，一行一个 JSON，`key=platform:userName`

**架构：**
- `BlockedUsersService` — 纯 Dart 单例（无 GetX/Hive 依赖），主进程和子进程通用
- `AppSettingsController` — 包装 `RxMap<String, BlockedUserEntry>` 做设置页响应式
- `BlockedUsersController` + `BlockedUsersPage` — 设置页拉黑管理 UI

**入口（聊天消息右击 + 子窗口弹幕右击 + 设置页）：**
1. **聊天消息右击：** `live_room_page.dart` `buildMessageItem()` → GestureDetector(onSecondaryTapDown) → showMenu → `BlockedUsersService.instance.block()`
2. **子窗口弹幕右击：** `mini_player_window.dart` → `_onDanmakuTap()` → 直接拉黑 + OverlayEntry toast
3. **设置页：** `danmu_settings_page.dart` → "拉黑管理" → 列出所有已拉黑用户，可移除

**pub cache 追加修改（canvas_danmaku 0.2.7）：**
1. `danmaku_content_item.dart` — 加 `userName` 字段
2. `danmaku_screen.dart` — 移除 `IgnorePointer`，加 `GestureDetector` + hit-test + `onDanmakuSecondaryTap` 回调
3. `danmaku_screen.dart` — `GestureDetector` 必须加 `behavior: HitTestBehavior.translucent`，否则 GestureDetector 参与 hit test 会挡住父级 `MouseRegion` 的 hover 事件，导致弹幕开启时子窗口 `onEnter` 不触发（鼠标必须移到最底下才能显示播放器控件）

**子窗口区别：** 主窗口走聊天右击（`player_controls.dart` 已无弹幕右击），子窗口走弹幕右击。
**子窗口盾词缺失：** 子窗口 `_setupDanmakuHandlers` 只有拉黑过滤没有盾词过滤（用户已知）。

### 12. BlockedUsersService 简化（2026-05-31）
**去掉了 File.watch + onChangeCallbacks + dispose，改用：**
- `block()` — 内存加一条 + 用 `FileMode.append` 追加一行（`\n${jsonEncode(entry.toJson())}`），不全文重写
- `unblock()` — 内存删 + 全文重写（删行必须）
- `init()` — 启动时检测文件不存在则创建空文件
- `reload()` — 只重新读文件，无文件监听
- 格式：一行一个 JSON，每行 `{"key":...,"userName":...,"anchorName":...,"platform":...,"message":...,"timestamp":...}`
- 跨进程不同步（子窗口拉黑只存自己文件，不通知主窗口）
- 每次进拉黑管理页面时 `initState()` 调 `reload()` 再同步 RxMap

### 13. anchorName 字段（2026-05-31）
**File:** `blocked_users_service.dart`
- `BlockedUserEntry` 加 `String anchorName`（主播名字）
- `block()` 加 `{String anchorName = ''}` 参数
- 兼容旧数据：`fromJson` 中 `json['anchorName'] as String? ?? ''`
- 调用方：`live_room_page.dart:563` 传 `controller.detail.value?.userName`，`mini_player_window.dart:374` 传 `widget.args.userName`
- `blocked_users_page.dart` 展示格式为两行：`用户名 [平台] 主播名`（同级别）+ 灰色缩进第二行弹幕内容（平铺 Column，不用 ListTile title/subtitle）

### 14. 子窗口弹幕鼠标交互修复（2026-06-03）
- **问题：** 全屏/大窗口时鼠标进出触发 `danmakuController?.pause/resume`，弹幕永久卡死
- **onEnter：** 移除 `danmakuController?.pause()` — 进入窗口不暂停弹幕
- **onExit：** 移除 `danmakuController?.resume()` — 离开窗口不恢复弹幕（弹幕自然滚动）
- **右击拉黑关闭后：** 两条关闭路径只调 `resume()`，不 `clear()` — 弹幕继续自然滚动，支持连续拉黑多人
- **标题栏弹幕开关：** 已经是纯 null-form 真关闭（`liveDanmaku.stop()` + widget 移出树），开时重新 `_connectDanmaku()`，天然清空重来
- **右击弹出时：** 仍保留 `danmakuController?.pause()` 让用户看清弹幕
- **CPU 影响：** 零增加（net 减少，去掉了 on-hover 的 API 调用）

### 15. Toast 统一（2026-05-31）
- 主窗口聊天右击拉黑提示：从 `Get.snackbar` 改为 `OverlayEntry` 黑底白字圆角卡片，1 秒后自动移除
- 和子窗口 `_showToast()` 风格一致（子窗口原本就是 OverlayEntry，未改）

### 16. 关注列表搜索功能（2026-05-31）

**两个入口：**

**1. 关注 Tab（`follow_user_page.dart` + `follow_user_controller.dart`）**
- `FollowUserController.searchQuery: RxString('')` + `onSearch(String query)` 方法
- 搜索时从 `FollowService.instance.followList` 按 `userName.toLowerCase().contains(query.toLowerCase())` 模糊匹配
- 清空搜索恢复当前标签筛选
- 搜索期间自动跳过 `updatedListStream` 的 `filterData()`（避免刷新冲掉搜索结果）
- 切换到其他标签时自动清空搜索（`setFilterMode()` 中 `searchQuery.value = ''`）
- UI：`_FollowSearchBar`（StatefulWidget）放在标签栏和网格之间，带搜索图标、`X` 清除按钮

**2. 侧边栏关注列表（`live_room_page.dart` `_FollowListWithSearch`）**
- `_FollowListWithSearch` StatefulWidget，含 `TextEditingController` + `_query` 状态
- 搜索时从全部关注搜（不限于 liveList），方便找未开播主播
- 清空恢复显示 liveList
- 保留 `KeepAliveWrapper` + `RefreshIndicator` + `DesktopRefreshButton`

## 子窗口位置级联（setBounds 提前）
- **关键保证：** `main.dart` mini-player 分支中，在 `runApp` 之前算好位置，调用 `setBounds(x, y, 640, 360)` 一次搞定位置+尺寸
- **时序：** `setBounds` + `SetWindowPos` 已执行完毕 → `runApp` → Flutter 首帧 → `ShowWindow` → 窗口第一次出现就在正确位置（零瞬移闪屏）
- **公式：** `cascadeIndex` (0, 1, 2...) 传入子进程，`x=step*idx`, `y=屏幕高-窗口高-(step*idx)`, 超出边界重置到最左下
- `mini_player_window.dart` 已无 `_setInitialPosition()`，`initState` 只调 `_play()`，视频尺寸就绪后 `_resizeWindow` 调 `setSize`（`SWP_NOMOVE` 保留位置）

## 子窗口声音调试（2026-06-02）

### 问题特征
- 子窗口播放器完全无声，即使音量滑块显示有值
- 音量滑块可以拖动，但实际播放音量为0
- 问题出现在自定义控件栏实现后

### 根本原因
**media_kit volume API 范围是 0.0-100.0，不是 0.0-1.0！**

- `player.setVolume(0.0-100.0)` — 正确范围
- `_volume` 滑块状态用 0.0-1.0 — UI 习惯
- 传错范围导致 `player.setVolume(0.5)`（几乎静音）

### 修复方案
1. **滑块转换**：`_volume = v / 100.0` + `player.setVolume(v)`（直接传 0-100）
2. **静音逻辑**：保存 `_lastVolume`，点击时恢复
3. **初始静音**：`player.setVolume(0.0)` + `_volume = 0.0`

### 代码模式
```dart
// Volume 状态
double _volume = 0.0;      // 滑块自身状态（0.0-1.0）
double _lastVolume = 0.5;   // 静音前音量

// Stream 同步
_volumeSub = player.stream.volume.listen((v) {
  _volume = v / 100.0;  // media_kit 0-100 → _volume 0-1
  setState(() {});
});

// 滑块 onChanged
onChanged: (v) {
  _volume = v / 100.0;  // UI 习惯 0-1
  player.setVolume(v);   // 直接传 0-100 给 media_kit
  setState(() {});
}

// 静音按钮
if (_volume > 0) {
  _lastVolume = _volume;
  _volume = 0.0;
} else {
  _volume = _lastVolume;
}
player.setVolume(_volume * 100.0);  // 转换后传给 media_kit
```

### 调试步骤
1. **检查 media_kit 范围**：确认 0.0-100.0（不是 0.0-1.0）
2. **验证转换**：确保 `player.setVolume()` 接收 0-100 值
3. **测试固定音量**：直接 `player.setVolume(50)` 测试半音量
4. **检查静音恢复**：静音后恢复的音量是否正确

**当用户说"子窗口没声音"时：**
- 检查是否所有 `player.setVolume()` 都传 0-100 值
- 暂时改用 `player.setVolume(50)` 测试半音量是否生效
- 确认 volume stream 是否正确同步 `_volume`

**当用户说"音量滑块没反应"时：**
- 检查 `_volumeSub` 是否正确设置（`_volume = v / 100.0`）
- 验证 `player.setVolume(v)` 直接传滑块 0-100 值
- 确认滑块 `value: _volume * 100` 显示正确

## 滚动位置恢复教训（2026-05-31）
- **根因：** `followListScrollOffset` 只在 `onTap` 保存，点击遮罩关闭 Dialog 不保存 → 下次打开从0开始
- **正确做法：** `ScrollController(initialScrollOffset: savedOffset)` + `scrollCtrl.addListener(() => {if (scrollCtrl.hasClients) controller.followListScrollOffset = scrollCtrl.offset;})`
- **不要搞复杂方案：** 不要用 `_ScrollRestore` + `jumpTo` + 递归重试。监听器持续保存 offset 是最简单可靠的方案
- **排查原则：** 遇到"某状态没保留"，先检查所有退出路径是否都保存了状态，不要只盯着最明显的那个入口看

**当用户说"关注列表滚动位置不对"时：**
- 检查 Dialog 的 `ScrollController` 有没有 `addListener` 持续保存 offset
- 检查 `initialScrollOffset` 有没有传对
- 不要搞 `_ScrollRestore` / `jumpTo` 之类的方案
