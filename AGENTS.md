# dart_simple_live �?Project Context

## ⚠️ 用户编码偏好（每次必须先看）
- **禁止中间状态变量：** 不要 `bool _xxx = false` �?`double _xxx = 0.0` �?`= false` / `= 0.0` 的中间副本变�?
- **状态直读权威源�?* UI 从源头直读（`player.state.playing` / `player.state.volume`），不建中间缓存
- **�?null-form 隐藏�?* widget 隐藏就是不在图树（`if (condition)`），不用 `Offstage` / `Visibility` / `Opacity(0)` / `Positioned(bottom: -48)` �?假隐�?
- **subscription 只触�?setState�?* stream subscription 只调 `setState((){})` 不存�?
- **例外——UI 交互变量（滑�?拖拽）：** 音量滑块需�?`_volume` 作为滑块自身状态，不是 `player.state.volume` 的副本�?
  原因�?`player.stream.volume` 是异步的（platform channel IPC），拖拽过程中无法靠它提供实时视觉反馈�?
  规则：交互变量是 UI 控件的自持状态，不是 player state 的拷贝；`_volumeSub` 事件流会双向同步。其他交互控件同理（如拖动条）�?
- **`_lastVolume` 例外�?* 静音恢复需要保存静音前音量，`_lastVolume` 不是 player.state 的副本，是用户意图的中间态。这个是允许的�?

## 触发子进�?

当我�?`[子进程]` 时，表示正在派独�?agent 执行任务，不占主对话上下文�?
你想强制让我派子 agent，直接说"调用子agent"�?子进程执�?即可�?

## 知识保存规范

1. **发现重要信息（修 bug、新坑、关键决策）�?* �?对我�?`记一下`，我会追加到 `AGENTS.md`
2. **修改构建/环境/依赖�?* �?对我�?`更新agent`，我会同步更�?
3. `AGENTS.md` 只在新对话开始时加载�?*对话中不会自动更�?*
4. 我必须主动把新知识写�?`AGENTS.md`，否则下次对话我会忘�?
5. 只有你明确说时才 commit & push 到 GitHub，不会自动推
6. **禁止碰 C 盘！** 不清理 C 盘缓存、CrashDumps、Chrome 等空间，只允许在项目目录和 D 盘路径下操作

## ⚠️ 不可忘记的规则（每次对话必须先看�?

### 抖音子窗�?
- **抖音 URL 永远不让主进程解析传给子进程** �?必黑屏。子进程自己�?`DouyinSite().getRoomDetail/getPlayQualites/getPlayUrls`
- **子进程内 `Player()` 必须�?`configuration: PlayerConfiguration(title: ..., logLevel: MPVLogLevel.error)`**，裸 `Player()` 抖音黑屏
- **`_openMiniWindow()` 抖音分支必须�?`Sites.allSites` 单例**（保留用�?cookie），不能 `new DouyinSite()`

### 子进程卡�?
- **子进�?`Process.start` 必须�?`mode: ProcessStartMode.detached`**，否�?stdout 管道写满 4KB 死锁
- **`main.dart` 子进程入口加 `CoreLog.enableLog = false`**（双重保险）

### 构建
- 构建前设�?`$env:FLUTTER_VS_INSTALL_PATH` �?`$env:FLUTTER_VS_MSVC_VERSION`
- Flutter SDK patches �?`D:\flutter`（`flutter upgrade` 会覆盖）

