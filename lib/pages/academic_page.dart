/*
 * 教务中心 — 课程、成绩、考试等教务信息聚合
 * @Project : SSPU-all-in-one
 * @File : academic_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 教务中心页面
/// 提供课表查询、成绩查询、考试安排等功能入口
class AcademicPage extends StatelessWidget {
  const AcademicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('教务中心')),
      children: [
        // 功能卡片组
        _buildServiceCard(
          context,
          icon: FluentIcons.education,
          color: Colors.blue,
          title: '课表查询',
          description: '查看本学期课程表，支持按周次、课程名筛选',
          items: ['本周课程', '完整课表', '课程搜索'],
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          context,
          icon: FluentIcons.certificate,
          color: Colors.teal,
          title: '成绩查询',
          description: '查看历史成绩与绩点统计，支持按学期筛选',
          items: ['本学期成绩', '历史成绩', 'GPA 统计'],
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          context,
          icon: FluentIcons.calendar,
          color: Colors.orange,
          title: '考试安排',
          description: '查看即将到来的考试时间、地点、座位号',
          items: ['近期考试', '所有考试'],
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          context,
          icon: FluentIcons.feedback,
          color: Colors.purple,
          title: '教学评价',
          description: '在线完成教学评价，查看评价状态',
          items: ['待评价课程', '已完成评价'],
        ),

        const SizedBox(height: 16),

        // 开发状态提示
        const InfoBar(
          title: Text('功能开发中'),
          content: Text('教务接口尚未接入，以上内容为功能规划预览。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ],
    );
  }

  /// 构建单个服务功能卡片
  Widget _buildServiceCard(
    BuildContext context, {
    required IconData icon,
    required AccentColor color,
    required String title,
    required String description,
    required List<String> items,
  }) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.typography.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(FluentIcons.chevron_right, size: 12),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => Button(
                        child: Text(item),
                        onPressed: () {},
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
