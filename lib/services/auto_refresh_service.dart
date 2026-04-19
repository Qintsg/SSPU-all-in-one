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
  final ConstructionNewsService _constructionService = ConstructionNewsService.instance;
  final CampusNewsService _campusService = CampusNewsService.instance;
  final StudentAffairsService _studentService = StudentAffairsService.instance;
  final CollegeNewsService _collegeService = CollegeNewsService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  /// 各渠道的定时器，key 为渠道标识
  final Map<String, Timer> _timers = {};

  /// 是否已初始化
  bool _initialized = false;

  /// 默认每次自动抓取的条数
  static const int _defaultFetchCount = 20;

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
      fetchMessages: () => _newsService.fetchLatestInfo(
        maxCount: _defaultFetchCount,
      ),
    );

    await _setupTimer(
      channelKey: 'notice',
      getInterval: _stateService.getNoticeInterval,
      isEnabled: _stateService.isNoticeEnabled,
      fetchMessages: () => _newsService.fetchNotices(
        maxCount: _defaultFetchCount,
      ),
    );

    // 教务处学生专栏
    await _setupTimer(
      channelKey: 'jwcStudent',
      getInterval: () => _stateService.getChannelInterval('jwc'),
      isEnabled: () => _stateService.isChannelEnabled('jwc'),
      fetchMessages: () => _jwcService.fetchStudentNews(
        maxCount: _defaultFetchCount,
      ),
    );

    // 教务处教师专栏
    await _setupTimer(
      channelKey: 'jwcTeacher',
      getInterval: () => _stateService.getChannelInterval('jwc'),
      isEnabled: () => _stateService.isChannelEnabled('jwc'),
      fetchMessages: () => _jwcService.fetchTeacherNews(
        maxCount: _defaultFetchCount,
      ),
    );

    // 信息技术中心
    await _setupTimer(
      channelKey: 'itc',
      getInterval: () => _stateService.getChannelInterval('itc'),
      isEnabled: () => _stateService.isChannelEnabled('itc'),
      fetchMessages: () => _itcService.fetchNews(
        maxCount: _defaultFetchCount,
      ),
    );

    // 学校官网通知公告
    await _setupTimer(
      channelKey: 'sspuNotice',
      getInterval: () => _stateService.getChannelInterval('sspu_notice'),
      isEnabled: () => _stateService.isChannelEnabled('sspu_notice'),
      fetchMessages: () => _officialService.fetchNotices(
        maxCount: _defaultFetchCount,
      ),
    );

    // 学校官网学术活动讲座
    await _setupTimer(
      channelKey: 'sspuActivity',
      getInterval: () => _stateService.getChannelInterval('sspu_activity'),
      isEnabled: () => _stateService.isChannelEnabled('sspu_activity'),
      fetchMessages: () => _officialService.fetchActivities(
        maxCount: _defaultFetchCount,
      ),
    );

    // 体育部通知公告
    await _setupTimer(
      channelKey: 'sportsNotice',
      getInterval: () => _stateService.getChannelInterval('sports'),
      isEnabled: () => _stateService.isChannelEnabled('sports'),
      fetchMessages: () => _sportsService.fetchNotices(
        maxCount: _defaultFetchCount,
      ),
    );

    // 体育部赛事通知
    await _setupTimer(
      channelKey: 'sportsEvent',
      getInterval: () => _stateService.getChannelInterval('sports'),
      isEnabled: () => _stateService.isChannelEnabled('sports'),
      fetchMessages: () => _sportsService.fetchEvents(
        maxCount: _defaultFetchCount,
      ),
    );

    // 保卫处平安动态
    await _setupTimer(
      channelKey: 'securityNews',
      getInterval: () => _stateService.getChannelInterval('security_dept'),
      isEnabled: () => _stateService.isChannelEnabled('security_dept'),
      fetchMessages: () => _securityService.fetchNews(
        maxCount: _defaultFetchCount,
      ),
    );

    // 保卫处宣教专栏
    await _setupTimer(
      channelKey: 'securityEducation',
      getInterval: () => _stateService.getChannelInterval('security_dept'),
      isEnabled: () => _stateService.isChannelEnabled('security_dept'),
      fetchMessages: () => _securityService.fetchEducation(
        maxCount: _defaultFetchCount,
      ),
    );

    // 校区建设办要闻
    await _setupTimer(
      channelKey: 'constructionNews',
      getInterval: () => _stateService.getChannelInterval('construction'),
      isEnabled: () => _stateService.isChannelEnabled('construction'),
      fetchMessages: () => _constructionService.fetchNews(),
    );

    // 校区建设办通知
    await _setupTimer(
      channelKey: 'constructionNotice',
      getInterval: () => _stateService.getChannelInterval('construction'),
      isEnabled: () => _stateService.isChannelEnabled('construction'),
      fetchMessages: () => _constructionService.fetchNotices(),
    );

    // 新闻网综合新闻
    await _setupTimer(
      channelKey: 'campusNews',
      getInterval: () => _stateService.getChannelInterval('news_center'),
      isEnabled: () => _stateService.isChannelEnabled('news_center'),
      fetchMessages: () => _campusService.fetchCampusNews(),
    );

    // 学生处学工要闻
    await _setupTimer(
      channelKey: 'studentNews',
      getInterval: () => _stateService.getChannelInterval('student_affairs'),
      isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
      fetchMessages: () => _studentService.fetchNews(),
    );

    // 学生处通知公告
    await _setupTimer(
      channelKey: 'studentNotice',
      getInterval: () => _stateService.getChannelInterval('student_affairs'),
      isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
      fetchMessages: () => _studentService.fetchNotices(),
    );

    // ==================== 教学单位渠道（19个学院/部门） ====================
    // 所有学院共用 CollegeNewsService，通过 channelId 区分解析配置
    final collegeChannelIds = [
      'college_cs', 'college_im', 'college_re', 'college_em', 'college_ic',
      'college_imhe', 'college_econ', 'college_lang', 'college_math',
      'college_art', 'college_vte', 'college_vt', 'college_marx', 'college_ce',
      'center_art_edu', 'center_intl', 'center_innov', 'graduate', 'lib_center',
    ];
    for (final channelId in collegeChannelIds) {
      await _setupTimer(
        channelKey: channelId,
        getInterval: () => _stateService.getChannelInterval(channelId),
        isEnabled: () => _stateService.isChannelEnabled(channelId),
        fetchMessages: () => _collegeService.fetchNews(channelId),
      );
    }

    // 微信渠道占位 — 未来接入时取消注释
    // await _setupTimer(channelKey: 'wechatPublic', ...);
    // await _setupTimer(channelKey: 'wechatService', ...);
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
    required Future<List<MessageItem>> Function() fetchMessages,
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
    Future<List<MessageItem>> Function() fetchMessages,
  ) async {
    try {
      // 加载已有消息
      final existingMessages = await _stateService.loadMessages();
      final existingIds = existingMessages.map((m) => m.id).toSet();

      // 抓取新消息
      final fetched = await fetchMessages();

      // 找出真正的新消息（ID 不在已有集合中）
      final newMessages =
          fetched.where((m) => !existingIds.contains(m.id)).toList();

      if (newMessages.isEmpty) return;

      // 合并并持久化
      final merged = _stateService.mergeMessages(existingMessages, fetched);
      await _stateService.saveMessages(merged);

      // 推送系统通知
      if (newMessages.length == 1) {
        await _notificationService.show(
          title: '新消息',
          body: newMessages.first.title,
        );
      } else {
        await _notificationService.show(
          title: '${newMessages.length} 条新消息',
          body: newMessages.take(3).map((m) => m.title).join('\n'),
        );
      }
    } catch (_) {
      // 静默失败，下次定时器触发会重试
    }
  }

  /// 重新加载某个渠道的定时器配置
  /// 设置页修改间隔后调用此方法使新间隔生效
  /// [channelKey] 渠道标识：'latestInfo' / 'notice' / 'wechatPublic' / 'wechatService'
  Future<void> reloadChannel(String channelKey) async {
    switch (channelKey) {
      case 'latestInfo':
        await _setupTimer(
          channelKey: 'latestInfo',
          getInterval: _stateService.getLatestInfoInterval,
          isEnabled: _stateService.isLatestInfoEnabled,
          fetchMessages: () => _newsService.fetchLatestInfo(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'notice':
        await _setupTimer(
          channelKey: 'notice',
          getInterval: _stateService.getNoticeInterval,
          isEnabled: _stateService.isNoticeEnabled,
          fetchMessages: () => _newsService.fetchNotices(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'jwcStudent':
        await _setupTimer(
          channelKey: 'jwcStudent',
          getInterval: () => _stateService.getChannelInterval('jwc'),
          isEnabled: () => _stateService.isChannelEnabled('jwc'),
          fetchMessages: () => _jwcService.fetchStudentNews(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'jwcTeacher':
        await _setupTimer(
          channelKey: 'jwcTeacher',
          getInterval: () => _stateService.getChannelInterval('jwc'),
          isEnabled: () => _stateService.isChannelEnabled('jwc'),
          fetchMessages: () => _jwcService.fetchTeacherNews(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'itc':
        await _setupTimer(
          channelKey: 'itc',
          getInterval: () => _stateService.getChannelInterval('itc'),
          isEnabled: () => _stateService.isChannelEnabled('itc'),
          fetchMessages: () => _itcService.fetchNews(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'sspuNotice':
        await _setupTimer(
          channelKey: 'sspuNotice',
          getInterval: () => _stateService.getChannelInterval('sspu_notice'),
          isEnabled: () => _stateService.isChannelEnabled('sspu_notice'),
          fetchMessages: () => _officialService.fetchNotices(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'sspuActivity':
        await _setupTimer(
          channelKey: 'sspuActivity',
          getInterval: () => _stateService.getChannelInterval('sspu_activity'),
          isEnabled: () => _stateService.isChannelEnabled('sspu_activity'),
          fetchMessages: () => _officialService.fetchActivities(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'sportsNotice':
        await _setupTimer(
          channelKey: 'sportsNotice',
          getInterval: () => _stateService.getChannelInterval('sports'),
          isEnabled: () => _stateService.isChannelEnabled('sports'),
          fetchMessages: () => _sportsService.fetchNotices(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'sportsEvent':
        await _setupTimer(
          channelKey: 'sportsEvent',
          getInterval: () => _stateService.getChannelInterval('sports'),
          isEnabled: () => _stateService.isChannelEnabled('sports'),
          fetchMessages: () => _sportsService.fetchEvents(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'securityNews':
        await _setupTimer(
          channelKey: 'securityNews',
          getInterval: () => _stateService.getChannelInterval('security_dept'),
          isEnabled: () => _stateService.isChannelEnabled('security_dept'),
          fetchMessages: () => _securityService.fetchNews(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'securityEducation':
        await _setupTimer(
          channelKey: 'securityEducation',
          getInterval: () => _stateService.getChannelInterval('security_dept'),
          isEnabled: () => _stateService.isChannelEnabled('security_dept'),
          fetchMessages: () => _securityService.fetchEducation(
            maxCount: _defaultFetchCount,
          ),
        );
        break;
      case 'constructionNews':
        await _setupTimer(
          channelKey: 'constructionNews',
          getInterval: () => _stateService.getChannelInterval('construction'),
          isEnabled: () => _stateService.isChannelEnabled('construction'),
          fetchMessages: () => _constructionService.fetchNews(),
        );
        break;
      case 'constructionNotice':
        await _setupTimer(
          channelKey: 'constructionNotice',
          getInterval: () => _stateService.getChannelInterval('construction'),
          isEnabled: () => _stateService.isChannelEnabled('construction'),
          fetchMessages: () => _constructionService.fetchNotices(),
        );
        break;
      case 'campusNews':
        await _setupTimer(
          channelKey: 'campusNews',
          getInterval: () => _stateService.getChannelInterval('news_center'),
          isEnabled: () => _stateService.isChannelEnabled('news_center'),
          fetchMessages: () => _campusService.fetchCampusNews(),
        );
        break;
      case 'studentNews':
        await _setupTimer(
          channelKey: 'studentNews',
          getInterval: () => _stateService.getChannelInterval('student_affairs'),
          isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
          fetchMessages: () => _studentService.fetchNews(),
        );
        break;
      case 'studentNotice':
        await _setupTimer(
          channelKey: 'studentNotice',
          getInterval: () => _stateService.getChannelInterval('student_affairs'),
          isEnabled: () => _stateService.isChannelEnabled('student_affairs'),
          fetchMessages: () => _studentService.fetchNotices(),
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
          fetchMessages: () => _collegeService.fetchNews(channelKey),
        );
        break;
      // 微信渠道占位
      default:
        break;
    }
  }

  /// 重新加载所有渠道定时器
  /// 适用于应用恢复前台或全局刷新设置后
  Future<void> reloadAll() async {
    await reloadChannel('latestInfo');
    await reloadChannel('notice');
    await reloadChannel('jwcStudent');
    await reloadChannel('jwcTeacher');
    await reloadChannel('itc');
    await reloadChannel('sspuNotice');
    await reloadChannel('sspuActivity');
    await reloadChannel('sportsNotice');
    await reloadChannel('sportsEvent');
    await reloadChannel('securityNews');
    await reloadChannel('securityEducation');
    await reloadChannel('constructionNews');
    await reloadChannel('constructionNotice');
    await reloadChannel('campusNews');
    await reloadChannel('studentNews');
    await reloadChannel('studentNotice');
    // 教学单位渠道
    await reloadChannel('college_cs');
    await reloadChannel('college_im');
    await reloadChannel('college_re');
    await reloadChannel('college_em');
    await reloadChannel('college_ic');
    await reloadChannel('college_imhe');
    await reloadChannel('college_econ');
    await reloadChannel('college_lang');
    await reloadChannel('college_math');
    await reloadChannel('college_art');
    await reloadChannel('college_vte');
    await reloadChannel('college_vt');
    await reloadChannel('college_marx');
    await reloadChannel('college_ce');
    await reloadChannel('center_art_edu');
    await reloadChannel('center_intl');
    await reloadChannel('center_innov');
    await reloadChannel('graduate');
    await reloadChannel('lib_center');
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
