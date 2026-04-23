part of 'college_news_service.dart';

/// 从数统学院文章页提取精确发布时间。
/// 优先解析常规正文时间节点，失败后回退到微信样式页面中的 create_time。
Future<_CollegeArticlePublishTime?> _fetchCollegeMathPublishTime(
  CollegeNewsService service,
  String articleUrl,
) async {
  try {
    final htmlText = await service._http.fetchText(articleUrl);
    final document = html_parser.parse(htmlText);

    for (final selector in const ['.arti_update', '.time']) {
      final timeText = document.querySelector(selector)?.text ?? '';
      final match = RegExp(
        r'(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}:\d{2}))?',
      ).firstMatch(timeText);
      if (match == null) continue;

      final date = normalizeDate(match.group(1) ?? '');
      final time = match.group(2);
      final timestamp = time == null
          ? MessageItem.computeTimestamp(date)
          : DateTime.parse('$date $time').millisecondsSinceEpoch;
      return _CollegeArticlePublishTime(date: date, timestamp: timestamp);
    }

    final timestampMatch = RegExp(
      "(?:create_time|oriCreateTime|ct)\\s*[:=]\\s*['\\\"]?(\\d{10,13})",
    ).firstMatch(htmlText);
    if (timestampMatch != null) {
      final rawTimestamp = int.tryParse(timestampMatch.group(1) ?? '');
      if (rawTimestamp != null && rawTimestamp > 0) {
        final timestamp = rawTimestamp < 10000000000
            ? rawTimestamp * 1000
            : rawTimestamp;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final date = normalizeDate(
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
        );
        return _CollegeArticlePublishTime(date: date, timestamp: timestamp);
      }
    }

    return null;
  } catch (_) {
    return null;
  }
}

// ==================== 模板A: 标准列表解析 ====================

/// 解析模板A: ul/div 列表内 li 项，包含日期 span + 标题 a
List<MessageItem> _parseListA(
  Document document,
  CollegeConfig config, {
  Set<String>? knownMessageIds,
}) {
  final container = document.querySelector(config.listContainerSelector ?? '');
  if (container == null) return [];

  final items = container.querySelectorAll(config.listItemSelector ?? 'li');
  final messages = <MessageItem>[];

  for (final item in items) {
    // 提取标题和链接
    final titleEl = item.querySelector(config.titleSelector ?? 'a');
    if (titleEl == null) continue;

    final title = config.titleFromAttribute
        ? (titleEl.attributes['title']?.trim() ?? titleEl.text.trim())
        : titleEl.text.trim();

    final href = titleEl.attributes['href'] ?? '';
    if (title.isEmpty || href.isEmpty) continue;

    final fullUrl = _buildFullUrl(href, config.baseUrl);
    if (fullUrl.isEmpty) continue;
    final messageId = _generateId(fullUrl);
    if (knownMessageIds?.contains(messageId) ?? false) break;

    // 提取日期；选择器缺失时仍按当天消息兜底，避免信息中心日期空白。
    final dateEl = item.querySelector(config.dateSelector ?? 'span');
    final date = normalizeDate(dateEl?.text.trim() ?? '');

    messages.add(
      MessageItem(
        id: messageId,
        title: title,
        date: date,
        url: fullUrl,
        sourceType: MessageSourceType.schoolWebsite,
        sourceName: config.sourceName,
        category: config.category,
        timestamp: MessageItem.computeTimestamp(date),
      ),
    );
  }

  return messages;
}

// ==================== 模板B: news_list 图文卡片解析 ====================

