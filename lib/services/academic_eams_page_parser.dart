/*
 * 本专科教务页面解析器 — 解析 EAMS 课表、成绩、考试、培养计划与只读搜索表单
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

AcademicCourseTableSnapshot? _parseCourseTable(
  AcademicEamsHttpSnapshot snapshot,
) {
  final document = html_parser.parse(snapshot.body);
  for (final table in document.querySelectorAll('table')) {
    final grid = _buildTableGrid(table);
    if (grid.isEmpty) continue;
    final weekdayColumns = _extractWeekdayColumns(grid.first);
    if (weekdayColumns.length < 5) continue;

    final entries = <AcademicCourseTableEntry>[];
    var currentUnit = 0;
    for (var rowIndex = 1; rowIndex < grid.length; rowIndex++) {
      final row = grid[rowIndex];
      final rowHeader = row.isEmpty ? '' : row.first?.text ?? '';
      final parsedUnit = _extractLeadingInteger(rowHeader);
      if (parsedUnit != null) {
        currentUnit = parsedUnit;
      } else if (currentUnit == 0) {
        currentUnit = rowIndex;
      } else {
        currentUnit++;
      }

      for (final weekdayEntry in weekdayColumns.entries) {
        final columnIndex = weekdayEntry.key;
        if (columnIndex >= row.length) continue;
        final cell = row[columnIndex];
        if (cell == null || !cell.isOrigin) continue;
        final text = cell.text.trim();
        if (text.isEmpty ||
            _looksLikeWeekday(text) ||
            _looksLikeUnitLabel(text)) {
          continue;
        }
        final entry = _parseCourseTableCell(
          text,
          weekday: weekdayEntry.value,
          startUnit: currentUnit,
          endUnit: currentUnit + cell.rowSpan - 1,
        );
        if (entry != null) entries.add(entry);
      }
    }

    if (entries.isNotEmpty) {
      entries.sort((a, b) {
        final weekdayCompare = a.weekday.compareTo(b.weekday);
        if (weekdayCompare != 0) return weekdayCompare;
        return a.startUnit.compareTo(b.startUnit);
      });
      return AcademicCourseTableSnapshot(
        termName: _findTermName(document.body?.text ?? snapshot.body),
        entries: List.unmodifiable(entries),
        fetchedAt: DateTime.now(),
        sourceUri: snapshot.finalUri,
      );
    }
  }
  return null;
}

AcademicGradeSnapshot? _parseGrades(
  AcademicEamsHttpSnapshot? currentSnapshot,
  AcademicEamsHttpSnapshot? historySnapshot,
) {
  final currentRecords = currentSnapshot == null
      ? const <AcademicGradeRecord>[]
      : _parseGradeRecords(currentSnapshot.body);
  final historyRecords = historySnapshot == null
      ? const <AcademicGradeRecord>[]
      : _parseGradeRecords(historySnapshot.body);
  if (currentRecords.isEmpty && historyRecords.isEmpty) return null;

  final sourceUri = historySnapshot?.finalUri ?? currentSnapshot!.finalUri;
  return AcademicGradeSnapshot(
    currentTermRecords: currentRecords,
    historyRecords: historyRecords,
    fetchedAt: DateTime.now(),
    sourceUri: sourceUri,
  );
}

AcademicProgramPlanSnapshot? _parseProgramPlan(
  AcademicEamsHttpSnapshot? snapshot,
) {
  if (snapshot == null) return null;
  final document = html_parser.parse(snapshot.body);
  for (final table in _parseTables(document)) {
    final headers = table.headers
        .map((header) => header.toLowerCase())
        .toList();
    if (!_containsAny(headers, ['课程名称', '课程', 'course']) ||
        !_containsAny(headers, ['学分', 'credit'])) {
      continue;
    }

    final courses = <AcademicProgramPlanCourse>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程', '课程名']);
      if (courseName == null || courseName.isEmpty) continue;
      courses.add(
        AcademicProgramPlanCourse(
          courseName: courseName,
          courseCode: _pickValue(rowMap, ['课程代码', '课程编号', '课程序号']),
          credit: _parseDouble(_pickValue(rowMap, ['学分'])),
          moduleName: _pickValue(rowMap, ['模块', '模块名称']),
          category: _pickValue(rowMap, ['类别', '课程性质']),
          suggestedTerm: _pickValue(rowMap, ['建议学期', '学期']),
          rawCells: row,
        ),
      );
    }
    if (courses.isNotEmpty) {
      return AcademicProgramPlanSnapshot(
        planName: _extractHeadingText(document, ['培养计划', '教学计划']),
        courses: List.unmodifiable(courses),
        fetchedAt: DateTime.now(),
        sourceUri: snapshot.finalUri,
      );
    }
  }
  return null;
}

AcademicProgramCompletionSnapshot? _deriveProgramCompletion(
  AcademicProgramPlanSnapshot? plan,
  AcademicGradeSnapshot? grades,
) {
  if (plan == null || plan.courses.isEmpty) return null;

  final passedKeys = <String>{};
  if (grades != null) {
    for (final grade in [
      ...grades.currentTermRecords,
      ...grades.historyRecords,
    ]) {
      if (!grade.isPassed) continue;
      final key = _normalizeMatchKey(grade.courseCode ?? grade.courseName);
      if (key.isNotEmpty) passedKeys.add(key);
    }
  }

  final moduleBuckets = <String, List<AcademicProgramPlanCourse>>{};
  var completedCourseCount = 0;
  var pendingCourseCount = 0;
  var completedCredits = 0.0;
  var pendingCredits = 0.0;

  for (final course in plan.courses) {
    final key = _normalizeMatchKey(course.courseCode ?? course.courseName);
    final passed = key.isNotEmpty && passedKeys.contains(key);
    final moduleName = course.moduleName ?? course.category ?? '未分组模块';
    moduleBuckets.putIfAbsent(moduleName, () => []).add(course);
    final credit = course.credit ?? 0;
    if (passed) {
      completedCourseCount++;
      completedCredits += credit;
    } else {
      pendingCourseCount++;
      pendingCredits += credit;
    }
  }

  final progress = moduleBuckets.entries.map((entry) {
    final courses = entry.value;
    var completedCount = 0;
    var completedModuleCredits = 0.0;
    var totalCredits = 0.0;
    for (final course in courses) {
      final key = _normalizeMatchKey(course.courseCode ?? course.courseName);
      final passed = key.isNotEmpty && passedKeys.contains(key);
      final credit = course.credit ?? 0;
      totalCredits += credit;
      if (passed) {
        completedCount++;
        completedModuleCredits += credit;
      }
    }
    return AcademicProgramModuleProgress(
      moduleName: entry.key,
      totalCourseCount: courses.length,
      completedCourseCount: completedCount,
      pendingCourseCount: courses.length - completedCount,
      totalCredits: totalCredits,
      completedCredits: completedModuleCredits,
      pendingCredits: totalCredits - completedModuleCredits,
    );
  }).toList()..sort((a, b) => a.moduleName.compareTo(b.moduleName));

  return AcademicProgramCompletionSnapshot(
    completedCourseCount: completedCourseCount,
    pendingCourseCount: pendingCourseCount,
    completedCredits: completedCredits,
    pendingCredits: pendingCredits,
    moduleProgress: List.unmodifiable(progress),
  );
}

AcademicExamSnapshot? _parseExams(AcademicEamsHttpSnapshot? snapshot) {
  if (snapshot == null) return null;
  final document = html_parser.parse(snapshot.body);
  for (final table in _parseTables(document)) {
    final headers = table.headers
        .map((header) => header.toLowerCase())
        .toList();
    if (!_containsAny(headers, ['课程名称', '课程']) ||
        !_containsAny(headers, ['考试时间', '时间'])) {
      continue;
    }

    final records = <AcademicExamRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程']);
      if (courseName == null || courseName.isEmpty) continue;
      records.add(
        AcademicExamRecord(
          courseName: courseName,
          examTime: _pickValue(rowMap, ['考试时间', '时间']),
          location: _pickValue(rowMap, ['考试地点', '地点']),
          seatNumber: _pickValue(rowMap, ['座位号', '座位']),
          status: _pickValue(rowMap, ['状态', '备注']),
          rawCells: row,
        ),
      );
    }
    if (records.isNotEmpty) {
      return AcademicExamSnapshot(
        records: List.unmodifiable(records),
        fetchedAt: DateTime.now(),
        sourceUri: snapshot.finalUri,
      );
    }
  }
  return null;
}

AcademicCourseOfferingSearchResult? _parseCourseOfferings(
  AcademicEamsHttpSnapshot? snapshot,
  AcademicCourseOfferingSearchCriteria criteria,
) {
  if (snapshot == null) return null;
  final document = html_parser.parse(snapshot.body);
  for (final table in _parseTables(document)) {
    final headers = table.headers
        .map((header) => header.toLowerCase())
        .toList();
    if (!_containsAny(headers, ['课程名称', '课程']) ||
        !_containsAny(headers, ['教师', '老师', '任课教师'])) {
      continue;
    }
    final records = <AcademicCourseOfferingRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程']);
      if (courseName == null || courseName.isEmpty) continue;
      records.add(
        AcademicCourseOfferingRecord(
          courseName: courseName,
          courseCode: _pickValue(rowMap, ['课程代码', '课程编号']),
          teacher: _pickValue(rowMap, ['教师', '老师', '任课教师']),
          credit: _parseDouble(_pickValue(rowMap, ['学分'])),
          capacity: _parseInt(_pickValue(rowMap, ['容量', '课容量', '人数上限'])),
          department: _pickValue(rowMap, ['开课院系', '院系', '学院']),
          scheduleText: _pickValue(rowMap, ['上课时间', '时间', '课表']),
          locationText: _pickValue(rowMap, ['地点', '教室', '上课地点']),
          termName: _pickValue(rowMap, ['学期', '学年学期']),
          rawCells: row,
        ),
      );
    }
    if (records.isNotEmpty) {
      return AcademicCourseOfferingSearchResult(
        criteria: criteria,
        records: List.unmodifiable(records),
        fetchedAt: DateTime.now(),
        sourceUri: snapshot.finalUri,
      );
    }
  }
  return null;
}

AcademicFreeClassroomSearchResult? _parseFreeClassrooms(
  AcademicEamsHttpSnapshot? snapshot,
  AcademicFreeClassroomSearchCriteria criteria,
) {
  if (snapshot == null) return null;
  final document = html_parser.parse(snapshot.body);
  for (final table in _parseTables(document)) {
    final headers = table.headers
        .map((header) => header.toLowerCase())
        .toList();
    if (!_containsAny(headers, ['教室']) ||
        !_containsAny(headers, ['楼宇', '楼', '建筑'])) {
      continue;
    }
    final records = <AcademicFreeClassroomRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final roomName = _pickValue(rowMap, ['教室', '教室名称', '房间']);
      if (roomName == null || roomName.isEmpty) continue;
      records.add(
        AcademicFreeClassroomRecord(
          roomName: roomName,
          campus: _pickValue(rowMap, ['校区']),
          building: _pickValue(rowMap, ['楼宇', '楼', '建筑']),
          location: _pickValue(rowMap, ['位置', '地点']),
          capacity: _parseInt(_pickValue(rowMap, ['容量', '座位数'])),
          dateText: _pickValue(rowMap, ['日期']),
          lessonText: _pickValue(rowMap, ['节次', '时间']),
          rawCells: row,
        ),
      );
    }
    if (records.isNotEmpty) {
      return AcademicFreeClassroomSearchResult(
        criteria: criteria,
        records: List.unmodifiable(records),
        fetchedAt: DateTime.now(),
        sourceUri: snapshot.finalUri,
      );
    }
  }
  return null;
}

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
      final selectedOption = select
          .querySelectorAll('option')
          .firstWhere(
            (option) => option.attributes.containsKey('selected'),
            orElse: () =>
                select.querySelector('option') ??
                html_dom.Element.tag('option'),
          );
      final selectedValue =
          selectedOption.attributes['value']?.trim() ??
          _cleanText(selectedOption.text);
      defaults[name] = selectedValue;
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

List<AcademicGradeRecord> _parseGradeRecords(String body) {
  final document = html_parser.parse(body);
  for (final table in _parseTables(document)) {
    final headers = table.headers
        .map((header) => header.toLowerCase())
        .toList();
    if (!_containsAny(headers, ['课程名称', '课程']) ||
        !_containsAny(headers, ['成绩', '分数', '总评'])) {
      continue;
    }

    final records = <AcademicGradeRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程']);
      if (courseName == null || courseName.isEmpty) continue;
      records.add(
        AcademicGradeRecord(
          courseName: courseName,
          courseCode: _pickValue(rowMap, ['课程代码', '课程编号']),
          termName: _pickValue(rowMap, ['学年学期', '学期']),
          scoreText: _pickValue(rowMap, ['总评成绩', '成绩', '分数', '最终成绩']) ?? '',
          credit: _parseDouble(_pickValue(rowMap, ['学分'])),
          gradePoint: _parseDouble(_pickValue(rowMap, ['绩点', 'GP', 'gpa'])),
          processScoreText: _pickValue(rowMap, ['平时成绩', '过程成绩', '过程化成绩']),
          totalScoreText: _pickValue(rowMap, ['总评成绩', '最终成绩']),
          rawCells: row,
        ),
      );
    }
    if (records.isNotEmpty) return List.unmodifiable(records);
  }
  return const <AcademicGradeRecord>[];
}

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

String _cleanText(String value) {
  return value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _PendingGridCell {
  _PendingGridCell({required this.cell, required this.remainingRows});

  final _GridCell cell;
  int remainingRows;
}
