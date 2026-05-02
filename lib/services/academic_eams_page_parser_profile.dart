/*
 * 本专科教务个人信息解析器 — 解析 EAMS 页面中的学生基础信息
 * @Project : SSPU-all-in-one
 * @File : academic_eams_page_parser_profile.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

AcademicEamsProfile? _parseProfile(List<AcademicEamsHttpSnapshot> snapshots) {
  final rawFields = <String, String>{};
  for (final snapshot in snapshots) {
    final document = html_parser.parse(snapshot.body);
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .where((text) => text.isNotEmpty)
          .toList();
      if (cells.length < 2) continue;
      for (var index = 0; index < cells.length - 1; index++) {
        final label = cells[index].replaceAll(RegExp(r'[:：]$'), '').trim();
        final value = cells[index + 1].trim();
        if (_looksLikeProfileLabel(label) && value.isNotEmpty) {
          rawFields.putIfAbsent(label, () => value);
        }
      }
    }

    final bodyText = _cleanText(document.body?.text ?? snapshot.body);
    _captureProfileByRegex(rawFields, bodyText, '姓名');
    _captureProfileByRegex(rawFields, bodyText, '学号');
    _captureProfileByRegex(rawFields, bodyText, '院系');
    _captureProfileByRegex(rawFields, bodyText, '专业');
    _captureProfileByRegex(rawFields, bodyText, '班级');
  }

  if (rawFields.isEmpty) return null;
  final profile = AcademicEamsProfile(
    name: rawFields['姓名'] ?? rawFields['学生姓名'],
    studentId: rawFields['学号'] ?? rawFields['学工号'],
    department: rawFields['院系'] ?? rawFields['学院'],
    major: rawFields['专业'],
    className: rawFields['班级'],
    rawFields: Map.unmodifiable(rawFields),
  );
  return profile.hasAnyValue ? profile : null;
}
