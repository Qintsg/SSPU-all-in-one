# 紧急上下文恢复点（代码拆分进行中）

## 当前精确状态
settings_page.dart 已完成：
- ✅ 添加 import password_dialogs + settings_widgets
- ✅ 删除 _intervalOptions 常量 + _buildIntervalSelector（约70行）
- ✅ 删除 3个密码对话框方法（约262行）
- 文件当前约740行

仍需在 settings_page.dart 完成：
1. **更新密码对话框调用点**（约L220-240区域，安全设置卡片内）：
   - `_showSetPasswordDialog()` → `showSetPasswordDialog(context).then((ok) { if (ok && mounted) { setState(() => _isPasswordEnabled = true); _showSuccessBar('密码已设置'); }})`
   - `_showRemovePasswordDialog()` → `showRemovePasswordDialog(context).then((ok) { if (ok && mounted) { setState(() => _isPasswordEnabled = false); _showSuccessBar('密码保护已移除'); }})`
   - `_showChangePasswordDialog()` → `showChangePasswordDialog(context).then((ok) { if (ok && mounted) _showSuccessBar('密码已修改'); })`

2. **更新导航栏调用点**（约L153-163区域）：
   - `_buildNavTab(0, FluentIcons.lock, '安全')` → `buildNavTab(context: context, index: 0, selectedIndex: _selectedTab, icon: FluentIcons.lock, label: '安全', onTap: () => setState(() => _selectedTab = 0))`
   - 同理更新其他3个 _buildNavTab 调用

3. **更新渠道开关调用点**（约L300-400区域，信息渠道卡片内）：
   - `_buildChannelToggle(icon:, title:, ...)` → `buildChannelToggle(context: context, icon:, title:, ...)`（4处）
   - `_buildIntervalSelector(currentValue:, ...)` → `buildIntervalSelector(context: context, currentValue:, ...)`（4处）

4. **更新时间选择器调用点**（约L530-570区域，消息推送卡片内）：
   - `_buildTimePicker(label:, ...)` → `buildTimePicker(context: context, label:, ...)`（2处）

5. **删除末尾已提取方法**（约L592-810）：
   - `_buildNavTab` 方法（约L592-636）
   - `_buildTimePicker` 方法（约L638-690）
   - `_buildChannelToggle` 方法（约L692-730）
   注意：保留 `_showChannelChangedTip` 方法（它未被提取）

## info_page.dart 修改计划
1. 添加 `import '../widgets/message_tile.dart';`
2. 在 _buildMessageList 中将 `_MessageTile(` → `MessageTile(`
3. 删除 _MessageTile 类（文件末尾约130行）

## 已创建的提取文件（已完成，不需修改）
- `lib/widgets/password_dialogs.dart` — showSetPasswordDialog, showRemovePasswordDialog, showChangePasswordDialog
- `lib/widgets/settings_widgets.dart` — kIntervalOptions, buildIntervalSelector, buildTimePicker, buildChannelToggle, buildNavTab
- `lib/widgets/message_tile.dart` — MessageTile 类

## 项目信息
- 路径: e:\Projects\Qintsg\SSPU-all-in-one
- 分支: develop
- Flutter 3.41.4, Dart 3.11.1, Windows
- fluent_ui ^4.11.1
- Dida365项目ID: 69e37a01e4b0028dfb42216d
- commit格式: type(scope): 中文摘要

## 验证+提交步骤
```
cd "e:\Projects\Qintsg\SSPU-all-in-one"
flutter analyze
flutter build windows
git add -A
git commit -m "refactor(frontend): 拆分 settings_page 和 info_page 公用组件到 widgets 目录"
```

## 后续任务
- 1.3 设置页左侧导航重构（6栏目+二级页面）
- 1.4 首页消息跳转（内嵌WebView，多平台）
- 2.1-6.2 完整任务队列见 .github/dida365-state.md
