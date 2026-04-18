/*
 * 主页 — 应用首屏，展示欢迎信息与核心功能入口
 * @Project : SSPU-all-in-one
 * @File : home_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 主页
/// 展示校园信息摘要、快捷入口、公告等内容
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('主页')),
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
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '欢迎使用 SSPU All-in-One',
                            style: theme.typography.subtitle,
                          ),
                          const SizedBox(height: 8),
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
        ),

        const SizedBox(height: 16),

        // 功能快捷入口区域
        Text('快捷功能', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FeatureTile(
              icon: FluentIcons.education,
              label: '课表查询',
              color: Colors.blue,
            ),
            _FeatureTile(
              icon: FluentIcons.certificate,
              label: '成绩查询',
              color: Colors.teal,
            ),
            _FeatureTile(
              icon: FluentIcons.calendar,
              label: '考试安排',
              color: Colors.orange,
            ),
            _FeatureTile(
              icon: FluentIcons.news,
              label: '校园公告',
              color: Colors.purple,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 校园公告占位
        Text('最新公告', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnnouncementItem(
                  context,
                  title: '欢迎使用 SSPU All-in-One',
                  date: '系统通知',
                  summary: '本应用旨在将教务查询、校园公告、常用链接等功能集成于一体，提供便捷的校园服务体验。',
                ),
                const Divider(),
                _buildAnnouncementItem(
                  context,
                  title: '功能持续开发中',
                  date: '开发日志',
                  summary: '教务中心、信息中心等核心功能正在开发，敬请期待。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建单条公告项
  Widget _buildAnnouncementItem(
    BuildContext context, {
    required String title,
    required String date,
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
                date,
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

/// 功能快捷入口砖块
class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AccentColor color;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.color,
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
          width: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered
                ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                : isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovered
                  ? color.withValues(alpha: 0.3)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
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
