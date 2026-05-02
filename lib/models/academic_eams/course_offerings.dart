/*
 * 本专科教务系统开课检索模型
 * @Project : SSPU-all-in-one
 * @File : course_offerings.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 开课检索条件。
class AcademicCourseOfferingSearchCriteria {
  const AcademicCourseOfferingSearchCriteria({
    this.termName,
    this.courseCode,
    this.courseName,
    this.teacher,
    this.department,
  });

  /// 学期名称。
  final String? termName;

  /// 课程代码。
  final String? courseCode;

  /// 课程名称。
  final String? courseName;

  /// 教师名称。
  final String? teacher;

  /// 开课院系。
  final String? department;
}

/// 单条开课记录。
class AcademicCourseOfferingRecord {
  const AcademicCourseOfferingRecord({
    required this.courseName,
    required this.rawCells,
    this.courseCode,
    this.teacher,
    this.credit,
    this.capacity,
    this.department,
    this.scheduleText,
    this.locationText,
    this.termName,
  });

  /// 课程名称。
  final String courseName;

  /// 课程代码。
  final String? courseCode;

  /// 教师名称。
  final String? teacher;

  /// 学分。
  final double? credit;

  /// 容量。
  final int? capacity;

  /// 开课院系。
  final String? department;

  /// 时间文本。
  final String? scheduleText;

  /// 地点文本。
  final String? locationText;

  /// 学期名称。
  final String? termName;

  /// 原始单元格文本。
  final List<String> rawCells;
}

/// 开课检索结果。
class AcademicCourseOfferingSearchResult {
  const AcademicCourseOfferingSearchResult({
    required this.criteria,
    required this.records,
    required this.fetchedAt,
    required this.sourceUri,
  });

  /// 本次只读搜索条件。
  final AcademicCourseOfferingSearchCriteria criteria;

  /// 命中的开课记录。
  final List<AcademicCourseOfferingRecord> records;

  /// 解析完成时间。
  final DateTime fetchedAt;

  /// 来源页面地址。
  final Uri sourceUri;
}
