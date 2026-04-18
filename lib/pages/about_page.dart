/*
 * 关于页面 — 展示软件信息、作者、许可证、开源项目列表
 * @Project : SSPU-all-in-one
 * @File : about_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

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
    name: 'WeWeRSS',
    description: '公众号/服务号文章获取思路参考',
    license: 'MIT',
    url: 'https://github.com/cooderl/wewe-rss',
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

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('关于')),
      children: [
        // 软件信息
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SSPU All-in-One',
                  style: typography.subtitle),
              const SizedBox(height: 4),
              Text('版本 0.0.1-alpha',
                  style: typography.caption),
              const SizedBox(height: 16),
              _buildInfoRow(context, '著作人', 'Qintsg'),
              const SizedBox(height: 8),
              _buildInfoRow(context, '许可证', 'MIT License'),
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
            _agreementText.trim(),
            style: FluentTheme.of(context).typography.body,
          ),
        ),
      ],
    );
  }
}

const String _agreementText = '''
SSPU All-in-One 使用协议

最后更新日期：2026年4月18日

请在使用本软件前仔细阅读以下条款。使用本软件即表示您已阅读并同意以下全部内容。

一、免责声明

1. 本软件（SSPU All-in-One）未获得上海第二工业大学（SSPU）、微信、微信读书及其关联方的任何官方授权、认可或背书。

2. 本软件与上海第二工业大学、腾讯公司及其旗下产品（包括但不限于微信、微信读书）不存在任何合作、代理或隶属关系。

3. 使用本软件所产生的一切后果（包括但不限于账号风险、数据丢失、隐私泄露、学业影响等）由用户自行承担，本软件的开发者不承担任何直接或间接责任。

4. 本软件不保证所提供信息的准确性、完整性和时效性。用户应自行核实相关信息的正确性。

二、知识产权

1. 本软件采用 MIT 许可证开源。

2. 本软件中涉及的第三方商标、名称、标识（包括但不限于"上海第二工业大学"、"微信"、"微信读书"等）均为其各自所有者的财产，本软件对其不主张任何权利。

三、使用限制

1. 用户不得利用本软件从事任何违反法律法规的活动。

2. 用户不得利用本软件对任何第三方服务进行恶意攻击、干扰或破坏。

四、协议变更

开发者保留随时修改本协议的权利。修改后的协议将在软件更新时生效。继续使用本软件即表示您接受修改后的协议。

五、其他

1. 本协议受中华人民共和国法律管辖。

2. 如本协议的任何条款被认定为无效或不可执行，其余条款仍然有效。
''';