/// 解析模板B: ul.news_list 内的 li.news 卡片
List<MessageItem> _parseNewsListB(
  Document document,
  CollegeConfig config, {
  Set<String>? knownMessageIds,
}) {
  final containerSelector = config.newsListContainerSelector ?? 'ul.news_list';
  final container = document.querySelector(containerSelector);
  if (container == null) return [];

  final items = container.querySelectorAll('li.news');
  // 如果没有 li.news，尝试用 div 子项（如艺术学院 div.index_list2_box）
  final actualItems = items.isNotEmpty
      ? items
      : container.children
            .where((e) => e.localName == 'div' || e.localName == 'li')
            .toList();

  final messages = <MessageItem>[];

  for (final item in actualItems) {
    // 提取链接
    String href = '';
    final linkEl = config.newsListLinkSelector != null
        ? item.querySelector(config.newsListLinkSelector!)
        : null;

    if (linkEl != null) {
      href = linkEl.attributes['href'] ?? '';
    }

    // 提取标题
    String title = '';
    final titleEl = config.newsListTitleSelector != null
        ? item.querySelector(config.newsListTitleSelector!)
        : null;

    if (titleEl != null) {
      // 优先取 title 属性，否则取文本
      title = titleEl.attributes['title']?.trim() ?? titleEl.text.trim();
      // 如果链接为空，尝试从标题元素获取
      if (href.isEmpty) {
        href = titleEl.attributes['href'] ?? '';
      }
    }

    if (title.isEmpty || href.isEmpty) continue;

    final fullUrl = _buildFullUrl(href, config.baseUrl);
    if (fullUrl.isEmpty) continue;
    final messageId = _generateId(fullUrl);
    if (knownMessageIds?.contains(messageId) ?? false) break;

    // 提取日期；部分官网模板当天条目可能只给时间或不给日期。
    String date = '';
    if (config.newsListDateSelector != null) {
      final dateEl = item.querySelector(config.newsListDateSelector!);
      date = dateEl?.text.trim() ?? '';
    }
    date = normalizeDate(date);

    messages.add(
      MessageItem(
        id: messageId,
        title: title,
        date: date,
        url: fullUrl,
        sourceType: MessageSourceType.schoolWebsite,
        sourceName: config.sourceName,
        category: config.category,
        timestamp: MessageItem.computeTimestamp(date),
      ),
    );
  }

  return messages;
}

// ==================== 模板C: swiper 轮播解析 ====================

/// 解析模板C: swiper-wrapper 内的 swiper-slide 卡片
/// 智控学院特有：news_title(标题) + news_days(日) + news_years(YYYY.MM)
List<MessageItem> _parseSwiperC(
  Document document,
  CollegeConfig config, {
  Set<String>? knownMessageIds,
}) {
  final container = document.querySelector(
    config.swiperContainerSelector ?? 'div.swiper-wrapper',
  );
  if (container == null) return [];

  final slides = container.querySelectorAll('div.swiper-slide');
  final messages = <MessageItem>[];

  for (final slide in slides) {
    // 提取链接（slide 内第一个 a 标签）
    final anchor = slide.querySelector('a');
    final href = anchor?.attributes['href'] ?? '';
    if (href.isEmpty) continue;

    final fullUrl = _buildFullUrl(href, config.baseUrl);
    if (fullUrl.isEmpty) continue;
    final messageId = _generateId(fullUrl);
    if (knownMessageIds?.contains(messageId) ?? false) break;

    // 提取标题
    final titleEl = slide.querySelector('div.news_title');
    final title = titleEl?.text.trim() ?? '';
    if (title.isEmpty) continue;

    // 拼合日期: news_days(DD) + news_years(YYYY.MM)
    final daysEl = slide.querySelector('div.news_days');
    final yearsEl = slide.querySelector('div.news_years');
    String date = '';
    if (daysEl != null && yearsEl != null) {
      final day = daysEl.text.trim().padLeft(2, '0');
      final yearMonth = yearsEl.text.trim().replaceAll('.', '-');
      date = '$yearMonth-$day';
    }
    date = normalizeDate(date);

    messages.add(
      MessageItem(
        id: messageId,
        title: title,
        date: date,
        url: fullUrl,
        sourceType: MessageSourceType.schoolWebsite,
        sourceName: config.sourceName,
        category: config.category,
        timestamp: MessageItem.computeTimestamp(date),
      ),
    );
  }

  return messages;
}

