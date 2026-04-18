/*
 * 信息中心 — 校园通知、公众号推文、官网资讯聚合
 * @Project : SSPU-all-in-one
 * @File : info_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 信息中心占位页面
/// 后续将聚合各官网、微信公众号等渠道的校园资讯
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('信息中心')),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '校园资讯',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 12),
                const InfoBar(
                  title: Text('功能开发中'),
                  content: Text('校园通知、公众号推文、官网资讯聚合功能正在开发中。'),
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
