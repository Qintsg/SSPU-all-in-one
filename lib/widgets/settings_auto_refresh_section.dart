/*
 * 设置页自动刷新分区组件 — 校园网检测频率与刷新设置快捷入口
 * @Project : SSPU-all-in-one
 * @File : settings_auto_refresh_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../theme/fluent_tokens.dart';
import 'settings_widgets.dart';

/// 设置页自动刷新设置分区。
class SettingsAutoRefreshSection extends StatelessWidget {
  /// 校园网 / VPN 状态检测间隔，单位分钟。
  final int campusNetworkDetectionIntervalMinutes;

  /// 校园网 / VPN 状态检测间隔修改回调。
  final Future<void> Function(int minutes)
  onCampusNetworkDetectionIntervalChanged;

  /// 跳转职能部门自动刷新设置。
  final VoidCallback onOpenDepartmentRefreshSettings;

  /// 跳转教学单位自动刷新设置。
  final VoidCallback onOpenTeachingRefreshSettings;

  /// 跳转微信推文自动刷新设置。
  final VoidCallback onOpenWechatRefreshSettings;

  const SettingsAutoRefreshSection({
    super.key,
    required this.campusNetworkDetectionIntervalMinutes,
    required this.onCampusNetworkDetectionIntervalChanged,
    required this.onOpenDepartmentRefreshSettings,
    required this.onOpenTeachingRefreshSettings,
    required this.onOpenWechatRefreshSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCampusNetworkIntervalCard(context),
        const SizedBox(height: FluentSpacing.l),
        _buildRefreshShortcutCard(context),
      ],
    );
  }

  Widget _buildCampusNetworkIntervalCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自动刷新设置', style: theme.typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            buildResponsiveSettingsRow(
              context: context,
              icon: FluentIcons.plug_connected,
              title: Text('校园网 / VPN 状态检测', style: theme.typography.bodyStrong),
              subtitle: Text(
                '控制导航栏状态徽标的自动检测频率；关闭后仍可点击徽标手动检测',
                style: theme.typography.caption,
              ),
              trailing: _buildIntervalComboBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshShortcutCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('消息自动刷新快捷入口', style: theme.typography.subtitle),
            const SizedBox(height: FluentSpacing.s),
            Text(
              '以下入口会跳转到对应分区顶部的自动刷新设置面板。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: FluentSpacing.l),
            _buildShortcutRow(
              context: context,
              icon: FluentIcons.education,
              title: '职能部门',
              description: '配置职能部门官网消息的自动刷新频率和抓取条数',
              onPressed: onOpenDepartmentRefreshSettings,
            ),
            const SizedBox(height: FluentSpacing.m),
            _buildShortcutRow(
              context: context,
              icon: FluentIcons.library,
              title: '教学单位',
              description: '配置学院、中心等教学单位消息的自动刷新频率和抓取条数',
              onPressed: onOpenTeachingRefreshSettings,
            ),
            const SizedBox(height: FluentSpacing.m),
            _buildShortcutRow(
              context: context,
              icon: FluentIcons.chat,
              title: '微信推文',
              description: '配置公众号平台推文的自动刷新频率和抓取条数',
              onPressed: onOpenWechatRefreshSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalComboBox() {
    final selectedValue =
        kIntervalOptions.containsKey(campusNetworkDetectionIntervalMinutes)
        ? campusNetworkDetectionIntervalMinutes
        : 15;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: kIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onCampusNetworkDetectionIntervalChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildShortcutRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: icon,
      title: Text(title, style: theme.typography.bodyStrong),
      subtitle: Text(description, style: theme.typography.caption),
      trailing: Button(onPressed: onPressed, child: const Text('前往设置')),
    );
  }
}
