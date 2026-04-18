/*
 * 信息中心 — 校园通知、公众号推文、官网资讯聚合
 * @Project : SSPU-all-in-one
 * @File : info_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 信息中心页面
/// 聚合各官网、微信公众号等渠道的校园资讯
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('信息中心')),
      children: [
        // 资讯渠道列表
        Text('资讯渠道', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _buildChannelTile(
                context,
                icon: FluentIcons.globe,
                color: Colors.blue,
                title: '学校官网通知',
                subtitle: '上海第二工业大学官方网站公告与新闻',
              ),
              const Divider(),
              _buildChannelTile(
                context,
                icon: FluentIcons.chat,
                color: Colors.green,
                title: '微信公众号',
                subtitle: '校园官方微信公众号推文聚合',
              ),
              const Divider(),
              _buildChannelTile(
                context,
                icon: FluentIcons.education,
                color: Colors.orange,
                title: '教务通知',
                subtitle: '教务处发布的考试、选课、教学安排等通知',
              ),
              const Divider(),
              _buildChannelTile(
                context,
                icon: FluentIcons.library,
                color: Colors.purple,
                title: '图书馆通知',
                subtitle: '图书馆开放时间、讲座、新书推荐',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 最新资讯占位
        Text('最新资讯', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNewsItem(
                  context,
                  source: '官网',
                  title: '暂无最新资讯',
                  summary: '资讯渠道尚未接入，接入后将自动拉取最新内容。',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 开发状态提示
        const InfoBar(
          title: Text('功能开发中'),
          content: Text('资讯渠道数据源正在接入，以上内容为功能规划预览。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ],
    );
  }

  /// 构建资讯渠道列表项
  Widget _buildChannelTile(
    BuildContext context, {
    required IconData icon,
    required AccentColor color,
    required String title,
    required String subtitle,
  }) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return HoverButton(
      onPressed: () {},
      builder: (context, states) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.typography.body),
                    Text(
                      subtitle,
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(FluentIcons.chevron_right, size: 12),
            ],
          ),
        );
      },
    );
  }

  /// 构建单条资讯项
  Widget _buildNewsItem(
    BuildContext context, {
    required String source,
    required String title,
    required String summary,
  }) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.typography.bodyStrong),
              ),
              Text(
                source,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(summary, style: theme.typography.body),
        ],
      ),
    );
  }
}
