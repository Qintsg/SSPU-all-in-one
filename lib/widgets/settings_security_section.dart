/*
 * 设置页安全分区组件 — 密码保护与数据管理
 * @Project : SSPU-all-in-one
 * @File : settings_security_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../theme/fluent_tokens.dart';

/// 安全设置分区。
class SettingsSecuritySection extends StatelessWidget {
  /// 是否已启用密码保护。
  final bool isPasswordEnabled;

  /// 开关密码保护。
  final ValueChanged<bool> onPasswordProtectionChanged;

  /// 修改密码回调。
  final VoidCallback onChangePassword;

  /// 立即上锁回调。
  final VoidCallback? onLock;

  /// 清理消息缓存回调。
  final VoidCallback onClearMessageCache;

  /// 清除所有数据回调。
  final VoidCallback onClearAllData;

  const SettingsSecuritySection({
    super.key,
    required this.isPasswordEnabled,
    required this.onPasswordProtectionChanged,
    required this.onChangePassword,
    required this.onLock,
    required this.onClearMessageCache,
    required this.onClearAllData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            Row(
              children: [
                const Icon(FluentIcons.lock, size: 20),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '密码保护',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        isPasswordEnabled
                            ? '已开启 — 重新打开应用时需要输入密码'
                            : '未开启 — 任何人可直接进入应用',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                ),
                ToggleSwitch(
                  checked: isPasswordEnabled,
                  onChanged: onPasswordProtectionChanged,
                ),
              ],
            ),
            if (isPasswordEnabled) ...[
              const SizedBox(height: FluentSpacing.m),
              Row(
                children: [
                  Button(
                    onPressed: onChangePassword,
                    child: const Text('修改密码'),
                  ),
                  const SizedBox(width: FluentSpacing.m),
                  FilledButton(
                    onPressed: onLock,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.lock, size: 14),
                        SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
                        Text('立即上锁'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: FluentSpacing.xl),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            Text('数据管理', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '清理信息中心缓存的消息，不影响登录信息和设置',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            Button(
              onPressed: onClearMessageCache,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.broom, size: 14),
                  SizedBox(width: 6),
                  Text('清理信息中心缓存'),
                ],
              ),
            ),
            const SizedBox(height: FluentSpacing.l),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            Text(
              '清除所有本地数据（包括登录信息、设置、缓存等），应用将退出',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            Button(
              onPressed: onClearAllData,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14),
                  SizedBox(width: 6),
                  Text('清除所有数据'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