// ==================== 模板D: 自定义结构解析 ====================

/// 解析模板D: 各种非标准 HTML 结构
/// 支持: imhe(a.btt-3), stes(a.item拼合日期), education(span.first+last), sie(div.item斜杠日期)
List<MessageItem> _parseCustomD(
  Document document,
  CollegeConfig config, {
  Set<String>? knownMessageIds,
}) {
  if (config.customItemSelector == null) return [];

  final items = document.querySelectorAll(config.customItemSelector!);
  final messages = <MessageItem>[];

  for (final item in items) {
    // 提取链接
    String href = '';
    if (config.customLinkSelector != null) {
      final linkEl = item.querySelector(config.customLinkSelector!);
      href = linkEl?.attributes['href'] ?? '';
    } else {
      // 项目本身就是 a 标签，或内部第一个 a
      href = item.attributes['href'] ?? '';
      if (href.isEmpty) {
        final innerA = item.querySelector('a');
        href = innerA?.attributes['href'] ?? '';
      }
    }
    if (href.isEmpty) continue;

    final fullUrl = _buildFullUrl(href, config.baseUrl);
    if (fullUrl.isEmpty) continue;
    final messageId = _generateId(fullUrl);
    if (knownMessageIds?.contains(messageId) ?? false) break;

    // 提取标题
    String title = '';
    if (config.customTitleSelector != null) {
      final titleEl = item.querySelector(config.customTitleSelector!);
      if (titleEl != null) {
        // 优先 title 属性
        title = titleEl.attributes['title']?.trim() ?? titleEl.text.trim();
      }
    }
    if (title.isEmpty) continue;

    // 提取日期；解析失败时使用当天日期，保持 MessageItem.date 可展示。
    String date = '';
    if (config.customDateComposite &&
        config.customDateYearMonthSelector != null) {
      // 拼合模式: day(customDateSelector) + yearMonth(customDateYearMonthSelector)
      final dayEl = item.querySelector(config.customDateSelector ?? '');
      final ymEl = item.querySelector(config.customDateYearMonthSelector!);
      if (dayEl != null && ymEl != null) {
        final day = dayEl.text.trim().padLeft(2, '0');
        final yearMonth = ymEl.text.trim();
        date = '$yearMonth-$day';
      }
    } else if (config.customDateSelector != null) {
      final dateEl = item.querySelector(config.customDateSelector!);
      date = dateEl?.text.trim() ?? '';
    }
    date = normalizeDate(date);

    messages.add(
      MessageItem(
        id: messageId,
        title: title,
        date: date,
        url: fullUrl,
        sourceType: MessageSourceType.schoolWebsite,
        sourceName: config.sourceName,
        category: config.category,
        timestamp: MessageItem.computeTimestamp(date),
      ),
    );
  }

  return messages;
}

// ==================== 工具方法 ====================

/// 构建完整 URL：过滤脚本/锚点等无效链接，避免 WebView 加载非法 URL。
String _buildFullUrl(String href, String baseUrl) {
  final normalizedHref = href.trim();
  if (normalizedHref.isEmpty) return '';

  final lowerHref = normalizedHref.toLowerCase();
  if (lowerHref == '#' ||
      lowerHref.startsWith('#') ||
      lowerHref.startsWith('javascript:') ||
      lowerHref.startsWith('mailto:') ||
      lowerHref.startsWith('tel:')) {
    return '';
  }

  final baseUri = Uri.tryParse(baseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    return '';
  }

  final resolved = baseUri.resolve(normalizedHref);
  if (!resolved.hasScheme || resolved.host.isEmpty) return '';
  if (resolved.scheme != 'http' && resolved.scheme != 'https') return '';
  return resolved.toString();
}

/// 基于 URL 生成稳定的消息唯一 ID（MD5 哈希）
String _generateId(String url) {
  final bytes = utf8.encode(url);
  final digest = md5.convert(bytes);
  return digest.toString();
}