### 部署（覆�?exe/DLL/data，保留配置文件）
- **绝对不要 `Remove-Item -Recurse` �?`D:\simple_live`** �?会删�?`blocked_users.json`
- 正确做法：逐项从构建输出复制到目标目录，覆盖同名文件，不删不存在于构建输出中的文件
- ⚠️ `Copy-Item -Recurse` 到已有目录会产生嵌套！用 `$dst\` 作目标而非 `$dst\$name`
```powershell
$src = "simple_live_app\build\windows\x64\runner\Release"
$dst = "D:\simple_live"
Get-ChildItem $src | ForEach-Object {
  if ($_.PSIsContainer) {
    Copy-Item -Path $_.FullName -Destination "$dst\" -Recurse -Force
  } else {
    Copy-Item -Path $_.FullName -Destination "$dst\" -Force
  }
}
```
- `blocked_users.json` 不存在于构建输出 �?永远不会被覆盖，无需备份恢复

### AI token 消�?
- **每次 `flutter build` 输出 + 部署操作都进入对话上下文，消�?token**
- 构建/部署完成后应提醒 AI compress 掉这些原始输出（只留"构建成功/部署完毕"结论�?

## Project Overview
- 聚合直播平台 (Bilibili, 斗鱼, 虎牙, 抖音�? �?Flutter 桌面�?
- 两个入口: `simple_live_app/` (Flutter GUI) + `simple_live_console/` (CLI)
- 核心�? `simple_live_core/` (�?Dart package)
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
The Flutter SDK was patched to bypass this �?see "Flutter SDK Patches" below.

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

### 部署（覆�?exe/DLL/data，保留配置文件）
- **绝对不要 `Remove-Item -Recurse` �?`D:\simple_live`** �?会删�?`blocked_users.json`
- 正确做法：逐项从构建输出复制到目标目录，覆盖同名文件，不删不存在于构建输出中的文件
- ⚠️ `Copy-Item -Recurse` 到已有目录会产生嵌套！用 `$dst\` 作目标而非 `$dst\$name`
```powershell
$src = "simple_live_app\build\windows\x64\runner\Release"
$dst = "D:\simple_live"
Get-ChildItem $src | ForEach-Object {
  if ($_.PSIsContainer) {
    Copy-Item -Path $_.FullName -Destination "$dst\" -Recurse -Force
  } else {
    Copy-Item -Path $_.FullName -Destination "$dst\" -Force
  }
}
```
- `blocked_users.json` 不存在于构建输出 �?永远不会被覆盖，无需备份恢复

### Proxy
- SOCKS5 proxy on port 7897, set via `cmd_init.bat` (AutoRun script on cmd startup)
- Proxy can corrupt CMake's built-in file downloads (mpv, ANGLE .7z files)
- cmd_init.bat is now SILENT (no `[Proxy ON]` echo), removing the echo fixed MSBuild `FormatException`
- PowerShell does NOT have the proxy AutoRun �?use PowerShell to bypass proxy-related cmd issues

## ⚠️ C 盘缓存 — 绝不碰！
- **禁止 AI 清理 C 盘空间！** 不删 C 盘 CrashDumps、Temp、Chrome 缓存、Pub 缓存等
- 以下目录仅作知识记录（了解缓存位置），不是清理清单
- 只允许操作：项目目录、`D:\simple_live\`、`D:\flutter\`、`D:\VS\`、`D:\tools\`

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

### 1. KeepAliveWrapper �?关注 Tab 不重置滚动位�?
**File:** `simple_live_app/lib/modules/live_room/live_room_page.dart`
**Line:** ~731
**Change:** Wrapped `buildFollowList()` return value with `KeepAliveWrapper`.
- Prevents `PageView` from destroying the follow-list widget when switching tabs
- User confirmed fixed (scrolling position no longer resets)

### 2. 弹幕字体/速度自适应窗口缩放
**Files:**
- `simple_live_app/lib/modules/live_room/player/player_controls.dart` �?`buildDanmuView()`
- `simple_live_app/lib/modules/live_room/live_room_controller.dart`

**How it works:**
- `Positioned.fill` 直接作为 Stack 子节点（避免白色遮挡），内部 `Obx(Offstage(Padding(danmakuView)))`
- `DanmakuScreen` 只创建一次（`if (danmakuView == null)`�?
- 窗口大小变化触发 `LiveRoomController.didChangeMetrics()` �?200ms 防抖 �?`_applyDanmakuScale()`
- `_applyDanmakuScale()` 通过 `windowManager.getBounds()` 获取窗口宽度
- 缩放公式: `scale = (width / 1920).clamp(0.5, 3.0)`
- 字号 = 用户设定 × scale; duration = 用户设定 × scale，clamp 4~20
- 设置页改动字�?速度等自动触�?`ever` 监听�?�?重新调用 `_applyDanmakuScale()`

### 3. 弹幕设置页实时同�?
**File:** `simple_live_app/lib/modules/live_room/live_room_controller.dart`
**Change:** �?`onInit()` 中加 5 �?`ever` 监听�?
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

### 6. Huya 防反爬标�?

**用户�?虎牙坏了"时：**
打开 `simple_live_core/lib/src/huya_site.dart`，搜 `[虎牙参数]` 可以看到所有关键行�?
对照 https://github.com/wbt5/real-url �?`huya.py` 更新�?

**共有 5 �?`[虎牙参数]` 位置（类顶部注释覆盖范围）：**
1. `kUserAgent` �?房间页爬�?UA
2. `HYSDK_UA` �?直播流请�?UA，最常改
3. `tupClient` �?Tars RPC 接口地址
4. `tid.sHuYaUA` (getCndTokenInfoEx �? �?RPC 体内 UA
5. 远程配置 URL (获取 play_config.json 的地�?

### 7. 修复 db_service 标签去重 bug

**File:** `simple_live_app/lib/services/db_service.dart:54`
**Bug:** `if (getFollowTagExistByTag(tag) && tag.length > 8)` �?条件应为 `||` 或直接只判断存在�?
原代码用 `&&` 导致短标签（<=8字符）永远不命中，每次导入都创建重复标签�?
**Fix:** 删掉 `&&` 后的长度判断，只检查是否存在�?

### 8. 多窗口弹幕播放器（子进程�?

**架构�?* 放弃 `desktop_multi_window`（同进程多引擎），改�?`Process.start` 独立进程�?

**文件�?*
- `main.dart:17-33` �?启动时检�?`SIMPLE_LIVE_MINIPLAYER` 环境变量，存在则直接�?`MiniPlayerApp`（不初始�?Hive/GetX/服务�?
- `windows/mini_player_window.dart` �?`MiniPlayerApp` / `MiniPlayerPage` / `MiniPlayerArguments`，自包含的播放器页面
- `modules/live_room/live_room_page.dart:924-1004` �?`_openMiniWindow()`，主进程解析�?URL + 弹幕参数，但**抖音除外**（抖音由子进程自己解�?URL，否则黑屏）

**弹幕连接�?*
- 子进�?*直接**连平�?WebSocket（BiliBiliDanmaku / DouyuDanmaku / HuyaDanmaku / DouyinDanmaku），不经过主进程
- 主进程只传连接参数（roomId、token、serverHost 等）�?`MiniPlayerArguments.danmakuJson`
- 启动窗口期间（~1-2秒）会漏弹幕，连接成功后实时接收

**注意�?*
- 子进程是完整 `simple_live_app.exe`，不�?Hive / GetX / dio
- 弹幕默认关闭，标题栏有开关按钮（`_buildDanmakuToggle()`�?
- 每个子进�?~200-400MB RAM，按需使用
- 环境变量 JSON 小于 Windows 32KB 限制

### ⚠️ 子窗口独立原则（不可违反�?
- **子窗口和主窗口在 UI 上完全无�?* —�?子窗口就是一个独立的新播放器控件
- 二者除了启动时的环境变�?JSON 数据传输外，**不能有任何共享状�?*
- **禁止�?* 共享 GetX 实例、共�?Dio 单例、共�?Hive 实例、共享任�?Dart 对象
- **禁止�?* 子进程读写主进程的内存或文件（`BlockedUsersService` �?JSON 文件是唯一跨进程存储，且只读不写冲突）
- **允许�?* 主进�?`Process.start` 传环境变�?�?子进�?`Platform.environment` 读取
- **允许�?* 主进�?`MiniPlayerManager` 记录子进�?PID（用�?cascade 索引分配 + 主窗口关闭时 kill）—�?只跟�?PID，不�?UI 状�?
- **子进程只�?FFI 参数（SetWindowLongPtrW），不传 UI 状�?*

### 子窗口标题栏结构（不可忘记）
- **需求：去掉原生 OS 标题栏，保留自定义标题栏**
- 原生 OS 标题栏通过 `SetWindowLongPtrW` �?`main.dart` �?`runApp` 之前移除（保�?`WS_THICKFRAME` 可调边框）：
  - **唯一一处：`main.dart` mini-player block �?`runApp(...)` 之前，`windowManager.setBounds` 之后**
  - 时序：C++ Flutter runner �?`main()` 运行前已创建好窗口（`FLUTTER_RUNNER_WIN32_WINDOW`），`FindWindowW` 一定找得到，不需要重�?
  - **PID 过滤�?* `FindWindowW` 是全局窗口搜索（跨进程），必须�?`GetCurrentProcessId` + `GetWindowThreadProcessId` 确认找到�?HWND 属于当前子进程，防止误删主进程标题栏
  - **加上 `SetWindowPos(SWP_FRAMECHANGED)`** 重算 NC 区消�?31px 空位。此�?swap chain 未创建，不白�?
- `mini_player_window.dart` **没有**移除逻辑（不再需�?`_removeOsTitleBar`�?
- ⚠️ **removeMask 必须�?`0x00CB0000` 不是 `0x00CF0000`**：`0x00CF0000` 多包�?`WS_SIZEBOX(0x040000)`，会删除可调边框导致无法拖拽大小
- 自定义标题栏 36px 高，黑渐变背景，`_showControls` 控制显示/隐藏�? 秒无鼠标动作后隐藏）
- 布局：`Stack(渐变 + GestureDetector(左半文字: 拖拽+双击全屏) + Positioned(右半按钮))`
- **文字区用自定�?`GestureDetector` 替代 `DragToMoveArea`**（`behavior: HitTestBehavior.translucent`）：
  - `onPanStart` �?`windowManager.startDragging()`（拖拽移动）
  - `onDoubleTap` �?`_toggleFullscreen()`（双击全屏，非最大化�?
- **禁止用文字区 GestureDetector 包裹按钮** —�?按钮在独�?`Positioned(right:0)` 中，物理上不重叠
- 标题文字�?`widget.args.userName`（主播名），不是 `title`
- 按钮从右到左：关�?�?最大化/还原 �?最小化 �?**浏览器打开** �?置顶 �?弹幕开�?�?字号 +/- �?速度 << >>
- 浏览器按钮（`Icons.open_in_browser`）→ `_openInBrowser()`，按平台构建 web URL（抖音取 `webRid`�?
- 关闭按钮点击：`globalMiniPlayer.dispose()` + `windowManager.setPreventClose(false)` + `windowManager.destroy()`
- 全屏：`windowManager.isFullScreen()` + `setFullScreen()`（注�?API �?camelCase FullScreen 不是 Fullscreen�?
- 控件显示策略：`onEnter` 显示 �?`onExit` 3 秒后 null-form 移除。不�?`onHover`（MouseRegion onHover 即使只做字段检查也会触�?Flutter 每帧命中测试，多窗口�?CPU 明显升高�?
- **ESC 退出全屏已删除�?* `Focus(autofocus: true)` 在多子窗口下可能引起 focus scope 抖动导致 CPU 上涨。等找到�?CPU 方案再加回来�?
- `_cleanupTimer` 回调中注�?`_isOverlayActive` �?true 时也应跳�?`setState`（当前写的是 `if (!_isOverlayActive) _showControls = false;` �?`setState` 仍在外面统一调用�?
### 子窗口自定义控件�?�?轻量级覆�?+ CPU 回归修复�?026-06-02�?
- **🔥 CPU 回归根因：`MaterialDesktopVideoControlsTheme` 包裹 `Video` + `controls: MaterialDesktopVideoControls`** 导致每个子窗�?~11 �?stream subscriptions + `AnimatedOpacity` + 复杂子树�?0 个子窗口仅能开 5 �?
- **修复方案�?* 永久 `controls: null`，完全移�?`MaterialDesktopVideoControlsTheme`。`MaterialDesktopVideoControls` 内部订阅 `playlist` + `buffering` 两个流，无用户交互也会持续触�?`setState`。加�?5 个子控件的额外流订阅，总共 11 个。删除后恢复 10 窗口容量
- **自定义控件栏**（`_buildControlsBar`）：底部 48px 渐变条，包含播放/暂停 + 音量图标 + 音量滑动�?
  - �?null-form（`if (_showControls)`），hover 才挂载，离开 3 秒后销�?
- **`_volume` 是滑块自身状态（不是 player.state.volume 的副本）�?*
  - `player.stream.volume` 是异步的（platform channel IPC），拖拽时不能依赖它提供实时反馈
  - `_volume` �?Slider widget 的交互变量，`onChanged` 更新 `_volume` + `player.setVolume()` + `setState` 同步
  - `_volumeSub` �?volume 流变化时写入 `_volume = v` 双向同步
  - 播放/暂停 icon �?`player.state.playing` 直读（足够快�?
- `_showControls` 同时控制**自定义标题栏** + **控件�?*的挂�?销�?
- 显示策略：`onEnter` 显示 �?`onHover` 重置 3 秒倒计时（鼠标每动一下延后）�?`onExit` �?3 秒倒计�?�?倒计时到�?`_showControls=false`（null-form 真移除）
- **DanmakuScreen** 定位 `top: _showControls ? 36 : 0`（避开标题栏），`bottom: _showControls ? 48 : 0`（避开控件栏）
- 鼠标进入时不暂停弹幕（`onEnter` 移除 `pause()`），离开时不恢复（`onExit` 移除 `resume()`�?
- 右击弹幕弹出拉黑菜单�?`pause()`，关闭后 `clear() + resume()` 清旧弹幕接实�?

## 抖音子窗口修复思路

### 问题1：黑�?
- 抖音 URL 由主进程解析传到子进�?�?黑屏
- 改为子进程自己调 `DouyinSite().getRoomDetail/getPlayQualites/getPlayUrls` �?正常播放
- 原因未明（可能是 URL 过期或格式差异），但屡试不爽
- **另外必须�?`Player(configuration: PlayerConfiguration(title: 'Simple Live Player', logLevel: MPVLogLevel.error))`**，裸 `Player()` 抖音也黑�?

### 问题2：卡死（关主窗口就好�?
- **根因�?* `Process.start` 默认�?stdout/stderr 管道，子进程 `HttpClient.instance`（Dio 单例）的 `CustomInterceptor` �?`CoreLog` �?`Logger` �?`print()` �?stdout
- 主进程从不读管道�?KB 缓冲区写满就死锁
- **修复�?* `Process.start` �?`mode: ProcessStartMode.detached`，不连管�?
- **双重保险�?* `main.dart` 子进程入口加 `CoreLog.enableLog = false`

### 问题3：主进程 cookie 丢失
- `_openMiniWindow()` 中抖音分支误�?`new DouyinSite()` �?没用�?cookie
- **修复�?* �?`Sites.allSites[Constant.kDouyin]!.liveSite` 单例，保�?`DouyinAccountService` 设的 cookie

### 教训
- 抖音 URL **永远不能让主进程解析传到子进�?* �?必黑�?
- 子进程只要做 HTTP 请求（Dio），就必须防管道死锁
- `ProcessStartMode.detached` + `CoreLog.enableLog = false` 是标准配�?

## Quick Reference for AI

**当用户说"弹幕不显�?时：**
- 主窗�? 检�?`player_controls.dart` �?`buildDanmuView()` 是否多层嵌套/遮挡
- 子窗�? 弹幕默认关闭（需点标题栏眼睛按钮开启）。如不显示，检�?`_connectDanmaku()` �?`danmakuJson` 是否有数�?

**当用户说"虎牙坏了"时：**
- 打开 `simple_live_core/lib/src/huya_site.dart`，搜 `[虎牙参数]` 更新 UA/Tars 接口

**当用户说"子窗口打不开"时：**
- 检�?`live_room_page.dart:924` �?`_openMiniWindow()` 中的 stream URL 解析
- 子进程启动时需�?`MediaKit.ensureInitialized()` �?`main()` 中完�?
- `Process.start` �?`environment` 参数必须包含 `SIMPLE_LIVE_MINIPLAYER` JSON

**当用户说"抖音子窗口黑�?时：**
- 抖音必须由子进程自己解析�?URL（主进程解析传到子进程就用不了，原因不明但屡试不爽）
- `_openMiniWindow()` 中抖音走单独分支：`_openMiniWindow` 只取 `danmakuJson`，`streamUrl` 留空
- **注意�?* 抖音分支必须�?`Sites.allSites` 的单例（保留用户 cookie），不能 `new DouyinSite()`
- `mini_player_window.dart._play()` 检�?`streamUrl.isEmpty && siteId == 'douyin'` 时调�?`_resolveDouyinAndPlay()`
- `_resolveDouyinAndPlay()` 在子进程内调�?`DouyinSite().getRoomDetail/getPlayQualites/getPlayUrls`，然�?`player.open`
- **`mini_player_window.dart` �?`Player` 必须�?`configuration` 参数（`PlayerConfiguration(title: ..., logLevel: MPVLogLevel.error)`�?*，裸 `Player()` 抖音黑屏
- 其他平台（B�?斗鱼/虎牙）：主进程解�?URL 后传给子进程，子进程不重复解析（B站重复解析会卡死�?
- 任何时候都不要把抖音URL放到 `streamUrl` 传给子进程——必黑屏

**当用户说"子进程卡死（关主窗口就好�?时：**
- 根因：`Process.start` 默认创建 stdout/stderr 管道，子进程 `HttpClient.instance`（Dio 单例）的 `CustomInterceptor` �?`CoreLog` �?`Logger` �?`print()` �?stdout
- 主进程从不读管道�?KB 缓冲区写满就死锁
- 关主窗口 �?管道断开 �?子进程解�?
- 修复：`_openMiniWindow()` �?`Process.start` �?`mode: ProcessStartMode.detached`，不连管�?
- 双重保险：`main.dart` 子进程入口加 `CoreLog.enableLog = false`
- 所有平台都会触发，只是抖音子进程需�?HTTP 请求（Dio 输出日志最多），所以最容易复现

**当构建失败（MSVC/VS）时�?*
- 确保设置�?`FLUTTER_VS_INSTALL_PATH` �?`FLUTTER_VS_MSVC_VERSION`
- 检�?`D:\flutter\` SDK �?patches 是否还在（`flutter upgrade` 会覆盖）

**安全删除操作�?*
1. �?`simple_live_app/build/`（重建即可）
2. �?`D:\simple_live\` 下所有文件（重建输出�?
3. �?`simple_live_core/packages/dart_quickjs/`（需要重�?git clone�?

## GitHub Repository
- **GitHub 用户:** https://github.com/Shameless404
- **远程仓库:** https://github.com/Shameless404/dart_simple_live.git
- **默认分支:** master
- **注意:** GitHub Personal Access Token 需�?`workflow` 权限才能推�?`.github/workflows/` 下的文件。✅ 已解决�?

## SDK Constraints
- Dart SDK constraint: `>=3.0.5 <4.0.0` (app), `>=3.10.0` (core)
- Flutter: 3.44.0
- Key packages: dio ^5.9.0, get ^4.7.3, protobuf ^3.1.0, lottie ^3.3.2, media_kit

## Release & GitHub 操作规范

### Release 操作红牌
- **绝不自行修改 Release 描述**（语言、格式、内容）必须先问用户
- **Release ZIP 文件名必须与 README 链接一致**：`simple_live_v<version>_windows-x64.zip`
- **版本永远 v0.0.1**，不做版本递增
- **创建 release 后检查**：`draft` 要发布、描述是否正确、ZIP 可下载
- **🔥 更新 release 绝不重新 build！** 用 `D:\simple_live\` 已有的构建输出打 ZIP
- **绝不碰 C 盘**（缓存、CrashDumps、Chrome、Temp 等都不要管）
- **tag 必须同步更新到最新 commit**，否则 GitHub 源码 zip 不会更新
- **如果 release 是 draft 状态，必须 publish**，否则下载链接是 `untagged-xxx` 格式

### Release ZIP 创建
```powershell
# 从构建输出创�?ZIP（不部署到 D:\simple_live\）
New-Item -ItemType Directory -Path "temp_zip" -Force | Out-Null
Get-ChildItem "simple_live_app\build\windows\x64\runner\Release" | ForEach-Object {
  if ($_.PSIsContainer) {
    Copy-Item -Path $_.FullName -Destination "temp_zip\$($_.Name)" -Recurse -Force
  } else {
    Copy-Item -Path $_.FullName -Destination "temp_zip\" -Force
  }
}
Compress-Archive -Path "temp_zip\*" -DestinationPath "simple_live_v0.0.1_windows-x64.zip" -Force
Remove-Item -LiteralPath "temp_zip" -Recurse -Force
```
> **注意：** 系统没有安装 `zip` 命令，必须用 PowerShell 自带的 `Compress-Archive`。ZIP 在项目根目录创建，用完即删，不放 `D:\simple_live\`。

**🔥 更新 release 时的正确做法（不 build，用 D:\simple_live\ 现有文件）：**
```powershell
# 更新 tag（让 GitHub 重新生成源码包）
git tag -d v0.0.1
git push origin :refs/tags/v0.0.1
git tag v0.0.1 HEAD
git push origin v0.0.1

