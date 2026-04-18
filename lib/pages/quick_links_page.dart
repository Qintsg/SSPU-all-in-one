/*
 * 快速跳转 — 常用校园链接与服务的快捷入口
 * @Project : SSPU-all-in-one
 * @File : quick_links_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 快速跳转占位页面
/// 后续将提供常用校园网站、服务平台的快捷跳转链接
class QuickLinksPage extends StatelessWidget {
  const QuickLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('快速跳转')),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '常用链接',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 12),
                const InfoBar(
                  title: Text('功能开发中'),
                  content: Text('常用校园网站与服务平台的快捷跳转功能正在开发中。'),
                  severity: InfoBarSeverity.info,
                  isLong: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
