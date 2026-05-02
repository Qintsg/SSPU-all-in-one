/*
 * 独立课程表页面 — 展示本专科教务系统只读课表数据
 * @Project : SSPU-all-in-one
 * @File : course_schedule_page.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../models/academic_eams.dart';
import '../services/academic_eams_service.dart';
import '../theme/fluent_tokens.dart';

/// 独立课程表页面。
class CourseSchedulePage extends StatefulWidget {
  /// 本专科教务只读服务，测试中可替换为 fake。
  final AcademicEamsClient? academicEamsService;

  /// 从教务中心摘要页带入的初始课表结果。
  final AcademicEamsQueryResult? initialResult;

  /// 测试专用：覆盖自动刷新开关。
  final bool? autoRefreshEnabledOverride;

  /// 测试专用：覆盖自动刷新间隔。
  final int? autoRefreshIntervalOverride;

  const CourseSchedulePage({
    super.key,
    this.academicEamsService,
    this.initialResult,
    this.autoRefreshEnabledOverride,
    this.autoRefreshIntervalOverride,
  });

  @override
  State<CourseSchedulePage> createState() => _CourseSchedulePageState();
}

class _CourseSchedulePageState extends State<CourseSchedulePage> {
  AcademicEamsQueryResult? _result;
  bool _isLoading = false;
  bool _autoRefreshEnabled = false;
  int _autoRefreshIntervalMinutes =
      AcademicEamsService.defaultAutoRefreshIntervalMinutes;
  Timer? _autoRefreshTimer;

  AcademicEamsClient get _academicEamsService {
    return widget.academicEamsService ?? AcademicEamsService.instance;
  }

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _loadAutoRefreshSettings();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAutoRefreshSettings() async {
    final service = widget.academicEamsService is AcademicEamsService
        ? widget.academicEamsService as AcademicEamsService
        : AcademicEamsService.instance;
    final enabled =
        widget.autoRefreshEnabledOverride ??
        await service.isAutoRefreshEnabled();
    final interval =
        widget.autoRefreshIntervalOverride ??
        await service.getAutoRefreshIntervalMinutes();
    if (!mounted) return;
    setState(() {
      _autoRefreshEnabled = enabled;
      _autoRefreshIntervalMinutes = interval;
    });
    _restartAutoRefreshTimer();
    if (enabled) unawaited(_loadCourseTable());
  }

  Future<void> _loadCourseTable() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final result = await _academicEamsService.fetchCourseTable();
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  void _restartAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    if (!_autoRefreshEnabled) return;
    final intervalMinutes = _autoRefreshIntervalMinutes;
    if (intervalMinutes <= 0) return;
    _autoRefreshTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _loadCourseTable(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final canPop = Navigator.of(context).canPop();
    final snapshot = _result?.snapshot;
    final courseTable = snapshot?.courseTable;

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('课程表'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canPop) ...[
              Button(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
              const SizedBox(width: FluentSpacing.s),
            ],
            FilledButton(
              key: const Key('course-schedule-refresh'),
              onPressed: _isLoading ? null : _loadCourseTable,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  else
                    const Icon(FluentIcons.refresh, size: 14),
                  const SizedBox(width: 6),
                  const Text('刷新课表'),
                ],
              ),
            ),
          ],
        ),
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('课程表说明', style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.s),
                Text(
                  _autoRefreshEnabled
                      ? '自动刷新已开启，每 $_autoRefreshIntervalMinutes 分钟更新一次；也可手动刷新。'
                      : '自动刷新未开启。点击“刷新课表”可手动读取；本专科教务需要校园网或学校 VPN。',
                ),
                const SizedBox(height: FluentSpacing.xs),
                Text(
                  '本页面只展示课程名称、时间、地点、教师和周次信息，不提供选课、退课或调课入口。',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        if (_isLoading && _result == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(FluentSpacing.xl),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  SizedBox(width: FluentSpacing.s),
                  Text('正在读取当前学期课表...'),
                ],
              ),
            ),
          )
        else if (_result == null)
          const InfoBar(
            title: Text('尚未读取课表'),
            content: Text('点击“刷新课表”即可按当前 OA 登录态只读获取本学期课表。'),
            severity: InfoBarSeverity.info,
            isLong: true,
          )
        else if (!_result!.isSuccess || courseTable == null)
          InfoBar(
            title: Text(_result!.message),
            content: Text(_result!.detail),
            severity: _severityOf(_result!.status),
            isLong: true,
          )
        else ...[
          _CourseScheduleSummaryCard(
            snapshot: snapshot!,
            checkedAt: _result!.checkedAt,
          ),
          const SizedBox(height: FluentSpacing.m),
          ..._buildWeekdaySections(courseTable),
        ],
      ],
    );
  }

  InfoBarSeverity _severityOf(AcademicEamsQueryStatus status) {
    return switch (status) {
      AcademicEamsQueryStatus.success => InfoBarSeverity.success,
      AcademicEamsQueryStatus.partialSuccess ||
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

  List<Widget> _buildWeekdaySections(AcademicCourseTableSnapshot courseTable) {
    final groupedEntries = <int, List<AcademicCourseTableEntry>>{};
    for (final entry in courseTable.entries) {
      groupedEntries.putIfAbsent(entry.weekday, () => []).add(entry);
    }

    final widgets = <Widget>[];
    for (final weekday in groupedEntries.keys.toList()..sort()) {
      final entries = groupedEntries[weekday]!
        ..sort((a, b) => a.startUnit.compareTo(b.startUnit));
      widgets.add(
        _CourseScheduleWeekdaySection(weekday: weekday, entries: entries),
      );
      widgets.add(const SizedBox(height: FluentSpacing.m));
    }
    if (widgets.isNotEmpty) widgets.removeLast();
    return widgets;
  }
}

class _CourseScheduleSummaryCard extends StatelessWidget {
  const _CourseScheduleSummaryCard({
    required this.snapshot,
    required this.checkedAt,
  });

  final AcademicEamsSnapshot snapshot;
  final DateTime checkedAt;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final profile = snapshot.profile;
    final courseTable = snapshot.courseTable!;
    final completion = snapshot.programCompletion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本学期概览', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.s),
            Wrap(
              spacing: FluentSpacing.s,
              runSpacing: FluentSpacing.s,
              children: [
                _CourseSummaryTag(
                  label: '学期',
                  value: courseTable.termName ?? '当前学期',
                ),
                _CourseSummaryTag(
                  label: '课程数',
                  value: '${courseTable.entries.length} 门',
                ),
                _CourseSummaryTag(
                  label: '刷新时间',
                  value:
                      '${checkedAt.hour.toString().padLeft(2, '0')}:${checkedAt.minute.toString().padLeft(2, '0')}',
                ),
                if (completion != null)
                  _CourseSummaryTag(
                    label: '培养计划',
                    value:
                        '${completion.completedCredits.toStringAsFixed(1)}/${(completion.completedCredits + completion.pendingCredits).toStringAsFixed(1)} 学分',
                  ),
              ],
            ),
            if (profile != null && profile.hasAnyValue) ...[
              const SizedBox(height: FluentSpacing.m),
              Text(
                [
                  if (profile.name != null && profile.name!.isNotEmpty)
                    '姓名：${profile.name}',
                  if (profile.department != null &&
                      profile.department!.isNotEmpty)
                    '院系：${profile.department}',
                  if (profile.major != null && profile.major!.isNotEmpty)
                    '专业：${profile.major}',
                  if (profile.className != null &&
                      profile.className!.isNotEmpty)
                    '班级：${profile.className}',
                ].join('  ·  '),
              ),
            ],
            if (snapshot.warnings.isNotEmpty) ...[
              const SizedBox(height: FluentSpacing.m),
              InfoBar(
                title: const Text('课表已可用，部分教务模块仍在降级'),
                content: Text(snapshot.warnings.join('；')),
                severity: InfoBarSeverity.warning,
                isLong: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseSummaryTag extends StatelessWidget {
  const _CourseSummaryTag({required this.label, required this.value});

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
        color: theme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.16)),
      ),
      child: Text('$label：$value'),
    );
  }
}

class _CourseScheduleWeekdaySection extends StatelessWidget {
  const _CourseScheduleWeekdaySection({
    required this.weekday,
    required this.entries,
  });

  final int weekday;
  final List<AcademicCourseTableEntry> entries;

  @override
  Widget build(BuildContext context) {
    final title = switch (weekday) {
      1 => '周一',
      2 => '周二',
      3 => '周三',
      4 => '周四',
      5 => '周五',
      6 => '周六',
      7 => '周日',
      _ => '未知',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.m),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: FluentSpacing.s),
                child: _CourseScheduleEntryCard(entry: entry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseScheduleEntryCard extends StatelessWidget {
  const _CourseScheduleEntryCard({required this.entry});

  final AcademicCourseTableEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FluentSpacing.m),
      decoration: BoxDecoration(
        color: theme.resources.controlAltFillColorSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.courseName, style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Wrap(
            spacing: FluentSpacing.s,
            runSpacing: FluentSpacing.xs,
            children: [
              _buildMeta(context, FluentIcons.clock, entry.timeText),
              if (entry.location != null && entry.location!.isNotEmpty)
                _buildMeta(context, FluentIcons.location, entry.location!),
              if (entry.teacher != null && entry.teacher!.isNotEmpty)
                _buildMeta(context, FluentIcons.contact, entry.teacher!),
              if (entry.weekDescription != null &&
                  entry.weekDescription!.isNotEmpty)
                _buildMeta(
                  context,
                  FluentIcons.calendar_week,
                  entry.weekDescription!,
                ),
            ],
          ),
          if (entry.location == null &&
              entry.teacher == null &&
              entry.weekDescription == null)
            Padding(
              padding: const EdgeInsets.only(top: FluentSpacing.xs),
              child: Text(
                entry.rawText,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeta(BuildContext context, IconData icon, String text) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.resources.textFillColorSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ],
    );
  }
}
