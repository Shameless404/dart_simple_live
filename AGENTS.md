# dart_simple_live — Project Context

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
- **弹幕：** 默认 OFF，`_danmakuEnabled = false`，`DanmakuScreen` 不在 widget 树
- **视频：** `Video(controls: null, wakelock: false)`，无原生 controls 子树，仅 mpv 解码
- **控制栏：** `_showControls = false` → build 返回 null，鼠标进入才挂载
- 所有平台统一：弹幕/控制栏默认不在树，无 Timer/Stream 开销

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

### 14. Toast 统一（2026-05-31）
- 主窗口聊天右击拉黑提示：从 `Get.snackbar` 改为 `OverlayEntry` 黑底白字圆角卡片，1 秒后自动移除
- 和子窗口 `_showToast()` 风格一致（子窗口原本就是 OverlayEntry，未改）

### 15. 关注列表搜索功能（2026-05-31）

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