# 从 D:\simple_live\ 打 ZIP（排除 blocked_users.json）
New-Item -ItemType Directory -Path "temp_zip" -Force | Out-Null
Get-ChildItem "D:\simple_live" | Where-Object { $_.Name -ne "blocked_users.json" } | ForEach-Object {
  if ($_.PSIsContainer) {
    Copy-Item -Path $_.FullName -Destination "temp_zip\$($_.Name)" -Recurse -Force
  } else {
    Copy-Item -Path $_.FullName -Destination "temp_zip\" -Force
  }
}
Compress-Archive -Path "temp_zip\*" -DestinationPath "simple_live_v0.0.1_windows-x64.zip" -Force
Remove-Item -LiteralPath "temp_zip" -Recurse -Force

# 然后走 Release Asset 替换流程
```

### Release Asset 替换（不删 release / tag）
```powershell
# 1. 获取 release ID
$release = curl.exe -s -H "Authorization: token <TOKEN>" https://api.github.com/repos/Shameless404/dart_simple_live/releases/tags/v0.0.1
# release_id = from json, asset_id = from json.assets[0].id

# 2. 删旧 asset
curl.exe -s -X DELETE -H "Authorization: token <TOKEN>" https://api.github.com/repos/Shameless404/dart_simple_live/releases/assets/<ASSET_ID>

