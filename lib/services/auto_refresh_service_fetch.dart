part of 'auto_refresh_service.dart';

Future<List<MessageItem>> _fetchEnabledSchoolWebsiteMessages(
  AutoRefreshService service, {
  int maxCount = 20,
  Future<void> Function(List<MessageItem> messages, int completed, int total)?
  onBatchCompleted,
}) async {
  final futures = <Future<List<MessageItem>>>[];
  final existingMessages = await service._stateService.loadMessages();
  final knownMessageIds = existingMessages.map((msg) => msg.id).toSet();

  // 信息公开网
  if (await service._stateService.isLatestInfoEnabled()) {
    futures.add(
      service._newsService.fetchLatestInfo(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isNoticeEnabled()) {
    futures.add(
      service._newsService.fetchNotices(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }

  // 职能部门
  if (await service._stateService.isChannelEnabled('jwc')) {
    futures.add(
      service._jwcService.fetchTeachingNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
    futures.add(
      service._jwcService.fetchStudentNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
    futures.add(
      service._jwcService.fetchTeacherNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('itc')) {
    futures.add(
      service._itcService.fetchNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('sspu_notice')) {
    futures.add(
      service._officialService.fetchNotices(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('sspu_news')) {
    futures.add(
      service._officialService.fetchNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('sspu_activity')) {
    futures.add(
      service._officialService.fetchActivities(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('sports')) {
    futures.add(
      service._sportsService.fetchNotices(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
    futures.add(
      service._sportsService.fetchEvents(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('security_dept')) {
    futures.add(
      service._securityService.fetchNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
    futures.add(
      service._securityService.fetchEducation(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('construction')) {
    futures.add(
      service._constructionService.fetchNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
    futures.add(
      service._constructionService.fetchNotices(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('news_center')) {
    futures.add(
      service._campusService.fetchCampusNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }
  if (await service._stateService.isChannelEnabled('student_affairs')) {
    futures.add(
      service._studentService.fetchNews(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
    futures.add(
      service._studentService.fetchNotices(
        maxCount: maxCount,
        knownMessageIds: knownMessageIds,
      ),
    );
  }

  // 配置驱动站点（教学单位 + 职能部门）
  const siteChannelIds = [
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
  for (final id in siteChannelIds) {
    if (await service._stateService.isChannelEnabled(id)) {
      futures.add(
        service._collegeService.fetchNews(id, knownMessageIds: knownMessageIds),
      );
    }
  }

  if (futures.isEmpty) return [];

  // 并行执行，单个渠道异常不影响其他渠道
  var completed = 0;
  final results = await Future.wait(
    futures.map((future) async {
      final messages = await future.catchError((_) => <MessageItem>[]);
      completed++;
      await onBatchCompleted?.call(messages, completed, futures.length);
      return messages;
    }),
  );
  return results.expand((msgs) => msgs).toList();
}

/// 配置并启动单个渠道的定时器
/// [channelKey] 渠道标识（用作 Timer map 的 key）
/// [getInterval] 获取当前间隔（分钟）的异步方法
/// [isEnabled] 检查渠道是否启用的异步方法
/// [fetchMessages] 抓取该渠道消息的异步方法
