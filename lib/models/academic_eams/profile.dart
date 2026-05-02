/*
 * 本专科教务系统个人信息模型
 * @Project : SSPU-all-in-one
 * @File : profile.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 本专科教务系统个人基本信息。
class AcademicEamsProfile {
  const AcademicEamsProfile({
    required this.name,
    required this.studentId,
    required this.department,
    required this.major,
    required this.className,
    required this.rawFields,
  });

  /// 学生姓名。
  final String? name;

  /// 学号。
  final String? studentId;

  /// 院系名称。
  final String? department;

  /// 专业名称。
  final String? major;

  /// 班级名称。
  final String? className;

  /// 原始字段集合，供页面结构变化时回退展示。
  final Map<String, String> rawFields;

  /// 是否至少解析出一个核心字段。
  bool get hasAnyValue {
    return [
      name,
      studentId,
      department,
      major,
      className,
    ].any((value) => value != null && value.trim().isNotEmpty);
  }
}