# 3. 上传新 asset
curl.exe -s -X POST -H "Authorization: token <TOKEN>" -H "Content-Type: application/zip" --data-binary "@simple_live_v0.0.1_windows-x64.zip" "https://uploads.github.com/repos/Shameless404/dart_simple_live/releases/<RELEASE_ID>/assets?name=simple_live_v0.0.1_windows-x64.zip"

# 4. 删本地 ZIP
Remove-Item -LiteralPath "simple_live_v0.0.1_windows-x64.zip" -Force
```
> **注意：** Token 在 `git remote -v` 的 URL 中（`https://<TOKEN>@github.com/...`）。不删 release 也不删 tag，只替换 asset。
> **draft 处理：** 如果 release 是 draft 状态（`Get-ChildItem` 返回或通过 API 查 `draft=True`），必须先 publish 再替换 asset，否则下载链接是 `untagged-xxx` 格式且源码包不会自动更新。发布用 `curl.exe -s -X PATCH` 设 `{"draft":false}`。

### 两种场景区分

**场景 A �?本地测试（正常情况）�?*
- 构建后部署到 `D:\simple_live\`，覆盖旧�?exe + DLL
- 用户双击运行测试

**场景 B �?发布 Release（上�?GitHub）：**
- 不动 `D:\simple_live\`（用户本地运行的版本不受影响）
- 从 `D:\simple_live\` 打包 ZIP（排除 `blocked_users.json`），上传到 GitHub Release
- ZIP 是中间产物，上传完成后从源码目录删除
- 没有 gh CLI，用 `curl.exe` + GitHub REST API
- **绝不重新 build**，用已有的构建输出

### PowerShell 中文编码
- `ConvertTo-Json` + `Invoke-RestMethod` 会导致中文乱码（PowerShell 5.1 限制�?
- 可靠方案：`curl.exe -s -X PATCH ... --data-binary "@file.json"` + 文件�?`[System.Text.Encoding]::ASCII.GetBytes(unicodeEscapedJson)` 写入
- 对中文用 `\uXXXX` 转义再拼 JSON，确保输出纯 ASCII

## 子进�?hardError 修复（最终方案）

### 根因
用户�?X �?Flutter 引擎先开�?native shutdown �?`MiniPlayerState.dispose()` �?`player.dispose()` �?mpv 回调发向已销毁的 isolate �?hardError。`exit(0)` 也来不及（engine shutdown 先于 `dispose()` 执行）�?

### 修复方案
�?`main.dart` 子进程入口加 `window_manager` 拦截 WM_CLOSE�?
```dart
await windowManager.ensureInitialized();
await windowManager.setPreventClose(true);
windowManager.addListener(_MiniWindowCloseHandler());
```

`_MiniWindowCloseHandler` �?`destroy()` 前先 dispose player�?
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
- 定义�?`mini_player_window.dart`：`Player? globalMiniPlayer;`
- `MiniPlayerPage.initState()` 中赋值：`globalMiniPlayer = player;`
- `MiniPlayerPage.dispose()` 中置 null：`globalMiniPlayer = null;`
- `main.dart` �?import `mini_player_window.dart`，可直接访问

## canvas_danmaku 空转 CPU 修复
- canvas_danmaku 0.2.7 �?30fps Timer 即使弹幕列表为空也调�?`setState()` �?白烧 CPU
- **修复（pub cache�? 处）�?*
  1. `initState()` Timer 回调�? 个列表全空时 `return` �?`setState`
  2. `resume()` 中创建的 Timer 回调：同�?
  3. `_startTick()` while 循环开头：4 个列表全空时 `continue` 跳过 `removeWhere`
- 默认弹幕 OFF �?`DanmakuScreen` 不在 widget 树，零开销
- 弹幕 ON 但无消息�?Timer 仍跑�?`setState` 被跳过，`_startTick` 循环�?`Future.delayed(100ms)`

## 子窗口默认状�?�?CPU 零额外开销
- **音量�?* 初始必须 `player.setVolume(0.0)` —�?默认静音（media_kit范围�?.0-100.0�?00.0为最大）
- **播放器：** 永久 `controls: null`（无原生控件子树），�?mpv 解码
- **弹幕�?* 默认关闭（`_danmakuUserEnabled = false`），不在树中。开启后始终在树�?
- **标题栏：** 默认不显示，null-form（`if (_showControls)`），鼠标进入才挂�?
- **控件栏：** 默认不显示，null-form（`if (_showControls)`），与标题栏同步挂载/销�?
- 所有平台统一：弹�?标题�?控件栏默认不在树，无 Timer/Stream 开销

## 置顶 toggle 修复
- `_PinToggleButton.onTap` 必须�?`await windowManager.setAlwaysOnTop(newValue)` �?`setState`
- `initState` 中加 `_initPinned()` �?`windowManager.isAlwaysOnTop()` 读取真实状�?
- 控制栏重建时（鼠标离开/再进入）不再复位�?false，始终从真实窗口状态同�?

## 子窗口尺寸按宽高比适配
- **方案�?* �?`player.stream.videoParams.firstWhere(dw>0, dh>0)` �?CPU 等视频尺�?
- 必须�?`player.open()` 前订�?stream（broadcast 不重放历史，否则错过事件�?
- 横屏（aspectRatio �?1）→ 宽度 640，高度按比例缩放
- 竖屏 �?高度 540，宽度按比例缩放
- 处理 `rotate` 90/270 交换 w/h
- Clamp: 280~900 × 200~700

### 9. 关注列表启动时自动刷�?
- `follow_user_controller.dart:45`: `onInit()` 中加 `filterData()` �?�?`FollowService.followList` �?`pageController.list`
- `follow_user_controller.dart:46`: �?`updateTagList()` 展示自定义标�?
- `follow_user_controller.dart:81-88`: `filterData()` 额外�?`pageEmpty`, `pageError`, `pageLoadding`, `canLoadMore=false`
- `follow_service.dart:57`: `onInit()` �?`loadData()`（启动时�?Hive 加载�?
- `follow_user_page.dart:155`: `firstRefresh: true �?false`
- **构建输出位置�?* `D:\simple_live\simple_live_app.exe`

### 10. canvas_danmaku 无手�?点击 API
- 整个 widget �?`IgnorePointer` 包裹，不参与 HitTest
- `DanmakuController` 仅有 CRUD：`pause/resume/clear/addDanmaku/updateOption`
- `DanmakuContentItem` 只有 `text/color/type/selfSend`，无 `userName`
- 弹幕上实现右�?点击 �?必须�?pub cache 源码

### 11. 弹幕拉黑管理（已实现�?

**存储�?* `blocked_users.json` �?exe 同目录，一行一�?JSON，`key=platform:userName`

**架构�?*
- `BlockedUsersService` �?�?Dart 单例（无 GetX/Hive 依赖），主进程和子进程通用
- `AppSettingsController` �?包装 `RxMap<String, BlockedUserEntry>` 做设置页响应�?
- `BlockedUsersController` + `BlockedUsersPage` �?设置页拉黑管�?UI

**入口（聊天消息右�?+ 子窗口弹幕右�?+ 设置页）�?*
1. **聊天消息右击�?* `live_room_page.dart` `buildMessageItem()` �?GestureDetector(onSecondaryTapDown) �?showMenu �?`BlockedUsersService.instance.block()`
2. **子窗口弹幕右击：** `mini_player_window.dart` �?`_onDanmakuTap()` �?直接拉黑 + OverlayEntry toast
3. **设置页：** `danmu_settings_page.dart` �?"拉黑管理" �?列出所有已拉黑用户，可移除

**pub cache 追加修改（canvas_danmaku 0.2.7）：**
1. `danmaku_content_item.dart` �?�?`userName` 字段
2. `danmaku_screen.dart` �?移除 `IgnorePointer`，加 `GestureDetector` + hit-test + `onDanmakuSecondaryTap` 回调
3. `danmaku_screen.dart` �?`GestureDetector` 必须�?`behavior: HitTestBehavior.translucent`，否�?GestureDetector 参与 hit test 会挡住父�?`MouseRegion` �?hover 事件，导致弹幕开启时子窗�?`onEnter` 不触发（鼠标必须移到最底下才能显示播放器控件）

**子窗口区别：** 主窗口走聊天右击（`player_controls.dart` 已无弹幕右击），子窗口走弹幕右击�?
**子窗口盾词缺失：** 子窗�?`_setupDanmakuHandlers` 只有拉黑过滤没有盾词过滤（用户已知）�?

### 12. BlockedUsersService 简化（2026-05-31�?
**去掉�?File.watch + onChangeCallbacks + dispose，改用：**
- `block()` �?内存加一�?+ �?`FileMode.append` 追加一行（`\n${jsonEncode(entry.toJson())}`），不全文重�?
- `unblock()` �?内存�?+ 全文重写（删行必须）
- `init()` �?启动时检测文件不存在则创建空文件
- `reload()` �?只重新读文件，无文件监听
- 格式：一行一�?JSON，每�?`{"key":...,"userName":...,"anchorName":...,"platform":...,"message":...,"timestamp":...}`
- 跨进程不同步（子窗口拉黑只存自己文件，不通知主窗口）
- 每次进拉黑管理页面时 `initState()` �?`reload()` 再同�?RxMap

### 13. anchorName 字段�?026-05-31�?
**File:** `blocked_users_service.dart`
- `BlockedUserEntry` �?`String anchorName`（主播名字）
- `block()` �?`{String anchorName = ''}` 参数
- 兼容旧数据：`fromJson` �?`json['anchorName'] as String? ?? ''`
- 调用方：`live_room_page.dart:563` �?`controller.detail.value?.userName`，`mini_player_window.dart:374` �?`widget.args.userName`
- `blocked_users_page.dart` 展示格式为两行：`用户�?[平台] 主播名`（同级别�? 灰色缩进第二行弹幕内容（平铺 Column，不�?ListTile title/subtitle�?

### 14. 子窗口弹幕鼠标交互修复（2026-06-03�?
- **问题�?* 全屏/大窗口时鼠标进出触发 `danmakuController?.pause/resume`，弹幕永久卡�?
- **onEnter�?* 移除 `danmakuController?.pause()` �?进入窗口不暂停弹�?
- **onExit�?* 移除 `danmakuController?.resume()` �?离开窗口不恢复弹幕（弹幕自然滚动�?
- **右击拉黑关闭后：** 两条关闭路径只调 `resume()`，不 `clear()` �?弹幕继续自然滚动，支持连续拉黑多�?
- **标题栏弹幕开关：** 已经是纯 null-form 真关闭（`liveDanmaku.stop()` + widget 移出树），开时重�?`_connectDanmaku()`，天然清空重�?
- **右击弹出时：** 仍保�?`danmakuController?.pause()` 让用户看清弹�?
- **CPU 影响�?* 零增加（net 减少，去掉了 on-hover �?API 调用�?

### 15. Toast 统一�?026-05-31�?
- 主窗口聊天右击拉黑提示：�?`Get.snackbar` 改为 `OverlayEntry` 黑底白字圆角卡片�? 秒后自动移除
- 和子窗口 `_showToast()` 风格一致（子窗口原本就�?OverlayEntry，未改）

### 16. 关注列表搜索功能�?026-05-31�?

**两个入口�?*

**1. 关注 Tab（`follow_user_page.dart` + `follow_user_controller.dart`�?*
- `FollowUserController.searchQuery: RxString('')` + `onSearch(String query)` 方法
- 搜索时从 `FollowService.instance.followList` �?`userName.toLowerCase().contains(query.toLowerCase())` 模糊匹配
- 清空搜索恢复当前标签筛�?
- 搜索期间自动跳过 `updatedListStream` �?`filterData()`（避免刷新冲掉搜索结果）
- 切换到其他标签时自动清空搜索（`setFilterMode()` �?`searchQuery.value = ''`�?
- UI：`_FollowSearchBar`（StatefulWidget）放在标签栏和网格之间，带搜索图标、`X` 清除按钮

**2. 侧边栏关注列表（`live_room_page.dart` `_FollowListWithSearch`�?*
- `_FollowListWithSearch` StatefulWidget，含 `TextEditingController` + `_query` 状�?
- 搜索时从全部关注搜（不限�?liveList），方便找未开播主�?
- 清空恢复显示 liveList
- 保留 `KeepAliveWrapper` + `RefreshIndicator` + `DesktopRefreshButton`

## 子窗口位置级联（setBounds 提前�?
- **关键保证�?* `main.dart` mini-player 分支中，�?`runApp` 之前算好位置，调�?`setBounds(x, y, 640, 360)` 一次搞定位�?尺寸
- **时序�?* `setBounds` + `SetWindowPos` 已执行完�?�?`runApp` �?Flutter 首帧 �?`ShowWindow` �?窗口第一次出现就在正确位置（零瞬移闪屏）
- **公式�?* `cascadeIndex` (0, 1, 2...) 传入子进程，`x=step*idx`, `y=屏幕�?窗口�?(step*idx)`, 超出边界重置到最左下
- `mini_player_window.dart` 已无 `_setInitialPosition()`，`initState` 只调 `_play()`，视频尺寸就绪后 `_resizeWindow` �?`setSize`（`SWP_NOMOVE` 保留位置�?

## 子窗口声音调试（2026-06-02�?

### 问题特征
- 子窗口播放器完全无声，即使音量滑块显示有�?
- 音量滑块可以拖动，但实际播放音量�?
- 问题出现在自定义控件栏实现后

### 根本原因
**media_kit volume API 范围�?0.0-100.0，不�?0.0-1.0�?*

- `player.setVolume(0.0-100.0)` �?正确范围
- `_volume` 滑块状态用 0.0-1.0 �?UI 习惯
- 传错范围导致 `player.setVolume(0.5)`（几乎静音）

### 修复方案
1. **滑块转换**：`_volume = v / 100.0` + `player.setVolume(v)`（直接传 0-100�?
2. **静音逻辑**：保�?`_lastVolume`，点击时恢复
3. **初始静音**：`player.setVolume(0.0)` + `_volume = 0.0`

### 代码模式
```dart
// Volume 状�?
double _volume = 0.0;      // 滑块自身状态（0.0-1.0�?
double _lastVolume = 0.5;   // 静音前音�?

