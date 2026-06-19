# dart_simple_live — Project Context

## 编码偏好
- **null-form 隐藏**：widget 不在图树 = 真隐藏，不用 `Offstage`/`Visibility`/`Opacity(0)` 等假隐藏（假隐藏 widget 仍在树中占据内存、跑 build/didUpdateWidget、有 stream subscription 就继续耗 CPU）

## 不可忘记
- **抖音 URL 永远不让主进程解析传子进程** → 黑屏；子进程自己调 `DouyinSite().getRoomDetail/...`
- 子进程 `Player()` 必须 `configuration: PlayerConfiguration(title:..., logLevel: MPVLogLevel.error)`
- `_openMiniWindow()` 抖音分支用 `Sites.allSites` 单例，不 `new DouyinSite()`
- `Process.start` 必须 `mode: ProcessStartMode.detached`，`main.dart` 子进程入口加 `CoreLog.enableLog = false`
- 构建设 `$env:FLUTTER_VS_INSTALL_PATH` + `$env:FLUTTER_VS_MSVC_VERSION`；Flutter SDK patches 在 `D:\flutter`
- 部署：`D:\simple_live` 绝不 `Remove-Item -Recurse`；`Copy-Item` 用 `"$dst\"` 防嵌套

## 环境
| 组件 | 路径 | 备注 |
|------|------|------|
| Flutter SDK | `D:\flutter` v3.44.0 | patches: visual_studio.dart + build_windows.dart |
| VS BuildTools | `D:\VS\BuildTools`，MSVC 14.44.35207 | 未注册 vswhere |
| dart_quickjs | `simple_live_core/packages/dart_quickjs/` | path 替代 git 依赖 |

## 架构速览
- **主窗口 Stack**：视频 → GestureDetector → 底部 48px 控制栏 → 弹幕层（`Positioned.fill bottom:48`，最高 z）
- **子窗口 Stack**：视频(`controls:null`) → 弹幕(top:36/bottom:48) → 标题栏 36px(null-form) → 控件栏 48px(null-form)
- **数据流**：Dio→Core Site→URL→mpv；WS→Danmaku→canvas_danmaku；拉黑→`BlockedUsersService`→`blocked_users.json`
- **跨进程**：`Process.start` + 环境变量 JSON 传参，不共享 GetX/Dio/Hive 对象

## Quick Reference
- 虎牙坏了 → `huya_site.dart` 搜 `[虎牙参数]`（5 处）
- 子窗口没声音 → `player.setVolume()` 传 0-100 不是 0-1
- 构建失败 → 检查 env vars + Flutter SDK patches
- 子进程卡死 → `detached` + `CoreLog.enableLog = false`

## 排查记录（思路+难点）

### layers 弹幕右键 vs 控件冲突
`GestureDetector(translucent)` 不传透右键、弹幕在上层阻 `MouseRegion(onEnter)`
→ **最终方案**：弹幕限高（`Positioned.fill bottom:48`），顶部兼顾右键穿透，底部留空间给控件 hover

### deploy 文件没覆盖
`Copy-Item -Recurse -Destination "$dst\$name"` 到已存在的 `data\` 目录 → 生成 `data\data\app.so` 嵌套
→ 部署后控件消失/修改不生效时，**先检查 `D:\simple_live\` 对应文件时间戳**，否则可能白排查

### scroll 弹幕右键命中偏移
`DanmakuScreen._findDanmakuAtPosition` 用 `item.xPosition - (_viewWidth + item.width) * progress` 重复计算位移
→ 思路：ScrollDanmakuPainter 已每帧增量更新 `xPosition += delta`；**画布上当前 `xPosition` 就是实时位置**，不需再加进度换算

### OverlayEntry 叠层泄漏
每次右键 `overlay.insert()` 透明全屏截点 → 多次后叠 3-4 层互相盖
→ **修复模式**：顶层变量 `_danmakuMenuEntry` 跟踪，新插入前先 `remove()` 旧的

### percentage vs pixel 控件对齐
80% 弹幕覆盖（`FractionallySizedBox(0.8)`）→ 底部留 20% 不符实际 48px 控件栏
→ **原则**：UI 组件对齐固定像素元素时用 `Positioned(bottom:48)` 而非比例值

### media_kit controls 隐藏流
`MaterialDesktopVideoControls` 订阅 `playlist`+`buffering`，无交互也触 `setState` → CPU 上涨
→ **原则**：第三控件库的流订阅不可见但耗资源；自义 `controls:null` + 轻量自实现才可控

### vf 属性不可写
`setProperty('vf',...)` / `command(['change-list','vf',...])` 在 Dart API 层全部无效果
→ 替代：`hwdec=no` + `framedrop=vo` + 最低画质

## Release
- 版本永远 `v0.0.1`，ZIP: `simple_live_v0.0.1_windows-x64.zip`
- 更新：不 build，`D:\simple_live\` 打 ZIP（排除 blocked_users.json）→ curl.exe 换 asset
- Token 在 `git remote -v` URL 中；draft 必须先 publish
