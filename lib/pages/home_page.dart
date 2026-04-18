/*
 * 主页 — 应用首屏，展示欢迎信息与核心功能入口
 * @Project : SSPU-all-in-one
 * @File : home_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 主页占位页面
/// 后续将展示校园信息摘要、快捷入口等内容
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('主页')),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '欢迎使用 SSPU All-in-One',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Text(
                  '上海第二工业大学校园综合服务应用',
                  style: FluentTheme.of(context).typography.bodyLarge,
                ),
                const SizedBox(height: 20),
                // 功能概览卡片区域（占位）
                const InfoBar(
                  title: Text('功能开发中'),
                  content: Text('主页内容正在规划中，敬请期待。'),
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
