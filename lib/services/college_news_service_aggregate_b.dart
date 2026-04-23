part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchCenterTrainingNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _centerTrainingCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCenterTrainingListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 集成电路学院使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCollegeIcNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _collegeIcCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://sic.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.collegeIc,
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

/// 智能医学与健康工程学院使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchCollegeImheNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _collegeImheCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://imhe.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.collegeImhe,
        category: category,
        customItemSelector: 'a.btt-3',
        customTitleSelector: 'div.btt-4',
        customDateSelector: 'div.time-1',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 艺术与设计学院使用指定列表页聚合成学院动态分类。
Future<List<MessageItem>> _fetchCollegeArtNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _collegeArtCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://design.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.collegeArt,
        category: category,
        customItemSelector: 'div.xydt_list2_box',
        customTitleSelector: 'div.xydt_list2_title',
        customDateSelector: 'div.xydt_list2_bottom span',
        customLinkSelector: 'div.xydt_list2_con > a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 艺术教育中心使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchCenterArtEduNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _centerArtEduCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://education.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.centerArtEdu,
        category: category,
        customItemSelector: 'div.ListContent ul li',
        customTitleSelector: 'span.first',
        customDateSelector: 'span.last',
        customLinkSelector: 'a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 创新创业教育中心使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCenterInnovNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _centerInnovCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://cxcy.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.centerInnov,
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

/// 图书馆使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchLibCenterNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _libCenterCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://library.sspu.edu.cn',
        template: CollegeTemplate.listA,
        sourceName: MessageSourceName.libCenter,
        category: category,
        listContainerSelector: 'div.newslists ul',
        listItemSelector: 'li.news.clearfix',
        dateSelector: 'span.nowdate',
        titleSelector: 'a[title]',
        titleFromAttribute: true,
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 后勤服务中心使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchLogisticsCenterNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _logisticsCenterCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://hqgl.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.logisticsCenter,
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

/// 外国留学生事务办公室使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchForeignStudentOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _foreignStudentOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://lxs.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.foreignStudentOffice,
        category: category,
        customItemSelector: 'div.list-1 a.item',
        customTitleSelector: 'p.item-tit',
        customDateSelector: 'div.item-time',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 国际交流处使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchIntlExchangeOfficeNews(
  CollegeNewsService service, {
  Set<String>? knownMessageIds,
}) async {
  return _fetchMergedCategoryPages(
    _intlExchangeOfficeCategoryPaths,
    (relativePath, category, ids) => _fetchConfiguredListPage(
      service,
      relativePath: relativePath,
      config: CollegeConfig(
        baseUrl: 'https://gjjlc.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.intlExchangeOffice,
        category: category,
        customItemSelector: 'div.rightlist ul li',
        customTitleSelector: 'a',
        customDateSelector: 'span',
        customLinkSelector: 'a',
      ),
      knownMessageIds: ids,
    ),
    knownMessageIds: knownMessageIds,
  );
}

/// 研究生处使用指定列表页聚合成动态分类。
