/*
 * 关于页面 — 展示软件信息、作者、许可证、开源项目列表
 * @Project : SSPU-all-in-one
 * @File : about_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/fluent_tokens.dart';
import 'agreement_page.dart';

/// 使用/参考的开源项目列表
/// 若后续用户没有明确说明，不得修改此内容
const List<_OpenSourceProject> _openSourceProjects = [
  _OpenSourceProject(
    name: 'Flutter',
    description: '跨平台 UI 框架',
    license: 'BSD-3-Clause',
    url: 'https://flutter.dev',
  ),
  _OpenSourceProject(
    name: 'fluent_ui',
    description: 'Fluent Design 组件库',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/fluent_ui',
  ),
  _OpenSourceProject(
    name: 'shared_preferences',
    description: '本地持久化存储',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/shared_preferences',
  ),
  _OpenSourceProject(
    name: 'crypto',
    description: '加密算法库',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/crypto',
  ),
  _OpenSourceProject(
    name: 'url_launcher',
    description: '打开外部链接',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/url_launcher',
  ),
  _OpenSourceProject(
    name: 'MiSans',
    description: '小米全新系统字体，数字等宽',
    license: 'MiSans EULA',
    url: 'https://hyperos.mi.com/font/zh',
  ),
  _OpenSourceProject(
    name: 'WeWeRSS',
    description: '公众号/服务号文章获取思路参考',
    license: 'MIT',
    url: 'https://github.com/cooderl/wewe-rss',
  ),
  _OpenSourceProject(
    name: 'window_manager',
    description: 'Flutter 桌面窗口管理',
    license: 'MIT',
    url: 'https://pub.dev/packages/window_manager',
  ),
  _OpenSourceProject(
    name: 'tray_manager',
    description: '系统托盘图标管理',
    license: 'MIT',
    url: 'https://pub.dev/packages/tray_manager',
  ),
  _OpenSourceProject(
    name: 'dio',
    description: '强大的 HTTP 客户端库',
    license: 'MIT',
    url: 'https://pub.dev/packages/dio',
  ),
  _OpenSourceProject(
    name: 'local_notifier',
    description: 'Windows 本地系统通知推送',
    license: 'MIT',
    url: 'https://pub.dev/packages/local_notifier',
  ),
  _OpenSourceProject(
    name: 'html',
    description: 'HTML 解析库',
    license: 'MIT',
    url: 'https://pub.dev/packages/html',
  ),
];

class _OpenSourceProject {
  final String name;
  final String description;
  final String license;
  final String url;

  const _OpenSourceProject({
    required this.name,
    required this.description,
    required this.license,
    required this.url,
  });
}

/// 关于页面
/// 若后续用户没有明确说明，不得修改此页面内容
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('关于')),
      children: [
        // 软件信息
        Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : FluentLightColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SSPU All-in-One', style: typography.subtitle),
                    const SizedBox(height: 4),
                    Text('版本 0.0.1-alpha', style: typography.caption),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, '著作人', 'Qintsg'),
                    const SizedBox(height: 8),
                    _buildInfoRow(context, '许可证', 'MIT License'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 操作按钮
        Card(
          child: Column(
            children: [
              _buildActionTile(
                context,
                icon: FluentIcons.open_source,
                title: 'GitHub 仓库',
                subtitle: 'Qintsg/SSPU-all-in-one',
                onTap: () => _openUrl(
                    'https://github.com/Qintsg/SSPU-all-in-one'),
              ),
              const Divider(),
              _buildActionTile(
                context,
                icon: FluentIcons.document_set,
                title: '使用协议',
                subtitle: '查看完整使用协议条款',
                onTap: () => Navigator.of(context).push(
                  FluentPageRoute(
                    builder: (_) => const _AgreementNavigationWrapper(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 开源项目列表
        Text('使用/参考的开源项目', style: typography.bodyStrong),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: _openSourceProjects.asMap().entries.map((entry) {
              final project = entry.value;
              final isLast = entry.key == _openSourceProjects.length - 1;
              return Column(
                children: [
                  _buildActionTile(
                    context,
                    icon: FluentIcons.code,
                    title: project.name,
                    subtitle: '${project.description} · ${project.license}',
                    onTap: () => _openUrl(project.url),
                  ),
                  if (!isLast) const Divider(),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final typography = FluentTheme.of(context).typography;
    return Row(
      children: [
        Text('$label：', style: typography.body),
        Text(value, style: typography.bodyStrong),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final typography = FluentTheme.of(context).typography;
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: typography.body),
                    Text(subtitle,
                        style: typography.caption?.copyWith(
                          color: FluentTheme.of(context)
                              .resources
                              .textFillColorSecondary,
                        )),
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
}

/// 使用协议导航包装器（从关于页导航进入时使用）
class _AgreementNavigationWrapper extends StatelessWidget {
  const _AgreementNavigationWrapper();

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('使用协议'),
        leading: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      children: [
        Card(
          child: SelectableText(
            kAgreementText.trim(),
            style: FluentTheme.of(context).typography.body,
          ),
        ),
      ],
    );
  }
}
