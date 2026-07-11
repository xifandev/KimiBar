# KimiCodeBar 交互规范

## 可点击元素反馈规范

所有可点击的 UI 元素必须同时满足以下两条反馈规则，以保证 macOS 菜单栏应用的操作体验一致、清晰：

1. **鼠标悬停时显示手型光标（pointingHand）**
   - 使用自定义 `.cursor(.pointingHand)` 扩展实现。
   - 系统原生按钮（如 `.borderedProminent`）默认不会变成手型光标，仍需显式添加。

2. **鼠标悬停时提供高亮反馈**
   - 必须改变背景色或前景色，让用户明确感知到当前元素可点击。
   - 推荐做法：背景从 `Color.white.opacity(0.08)` 提升到 `Color.white.opacity(0.14)`，前景从 `.kimiTextSecondary` 提升到 `.kimiTextPrimary`。
   - 使用 `@State private var isHoveredXXX` 配合 `.onHover { isHoveredXXX = $0 }` 实现。

## 当前已应用该规范的位置

- `ActionButton`：面板底部四个操作按钮。
- `CommunityButton`：面板右上角「社区版」GitHub 链接按钮。
- `LinkRow`：通用链接行组件。
- `SettingsView` 关闭按钮：设置气泡右上角圆形 × 按钮。
- `SettingsView` 「去控制台获取」链接按钮。
- `SettingsView` 「修改 / 保存 / 完成」按钮。
- `UpdateAlertView` 「稍后再说 / 安装更新」按钮。
- 版本卡片中的「检查更新」按钮。
- `ErrorMessageView` 错误信息复制按钮。

## 新增可点击元素时的 checklist

- [ ] 是否为该元素添加 `.cursor(.pointingHand)`？
- [ ] 是否为该元素添加 `@State isHovered` 状态？
- [ ] 是否在 `.onHover` 中改变背景/前景色，产生明显的高亮反馈？
- [ ] 禁用状态下是否移除了手型光标并降低视觉权重？

## 相关实现文件

- `KimiBar/KimiBarApp.swift`：主面板、设置气泡、更新弹窗等 UI 组件。
