/*
 * 本专科教务系统模型 — 描述 EAMS 只读查询结果与结构化业务数据
 * @Project : SSPU-all-in-one
 * @File : academic_eams.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'campus_network_status.dart';

/// 本专科教务系统通用查询状态。
enum AcademicEamsQueryStatus {
  /// 所需数据全部读取成功。
  success,

  /// 主要数据已读取成功，但存在可降级模块或入口未识别。
  partialSuccess,

  /// 未保存学工号 / OA 账号。
  missingOaAccount,

  /// 未保存 OA 密码。
  missingOaPassword,

  /// 校园网 / VPN 前置检测不可达。
  campusNetworkUnavailable,

  /// OA / CAS 登录状态不可用。
  oaLoginRequired,

  /// 本专科教务首页或业务页面不可用。
  systemUnavailable,

  /// 需要的只读入口未识别到。
  readOnlyEntryUnavailable,

  /// 只读查询表单不可识别，无法构造安全搜索参数。
  queryFormUnavailable,

  /// 页面结构无法解析为目标数据。
  parseFailed,

  /// 网络请求失败或超时。
  networkError,

  /// 未归类异常。
  unexpectedError,
}

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

/// 本专科教务系统首页摘要快照。
class AcademicEamsSnapshot {
  const AcademicEamsSnapshot({
    required this.fetchedAt,
    required this.sourceUri,
    required this.warnings,
    required this.hasCourseOfferingEntry,
    required this.hasFreeClassroomEntry,
    this.profile,
    this.courseTable,
    this.grades,
    this.programPlan,
    this.programCompletion,
    this.exams,
    this.courseOfferingsPreview,
    this.freeClassroomsPreview,
  });

  /// 汇总解析完成时间。
  final DateTime fetchedAt;

  /// 触发本次读取的业务页面地址。
  final Uri sourceUri;

  /// 页面可读但未完整解析的模块告警。
  final List<String> warnings;

  /// 是否已识别开课检索入口。
  final bool hasCourseOfferingEntry;

  /// 是否已识别空闲教室入口。
  final bool hasFreeClassroomEntry;

  /// 个人基本信息。
  final AcademicEamsProfile? profile;

  /// 当前学期课表。
  final AcademicCourseTableSnapshot? courseTable;

  /// 成绩快照。
  final AcademicGradeSnapshot? grades;

  /// 培养计划。
  final AcademicProgramPlanSnapshot? programPlan;

  /// 培养计划完成情况。
  final AcademicProgramCompletionSnapshot? programCompletion;

  /// 期末考试安排。
  final AcademicExamSnapshot? exams;

  /// 开课检索预览结果；仅在首页探测出结果表格时返回。
  final AcademicCourseOfferingSearchResult? courseOfferingsPreview;

  /// 空闲教室预览结果；仅在首页探测出结果表格时返回。
  final AcademicFreeClassroomSearchResult? freeClassroomsPreview;

  /// 是否至少解析出一个核心模块。
  bool get hasAnyData {
    return profile?.hasAnyValue == true ||
        (courseTable?.entries.isNotEmpty ?? false) ||
        (grades?.currentTermRecords.isNotEmpty ?? false) ||
        (grades?.historyRecords.isNotEmpty ?? false) ||
        (programPlan?.courses.isNotEmpty ?? false) ||
        (exams?.records.isNotEmpty ?? false) ||
        (courseOfferingsPreview?.records.isNotEmpty ?? false) ||
        (freeClassroomsPreview?.records.isNotEmpty ?? false);
  }
}

/// 本专科教务系统查询结果。
class AcademicEamsQueryResult {
  const AcademicEamsQueryResult({
    required this.status,
    required this.message,
    required this.detail,
    required this.checkedAt,
    required this.entranceUri,
    this.finalUri,
    this.campusNetworkStatus,
    this.snapshot,
    this.courseOfferings,
    this.freeClassrooms,
  });

  /// 结构化状态。
  final AcademicEamsQueryStatus status;

  /// 面向用户的简短说明。
  final String message;

  /// 面向排查的安全详情，不包含 Cookie、密码或 Ticket。
  final String detail;

  /// 本次查询完成时间。
  final DateTime checkedAt;

  /// 本专科教务 OA 入口。
  final Uri entranceUri;

  /// 当前流程最终地址。
  final Uri? finalUri;

  /// 校园网 / VPN 前置检测结果。
  final CampusNetworkStatus? campusNetworkStatus;

  /// 教务摘要、课表、成绩、培养计划等快照。
  final AcademicEamsSnapshot? snapshot;

  /// 开课检索结果。
  final AcademicCourseOfferingSearchResult? courseOfferings;

  /// 空闲教室查询结果。
  final AcademicFreeClassroomSearchResult? freeClassrooms;

  /// 是否可视为成功完成了用户可见读取。
  bool get isSuccess {
    return status == AcademicEamsQueryStatus.success ||
        status == AcademicEamsQueryStatus.partialSuccess;
  }
}
