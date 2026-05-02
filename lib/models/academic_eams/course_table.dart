/*
 * 本专科教务系统课表模型
 * @Project : SSPU-all-in-one
 * @File : course_table.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 单条课表课程记录。
class AcademicCourseTableEntry {
  const AcademicCourseTableEntry({
    required this.courseName,
    required this.weekday,
    required this.startUnit,
    required this.endUnit,
    required this.timeText,
    required this.rawText,
    this.teacher,
    this.location,
    this.weekDescription,
  });

  /// 课程名称。
  final String courseName;

  /// 星期序号，1=周一，7=周日。
  final int weekday;

  /// 起始节次。
  final int startUnit;

  /// 结束节次。
  final int endUnit;

  /// 由节次与星期生成的展示时间文本。
  final String timeText;

  /// 教师名称。
  final String? teacher;

  /// 上课地点。
  final String? location;

  /// 周次或单双周说明。
  final String? weekDescription;

  /// 单元格原始文本，供解析降级展示。
  final String rawText;

  /// 友好的星期文案。
  String get weekdayLabel {
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
}

/// 当前学期课表快照。
class AcademicCourseTableSnapshot {
  const AcademicCourseTableSnapshot({
    required this.entries,
    required this.fetchedAt,
    required this.sourceUri,
    this.termName,
  });

  /// 当前学期名称。
  final String? termName;

  /// 结构化课程记录。
  final List<AcademicCourseTableEntry> entries;

  /// 课表解析完成时间。
  final DateTime fetchedAt;

  /// 产生该快照的业务页面地址。
  final Uri sourceUri;
}
