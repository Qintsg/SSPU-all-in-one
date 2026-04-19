/*
 * 快速跳转 — 常用校园链接与服务的快捷入口
 * @Project : SSPU-all-in-one
 * @File : quick_links_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 快速跳转页面
/// 提供常用校园网站、服务平台的快捷跳转链接
class QuickLinksPage extends StatelessWidget {
  const QuickLinksPage({super.key});

  /// 打开外部链接
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('快速跳转')),
      children: [
        // 常用链接组
        Text('校园服务', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _LinkTile(
              icon: FluentIcons.globe,
              label: '学校官网',
              color: Colors.blue,
              url: 'https://www.sspu.edu.cn',
              onTap: _openUrl,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '教务系统',
              color: Colors.teal,
              url: 'https://jwxt.sspu.edu.cn',
              onTap: _openUrl,
            ),
            _LinkTile(
              icon: FluentIcons.library,
              label: '图书馆',
              color: Colors.orange,
              url: 'https://lib.sspu.edu.cn',
              onTap: _openUrl,
            ),
            _LinkTile(
              icon: FluentIcons.mail,
              label: '校园邮箱',
              color: Colors.purple,
              url: 'https://mail.sspu.edu.cn',
              onTap: _openUrl,
            ),
            _LinkTile(
              icon: FluentIcons.open_file,
              label: '信息公开网',
              color: Colors.magenta,
              url: 'https://xxgk.sspu.edu.cn',
              onTap: _openUrl,
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text('学习资源', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _LinkTile(
              icon: FluentIcons.video,
              label: '网络课程',
              color: Colors.red,
              url: 'https://www.icourse163.org',
              onTap: _openUrl,
            ),
            _LinkTile(
              icon: FluentIcons.database,
              label: '知网',
              color: Colors.magenta,
              url: 'https://www.cnki.net',
              onTap: _openUrl,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 提示
        const InfoBar(
          title: Text('提示'),
          content: Text('点击卡片将在默认浏览器中打开对应网站。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ],
    );
  }
}

/// 快捷链接砖块组件
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AccentColor color;
  final String url;
  final Future<void> Function(String) onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return HoverButton(
      onPressed: () => onTap(url),
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
