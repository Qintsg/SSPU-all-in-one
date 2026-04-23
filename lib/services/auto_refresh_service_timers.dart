part of 'auto_refresh_service.dart';

Future<void> _setupAutoRefreshTimer(
  AutoRefreshService service, {
  required String channelKey,
  required Future<int> Function() getInterval,
  required Future<bool> Function() isEnabled,
  required Future<List<MessageItem>> Function(Set<String> knownMessageIds)
  fetchMessages,
}) async {
  // 先取消已有定时器
  service._timers[channelKey]?.cancel();
  service._timers.remove(channelKey);

  final enabled = await isEnabled();
  final intervalMinutes = await getInterval();

  // 渠道未启用或间隔为 0（关闭）则不启动
  if (!enabled || intervalMinutes <= 0) return;

  final duration = Duration(minutes: intervalMinutes);

  service._timers[channelKey] = Timer.periodic(duration, (_) async {
    await _doAutoRefresh(service, channelKey, fetchMessages);
  });
}

/// 执行单次刷新：抓取 → 对比 → 合并持久化 → 推送新消息通知
/// [channelKey] 渠道标识（用于日志）
/// [fetchMessages] 抓取消息的方法
Future<void> _doAutoRefresh(
  AutoRefreshService service,
  String channelKey,
  Future<List<MessageItem>> Function(Set<String> knownMessageIds) fetchMessages,
) async {
  try {
    // 加载已有消息
    final existingMessages = await service._stateService.loadMessages();
    final existingIds = existingMessages.map((m) => m.id).toSet();

    // 抓取新消息
    final fetched = await fetchMessages(existingIds);

    // 找出真正的新消息（ID 不在已有集合中）
    final newMessages = fetched
        .where((m) => !existingIds.contains(m.id))
        .toList();

    if (newMessages.isEmpty) return;

    // 合并并持久化
    final merged = service._stateService.mergeMessages(
      existingMessages,
      fetched,
    );
    await service._stateService.saveMessages(merged);

    // 推送系统通知（检查全局开关和勿扰时段）
    final notifEnabled = await service._stateService.isNotificationEnabled();
    final inDnd = await service._stateService.isInDndPeriod();
    if (notifEnabled && !inDnd && service._notificationService.isAvailable) {
      // 过滤掉单个公众号通知关闭的消息
      final notifiableMessages = <MessageItem>[];
      for (final msg in newMessages) {
        if (msg.mpBookId != null) {
          final mpEnabled = await service._stateService.isMpNotificationEnabled(
            msg.mpBookId!,
          );
          if (!mpEnabled) continue;
        }
        notifiableMessages.add(msg);
      }

      if (notifiableMessages.length == 1) {
        await service._notificationService.show(
          title: '新消息',
          body: notifiableMessages.first.title,
        );
      } else if (notifiableMessages.length > 1) {
        await service._notificationService.show(
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
/// 设置页修改间隔后调用此方法使新间隔生效。
/// [channelKey] 可传设置页渠道 ID，也可传内部定时器 key。
Future<void> _reloadAutoRefreshChannel(
  AutoRefreshService service,
  String channelKey,
) async {
  final timerKeys = service._timerKeysForChannel(channelKey);
  if (timerKeys.length != 1 || timerKeys.single != channelKey) {
    for (final timerKey in timerKeys) {
      await _reloadAutoRefreshChannel(service, timerKey);
    }
    return;
  }

  switch (channelKey) {
    case 'latestInfo':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'latestInfo',
        getInterval: service._stateService.getLatestInfoInterval,
        isEnabled: service._stateService.isLatestInfoEnabled,
        fetchMessages: (knownMessageIds) =>
            service._newsService.fetchLatestInfo(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'notice':
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
      break;
    case 'jwcTeaching':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'jwcTeaching',
        getInterval: () => service._stateService.getChannelInterval('jwc'),
        isEnabled: () => service._stateService.isChannelEnabled('jwc'),
        fetchMessages: (knownMessageIds) =>
            service._jwcService.fetchTeachingNews(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'jwcStudent':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'jwcStudent',
        getInterval: () => service._stateService.getChannelInterval('jwc'),
        isEnabled: () => service._stateService.isChannelEnabled('jwc'),
        fetchMessages: (knownMessageIds) =>
            service._jwcService.fetchStudentNews(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'jwcTeacher':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'jwcTeacher',
        getInterval: () => service._stateService.getChannelInterval('jwc'),
        isEnabled: () => service._stateService.isChannelEnabled('jwc'),
        fetchMessages: (knownMessageIds) =>
            service._jwcService.fetchTeacherNews(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'itc':
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
      break;
    case 'sspuNotice':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'sspuNotice',
        getInterval: () =>
            service._stateService.getChannelInterval('sspu_notice'),
        isEnabled: () => service._stateService.isChannelEnabled('sspu_notice'),
        fetchMessages: (knownMessageIds) =>
            service._officialService.fetchNotices(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'sspuNews':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'sspuNews',
        getInterval: () =>
            service._stateService.getChannelInterval('sspu_news'),
        isEnabled: () => service._stateService.isChannelEnabled('sspu_news'),
        fetchMessages: (knownMessageIds) => service._officialService.fetchNews(
          maxCount: AutoRefreshService._defaultFetchCount,
          knownMessageIds: knownMessageIds,
        ),
      );
      break;
    case 'sspuActivity':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'sspuActivity',
        getInterval: () =>
            service._stateService.getChannelInterval('sspu_activity'),
        isEnabled: () =>
            service._stateService.isChannelEnabled('sspu_activity'),
        fetchMessages: (knownMessageIds) =>
            service._officialService.fetchActivities(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'sportsNotice':
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
      break;
    case 'sportsEvent':
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
      break;
    case 'securityNews':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'securityNews',
        getInterval: () =>
            service._stateService.getChannelInterval('security_dept'),
        isEnabled: () =>
            service._stateService.isChannelEnabled('security_dept'),
        fetchMessages: (knownMessageIds) => service._securityService.fetchNews(
          maxCount: AutoRefreshService._defaultFetchCount,
          knownMessageIds: knownMessageIds,
        ),
      );
      break;
    case 'securityEducation':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'securityEducation',
        getInterval: () =>
            service._stateService.getChannelInterval('security_dept'),
        isEnabled: () =>
            service._stateService.isChannelEnabled('security_dept'),
        fetchMessages: (knownMessageIds) =>
            service._securityService.fetchEducation(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'constructionNews':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'constructionNews',
        getInterval: () =>
            service._stateService.getChannelInterval('construction'),
        isEnabled: () => service._stateService.isChannelEnabled('construction'),
        fetchMessages: (knownMessageIds) =>
            service._constructionService.fetchNews(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'constructionNotice':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'constructionNotice',
        getInterval: () =>
            service._stateService.getChannelInterval('construction'),
        isEnabled: () => service._stateService.isChannelEnabled('construction'),
        fetchMessages: (knownMessageIds) =>
            service._constructionService.fetchNotices(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'campusNews':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'campusNews',
        getInterval: () =>
            service._stateService.getChannelInterval('news_center'),
        isEnabled: () => service._stateService.isChannelEnabled('news_center'),
        fetchMessages: (knownMessageIds) =>
            service._campusService.fetchCampusNews(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    case 'studentNews':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'studentNews',
        getInterval: () =>
            service._stateService.getChannelInterval('student_affairs'),
        isEnabled: () =>
            service._stateService.isChannelEnabled('student_affairs'),
        fetchMessages: (knownMessageIds) => service._studentService.fetchNews(
          maxCount: AutoRefreshService._defaultFetchCount,
          knownMessageIds: knownMessageIds,
        ),
      );
      break;
    case 'studentNotice':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'studentNotice',
        getInterval: () =>
            service._stateService.getChannelInterval('student_affairs'),
        isEnabled: () =>
            service._stateService.isChannelEnabled('student_affairs'),
        fetchMessages: (knownMessageIds) =>
            service._studentService.fetchNotices(
              maxCount: AutoRefreshService._defaultFetchCount,
              knownMessageIds: knownMessageIds,
            ),
      );
      break;
    // 配置驱动站点渠道（教学单位 / 中心 / 职能部门统一处理）
    case 'logistics_center':
    case 'foreign_student_office':
    case 'intl_exchange_office':
    case 'admissions_office':
    case 'hr_office':
    case 'research_office':
    case 'union':
    case 'party_org_dept':
    case 'united_front_dept':
    case 'party_office':
    case 'youth_league':
    case 'assets_lab_office':
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
    case 'center_training':
    case 'graduate':
    case 'lib_center':
      await _setupAutoRefreshTimer(
        service,
        channelKey: channelKey,
        getInterval: () => service._stateService.getChannelInterval(channelKey),
        isEnabled: () => service._stateService.isChannelEnabled(channelKey),
        fetchMessages: (knownMessageIds) => service._collegeService.fetchNews(
          channelKey,
          knownMessageIds: knownMessageIds,
        ),
      );
      break;
    // 微信公众号渠道
    case 'wechatPublic':
      await _setupAutoRefreshTimer(
        service,
        channelKey: 'wechatPublic',
        getInterval: () =>
            service._stateService.getChannelInterval('wechat_public'),
        isEnabled: () =>
            service._stateService.isChannelEnabled('wechat_public'),
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
      break;
    // 其他渠道占位
    default:
      break;
  }
}

/// 重新加载所有渠道定时器
/// 适用于应用恢复前台或全局刷新设置后

Future<void> _reloadAllAutoRefreshChannels(AutoRefreshService service) async {
  for (final channelId in AutoRefreshService._refreshChannelIds) {
    await _reloadAutoRefreshChannel(service, channelId);
  }
}

/// 销毁所有定时器
