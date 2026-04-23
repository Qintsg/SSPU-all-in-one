part of 'info_page.dart';

const Map<MessageCategory, String> _infoCategoryToChannelId = {
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
  MessageCategory.logisticsNotice: 'logistics_center',
  MessageCategory.logisticsNews: 'logistics_center',
  MessageCategory.foreignStudentNotice: 'foreign_student_office',
  MessageCategory.foreignStudentNews: 'foreign_student_office',
  MessageCategory.intlExchangeNews: 'intl_exchange_office',
  MessageCategory.intlExchangeNotice: 'intl_exchange_office',
  MessageCategory.admissionsNews: 'admissions_office',
  MessageCategory.hrNews: 'hr_office',
  MessageCategory.hrRecruitment: 'hr_office',
  MessageCategory.hrNotice: 'hr_office',
  MessageCategory.researchInfo: 'research_office',
  MessageCategory.researchNotice: 'research_office',
  MessageCategory.researchAchievement: 'research_office',
  MessageCategory.unionNews: 'union',
  MessageCategory.unionPartyLeadership: 'union',
  MessageCategory.unionNotice: 'union',
  MessageCategory.partyOrgNews: 'party_org_dept',
  MessageCategory.partyOrgNotice: 'party_org_dept',
  MessageCategory.unitedFrontNews: 'united_front_dept',
  MessageCategory.unitedFrontVoice: 'united_front_dept',
  MessageCategory.unitedFrontStyle: 'united_front_dept',
  MessageCategory.partyOfficeNews: 'party_office',
  MessageCategory.youthLeagueHighlights: 'youth_league',
  MessageCategory.youthLeagueNotice: 'youth_league',
  MessageCategory.youthLeagueGrassroots: 'youth_league',
  MessageCategory.assetsLabNews: 'assets_lab_office',
  MessageCategory.assetsLabNotice: 'assets_lab_office',
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
  MessageCategory.collegeIcNotice: 'college_ic',
  MessageCategory.collegeIcAcademic: 'college_ic',
  MessageCategory.collegeIcResearch: 'college_ic',
  MessageCategory.collegeImheNews: 'college_imhe',
  MessageCategory.collegeImheNotice: 'college_imhe',
  MessageCategory.collegeEconNews: 'college_econ',
  MessageCategory.collegeEconNotice: 'college_econ',
  MessageCategory.collegeEconStudentDevelopment: 'college_econ',
  MessageCategory.collegeEconPartyLeadership: 'college_econ',
  MessageCategory.collegeLangNews: 'college_lang',
  MessageCategory.collegeLangNotice: 'college_lang',
  MessageCategory.collegeLangStudentActivities: 'college_lang',
  MessageCategory.collegeLangLecture: 'college_lang',
  MessageCategory.collegeMathNews: 'college_math',
  MessageCategory.collegeMathNotice: 'college_math',
  MessageCategory.collegeMathAcademic: 'college_math',
  MessageCategory.collegeMathStudentDevelopment: 'college_math',
  MessageCategory.collegeArtNews: 'college_art',
  MessageCategory.collegeVteNews: 'college_vte',
  MessageCategory.collegeVteNotice: 'college_vte',
  MessageCategory.collegeVtNews: 'college_vt',
  MessageCategory.collegeVtNotice: 'college_vt',
  MessageCategory.collegeMarxNews: 'college_marx',
  MessageCategory.collegeMarxNotice: 'college_marx',
  MessageCategory.collegeMarxResearch: 'college_marx',
  MessageCategory.collegeMarxTeaching: 'college_marx',
  MessageCategory.collegeCeNews: 'college_ce',
  MessageCategory.collegeCeNotice: 'college_ce',
  MessageCategory.centerArtEduNews: 'center_art_edu',
  MessageCategory.centerArtEduLecture: 'center_art_edu',
  MessageCategory.centerIntlNews: 'center_intl',
  MessageCategory.centerIntlNotice: 'center_intl',
  MessageCategory.centerInnovNews: 'center_innov',
  MessageCategory.centerInnovNotice: 'center_innov',
  MessageCategory.centerInnovCompetition: 'center_innov',
  MessageCategory.centerInnovPractice: 'center_innov',
  MessageCategory.centerTrainingNews: 'center_training',
  MessageCategory.centerTrainingNotice: 'center_training',
  MessageCategory.graduateNews: 'graduate',
  MessageCategory.libCenterNews: 'lib_center',
  MessageCategory.libCenterNotice: 'lib_center',
  MessageCategory.libCenterLecture: 'lib_center',
};

