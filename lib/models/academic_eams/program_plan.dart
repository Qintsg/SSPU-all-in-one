/*
 * 本专科教务系统培养计划模型
 * @Project : SSPU-all-in-one
 * @File : program_plan.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 培养计划中的单门课程。
class AcademicProgramPlanCourse {
  const AcademicProgramPlanCourse({
    required this.courseName,
    required this.rawCells,
    this.courseCode,
    this.credit,
    this.moduleName,
    this.category,
    this.suggestedTerm,
  });

  /// 课程名称。
  final String courseName;

  /// 课程代码。
  final String? courseCode;

  /// 学分。
  final double? credit;

  /// 模块名称。
  final String? moduleName;

  /// 类别或课程性质。
  final String? category;

  /// 建议修读学期。
  final String? suggestedTerm;

  /// 原始单元格文本。
  final List<String> rawCells;
}

/// 培养计划快照。
class AcademicProgramPlanSnapshot {
  const AcademicProgramPlanSnapshot({
    required this.courses,
    required this.fetchedAt,
    required this.sourceUri,
    this.planName,
  });

  /// 培养计划名称。
  final String? planName;

  /// 培养计划课程列表。
  final List<AcademicProgramPlanCourse> courses;

  /// 解析完成时间。
  final DateTime fetchedAt;

  /// 来源页面地址。
  final Uri sourceUri;
}

/// 单个培养计划模块的完成进度。
class AcademicProgramModuleProgress {
  const AcademicProgramModuleProgress({
    required this.moduleName,
    required this.totalCourseCount,
    required this.completedCourseCount,
    required this.pendingCourseCount,
    required this.totalCredits,
    required this.completedCredits,
    required this.pendingCredits,
  });

  /// 模块名称。
  final String moduleName;

  /// 模块总课程数。
  final int totalCourseCount;

  /// 模块已完成课程数。
  final int completedCourseCount;

  /// 模块待完成课程数。
  final int pendingCourseCount;

  /// 模块总学分。
  final double totalCredits;

  /// 模块已修学分。
  final double completedCredits;

  /// 模块未修学分。
  final double pendingCredits;
}

/// 培养计划完成情况快照。
class AcademicProgramCompletionSnapshot {
  const AcademicProgramCompletionSnapshot({
    required this.completedCourseCount,
    required this.pendingCourseCount,
    required this.completedCredits,
    required this.pendingCredits,
    required this.moduleProgress,
  });

  /// 已完成课程数。
  final int completedCourseCount;

  /// 未完成课程数。
  final int pendingCourseCount;

  /// 已修学分。
  final double completedCredits;

  /// 未修学分。
  final double pendingCredits;

  /// 按模块聚合的完成进度。
  final List<AcademicProgramModuleProgress> moduleProgress;
}
