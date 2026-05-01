/*
 * 教务中心第二课堂学分卡片 — 展示学工报表只读查询结果
 * @Project : SSPU-all-in-one
 * @File : academic_student_report_card.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'academic_page.dart';

/// 教务中心第二课堂学分卡片。
class AcademicStudentReportCard extends StatelessWidget {
  /// 最近一次学工报表查询结果。
  final StudentReportQueryResult? result;

  /// 当前是否正在读取学工报表系统。
  final bool isLoading;

  /// 是否已开启自动刷新。
  final bool autoRefreshEnabled;

  /// 手动刷新回调。
  final VoidCallback onRefresh;

  const AcademicStudentReportCard({
    super.key,
    required this.result,
    required this.isLoading,
    required this.autoRefreshEnabled,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
                      Text('第二课堂学分', style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '数据来自学工报表系统，通过 OA 登录态只读读取第二课堂学分。',
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
                  Text('正在读取第二课堂学分...'),
                ],
              ),
            ] else if (result == null) ...[
              Text(
                autoRefreshEnabled
                    ? '自动刷新已开启，等待下一次读取；也可点击右上角刷新。'
                    : '自动刷新未开启。点击右上角刷新图标可手动读取；学工报表需要校园网或学校 VPN。',
              ),
            ] else if (result!.isSuccess && summary != null) ...[
              _SecondClassroomSummaryView(summary: summary),
            ] else ...[
              InfoBar(
                title: Text(result!.message),
                content: Text(result!.detail),
                severity: _studentReportSeverity(result!.status),
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
                    _studentReportLastRefreshLabel(result),
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                  Tooltip(
                    message: '手动刷新第二课堂学分',
                    child: IconButton(
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

  InfoBarSeverity _studentReportSeverity(StudentReportQueryStatus status) {
    return switch (status) {
      StudentReportQueryStatus.success => InfoBarSeverity.success,
      StudentReportQueryStatus.missingOaAccount ||
      StudentReportQueryStatus.missingOaPassword ||
      StudentReportQueryStatus.campusNetworkUnavailable =>
        InfoBarSeverity.warning,
      StudentReportQueryStatus.oaLoginRequired ||
      StudentReportQueryStatus.reportSystemUnavailable ||
      StudentReportQueryStatus.secondClassroomEntryUnavailable ||
      StudentReportQueryStatus.parseFailed ||
      StudentReportQueryStatus.networkError ||
      StudentReportQueryStatus.unexpectedError => InfoBarSeverity.error,
    };
  }

  String _studentReportLastRefreshLabel(StudentReportQueryResult? result) {
    final checkedAt = result?.checkedAt;
    if (checkedAt == null) return '上次刷新：未刷新';
    return '上次刷新：${checkedAt.year.toString().padLeft(4, '0')}-'
        '${checkedAt.month.toString().padLeft(2, '0')}-'
        '${checkedAt.day.toString().padLeft(2, '0')} '
        '${checkedAt.hour.toString().padLeft(2, '0')}:'
        '${checkedAt.minute.toString().padLeft(2, '0')}';
  }
}

class _SecondClassroomSummaryView extends StatelessWidget {
  const _SecondClassroomSummaryView({required this.summary});

  final SecondClassroomCreditSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final previewRecords = summary.records.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              summary.records.length.toString(),
              style: theme.typography.display?.copyWith(
                color: theme.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: FluentSpacing.s),
            Padding(
              padding: const EdgeInsets.only(bottom: FluentSpacing.xs),
              child: Text('项得分记录', style: theme.typography.bodyStrong),
            ),
          ],
        ),
        const SizedBox(height: FluentSpacing.xs),
        Text(
          '逐项展示学工报表返回的具体得分，不再将单项分值相加作为总学分。',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        ...previewRecords.map(
          (record) => _SecondClassroomScoreTile(
            record: record,
            onTap: () =>
                unawaited(_showSecondClassroomRecordDialog(context, record)),
          ),
        ),
        if (summary.records.length > previewRecords.length)
          Padding(
            padding: const EdgeInsets.only(top: FluentSpacing.xs),
            child: Text(
              '还有 ${summary.records.length - previewRecords.length} 项得分记录，点击下方按钮查看全部。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        const SizedBox(height: FluentSpacing.l),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            FluentPageRoute(
              builder: (_) => StudentReportDetailPage(summary: summary),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.list, size: 14),
              SizedBox(width: 6),
              Text('查看全部得分记录'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecondClassroomScoreTile extends StatelessWidget {
  const _SecondClassroomScoreTile({required this.record, required this.onTap});

  final SecondClassroomCreditRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final meta = [
      record.category,
      if (record.occurredAt != null) record.occurredAt!,
      if (record.status != null) record.status!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: FluentSpacing.s),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(FluentSpacing.m),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.itemName, style: theme.typography.bodyStrong),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: FluentSpacing.xxs),
                        Text(
                          meta,
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FluentSpacing.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCredit(record.credit),
                      style: theme.typography.bodyLarge?.copyWith(
                        color: theme.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '得分',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showSecondClassroomRecordDialog(
  BuildContext context,
  SecondClassroomCreditRecord record,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('得分详情'),
      content: _SecondClassroomRecordDetailCard(record: record),
      actions: [
        Button(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _SecondClassroomRecordDetailCard extends StatelessWidget {
  const _SecondClassroomRecordDetailCard({required this.record});

  final SecondClassroomCreditRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final detailRows = [
      _DetailRow(label: '项目', value: record.itemName),
      _DetailRow(label: '类别', value: record.category),
      _DetailRow(label: '得分', value: _formatCredit(record.credit)),
      if (record.occurredAt != null)
        _DetailRow(label: '时间', value: record.occurredAt!),
      if (record.status != null) _DetailRow(label: '状态', value: record.status!),
      if (record.rawCells.isNotEmpty)
        _DetailRow(label: '原始记录', value: record.rawCells.join(' / ')),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCredit(record.credit),
                  style: theme.typography.display?.copyWith(
                    color: theme.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: FluentSpacing.s),
                ...detailRows.map((row) => _buildDetailRow(context, row)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, _DetailRow row) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: FluentSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: FluentSpacing.xxs),
          Text(row.value),
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// 第二课堂得分明细二级页面。
class StudentReportDetailPage extends StatelessWidget {
  /// 已读取的第二课堂学分汇总与明细。
  final SecondClassroomCreditSummary summary;

  const StudentReportDetailPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('第二课堂得分明细'),
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
                Text('得分记录 ${summary.records.length} 项。点击任一记录可查看得分详情。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        ...summary.records.map((record) => _buildRecordCard(context, record)),
      ],
    );
  }

  /// 构建单条第二课堂得分记录，点击后弹出完整详情卡片。
  Widget _buildRecordCard(
    BuildContext context,
    SecondClassroomCreditRecord record,
  ) {
    return _SecondClassroomScoreTile(
      record: record,
      onTap: () => unawaited(_showSecondClassroomRecordDialog(context, record)),
    );
  }
}

/// 学分展示保留必要小数，避免整数显示为 3.0。
String _formatCredit(double credit) {
  final text = credit.toStringAsFixed(2);
  return text
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'0$'), '');
}
