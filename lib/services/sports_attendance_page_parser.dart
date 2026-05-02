/*
 * 体育部考勤页面解析器 — 提取课外活动分类次数与记录
 * @Project : SSPU-all-in-one
 * @File : sports_attendance_page_parser.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'sports_attendance_service.dart';

class _SportsAttendancePageParser {
  static SportsAttendanceSummary? parse(String body, {required Uri sourceUri}) {
    final document = html_parser.parse(body);
    final normalizedPageText = _cleanText(document.body?.text ?? body);
    final records = _parseRecords(document);
    final explicitCounts = _parseExplicitCounts(normalizedPageText);
    final aggregatedCounts = _aggregateRecordCounts(records);

    final morningExerciseCount =
        explicitCounts[SportsAttendanceCategory.morningExercise] ??
        aggregatedCounts[SportsAttendanceCategory.morningExercise] ??
        0;
    final extracurricularActivityCount =
        explicitCounts[SportsAttendanceCategory.extracurricularActivity] ??
        aggregatedCounts[SportsAttendanceCategory.extracurricularActivity] ??
        0;
    final countAdjustmentCount =
        explicitCounts[SportsAttendanceCategory.countAdjustment] ??
        aggregatedCounts[SportsAttendanceCategory.countAdjustment] ??
        0;
    final sportsCorridorCount =
        explicitCounts[SportsAttendanceCategory.sportsCorridor] ??
        aggregatedCounts[SportsAttendanceCategory.sportsCorridor] ??
        0;

    final hasAnyCount =
        morningExerciseCount != 0 ||
        extracurricularActivityCount != 0 ||
        countAdjustmentCount != 0 ||
        sportsCorridorCount != 0;
    if (!hasAnyCount && records.isEmpty) return null;

    return SportsAttendanceSummary(
      morningExerciseCount: morningExerciseCount,
      extracurricularActivityCount: extracurricularActivityCount,
      countAdjustmentCount: countAdjustmentCount,
      sportsCorridorCount: sportsCorridorCount,
      records: List.unmodifiable(records),
      fetchedAt: DateTime.now(),
      sourceUri: sourceUri,
    );
  }

  static List<SportsAttendanceRecord> _parseRecords(
    html_dom.Document document,
  ) {
    final records = <SportsAttendanceRecord>[];
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .where((cellText) => cellText.isNotEmpty)
          .toList();
      if (cells.length < 2) continue;

      final joinedCells = cells.join(' ');
      if (joinedCells.length > 500 || cells.any((cell) => cell.length > 160)) {
        continue;
      }
      final category = _categoryOf(joinedCells);
      final hasDate = _datePattern.hasMatch(joinedCells);
      final hasUsefulNumber = RegExp(
        r'-?\d+\s*次(?!数|调整)',
      ).hasMatch(joinedCells);
      if (category == SportsAttendanceCategory.unknown && !hasDate) continue;
      if (!hasDate && !hasUsefulNumber) continue;

      records.add(
        SportsAttendanceRecord(
          category: category,
          count: _recordCount(cells, category),
          cells: List.unmodifiable(cells),
          occurredAt: _firstMatchText(cells, _datePattern),
          project: _firstProject(cells, category),
          location: _firstLocation(cells),
          remark: _lastRemark(cells),
        ),
      );
    }
    return records;
  }

  static Map<SportsAttendanceCategory, int> _parseExplicitCounts(String text) {
    final counts = <SportsAttendanceCategory, int>{};
    for (final category in SportsAttendanceCategory.values) {
      if (category == SportsAttendanceCategory.unknown) continue;
      final label = RegExp.escape(category.label);
      final patterns = [
        RegExp('$label(?:总次数|次数|合计|累计)[^0-9-]{0,8}(-?\\d+)\\s*次?'),
        RegExp('(?:总|合计|累计)[^，。；;]{0,8}$label[^0-9-]{0,8}(-?\\d+)\\s*次?'),
        RegExp('$label\\s*[:：]\\s*(-?\\d+)\\s*次?'),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        final parsedCount = int.tryParse(match?.group(1) ?? '');
        if (parsedCount == null) continue;
        counts[category] = parsedCount;
        break;
      }
    }
    return counts;
  }

  static Map<SportsAttendanceCategory, int> _aggregateRecordCounts(
    List<SportsAttendanceRecord> records,
  ) {
    final counts = <SportsAttendanceCategory, int>{};
    for (final record in records) {
      if (record.category == SportsAttendanceCategory.unknown) continue;
      counts[record.category] = (counts[record.category] ?? 0) + record.count;
    }
    return counts;
  }

  static SportsAttendanceCategory _categoryOf(String text) {
    if (text.contains('早操')) return SportsAttendanceCategory.morningExercise;
    if (text.contains('次数调整') || text.contains('调整')) {
      return SportsAttendanceCategory.countAdjustment;
    }
    if (text.contains('体育长廊') || text.contains('长廊')) {
      return SportsAttendanceCategory.sportsCorridor;
    }
    if (text.contains('课外活动') || text.contains('课外')) {
      return SportsAttendanceCategory.extracurricularActivity;
    }
    return SportsAttendanceCategory.unknown;
  }

  static int _recordCount(
    List<String> cells,
    SportsAttendanceCategory category,
  ) {
    final joinedCells = cells.join(' ');
    if (joinedCells.contains('无效')) return 0;
    final countWithUnit = RegExp(
      r'(-?\d+)\s*次(?!数|调整)',
    ).firstMatch(joinedCells);
    final parsedCountWithUnit = int.tryParse(countWithUnit?.group(1) ?? '');
    if (parsedCountWithUnit != null) return parsedCountWithUnit;

    if (category == SportsAttendanceCategory.countAdjustment) {
      for (final cell in cells.reversed) {
        if (_datePattern.hasMatch(cell)) continue;
        final parsedSignedCount = int.tryParse(cell.trim());
        if (parsedSignedCount != null) return parsedSignedCount;
      }
    }
    return 1;
  }

  static String? _firstMatchText(List<String> cells, RegExp pattern) {
    for (final cell in cells) {
      final match = pattern.firstMatch(cell);
      if (match != null) return match.group(0);
    }
    return null;
  }

  static String? _firstProject(
    List<String> cells,
    SportsAttendanceCategory category,
  ) {
    for (final cell in cells) {
      if (_datePattern.hasMatch(cell)) continue;
      if (RegExp(r'^-?\d+\s*次?$').hasMatch(cell)) continue;
      if (cell == category.label) continue;
      if (_looksLikeLocation(cell)) continue;
      return cell;
    }
    return category == SportsAttendanceCategory.unknown ? null : category.label;
  }

  static String? _firstLocation(List<String> cells) {
    for (final cell in cells) {
      if (_looksLikeLocation(cell)) return cell;
    }
    return null;
  }

  static String? _lastRemark(List<String> cells) {
    for (final cell in cells.reversed) {
      if (_datePattern.hasMatch(cell)) continue;
      if (RegExp(r'^-?\d+\s*次?$').hasMatch(cell)) continue;
      if (_looksLikeLocation(cell)) continue;
      return cell;
    }
    return null;
  }

  static bool _looksLikeLocation(String text) {
    return text.contains('场') ||
        text.contains('馆') ||
        text.contains('房') ||
        text.contains('长廊') ||
        text.contains('校区') ||
        text.contains('操场');
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final RegExp _datePattern = RegExp(
    r'\d{4}[-/]\d{1,2}[-/]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?',
  );
}
