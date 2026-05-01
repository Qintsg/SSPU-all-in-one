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
import '../models/student_report.dart';
import '../services/sports_attendance_service.dart';
import '../services/student_report_service.dart';
import '../theme/fluent_tokens.dart';

part 'academic_sports_attendance_card.dart';
part 'academic_student_report_card.dart';

/// 教务中心页面。
/// 已接入体育部考勤和第二课堂学分，其余教务能力保留规划入口。
class AcademicPage extends StatefulWidget {
  /// 体育部课外活动考勤服务，测试中可替换为 fake。
  final SportsAttendanceClient? sportsAttendanceService;

  /// 学工报表第二课堂学分服务，测试中可替换为 fake。
  final StudentReportClient? studentReportService;

  /// 测试专用：覆盖体育部考勤自动刷新开关，避免读取真实本地设置。
  final bool? sportsAttendanceAutoRefreshEnabledOverride;

  /// 测试专用：覆盖体育部考勤自动刷新间隔。
  final int? sportsAttendanceAutoRefreshIntervalOverride;

  /// 测试专用：覆盖第二课堂学分自动刷新开关。
  final bool? studentReportAutoRefreshEnabledOverride;

  /// 测试专用：覆盖第二课堂学分自动刷新间隔。
  final int? studentReportAutoRefreshIntervalOverride;

  const AcademicPage({
    super.key,
    this.sportsAttendanceService,
    this.studentReportService,
    this.sportsAttendanceAutoRefreshEnabledOverride,
    this.sportsAttendanceAutoRefreshIntervalOverride,
    this.studentReportAutoRefreshEnabledOverride,
    this.studentReportAutoRefreshIntervalOverride,
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

  StudentReportQueryResult? _studentReportResult;
  bool _isLoadingStudentReport = false;
  bool _studentReportAutoRefreshEnabled = false;
  int _studentReportAutoRefreshIntervalMinutes =
      StudentReportService.defaultAutoRefreshIntervalMinutes;
  Timer? _studentReportAutoRefreshTimer;

  SportsAttendanceClient get _sportsAttendanceService {
    return widget.sportsAttendanceService ?? SportsAttendanceService.instance;
  }

  StudentReportClient get _studentReportService {
    return widget.studentReportService ?? StudentReportService.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadSportsAttendanceAutoRefreshSettings();
    _loadStudentReportAutoRefreshSettings();
  }

  @override
  void dispose() {
    _sportsAttendanceAutoRefreshTimer?.cancel();
    _studentReportAutoRefreshTimer?.cancel();
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

  /// 读取第二课堂学分自动刷新设置；未启用时不主动访问学工报表。
  Future<void> _loadStudentReportAutoRefreshSettings() async {
    final enabled =
        widget.studentReportAutoRefreshEnabledOverride ??
        await StudentReportService.instance.isAutoRefreshEnabled();
    final interval =
        widget.studentReportAutoRefreshIntervalOverride ??
        await StudentReportService.instance.getAutoRefreshIntervalMinutes();
    if (!mounted) return;
    setState(() {
      _studentReportAutoRefreshEnabled = enabled;
      _studentReportAutoRefreshIntervalMinutes = interval;
    });
    _restartStudentReportAutoRefreshTimer();
    if (enabled) unawaited(_loadStudentReport());
  }

  /// 读取第二课堂学分；失败时在卡片内展示明确状态。
  Future<void> _loadStudentReport() async {
    if (_isLoadingStudentReport) return;
    setState(() => _isLoadingStudentReport = true);

    final result = await _studentReportService.fetchSecondClassroomCredits();
    if (!mounted) return;
    setState(() {
      _studentReportResult = result;
      _isLoadingStudentReport = false;
    });
  }

  /// 根据设置重建第二课堂学分自动刷新定时器。
  void _restartStudentReportAutoRefreshTimer() {
    _studentReportAutoRefreshTimer?.cancel();
    _studentReportAutoRefreshTimer = null;
    if (!_studentReportAutoRefreshEnabled) return;
    final intervalMinutes = _studentReportAutoRefreshIntervalMinutes;
    if (intervalMinutes <= 0) return;
    _studentReportAutoRefreshTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _loadStudentReport(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('教务中心')),
      children: [
        AcademicSportsAttendanceCard(
              result: _sportsAttendanceResult,
              isLoading: _isLoadingSportsAttendance,
              autoRefreshEnabled: _sportsAttendanceAutoRefreshEnabled,
              onRefresh: _loadSportsAttendance,
            )
            .animate()
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        AcademicStudentReportCard(
              result: _studentReportResult,
              isLoading: _isLoadingStudentReport,
              autoRefreshEnabled: _studentReportAutoRefreshEnabled,
              onRefresh: _loadStudentReport,
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
              icon: FluentIcons.education,
              color: theme.accentColor,
              title: '课表查询',
              description: '查看本学期课程表，支持按周次、课程名筛选',
              items: ['本周课程', '完整课表', '课程搜索'],
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
              icon: FluentIcons.certificate,
              color: theme.resources.systemFillColorSuccess,
              title: '成绩查询',
              description: '查看历史成绩与绩点统计，支持按学期筛选',
              items: ['本学期成绩', '历史成绩', 'GPA 统计'],
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
              icon: FluentIcons.calendar,
              color: theme.resources.systemFillColorCaution,
              title: '考试安排',
              description: '查看即将到来的考试时间、地点、座位号',
              items: ['近期考试', '所有考试'],
            )
            .animate(delay: 320.ms)
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
            .animate(delay: 400.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.l),
        const InfoBar(
          title: Text('部分功能开发中'),
          content: Text('体育部课外活动考勤和第二课堂学分已接入；课表、成绩、考试与教学评价仍为功能规划预览。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ],
    );
  }

  /// 构建单个服务功能卡片。
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
