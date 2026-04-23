/*
 * 信息中心 — 校园消息聚合列表
 * 展示学校官网、微信等渠道的消息，支持搜索、筛选、已读/未读、分页
 * @Project : SSPU-all-in-one
 * @File : info_page.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
 */

import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/message_item.dart';
import '../models/channel_config.dart';
import '../services/auto_refresh_service.dart';
import '../services/wechat_article_service.dart';
import '../theme/fluent_tokens.dart';
import '../widgets/message_tile.dart';
import '../services/message_state_service.dart';
import '../utils/webview_env.dart';
import 'webview_page.dart';

part 'info_page_dialogs.dart';
part 'info_page_filters.dart';
part 'info_page_widgets.dart';

/// 信息中心页面
/// 统一大列表展示所有渠道消息，支持搜索/筛选/已读未读/分页
class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  /// 所有已加载的消息
  final List<MessageItem> _allMessages = [];

  /// 经过搜索和筛选后的消息
  List<MessageItem> _filteredMessages = [];

  /// 是否正在加载
  bool _isLoading = false;

  /// 是否正在刷新官网消息。
  bool _isRefreshingSchoolWebsite = false;

  /// 是否正在刷新微信公众号消息。
  bool _isRefreshingWechat = false;

  /// 刷新进度提示文本。
  String _refreshProgressText = '';

  /// 已完成的刷新任务数。
  int _refreshCompleted = 0;

  /// 总刷新任务数。
  int _refreshTotal = 0;

  /// 微信公众号来源是否已完成公众号平台认证。
  bool _wechatSourceConfigured = false;

  /// 搜索关键词
  String _searchQuery = '';

  /// 筛选：来源类型（null 表示不筛选）
  MessageSourceType? _filterSourceType;

  /// 筛选：来源名称（null 表示不筛选）
  MessageSourceName? _filterSourceName;

  /// 筛选：内容分类（null 表示不筛选）
  MessageCategory? _filterCategory;

  /// 筛选：仅显示未读
  bool _filterUnreadOnly = false;

  /// 当前页码（从 0 开始）
  int _currentPage = 0;

  /// 每页条数
  static const int _pageSize = 20;

  /// 搜索框控制器
  final TextEditingController _searchController = TextEditingController();

  /// 消息状态服务
  final MessageStateService _stateService = MessageStateService.instance;

  /// 自动刷新服务（用于手动全渠道刷新）
  final AutoRefreshService _autoRefreshService = AutoRefreshService.instance;

  void _debugWechatRefreshLog(String message) {
    if (kDebugMode) {
      debugPrint('[InfoPage][WechatRefresh] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 初始化状态服务，从本地存储加载消息并根据渠道开关过滤显示
  Future<void> _initAndLoad() async {
    await _stateService.init();
    _wechatSourceConfigured = await WechatArticleService.instance
        .hasConfiguredSource();
    // 从本地存储加载已有消息，不弹刷新对话框
    final persisted = await _stateService.loadMessages();
    _allMessages
      ..clear()
      ..addAll(persisted);
    // 根据渠道开关过滤并排序
    await _filterByEnabledChannels();
  }

  /// 刷新官网消息：抓取所有已启用渠道的新数据并与已有数据合并持久化
  /// [maxCount] 每个栏目获取的条数，null 则弹出输入框
  Future<void> _refreshSchoolWebsite({int? maxCount}) async {
    // 弹出条数选择对话框
    final count = maxCount ?? await _showFetchCountDialog();
    if (count == null) return;

    setState(() {
      _isLoading = true;
      _isRefreshingSchoolWebsite = true;
      _refreshProgressText = '正在准备刷新官网消息...';
      _refreshCompleted = 0;
      _refreshTotal = 0;
    });

    try {
      // 仅抓取官网/信息中心渠道，避免将微信公众号刷新串进官网刷新链路。
      final allFetched = await _autoRefreshService
          .fetchEnabledSchoolWebsiteMessages(
            maxCount: count,
            onBatchCompleted: (messages, completed, total) async {
              final merged = _stateService.mergeMessages(
                _allMessages,
                messages,
              );
              _allMessages
                ..clear()
                ..addAll(merged);
              await _stateService.saveMessages(_allMessages);
              await _filterByEnabledChannels();
              if (!mounted) return;
              setState(() {
                _refreshCompleted = completed;
                _refreshTotal = total;
                _refreshProgressText =
                    '已完成 $completed / $total 个渠道，新增 ${messages.length} 条';
              });
            },
          );

      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: Text('官网消息刷新完成，获取 ${allFetched.length} 条候选消息'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshingSchoolWebsite = false;
          _refreshProgressText = '';
          _refreshCompleted = 0;
          _refreshTotal = 0;
        });
      }
    }
  }

  /// 刷新微信公众号文章：通过 WechatArticleService 获取已关注公众号的推文
  Future<void> _refreshWechatArticles() async {
    _debugWechatRefreshLog('manual refresh clicked');
    final isConfigured = await WechatArticleService.instance
        .hasConfiguredSource();
    if (!isConfigured) {
      _wechatSourceConfigured = false;
      _debugWechatRefreshLog('source not configured');
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('未获取到微信公众号文章'),
              content: const Text('请先在设置中完成公众号平台认证并关注目标公众号'),
              severity: InfoBarSeverity.warning,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
        setState(() {});
      }
      return;
    }

    final validation = await WechatArticleService.instance.validateSource();
    _debugWechatRefreshLog(
      'validation valid=${validation.isValid} message=${validation.message}',
    );
    if (!validation.isValid) {
      _wechatSourceConfigured = false;
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('微信公众号认证不可用'),
              content: Text(validation.message),
              severity: InfoBarSeverity.warning,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
        setState(() {});
      }
      return;
    }

    _wechatSourceConfigured = true;
    setState(() {
      _isLoading = true;
      _isRefreshingWechat = true;
      _refreshProgressText = '正在刷新微信公众号文章...';
      _refreshCompleted = 0;
      _refreshTotal = 0;
    });

    try {
      final persistedMessages = await _stateService.loadMessages();
      final maxCount = await _stateService.getChannelManualFetchCount(
        'wechat_public',
        defaultValue: 50,
      );
      _debugWechatRefreshLog(
        'fetch request maxCount=$maxCount persisted=${persistedMessages.length}',
      );
      final articles = await WechatArticleService.instance.fetchArticles(
        maxCount: maxCount,
        knownMessageIds: persistedMessages.map((msg) => msg.id).toSet(),
        validateBeforeFetch: false,
      );
      _debugWechatRefreshLog('fetch returned articles=${articles.length}');

      if (articles.isEmpty) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (ctx, close) {
              return InfoBar(
                title: const Text('未获取到微信公众号文章'),
                content: const Text('请确认已在设置中完成公众号平台认证并关注公众号'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              );
            },
          );
        }
        return;
      }

      // 与已有消息合并
      final merged = _stateService.mergeMessages(_allMessages, articles);
      _debugWechatRefreshLog(
        'merge old=${_allMessages.length} fetched=${articles.length} merged=${merged.length}',
      );
      _allMessages
        ..clear()
        ..addAll(merged);

      // 持久化
      await _stateService.saveMessages(_allMessages);

      // 过滤并排序
      await _filterByEnabledChannels();
      _debugWechatRefreshLog(
        'filter completed visible=${_filteredMessages.length}',
      );

      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: Text('已获取 ${articles.length} 篇微信公众号文章'),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } catch (e) {
      _debugWechatRefreshLog('refresh failed: $e');
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('刷新微信公众号文章失败'),
              content: Text(e.toString()),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshingWechat = false;
          _refreshProgressText = '';
          _refreshCompleted = 0;
          _refreshTotal = 0;
        });
      }
    }
  }

  /// 根据渠道开关过滤消息并排序
  /// 通过 _categoryToChannelId 映射表统一检查所有渠道的启用状态
  Future<void> _filterByEnabledChannels() async {
    await _filterInfoPageByEnabledChannels(this);
  }

  /// 弹出获取条数输入对话框
  /// 返回用户输入的条数，取消返回 null
  Future<int?> _showFetchCountDialog() => _showInfoFetchCountDialog(this);

  /// 全部标为已读
  Future<void> _markAllRead() async {
    final allIds = _filteredMessages.map((msg) => msg.id).toList();
    await _stateService.markAllAsRead(allIds);
    setState(() {});
  }

  /// 供同库 helper 刷新当前页面。
  void _refreshView() {
    if (mounted) setState(() {});
  }

  /// 供同库 helper 跳转分页。
  void _setCurrentPage(int page) {
    if (mounted) setState(() => _currentPage = page);
  }

  /// 应用搜索和筛选条件
  void _applyFilters() => _applyInfoPageFilters(this);

  /// 获取当前页的消息列表
  List<MessageItem> get _pagedMessages => _getPagedInfoMessages(this);

  /// 总页数
  int get _totalPages => _getInfoTotalPages(this);

  /// 打开消息：标记已读并在内嵌 WebView 中打开
  /// WebView 初始化失败时自动 fallback 到外部浏览器
  Future<void> _openMessage(MessageItem message) async {
    await _stateService.markAsRead(message.id);
    if (mounted) {
      Navigator.of(context).push(
        FluentPageRoute(
          builder: (_) => WebViewPage(
            url: message.url,
            initialTitle: message.title,
            webViewEnvironment: globalWebViewEnvironment,
          ),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => _buildInfoPageView(this, context);

  /// 构建操作栏：全部标为已读 + 刷新官网消息 + 刷新微信消息（占位）
  Widget _buildActionBar(FluentThemeData theme) =>
      _buildInfoActionBar(this, theme);

  /// 构建刷新进度条。
  Widget _buildRefreshProgress(FluentThemeData theme) =>
      _buildInfoRefreshProgress(this, theme);

  /// 构建搜索栏
  Widget _buildSearchBar(FluentThemeData theme) =>
      _buildInfoSearchBar(this, theme);

  /// 构建筛选栏：来源类型 + 来源名称（级联） + 内容分类（级联） + 未读筛选
  Widget _buildFilterBar(FluentThemeData theme, bool isDark) =>
      _buildInfoFilterBar(this, theme, isDark);

  /// 根据当前来源类型获取可选的来源名称列表
  List<MessageSourceName> _getAvailableSourceNames() =>
      _getInfoAvailableSourceNames(this);

  /// 根据当前来源名称获取可选的内容分类列表
  List<MessageCategory> _getAvailableCategories() =>
      _getInfoAvailableCategories(this);

  /// 构建筛选下拉框通用方法
  Widget _buildFilterCombo<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    bool enabled = true,
  }) => _buildInfoFilterCombo(
    label: label,
    value: value,
    items: items,
    itemLabel: itemLabel,
    onChanged: onChanged,
    enabled: enabled,
  );

  /// 构建消息列表
  Widget _buildMessageList(FluentThemeData theme, bool isDark) =>
      _buildInfoMessageList(this, theme, isDark);

  /// 构建分页导航栏
  Widget _buildPagination(FluentThemeData theme) =>
      _buildInfoPagination(this, theme);

  /// 弹出页码跳转对话框
  /// 用户输入目标页码后直接跳转
  Future<void> _showPageJumpDialog() => _showInfoPageJumpDialog(this);
}