Future<void> _filterInfoPageByEnabledChannels(_InfoPageState state) async {
  final allConfigs = [...departmentChannels, ...teachingChannels];
  final enabledCache = <String, bool>{};
  for (final config in allConfigs) {
    enabledCache[config.id] = await state._stateService.isChannelEnabled(
      config.id,
      defaultValue: config.defaultEnabled,
    );
  }

  final categoryEnabledCache = <String, bool>{};
  for (final entry in channelSubcategories.entries) {
    for (final sub in entry.value) {
      categoryEnabledCache[sub.category.name] = await state._stateService
          .isCategoryEnabled(sub.category.name);
    }
  }

  final wechatPublicEnabled = await state._stateService.isWechatPublicEnabled();
  final wechatServiceEnabled = await state._stateService
      .isWechatServiceEnabled();

  final mpEnabledCache = <String, bool>{};
  for (final msg in state._allMessages) {
    if (msg.mpBookId != null && !mpEnabledCache.containsKey(msg.mpBookId)) {
      mpEnabledCache[msg.mpBookId!] = await state._stateService
          .isMpNotificationEnabled(msg.mpBookId!);
    }
  }

  state._allMessages.removeWhere((msg) {
    if (msg.sourceType == MessageSourceType.wechatPublic) {
      if (!wechatPublicEnabled) return true;
      if (msg.mpBookId != null) {
        return !(mpEnabledCache[msg.mpBookId] ?? true);
      }
      return false;
    }
    if (msg.sourceType == MessageSourceType.wechatService) {
      return !wechatServiceEnabled;
    }

    final channelId = _infoCategoryToChannelId[msg.category];
    if (channelId != null) {
      if (!(enabledCache[channelId] ?? false)) return true;
      final categoryName = msg.category.name;
      if (categoryEnabledCache.containsKey(categoryName)) {
        return !categoryEnabledCache[categoryName]!;
      }
    }
    return false;
  });

  state._allMessages.sort((a, b) {
    final tsA = a.timestamp ?? _infoDateToTimestamp(a.date);
    final tsB = b.timestamp ?? _infoDateToTimestamp(b.date);
    return tsB.compareTo(tsA);
  });

  state._applyFilters();
}

