/*
 * 教务中心本专科教务摘要卡片 — 展示 EAMS 只读状态、课表、成绩、考试与培养计划概览
 * @Project : SSPU-all-in-one
 * @File : academic_eams_summary_card.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_page.dart';

/// 教务中心本专科教务摘要卡片。
class AcademicEamsSummaryCard extends StatelessWidget {
  /// 最近一次本专科教务查询结果。
  final AcademicEamsQueryResult? result;

  /// 当前是否正在读取本专科教务系统。
  final bool isLoading;

  /// 是否已开启自动刷新。
  final bool autoRefreshEnabled;

  /// 手动刷新回调。
  final VoidCallback onRefresh;

  /// 打开独立课程表页面回调。
  final VoidCallback onOpenCourseSchedule;

  const AcademicEamsSummaryCard({
    super.key,
    required this.result,
    required this.isLoading,
    required this.autoRefreshEnabled,
    required this.onRefresh,
    required this.onOpenCourseSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final snapshot = result?.snapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    FluentIcons.education,
                    color: theme.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本专科教务', style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '通过 OA 登录态只读读取 EAMS 个人信息、课表、成绩、考试和培养计划。',
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.l),
            if (isLoading) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  SizedBox(width: FluentSpacing.s),
                  Text('正在读取本专科教务摘要...'),
                ],
              ),
            ] else if (result == null) ...[
              Text(
                autoRefreshEnabled
                    ? '自动刷新已开启，等待下一次读取；也可点击右上角刷新。'
                    : '自动刷新未开启。点击右上角刷新图标可手动读取；本专科教务需要校园网或学校 VPN。',
              ),
            ] else if (result!.isSuccess && snapshot != null) ...[
              _AcademicEamsSnapshotView(
                snapshot: snapshot,
                status: result!.status,
                onOpenCourseSchedule: onOpenCourseSchedule,
              ),
            ] else ...[
              InfoBar(
                title: Text(result!.message),
                content: Text(result!.detail),
                severity: _academicEamsSeverity(result!.status),
                isLong: true,
              ),
            ],
            const SizedBox(height: FluentSpacing.m),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: FluentSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _academicEamsLastRefreshLabel(result),
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                  Tooltip(
                    message: '手动刷新本专科教务摘要',
                    child: IconButton(
                      key: const Key('academic-eams-refresh'),
                      icon: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.refresh, size: 14),
                      onPressed: isLoading ? null : onRefresh,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InfoBarSeverity _academicEamsSeverity(AcademicEamsQueryStatus status) {
    return switch (status) {
      AcademicEamsQueryStatus.success => InfoBarSeverity.success,
      AcademicEamsQueryStatus.partialSuccess => InfoBarSeverity.warning,
      AcademicEamsQueryStatus.missingOaAccount ||
      AcademicEamsQueryStatus.missingOaPassword ||
      AcademicEamsQueryStatus.campusNetworkUnavailable =>
        InfoBarSeverity.warning,
      AcademicEamsQueryStatus.oaLoginRequired ||
      AcademicEamsQueryStatus.systemUnavailable ||
      AcademicEamsQueryStatus.readOnlyEntryUnavailable ||
      AcademicEamsQueryStatus.queryFormUnavailable ||
      AcademicEamsQueryStatus.parseFailed ||
      AcademicEamsQueryStatus.networkError ||
      AcademicEamsQueryStatus.unexpectedError => InfoBarSeverity.error,
    };
  }

  String _academicEamsLastRefreshLabel(AcademicEamsQueryResult? result) {
    final checkedAt = result?.checkedAt;
    if (checkedAt == null) return '上次刷新：未刷新';
    return '上次刷新：${checkedAt.year.toString().padLeft(4, '0')}-'
        '${checkedAt.month.toString().padLeft(2, '0')}-'
        '${checkedAt.day.toString().padLeft(2, '0')} '
        '${checkedAt.hour.toString().padLeft(2, '0')}:'
        '${checkedAt.minute.toString().padLeft(2, '0')}';
  }
}

class _AcademicEamsSnapshotView extends StatelessWidget {
  const _AcademicEamsSnapshotView({
    required this.snapshot,
    required this.status,
    required this.onOpenCourseSchedule,
  });

  final AcademicEamsSnapshot snapshot;
  final AcademicEamsQueryStatus status;
  final VoidCallback onOpenCourseSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final profile = snapshot.profile;
    final courseCount = snapshot.courseTable?.entries.length ?? 0;
    final gradeCount =
        (snapshot.grades?.historyRecords.length ?? 0) +
        (snapshot.grades?.currentTermRecords.length ?? 0);
    final examCount = snapshot.exams?.records.length ?? 0;
    final completion = snapshot.programCompletion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile != null && profile.hasAnyValue)
          _AcademicProfileSummary(profile: profile),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          children: [
            _AcademicMetricPill(
              label: '课表',
              value: courseCount.toString(),
              suffix: '门',
            ),
            _AcademicMetricPill(
              label: '成绩',
              value: gradeCount.toString(),
              suffix: '条',
            ),
            _AcademicMetricPill(
              label: '考试',
              value: examCount.toString(),
              suffix: '场',
            ),
            _AcademicMetricPill(
              label: '培养计划',
              value: completion == null
                  ? '待补全'
                  : '${completion.completedCredits.toStringAsFixed(1)}/${(completion.completedCredits + completion.pendingCredits).toStringAsFixed(1)}',
              suffix: completion == null ? '' : '学分',
            ),
          ],
        ),
        const SizedBox(height: FluentSpacing.m),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          children: [
            _AcademicCapabilityTag(
              icon: FluentIcons.calendar,
              label: '独立课程表页',
              value: courseCount > 0 ? '已可用' : '可打开',
            ),
            _AcademicCapabilityTag(
              icon: FluentIcons.certificate,
              label: '历史成绩',
              value: gradeCount > 0 ? '已读取' : '待读取',
            ),
            _AcademicCapabilityTag(
              icon: FluentIcons.search,
              label: '开课检索',
              value: snapshot.hasCourseOfferingEntry ? '入口已识别' : '入口待确认',
            ),
            _AcademicCapabilityTag(
              icon: FluentIcons.home,
              label: '空闲教室',
              value: snapshot.hasFreeClassroomEntry ? '入口已识别' : '入口待确认',
            ),
          ],
        ),
        if (snapshot.warnings.isNotEmpty) ...[
          const SizedBox(height: FluentSpacing.m),
          InfoBar(
            title: Text(
              status == AcademicEamsQueryStatus.partialSuccess
                  ? '部分数据已降级展示'
                  : '只读入口状态',
            ),
            content: Text(snapshot.warnings.join('；')),
            severity: InfoBarSeverity.warning,
            isLong: true,
          ),
        ],
        const SizedBox(height: FluentSpacing.l),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          children: [
            FilledButton(
              key: const Key('open-course-schedule'),
              onPressed: onOpenCourseSchedule,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.calendar, size: 14),
                  SizedBox(width: 6),
                  Text('打开课程表页面'),
                ],
              ),
            ),
            if (completion != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FluentSpacing.m,
                  vertical: FluentSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: theme.resources.controlAltFillColorSecondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '已修 ${completion.completedCourseCount} 门，未修 ${completion.pendingCourseCount} 门',
                ),
              ),
          ],
        ),
        if (snapshot.courseTable != null &&
            snapshot.courseTable!.entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FluentSpacing.s),
            child: Text(
              '课表页会展示课程名称、时间、地点、教师和周次信息；当前摘要只保留统计与入口。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _AcademicProfileSummary extends StatelessWidget {
  const _AcademicProfileSummary({required this.profile});

  final AcademicEamsProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final items = <String>[
      if (profile.name != null && profile.name!.isNotEmpty)
        '姓名：${profile.name}',
      if (profile.studentId != null && profile.studentId!.isNotEmpty)
        '学号：${profile.studentId}',
      if (profile.department != null && profile.department!.isNotEmpty)
        '院系：${profile.department}',
      if (profile.major != null && profile.major!.isNotEmpty)
        '专业：${profile.major}',
      if (profile.className != null && profile.className!.isNotEmpty)
        '班级：${profile.className}',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: FluentSpacing.m),
      padding: const EdgeInsets.all(FluentSpacing.m),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.16)),
      ),
      child: Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.xs,
        children: items.map((item) => Text(item)).toList(),
      ),
    );
  }
}

class _AcademicMetricPill extends StatelessWidget {
  const _AcademicMetricPill({
    required this.label,
    required this.value,
    required this.suffix,
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FluentSpacing.m,
        vertical: FluentSpacing.s,
      ),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.16)),
      ),
      child: Text('$label $value$suffix'),
    );
  }
}

class _AcademicCapabilityTag extends StatelessWidget {
  const _AcademicCapabilityTag({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FluentSpacing.m,
        vertical: FluentSpacing.s,
      ),
      decoration: BoxDecoration(
        color: theme.resources.controlAltFillColorSecondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.resources.textFillColorSecondary),
          const SizedBox(width: 6),
          Text('$label：$value'),
        ],
      ),
    );
  }
}
