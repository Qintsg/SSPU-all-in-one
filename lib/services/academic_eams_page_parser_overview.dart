/*
 * 本专科教务概览解析器 — 解析课表、成绩、培养计划、考试与只读检索结果
 * @Project : SSPU-all-in-one
 * @File : academic_eams_page_parser_overview.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

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
  final activityEntries = _parseCourseTableActivities(snapshot.body);
  if (activityEntries.isNotEmpty) {
    activityEntries.sort((a, b) {
      final weekdayCompare = a.weekday.compareTo(b.weekday);
      if (weekdayCompare != 0) return weekdayCompare;
      return a.startUnit.compareTo(b.startUnit);
    });
    return AcademicCourseTableSnapshot(
      termName: _findTermName(document.body?.text ?? snapshot.body),
      entries: List.unmodifiable(activityEntries),
      fetchedAt: DateTime.now(),
      sourceUri: snapshot.finalUri,
    );
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
      final codeKey = _normalizeMatchKey(grade.courseCode ?? '');
      final nameKey = _normalizeMatchKey(grade.courseName);
      if (codeKey.isNotEmpty) passedKeys.add(codeKey);
      if (nameKey.isNotEmpty) passedKeys.add(nameKey);
    }
  }

  final moduleBuckets = <String, List<AcademicProgramPlanCourse>>{};
  var completedCourseCount = 0;
  var pendingCourseCount = 0;
  var completedCredits = 0.0;
  var pendingCredits = 0.0;

  for (final course in plan.courses) {
    final codeKey = _normalizeMatchKey(course.courseCode ?? '');
    final nameKey = _normalizeMatchKey(course.courseName);
    final passed =
        (codeKey.isNotEmpty && passedKeys.contains(codeKey)) ||
        (nameKey.isNotEmpty && passedKeys.contains(nameKey));
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
      final codeKey = _normalizeMatchKey(course.courseCode ?? '');
      final nameKey = _normalizeMatchKey(course.courseName);
      final passed =
          (codeKey.isNotEmpty && passedKeys.contains(codeKey)) ||
          (nameKey.isNotEmpty && passedKeys.contains(nameKey));
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
    if (!_containsAny(headers, ['课程名称', '课程', 'course name']) ||
        !_containsAny(headers, ['考试时间', '时间', 'exam time', 'time'])) {
      continue;
    }

    final records = <AcademicExamRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程', 'Course Name']);
      if (courseName == null || courseName.isEmpty) continue;
      records.add(
        AcademicExamRecord(
          courseName: courseName,
          examTime: _pickValue(rowMap, ['考试时间', '时间', 'Exam Time', 'Time']),
          location: _pickValue(rowMap, ['考试地点', '地点', 'Exam Room', 'Place']),
          seatNumber: _pickValue(rowMap, ['座位号', '座位', 'Seat No', 'Seat']),
          status: _pickValue(rowMap, ['状态', '备注', 'Status', 'Remark']),
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
    if (!_containsAny(headers, ['课程名称', '课程', 'course name']) ||
        !_containsAny(headers, ['教师', '老师', '任课教师', 'teacher'])) {
      continue;
    }
    final records = <AcademicCourseOfferingRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程', 'Course Name']);
      if (courseName == null || courseName.isEmpty) continue;
      records.add(
        AcademicCourseOfferingRecord(
          courseName: courseName,
          courseCode: _pickValue(rowMap, ['课程代码', '课程编号', 'Course Code']),
          teacher: _pickValue(rowMap, ['教师', '老师', '任课教师', 'Teacher']),
          credit: _parseDouble(_pickValue(rowMap, ['学分', 'Credit'])),
          capacity: _parseInt(
            _pickValue(rowMap, ['容量', '课容量', '人数上限', 'Capacity']),
          ),
          department: _pickValue(rowMap, ['开课院系', '院系', '学院', 'Department']),
          scheduleText: _pickValue(rowMap, [
            '上课时间',
            '时间',
            '课表',
            'Schedule',
            'Time',
          ]),
          locationText: _pickValue(rowMap, [
            '地点',
            '教室',
            '上课地点',
            'Place',
            'Classroom',
          ]),
          termName: _pickValue(rowMap, ['学期', '学年学期', 'Term']),
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

List<AcademicGradeRecord> _parseGradeRecords(String body) {
  final document = html_parser.parse(body);
  for (final table in _parseTables(document)) {
    final headers = table.headers
        .map((header) => header.toLowerCase())
        .toList();
    if (!_containsAny(headers, ['课程名称', '课程', 'course name']) ||
        !_containsAny(headers, ['成绩', '分数', '总评', 'grade', 'final'])) {
      continue;
    }

    final records = <AcademicGradeRecord>[];
    for (final row in table.rows) {
      final rowMap = _rowToMap(table.headers, row);
      final courseName = _pickValue(rowMap, ['课程名称', '课程', 'Course Name']);
      if (courseName == null || courseName.isEmpty) continue;
      records.add(
        AcademicGradeRecord(
          courseName: courseName,
          courseCode: _pickValue(rowMap, ['课程代码', '课程编号', 'Course Code']),
          termName: _pickValue(rowMap, [
            '学年学期',
            '学期',
            'Academic Year & Semester',
            'Term',
          ]),
          scoreText:
              _pickValue(rowMap, [
                '总评成绩',
                '成绩',
                '分数',
                '最终成绩',
                '总评',
                '最终',
                'Grade',
                'Final',
              ]) ??
              '',
          credit: _parseDouble(_pickValue(rowMap, ['学分', 'Credit'])),
          gradePoint: _parseDouble(
            _pickValue(rowMap, ['绩点', 'GP', 'gpa', 'Grade Point']),
          ),
          processScoreText: _pickValue(rowMap, [
            '平时成绩',
            '过程成绩',
            '过程化成绩',
            'Process Grade',
          ]),
          totalScoreText: _pickValue(rowMap, [
            '总评成绩',
            '最终成绩',
            '总评',
            '最终',
            'Grade',
            'Final',
          ]),
          rawCells: row,
        ),
      );
    }
    if (records.isNotEmpty) return List.unmodifiable(records);
  }
  return const <AcademicGradeRecord>[];
}
