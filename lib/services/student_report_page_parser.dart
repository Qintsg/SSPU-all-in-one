/*
 * 学工报表页面解析器 — 定位第二课堂入口并提取学分明细
 * @Project : SSPU-all-in-one
 * @File : student_report_page_parser.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'student_report_service.dart';

/// 学工报表页面导航辅助，仅返回可 GET 打开的只读查询入口。
class StudentReportPageNavigator {
  StudentReportPageNavigator._();

  /// 在 OA 门户页中定位学工报表 SSO 入口。
  static Uri? findReportSystemUri(StudentReportHttpSnapshot snapshot) {
    final document = html_parser.parse(snapshot.body);
    const attributeNames = ['href', 'src', 'action', 'data-url', 'data-href'];
    for (final element in document.querySelectorAll('*')) {
      for (final attributeName in attributeNames) {
        final rawValue = element.attributes[attributeName]?.trim();
        final uri = _reportSystemUriFromText(snapshot.finalUri, rawValue ?? '');
        if (uri != null) return uri;
      }
    }

    return _reportSystemUriFromText(snapshot.finalUri, snapshot.body);
  }

  /// 在首页中定位“第二课堂学分查询”入口。
  static Uri? findSecondClassroomUri(StudentReportHttpSnapshot snapshot) {
    final document = html_parser.parse(snapshot.body);
    final anchors = document.querySelectorAll('a[href], area[href]');
    for (final anchor in anchors) {
      final href = anchor.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;
      final linkText = _cleanText(anchor.text);
      final lowerHref = href.toLowerCase();
      if (_hasSecondClassroomCreditHint(linkText) ||
          lowerHref.contains('secondclassroom') ||
          lowerHref.contains('second_classroom')) {
        if (!lowerHref.startsWith('javascript:')) {
          return _resolveBusinessUri(snapshot.finalUri, href);
        }
        final uri = _uriFromElementAttributes(snapshot.finalUri, anchor);
        if (uri != null) return uri;
      }
    }

    for (final element in document.querySelectorAll('*')) {
      final elementText = _cleanText(element.text);
      if (!_hasSecondClassroomCreditHint(elementText)) continue;
      final uri = _uriFromElementAttributes(snapshot.finalUri, element);
      if (uri != null) return uri;
    }

    return _uriFromInlineScript(snapshot.finalUri, snapshot.body);
  }

  static Uri? _uriFromElementAttributes(Uri baseUri, html_dom.Element element) {
    const candidateAttributes = [
      'href',
      'data-url',
      'data-href',
      'url',
      'onclick',
    ];
    for (final attributeName in candidateAttributes) {
      final value = element.attributes[attributeName]?.trim();
      if (value == null || value.isEmpty) continue;
      final uri = _uriFromText(baseUri, value);
      if (uri != null) return uri;
    }
    return null;
  }

  static Uri? _uriFromInlineScript(Uri baseUri, String body) {
    final normalizedBody = body.replaceAll('&amp;', '&');
    for (final pattern in _secondClassroomPatterns) {
      final match = pattern.firstMatch(normalizedBody);
      final rawUri = match?.group(1)?.trim();
      if (rawUri != null && rawUri.isNotEmpty) {
        return _resolveBusinessUri(baseUri, rawUri);
      }
    }
    return null;
  }

  static Uri? _uriFromText(Uri baseUri, String text) {
    final normalizedText = text.replaceAll('&amp;', '&');
    for (final pattern in _secondClassroomPatterns) {
      final match = pattern.firstMatch(normalizedText);
      final rawUri = match?.group(1)?.trim();
      if (rawUri != null && rawUri.isNotEmpty) {
        return _resolveBusinessUri(baseUri, rawUri);
      }
    }
    return null;
  }

  static Uri _resolveBusinessUri(Uri baseUri, String rawUri) {
    final normalizedUri = rawUri.replaceAll('&amp;', '&').trim();
    final lowerPath = baseUri.path.toLowerCase();
    final sharedcIndex = lowerPath.indexOf('/sharedc/');
    if (normalizedUri.startsWith('/') &&
        sharedcIndex >= 0 &&
        !normalizedUri.toLowerCase().startsWith('/sharedc/')) {
      return baseUri.replace(path: '/sharedc$normalizedUri', query: '');
    }

    if (normalizedUri.startsWith('http://') ||
        normalizedUri.startsWith('https://') ||
        normalizedUri.startsWith('//') ||
        normalizedUri.startsWith('/')) {
      return baseUri.resolve(normalizedUri);
    }

    if (sharedcIndex >= 0) {
      final sharedcRoot = baseUri.path.substring(
        0,
        sharedcIndex + '/sharedc/'.length,
      );
      return baseUri
          .replace(path: sharedcRoot, query: '')
          .resolve(normalizedUri);
    }
    return baseUri.resolve(normalizedUri);
  }

  static bool _hasSecondClassroomCreditHint(String text) {
    return text.contains('第二课堂学分') ||
        text.contains('第二学堂学分') ||
        (text.contains('学分') && text.contains('查询'));
  }

  static Uri? _reportSystemUriFromText(Uri baseUri, String text) {
    if (text.isEmpty) return null;
    final normalizedText = text.replaceAll('&amp;', '&');
    for (final pattern in _reportSystemPatterns) {
      final match = pattern.firstMatch(normalizedText);
      final rawUri = match?.group(1)?.trim();
      if (rawUri == null || rawUri.isEmpty) continue;
      final uri = baseUri.resolve(rawUri);
      if (_isReportSystemSsoUri(uri)) return uri;
    }
    return null;
  }

  static bool _isReportSystemSsoUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == 'xgbb.sspu.edu.cn' &&
        path.contains('/sharedc/sso/') &&
        !path.contains('/core/login/');
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final List<RegExp> _secondClassroomPatterns = [
    RegExp(r'''['"]([^'"]*secondClassroom[^'"]*)['"]''', caseSensitive: false),
    RegExp(r'''['"]([^'"]*second_classroom[^'"]*)['"]''', caseSensitive: false),
    RegExp(
      r'''['"]?((?:/?(?:sharedc/)?dc/)?studentxfform/[^'"\s),]+)['"]?''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(?:location\.href|window\.open)\s*\(?\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ),
    RegExp(r'''toMain\s*\(\s*['"]([^'"]+)['"]''', caseSensitive: false),
  ];

  static final List<RegExp> _reportSystemPatterns = [
    RegExp(
      r'''['"]([^'"]*xgbb\.sspu\.edu\.cn/sharedc/sso/[^'"]*)['"]''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(https?://xgbb\.sspu\.edu\.cn/sharedc/sso/[^\s"'<>]+)''',
      caseSensitive: false,
    ),
  ];
}

/// 第二课堂学分页面解析器，逐项提取得分明细。
class StudentReportPageParser {
  StudentReportPageParser._();

  /// 从候选页面中提取第二课堂学分汇总。
  static SecondClassroomCreditSummary? parse(
    List<StudentReportHttpSnapshot> snapshots,
  ) {
    final records = <SecondClassroomCreditRecord>[];
    for (final snapshot in snapshots) {
      for (final fragment in _extractHtmlFragments(snapshot.body)) {
        final document = html_parser.parse(fragment);
        records.addAll(_parseRecords(document));
      }
    }

    final uniqueRecords = _deduplicateRecords(records);
    if (uniqueRecords.isEmpty) return null;

    return SecondClassroomCreditSummary(
      records: List.unmodifiable(uniqueRecords),
      fetchedAt: DateTime.now(),
      sourceUri: snapshots.last.finalUri,
    );
  }

  static List<String> _extractHtmlFragments(String body) {
    final fragments = <String>[body];
    final cdataPattern = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
    for (final match in cdataPattern.allMatches(body)) {
      final fragment = match.group(1);
      if (fragment != null && fragment.trim().isNotEmpty) {
        fragments.add(fragment);
      }
    }
    return fragments;
  }

  static List<SecondClassroomCreditRecord> _parseRecords(
    html_dom.Document document,
  ) {
    final records = <SecondClassroomCreditRecord>[];
    for (final table in document.querySelectorAll('table')) {
      final rows = table.querySelectorAll('tr');
      var header = const <String>[];
      for (final row in rows) {
        final cells = row
            .querySelectorAll('th,td')
            .map((cell) => _cleanText(cell.text))
            .where((cellText) => cellText.isNotEmpty)
            .toList();
        if (cells.length < 2) continue;
        if (_looksLikeHeader(cells)) {
          header = cells;
          continue;
        }

        final record = _recordFromCells(header: header, cells: cells);
        if (record != null) records.add(record);
      }
    }
    return records;
  }

  static bool _looksLikeHeader(List<String> cells) {
    final joinedCells = cells.join(' ');
    return joinedCells.contains('学分') &&
        (joinedCells.contains('类别') ||
            joinedCells.contains('项目') ||
            joinedCells.contains('名称'));
  }

  static SecondClassroomCreditRecord? _recordFromCells({
    required List<String> header,
    required List<String> cells,
  }) {
    final creditIndex = _indexOfAny(header, const ['学分', '分值']);
    final fallbackCreditIndex = _lastCreditIndex(cells);
    final resolvedCreditIndex = creditIndex >= 0
        ? creditIndex
        : fallbackCreditIndex;
    if (resolvedCreditIndex < 0 || resolvedCreditIndex >= cells.length) {
      return null;
    }

    final credit = _parseCredit(cells[resolvedCreditIndex]);
    if (credit == null) return null;

    final category = _cellAt(
      cells,
      _indexOfAny(header, const ['类别', '类型', '模块']),
      fallback: '未分类',
    );
    final itemName = _cellAt(
      cells,
      _indexOfAny(header, const ['项目名称', '活动名称', '课程名称', '项目', '名称']),
      fallback: _firstNonCreditCell(cells, resolvedCreditIndex),
    );
    if (itemName.isEmpty) return null;

    return SecondClassroomCreditRecord(
      category: category.isEmpty ? '未分类' : category,
      itemName: itemName,
      credit: credit,
      occurredAt: _nullableCell(
        cells,
        _indexOfAny(header, const ['认定时间', '获得时间', '时间', '日期']),
      ),
      status: _nullableCell(
        cells,
        _indexOfAny(header, const ['状态', '审核状态', '认定状态']),
      ),
      rawCells: List.unmodifiable(cells),
    );
  }

  static int _indexOfAny(List<String> header, List<String> labels) {
    for (var index = 0; index < header.length; index++) {
      final cell = header[index];
      if (labels.any(cell.contains)) return index;
    }
    return -1;
  }

  static int _lastCreditIndex(List<String> cells) {
    for (var index = cells.length - 1; index >= 0; index--) {
      if (_parseCredit(cells[index]) != null) return index;
    }
    return -1;
  }

  static String _cellAt(
    List<String> cells,
    int index, {
    required String fallback,
  }) {
    if (index >= 0 && index < cells.length) return cells[index];
    return fallback;
  }

  static String? _nullableCell(List<String> cells, int index) {
    if (index < 0 || index >= cells.length || cells[index].isEmpty) return null;
    return cells[index];
  }

  static String _firstNonCreditCell(List<String> cells, int creditIndex) {
    for (var index = 0; index < cells.length; index++) {
      if (index == creditIndex) continue;
      if (cells[index].isNotEmpty && _parseCredit(cells[index]) == null) {
        return cells[index];
      }
    }
    return '';
  }

  static List<SecondClassroomCreditRecord> _deduplicateRecords(
    List<SecondClassroomCreditRecord> records,
  ) {
    final seen = <String>{};
    final uniqueRecords = <SecondClassroomCreditRecord>[];
    for (final record in records) {
      final key =
          '${record.category}|${record.itemName}|${record.credit}|${record.rawCells.join('|')}';
      if (!seen.add(key)) continue;
      uniqueRecords.add(record);
    }
    return uniqueRecords;
  }

  static double? _parseCredit(String text) {
    final normalizedText = text.replaceAll(',', '').replaceAll('学分', '');
    final match = RegExp(r'([+\-]?\d+(?:\.\d+)?)').firstMatch(normalizedText);
    return double.tryParse(match?.group(1) ?? '');
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
