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

  /// 自动刷新服务（用于手动全渠道刷新）
  final AutoRefreshService _autoRefreshService = AutoRefreshService.instance;

  /// 消息分类 → 渠道配置 ID 映射表，用于根据渠道开关过滤消息
  static const Map<MessageCategory, String> _categoryToChannelId = {
    MessageCategory.latestInfo: 'latest_info',
    MessageCategory.notice: 'notice',
    MessageCategory.jwcTeaching: 'jwc',
    MessageCategory.jwcStudent: 'jwc',
    MessageCategory.jwcTeacher: 'jwc',
    MessageCategory.itcNews: 'itc',
    MessageCategory.sspuNews: 'sspu_news',
    MessageCategory.sspuNotice: 'sspu_notice',
    MessageCategory.sspuActivity: 'sspu_activity',
    MessageCategory.sportsNotice: 'sports',
    MessageCategory.sportsEvent: 'sports',
    MessageCategory.securityNews: 'security_dept',
    MessageCategory.securityEducation: 'security_dept',
    MessageCategory.constructionNews: 'construction',
    MessageCategory.constructionNotice: 'construction',
    MessageCategory.campusNews: 'news_center',
    MessageCategory.studentNews: 'student_affairs',
    MessageCategory.studentNotice: 'student_affairs',
    MessageCategory.collegeCsNews: 'college_cs',
    MessageCategory.collegeCsTeacherWork: 'college_cs',
    MessageCategory.collegeCsStudentWork: 'college_cs',
    MessageCategory.collegeImNews: 'college_im',
    MessageCategory.collegeImTeachingResearch: 'college_im',
    MessageCategory.collegeImNotice: 'college_im',
    MessageCategory.collegeReNews: 'college_re',
    MessageCategory.collegeReNotice: 'college_re',
    MessageCategory.collegeReResearchService: 'college_re',
    MessageCategory.collegeRePartyIdeology: 'college_re',
    MessageCategory.collegeEmNews: 'college_em',
    MessageCategory.collegeEmNotice: 'college_em',
    MessageCategory.collegeEmStudentDevelopment: 'college_em',
    MessageCategory.collegeEmResearch: 'college_em',
    MessageCategory.collegeIcNews: 'college_ic',
    MessageCategory.collegeImheNews: 'college_imhe',
    MessageCategory.collegeEconNews: 'college_econ',
    MessageCategory.collegeLangNews: 'college_lang',
    MessageCategory.collegeMathNews: 'college_math',
    MessageCategory.collegeArtNews: 'college_art',
    MessageCategory.collegeVteNews: 'college_vte',
    MessageCategory.collegeVtNews: 'college_vt',
    MessageCategory.collegeMarxNews: 'college_marx',
    MessageCategory.collegeCeNews: 'college_ce',
    MessageCategory.centerArtEduNews: 'center_art_edu',
    MessageCategory.centerIntlNews: 'center_intl',
    MessageCategory.centerInnovNews: 'center_innov',
    MessageCategory.graduateNews: 'graduate',
    MessageCategory.libCenterNews: 'lib_center',
  };

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

  /// 刷新官网消息：抓取所有已启用渠道的新数据并与已有数据合并持久化
  /// [maxCount] 每个栏目获取的条数，null 则弹出输入框
  Future<void> _refreshSchoolWebsite({int? maxCount}) async {
    // 弹出条数选择对话框
    final count = maxCount ?? await _showFetchCountDialog();
    if (count == null) return;

    setState(() => _isLoading = true);

    try {
      // 仅抓取官网/信息中心渠道，避免将微信公众号刷新串进官网刷新链路。
      final newMessages = await _autoRefreshService
          .fetchEnabledSchoolWebsiteMessages(maxCount: count);

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

  /// 刷新微信公众号文章：通过 WechatArticleService 获取已关注公众号的推文
  Future<void> _refreshWechatArticles() async {
    setState(() => _isLoading = true);

    try {
      final persistedMessages = await _stateService.loadMessages();
      final articles = await WechatArticleService.instance.fetchArticles(
        maxCount: 50,
        knownMessageIds: persistedMessages.map((msg) => msg.id).toSet(),
      );

      if (articles.isEmpty) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (ctx, close) {
              return InfoBar(
                title: const Text('未获取到微信公众号文章'),
                content: const Text('请确认已在设置中配置微信读书 Cookie 并关注公众号'),
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
      _allMessages
        ..clear()
        ..addAll(merged);

      // 持久化
      await _stateService.saveMessages(_allMessages);

      // 过滤并排序
      await _filterByEnabledChannels();

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
        setState(() => _isLoading = false);
      }
    }
  }

  /// 根据渠道开关过滤消息并排序
  /// 通过 _categoryToChannelId 映射表统一检查所有渠道的启用状态
  Future<void> _filterByEnabledChannels() async {
    // 预加载所有渠道的启用状态，避免逾历每条消息时重复读取存储
    final allConfigs = [...departmentChannels, ...teachingChannels];
    final enabledCache = <String, bool>{};
    for (final config in allConfigs) {
      enabledCache[config.id] = await _stateService.isChannelEnabled(
        config.id,
        defaultValue: config.defaultEnabled,
      );
    }

    // 预加载子分类启用状态（仅有多子分类的渠道）
    final categoryEnabledCache = <String, bool>{};
    for (final entry in channelSubcategories.entries) {
      for (final sub in entry.value) {
        categoryEnabledCache[sub.category.name] = await _stateService
            .isCategoryEnabled(sub.category.name);
      }
    }

    // 微信渠道单独检查（使用专有方法）
    final wechatPublicEnabled = await _stateService.isWechatPublicEnabled();
    final wechatServiceEnabled = await _stateService.isWechatServiceEnabled();

    // 预加载单个公众号通知开关状态（用于 per-mp 过滤）
    final mpEnabledCache = <String, bool>{};
    for (final msg in _allMessages) {
      if (msg.mpBookId != null && !mpEnabledCache.containsKey(msg.mpBookId)) {
        mpEnabledCache[msg.mpBookId!] = await _stateService
            .isMpNotificationEnabled(msg.mpBookId!);
      }
    }

    // 过滤掉已关闭渠道的消息
    _allMessages.removeWhere((msg) {
      // 微信渠道按 sourceType 判断
      if (msg.sourceType == MessageSourceType.wechatPublic) {
        if (!wechatPublicEnabled) return true;
        // 渠道启用时进一步检查单个公众号开关
        if (msg.mpBookId != null) {
          return !(mpEnabledCache[msg.mpBookId] ?? true);
        }
        return false;
      }
      if (msg.sourceType == MessageSourceType.wechatService) {
        return !wechatServiceEnabled;
      }

      // 其他渠道按 category → channelId 映射判断
      final channelId = _categoryToChannelId[msg.category];
      if (channelId != null) {
        // 渠道级检查 — 渠道关闭则直接过滤
        if (!(enabledCache[channelId] ?? false)) return true;
        // 子分类级检查 — 渠道启用但子分类关闭时过滤
        final catName = msg.category.name;
        if (categoryEnabledCache.containsKey(catName)) {
          return !categoryEnabledCache[catName]!;
        }
        return false;
      }

      // 未在映射表中的分类保留显示
      return false;
    });

    // 按时间倒序排列（将所有消息统一转为毫秒时间戳比较）
    _allMessages.sort((a, b) {
      final tsA = a.timestamp ?? _dateToTimestamp(a.date);
      final tsB = b.timestamp ?? _dateToTimestamp(b.date);
      return tsB.compareTo(tsA);
    });
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
              const SizedBox(height: FluentSpacing.m),
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
                final count = text.isEmpty ? 20 : (int.tryParse(text) ?? 20);
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

  /// 将 YYYY-MM-DD 日期字符串转为毫秒时间戳（当天 00:00）
  int _dateToTimestamp(String date) {
    try {
      final dt = DateTime.parse(date);
      return dt.millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
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
      if (_filterSourceType != null && msg.sourceType != _filterSourceType) {
        return false;
      }

      // 来源名称筛选
      if (_filterSourceName != null && msg.sourceName != _filterSourceName) {
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
            webViewEnvironment: globalWebViewEnvironment,
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
            const SizedBox(height: FluentSpacing.m),

            // ==================== 搜索栏 ====================
            _buildSearchBar(theme),
            const SizedBox(height: FluentSpacing.s),

            // ==================== 筛选栏 ====================
            _buildFilterBar(theme, isDark).animate().fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            ),
            const SizedBox(height: FluentSpacing.m),

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
                          const SizedBox(height: FluentSpacing.m),
                          Text(
                            '暂无消息',
                            style: theme.typography.body?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                          const SizedBox(height: FluentSpacing.s),
                          Text(
                            '点击上方刷新按钮获取最新消息',
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildMessageList(theme, isDark),
            ),

            // ==================== 分页栏 ====================
            if (_filteredMessages.isNotEmpty) ...[
              const SizedBox(height: FluentSpacing.s),
              _buildPagination(theme),
              const SizedBox(height: FluentSpacing.m),
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
              const SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
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
              SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
              Text('刷新官网消息'),
            ],
          ),
        ),
        // 刷新微信公众号/服务号消息
        Button(
          onPressed: _isLoading ? null : _refreshWechatArticles,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 14),
              SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
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
        return [
          MessageSourceName.infoDisclosure,
          MessageSourceName.jwc,
          MessageSourceName.itc,
          MessageSourceName.sspuOfficial,
          MessageSourceName.sports,
          MessageSourceName.securityDept,
          MessageSourceName.construction,
          MessageSourceName.newsCenter,
          MessageSourceName.studentAffairs,
          MessageSourceName.collegeCs,
          MessageSourceName.collegeIm,
          MessageSourceName.collegeRe,
          MessageSourceName.collegeEm,
          MessageSourceName.collegeIc,
          MessageSourceName.collegeImhe,
          MessageSourceName.collegeEcon,
          MessageSourceName.collegeLang,
          MessageSourceName.collegeMath,
          MessageSourceName.collegeArt,
          MessageSourceName.collegeVte,
          MessageSourceName.collegeVt,
          MessageSourceName.collegeMarx,
          MessageSourceName.collegeCe,
          MessageSourceName.centerArtEdu,
          MessageSourceName.centerIntl,
          MessageSourceName.centerInnov,
          MessageSourceName.graduate,
          MessageSourceName.libCenter,
        ];
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
        return [
          MessageCategory.jwcTeaching,
          MessageCategory.jwcStudent,
          MessageCategory.jwcTeacher,
        ];
      case MessageSourceName.itc:
        return [MessageCategory.itcNews];
      case MessageSourceName.sspuOfficial:
        return [
          MessageCategory.sspuNews,
          MessageCategory.sspuNotice,
          MessageCategory.sspuActivity,
        ];
      case MessageSourceName.sports:
        return [MessageCategory.sportsNotice, MessageCategory.sportsEvent];
      case MessageSourceName.securityDept:
        return [
          MessageCategory.securityNews,
          MessageCategory.securityEducation,
        ];
      case MessageSourceName.construction:
        return [
          MessageCategory.constructionNews,
          MessageCategory.constructionNotice,
        ];
      case MessageSourceName.newsCenter:
        return [MessageCategory.campusNews];
      case MessageSourceName.studentAffairs:
        return [MessageCategory.studentNews, MessageCategory.studentNotice];
      case MessageSourceName.wechatPublicPlaceholder:
        return [MessageCategory.wechatArticle];
      case MessageSourceName.wechatServicePlaceholder:
        return [MessageCategory.wechatArticle];
      // 教学单位渠道 — 部分学院会把多个站点栏目聚合为多个分类
      case MessageSourceName.collegeCs:
        return [
          MessageCategory.collegeCsNews,
          MessageCategory.collegeCsTeacherWork,
          MessageCategory.collegeCsStudentWork,
        ];
      case MessageSourceName.collegeIm:
        return [
          MessageCategory.collegeImNews,
          MessageCategory.collegeImTeachingResearch,
          MessageCategory.collegeImNotice,
        ];
      case MessageSourceName.collegeRe:
        return [
          MessageCategory.collegeReNews,
          MessageCategory.collegeReNotice,
          MessageCategory.collegeReResearchService,
          MessageCategory.collegeRePartyIdeology,
        ];
      case MessageSourceName.collegeEm:
        return [
          MessageCategory.collegeEmNews,
          MessageCategory.collegeEmNotice,
          MessageCategory.collegeEmStudentDevelopment,
          MessageCategory.collegeEmResearch,
        ];
      case MessageSourceName.collegeIc:
        return [MessageCategory.collegeIcNews];
      case MessageSourceName.collegeImhe:
        return [MessageCategory.collegeImheNews];
      case MessageSourceName.collegeEcon:
        return [MessageCategory.collegeEconNews];
      case MessageSourceName.collegeLang:
        return [MessageCategory.collegeLangNews];
      case MessageSourceName.collegeMath:
        return [MessageCategory.collegeMathNews];
      case MessageSourceName.collegeArt:
        return [MessageCategory.collegeArtNews];
      case MessageSourceName.collegeVte:
        return [MessageCategory.collegeVteNews];
      case MessageSourceName.collegeVt:
        return [MessageCategory.collegeVtNews];
      case MessageSourceName.collegeMarx:
        return [MessageCategory.collegeMarxNews];
      case MessageSourceName.collegeCe:
        return [MessageCategory.collegeCeNews];
      case MessageSourceName.centerArtEdu:
        return [MessageCategory.centerArtEduNews];
      case MessageSourceName.centerIntl:
        return [MessageCategory.centerIntlNews];
      case MessageSourceName.centerInnov:
        return [MessageCategory.centerInnovNews];
      case MessageSourceName.graduate:
        return [MessageCategory.graduateNews];
      case MessageSourceName.libCenter:
        return [MessageCategory.libCenterNews];
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
        ComboBoxItem<T?>(value: null, child: Text('全部$label')),
        ...items.map(
          (item) => ComboBoxItem<T?>(value: item, child: Text(itemLabel(item))),
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
        const SizedBox(width: FluentSpacing.s),
        // 页码信息（可点击弹出跳转输入框）
        Tooltip(
          message: '点击跳转到指定页',
          child: HoverButton(
            onPressed: () => _showPageJumpDialog(),
            builder: (context, states) {
              return Text(
                '第 ${_currentPage + 1} / $_totalPages 页  '
                '(共 ${_filteredMessages.length} 条)',
                style: theme.typography.caption?.copyWith(
                  decoration: states.isHovered
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: FluentSpacing.s),
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

  /// 弹出页码跳转对话框
  /// 用户输入目标页码后直接跳转
  Future<void> _showPageJumpDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('跳转到指定页'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前第 ${_currentPage + 1} 页，共 $_totalPages 页'),
            const SizedBox(height: FluentSpacing.s),
            TextBox(
              controller: controller,
              placeholder: '输入页码 (1-$_totalPages)',
              keyboardType: TextInputType.number,
              autofocus: true,
              onSubmitted: (_) {
                // 回车确认
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= _totalPages) {
                  Navigator.of(ctx).pop(page - 1);
                }
              },
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            child: const Text('跳转'),
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.of(ctx).pop(page - 1);
              }
            },
          ),
        ],
      ),
    );
    controller.dispose();
    // 执行跳转
    if (result != null && mounted) {
      setState(() => _currentPage = result);
    }
  }
}
