# dart_simple_live — Project Context

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
xcopy "simple_live_app\build\windows\x64\runner\Release" "D:\simple_live\" /E /I /Y /Q
```

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

**共有 4 处 `[虎牙参数]` 位置（类顶部注释覆盖范围）：**
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
- 弹幕一直显示，无开关按钮（media_kit controls 会盖住自定义按钮）
- 每个子进程 ~200-400MB RAM，按需使用
- 环境变量 JSON 小于 Windows 32KB 限制

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
- 子窗口: 弹幕一直显示（无法开关），如果子窗口不显示弹幕，检查 `mini_player_window.dart` 的 `_connectDanmaku()` 和 `danmakuJson` 是否有数据

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
