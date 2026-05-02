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

part 'home_campus_card_balance_card.dart';
part 'home_campus_card_detail_page.dart';

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
