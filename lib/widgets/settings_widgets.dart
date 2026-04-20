/*
 * 设置页公用组件 — 间隔选择器、时间选择器、渠道开关行、导航标签
 * @Project : SSPU-all-in-one
 * @File : settings_widgets.dart
 * @Author : Qintsg
 * @Date : 2026-07-17
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 可选的自动刷新间隔（分钟 => 显示文本）
const Map<int, String> kIntervalOptions = {
  0: '关闭',
  15: '15 分钟',
  30: '30 分钟',
  60: '1 小时',
  120: '2 小时',
  360: '6 小时',
  720: '12 小时',
  1440: '24 小时',
};

/// 构建自动刷新间隔选择器
/// [currentValue] 当前间隔（分钟）
/// [enabled] 渠道是否启用（未启用时灰色不可点）
/// [onChanged] 选中新值后回调
Widget buildIntervalSelector({
  required BuildContext context,
  required int currentValue,
  required bool enabled,
  required Future<void> Function(int minutes) onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(left: 32, top: 6),
    child: Row(
      children: [
        Icon(
          FluentIcons.sync,
          size: 14,
          color: enabled
              ? FluentTheme.of(context).inactiveColor
              : FluentTheme.of(context).inactiveColor.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 8),
        Text(
          '自动刷新：',
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: enabled
                ? null
                : FluentTheme.of(context).inactiveColor.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 4),
        ComboBox<int>(
          value: kIntervalOptions.containsKey(currentValue) ? currentValue : 0,
          items: kIntervalOptions.entries
              .map(
                (entry) => ComboBoxItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
        ),
      ],
    ),
  );
}

/// 构建左侧垂直导航项目
/// [index] 当前导航项索引
/// [selectedIndex] 当前选中的索引
/// [icon] 导航图标
/// [label] 导航文本
/// [onTap] 点击回调
Widget buildSettingsNavItem({
  required BuildContext context,
  required int index,
  required int selectedIndex,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final isSelected = index == selectedIndex;
  final theme = FluentTheme.of(context);

  return HoverButton(
    onPressed: onTap,
    builder: (context, states) {
      final hovered = states.isHovered || states.isPressed;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.1)
              : hovered
              ? theme.inactiveColor.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // 选中指示条
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? theme.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(icon, size: 16, color: isSelected ? theme.accentColor : null),
            const SizedBox(width: 10),
            Text(
              label,
              style: isSelected
                  ? theme.typography.bodyStrong?.copyWith(
                      color: theme.accentColor,
                    )
                  : theme.typography.body,
            ),
          ],
        ),
      );
    },
  );
}

/// 构建时间选择器（小时 + 分钟 ComboBox）
/// [label] 标签（如"开始""结束"）
/// [hour] 当前小时（0–23）
/// [minute] 当前分钟（0/15/30/45）
/// [onChanged] 选中新值后回调
Widget buildTimePicker({
  required BuildContext context,
  required String label,
  required int hour,
  required int minute,
  required Future<void> Function(int h, int m) onChanged,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ', style: FluentTheme.of(context).typography.caption),
      ComboBox<int>(
        value: hour,
        items: List.generate(
          24,
          (h) => ComboBoxItem<int>(
            value: h,
            child: Text(h.toString().padLeft(2, '0')),
          ),
        ),
        onChanged: (h) {
          if (h != null) onChanged(h, minute);
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(':', style: FluentTheme.of(context).typography.bodyStrong),
      ),
      ComboBox<int>(
        value: [0, 15, 30, 45].contains(minute) ? minute : 0,
        items: const [
          ComboBoxItem(value: 0, child: Text('00')),
          ComboBoxItem(value: 15, child: Text('15')),
          ComboBoxItem(value: 30, child: Text('30')),
          ComboBoxItem(value: 45, child: Text('45')),
        ],
        onChanged: (m) {
          if (m != null) onChanged(hour, m);
        },
      ),
    ],
  );
}

/// 构建信息渠道开关行
/// [icon] 图标
/// [title] 渠道名称
/// [subtitle] 渠道描述
/// [value] 是否启用
/// [onChanged] 切换回调
Widget buildChannelToggle({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 2),
            Text(subtitle, style: FluentTheme.of(context).typography.caption),
          ],
        ),
      ),
      ToggleSwitch(checked: value, onChanged: onChanged),
    ],
  );
}

/// 构建设置分区导航栏按钮
/// [index] 分区索引
/// [selectedIndex] 当前选中索引
/// [icon] 图标
/// [label] 显示文本
/// [onTap] 点击回调
Widget buildNavTab({
  required BuildContext context,
  required int index,
  required int selectedIndex,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final isSelected = selectedIndex == index;
  final theme = FluentTheme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Button(
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        backgroundColor: WidgetStatePropertyAll(
          isSelected
              ? theme.accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? theme.accentColor : null),
          const SizedBox(width: 6),
          Text(
            label,
            style: isSelected
                ? theme.typography.bodyStrong?.copyWith(
                    color: theme.accentColor,
                  )
                : theme.typography.body,
          ),
        ],
      ),
    ),
  );
}
