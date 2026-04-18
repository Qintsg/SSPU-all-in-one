/*
 * 教务中心 — 课程、成绩、考试等教务信息聚合
 * @Project : SSPU-all-in-one
 * @File : academic_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 教务中心占位页面
/// 后续将接入课表查询、成绩查询、考试安排等功能
class AcademicPage extends StatelessWidget {
  const AcademicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('教务中心')),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '教务服务',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 12),
                const InfoBar(
                  title: Text('功能开发中'),
                  content: Text('课表查询、成绩查询、考试安排等功能正在开发中。'),
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