int _infoDateToTimestamp(String date) {
  try {
    final dt = DateTime.parse(date);
    return dt.millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

void _applyInfoPageFilters(_InfoPageState state) {
  state._filteredMessages = state._allMessages.where((msg) {
    if (state._searchQuery.isNotEmpty &&
        !msg.title.toLowerCase().contains(state._searchQuery.toLowerCase())) {
      return false;
    }
    if (state._filterSourceType != null &&
        msg.sourceType != state._filterSourceType) {
      return false;
    }
    if (state._filterSourceName != null &&
        msg.sourceName != state._filterSourceName) {
      return false;
    }
    if (state._filterCategory != null &&
        msg.category != state._filterCategory) {
      return false;
    }
    if (state._filterUnreadOnly && state._stateService.isRead(msg.id)) {
      return false;
    }
    return true;
  }).toList();

  state._currentPage = 0;
  state._refreshView();
}

List<MessageItem> _getPagedInfoMessages(_InfoPageState state) {
  final startIndex = state._currentPage * _InfoPageState._pageSize;
  final endIndex = min(
    startIndex + _InfoPageState._pageSize,
    state._filteredMessages.length,
  );
  if (startIndex >= state._filteredMessages.length) return [];
  return state._filteredMessages.sublist(startIndex, endIndex);
}

int _getInfoTotalPages(_InfoPageState state) =>
    (state._filteredMessages.length / _InfoPageState._pageSize).ceil().clamp(
      1,
      9999,
    );

List<MessageSourceName> _getInfoAvailableSourceNames(_InfoPageState state) {
  if (state._filterSourceType == null) return const [];
  switch (state._filterSourceType!) {
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
        MessageSourceName.logisticsCenter,
        MessageSourceName.foreignStudentOffice,
        MessageSourceName.intlExchangeOffice,
        MessageSourceName.admissionsOffice,
        MessageSourceName.hrOffice,
        MessageSourceName.researchOffice,
        MessageSourceName.union,
        MessageSourceName.partyOrgDept,
        MessageSourceName.unitedFrontDept,
        MessageSourceName.partyOffice,
        MessageSourceName.youthLeague,
        MessageSourceName.assetsLabOffice,
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
        MessageSourceName.centerTraining,
        MessageSourceName.graduate,
        MessageSourceName.libCenter,
      ];
    case MessageSourceType.wechatPublic:
      return [MessageSourceName.wechatPublicPlaceholder];
    case MessageSourceType.wechatService:
      return [MessageSourceName.wechatServicePlaceholder];
  }
}

List<MessageCategory> _getInfoAvailableCategories(_InfoPageState state) {
  if (state._filterSourceName == null) return const [];
  switch (state._filterSourceName!) {
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
      return [MessageCategory.securityNews, MessageCategory.securityEducation];
    case MessageSourceName.construction:
      return [
        MessageCategory.constructionNews,
        MessageCategory.constructionNotice,
      ];
    case MessageSourceName.newsCenter:
      return [MessageCategory.campusNews];
    case MessageSourceName.studentAffairs:
      return [MessageCategory.studentNews, MessageCategory.studentNotice];
    case MessageSourceName.logisticsCenter:
      return [MessageCategory.logisticsNotice, MessageCategory.logisticsNews];
    case MessageSourceName.foreignStudentOffice:
      return [
        MessageCategory.foreignStudentNotice,
        MessageCategory.foreignStudentNews,
      ];
    case MessageSourceName.intlExchangeOffice:
      return [
        MessageCategory.intlExchangeNews,
        MessageCategory.intlExchangeNotice,
      ];
    case MessageSourceName.admissionsOffice:
      return [MessageCategory.admissionsNews];
    case MessageSourceName.hrOffice:
      return [
        MessageCategory.hrNews,
        MessageCategory.hrRecruitment,
        MessageCategory.hrNotice,
      ];
    case MessageSourceName.researchOffice:
      return [
        MessageCategory.researchInfo,
        MessageCategory.researchNotice,
        MessageCategory.researchAchievement,
      ];
    case MessageSourceName.union:
      return [
        MessageCategory.unionNews,
        MessageCategory.unionPartyLeadership,
        MessageCategory.unionNotice,
      ];
    case MessageSourceName.partyOrgDept:
      return [MessageCategory.partyOrgNews, MessageCategory.partyOrgNotice];
    case MessageSourceName.unitedFrontDept:
      return [
        MessageCategory.unitedFrontNews,
        MessageCategory.unitedFrontVoice,
        MessageCategory.unitedFrontStyle,
      ];
    case MessageSourceName.partyOffice:
      return [MessageCategory.partyOfficeNews];
    case MessageSourceName.youthLeague:
      return [
        MessageCategory.youthLeagueHighlights,
        MessageCategory.youthLeagueNotice,
        MessageCategory.youthLeagueGrassroots,
      ];
    case MessageSourceName.assetsLabOffice:
      return [MessageCategory.assetsLabNews, MessageCategory.assetsLabNotice];
    case MessageSourceName.wechatPublicPlaceholder:
    case MessageSourceName.wechatServicePlaceholder:
      return [MessageCategory.wechatArticle];
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
      return [
        MessageCategory.collegeIcNews,
        MessageCategory.collegeIcNotice,
        MessageCategory.collegeIcAcademic,
        MessageCategory.collegeIcResearch,
      ];
    case MessageSourceName.collegeImhe:
      return [
        MessageCategory.collegeImheNews,
        MessageCategory.collegeImheNotice,
      ];
    case MessageSourceName.collegeEcon:
      return [
        MessageCategory.collegeEconNews,
        MessageCategory.collegeEconNotice,
        MessageCategory.collegeEconStudentDevelopment,
        MessageCategory.collegeEconPartyLeadership,
      ];
    case MessageSourceName.collegeLang:
      return [
        MessageCategory.collegeLangNews,
        MessageCategory.collegeLangNotice,
        MessageCategory.collegeLangStudentActivities,
        MessageCategory.collegeLangLecture,
      ];
    case MessageSourceName.collegeMath:
      return [
        MessageCategory.collegeMathNews,
        MessageCategory.collegeMathNotice,
        MessageCategory.collegeMathAcademic,
        MessageCategory.collegeMathStudentDevelopment,
      ];
    case MessageSourceName.collegeArt:
      return [MessageCategory.collegeArtNews];
    case MessageSourceName.collegeVte:
      return [MessageCategory.collegeVteNews, MessageCategory.collegeVteNotice];
    case MessageSourceName.collegeVt:
      return [MessageCategory.collegeVtNews, MessageCategory.collegeVtNotice];
    case MessageSourceName.collegeMarx:
      return [
        MessageCategory.collegeMarxNews,
        MessageCategory.collegeMarxNotice,
        MessageCategory.collegeMarxResearch,
        MessageCategory.collegeMarxTeaching,
      ];
    case MessageSourceName.collegeCe:
      return [MessageCategory.collegeCeNews, MessageCategory.collegeCeNotice];
    case MessageSourceName.centerArtEdu:
      return [
        MessageCategory.centerArtEduNews,
        MessageCategory.centerArtEduLecture,
      ];
    case MessageSourceName.centerIntl:
      return [MessageCategory.centerIntlNews, MessageCategory.centerIntlNotice];
    case MessageSourceName.centerInnov:
      return [
        MessageCategory.centerInnovNews,
        MessageCategory.centerInnovNotice,
        MessageCategory.centerInnovCompetition,
        MessageCategory.centerInnovPractice,
      ];
    case MessageSourceName.centerTraining:
      return [
        MessageCategory.centerTrainingNews,
        MessageCategory.centerTrainingNotice,
      ];
    case MessageSourceName.graduate:
      return [MessageCategory.graduateNews];
    case MessageSourceName.libCenter:
      return [
        MessageCategory.libCenterNews,
        MessageCategory.libCenterNotice,
        MessageCategory.libCenterLecture,
      ];
  }
}
