part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchGraduateNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _graduateCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://yjs.sspu.edu.cn',
        template: CollegeTemplate.listA,
        sourceName: MessageSourceName.graduate,
        category: category,
        listContainerSelector: 'div.tyList ul',
        listItemSelector: 'li',
        dateSelector: 'span.riqi',
        titleSelector: 'a',
        titleFromAttribute: true,
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 招生办使用指定列表页聚合成招生动态分类。
Future<List<MessageItem>> _fetchAdmissionsOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _admissionsOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://zsb.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.admissionsOffice,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 人事处使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchHrOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _hrOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://hr.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.hrOffice,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 科研处使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchResearchOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _researchOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://kyc.sspu.edu.cn',
        template: CollegeTemplate.listA,
        sourceName: MessageSourceName.researchOffice,
        category: category,
        listContainerSelector: 'div.rightlist ul',
        listItemSelector: 'li',
        dateSelector: 'span',
        titleSelector: 'a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 校工会使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchUnionNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _unionCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://gh.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.union,
        category: category,
        customItemSelector: 'div.jzlb.clearfix',
        customTitleSelector: 'div.btt3 a',
        customDateSelector: 'div.fbsj4',
        customLinkSelector: 'div.btt3 a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 党委组织部使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchPartyOrgDeptNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _partyOrgDeptCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://zzb.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.partyOrgDept,
        category: category,
        newsListContainerSelector: 'ul.news_list',
        newsListTitleSelector: 'div.item-right a',
        newsListDateSelector: 'div.item-time',
        newsListLinkSelector: 'div.item-right a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 党委统战部使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchUnitedFrontDeptNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _unitedFrontDeptCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://tzb.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.unitedFrontDept,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 党委办公室使用指定列表页聚合成工作动态分类。
Future<List<MessageItem>> _fetchPartyOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _partyOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://db.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.partyOffice,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 校团委使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchYouthLeagueNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _youthLeagueCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://tuanwei.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.youthLeague,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 资产与实验管理处使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchAssetsLabOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _assetsLabOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://zc.sspu.edu.cn',
        template: CollegeTemplate.listA,
        sourceName: MessageSourceName.assetsLabOffice,
        category: category,
        listContainerSelector: 'div.listbody div.list_news ul',
        listItemSelector: 'li',
        dateSelector: 'span',
        titleSelector: 'a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 通用的多分类聚合抓取逻辑。
