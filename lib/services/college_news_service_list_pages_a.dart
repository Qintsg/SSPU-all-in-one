part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchConfiguredListPage(
  CollegeNewsService service, {
  required String relativePath,
  required CollegeConfig config,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      '${config.baseUrl}$relativePath',
    );
    final document = html_parser.parse(htmlText);

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
    return [];
  }
}

/// 抓取计信学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeCsListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://jxxy.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final items = document.querySelectorAll('li.ui-preDot');
    final messages = <MessageItem>[];

    for (final item in items) {
      final titleElement = item.querySelector('a.text-overflow');
      final dateElement = item.querySelector('span.time');
      if (titleElement == null || dateElement == null) continue;

      final href = titleElement.attributes['href'] ?? '';
      final title =
          titleElement.attributes['title']?.trim() ?? titleElement.text.trim();
      if (href.isEmpty || title.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, 'https://jxxy.sspu.edu.cn');
      if (fullUrl.isEmpty) continue;
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      final date = normalizeDate(dateElement.text.trim());
      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.collegeCs,
          category: category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  } catch (_) {
    return [];
  }
}

/// 抓取智控学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeImListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://imce.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final items = document.querySelectorAll('div.jzlb');
    final messages = <MessageItem>[];

    for (final item in items) {
      final titleElement = item.querySelector('div.xysbt a');
      final dateElement = item.querySelector('div.xyssj');
      if (titleElement == null || dateElement == null) continue;

      final href = titleElement.attributes['href'] ?? '';
      final title =
          titleElement.attributes['title']?.trim() ?? titleElement.text.trim();
      if (href.isEmpty || title.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, 'https://imce.sspu.edu.cn');
      if (fullUrl.isEmpty) continue;
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      final date = normalizeDate(dateElement.text.trim());
      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.collegeIm,
          category: category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  } catch (_) {
    return [];
  }
}

/// 抓取资环学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeReListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://zihuan.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final items = document.querySelectorAll('div.listbody ul li');
    final messages = <MessageItem>[];

    for (final item in items) {
      final titleElement = item.querySelector('a');
      final dateElement = item.querySelector('span');
      if (titleElement == null || dateElement == null) continue;

      final href = titleElement.attributes['href'] ?? '';
      final title =
          titleElement.attributes['title']?.trim() ?? titleElement.text.trim();
      if (href.isEmpty || title.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, 'https://zihuan.sspu.edu.cn');
      if (fullUrl.isEmpty) continue;
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      final date = normalizeDate(dateElement.text.trim());
      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.collegeRe,
          category: category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  } catch (_) {
    return [];
  }
}

/// 抓取能材学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeEmListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://sem.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://sem.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeEm,
      category: category,
      newsListContainerSelector: 'ul.news_list.list2',
      newsListTitleSelector: 'span.news_title a',
      newsListDateSelector: 'span.news_meta',
      newsListLinkSelector: 'span.news_title a',
    );

    return _parseNewsListB(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取经管学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeEconListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://jjglxy.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final config = CollegeConfig(
      baseUrl: 'https://jjglxy.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeEcon,
      category: category,
      newsListContainerSelector: 'ul.news_list.list2',
      newsListTitleSelector: 'span.news_title a',
      newsListDateSelector: 'span.news_meta',
      newsListLinkSelector: 'span.news_title a',
    );

    return _parseNewsListB(document, config, knownMessageIds: knownMessageIds);
  } catch (_) {
    return [];
  }
}

/// 抓取文传学院某个子栏目列表页。
Future<List<MessageItem>> _fetchCollegeLangListPage(
  CollegeNewsService service, {
  required String relativePath,
  required MessageCategory category,
  Set<String>? knownMessageIds,
}) async {
  try {
    final htmlText = await service._http.fetchText(
      'https://wywh.sspu.edu.cn$relativePath',
    );
    final document = html_parser.parse(htmlText);
    final items = document.querySelectorAll('div.right_list ul li');
    final messages = <MessageItem>[];

    for (final item in items) {
      final dateElement = item.querySelector('span');
      if (dateElement == null) continue;

      Element? titleElement;
      for (final link in item.querySelectorAll('a')) {
        final href = link.attributes['href'] ?? '';
        final title = link.attributes['title']?.trim() ?? link.text.trim();
        if (href.isNotEmpty && title.isNotEmpty) {
          titleElement = link;
          break;
        }
      }
      if (titleElement == null) continue;

      final href = titleElement.attributes['href'] ?? '';
      final title =
          titleElement.attributes['title']?.trim() ?? titleElement.text.trim();
      if (href.isEmpty || title.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, 'https://wywh.sspu.edu.cn');
      if (fullUrl.isEmpty) continue;
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      final date = normalizeDate(dateElement.text.trim());
      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.collegeLang,
          category: category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  } catch (_) {
    return [];
  }
}

/// 抓取数统学院某个子栏目列表页，并进入文章页补齐精确发布时间。
