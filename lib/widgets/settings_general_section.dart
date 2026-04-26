/*
 * 设置页常规分区组件 — 窗口行为与消息推送设置
 * @Project : SSPU-all-in-one
 * @File : settings_general_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../theme/fluent_tokens.dart';
import 'settings_widgets.dart';

/// 常规设置分区。
class SettingsGeneralSection extends StatelessWidget {
  /// 当前关闭行为。
  final String closeBehavior;

  /// 是否启用消息推送。
  final bool notificationEnabled;

  /// 是否启用勿扰。
  final bool dndEnabled;

  /// 勿扰开始时间。
  final int dndStartHour;
  final int dndStartMinute;

  /// 勿扰结束时间。
  final int dndEndHour;
  final int dndEndMinute;

  /// 关闭行为修改回调。
  final ValueChanged<String> onCloseBehaviorChanged;

  /// 消息推送开关回调。
  final ValueChanged<bool> onNotificationChanged;

  /// 勿扰开关回调。
  final ValueChanged<bool> onDndChanged;

  /// 勿扰开始时间修改回调。
  final Future<void> Function(int hour, int minute) onDndStartChanged;

  /// 勿扰结束时间修改回调。
  final Future<void> Function(int hour, int minute) onDndEndChanged;

  const SettingsGeneralSection({
    super.key,
    required this.closeBehavior,
    required this.notificationEnabled,
    required this.dndEnabled,
    required this.dndStartHour,
    required this.dndStartMinute,
    required this.dndEndHour,
    required this.dndEndMinute,
    required this.onCloseBehaviorChanged,
    required this.onNotificationChanged,
    required this.onDndChanged,
    required this.onDndStartChanged,
    required this.onDndEndChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWindowBehaviorSection(context),
        const SizedBox(height: FluentSpacing.l),
        _buildNotificationSection(context),
      ],
    );
  }

  Widget _buildWindowBehaviorSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('窗口行为', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            buildResponsiveSettingsRow(
              context: context,
              icon: FluentIcons.chrome_close,
              title: Text(
                '关闭按钮行为',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              subtitle: Text(
                '选择点击窗口关闭按钮时的操作',
                style: FluentTheme.of(context).typography.caption,
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: ComboBox<String>(
                  isExpanded: true,
                  value: closeBehavior,
                  items: const [
                    ComboBoxItem(value: 'ask', child: Text('每次询问')),
                    ComboBoxItem(value: 'minimize', child: Text('最小化到托盘')),
                    ComboBoxItem(value: 'exit', child: Text('直接退出')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onCloseBehaviorChanged(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    final theme = FluentTheme.of(context);
    final disabledColor = theme.inactiveColor.withValues(alpha: 0.4);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('消息推送', style: theme.typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            buildResponsiveSettingsRow(
              context: context,
              icon: FluentIcons.ringer,
              title: Text('启用消息推送', style: theme.typography.bodyStrong),
              subtitle: Text(
                '当自动刷新发现新消息时推送系统通知',
                style: theme.typography.caption,
              ),
              trailing: ToggleSwitch(
                checked: notificationEnabled,
                onChanged: onNotificationChanged,
              ),
            ),
            const SizedBox(height: FluentSpacing.l),
            buildResponsiveSettingsRow(
              context: context,
              icon: FluentIcons.ringer_off,
              iconColor: notificationEnabled ? null : disabledColor,
              title: Text(
                '勿扰时段',
                style: theme.typography.bodyStrong?.copyWith(
                  color: notificationEnabled ? null : disabledColor,
                ),
              ),
              subtitle: Text(
                '在指定时间段内不推送通知',
                style: theme.typography.caption?.copyWith(
                  color: notificationEnabled ? null : disabledColor,
                ),
              ),
              trailing: ToggleSwitch(
                checked: dndEnabled,
                onChanged: notificationEnabled ? onDndChanged : null,
              ),
            ),
            if (dndEnabled && notificationEnabled)
              Padding(
                padding: const EdgeInsets.only(
                  left: FluentSpacing.xxl,
                  top: FluentSpacing.m,
                ),
                child: Wrap(
                  spacing: FluentSpacing.s,
                  runSpacing: FluentSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    buildTimePicker(
                      context: context,
                      label: '开始',
                      hour: dndStartHour,
                      minute: dndStartMinute,
                      onChanged: onDndStartChanged,
                    ),
                    Text('—', style: theme.typography.bodyStrong),
                    buildTimePicker(
                      context: context,
                      label: '结束',
                      hour: dndEndHour,
                      minute: dndEndMinute,
                      onChanged: onDndEndChanged,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
