/*
 * 主页校园卡详情页 — 校园卡余额与交易记录只读展示
 * @Project : SSPU-all-in-one
 * @File : home_campus_card_detail_page.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'home_page.dart';

/// 校园卡余额与交易记录详情页。
class CampusCardDetailPage extends StatefulWidget {
  /// 首页已读取的校园卡快照。
  final CampusCardSnapshot initialSnapshot;

  /// 校园卡查询服务，继续用于交易记录条件查询。
  final CampusCardBalanceClient campusCardService;

  const CampusCardDetailPage({
    super.key,
    required this.initialSnapshot,
    required this.campusCardService,
  });

  @override
  State<CampusCardDetailPage> createState() => _CampusCardDetailPageState();
}

class _CampusCardDetailPageState extends State<CampusCardDetailPage> {
  late CampusCardSnapshot _snapshot;
  CampusCardQueryResult? _queryResult;
  bool _isQuerying = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    final now = DateTime.now();
    _startDateController.text = _formatDate(
      now.subtract(const Duration(days: 30)),
    );
    _endDateController.text = _formatDate(now);
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  /// 按用户输入日期查询交易记录，日期为空时查询系统默认最近记录。
  Future<void> _queryTransactions() async {
    setState(() => _isQuerying = true);
    final result = await widget.campusCardService.fetchCampusCard(
      startDate: _parseDate(_startDateController.text),
      endDate: _parseDate(_endDateController.text),
    );
    if (!mounted) return;
    setState(() {
      _queryResult = result;
      if (result.isSuccess && result.snapshot != null) {
        _snapshot = result.snapshot!;
      }
      _isQuerying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('校园卡详情'),
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
                Text('账户概览', style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.s),
                Text(
                  '余额：${_snapshot.balance == null ? '未读取' : _formatMoney(_snapshot.balance!)}',
                ),
                Text(
                  '卡状态：${_snapshot.status.isEmpty ? '未读取' : _snapshot.status}',
                ),
                Text('最近刷新：${_formatDateTime(_snapshot.fetchedAt)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('交易记录查询', style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.s),
                Text(
                  '日期格式为 yyyy-MM-dd；查询只读取交易记录，不执行充值、支付或其它写入操作。',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: FluentSpacing.m),
                Wrap(
                  spacing: FluentSpacing.s,
                  runSpacing: FluentSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      child: TextBox(
                        controller: _startDateController,
                        placeholder: '开始日期',
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextBox(
                        controller: _endDateController,
                        placeholder: '结束日期',
                      ),
                    ),
                    FilledButton(
                      onPressed: _isQuerying ? null : _queryTransactions,
                      child: _isQuerying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Text('查询'),
                    ),
                  ],
                ),
                if (_queryResult != null && !_queryResult!.isSuccess) ...[
                  const SizedBox(height: FluentSpacing.m),
                  InfoBar(
                    title: Text(_queryResult!.message),
                    content: Text(_queryResult!.detail),
                    severity: InfoBarSeverity.warning,
                    isLong: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        if (_snapshot.records.isEmpty)
          const InfoBar(
            title: Text('暂无交易记录'),
            content: Text('当前查询结果没有可展示的校园卡交易记录。'),
            severity: InfoBarSeverity.info,
            isLong: true,
          )
        else
          ..._snapshot.records.map(_buildRecordCard),
      ],
    );
  }

  /// 构建单条交易记录卡片，保留原始单元格兜底。
  Widget _buildRecordCard(CampusCardTransactionRecord record) {
    final details = [
      if (record.type != null) '类型：${record.type}',
      if (record.merchant != null) '摘要：${record.merchant}',
      if (record.balanceAfter != null)
        '交易后余额：${_formatMoney(record.balanceAfter!)}',
      if (record.rawCells.isNotEmpty) '原始记录：${record.rawCells.join(' / ')}',
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
                  Expanded(child: Text(record.occurredAt)),
                  Text(_formatSignedMoney(record.amount)),
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

  DateTime? _parseDate(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return null;
    return DateTime.tryParse(trimmedText);
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String _formatMoney(double value) {
    return '¥${value.toStringAsFixed(2)}';
  }

  static String _formatSignedMoney(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${_formatMoney(value)}';
  }
}
