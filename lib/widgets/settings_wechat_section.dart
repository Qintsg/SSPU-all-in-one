/*
 * 设置页微信分区组件 — 公众号平台认证、刷新设置与 SSPU 微信矩阵
 * @Project : SSPU-all-in-one
 * @File : settings_wechat_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/settings_wechat_controller.dart';
import '../theme/fluent_tokens.dart';
import '../utils/webview_env.dart';
import 'settings_widgets.dart';
import 'settings_wechat_auth_guide.dart';
import 'settings_wechat_matrix_card.dart';
import '../pages/wxmp_login_page.dart';

/// 微信推文设置分区。
class SettingsWechatSection extends StatefulWidget {
  const SettingsWechatSection({super.key});

  @override
  State<SettingsWechatSection> createState() => _SettingsWechatSectionState();
}

class _SettingsWechatSectionState extends State<SettingsWechatSection> {
  final SettingsWechatController _controller = SettingsWechatController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  Future<void> _showFeedback(SettingsWechatFeedback feedback) async {
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: Text(feedback.title),
        content: feedback.content == null ? null : Text(feedback.content!),
        severity: feedback.severity,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('无法打开链接'),
        content: Text(url),
        severity: InfoBarSeverity.warning,
      ),
    );
  }

  Future<void> _openWxmpLogin() async {
    final success = await Navigator.of(context).push<bool>(
      FluentPageRoute(
        builder: (_) =>
            WxmpLoginPage(webViewEnvironment: globalWebViewEnvironment),
      ),
    );
    if (success == true) {
      await _showFeedback(await _controller.handleLoginSuccess());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: ProgressRing());
        }

        final theme = FluentTheme.of(context);
        final disabledColor = theme.resources.textFillColorSecondary.withValues(
          alpha: 0.7,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('微信推文消息获取', style: theme.typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(FluentSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: FluentSpacing.s,
                      runSpacing: FluentSpacing.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('刷新设置', style: theme.typography.bodyStrong),
                        FilledButton(
                          onPressed: () async => _showFeedback(
                            await _controller.setWechatPageEnabled(true),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.check_mark, size: 14),
                              SizedBox(width: 6),
                              Text('一键全开'),
                            ],
                          ),
                        ),
                        Button(
                          onPressed: () async => _showFeedback(
                            await _controller.setWechatPageEnabled(false),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.blocked, size: 14),
                              SizedBox(width: 6),
                              Text('一键全关'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FluentSpacing.s),
                    Wrap(
                      spacing: FluentSpacing.l,
                      runSpacing: FluentSpacing.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        buildCountNumberBox(
                          context: context,
                          label: '手动刷新文章个数',
                          value: _controller.wechatManualFetchCount,
                          enabled: true,
                          onChanged: (value) =>
                              _controller.setManualFetchCount(value),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('启用自动刷新：', style: theme.typography.caption),
                            const SizedBox(width: FluentSpacing.xs),
                            ToggleSwitch(
                              checked: _controller.wechatAutoRefreshEnabled,
                              onChanged: (value) =>
                                  _controller.setAutoRefreshEnabled(value),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '自动刷新频率：',
                              style: theme.typography.caption?.copyWith(
                                color: _controller.wechatAutoRefreshEnabled
                                    ? null
                                    : disabledColor,
                              ),
                            ),
                            const SizedBox(width: FluentSpacing.xs),
                            ComboBox<int>(
                              value:
                                  kIntervalOptions.containsKey(
                                    _controller.wechatRefreshInterval,
                                  )
                                  ? _controller.wechatRefreshInterval
                                  : 120,
                              items: kIntervalOptions.entries
                                  .where((entry) => entry.key > 0)
                                  .map(
                                    (entry) => ComboBoxItem<int>(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _controller.wechatAutoRefreshEnabled
                                  ? (value) {
                                      if (value != null) {
                                        _controller.setRefreshInterval(value);
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ),
                        buildCountNumberBox(
                          context: context,
                          label: '自动刷新文章个数',
                          value: _controller.wechatAutoFetchCount,
                          enabled: _controller.wechatAutoRefreshEnabled,
                          onChanged: (value) =>
                              _controller.setAutoFetchCount(value),
                        ),
                      ],
                    ),
                    const SizedBox(height: FluentSpacing.s),
                    Text(
                      '注意：若频率过快，可能会触发微信公众平台的接口频率限制。',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FluentSpacing.l),
            SettingsWechatAuthGuide(
              onOpenOfficialSite: () =>
                  _openExternalUrl('https://mp.weixin.qq.com/'),
            ),
            const SizedBox(height: FluentSpacing.l),
            _buildAuthCard(theme),
            const SizedBox(height: FluentSpacing.l),
            SettingsWechatMatrixCard(
              authenticated: _controller.wxmpAuthenticated,
              batchFollowing: _controller.wxmpBatchFollowing,
              batchProgress: _controller.wxmpBatchProgress,
              mpNotificationEnabled: _controller.wxmpMpNotificationEnabled,
              followedMps: _controller.wxmpFollowedMps,
              followingAccountId: _controller.wxmpFollowingAccountId,
              onBatchFollow: () async =>
                  _showFeedback(await _controller.batchFollowSspuWxmp()),
              onFollowAccount: (account) async =>
                  _showFeedback(await _controller.followSspuAccount(account)),
              onToggleMp: (fakeid, enabled) =>
                  _controller.setMpNotificationEnabled(fakeid, enabled),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuthCard(FluentThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('公众号平台认证', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '通过公众号管理平台 (mp.weixin.qq.com) 获取推文，需拥有公众号（个人订阅号即可）',
              style: theme.typography.caption,
            ),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '高级配置已合并到认证配置中，扫码登录成功后会自动更新配置文件。'
              '用户配置与文章缓存统一保存在 ~/.sspu-all-in-one/。',
              style: theme.typography.caption,
            ),
            if (_controller.wxmpAuthStatus != null) ...[
              const SizedBox(height: FluentSpacing.xs),
              Text(
                _controller.wxmpAuthStatus!.message,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
            const SizedBox(height: FluentSpacing.s),
            SelectableText(
              _controller.wxmpConfigPath.isEmpty
                  ? '认证配置路径加载中...'
                  : _controller.wxmpConfigPath,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            if (_controller.stateFilePath.isNotEmpty) ...[
              const SizedBox(height: FluentSpacing.xxs),
              SelectableText(
                '状态与缓存：${_controller.stateFilePath}',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
            if (_controller.wxmpConfigMessage.isNotEmpty) ...[
              const SizedBox(height: FluentSpacing.xxs),
              Text(
                _controller.wxmpConfigMessage,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
            const SizedBox(height: FluentSpacing.m),
            Row(
              children: [
                Icon(
                  _controller.wxmpAuthenticated
                      ? FluentIcons.check_mark
                      : FluentIcons.warning,
                  size: 16,
                  color: _controller.wxmpAuthenticated
                      ? (isDark
                            ? FluentDarkColors.statusSuccess
                            : FluentLightColors.statusSuccess)
                      : (isDark
                            ? FluentDarkColors.statusWarning
                            : FluentLightColors.statusWarning),
                ),
                const SizedBox(width: FluentSpacing.s),
                Text(
                  _controller.wxmpAuthenticated ? '已认证' : '未认证',
                  style: theme.typography.body,
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.m),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _openWxmpLogin,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.q_r_code, size: 14),
                      SizedBox(width: 6),
                      Text('扫码登录'),
                    ],
                  ),
                ),
                if (_controller.wxmpAuthenticated)
                  Button(
                    onPressed: _controller.wxmpValidating
                        ? null
                        : () async =>
                              _showFeedback(await _controller.validateAuth()),
                    child: _controller.wxmpValidating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.shield, size: 14),
                              SizedBox(width: 6),
                              Text('校验有效性'),
                            ],
                          ),
                  ),
                Button(
                  onPressed: () async =>
                      _showFeedback(await _controller.openConfigDirectory()),
                  child: const Text('打开配置文件目录'),
                ),
                Button(
                  onPressed: () async =>
                      _showFeedback(
                        await _controller.openConfigFileWithVSCode(),
                      ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.open_in_new_window, size: 14),
                      SizedBox(width: 6),
                      Text('使用 Visual Studio Code 打开配置文件'),
                    ],
                  ),
                ),
                Button(
                  onPressed: () async =>
                      _showFeedback(await _controller.reloadConfigFile()),
                  child: const Text('重新加载配置'),
                ),
                if (_controller.wxmpAuthenticated)
                  Button(
                    onPressed: () async =>
                        _showFeedback(await _controller.clearAuth()),
                    child: const Text('清除认证'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