// Stream 同步
_volumeSub = player.stream.volume.listen((v) {
  _volume = v / 100.0;  // media_kit 0-100 �?_volume 0-1
  setState(() {});
});

// 滑块 onChanged
onChanged: (v) {
  _volume = v / 100.0;  // UI 习惯 0-1
  player.setVolume(v);   // 直接�?0-100 �?media_kit
  setState(() {});
}

// 静音按钮
if (_volume > 0) {
  _lastVolume = _volume;
  _volume = 0.0;
} else {
  _volume = _lastVolume;
}
player.setVolume(_volume * 100.0);  // 转换后传�?media_kit
```

### 调试步骤
1. **检�?media_kit 范围**：确�?0.0-100.0（不�?0.0-1.0�?
2. **验证转换**：确�?`player.setVolume()` 接收 0-100 �?
3. **测试固定音量**：直�?`player.setVolume(50)` 测试半音�?
4. **检查静音恢�?*：静音后恢复的音量是否正�?

**当用户说"子窗口没声音"时：**
- 检查是否所�?`player.setVolume()` 都传 0-100 �?
- 暂时改用 `player.setVolume(50)` 测试半音量是否生�?
- 确认 volume stream 是否正确同步 `_volume`

**当用户说"音量滑块没反�?时：**
- 检�?`_volumeSub` 是否正确设置（`_volume = v / 100.0`�?
- 验证 `player.setVolume(v)` 直接传滑�?0-100 �?
- 确认滑块 `value: _volume * 100` 显示正确

## 滚动位置恢复教训�?026-05-31�?
- **根因�?* `followListScrollOffset` 只在 `onTap` 保存，点击遮罩关�?Dialog 不保�?�?下次打开�?开�?
- **正确做法�?* `ScrollController(initialScrollOffset: savedOffset)` + `scrollCtrl.addListener(() => {if (scrollCtrl.hasClients) controller.followListScrollOffset = scrollCtrl.offset;})`
- **不要搞复杂方案：** 不要�?`_ScrollRestore` + `jumpTo` + 递归重试。监听器持续保存 offset 是最简单可靠的方案
- **排查原则�?* 遇到"某状态没保留"，先检查所有退出路径是否都保存了状态，不要只盯着最明显的那个入口看

**当用户说"关注列表滚动位置不对"时：**
- 检�?Dialog �?`ScrollController` 有没�?`addListener` 持续保存 offset
- 检�?`initialScrollOffset` 有没有传�?
- 不要�?`_ScrollRestore` / `jumpTo` 之类的方�?

**当用户说"release 版本更新"时：**
- 构建 → `Compress-Archive` 创建 ZIP → `curl.exe -X DELETE` 删旧 asset → `curl.exe -X POST` 传新 asset
- 不删 release / tag，不修改版本号，不动 `D:\simple_live\`
- Token 在 `git remote -v` 的 URL 中提取
- **绝不重新 build！** 用已有的构建输出（`D:\simple_live\`）打 ZIP
- 同时更新 tag 到最新 commit，发布 draft

## 子窗�?GPU 降载模式�?026-06 最终方案）

### vf 属性不可写
- `vf` �?libmpv/media_kit 里不可写：`change-list`/`setProperty`/`command` 均返回空�?
- `getProperty` 只对字符串型属性有效（�?`hwdec`），`estimated-display-fps`/`drop-frame-count`/`display-fps` 等浮�?整型属性全部返回空
- 结论：无法通过 vf 缩放分辨率来减少 GPU 负载

### 最终方案：软解自动切最低画�?
**`_toggleHwdecAndReload()` �?`mini_player_window.dart:360`�?*
- **硬解**（默认）：`hwdec=auto` + `framedrop=no` + 最高画质（`qualities[0]`�?
- **软解**（点软）：`hwdec=no` + `framedrop=vo` + 最低画质（`qualities.last`�?

**`_reloadStream()` �?`mini_player_window.dart:333`�?*
- 根据 `_hwdec` 选画质：硬→`qualities[0]`，软→`qualities.last`
- 所有平台（B�?斗鱼/虎牙/抖音）画质列表都是最高到最低排�?

**不用的方案（已证实无�?有害）：**
- `cache=yes` + `cache-secs=N` �?�?闪，已移�?
- `display-fps=24` �?导致画面变慢，已移除
- `deband`/`scaling` 等画质开�?�?和闪屏无关，已移�?

### 使用方式
- 默认硬解看直播（最高画质）
- �?CS→点软解，自动降最低画�?vo丢帧，不卡不�?
- 打完 CS→点硬解，自动恢复最高画�?
- 切的时候短暂黑一下（`stop()+open()` 重新加载流），正常现�?

## vf 属性不可写确认 (2026-06-06)
- setProperty('vf', ...) / command(['change-list', 'vf', 'set', ...]) 全部无效
- 命令执行无异常，但 getProperty('vf') 始终为空字符串
- libmpv/media_kit 限制：**无法**通过 Dart API 修改视频滤镜/缩放
- 替代 GPU 降载方案：hwdec=no + framedrop=vo + 最低画质，唯一有效方案
- 显卡：NVIDIA，D3D11 渲染路径
