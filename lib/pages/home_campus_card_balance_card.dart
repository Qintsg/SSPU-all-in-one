/*
 * 主页校园卡余额卡片 — 展示余额、状态和最近交易摘要
 * @Project : SSPU-all-in-one
 * @File : home_campus_card_balance_card.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'home_page.dart';

extension _HomeCampusCardBalanceCard on _HomePageState {
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
}
