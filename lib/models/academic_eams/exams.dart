/*
 * 本专科教务系统考试模型
 * @Project : SSPU-all-in-one
 * @File : exams.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 单条考试安排。
class AcademicExamRecord {
  const AcademicExamRecord({
    required this.courseName,
    required this.rawCells,
    this.examTime,
    this.location,
    this.seatNumber,
    this.status,
  });

  /// 课程名称。
  final String courseName;

  /// 考试时间文本。
  final String? examTime;

  /// 考试地点。
  final String? location;

  /// 座位号。
  final String? seatNumber;

  /// 页面中的状态或备注。
  final String? status;

  /// 原始单元格文本。
  final List<String> rawCells;
}

/// 考试安排快照。
class AcademicExamSnapshot {
  const AcademicExamSnapshot({
    required this.records,
    required this.fetchedAt,
    required this.sourceUri,
  });

  /// 已解析的考试记录。
  final List<AcademicExamRecord> records;

  /// 解析完成时间。
  final DateTime fetchedAt;

  /// 来源页面地址。
  final Uri sourceUri;
}
