# dart_simple_live — Project Context

## 编码偏好
- **null-form 隐藏**：widget 不在图树 = 真隐藏，不用 `Offstage`/`Visibility`/`Opacity(0)` 等假隐藏（假隐藏 widget 仍在树中占据内存、跑 build/didUpdateWidget、有 stream subscription 就继续耗 CPU）

## 不可忘记
- **抖音 URL 永远不让主进程解析传子进程** → 黑屏；子进程自己调 `DouyinSite().getRoomDetail/...`
- 子进程 `Player()` 必须 `configuration: PlayerConfiguration(title:..., logLevel: MPVLogLevel.error)`
- `_openMiniWindow()` 抖音分支用 `Sites.allSites` 单例，不 `new DouyinSite()`
- `Process.start` 必须 `mode: ProcessStartMode.detached`，`main.dart` 子进程入口加 `CoreLog.enableLog = false`
- 构建设 `$env:FLUTTER_VS_INSTALL_PATH` + `$env:FLUTTER_VS_MSVC_VERSION`；Flutter SDK patches 在 `D:\flutter`
- 部署：**只部署到 `D:\simple_live`**，绝不部署到 `C:\Program Files\`

## 部署流程（每次构建后必须执行）
1. 检查 `build\windows\app.so` + `build\flutter_assets\` + `build\windows\x64\runner\Release\simple_live_app.exe` 存在且是最新时间戳
2. 复制命令（3 部分缺一不可）：
   ```
   $src = "D:\Users\Administrator\Desktop\dart_simple_live-master\simple_live_app\build"
   $dst = "D:\simple_live"
   Copy-Item -Recurse -Force "$src\windows\x64\runner\Release\*" "$dst\" -Exclude "*.pdb"
   Copy-Item -Force "$src\windows\app.so" "$dst\data\app.so"
   Copy-Item -Recurse -Force "$src\flutter_assets\*" "$dst\data\flutter_assets\"
   ```
3. **验证**：   `Get-Item "D:\simple_live\data\app.so"` 和 `Get-Item "$src\windows\app.so"` 的 `Length` + `LastWriteTime` 必须一致
4. 忽略警告：`flutter_inappwebview_windows/windows/CMakeLists.txt` 的 CMake DEPENDS 警告是正常的，不影响功能

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
- 平台变糊/几分钟卡死 → 服务端对匿名请求降级 → 详见「匿名 vs 登录降级」；参考斗鱼 cookie 解法
- 子窗口没声音 → `player.setVolume()` 传 0-100 不是 0-1
- 构建失败 → 检查 env vars + Flutter SDK patches
- 子进程卡死 → `detached` + `CoreLog.enableLog = false`

## 问题排查方法论

### 循环复发 bug → 找"行为边界线"

当同一个 bug 反复出现、每次修完又换一种形式复发时：

**第一步：别急着改代码，先问用户观察到什么规律**
- 用户说"前 3 次正常，之后不行" → 问"那第 4 次前后有什么变了？"
- 用户说"消息多了就不行" → 问"刚到 50 条左右？"

**第二步：定位那个"范围线"（行为边界）**
- 这个 bug 反复修了 20+ 轮，每次只是换一种像素启发式（`pos < max - 5`、`_userScroll`、`_scrollToBottomLoop`…）
- 所有尝试都忽略了一个事实：出问题的时机总是在 `_messages.length > 50` 之后
- 50 条就是那条**范围线**，50 之后多出的操作 = `removeAt(0)`

**第三步：找出边界线引入的不可控因素**
- `removeAt(0)` 触发 Flutter 布局引擎的**滚动位置钳位**（`maxScrollExtent` 在 layout 阶段变化）
- 钳位发生在代码控制之外，不在 `_onScroll` 回调中，也不在用户交互中
- 所有像素启发式都在跟幽灵变量打架——你看到的 `pos` 和 `max` 已经不是布局引擎计算完的值

**第四步：找范式转换，而不是修补边界条件**
- 原来的设计：新消息 `add` 到列表末尾 → 用户在最底部 = `maxScrollExtent` → 每次新消息要 `jumpTo(max)` 去"追"
- 新设计：`reverse: true` → 位置 0 永远是底部 → 新消息 `insert(0)` 自然往上推 → 不需要"追"了
- `removeAt(0)` 变成 `removeLast()` → 删顶部旧消息，不碰底部，没有布局钳位

**第五步：状态机 > 像素启发式**
- 旧方案用 `pos >= max - threshold` 判断用户是否在底部 → 惰性渲染 + 布局钳位 → 永远不精确
- 新方案用纯布尔状态 `_paused`：离开底部 > 50px 就 true，回来就 false
- `_paused = true` 时冻结列表（buffer 消息，不 setState），用户看到的内容**一个像素都不动**
- 最后用 `ListQueue` 做 O(1) 缓冲，数据结构对了，性能不用"优化"

**核心原则：**
- 不要和 Flutter 布局系统打架：layout 阶段的 `maxScrollExtent` 调整不受代码控制
- 行为边界线比代码审查更值钱：用户观察到的"范围线"直接指向根因
- 范式转换 > 增量修补：20 轮修 edge case，不如换个思路让 edge case 不存在

### layers 弹幕右键 vs 控件冲突
`GestureDetector(translucent)` 不传透右键、弹幕在上层阻 `MouseRegion(onEnter)`
→ **最终方案**：弹幕限高（`Positioned.fill bottom:48`），顶部兼顾右键穿透，底部留空间给控件 hover

### deploy 文件没覆盖
`Copy-Item -Recurse -Destination "$dst\$name"` 到已存在的 `data\` 目录 → 生成 `data\data\app.so` 嵌套
→ 部署后控件消失/修改不生效时，**先检查 `D:\simple_live\` 对应文件时间戳**，否则可能白排查

- **漏 app.so**：`Copy-Item Release\*` 只复制 EXE 和 DLL，不复制 `build\windows\app.so`，Dart 代码没更新。必须用上面 3 部分命令
- **漏 flutter_assets**：不复制 `build\flutter_assets\` → 运行时可能缺资源
- **路径错**：只部署到 `D:\simple_live\`，绝不能到 `C:\Program Files\`

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

### 平台更新后变糊+卡死 → 匿名 vs 登录降级

**症状**：某个平台"昨天还好好的"，更新后 app 画质变糊 + 播放几分钟断流

**先别死磕签名/参数**（本次斗鱼教训：先在错误签名上耗数小时，其实签名没错，是服务端锁定）：
- 穷举请求 rate/hevc/cdn/did/浏览器头全无变化 → **服务端策略**，不是请求方式问题
- 判别依据：
  - 匿名降级：请求 `rate=0/8` 却返回 `rate=4` + `_4000.flv`/`_2000.flv`（流名后缀）+ `expire=300`（短 token）+ `token=web-h5-0-...`
  - 登录态：无后缀原画流名 + `expire=0`（永不过期）+ `token=web-h5-<uid>-...`

**诊断两步走**：
1. 让用户浏览器登录后，F12 → Network 看同一接口的响应（流名后缀/expire/token 前缀），与 app 匿名结果对比
2. 若确认登录态解锁 → 让用户贴 Cookie（或只贴响应），脚本带 Cookie 重测验证 → 再实现 cookie 登录

**落地模板**（斗鱼已实现，其他平台照抄）：
- Core Site 加 `cookie` 字段，`_getH5PlayData` 请求头带上；`getPlayUrls` 返回 referer/UA/origin headers（修 mpv 无头断流）
- App 建 `*AccountService`（仿 `DouyuAccountService`/`BiliBiliAccountService`）+ 存储 key（仿 `kDouyuCookie`）+ 账号页粘贴/清除 UI
- 子进程 mini player 透传 `douyuCookie`（仿 `bilibiliCookie`）

**注意事项**：
- cookie 约 7 天过期（`acf_jwt_token` exp=iat+7d），过期需重新粘贴；解锁需 `acf_jwt_token` + `acf_auth`/`dy_auth` 组合
- 弹幕 WS 一般不受此影响，不用带 cookie
- 验证脚本用 `python -` 管道 base64 方式跑（`@'...'@` + base64 + `| python -`，不要用 `python -c` 传参）

## Release
- 版本永远 `v0.0.1`，ZIP: `simple_live_v0.0.1_windows-x64.zip`
- 每次 push 后，`v0.0.1` tag 必须一起移到最新 commit，GitHub 源码 zip/tar.gz 才会更新
  ```
  git tag -d v0.0.1
  git tag v0.0.1
  git push --force origin v0.0.1
  ```
- 部署包完整流程（不 build，`D:\simple_live\` 已是最新）：
  1. 打 ZIP（排除 `blocked_users.json`）
  2. 删旧 release（保留 tag）→ 建新 release（发布时间 = today）
  3. 上传新 ZIP
  ```
  :: 1. ZIP
  Add-Type -Assembly "System.IO.Compression.FileSystem"
  $tmp = "$env:TEMP\simple_live_zip"
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  Copy-Item -Recurse "D:\simple_live\*" $tmp -Exclude "blocked_users.json"
  $zipPath = "$env:TEMP\simple_live_v0.0.1_windows-x64.zip"
  [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $zipPath)
  Remove-Item -Recurse -Force $tmp

  :: 2. 删旧 release → 建新 release
  $token = "YOUR_TOKEN"
  $oldRelease = curl.exe -s -H "Authorization: Bearer $token" "https://api.github.com/repos/Shameless404/dart_simple_live/releases/tags/v0.0.1"
  $oldId = ($oldRelease | ConvertFrom-Json).id
  curl.exe -s -X DELETE -H "Authorization: Bearer $token" "https://api.github.com/repos/Shameless404/dart_simple_live/releases/$oldId"
  $newRelease = curl.exe -s -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{"tag_name":"v0.0.1","name":"v0.0.1","draft":false,"prerelease":false}' "https://api.github.com/repos/Shameless404/dart_simple_live/releases"
  $newId = ($newRelease | ConvertFrom-Json).id

  :: 3. 上传 ZIP
  curl.exe -s -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/zip" --data-binary "@$zipPath" "https://uploads.github.com/repos/Shameless404/dart_simple_live/releases/$newId/assets?name=simple_live_v0.0.1_windows-x64.zip"

  :: 4. 清理
  Remove-Item $zipPath
  ```
- Token 在 `git remote -v` URL 中
