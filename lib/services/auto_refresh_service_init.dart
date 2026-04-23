part of 'auto_refresh_service.dart';

Future<void> _initAutoRefreshService(AutoRefreshService service) async {
  if (service._initialized) return;
  service._initialized = true;

  await service._stateService.init();
  await service._notificationService.init();

  // 根据各渠道配置启动对应定时器
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'latestInfo',
    getInterval: service._stateService.getLatestInfoInterval,
    isEnabled: service._stateService.isLatestInfoEnabled,
    fetchMessages: (knownMessageIds) => service._newsService.fetchLatestInfo(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  await _setupAutoRefreshTimer(
    service,
    channelKey: 'notice',
    getInterval: service._stateService.getNoticeInterval,
    isEnabled: service._stateService.isNoticeEnabled,
    fetchMessages: (knownMessageIds) => service._newsService.fetchNotices(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 教务处教学动态
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'jwcTeaching',
    getInterval: () => service._stateService.getChannelInterval('jwc'),
    isEnabled: () => service._stateService.isChannelEnabled('jwc'),
    fetchMessages: (knownMessageIds) => service._jwcService.fetchTeachingNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 教务处学生专栏
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'jwcStudent',
    getInterval: () => service._stateService.getChannelInterval('jwc'),
    isEnabled: () => service._stateService.isChannelEnabled('jwc'),
    fetchMessages: (knownMessageIds) => service._jwcService.fetchStudentNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 教务处教师专栏
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'jwcTeacher',
    getInterval: () => service._stateService.getChannelInterval('jwc'),
    isEnabled: () => service._stateService.isChannelEnabled('jwc'),
    fetchMessages: (knownMessageIds) => service._jwcService.fetchTeacherNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 信息技术中心
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'itc',
    getInterval: () => service._stateService.getChannelInterval('itc'),
    isEnabled: () => service._stateService.isChannelEnabled('itc'),
    fetchMessages: (knownMessageIds) => service._itcService.fetchNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 学校官网学校新闻
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'sspuNews',
    getInterval: () => service._stateService.getChannelInterval('sspu_news'),
    isEnabled: () => service._stateService.isChannelEnabled('sspu_news'),
    fetchMessages: (knownMessageIds) => service._officialService.fetchNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 学校官网通知公告
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'sspuNotice',
    getInterval: () => service._stateService.getChannelInterval('sspu_notice'),
    isEnabled: () => service._stateService.isChannelEnabled('sspu_notice'),
    fetchMessages: (knownMessageIds) => service._officialService.fetchNotices(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 学校官网校内活动
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'sspuActivity',
    getInterval: () =>
        service._stateService.getChannelInterval('sspu_activity'),
    isEnabled: () => service._stateService.isChannelEnabled('sspu_activity'),
    fetchMessages: (knownMessageIds) =>
        service._officialService.fetchActivities(
          maxCount: AutoRefreshService._defaultFetchCount,
          knownMessageIds: knownMessageIds,
        ),
  );

  // 体育部通知公告
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'sportsNotice',
    getInterval: () => service._stateService.getChannelInterval('sports'),
    isEnabled: () => service._stateService.isChannelEnabled('sports'),
    fetchMessages: (knownMessageIds) => service._sportsService.fetchNotices(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 体育部赛事通知
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'sportsEvent',
    getInterval: () => service._stateService.getChannelInterval('sports'),
    isEnabled: () => service._stateService.isChannelEnabled('sports'),
    fetchMessages: (knownMessageIds) => service._sportsService.fetchEvents(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 保卫处平安动态
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'securityNews',
    getInterval: () =>
        service._stateService.getChannelInterval('security_dept'),
    isEnabled: () => service._stateService.isChannelEnabled('security_dept'),
    fetchMessages: (knownMessageIds) => service._securityService.fetchNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 保卫处宣教专栏
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'securityEducation',
    getInterval: () =>
        service._stateService.getChannelInterval('security_dept'),
    isEnabled: () => service._stateService.isChannelEnabled('security_dept'),
    fetchMessages: (knownMessageIds) => service._securityService.fetchEducation(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 基建处建设要闻
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'constructionNews',
    getInterval: () => service._stateService.getChannelInterval('construction'),
    isEnabled: () => service._stateService.isChannelEnabled('construction'),
    fetchMessages: (knownMessageIds) => service._constructionService.fetchNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 基建处通知公告
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'constructionNotice',
    getInterval: () => service._stateService.getChannelInterval('construction'),
    isEnabled: () => service._stateService.isChannelEnabled('construction'),
    fetchMessages: (knownMessageIds) =>
        service._constructionService.fetchNotices(
          maxCount: AutoRefreshService._defaultFetchCount,
          knownMessageIds: knownMessageIds,
        ),
  );

  // 新闻网综合新闻
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'campusNews',
    getInterval: () => service._stateService.getChannelInterval('news_center'),
    isEnabled: () => service._stateService.isChannelEnabled('news_center'),
    fetchMessages: (knownMessageIds) => service._campusService.fetchCampusNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 学生处学工要闻
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'studentNews',
    getInterval: () =>
        service._stateService.getChannelInterval('student_affairs'),
    isEnabled: () => service._stateService.isChannelEnabled('student_affairs'),
    fetchMessages: (knownMessageIds) => service._studentService.fetchNews(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // 学生处通知公告
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'studentNotice',
    getInterval: () =>
        service._stateService.getChannelInterval('student_affairs'),
    isEnabled: () => service._stateService.isChannelEnabled('student_affairs'),
    fetchMessages: (knownMessageIds) => service._studentService.fetchNotices(
      maxCount: AutoRefreshService._defaultFetchCount,
      knownMessageIds: knownMessageIds,
    ),
  );

  // ==================== 配置驱动站点渠道 ====================
  // 学院、中心及职能部门共用 CollegeNewsService，通过 channelId 区分解析配置。
  final siteChannelIds = [
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
  ];
  for (final channelId in siteChannelIds) {
    await _setupAutoRefreshTimer(
      service,
      channelKey: channelId,
      getInterval: () => service._stateService.getChannelInterval(channelId),
      isEnabled: () => service._stateService.isChannelEnabled(channelId),
      fetchMessages: (knownMessageIds) => service._collegeService.fetchNews(
        channelId,
        knownMessageIds: knownMessageIds,
      ),
    );
  }

  // 微信公众号渠道（通过公众号平台获取）
  await _setupAutoRefreshTimer(
    service,
    channelKey: 'wechatPublic',
    getInterval: () =>
        service._stateService.getChannelInterval('wechat_public'),
    isEnabled: () => service._stateService.isChannelEnabled('wechat_public'),
    fetchMessages: (knownMessageIds) async {
      final maxCount = await service._stateService.getChannelAutoFetchCount(
        'wechat_public',
        defaultValue: AutoRefreshService._defaultFetchCount,
      );
      return service._wechatService.fetchArticles(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      );
    },
  );

  // 微信服务号占位 — 未来接入时取消注释
  // await _setupAutoRefreshTimer(service, channelKey: 'wechatService', ...);
}

/// 立即抓取所有已启用官网/信息中心渠道的消息并返回合并结果
/// 用于“刷新官网消息”按钮，不包含微信公众号渠道
/// [maxCount] 支持 maxCount 参数的服务使用此值
/// :return: 所有已启用官网/信息中心渠道的消息列表
