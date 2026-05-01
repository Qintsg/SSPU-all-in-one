/*
 * 主页 — 应用首屏，展示欢迎信息与最新消息摘要
 * @Project : SSPU-all-in-one
 * @File : home_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/campus_card.dart';
import '../models/message_item.dart';
import '../services/campus_card_service.dart';
import '../services/message_state_service.dart';
import '../theme/fluent_tokens.dart';
import '../utils/webview_env.dart';
import '../widgets/responsive_layout.dart';
import 'webview_page.dart';

/// 主页
/// 展示欢迎信息与最新消息列表
class HomePage extends StatefulWidget {
  /// 校园卡余额查询服务，测试中可替换为 fake。
  final CampusCardBalanceClient? campusCardService;

  /// 测试专用：覆盖校园卡余额自动刷新开关。
  final bool? campusCardAutoRefreshEnabledOverride;

  /// 测试专用：覆盖校园卡余额自动刷新间隔。
  final int? campusCardAutoRefreshIntervalOverride;

  const HomePage({
    super.key,
    this.campusCardService,
    this.campusCardAutoRefreshEnabledOverride,
    this.campusCardAutoRefreshIntervalOverride,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

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

class _HomePageState extends State<HomePage> {
  /// 最新消息列表（最多 5 条）
  List<MessageItem> _latestMessages = [];

  CampusCardQueryResult? _campusCardResult;
  bool _isLoadingCampusCard = false;
  bool _campusCardAutoRefreshEnabled = false;
  int _campusCardAutoRefreshIntervalMinutes =
      CampusCardService.defaultAutoRefreshIntervalMinutes;
  Timer? _campusCardAutoRefreshTimer;

  CampusCardBalanceClient get _campusCardService {
    return widget.campusCardService ?? CampusCardService.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadLatestMessages();
    _loadCampusCardAutoRefreshSettings();
  }

  @override
  void dispose() {
    _campusCardAutoRefreshTimer?.cancel();
    super.dispose();
  }

  /// 从本地存储加载消息并取前 5 条
  Future<void> _loadLatestMessages() async {
    final all = await MessageStateService.instance.loadMessages();
    // 按日期降序排列，取前 5 条
    all.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() => _latestMessages = all.take(5).toList());
    }
  }

  /// 读取校园卡自动刷新设置；默认不主动访问 OA / 校园卡系统。
  Future<void> _loadCampusCardAutoRefreshSettings() async {
    final enabled =
        widget.campusCardAutoRefreshEnabledOverride ??
        await CampusCardService.instance.isAutoRefreshEnabled();
    final interval =
        widget.campusCardAutoRefreshIntervalOverride ??
        await CampusCardService.instance.getAutoRefreshIntervalMinutes();
    if (!mounted) return;
    setState(() {
      _campusCardAutoRefreshEnabled = enabled;
      _campusCardAutoRefreshIntervalMinutes = interval;
    });
    _restartCampusCardAutoRefreshTimer();
    if (enabled) unawaited(_loadCampusCard());
  }

  /// 读取校园卡余额、状态和交易记录。
  Future<void> _loadCampusCard({DateTime? startDate, DateTime? endDate}) async {
    if (_isLoadingCampusCard) return;
    setState(() => _isLoadingCampusCard = true);

    final result = await _campusCardService.fetchCampusCard(
      startDate: startDate,
      endDate: endDate,
    );
    if (!mounted) return;
    setState(() {
      _campusCardResult = result;
      _isLoadingCampusCard = false;
    });
  }

  /// 根据设置重建校园卡余额自动刷新定时器。
  void _restartCampusCardAutoRefreshTimer() {
    _campusCardAutoRefreshTimer?.cancel();
    _campusCardAutoRefreshTimer = null;
    if (!_campusCardAutoRefreshEnabled) return;
    final intervalMinutes = _campusCardAutoRefreshIntervalMinutes;
    if (intervalMinutes <= 0) return;
    _campusCardAutoRefreshTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _loadCampusCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveBuilder(
      builder: (context, deviceType, constraints) {
        // 根据设备类型调整页面边距与磁贴尺寸
        final pagePadding = switch (deviceType) {
          DeviceType.phone => FluentSpacing.m,
          DeviceType.tablet => FluentSpacing.xl,
          DeviceType.desktop => FluentSpacing.xxl,
        };

        return ScaffoldPage.scrollable(
          header: const PageHeader(title: Text('主页')),
          padding: EdgeInsets.all(pagePadding),
          children: [
            // 欢迎卡片
            Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                // 根据主题亮暗自适应背景色
                                color: isDark
                                    ? FluentDarkColors.backgroundSecondary
                                    : FluentLightColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(
                                  FluentRadius.xxLarge,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 80,
                                height: 80,
                              ),
                            ),
                            const SizedBox(width: FluentSpacing.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '欢迎使用 SSPU All-in-One',
                                    style: theme.typography.subtitle,
                                  ),
                                  const SizedBox(height: FluentSpacing.s),
                                  Text(
                                    '上海第二工业大学校园综合服务应用',
                                    style: theme.typography.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(
                  duration: FluentDuration.slow,
                  curve: FluentEasing.decelerate,
                )
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: FluentSpacing.l),

            _buildCampusCardBalanceCard(context)
                .animate(delay: 100.ms)
                .fadeIn(
                  duration: FluentDuration.slow,
                  curve: FluentEasing.decelerate,
                )
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: FluentSpacing.l),

            // 最新消息
            Text('最新消息', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.s),
            Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FluentSpacing.l),
                    child: _latestMessages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FluentSpacing.xl,
                              ),
                              child: Text(
                                '暂无消息，开启信息渠道并等待自动刷新后将在此显示',
                                style: theme.typography.caption,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                int i = 0;
                                i < _latestMessages.length;
                                i++
                              ) ...[
                                if (i > 0) const Divider(),
                                _buildMessageItem(context, _latestMessages[i]),
                              ],
                            ],
                          ),
                  ),
                )
                .animate(delay: 200.ms)
                .fadeIn(
                  duration: FluentDuration.slow,
                  curve: FluentEasing.decelerate,
                )
                .slideY(begin: 0.05, end: 0),
          ],
        );
      },
    );
  }

  /// 构建校园卡余额卡片。
  Widget _buildCampusCardBalanceCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    final result = _campusCardResult;
    final snapshot = result?.snapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
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
                    FluentIcons.payment_card,
                    color: theme.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('校园卡余额', style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '需要校园网或学校 VPN，并复用 OA/CAS 登录状态。',
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: snapshot == null ? '刷新后查看详情' : '查看校园卡详情',
                  child: IconButton(
                    icon: const Icon(FluentIcons.chevron_right, size: 14),
                    onPressed: snapshot == null
                        ? null
                        : () => _openCampusCardDetail(snapshot),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.l),
            if (_isLoadingCampusCard) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  SizedBox(width: FluentSpacing.s),
                  Text('正在读取校园卡余额...'),
                ],
              ),
            ] else if (result == null) ...[
              Text(
                _campusCardAutoRefreshEnabled
                    ? '自动刷新已开启，等待下一次读取；也可点击右下角刷新。'
                    : '自动刷新未开启。点击右下角刷新图标可手动读取；校园卡查询需要校园网或学校 VPN。',
              ),
            ] else if (result.isSuccess && snapshot != null) ...[
              _buildCampusCardBalanceSummary(context, snapshot),
            ] else ...[
              InfoBar(
                title: Text(result.message),
                content: Text(result.detail),
                severity: _campusCardSeverity(result.status),
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
                    _campusCardLastRefreshLabel(result),
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                  Tooltip(
                    message: '刷新校园卡余额',
                    child: IconButton(
                      icon: _isLoadingCampusCard
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.refresh, size: 14),
                      onPressed: _isLoadingCampusCard ? null : _loadCampusCard,
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

  /// 构建校园卡余额、状态和最近交易记录摘要。
  Widget _buildCampusCardBalanceSummary(
    BuildContext context,
    CampusCardSnapshot snapshot,
  ) {
    final theme = FluentTheme.of(context);
    final recentRecords = snapshot.records.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              snapshot.balance == null
                  ? '未读取'
                  : _formatMoney(snapshot.balance!),
              style: theme.typography.display?.copyWith(
                color: theme.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: FluentSpacing.s),
            Padding(
              padding: const EdgeInsets.only(bottom: FluentSpacing.xs),
              child: Text('账户余额', style: theme.typography.bodyStrong),
            ),
          ],
        ),
        if (snapshot.hasAbnormalStatus) ...[
          const SizedBox(height: FluentSpacing.s),
          InfoBar(
            title: Text('卡状态：${snapshot.status}'),
            content: const Text('校园卡状态不是正常状态，请以校园卡系统或服务窗口为准。'),
            severity: InfoBarSeverity.warning,
            isLong: true,
          ),
        ],
        const SizedBox(height: FluentSpacing.m),
        Text('最近交易记录', style: theme.typography.bodyStrong),
        const SizedBox(height: FluentSpacing.xs),
        if (recentRecords.isEmpty)
          Text(
            '暂无可展示的最近交易记录',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          )
        else
          ...recentRecords.map((record) => _buildCampusCardRecordLine(record)),
      ],
    );
  }

  /// 构建首页校园卡交易记录单行摘要。
  Widget _buildCampusCardRecordLine(CampusCardTransactionRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FluentSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${record.occurredAt} · ${record.merchant ?? record.type ?? '交易'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(_formatSignedMoney(record.amount)),
        ],
      ),
    );
  }

  /// 打开校园卡详情页。
  void _openCampusCardDetail(CampusCardSnapshot snapshot) {
    Navigator.of(context).push(
      FluentPageRoute(
        builder: (_) => CampusCardDetailPage(
          initialSnapshot: snapshot,
          campusCardService: _campusCardService,
        ),
      ),
    );
  }

  InfoBarSeverity _campusCardSeverity(CampusCardQueryStatus status) {
    return switch (status) {
      CampusCardQueryStatus.success => InfoBarSeverity.success,
      CampusCardQueryStatus.missingOaAccount ||
      CampusCardQueryStatus.missingOaPassword ||
      CampusCardQueryStatus.campusNetworkUnavailable ||
      CampusCardQueryStatus.oaLoginRequired => InfoBarSeverity.warning,
      CampusCardQueryStatus.cardSystemUnavailable ||
      CampusCardQueryStatus.parseFailed ||
      CampusCardQueryStatus.networkError ||
      CampusCardQueryStatus.unexpectedError => InfoBarSeverity.error,
    };
  }

  String _campusCardLastRefreshLabel(CampusCardQueryResult? result) {
    final checkedAt = result?.checkedAt;
    if (checkedAt == null) return '上次刷新：未刷新';
    return '上次刷新：${_formatDateTime(checkedAt)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatMoney(double value) {
    return '¥${value.toStringAsFixed(2)}';
  }

  String _formatSignedMoney(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${_formatMoney(value)}';
  }

  /// 构建单条消息项（点击跳转内嵌 WebView）
  Widget _buildMessageItem(BuildContext context, MessageItem msg) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: () {
        // 标记已读并跳转内嵌 WebView
        MessageStateService.instance.markAsRead(msg.id);
        Navigator.of(context).push(
          FluentPageRoute(
            builder: (_) => WebViewPage(
              url: msg.url,
              initialTitle: msg.title,
              webViewEnvironment: globalWebViewEnvironment,
            ),
          ),
        );
      },
      builder: (context, states) {
        final isHovered = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isHovered
                ? theme.resources.subtleFillColorSecondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.title, style: theme.typography.bodyStrong),
                    const SizedBox(height: 4),
                    Text(
                      '${msg.category.label} · ${msg.sourceName.label}',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
              Text(
                msg.date,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
