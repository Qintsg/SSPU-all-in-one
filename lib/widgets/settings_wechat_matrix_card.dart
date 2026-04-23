/*
 * 微信推文矩阵卡片组件 — SSPU 官方公众号展示与关注控制
 * @Project : SSPU-all-in-one
 * @File : settings_wechat_matrix_card.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../models/sspu_wechat_accounts.dart';
import '../theme/fluent_tokens.dart';
import '../utils/wechat_followed_account_matcher.dart';

/// SSPU 微信矩阵卡片。
class SettingsWechatMatrixCard extends StatelessWidget {
  /// 已认证状态。
  final bool authenticated;

  /// 当前是否正在批量关注。
  final bool batchFollowing;

  /// 批量关注进度文本。
  final String batchProgress;

  /// 单个公众号的通知开关。
  final Map<String, bool> mpNotificationEnabled;

  /// 已关注列表。
  final List<Map<String, String>> followedMps;

  /// 当前正在关注的微信号。
  final String followingAccountId;

  /// 一键全部关注回调。
  final VoidCallback onBatchFollow;

  /// 单个公众号关注回调。
  final ValueChanged<SspuWechatAccount> onFollowAccount;

  /// 单个公众号开关回调。
  final Future<void> Function(String fakeid, bool enabled) onToggleMp;

  const SettingsWechatMatrixCard({
    super.key,
    required this.authenticated,
    required this.batchFollowing,
    required this.batchProgress,
    required this.mpNotificationEnabled,
    required this.followedMps,
    required this.followingAccountId,
    required this.onBatchFollow,
    required this.onFollowAccount,
    required this.onToggleMp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final allAccountsFollowed = sspuWechatAccounts.every(
      (account) => findFollowedWechatAccount(account, followedMps) != null,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('SSPU 微信矩阵', style: theme.typography.bodyStrong),
                          const SizedBox(width: FluentSpacing.s),
                          Text(
                            '来源：校园+微信矩阵·共 ${sspuWechatAccounts.length} 个',
                            style: theme.typography.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: FluentSpacing.s),
                      Text(
                        '以下为上海第二工业大学官方认可的微信公众号',
                        style: theme.typography.caption,
                      ),
                      const SizedBox(height: FluentSpacing.s),
                      Text(
                        '已关注的公众号可在此直接控制是否获取推文；未关注项仅展示状态。',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                ),
                if (!allAccountsFollowed) ...[
                  const SizedBox(width: FluentSpacing.m),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: !authenticated || batchFollowing
                            ? null
                            : onBatchFollow,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (batchFollowing)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: ProgressRing(strokeWidth: 2),
                                ),
                              ),
                            const Text('一键全部关注'),
                          ],
                        ),
                      ),
                      if (batchFollowing && batchProgress.isNotEmpty) ...[
                        const SizedBox(height: FluentSpacing.xs),
                        SizedBox(
                          width: 220,
                          child: Text(
                            batchProgress,
                            style: theme.typography.caption,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: FluentSpacing.m),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth < 360
                    ? constraints.maxWidth
                    : 340.0;
                return Wrap(
                  spacing: FluentSpacing.m,
                  runSpacing: FluentSpacing.s,
                  children: sspuWechatAccounts.map((account) {
                    final followed = findFollowedWechatAccount(
                      account,
                      followedMps,
                    );
                    final fakeid = followed?['fakeid'] ?? '';
                    final enabled = fakeid.isEmpty
                        ? false
                        : (mpNotificationEnabled[fakeid] ?? true);
                    final following = followingAccountId == account.wxAccount;

                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.all(FluentSpacing.s),
                        decoration: BoxDecoration(
                          color: theme.inactiveColor.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                account.iconUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      FluentIcons.chat,
                                      size: 28,
                                      color: theme.accentColor,
                                    ),
                              ),
                            ),
                            const SizedBox(width: FluentSpacing.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: theme.typography.bodyStrong,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    account.wxAccount,
                                    style: theme.typography.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: FluentSpacing.s),
                            if (!authenticated)
                              Text(
                                '未认证',
                                style: theme.typography.caption?.copyWith(
                                  color: theme.resources.textFillColorSecondary,
                                ),
                              )
                            else if (followed == null)
                              Button(
                                onPressed: following
                                    ? null
                                    : () => onFollowAccount(account),
                                child: following
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: ProgressRing(strokeWidth: 2),
                                      )
                                    : const Text('关注'),
                              )
                            else
                              Tooltip(
                                message: '控制是否获取该公众号推文',
                                child: ToggleSwitch(
                                  checked: enabled,
                                  onChanged: (value) =>
                                      onToggleMp(fakeid, value),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
