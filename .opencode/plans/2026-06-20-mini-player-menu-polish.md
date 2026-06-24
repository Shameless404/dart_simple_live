# 子窗口菜单美化 + 按钮反馈

## 目标
1. 菜单外观美化（深灰底 + 圆角 + 白字）
2. 菜单项和标题栏按钮增加悬停/点击视觉反馈
3. 菜单浮在标题栏之上（调 Stack 顺序）
4. 资源消耗最小化

## 改动清单

### 1. 调 Stack 渲染顺序
- 文件: `simple_live_app/lib/windows/mini_player_window.dart`
- 将标题栏 `Positioned` 移到菜单 `Stack` **之前**
- 效果: 菜单渲染在标题栏之上（z-order 更高），不会被遮挡

### 2. 菜单容器样式
- 改 `color: Colors.green` 为 `decoration: BoxDecoration`
  - `color: Color(0xFF2D2D2D)` 深灰底
  - `borderRadius: BorderRadius.circular(8)` 圆角
  - `border: Border.all(color: Colors.white24, width: 0.5)` 细边框

### 3. 新增 `_HoverItem` 轻量交互组件
- 类型: `StatefulWidget`（仅存 `_isHovered`、`_isPressed` 两个 bool）
- 无动画控制器，仅通过 `setState()` 切换 `Container` color
- 参数:
  - `child`: 子组件
  - `onTap`: 点击回调
  - `hoverColor`: 悬停背景色（默认 `Colors.white10`）
  - `pressColor`: 按下背景色（默认 `Colors.white24`）
  - `useTranslucent`: 是否启用 `HitTestBehavior.translucent`（标题栏按钮用）
- 实现: `MouseRegion`（enter/exit）+ `GestureDetector`（tapDown/Up/Cancel）

### 4. 修改 `_buildMoreMenuItem`
- `GestureDetector` → `_HoverItem`
- padding: `vertical: 12`（原 10）
- 文字: `Colors.white`（原 `Colors.yellow`）, `fontSize: 14`

### 5. 修改 `_TitleBarButton`
- `GestureDetector` → `_HoverItem(useTranslucent: true)`
- 尺寸不变（44×44）

### 6. 修改 `_TitleBarCloseButton`
- `GestureDetector` → `_HoverItem(useTranslucent: true, hoverColor: red30, pressColor: red)`
- 悬停变红半透明，按下深红

## 性能影响
| 组件 | 数量 | 额外开销 |
|------|------|----------|
| `_HoverItem` | 13 个 | 每个 ≈ 2 个 bool + MouseRegion 注册 |
| `setState` | 悬停/点击时 | 仅重绘单个按钮子树，无级联 |
| 动画控制器 | 0 | 无 |
| Material/InkWell | 0 | 无 |

总计额外内存 < 1KB，零 CPU 持续开销。
