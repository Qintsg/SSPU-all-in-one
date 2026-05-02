/*
 * 本专科教务系统成绩模型
 * @Project : SSPU-all-in-one
 * @File : grades.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 单条成绩记录。
class AcademicGradeRecord {
  const AcademicGradeRecord({
    required this.courseName,
    required this.scoreText,
    required this.rawCells,
    this.courseCode,
    this.termName,
    this.credit,
    this.gradePoint,
    this.processScoreText,
    this.totalScoreText,
  });

  /// 课程名称。
  final String courseName;

  /// 课程代码。
  final String? courseCode;

  /// 学年学期。
  final String? termName;

  /// 页面原始成绩文本。
  final String scoreText;

  /// 学分。
  final double? credit;

  /// 绩点。
  final double? gradePoint;

  /// 当前学期过程化成绩文本。
  final String? processScoreText;

  /// 当前学期总成绩文本。
  final String? totalScoreText;

  /// 原始单元格文本。
  final List<String> rawCells;

  /// 是否可视为通过，用于培养计划完成情况的保守统计。
  bool get isPassed {
    final normalized = scoreText.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized.contains('不及格') || normalized.contains('未通过')) {
      return false;
    }
    if (normalized.contains('通过') || normalized.contains('及格')) return true;
    final numeric = double.tryParse(normalized.replaceAll('%', ''));
    return numeric != null && numeric >= 60;
  }
}

/// 成绩查询快照。
class AcademicGradeSnapshot {
  const AcademicGradeSnapshot({
    required this.currentTermRecords,
    required this.historyRecords,
    required this.fetchedAt,
    required this.sourceUri,
  });

  /// 当前学期成绩记录。
  final List<AcademicGradeRecord> currentTermRecords;

  /// 历史成绩记录。
  final List<AcademicGradeRecord> historyRecords;

  /// 解析完成时间。
  final DateTime fetchedAt;

  /// 产生该快照的最后页面地址。
  final Uri sourceUri;
}
