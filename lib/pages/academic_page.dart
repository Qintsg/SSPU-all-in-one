/*
 * 教务中心 — 课程、成绩、考试等教务信息聚合
 * @Project : SSPU-all-in-one
 * @File : academic_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/sports_attendance.dart';
import '../services/sports_attendance_service.dart';
import '../theme/fluent_tokens.dart';

/// 教务中心页面
/// 提供课表查询、成绩查询、考试安排等功能入口
class AcademicPage extends StatefulWidget {
  /// 体育部课外活动考勤服务，测试中可替换为 fake。
  final SportsAttendanceClient? sportsAttendanceService;

  /// 测试专用：覆盖体育部考勤自动刷新开关，避免读取真实本地设置。
  final bool? sportsAttendanceAutoRefreshEnabledOverride;

  /// 测试专用：覆盖体育部考勤自动刷新间隔。
  final int? sportsAttendanceAutoRefreshIntervalOverride;

  const AcademicPage({
    super.key,
    this.sportsAttendanceService,
    this.sportsAttendanceAutoRefreshEnabledOverride,
    this.sportsAttendanceAutoRefreshIntervalOverride,
  });

  @override
  State<AcademicPage> createState() => _AcademicPageState();
}

class _AcademicPageState extends State<AcademicPage> {
  SportsAttendanceQueryResult? _sportsAttendanceResult;
  bool _isLoadingSportsAttendance = false;
  bool _sportsAttendanceAutoRefreshEnabled = false;
  int _sportsAttendanceAutoRefreshIntervalMinutes =
      SportsAttendanceService.defaultAutoRefreshIntervalMinutes;
  Timer? _sportsAttendanceAutoRefreshTimer;

  SportsAttendanceClient get _sportsAttendanceService {
    return widget.sportsAttendanceService ?? SportsAttendanceService.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadSportsAttendanceAutoRefreshSettings();
  }

  @override
  void dispose() {
    _sportsAttendanceAutoRefreshTimer?.cancel();
    super.dispose();
  }

  /// 读取体育部自动刷新设置；未启用时不主动访问体育部系统。
  Future<void> _loadSportsAttendanceAutoRefreshSettings() async {
    final enabled =
        widget.sportsAttendanceAutoRefreshEnabledOverride ??
        await SportsAttendanceService.instance.isAutoRefreshEnabled();
    final interval =
        widget.sportsAttendanceAutoRefreshIntervalOverride ??
        await SportsAttendanceService.instance.getAutoRefreshIntervalMinutes();
    if (!mounted) return;
    setState(() {
      _sportsAttendanceAutoRefreshEnabled = enabled;
      _sportsAttendanceAutoRefreshIntervalMinutes = interval;
    });
    _restartSportsAttendanceAutoRefreshTimer();
    if (enabled) unawaited(_loadSportsAttendance());
  }

  /// 读取体育部课外活动考勤；失败时在卡片内展示明确状态。
  Future<void> _loadSportsAttendance() async {
    if (_isLoadingSportsAttendance) return;
    setState(() => _isLoadingSportsAttendance = true);

    final result = await _sportsAttendanceService.fetchAttendanceSummary();
    if (!mounted) return;
    setState(() {
      _sportsAttendanceResult = result;
      _isLoadingSportsAttendance = false;
    });
  }

  /// 根据设置重建体育部考勤自动刷新定时器。
  void _restartSportsAttendanceAutoRefreshTimer() {
    _sportsAttendanceAutoRefreshTimer?.cancel();
    _sportsAttendanceAutoRefreshTimer = null;
    if (!_sportsAttendanceAutoRefreshEnabled) return;
    final intervalMinutes = _sportsAttendanceAutoRefreshIntervalMinutes;
    if (intervalMinutes <= 0) return;
    _sportsAttendanceAutoRefreshTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _loadSportsAttendance(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('教务中心')),
      children: [
        _buildSportsAttendanceCard(context)
            .animate()
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        // 功能卡片组
        _buildServiceCard(
              context,
              icon: FluentIcons.education,
              color: theme.accentColor,
              title: '课表查询',
              description: '查看本学期课程表，支持按周次、课程名筛选',
              items: ['本周课程', '完整课表', '课程搜索'],
            )
            .animate(delay: 80.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        _buildServiceCard(
              context,
              icon: FluentIcons.certificate,
              color: theme.resources.systemFillColorSuccess,
              title: '成绩查询',
              description: '查看历史成绩与绩点统计，支持按学期筛选',
              items: ['本学期成绩', '历史成绩', 'GPA 统计'],
            )
            .animate(delay: 160.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        _buildServiceCard(
              context,
              icon: FluentIcons.calendar,
              color: theme.resources.systemFillColorCaution,
              title: '考试安排',
              description: '查看即将到来的考试时间、地点、座位号',
              items: ['近期考试', '所有考试'],
            )
            .animate(delay: 240.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        _buildServiceCard(
              context,
              icon: FluentIcons.feedback,
              color: theme.resources.systemFillColorSolidNeutral,
              title: '教学评价',
              description: '在线完成教学评价，查看评价状态',
              items: ['待评价课程', '已完成评价'],
            )
            .animate(delay: 320.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: FluentSpacing.l),

        // 开发状态提示
        const InfoBar(
          title: Text('部分功能开发中'),
          content: Text('体育部课外活动考勤已接入；课表、成绩、考试与教学评价仍为功能规划预览。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ],
    );
  }

  /// 构建体育部课外活动考勤卡片。
  Widget _buildSportsAttendanceCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    final result = _sportsAttendanceResult;
    final summary = result?.summary;

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
                    color: theme.resources.systemFillColorSuccess.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    FluentIcons.running,
                    color: theme.resources.systemFillColorSuccess,
                    size: 22,
                  ),
                ),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('课外活动考勤', style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '数据来自体育部查询系统，使用学工号和体育部查询密码登录。',
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
            if (_isLoadingSportsAttendance) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  SizedBox(width: FluentSpacing.s),
                  Text('正在读取体育部考勤...'),
                ],
              ),
            ] else if (result == null) ...[
              Text(
                _sportsAttendanceAutoRefreshEnabled
                    ? '自动刷新已开启，等待下一次读取；也可点击右上角刷新。'
                    : '自动刷新未开启。点击右上角刷新图标可手动读取；体育查询需要校园网或学校 VPN。',
              ),
            ] else if (result.isSuccess && summary != null) ...[
              _buildSportsAttendanceSummary(context, summary),
            ] else ...[
              InfoBar(
                title: Text(result.message),
                content: Text(result.detail),
                severity: _sportsAttendanceSeverity(result.status),
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
                    _sportsAttendanceLastRefreshLabel(result),
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                  Tooltip(
                    message: '手动刷新体育考勤',
                    child: IconButton(
                      icon: _isLoadingSportsAttendance
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.refresh, size: 14),
                      onPressed: _isLoadingSportsAttendance
                          ? null
                          : _loadSportsAttendance,
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

  /// 构建体育部考勤四类次数汇总。
  Widget _buildSportsAttendanceSummary(
    BuildContext context,
    SportsAttendanceSummary summary,
  ) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${summary.totalCount}',
              style: theme.typography.display?.copyWith(
                color: theme.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: FluentSpacing.s),
            Padding(
              padding: const EdgeInsets.only(bottom: FluentSpacing.xs),
              child: Text('总次数', style: theme.typography.bodyStrong),
            ),
          ],
        ),
        const SizedBox(height: FluentSpacing.m),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          children: [
            _buildSportsAttendanceCountPill(
              SportsAttendanceCategory.morningExercise,
              summary.morningExerciseCount,
            ),
            _buildSportsAttendanceCountPill(
              SportsAttendanceCategory.extracurricularActivity,
              summary.extracurricularActivityCount,
            ),
            _buildSportsAttendanceCountPill(
              SportsAttendanceCategory.countAdjustment,
              summary.countAdjustmentCount,
            ),
            _buildSportsAttendanceCountPill(
              SportsAttendanceCategory.sportsCorridor,
              summary.sportsCorridorCount,
            ),
          ],
        ),
        const SizedBox(height: FluentSpacing.l),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          children: [
            FilledButton(
              onPressed: () => _openSportsAttendanceDetail(summary),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.list, size: 14),
                  SizedBox(width: 6),
                  Text('查看考勤记录'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建单个考勤分类次数标签。
  Widget _buildSportsAttendanceCountPill(
    SportsAttendanceCategory category,
    int count,
  ) {
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
      child: Text('${category.label} $count 次'),
    );
  }

  /// 打开体育部考勤明细二级页面。
  void _openSportsAttendanceDetail(SportsAttendanceSummary summary) {
    Navigator.of(context).push(
      FluentPageRoute(
        builder: (_) => SportsAttendanceDetailPage(summary: summary),
      ),
    );
  }

  /// 将体育部考勤查询状态映射为 Fluent 提示等级。
  InfoBarSeverity _sportsAttendanceSeverity(
    SportsAttendanceQueryStatus status,
  ) {
    return switch (status) {
      SportsAttendanceQueryStatus.success => InfoBarSeverity.success,
      SportsAttendanceQueryStatus.missingStudentId ||
      SportsAttendanceQueryStatus.missingSportsPassword ||
      SportsAttendanceQueryStatus.campusNetworkUnavailable =>
        InfoBarSeverity.warning,
      SportsAttendanceQueryStatus.loginPageUnavailable ||
      SportsAttendanceQueryStatus.credentialsRejected ||
      SportsAttendanceQueryStatus.sessionUnavailable ||
      SportsAttendanceQueryStatus.parseFailed ||
      SportsAttendanceQueryStatus.networkError ||
      SportsAttendanceQueryStatus.unexpectedError => InfoBarSeverity.error,
    };
  }

  /// 格式化体育考勤最近一次查询时间，未查询时保持明确兜底文案。
  String _sportsAttendanceLastRefreshLabel(
    SportsAttendanceQueryResult? result,
  ) {
    final checkedAt = result?.checkedAt;
    if (checkedAt == null) return '上次刷新：未刷新';
    return '上次刷新：${checkedAt.year.toString().padLeft(4, '0')}-'
        '${checkedAt.month.toString().padLeft(2, '0')}-'
        '${checkedAt.day.toString().padLeft(2, '0')} '
        '${checkedAt.hour.toString().padLeft(2, '0')}:'
        '${checkedAt.minute.toString().padLeft(2, '0')}';
  }

  /// 构建单个服务功能卡片
  Widget _buildServiceCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required List<String> items,
  }) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
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
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
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
            const SizedBox(height: FluentSpacing.m),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => Button(child: Text(item), onPressed: () {}))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 体育部课外活动考勤明细二级页面。
class SportsAttendanceDetailPage extends StatelessWidget {
  /// 已读取的考勤汇总与明细。
  final SportsAttendanceSummary summary;

  const SportsAttendanceDetailPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('课外活动考勤记录'),
        commandBar: Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('汇总', style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.s),
                Text(
                  '总次数 ${summary.totalCount} 次，明细 ${summary.records.length} 条。',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        if (summary.records.isEmpty)
          const InfoBar(
            title: Text('暂无明细记录'),
            content: Text('体育部页面返回了汇总次数，但没有可展示的考勤明细。'),
            severity: InfoBarSeverity.info,
            isLong: true,
          )
        else
          ...summary.records.map(_buildRecordCard),
      ],
    );
  }

  /// 构建单条考勤记录卡片，未知字段使用原始单元格兜底。
  Widget _buildRecordCard(SportsAttendanceRecord record) {
    final titleParts = [
      record.category.label,
      if (record.occurredAt != null) record.occurredAt!,
    ];
    final details = [
      if (record.project != null) '项目：${record.project}',
      if (record.location != null) '地点：${record.location}',
      if (record.remark != null) '备注：${record.remark}',
      if (record.cells.isNotEmpty) '原始记录：${record.cells.join(' / ')}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: FluentSpacing.s),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(FluentSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(titleParts.join(' · '))),
                  Text('${record.count} 次'),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: FluentSpacing.xs),
                Text(details.join('\n')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
