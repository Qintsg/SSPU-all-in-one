/*
 * 本专科教务系统空闲教室模型
 * @Project : SSPU-all-in-one
 * @File : free_classrooms.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 空闲教室查询条件。
class AcademicFreeClassroomSearchCriteria {
  const AcademicFreeClassroomSearchCriteria({
    this.campus,
    this.building,
    this.dateText,
    this.lessonFrom,
    this.lessonTo,
  });

  /// 校区。
  final String? campus;

  /// 楼宇。
  final String? building;

  /// 查询日期原始文本。
  final String? dateText;

  /// 起始节次。
  final int? lessonFrom;

  /// 结束节次。
  final int? lessonTo;
}

/// 单条空闲教室记录。
class AcademicFreeClassroomRecord {
  const AcademicFreeClassroomRecord({
    required this.roomName,
    required this.rawCells,
    this.campus,
    this.building,
    this.location,
    this.capacity,
    this.dateText,
    this.lessonText,
  });

  /// 教室名称。
  final String roomName;

  /// 校区。
  final String? campus;

  /// 楼宇。
  final String? building;

  /// 位置说明。
  final String? location;

  /// 容量。
  final int? capacity;

  /// 日期文本。
  final String? dateText;

  /// 节次文本。
  final String? lessonText;

  /// 原始单元格文本。
  final List<String> rawCells;
}

/// 空闲教室查询结果。
class AcademicFreeClassroomSearchResult {
  const AcademicFreeClassroomSearchResult({
    required this.criteria,
    required this.records,
    required this.fetchedAt,
    required this.sourceUri,
  });

  /// 本次查询条件。
  final AcademicFreeClassroomSearchCriteria criteria;

  /// 命中的空闲教室记录。
  final List<AcademicFreeClassroomRecord> records;

  /// 解析完成时间。
  final DateTime fetchedAt;

  /// 来源页面地址。
  final Uri sourceUri;
}
