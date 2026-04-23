part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchCollegeNews(
  CollegeNewsService service,
  String channelId, {
  Set<String>? knownMessageIds,
}) async {
  if (channelId == 'college_cs') {
    return _fetchCollegeCsNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_im') {
    return _fetchCollegeImNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_re') {
    return _fetchCollegeReNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_em') {
    return _fetchCollegeEmNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_ic') {
    return _fetchCollegeIcNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_imhe') {
    return _fetchCollegeImheNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_econ') {
    return _fetchCollegeEconNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_lang') {
    return _fetchCollegeLangNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_math') {
    return _fetchCollegeMathNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_art') {
    return _fetchCollegeArtNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_vte') {
    return _fetchCollegeVteNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_vt') {
    return _fetchCollegeVtNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_marx') {
    return _fetchCollegeMarxNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'college_ce') {
    return _fetchCollegeCeNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'center_art_edu') {
    return _fetchCenterArtEduNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'center_intl') {
    return _fetchCenterIntlNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'center_innov') {
    return _fetchCenterInnovNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'center_training') {
    return _fetchCenterTrainingNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'logistics_center') {
    return _fetchLogisticsCenterNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'foreign_student_office') {
    return _fetchForeignStudentOfficeNews(
      service,
      knownMessageIds: knownMessageIds,
    );
  }
  if (channelId == 'intl_exchange_office') {
    return _fetchIntlExchangeOfficeNews(
      service,
      knownMessageIds: knownMessageIds,
    );
  }
  if (channelId == 'graduate') {
    return _fetchGraduateNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'lib_center') {
    return _fetchLibCenterNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'admissions_office') {
    return _fetchAdmissionsOfficeNews(
      service,
      knownMessageIds: knownMessageIds,
    );
  }
  if (channelId == 'hr_office') {
    return _fetchHrOfficeNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'research_office') {
    return _fetchResearchOfficeNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'union') {
    return _fetchUnionNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'party_org_dept') {
    return _fetchPartyOrgDeptNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'united_front_dept') {
    return _fetchUnitedFrontDeptNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'party_office') {
    return _fetchPartyOfficeNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'youth_league') {
    return _fetchYouthLeagueNews(service, knownMessageIds: knownMessageIds);
  }
  if (channelId == 'assets_lab_office') {
    return _fetchAssetsLabOfficeNews(service, knownMessageIds: knownMessageIds);
  }

  final config = configs[channelId];
  if (config == null) return [];

  try {
    final htmlText = await service._http.fetchText(config.baseUrl);
    final document = html_parser.parse(htmlText);

    // 根据模板类型分派解析
    switch (config.template) {
      case CollegeTemplate.listA:
        return _parseListA(document, config, knownMessageIds: knownMessageIds);
      case CollegeTemplate.newsListB:
        return _parseNewsListB(
          document,
          config,
          knownMessageIds: knownMessageIds,
        );
      case CollegeTemplate.swiperC:
        return _parseSwiperC(
          document,
          config,
          knownMessageIds: knownMessageIds,
        );
      case CollegeTemplate.customD:
        return _parseCustomD(
          document,
          config,
          knownMessageIds: knownMessageIds,
        );
    }
  } catch (_) {
    // 网络异常或解析失败，静默返回空列表
    return [];
  }
}

/// 计信学院使用多个子栏目拼成三个聚合分类。
