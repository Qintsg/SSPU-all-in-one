part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchCollegeMathListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://sltj.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final items = document.querySelectorAll('div.listbody ul li');
    final messages = <MessageItem>[];

    for (final item in items) {
      final dateElement = item.querySelector('span');
      if (dateElement == null) continue;

      Element? titleElement;
      for (final link in item.querySelectorAll('a')) {
        final href = link.attributes['href'] ?? '';
        final rawTitle = link.attributes['title']?.trim() ?? '';
        final title = rawTitle.isNotEmpty ? rawTitle : link.text.trim();
        if (href.isEmpty || title.isEmpty) continue;
        if (rawTitle.contains('<') || rawTitle.contains('href=')) continue;
        titleElement = link;
        break;
      }
      if (titleElement == null) continue;

      final href = titleElement.attributes['href'] ?? '';
      final title =
          titleElement.attributes['title']?.trim() ?? titleElement.text.trim();
      if (href.isEmpty || title.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, 'https://sltj.sspu.edu.cn');
      if (fullUrl.isEmpty) continue;
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      final fallbackDate = normalizeDate(dateElement.text.trim());
      final publishTime = await _fetchCollegeMathPublishTime(service, fullUrl);
      final date = publishTime?.date ?? fallbackDate;

      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.collegeMath,
          category: category,
          timestamp:
              publishTime?.timestamp ?? MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  } catch (_) {
    return [];
  }
}

/// 抓取职师学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeVteListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://stes.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://stes.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.collegeVte,
      category: category,
      customItemSelector: 'div.list-1 a.item',
      customTitleSelector: 'div.tit',
      customDateSelector: 'div.time-2',
      customDateComposite: true,
      customDateYearMonthSelector: 'div.time-1',
    );

    return _parseCustomD(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取国教中心某个子栏目列表页。
Future<List<MessageItem>> _fetchCenterIntlListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://sie.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://sie.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.centerIntl,
      category: category,
      customItemSelector: 'div.list-1 a.item',
      customTitleSelector: 'p.item-tit',
      customDateSelector: 'div.item-time',
    );

    return _parseCustomD(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取继续教育学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeCeListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://adult.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://adult.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.collegeCe,
      category: category,
      customItemSelector: 'div.ListContent li',
      customTitleSelector: 'span.first',
      customDateSelector: 'span.last',
      customLinkSelector: 'a',
    );

    return _parseCustomD(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取职业技术学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeVtListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://cive.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://cive.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeVt,
      category: category,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'span.news_title a',
      newsListDateSelector: 'span.news_meta',
      newsListLinkSelector: 'a',
    );

    return _parseNewsListB(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取马克思主义学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeMarxListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://mkszyxy.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://mkszyxy.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeMarx,
      category: category,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.item-right a',
      newsListDateSelector: 'div.item-time',
      newsListLinkSelector: 'div.item-right a',
    );

    return _parseNewsListB(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取工程训练与创新教育中心某个子栏目列表页。
Future<List<MessageItem>> _fetchCenterTrainingListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://training.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://training.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.centerTraining,
      category: category,
      listContainerSelector: 'div.content ul',
      listItemSelector: 'li',
      dateSelector: 'span.riqi',
      titleSelector: 'a',
      titleFromAttribute: true,
    );

    return _parseListA(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}
