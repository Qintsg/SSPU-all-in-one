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

import '../models/message_item.dart';
import '../services/sspu_news_service.dart';
import '../widgets/message_tile.dart';
import '../services/message_state_service.dart';
import 'webview_page.dart';

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

  /// 新闻抓取服务
  final SspuNewsService _newsService = SspuNewsService.instance;

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
    // 从本地存储加载已有消息，不弹刷新对话框
    final persisted = await _stateService.loadMessages();
    _allMessages
      ..clear()
      ..addAll(persisted);
    // 根据渠道开关过滤并排序
    await _filterByEnabledChannels();
  }

  /// 刷新官网消息：抓取新数据并与已有数据合并持久化
  /// [maxCount] 每个栏目获取的条数，null 则弹出输入框
  Future<void> _refreshSchoolWebsite({int? maxCount}) async {
    // 弹出条数选择对话框
    final count = maxCount ?? await _showFetchCountDialog();
    if (count == null) return;

    setState(() => _isLoading = true);

    try {
      final latestInfoEnabled = await _stateService.isLatestInfoEnabled();
      final noticeEnabled = await _stateService.isNoticeEnabled();

      // 并行获取启用的栏目
      final futures = <Future<List<MessageItem>>>[];
      if (latestInfoEnabled) {
        futures.add(_newsService.fetchLatestInfo(maxCount: count));
      }
      if (noticeEnabled) {
        futures.add(_newsService.fetchNotices(maxCount: count));
      }

      final results = await Future.wait(futures);
      final newMessages = <MessageItem>[];
      for (final messages in results) {
        newMessages.addAll(messages);
      }

      // 与已有消息合并（不丢失旧数据）
      final merged = _stateService.mergeMessages(_allMessages, newMessages);
      _allMessages
        ..clear()
        ..addAll(merged);

      // 持久化合并后的全部消息
      await _stateService.saveMessages(_allMessages);

      // 根据渠道开关过滤并排序
      await _filterByEnabledChannels();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 根据渠道开关过滤消息并排序
  Future<void> _filterByEnabledChannels() async {
    final latestInfoEnabled = await _stateService.isLatestInfoEnabled();
    final noticeEnabled = await _stateService.isNoticeEnabled();
    final wechatPublicEnabled = await _stateService.isWechatPublicEnabled();
    final wechatServiceEnabled = await _stateService.isWechatServiceEnabled();

    // 过滤掉已关闭渠道的消息
    _allMessages.removeWhere((msg) {
      if (msg.category == MessageCategory.latestInfo && !latestInfoEnabled) {
        return true;
      }
      if (msg.category == MessageCategory.notice && !noticeEnabled) {
        return true;
      }
      if (msg.sourceType == MessageSourceType.wechatPublic &&
          !wechatPublicEnabled) {
        return true;
      }
      if (msg.sourceType == MessageSourceType.wechatService &&
          !wechatServiceEnabled) {
        return true;
      }
      return false;
    });

    // 按日期倒序排列
    _allMessages.sort((a, b) => b.date.compareTo(a.date));
    _applyFilters();
  }

  /// 弹出获取条数输入对话框
  /// 返回用户输入的条数，取消返回 null
  Future<int?> _showFetchCountDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<int?>(
      context: context,
      builder: (dialogContext) {
        return ContentDialog(
          title: const Text('获取消息条数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('输入每个栏目要获取的消息条数，留空默认 20 条。'),
              const SizedBox(height: 12),
              TextBox(
                controller: controller,
                placeholder: '20',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(dialogContext, null),
            ),
            FilledButton(
              child: const Text('确认'),
              onPressed: () {
                final text = controller.text.trim();
                final count =
                    text.isEmpty ? 20 : (int.tryParse(text) ?? 20);
                Navigator.pop(dialogContext, count.clamp(1, 200));
              },
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  /// 全部标为已读
  Future<void> _markAllRead() async {
    final allIds = _filteredMessages.map((msg) => msg.id).toList();
    await _stateService.markAllAsRead(allIds);
    setState(() {});
  }

  /// 应用搜索和筛选条件
  void _applyFilters() {
    _filteredMessages = _allMessages.where((msg) {
      // 搜索关键词过滤
      if (_searchQuery.isNotEmpty &&
          !msg.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // 来源类型筛选
      if (_filterSourceType != null &&
          msg.sourceType != _filterSourceType) {
        return false;
      }

      // 来源名称筛选
      if (_filterSourceName != null &&
          msg.sourceName != _filterSourceName) {
        return false;
      }

      // 内容分类筛选
      if (_filterCategory != null && msg.category != _filterCategory) {
        return false;
      }

      // 未读筛选
      if (_filterUnreadOnly && _stateService.isRead(msg.id)) {
        return false;
      }

      return true;
    }).toList();

    // 重置分页到首页
    _currentPage = 0;

    if (mounted) setState(() {});
  }

  /// 获取当前页的消息列表
  List<MessageItem> get _pagedMessages {
    final startIndex = _currentPage * _pageSize;
    final endIndex = min(startIndex + _pageSize, _filteredMessages.length);
    if (startIndex >= _filteredMessages.length) return [];
    return _filteredMessages.sublist(startIndex, endIndex);
  }

  /// 总页数
  int get _totalPages =>
      (_filteredMessages.length / _pageSize).ceil().clamp(1, 9999);

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
          ),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaffoldPage(
      header: const PageHeader(title: Text('信息中心')),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== 操作栏 ====================
            _buildActionBar(theme),
            const SizedBox(height: 12),

            // ==================== 搜索栏 ====================
            _buildSearchBar(theme),
            const SizedBox(height: 8),

            // ==================== 筛选栏 ====================
            _buildFilterBar(theme, isDark),
            const SizedBox(height: 12),

            // ==================== 消息列表 ====================
            Expanded(
              child: _isLoading
                  ? const Center(child: ProgressRing())
                  : _filteredMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FluentIcons.inbox,
                                size: 48,
                                color: theme.resources.textFillColorSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '暂无消息',
                                style: theme.typography.body?.copyWith(
                                  color:
                                      theme.resources.textFillColorSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '点击上方刷新按钮获取最新消息',
                                style: theme.typography.caption?.copyWith(
                                  color:
                                      theme.resources.textFillColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildMessageList(theme, isDark),
            ),

            // ==================== 分页栏 ====================
            if (_filteredMessages.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPagination(theme),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建操作栏：全部标为已读 + 刷新官网消息 + 刷新微信消息（占位）
  Widget _buildActionBar(FluentThemeData theme) {
    final unreadCount = _stateService.countUnread(
      _filteredMessages.map((msg) => msg.id).toList(),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 全部标为已读
        FilledButton(
          onPressed: _filteredMessages.isEmpty ? null : _markAllRead,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.read, size: 14),
              const SizedBox(width: 6),
              Text('全部标为已读${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
            ],
          ),
        ),
        // 刷新官网消息
        Button(
          onPressed: _isLoading ? null : () => _refreshSchoolWebsite(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 14),
              SizedBox(width: 6),
              Text('刷新官网消息'),
            ],
          ),
        ),
        // 刷新微信公众号/服务号消息（占位）
        Button(
          onPressed: null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 14),
              SizedBox(width: 6),
              Text('刷新微信公众号/服务号消息'),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(FluentThemeData theme) {
    return TextBox(
      controller: _searchController,
      placeholder: '搜索消息标题…',
      prefix: const Padding(
        padding: EdgeInsets.only(left: 8.0),
        child: Icon(FluentIcons.search, size: 14),
      ),
      suffix: _searchQuery.isNotEmpty
          ? IconButton(
              icon: const Icon(FluentIcons.clear, size: 12),
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                _applyFilters();
              },
            )
          : null,
      onChanged: (value) {
        _searchQuery = value;
        _applyFilters();
      },
    );
  }

  /// 构建筛选栏：来源类型 + 来源名称（级联） + 内容分类（级联） + 未读筛选
  Widget _buildFilterBar(FluentThemeData theme, bool isDark) {
    // 根据当前选中的来源类型，决定可选的来源名称
    final availableSourceNames = _getAvailableSourceNames();
    // 根据当前选中的来源名称，决定可选的内容分类
    final availableCategories = _getAvailableCategories();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 来源类型筛选
        _buildFilterCombo<MessageSourceType>(
          label: '来源类型',
          value: _filterSourceType,
          items: MessageSourceType.values,
          itemLabel: (item) => item.label,
          onChanged: (value) {
            _filterSourceType = value;
            // 级联重置：父级变化时清空子级选择
            _filterSourceName = null;
            _filterCategory = null;
            _applyFilters();
          },
        ),
        // 来源名称筛选（依赖来源类型）
        _buildFilterCombo<MessageSourceName>(
          label: '来源名称',
          value: _filterSourceName,
          items: availableSourceNames,
          itemLabel: (item) => item.label,
          onChanged: (value) {
            _filterSourceName = value;
            // 级联重置：来源名称变化时清空内容分类
            _filterCategory = null;
            _applyFilters();
          },
        ),
        // 内容分类筛选（依赖来源名称）
        _buildFilterCombo<MessageCategory>(
          label: '内容分类',
          value: _filterCategory,
          items: availableCategories,
          itemLabel: (item) => item.label,
          onChanged: (value) {
            _filterCategory = value;
            _applyFilters();
          },
        ),
        // 仅未读开关
        ToggleSwitch(
          checked: _filterUnreadOnly,
          content: const Text('仅未读'),
          onChanged: (value) {
            _filterUnreadOnly = value;
            _applyFilters();
          },
        ),
      ],
    );
  }

  /// 根据当前来源类型获取可选的来源名称列表
  List<MessageSourceName> _getAvailableSourceNames() {
    if (_filterSourceType == null) return MessageSourceName.values;
    switch (_filterSourceType!) {
      case MessageSourceType.schoolWebsite:
        return [MessageSourceName.infoDisclosure];
      case MessageSourceType.wechatPublic:
        return [MessageSourceName.wechatPublicPlaceholder];
      case MessageSourceType.wechatService:
        return [MessageSourceName.wechatServicePlaceholder];
    }
  }

  /// 根据当前来源名称获取可选的内容分类列表
  List<MessageCategory> _getAvailableCategories() {
    if (_filterSourceName == null) return MessageCategory.values;
    switch (_filterSourceName!) {
      case MessageSourceName.infoDisclosure:
        return [MessageCategory.latestInfo, MessageCategory.notice];
      case MessageSourceName.jwc:
        return [MessageCategory.jwcStudent, MessageCategory.jwcTeacher];
      case MessageSourceName.itc:
        return [MessageCategory.itcNews];
      case MessageSourceName.sspuOfficial:
        return [MessageCategory.sspuNotice, MessageCategory.sspuActivity];
      case MessageSourceName.sports:
        return [MessageCategory.sportsNotice, MessageCategory.sportsEvent];
      case MessageSourceName.securityDept:
        return [MessageCategory.securityNews, MessageCategory.securityEducation];
      case MessageSourceName.construction:
        return [MessageCategory.constructionNews, MessageCategory.constructionNotice];
      case MessageSourceName.newsCenter:
        return [MessageCategory.campusNews];
      case MessageSourceName.studentAffairs:
        return [MessageCategory.studentNews, MessageCategory.studentNotice];
      case MessageSourceName.wechatPublicPlaceholder:
        return [MessageCategory.wechatArticle];
      case MessageSourceName.wechatServicePlaceholder:
        return [MessageCategory.wechatArticle];
    }
  }

  /// 构建筛选下拉框通用方法
  Widget _buildFilterCombo<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return ComboBox<T?>(
      value: value,
      placeholder: Text(label),
      items: [
        ComboBoxItem<T?>(
          value: null,
          child: Text('全部$label'),
        ),
        ...items.map(
          (item) => ComboBoxItem<T?>(
            value: item,
            child: Text(itemLabel(item)),
          ),
        ),
      ],
      onChanged: (selectedValue) => onChanged(selectedValue),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(FluentThemeData theme, bool isDark) {
    final messages = _pagedMessages;

    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final message = messages[index];
        final isRead = _stateService.isRead(message.id);

        return MessageTile(
          message: message,
          isRead: isRead,
          isDark: isDark,
          theme: theme,
          onTap: () => _openMessage(message),
          onMarkRead: () async {
            await _stateService.markAsRead(message.id);
            setState(() {});
          },
        );
      },
    );
  }

  /// 构建分页导航栏
  Widget _buildPagination(FluentThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 上一页
        IconButton(
          icon: const Icon(FluentIcons.chevron_left, size: 12),
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
        ),
        const SizedBox(width: 8),
        // 页码信息
        Text(
          '第 ${_currentPage + 1} / $_totalPages 页  '
          '(共 ${_filteredMessages.length} 条)',
          style: theme.typography.caption,
        ),
        const SizedBox(width: 8),
        // 下一页
        IconButton(
          icon: const Icon(FluentIcons.chevron_right, size: 12),
          onPressed: _currentPage < _totalPages - 1
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }
}
