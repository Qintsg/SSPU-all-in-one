/*
 * 本专科教务查询表单解析器 — 解析开课检索与空闲教室的只读查询参数
 * @Project : SSPU-all-in-one
 * @File : academic_eams_page_parser_forms.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

_AcademicReadonlyQueryForm? _parseCourseOfferingQueryForm(
  AcademicEamsHttpSnapshot snapshot,
) {
  return _parseReadonlyQueryForm(
    snapshot,
    intentPatterns: const {
      _AcademicQueryField.termName: ['term', 'semester', 'project'],
      _AcademicQueryField.courseCode: ['coursecode', 'code', 'lessoncode'],
      _AcademicQueryField.courseName: ['coursename', 'name', 'lessonname'],
      _AcademicQueryField.teacher: ['teacher'],
      _AcademicQueryField.department: ['department', 'college', 'open'],
    },
    labelKeywords: const ['开课', '课程', '教师', '院系'],
  );
}

_AcademicReadonlyQueryForm? _parseFreeClassroomQueryForm(
  AcademicEamsHttpSnapshot snapshot,
) {
  return _parseReadonlyQueryForm(
    snapshot,
    intentPatterns: const {
      _AcademicQueryField.campus: ['campus'],
      _AcademicQueryField.building: ['building', 'build'],
      _AcademicQueryField.dateText: ['date', 'day', 'calendar'],
      _AcademicQueryField.lessonFrom: ['start', 'from', 'begin'],
      _AcademicQueryField.lessonTo: ['end', 'to', 'finish'],
    },
    labelKeywords: const ['空闲', '教室', '校区', '楼宇', '节次'],
  );
}

_AcademicReadonlyQueryForm? _parseReadonlyQueryForm(
  AcademicEamsHttpSnapshot snapshot, {
  required Map<_AcademicQueryField, List<String>> intentPatterns,
  required List<String> labelKeywords,
}) {
  final document = html_parser.parse(snapshot.body);
  for (final form in document.querySelectorAll('form')) {
    final fieldNames = form
        .querySelectorAll('input,select,textarea')
        .map((element) => element.attributes['name']?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    if (fieldNames.isEmpty) continue;

    final formText = _cleanText(form.text).toLowerCase();
    final hasKeyword = labelKeywords.any(
      (keyword) => formText.contains(keyword.toLowerCase()),
    );
    final mappedFields = <_AcademicQueryField, String>{};
    for (final patternEntry in intentPatterns.entries) {
      final fieldName = fieldNames.firstWhere(
        (candidate) => patternEntry.value.any(
          (pattern) => candidate.toLowerCase().contains(pattern),
        ),
        orElse: () => '',
      );
      if (fieldName.isNotEmpty) mappedFields[patternEntry.key] = fieldName;
    }
    if (!hasKeyword && mappedFields.isEmpty) continue;

    final defaults = <String, String>{};
    for (final input in form.querySelectorAll('input')) {
      final name = input.attributes['name']?.trim();
      if (name == null || name.isEmpty) continue;
      final type = input.attributes['type']?.toLowerCase() ?? 'text';
      if (type == 'checkbox' || type == 'radio') {
        if (input.attributes.containsKey('checked')) {
          defaults[name] = input.attributes['value'] ?? 'on';
        }
        continue;
      }
      defaults[name] = input.attributes['value'] ?? '';
    }
    for (final select in form.querySelectorAll('select')) {
      final name = select.attributes['name']?.trim();
      if (name == null || name.isEmpty) continue;
      defaults[name] = _resolveSelectDefaultValue(select);
    }
    for (final area in form.querySelectorAll('textarea')) {
      final name = area.attributes['name']?.trim();
      if (name == null || name.isEmpty) continue;
      defaults[name] = _cleanText(area.text);
    }

    final action = form.attributes['action']?.trim() ?? snapshot.finalUri.path;
    final method = form.attributes['method']?.trim().toUpperCase() ?? 'GET';
    return _AcademicReadonlyQueryForm(
      actionUri: snapshot.finalUri.resolve(action),
      method: method,
      defaultFields: Map.unmodifiable(defaults),
      fieldNamesByIntent: Map.unmodifiable(mappedFields),
    );
  }
  return null;
}

String _resolveSelectDefaultValue(html_dom.Element select) {
  final options = select.querySelectorAll('option');
  final selectedOption = options.firstWhere(
    (option) => option.attributes.containsKey('selected'),
    orElse: () => html_dom.Element.tag('option'),
  );
  if (selectedOption.attributes.isNotEmpty || selectedOption.text.isNotEmpty) {
    return selectedOption.attributes['value']?.trim() ??
        _cleanText(selectedOption.text);
  }

  final allOption = options.firstWhere((option) {
    final value = option.attributes['value']?.trim() ?? '';
    final text = _cleanText(option.text);
    return value.isEmpty || text.contains('全部') || text.contains('不限');
  }, orElse: () => html_dom.Element.tag('option'));
  if (allOption.attributes.isNotEmpty || allOption.text.isNotEmpty) {
    return allOption.attributes['value']?.trim() ?? _cleanText(allOption.text);
  }

  return '';
}
