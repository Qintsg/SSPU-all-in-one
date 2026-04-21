/*
 * 主页 — 应用首屏，展示欢迎信息与核心功能入口
 * @Project : SSPU-all-in-one
 * @File : home_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/message_item.dart';
import '../services/message_state_service.dart';
import '../theme/fluent_tokens.dart';
import '../utils/webview_env.dart';
import '../widgets/responsive_layout.dart';
import 'webview_page.dart';

/// 主页
/// 展示校园信息摘要、快捷入口、最新消息等内容
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 最新消息列表（最多 5 条）
  List<MessageItem> _latestMessages = [];

  @override
  void initState() {
    super.initState();
    _loadLatestMessages();
  }

  /// 从本地存储加载消息并取前 5 条
  Future<void> _loadLatestMessages() async {
    final all = await MessageStateService.instance.loadMessages();
    // 按日期降序排列，取前 5 条
    all.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() => _latestMessages = all.take(5).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveBuilder(
      builder: (context, deviceType, constraints) {
        // 根据设备类型调整页面边距与磁贴尺寸
        final pagePadding = switch (deviceType) {
          DeviceType.phone => FluentSpacing.m,
          DeviceType.tablet => FluentSpacing.xl,
          DeviceType.desktop => FluentSpacing.xxl,
        };
        final tileWidth = switch (deviceType) {
          DeviceType.phone => 110.0,
          DeviceType.tablet => 130.0,
          DeviceType.desktop => 140.0,
        };

        return ScaffoldPage.scrollable(
          header: const PageHeader(title: Text('主页')),
          padding: EdgeInsets.all(pagePadding),
          children: [
            // 欢迎卡片
            Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                // 根据主题亮暗自适应背景色
                                color: isDark
                                    ? FluentDarkColors.backgroundSecondary
                                    : FluentLightColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(
                                  FluentRadius.xxLarge,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 80,
                                height: 80,
                              ),
                            ),
                            const SizedBox(width: FluentSpacing.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '欢迎使用 SSPU All-in-One',
                                    style: theme.typography.subtitle,
                                  ),
                                  const SizedBox(height: FluentSpacing.s),
                                  Text(
                                    '上海第二工业大学校园综合服务应用',
                                    style: theme.typography.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(
                  duration: FluentDuration.slow,
                  curve: FluentEasing.decelerate,
                )
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: FluentSpacing.l),
            Text('快捷功能', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.s),
            Wrap(
                  spacing: FluentSpacing.m,
                  runSpacing: FluentSpacing.m,
                  children: [
                    _FeatureTile(
                      icon: FluentIcons.education,
                      label: '课表查询',
                      color: Colors.blue,
                      width: tileWidth,
                    ),
                    _FeatureTile(
                      icon: FluentIcons.certificate,
                      label: '成绩查询',
                      color: Colors.teal,
                      width: tileWidth,
                    ),
                    _FeatureTile(
                      icon: FluentIcons.calendar,
                      label: '考试安排',
                      color: Colors.orange,
                      width: tileWidth,
                    ),
                    _FeatureTile(
                      icon: FluentIcons.news,
                      label: '校园公告',
                      color: Colors.purple,
                      width: tileWidth,
                    ),
                  ],
                )
                .animate(delay: 100.ms)
                .fadeIn(
                  duration: FluentDuration.slow,
                  curve: FluentEasing.decelerate,
                )
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: FluentSpacing.l),

            // 最新消息
            Text('最新消息', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.s),
            Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FluentSpacing.l),
                    child: _latestMessages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FluentSpacing.xl,
                              ),
                              child: Text(
                                '暂无消息，开启信息渠道并等待自动刷新后将在此显示',
                                style: theme.typography.caption,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                int i = 0;
                                i < _latestMessages.length;
                                i++
                              ) ...[
                                if (i > 0) const Divider(),
                                _buildMessageItem(context, _latestMessages[i]),
                              ],
                            ],
                          ),
                  ),
                )
                .animate(delay: 200.ms)
                .fadeIn(
                  duration: FluentDuration.slow,
                  curve: FluentEasing.decelerate,
                )
                .slideY(begin: 0.05, end: 0),
          ],
        );
      },
    );
  }

  /// 构建单条消息项（点击跳转内嵌 WebView）
  Widget _buildMessageItem(BuildContext context, MessageItem msg) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: () {
        // 标记已读并跳转内嵌 WebView
        MessageStateService.instance.markAsRead(msg.id);
        Navigator.of(context).push(
          FluentPageRoute(
            builder: (_) => WebViewPage(
              url: msg.url,
              initialTitle: msg.title,
              webViewEnvironment: globalWebViewEnvironment,
            ),
          ),
        );
      },
      builder: (context, states) {
        final isHovered = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isHovered
                ? theme.resources.subtleFillColorSecondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.title, style: theme.typography.bodyStrong),
                    const SizedBox(height: 4),
                    Text(
                      '${msg.category.label} · ${msg.sourceName.label}',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
              Text(
                msg.date,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 功能快捷入口砖块
class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AccentColor color;

  /// 磁贴宽度（响应式调整）
  final double width;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.color,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return HoverButton(
      onPressed: () {},
      builder: (context, states) {
        final isHovered = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: width,
          padding: const EdgeInsets.all(FluentSpacing.l),
          decoration: BoxDecoration(
            color: isHovered
                ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                : isDark
                ? FluentDarkColors.hoverFill
                : Colors.white,
            borderRadius: BorderRadius.circular(FluentRadius.xLarge),
            border: Border.all(
              color: isHovered
                  ? color.withValues(alpha: 0.3)
                  : isDark
                  ? FluentDarkColors.borderSubtle
                  : FluentLightColors.borderSubtle,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: FluentSpacing.s),
              Text(
                label,
                style: theme.typography.body?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
