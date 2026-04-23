/*
 * 快速跳转 — 从 YAML 配置读取常用校园链接与服务入口
 * @Project : SSPU-all-in-one
 * @File : quick_links_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/quick_links_config_service.dart';
import '../theme/fluent_tokens.dart';
import '../widgets/responsive_layout.dart';

/// 快速跳转页面
/// 通过仓库内 YAML 配置生成分组与链接，便于后续维护简称和新增站点。
class QuickLinksPage extends StatelessWidget {
  const QuickLinksPage({super.key});

  /// 打开外部链接。
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuickLinkGroupConfig>>(
      future: QuickLinksConfigService.instance.loadGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ScaffoldPage(
            header: PageHeader(title: Text('快速跳转')),
            content: Center(child: ProgressRing()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return ScaffoldPage(
            header: const PageHeader(title: Text('快速跳转')),
            content: Center(
              child: InfoBar(
                title: const Text('快捷跳转配置加载失败'),
                content: Text('${snapshot.error ?? '配置为空'}'),
                severity: InfoBarSeverity.error,
              ),
            ),
          );
        }

        return _QuickLinksContent(groups: snapshot.data!, onOpenUrl: _openUrl);
      },
    );
  }
}

/// 快捷跳转内容区域。
class _QuickLinksContent extends StatelessWidget {
  /// 从 YAML 解析出的分组。
  final List<QuickLinkGroupConfig> groups;

  /// 外部链接打开回调。
  final Future<void> Function(String url) onOpenUrl;

  const _QuickLinksContent({required this.groups, required this.onOpenUrl});

  static final List<AccentColor> _groupColors = [
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.magenta,
    Colors.red,
  ];

  static const Map<String, IconData> _iconByKey = {
    'globe': FluentIcons.globe,
    'education': FluentIcons.education,
    'library': FluentIcons.library,
    'mail': FluentIcons.mail,
    'office': FluentIcons.contact,
    'sports': FluentIcons.running,
    'settings': FluentIcons.settings,
    'security': FluentIcons.lock,
    'news': FluentIcons.news,
    'people': FluentIcons.people,
    'finance': FluentIcons.money,
    'home': FluentIcons.home,
    'video': FluentIcons.video,
    'database': FluentIcons.database,
  };

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ResponsiveBuilder(
      builder: (context, deviceType, constraints) {
        final tileWidth = switch (deviceType) {
          DeviceType.phone => 118.0,
          DeviceType.tablet => 140.0,
          DeviceType.desktop => 152.0,
        };
        final pagePadding = switch (deviceType) {
          DeviceType.phone => FluentSpacing.m,
          DeviceType.tablet => FluentSpacing.xl,
          DeviceType.desktop => FluentSpacing.xxl,
        };

        return ScaffoldPage.scrollable(
          header: const PageHeader(title: Text('快速跳转')),
          padding: EdgeInsets.all(pagePadding),
          children: [
            for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
              ..._buildGroup(
                context,
                theme,
                groups[groupIndex],
                groupIndex,
                tileWidth,
              ),
            const SizedBox(height: FluentSpacing.l),
            const InfoBar(
              title: Text('提示'),
              content: Text(
                '点击卡片将在默认浏览器中打开对应网站。快捷入口由 assets/config/quick_links.yaml 维护。',
              ),
              severity: InfoBarSeverity.info,
              isLong: true,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGroup(
    BuildContext context,
    FluentThemeData theme,
    QuickLinkGroupConfig group,
    int groupIndex,
    double tileWidth,
  ) {
    final groupColor = _groupColors[groupIndex % _groupColors.length];
    return [
      if (groupIndex > 0) const SizedBox(height: FluentSpacing.l),
      Text(group.category, style: theme.typography.bodyStrong),
      const SizedBox(height: FluentSpacing.s),
      Wrap(
            spacing: FluentSpacing.m,
            runSpacing: FluentSpacing.m,
            children: group.items.map((item) {
              return _LinkTile(
                icon: _resolveIcon(group.category, item),
                label: item.name,
                color: _resolveColor(group.category, item, groupColor),
                url: item.url,
                onTap: onOpenUrl,
                width: tileWidth,
              );
            }).toList(),
          )
          .animate(delay: Duration(milliseconds: groupIndex * 80))
          .fadeIn(duration: FluentDuration.slow, curve: FluentEasing.decelerate)
          .slideY(begin: 0.05, end: 0),
    ];
  }

  IconData _resolveIcon(String category, QuickLinkItemConfig item) {
    final customIcon = item.icon?.trim();
    if (customIcon != null && customIcon.isNotEmpty) {
      return _iconByKey[customIcon] ?? FluentIcons.link;
    }

    final searchableText = '${item.name} $category';
    if (searchableText.contains('邮箱')) return FluentIcons.mail;
    if (searchableText.contains('图书') || searchableText.contains('档案')) {
      return FluentIcons.library;
    }
    if (searchableText.contains('体育')) return FluentIcons.running;
    if (searchableText.contains('新闻') || searchableText.contains('宣传')) {
      return FluentIcons.news;
    }
    if (searchableText.contains('财务') || searchableText.contains('校园卡')) {
      return FluentIcons.money;
    }
    if (searchableText.contains('保卫') || searchableText.contains('纪委')) {
      return FluentIcons.lock;
    }
    if (searchableText.contains('国际') || searchableText.contains('留学生')) {
      return FluentIcons.globe;
    }
    if (searchableText.contains('学生') ||
        searchableText.contains('招生') ||
        searchableText.contains('就业') ||
        searchableText.contains('人事') ||
        searchableText.contains('人才') ||
        searchableText.contains('党') ||
        searchableText.contains('团') ||
        searchableText.contains('工会') ||
        searchableText.contains('妇委')) {
      return FluentIcons.people;
    }
    if (searchableText.contains('课程') ||
        searchableText.contains('教学') ||
        searchableText.contains('教务') ||
        searchableText.contains('学习') ||
        searchableText.contains('学院') ||
        searchableText.contains('研究生')) {
      return FluentIcons.education;
    }
    if (searchableText.contains('艺术')) return FluentIcons.video;
    if (searchableText.contains('OA') || searchableText.contains('办公')) {
      return FluentIcons.contact;
    }
    if (searchableText.contains('资产') ||
        searchableText.contains('工创') ||
        searchableText.contains('工厂') ||
        searchableText.contains('创新') ||
        searchableText.contains('信息技术')) {
      return FluentIcons.settings;
    }
    return FluentIcons.globe;
  }

  AccentColor _resolveColor(
    String category,
    QuickLinkItemConfig item,
    AccentColor fallback,
  ) {
    final searchableText = '${item.name} $category';
    if (searchableText.contains('财务') || searchableText.contains('保卫')) {
      return Colors.red;
    }
    if (searchableText.contains('国际') || searchableText.contains('留学生')) {
      return Colors.teal;
    }
    if (searchableText.contains('学习') || searchableText.contains('教学')) {
      return Colors.blue;
    }
    if (searchableText.contains('图书') || searchableText.contains('档案')) {
      return Colors.orange;
    }
    if (searchableText.contains('党') ||
        searchableText.contains('团') ||
        searchableText.contains('工会')) {
      return Colors.magenta;
    }
    return fallback;
  }
}

/// 快捷链接砖块组件。
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AccentColor color;
  final String url;
  final Future<void> Function(String) onTap;

  /// 磁贴宽度（响应式调整）。
  final double width;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
    required this.onTap,
    this.width = 140,
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
          width: width,
          constraints: const BoxConstraints(minHeight: 118),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: FluentSpacing.s),
              Text(
                label,
                style: theme.typography.body?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
