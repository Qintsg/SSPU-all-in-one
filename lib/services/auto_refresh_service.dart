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

part 'auto_refresh_service_init.dart';
part 'auto_refresh_service_fetch.dart';
part 'auto_refresh_service_timers.dart';

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
    'sspu_news',
    'sspu_notice',
    'sspu_activity',
    'sports',
    'security_dept',
    'construction',
    'news_center',
    'student_affairs',
    'logistics_center',
    'foreign_student_office',
    'intl_exchange_office',
    'admissions_office',
    'hr_office',
    'research_office',
    'union',
    'party_org_dept',
    'united_front_dept',
    'party_office',
    'youth_league',
    'assets_lab_office',
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
    'center_training',
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
        return ['jwcTeaching', 'jwcStudent', 'jwcTeacher'];
      case 'sspu_news':
        return ['sspuNews'];
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
  /// 初始化并启动自动刷新
  /// 应在 app 启动时调用一次
  Future<void> init() => _initAutoRefreshService(this);

  /// 立即抓取所有已启用官网/信息中心渠道的消息并返回合并结果
  /// 用于“刷新官网消息”按钮，不包含微信公众号渠道
  Future<List<MessageItem>> fetchEnabledSchoolWebsiteMessages({
    Future<void> Function(List<MessageItem> messages, int completed, int total)?
    onBatchCompleted,
  }) => _fetchEnabledSchoolWebsiteMessages(
    this,
    onBatchCompleted: onBatchCompleted,
  );

  /// 重新加载某个渠道的定时器配置。
  /// 设置页修改间隔后调用此方法使新间隔生效。
  Future<void> reloadChannel(String channelKey) =>
      _reloadAutoRefreshChannel(this, channelKey);

  /// 重新加载所有渠道定时器。
  Future<void> reloadAll() => _reloadAllAutoRefreshChannels(this);

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _initialized = false;
  }
}
