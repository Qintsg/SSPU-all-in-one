/*
 * 本专科教务页面解析器 — 管理只读入口提取与通用解析辅助结构
 * @Project : SSPU-all-in-one
 * @File : academic_eams_page_parser.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

enum _AcademicQueryField {
  termName,
  courseCode,
  courseName,
  teacher,
  department,
  campus,
  building,
  dateText,
  lessonFrom,
  lessonTo,
}

class _AcademicReadonlyEntry {
  const _AcademicReadonlyEntry({required this.label, required this.uri});

  _AcademicReadonlyEntry.empty() : label = '', uri = Uri();

  final String label;
  final Uri uri;

  bool get isEmpty => label.isEmpty;
}

class _AcademicReadonlyQueryForm {
  const _AcademicReadonlyQueryForm({
    required this.actionUri,
    required this.method,
    required this.defaultFields,
    required this.fieldNamesByIntent,
  });

  final Uri actionUri;
  final String method;
  final Map<String, String> defaultFields;
  final Map<_AcademicQueryField, String> fieldNamesByIntent;

  Map<String, String> buildCourseOfferingFields(
    AcademicCourseOfferingSearchCriteria criteria,
  ) {
    final fields = Map<String, String>.from(defaultFields);
    _setIfPresent(fields, _AcademicQueryField.termName, criteria.termName);
    _setIfPresent(fields, _AcademicQueryField.courseCode, criteria.courseCode);
    _setIfPresent(fields, _AcademicQueryField.courseName, criteria.courseName);
    _setIfPresent(fields, _AcademicQueryField.teacher, criteria.teacher);
    _setIfPresent(fields, _AcademicQueryField.department, criteria.department);
    return fields;
  }

  Map<String, String> buildFreeClassroomFields(
    AcademicFreeClassroomSearchCriteria criteria,
  ) {
    final fields = Map<String, String>.from(defaultFields);
    _setIfPresent(fields, _AcademicQueryField.campus, criteria.campus);
    _setIfPresent(fields, _AcademicQueryField.building, criteria.building);
    _setIfPresent(fields, _AcademicQueryField.dateText, criteria.dateText);
    _setIfPresent(
      fields,
      _AcademicQueryField.lessonFrom,
      criteria.lessonFrom?.toString(),
    );
    _setIfPresent(
      fields,
      _AcademicQueryField.lessonTo,
      criteria.lessonTo?.toString(),
    );
    return fields;
  }

  void _setIfPresent(
    Map<String, String> fields,
    _AcademicQueryField intent,
    String? value,
  ) {
    final fieldName = fieldNamesByIntent[intent];
    final normalizedValue = value?.trim();
    if (fieldName == null ||
        normalizedValue == null ||
        normalizedValue.isEmpty) {
      return;
    }
    fields[fieldName] = normalizedValue;
  }
}

class _ParsedTable {
  const _ParsedTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class _GridCell {
  const _GridCell({
    required this.text,
    required this.rowSpan,
    required this.colSpan,
    required this.isOrigin,
  });

  final String text;
  final int rowSpan;
  final int colSpan;
  final bool isOrigin;
}

List<Uri> _findPossibleJumpUris(AcademicEamsHttpSnapshot snapshot) {
  final values = <String>{};
  final patterns = [
    RegExp(r'''https://jx\.sspu\.edu\.cn/eams/[^"'<> ]+'''),
    RegExp(r'''location(?:\.href)?\s*=\s*['"]([^'"]+)['"]'''),
    RegExp(r'''window\.open\(['"]([^'"]+)['"]'''),
    RegExp(r'''top\.window\.location\s*=\s*['"]([^'"]+)['"]'''),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(snapshot.body)) {
      final value = match.groupCount >= 1
          ? (match.group(1) ?? match.group(0) ?? '').trim()
          : '';
      if (value.isNotEmpty) values.add(value);
    }
  }

  final document = html_parser.parse(snapshot.body);
  for (final link in document.querySelectorAll('a[href]')) {
    final href = link.attributes['href']?.trim() ?? '';
    if (href.isEmpty || href.startsWith('javascript:')) continue;
    if (href.contains('/eams/')) values.add(href);
  }

  return values
      .map(snapshot.finalUri.resolve)
      .where((uri) => uri.host.toLowerCase() == 'jx.sspu.edu.cn')
      .toSet()
      .toList();
}

List<_AcademicReadonlyEntry> _extractReadonlyEntries(
  AcademicEamsHttpSnapshot snapshot,
) {
  final document = html_parser.parse(snapshot.body);
  final entries = <_AcademicReadonlyEntry>[];
  final seen = <String>{};
  const keywords = [
    '个人',
    '课表',
    '成绩',
    '考试',
    '培养',
    '计划',
    '空闲',
    '教室',
    '开课',
    '课程',
    '完成',
  ];
  for (final element in document.querySelectorAll('a,span,div,li')) {
    final text = _cleanText(element.text);
    if (text.isEmpty || !keywords.any(text.contains)) continue;
    final rawUri =
        element.attributes['href'] ??
        element.attributes['url'] ??
        element.attributes['menuurl'] ??
        '';
    final onclick = element.attributes['onclick'] ?? '';
    final target = rawUri.isNotEmpty
        ? rawUri
        : _extractActionFromOnclick(onclick);
    if (target.isEmpty) continue;
    final uri = snapshot.finalUri.resolve(target);
    final key = '$text|$uri';
    if (!seen.add(key) || !_isReadonlyEntry(text, uri)) continue;
    entries.add(_AcademicReadonlyEntry(label: text, uri: uri));
  }
  return entries;
}

String _extractActionFromOnclick(String onclick) {
  final patterns = [
    RegExp(r'''['"]([^'"]+\.action(?:\?[^'"]*)?)['"]'''),
    RegExp(r'''Go\(['"]([^'"]+)['"]'''),
    RegExp(r'''toMainUrl\(['"]([^'"]+)['"]'''),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(onclick);
    final value = match?.group(1)?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
}

bool _isReadonlyEntry(String label, Uri uri) {
  final normalizedLabel = label.replaceAll(RegExp(r'\s+'), '');
  final path = uri.path.toLowerCase();
  const blockedKeywords = [
    'logout',
    'exit',
    'password',
    'modify',
    'edit',
    'save',
    'delete',
    'remove',
    'submit',
    'update',
  ];
  if (blockedKeywords.any(path.contains)) return false;
  if (normalizedLabel.contains('退出') ||
      normalizedLabel.contains('注销') ||
      normalizedLabel.contains('密码') ||
      normalizedLabel.contains('修改')) {
    return false;
  }
  return true;
}

bool _containsAny(List<String> haystack, List<String> needles) {
  return haystack.any(
    (value) => needles.any((needle) => value.contains(needle.toLowerCase())),
  );
}

Map<String, String> _rowToMap(List<String> headers, List<String> row) {
  final map = <String, String>{};
  for (var index = 0; index < headers.length && index < row.length; index++) {
    final key = headers[index].trim();
    if (key.isEmpty) continue;
    map[key] = row[index].trim();
  }
  return map;
}

String? _pickValue(Map<String, String> rowMap, List<String> aliases) {
  for (final alias in aliases) {
    for (final entry in rowMap.entries) {
      if (entry.key.contains(alias)) return entry.value;
    }
  }
  return null;
}

double? _parseDouble(String? text) {
  if (text == null) return null;
  final normalized = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int? _parseInt(String? text) {
  if (text == null) return null;
  final normalized = text.replaceAll(RegExp(r'[^0-9\-]'), '');
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized);
}

int? _parsePositiveInt(String? text) {
  final value = int.tryParse(text ?? '');
  return value == null || value <= 0 ? null : value;
}

String _cleanText(String value) {
  return value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
