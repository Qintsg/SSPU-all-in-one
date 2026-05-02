/*
 * 本专科教务表格解析辅助 — 构建网格、课表单元格与通用表格读取工具
 * @Project : SSPU-all-in-one
 * @File : academic_eams_page_parser_tables.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

List<List<_GridCell?>> _buildTableGrid(html_dom.Element table) {
  final grid = <List<_GridCell?>>[];
  final pending = <int, _PendingGridCell>{};
  var maxColumnCount = 0;

  for (final row in table.querySelectorAll('tr')) {
    final gridRow = <_GridCell?>[];
    var columnIndex = 0;

    void fillPendingCells() {
      while (pending.containsKey(columnIndex)) {
        final pendingCell = pending[columnIndex]!;
        gridRow.add(
          _GridCell(
            text: pendingCell.cell.text,
            rowSpan: pendingCell.cell.rowSpan,
            colSpan: pendingCell.cell.colSpan,
            isOrigin: false,
          ),
        );
        pendingCell.remainingRows--;
        if (pendingCell.remainingRows <= 0) {
          pending.remove(columnIndex);
        }
        columnIndex++;
      }
    }

    fillPendingCells();
    for (final cell in row.querySelectorAll('th,td')) {
      fillPendingCells();
      final rowSpan = _parsePositiveInt(cell.attributes['rowspan']) ?? 1;
      final colSpan = _parsePositiveInt(cell.attributes['colspan']) ?? 1;
      final gridCell = _GridCell(
        text: _extractCellText(cell),
        rowSpan: rowSpan,
        colSpan: colSpan,
        isOrigin: true,
      );
      for (var offset = 0; offset < colSpan; offset++) {
        gridRow.add(
          _GridCell(
            text: gridCell.text,
            rowSpan: rowSpan,
            colSpan: colSpan,
            isOrigin: offset == 0,
          ),
        );
        if (rowSpan > 1) {
          pending[columnIndex + offset] = _PendingGridCell(
            cell: gridCell,
            remainingRows: rowSpan - 1,
          );
        }
      }
      columnIndex += colSpan;
      fillPendingCells();
    }
    fillPendingCells();
    if (gridRow.isNotEmpty) {
      maxColumnCount = maxColumnCount > gridRow.length
          ? maxColumnCount
          : gridRow.length;
      grid.add(gridRow);
    }
  }

  for (final row in grid) {
    while (row.length < maxColumnCount) {
      row.add(null);
    }
  }
  return grid;
}

Map<int, int> _extractWeekdayColumns(List<_GridCell?> headerRow) {
  final weekdayColumns = <int, int>{};
  for (var index = 0; index < headerRow.length; index++) {
    final text = headerRow[index]?.text ?? '';
    final weekday = _parseWeekday(text);
    if (weekday != null) weekdayColumns[index] = weekday;
  }
  return weekdayColumns;
}

AcademicCourseTableEntry? _parseCourseTableCell(
  String rawText, {
  required int weekday,
  required int startUnit,
  required int endUnit,
}) {
  final lines = rawText
      .split('\n')
      .map(_cleanText)
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;

  final courseName = lines.first;
  String? teacher;
  String? location;
  String? weeks;
  for (final line in lines.skip(1)) {
    if (weeks == null && _looksLikeWeekDescription(line)) {
      weeks = line;
      continue;
    }
    if (location == null && _looksLikeLocation(line)) {
      location = line;
      continue;
    }
    if (teacher == null && _looksLikeTeacher(line)) {
      teacher = line;
      continue;
    }
  }
  return AcademicCourseTableEntry(
    courseName: courseName,
    weekday: weekday,
    startUnit: startUnit,
    endUnit: endUnit,
    timeText: '${_weekdayLabel(weekday)} 第$startUnit-$endUnit节',
    teacher: teacher,
    location: location,
    weekDescription: weeks,
    rawText: rawText,
  );
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    1 => '周一',
    2 => '周二',
    3 => '周三',
    4 => '周四',
    5 => '周五',
    6 => '周六',
    7 => '周日',
    _ => '未知',
  };
}

bool _looksLikeProfileLabel(String text) {
  return ['姓名', '学生姓名', '学号', '学工号', '院系', '学院', '专业', '班级'].contains(text);
}

void _captureProfileByRegex(
  Map<String, String> rawFields,
  String bodyText,
  String label,
) {
  final pattern = RegExp('$label[:：]\\s*([^\\s]+)');
  final match = pattern.firstMatch(bodyText);
  final value = match?.group(1)?.trim();
  if (value != null && value.isNotEmpty) {
    rawFields.putIfAbsent(label, () => value);
  }
}

String? _findTermName(String text) {
  final pattern = RegExp(r'(\d{4}\s*-\s*\d{4}.*?(?:学年|学期)[^ ]*)');
  final match = pattern.firstMatch(text);
  return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _extractHeadingText(html_dom.Document document, List<String> keywords) {
  for (final selector in ['h1', 'h2', 'h3', '.title', '.caption']) {
    for (final element in document.querySelectorAll(selector)) {
      final text = _cleanText(element.text);
      if (text.isEmpty) continue;
      if (keywords.any(text.contains)) return text;
    }
  }
  return null;
}

List<_ParsedTable> _parseTables(html_dom.Document document) {
  final result = <_ParsedTable>[];
  for (final table in document.querySelectorAll('table')) {
    final rows = <List<String>>[];
    for (final row in table.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .toList();
      if (cells.any((text) => text.isNotEmpty)) rows.add(cells);
    }
    if (rows.length < 2) continue;
    final headers = rows.first;
    final dataRows = rows.skip(1).where((row) => row.isNotEmpty).toList();
    if (headers.every((text) => text.isEmpty) || dataRows.isEmpty) continue;
    result.add(_ParsedTable(headers: headers, rows: dataRows));
  }
  return result;
}

String _normalizeMatchKey(String value) {
  return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

int? _extractLeadingInteger(String text) {
  final match = RegExp(r'(\d+)').firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _parseWeekday(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  return switch (normalized) {
    '星期一' || '周一' => 1,
    '星期二' || '周二' => 2,
    '星期三' || '周三' => 3,
    '星期四' || '周四' => 4,
    '星期五' || '周五' => 5,
    '星期六' || '周六' => 6,
    '星期日' || '星期天' || '周日' => 7,
    _ => null,
  };
}

bool _looksLikeWeekday(String text) => _parseWeekday(text) != null;

bool _looksLikeUnitLabel(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  return normalized.contains('节') ||
      normalized.contains('第') && normalized.length <= 6;
}

bool _looksLikeWeekDescription(String text) {
  return text.contains('周') || text.contains('单双');
}

bool _looksLikeLocation(String text) {
  return text.contains('楼') ||
      text.contains('室') ||
      text.contains('馆') ||
      text.contains('教') ||
      text.contains('实验') ||
      text.contains('线上');
}

bool _looksLikeTeacher(String text) {
  return text.contains('老师') ||
      (RegExp(r'^[\u4e00-\u9fa5·]{2,12}$').hasMatch(text) &&
          !_looksLikeLocation(text) &&
          !_looksLikeWeekDescription(text));
}

String _extractCellText(html_dom.Element cell) {
  final html = cell.innerHtml.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  final text = html_parser.parseFragment(html).text ?? '';
  return text
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

class _PendingGridCell {
  _PendingGridCell({required this.cell, required this.remainingRows});

  final _GridCell cell;
  int remainingRows;
}
