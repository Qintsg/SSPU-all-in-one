/*
 * 自动刷新服务 — 定时抓取各渠道消息并推送新消息通知
 * 每个渠道独立 Timer.periodic，间隔可在设置中分别调整
 * 后台运行（最小化到托盘时 Timer 继续执行）
 * @Project : SSPU-all-in-one
 * @File : auto_refresh_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/message_item.dart';
import 'message_state_service.dart';
import 'sspu_news_service.dart';
import 'jwc_news_service.dart';
import 'itc_news_service.dart';
import 'sspu_official_service.dart';
import 'sports_news_service.dart';
import 'security_news_service.dart';
import 'construction_news_service.dart';
import 'campus_news_service.dart';
import 'student_affairs_service.dart';
import 'college_news_service.dart';
import 'notification_service.dart';
import 'wechat_article_service.dart';

/// 自动刷新服务（单例）
/// 根据各渠道配置的间隔定时抓取新消息，发现新消息时推送系统通知
class AutoRefreshService {
  AutoRefreshService._();

  static final AutoRefreshService instance = AutoRefreshService._();

  final MessageStateService _stateService = MessageStateService.instance;
  final SspuNewsService _newsService = SspuNewsService.instance;
  final JwcNewsService _jwcService = JwcNewsService.instance;
  final ItcNewsService _itcService = ItcNewsService.instance;
  final SspuOfficialService _officialService = SspuOfficialService.instance;
  final SportsNewsService _sportsService = SportsNewsService.instance;
  final SecurityNewsService _securityService = SecurityNewsService.instance;
  final ConstructionNewsService _constructionService =
      ConstructionNewsService.instance;
  final CampusNewsService _campusService = CampusNewsService.instance;
  final StudentAffairsService _studentService = StudentAffairsService.instance;
  final CollegeNewsService _collegeService = CollegeNewsService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final WechatArticleService _wechatService = WechatArticleService.instance;

  /// 各渠道的定时器，key 为渠道标识
  final Map<String, Timer> _timers = {};

  /// 是否已初始化
  bool _initialized = false;

  /// 默认每次自动抓取的条数
  static const int _defaultFetchCount = 20;

  /// 设置页使用的逻辑渠道 ID 列表，用于全量重载时覆盖所有可配置渠道。
  static const List<String> _refreshChannelIds = [
    'latest_info',
    'notice',
    'jwc',
    'itc',
    'sspu_notice',
    'sspu_activity',
    'sports',
    'security_dept',
    'construction',
    'news_center',
    'student_affairs',
    'college_cs',
    'college_im',
    'college_re',
    'college_em',
    'college_ic',
    'college_imhe',
    'college_econ',
    'college_lang',
    'college_math',
    'college_art',
    'college_vte',
    'college_vt',
    'college_marx',
    'college_ce',
    'center_art_edu',
    'center_intl',
    'center_innov',
    'graduate',
    'lib_center',
    'wechat_public',
  ];

  /// 将设置页逻辑渠道 ID 映射到实际定时器 key。
  /// 多子栏目的渠道共用一个设置项，但需要重载多个抓取定时器。
  List<String> _timerKeysForChannel(String channelKey) {
    switch (channelKey) {
      case 'latest_info':
        return ['latestInfo'];
      case 'jwc':
        return ['jwcStudent', 'jwcTeacher'];
      case 'sspu_notice':
        return ['sspuNotice'];
      case 'sspu_activity':
        return ['sspuActivity'];
      case 'sports':
        return ['sportsNotice', 'sportsEvent'];
      case 'security_dept':
        return ['securityNews', 'securityEducation'];
      case 'construction':
        return ['constructionNews', 'constructionNotice'];
      case 'news_center':
        return ['campusNews'];
      case 'student_affairs':
        return ['studentNews', 'studentNotice'];
      case 'wechat_public':
        return ['wechatPublic'];
      default:
        return [channelKey];
    }
  }

  /// 测试入口：确认设置页渠道 ID 能正确映射到内部定时器 key。
  @visibleForTesting
  List<String> debugTimerKeysForChannel(String channelKey) {
    return List.unmodifiable(_timerKeysForChannel(channelKey));
  }

  /// 初始化并启动自动刷新
  /// 应在 app 启动时调用一次
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _stateService.init();
    await _notificationService.init();

    // 根据各渠道配置启动对应定时器
    await _setupTimer(
      channelKey: 'latestInfo',
      getInterval: _stateService.getLatestInfoInterval,
      isEnabled: _stateService.isLatestInfoEnabled,
      fetchMessages: (knownMessageIds) => _newsService.fetchLatestInfo(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    await _setupTimer(
      channelKey: 'notice',
      getInterval: _stateService.getNoticeInterval,
      isEnabled: _stateService.isNoticeEnabled,
      fetchMessages: (knownMessageIds) => _newsService.fetchNotices(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 教务处学生专栏
    await _setupTimer(
      channelKey: 'jwcStudent',
      getInterval: () => _stateService.getChannelInterval('jwc'),
      isEnabled: () => _stateService.isChannelEnabled('jwc'),
      fetchMessages: (knownMessageIds) => _jwcService.fetchStudentNews(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 教务处教师专栏
    await _setupTimer(
      channelKey: 'jwcTeacher',
      getInterval: () => _stateService.getChannelInterval('jwc'),
      isEnabled: () => _stateService.isChannelEnabled('jwc'),
      fetchMessages: (knownMessageIds) => _jwcService.fetchTeacherNews(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 信息技术中心
    await _setupTimer(
      channelKey: 'itc',
      getInterval: () => _stateService.getChannelInterval('itc'),
      isEnabled: () => _stateService.isChannelEnabled('itc'),
      fetchMessages: (knownMessageIds) => _itcService.fetchNews(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 学校官网通知公告
    await _setupTimer(
      channelKey: 'sspuNotice',
      getInterval: () => _stateService.getChannelInterval('sspu_notice'),
      isEnabled: () => _stateService.isChannelEnabled('sspu_notice'),
      fetchMessages: (knownMessageIds) => _officialService.fetchNotices(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 学校官网学术活动讲座
    await _setupTimer(
      channelKey: 'sspuActivity',
      getInterval: () => _stateService.getChannelInterval('sspu_activity'),
      isEnabled: () => _stateService.isChannelEnabled('sspu_activity'),
      fetchMessages: (knownMessageIds) => _officialService.fetchActivities(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 体育部通知公告
    await _setupTimer(
      channelKey: 'sportsNotice',
      getInterval: () => _stateService.getChannelInterval('sports'),
      isEnabled: () => _stateService.isChannelEnabled('sports'),
      fetchMessages: (knownMessageIds) => _sportsService.fetchNotices(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 体育部赛事通知
    await _setupTimer(
      channelKey: 'sportsEvent',
      getInterval: () => _stateService.getChannelInterval('sports'),
      isEnabled: () => _stateService.isChannelEnabled('sports'),
      fetchMessages: (knownMessageIds) => _sportsService.fetchEvents(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 保卫处平安动态
    await _setupTimer(
      channelKey: 'securityNews',
      getInterval: () => _stateService.getChannelInterval('security_dept'),
      isEnabled: () => _stateService.isChannelEnabled('security_dept'),
      fetchMessages: (knownMessageIds) => _securityService.fetchNews(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 保卫处宣教专栏
    await _setupTimer(
      channelKey: 'securityEducation',
      getInterval: () => _stateService.getChannelInterval('security_dept'),
      isEnabled: () => _stateService.isChannelEnabled('security_dept'),
      fetchMessages: (knownMessageIds) => _securityService.fetchEducation(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 校区建设办要闻
    await _setupTimer(
      channelKey: 'constructionNews',
      getInterval: () => _stateService.getChannelInterval('construction'),
      isEnabled: () => _stateService.isChannelEnabled('construction'),
      fetchMessages: (knownMessageIds) =>
          _constructionService.fetchNews(knownMessageIds: knownMessageIds),
    );

    // 校区建设办通知
    await _setupTimer(
      channelKey: 'constructionNotice',
      getInterval: () => _stateService.getChannelInterval('construction'),
      isEnabled: () => _stateService.isChannelEnabled('construction'),
      fetchMessages: (knownMessageIds) =>
          _constructionService.fetchNotices(knownMessageIds: knownMessageIds),
    );

    // 新闻网综合新闻
    await _setupTimer(
      channelKey: 'campusNews',
      getInterval: () => _stateService.getChannelInterval('news_center'),
      isEnabled: () => _stateService.isChannelEnabled('news_center'),
      fetchMessages: (knownMessageIds) =>
          _campusService.fetchCampusNews(knownMessageIds: knownMessageIds),
    );

    // 学生处学工要闻
    await _setupTimer(
      channelKey: 'studentNews',
      getInterval: () => _stateService.getChannelInterval('student_affairs'),
      isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
      fetchMessages: (knownMessageIds) =>
          _studentService.fetchNews(knownMessageIds: knownMessageIds),
    );

    // 学生处通知公告
    await _setupTimer(
      channelKey: 'studentNotice',
      getInterval: () => _stateService.getChannelInterval('student_affairs'),
      isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
      fetchMessages: (knownMessageIds) =>
          _studentService.fetchNotices(knownMessageIds: knownMessageIds),
    );

    // ==================== 教学单位渠道（19个学院/部门） ====================
    // 所有学院共用 CollegeNewsService，通过 channelId 区分解析配置
    final collegeChannelIds = [
      'college_cs',
      'college_im',
      'college_re',
      'college_em',
      'college_ic',
      'college_imhe',
      'college_econ',
      'college_lang',
      'college_math',
      'college_art',
      'college_vte',
      'college_vt',
      'college_marx',
      'college_ce',
      'center_art_edu',
      'center_intl',
      'center_innov',
      'graduate',
      'lib_center',
    ];
    for (final channelId in collegeChannelIds) {
      await _setupTimer(
        channelKey: channelId,
        getInterval: () => _stateService.getChannelInterval(channelId),
        isEnabled: () => _stateService.isChannelEnabled(channelId),
        fetchMessages: (knownMessageIds) => _collegeService.fetchNews(
          channelId,
          knownMessageIds: knownMessageIds,
        ),
      );
    }

    // 微信公众号渠道（通过微信读书 API）
    await _setupTimer(
      channelKey: 'wechatPublic',
      getInterval: () => _stateService.getChannelInterval('wechat_public'),
      isEnabled: () => _stateService.isChannelEnabled('wechat_public'),
      fetchMessages: (knownMessageIds) => _wechatService.fetchArticles(
        maxCount: _defaultFetchCount,
        knownMessageIds: knownMessageIds,
      ),
    );

    // 微信服务号占位 — 未来接入时取消注释
    // await _setupTimer(channelKey: 'wechatService', ...);
  }

  /// 立即抓取所有已启用官网/信息中心渠道的消息并返回合并结果
  /// 用于“刷新官网消息”按钮，不包含微信公众号渠道
  /// [maxCount] 支持 maxCount 参数的服务使用此值
  /// :return: 所有已启用官网/信息中心渠道的消息列表
  Future<List<MessageItem>> fetchEnabledSchoolWebsiteMessages({
    int maxCount = 20,
  }) async {
    final futures = <Future<List<MessageItem>>>[];
    final existingMessages = await _stateService.loadMessages();
    final knownMessageIds = existingMessages.map((msg) => msg.id).toSet();

    // 信息公开网
    if (await _stateService.isLatestInfoEnabled()) {
      futures.add(
        _newsService.fetchLatestInfo(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isNoticeEnabled()) {
      futures.add(
        _newsService.fetchNotices(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }

    // 职能部门
    if (await _stateService.isChannelEnabled('jwc')) {
      futures.add(
        _jwcService.fetchStudentNews(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
      futures.add(
        _jwcService.fetchTeacherNews(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isChannelEnabled('itc')) {
      futures.add(
        _itcService.fetchNews(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isChannelEnabled('sspu_notice')) {
      futures.add(
        _officialService.fetchNotices(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isChannelEnabled('sspu_activity')) {
      futures.add(
        _officialService.fetchActivities(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isChannelEnabled('sports')) {
      futures.add(
        _sportsService.fetchNotices(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
      futures.add(
        _sportsService.fetchEvents(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isChannelEnabled('security_dept')) {
      futures.add(
        _securityService.fetchNews(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
      futures.add(
        _securityService.fetchEducation(
          maxCount: maxCount,
          knownMessageIds: knownMessageIds,
        ),
      );
    }
    if (await _stateService.isChannelEnabled('construction')) {
      futures.add(
        _constructionService.fetchNews(knownMessageIds: knownMessageIds),
      );
      futures.add(
        _constructionService.fetchNotices(knownMessageIds: knownMessageIds),
      );
    }
    if (await _stateService.isChannelEnabled('news_center')) {
      futures.add(
        _campusService.fetchCampusNews(knownMessageIds: knownMessageIds),
      );
    }
    if (await _stateService.isChannelEnabled('student_affairs')) {
      futures.add(_studentService.fetchNews(knownMessageIds: knownMessageIds));
      futures.add(
        _studentService.fetchNotices(knownMessageIds: knownMessageIds),
      );
    }

    // 教学单位（19个学院/部门）
    const collegeIds = [
      'college_cs',
      'college_im',
      'college_re',
      'college_em',
      'college_ic',
      'college_imhe',
      'college_econ',
      'college_lang',
      'college_math',
      'college_art',
      'college_vte',
      'college_vt',
      'college_marx',
      'college_ce',
      'center_art_edu',
      'center_intl',
      'center_innov',
      'graduate',
      'lib_center',
    ];
    for (final id in collegeIds) {
      if (await _stateService.isChannelEnabled(id)) {
        futures.add(
          _collegeService.fetchNews(id, knownMessageIds: knownMessageIds),
        );
      }
    }

    if (futures.isEmpty) return [];

    // 并行执行，单个渠道异常不影响其他渠道
    final results = await Future.wait(
      futures.map((f) => f.catchError((_) => <MessageItem>[])),
    );
    return results.expand((msgs) => msgs).toList();
  }

  /// 配置并启动单个渠道的定时器
  /// [channelKey] 渠道标识（用作 Timer map 的 key）
  /// [getInterval] 获取当前间隔（分钟）的异步方法
  /// [isEnabled] 检查渠道是否启用的异步方法
  /// [fetchMessages] 抓取该渠道消息的异步方法
  Future<void> _setupTimer({
    required String channelKey,
    required Future<int> Function() getInterval,
    required Future<bool> Function() isEnabled,
    required Future<List<MessageItem>> Function(Set<String> knownMessageIds)
    fetchMessages,
  }) async {
    // 先取消已有定时器
    _timers[channelKey]?.cancel();
    _timers.remove(channelKey);

    final enabled = await isEnabled();
    final intervalMinutes = await getInterval();

    // 渠道未启用或间隔为 0（关闭）则不启动
    if (!enabled || intervalMinutes <= 0) return;

    final duration = Duration(minutes: intervalMinutes);

    _timers[channelKey] = Timer.periodic(duration, (_) async {
      await _doRefresh(channelKey, fetchMessages);
    });
  }

  /// 执行单次刷新：抓取 → 对比 → 合并持久化 → 推送新消息通知
  /// [channelKey] 渠道标识（用于日志）
  /// [fetchMessages] 抓取消息的方法
  Future<void> _doRefresh(
    String channelKey,
    Future<List<MessageItem>> Function(Set<String> knownMessageIds)
    fetchMessages,
  ) async {
    try {
      // 加载已有消息
      final existingMessages = await _stateService.loadMessages();
      final existingIds = existingMessages.map((m) => m.id).toSet();

      // 抓取新消息
      final fetched = await fetchMessages(existingIds);

      // 找出真正的新消息（ID 不在已有集合中）
      final newMessages = fetched
          .where((m) => !existingIds.contains(m.id))
          .toList();

      if (newMessages.isEmpty) return;

      // 合并并持久化
      final merged = _stateService.mergeMessages(existingMessages, fetched);
      await _stateService.saveMessages(merged);

      // 推送系统通知（检查全局开关和勿扰时段）
      final notifEnabled = await _stateService.isNotificationEnabled();
      final inDnd = await _stateService.isInDndPeriod();
      if (notifEnabled && !inDnd && _notificationService.isAvailable) {
        // 过滤掉单个公众号通知关闭的消息
        final notifiableMessages = <MessageItem>[];
        for (final msg in newMessages) {
          if (msg.mpBookId != null) {
            final mpEnabled = await _stateService.isMpNotificationEnabled(
              msg.mpBookId!,
            );
            if (!mpEnabled) continue;
          }
          notifiableMessages.add(msg);
        }

        if (notifiableMessages.length == 1) {
          await _notificationService.show(
            title: '新消息',
            body: notifiableMessages.first.title,
          );
        } else if (notifiableMessages.length > 1) {
          await _notificationService.show(
            title: '${notifiableMessages.length} 条新消息',
            body: notifiableMessages.take(3).map((m) => m.title).join('\n'),
          );
        }
      }
    } catch (_) {
      // 静默失败，下次定时器触发会重试
    }
  }

  /// 重新加载某个渠道的定时器配置。
  /// [channelKey] 可传设置页渠道 ID，也可传内部定时器 key。
  Future<void> reloadChannel(String channelKey) async {
    final timerKeys = _timerKeysForChannel(channelKey);
    if (timerKeys.length != 1 || timerKeys.single != channelKey) {
      for (final timerKey in timerKeys) {
        await reloadChannel(timerKey);
      }
      return;
    }

    switch (channelKey) {
      case 'latestInfo':
        await _setupTimer(
          channelKey: 'latestInfo',
          getInterval: _stateService.getLatestInfoInterval,
          isEnabled: _stateService.isLatestInfoEnabled,
          fetchMessages: (knownMessageIds) => _newsService.fetchLatestInfo(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'notice':
        await _setupTimer(
          channelKey: 'notice',
          getInterval: _stateService.getNoticeInterval,
          isEnabled: _stateService.isNoticeEnabled,
          fetchMessages: (knownMessageIds) => _newsService.fetchNotices(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'jwcStudent':
        await _setupTimer(
          channelKey: 'jwcStudent',
          getInterval: () => _stateService.getChannelInterval('jwc'),
          isEnabled: () => _stateService.isChannelEnabled('jwc'),
          fetchMessages: (knownMessageIds) => _jwcService.fetchStudentNews(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'jwcTeacher':
        await _setupTimer(
          channelKey: 'jwcTeacher',
          getInterval: () => _stateService.getChannelInterval('jwc'),
          isEnabled: () => _stateService.isChannelEnabled('jwc'),
          fetchMessages: (knownMessageIds) => _jwcService.fetchTeacherNews(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'itc':
        await _setupTimer(
          channelKey: 'itc',
          getInterval: () => _stateService.getChannelInterval('itc'),
          isEnabled: () => _stateService.isChannelEnabled('itc'),
          fetchMessages: (knownMessageIds) => _itcService.fetchNews(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'sspuNotice':
        await _setupTimer(
          channelKey: 'sspuNotice',
          getInterval: () => _stateService.getChannelInterval('sspu_notice'),
          isEnabled: () => _stateService.isChannelEnabled('sspu_notice'),
          fetchMessages: (knownMessageIds) => _officialService.fetchNotices(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'sspuActivity':
        await _setupTimer(
          channelKey: 'sspuActivity',
          getInterval: () => _stateService.getChannelInterval('sspu_activity'),
          isEnabled: () => _stateService.isChannelEnabled('sspu_activity'),
          fetchMessages: (knownMessageIds) => _officialService.fetchActivities(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'sportsNotice':
        await _setupTimer(
          channelKey: 'sportsNotice',
          getInterval: () => _stateService.getChannelInterval('sports'),
          isEnabled: () => _stateService.isChannelEnabled('sports'),
          fetchMessages: (knownMessageIds) => _sportsService.fetchNotices(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'sportsEvent':
        await _setupTimer(
          channelKey: 'sportsEvent',
          getInterval: () => _stateService.getChannelInterval('sports'),
          isEnabled: () => _stateService.isChannelEnabled('sports'),
          fetchMessages: (knownMessageIds) => _sportsService.fetchEvents(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'securityNews':
        await _setupTimer(
          channelKey: 'securityNews',
          getInterval: () => _stateService.getChannelInterval('security_dept'),
          isEnabled: () => _stateService.isChannelEnabled('security_dept'),
          fetchMessages: (knownMessageIds) => _securityService.fetchNews(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'securityEducation':
        await _setupTimer(
          channelKey: 'securityEducation',
          getInterval: () => _stateService.getChannelInterval('security_dept'),
          isEnabled: () => _stateService.isChannelEnabled('security_dept'),
          fetchMessages: (knownMessageIds) => _securityService.fetchEducation(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'constructionNews':
        await _setupTimer(
          channelKey: 'constructionNews',
          getInterval: () => _stateService.getChannelInterval('construction'),
          isEnabled: () => _stateService.isChannelEnabled('construction'),
          fetchMessages: (knownMessageIds) =>
              _constructionService.fetchNews(knownMessageIds: knownMessageIds),
        );
        break;
      case 'constructionNotice':
        await _setupTimer(
          channelKey: 'constructionNotice',
          getInterval: () => _stateService.getChannelInterval('construction'),
          isEnabled: () => _stateService.isChannelEnabled('construction'),
          fetchMessages: (knownMessageIds) => _constructionService.fetchNotices(
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      case 'campusNews':
        await _setupTimer(
          channelKey: 'campusNews',
          getInterval: () => _stateService.getChannelInterval('news_center'),
          isEnabled: () => _stateService.isChannelEnabled('news_center'),
          fetchMessages: (knownMessageIds) =>
              _campusService.fetchCampusNews(knownMessageIds: knownMessageIds),
        );
        break;
      case 'studentNews':
        await _setupTimer(
          channelKey: 'studentNews',
          getInterval: () =>
              _stateService.getChannelInterval('student_affairs'),
          isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
          fetchMessages: (knownMessageIds) =>
              _studentService.fetchNews(knownMessageIds: knownMessageIds),
        );
        break;
      case 'studentNotice':
        await _setupTimer(
          channelKey: 'studentNotice',
          getInterval: () =>
              _stateService.getChannelInterval('student_affairs'),
          isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
          fetchMessages: (knownMessageIds) =>
              _studentService.fetchNotices(knownMessageIds: knownMessageIds),
        );
        break;
      // 教学单位渠道（19个学院/部门，统一处理）
      case 'college_cs':
      case 'college_im':
      case 'college_re':
      case 'college_em':
      case 'college_ic':
      case 'college_imhe':
      case 'college_econ':
      case 'college_lang':
      case 'college_math':
      case 'college_art':
      case 'college_vte':
      case 'college_vt':
      case 'college_marx':
      case 'college_ce':
      case 'center_art_edu':
      case 'center_intl':
      case 'center_innov':
      case 'graduate':
      case 'lib_center':
        await _setupTimer(
          channelKey: channelKey,
          getInterval: () => _stateService.getChannelInterval(channelKey),
          isEnabled: () => _stateService.isChannelEnabled(channelKey),
          fetchMessages: (knownMessageIds) => _collegeService.fetchNews(
            channelKey,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      // 微信公众号渠道
      case 'wechatPublic':
        await _setupTimer(
          channelKey: 'wechatPublic',
          getInterval: () => _stateService.getChannelInterval('wechat_public'),
          isEnabled: () => _stateService.isChannelEnabled('wechat_public'),
          fetchMessages: (knownMessageIds) => _wechatService.fetchArticles(
            maxCount: _defaultFetchCount,
            knownMessageIds: knownMessageIds,
          ),
        );
        break;
      // 其他渠道占位
      default:
        break;
    }
  }

  /// 重新加载所有渠道定时器
  /// 适用于应用恢复前台或全局刷新设置后
  Future<void> reloadAll() async {
    for (final channelId in _refreshChannelIds) {
      await reloadChannel(channelId);
    }
  }

  /// 销毁所有定时器
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _initialized = false;
  }
}
