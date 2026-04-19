/*
 * 快速跳转 — 常用校园链接与服务的快捷入口
 * @Project : SSPU-all-in-one
 * @File : quick_links_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/fluent_tokens.dart';
import '../widgets/responsive_layout.dart';

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

    return ResponsiveBuilder(
      builder: (context, deviceType, constraints) {
        final tileWidth = switch (deviceType) {
          DeviceType.phone => 110.0,
          DeviceType.tablet => 130.0,
          DeviceType.desktop => 140.0,
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
        // 常用链接组
        Text('校园服务', style: theme.typography.bodyStrong),
        const SizedBox(height: FluentSpacing.s),
        Wrap(
          spacing: FluentSpacing.m,
          runSpacing: FluentSpacing.m,
          children: [
            _LinkTile(
              icon: FluentIcons.globe,
              label: '学校官网',
              color: Colors.blue,
              url: 'https://www.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '教务系统',
              color: Colors.teal,
              url: 'https://jwxt.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.library,
              label: '图书馆',
              color: Colors.orange,
              url: 'https://library.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.mail,
              label: '校园邮箱',
              color: Colors.purple,
              url: 'https://mail.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.open_file,
              label: '信息公开网',
              color: Colors.magenta,
              url: 'https://xxgk.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.contact,
              label: 'OA办公',
              color: Colors.blue,
              url: 'https://oa.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.running,
              label: '体育综合查询',
              color: Colors.green,
              url: 'https://tygl.sspu.edu.cn/sportscore/',
              onTap: _openUrl,
              width: tileWidth,
            ),
          ],
        ),

        const SizedBox(height: FluentSpacing.l),

        // 职能部门链接
        Text('职能部门', style: theme.typography.bodyStrong),
        const SizedBox(height: FluentSpacing.s),
        Wrap(
          spacing: FluentSpacing.m,
          runSpacing: FluentSpacing.m,
          children: [
            _LinkTile(
              icon: FluentIcons.education,
              label: '教务处',
              color: Colors.teal,
              url: 'https://jwc.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.settings,
              label: '信息技术中心',
              color: Colors.blue,
              url: 'https://itc.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.globe,
              label: '体育部',
              color: Colors.green,
              url: 'https://tyb.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.lock,
              label: '保卫处',
              color: Colors.red,
              url: 'https://bwc.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.home,
              label: '校区建设办',
              color: Colors.orange,
              url: 'https://xqjsb.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.news,
              label: '新闻网',
              color: Colors.purple,
              url: 'https://news.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.mail,
              label: '学生处',
              color: Colors.magenta,
              url: 'https://xsc.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
          ],
        ),

        const SizedBox(height: FluentSpacing.l),

        // 教学单位链接
        Text('教学单位', style: theme.typography.bodyStrong),
        const SizedBox(height: FluentSpacing.s),
        Wrap(
          spacing: FluentSpacing.m,
          runSpacing: FluentSpacing.m,
          children: [
            _LinkTile(
              icon: FluentIcons.settings,
              label: '计信学院',
              color: Colors.blue,
              url: 'https://jxxy.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.settings,
              label: '智控学院',
              color: Colors.teal,
              url: 'https://imce.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.globe,
              label: '资环学院',
              color: Colors.green,
              url: 'https://zihuan.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.settings,
              label: '能材学院',
              color: Colors.orange,
              url: 'https://sem.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.settings,
              label: '集成电路学院',
              color: Colors.purple,
              url: 'https://sic.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.settings,
              label: '智医学院',
              color: Colors.red,
              url: 'https://imhe.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.database,
              label: '经管学院',
              color: Colors.magenta,
              url: 'https://jjglxy.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.read,
              label: '语文学院',
              color: Colors.blue,
              url: 'https://wywh.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '数统学院',
              color: Colors.teal,
              url: 'https://sltj.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.video,
              label: '艺设学院',
              color: Colors.purple,
              url: 'https://design.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '职师学院',
              color: Colors.green,
              url: 'https://stes.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '职技学院',
              color: Colors.orange,
              url: 'https://cive.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.library,
              label: '马学院',
              color: Colors.red,
              url: 'https://mkszyxy.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '继教学院',
              color: Colors.magenta,
              url: 'https://adult.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.video,
              label: '艺教中心',
              color: Colors.blue,
              url: 'https://education.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.globe,
              label: '国教中心',
              color: Colors.teal,
              url: 'https://sie.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.settings,
              label: '创创中心',
              color: Colors.green,
              url: 'https://cxcy.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.education,
              label: '研究生处',
              color: Colors.orange,
              url: 'https://yjs.sspu.edu.cn',
              onTap: _openUrl,
              width: tileWidth,
            ),
          ],
        ),

        const SizedBox(height: FluentSpacing.l),

        Text('学习资源', style: theme.typography.bodyStrong),
        const SizedBox(height: FluentSpacing.s),
        Wrap(
          spacing: FluentSpacing.m,
          runSpacing: FluentSpacing.m,
          children: [
            _LinkTile(
              icon: FluentIcons.video,
              label: '网络课程',
              color: Colors.red,
              url: 'https://www.icourse163.org',
              onTap: _openUrl,
              width: tileWidth,
            ),
            _LinkTile(
              icon: FluentIcons.database,
              label: '知网',
              color: Colors.magenta,
              url: 'https://www.cnki.net',
              onTap: _openUrl,
              width: tileWidth,
            ),
          ],
        ),

        const SizedBox(height: FluentSpacing.l),

        // 提示
        const InfoBar(
          title: Text('提示'),
          content: Text('点击卡片将在默认浏览器中打开对应网站。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ],
    );
      },
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
  /// 磁贴宽度（响应式调整）
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
