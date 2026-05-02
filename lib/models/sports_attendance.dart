/*
 * 体育部课外活动考勤模型 — 描述体育部查询系统只读考勤结果
 * @Project : SSPU-all-in-one
 * @File : sports_attendance.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'campus_network_status.dart';

/// 体育部课外活动考勤分类。
enum SportsAttendanceCategory {
  /// 早操考勤。
  morningExercise('早操'),

  /// 课外活动考勤。
  extracurricularActivity('课外活动'),

  /// 次数调整。
  countAdjustment('次数调整'),

  /// 体育长廊。
  sportsCorridor('体育长廊'),

  /// 暂未识别的记录类型。
  unknown('其它');

  const SportsAttendanceCategory(this.label);

  /// 页面展示名称。
  final String label;
}

/// 体育部考勤查询状态。
enum SportsAttendanceQueryStatus {
  /// 查询成功。
  success,

  /// 未保存学工号。
  missingStudentId,

  /// 未保存体育部查询密码。
  missingSportsPassword,

  /// 校园网 / VPN 前置检测不可达。
  campusNetworkUnavailable,

  /// 登录页无法识别。
  loginPageUnavailable,

  /// 体育部账号或密码未通过校验。
  credentialsRejected,

  /// 登录后仍无法访问考勤页面。
  sessionUnavailable,

  /// 页面结构无法解析出考勤数据。
  parseFailed,

  /// 网络请求失败或超时。
  networkError,

  /// 未归类异常。
  unexpectedError,
}

/// 单条体育部课外活动考勤记录。
class SportsAttendanceRecord {
  const SportsAttendanceRecord({
    required this.category,
    required this.count,
    required this.cells,
    this.occurredAt,
    this.project,
    this.location,
    this.remark,
  });

  /// 记录类型。
  final SportsAttendanceCategory category;

  /// 该记录折算次数，无法识别时按 1 次保守计算。
  final int count;

  /// 原始表格单元格文本，供二级页面兜底展示。
  final List<String> cells;

  /// 考勤发生时间或日期。
  final String? occurredAt;

  /// 项目或活动名称。
  final String? project;

  /// 考勤地点。
  final String? location;

  /// 备注或状态。
  final String? remark;
}

/// 体育部课外活动考勤汇总。
class SportsAttendanceSummary {
  const SportsAttendanceSummary({
    required this.morningExerciseCount,
    required this.extracurricularActivityCount,
    required this.countAdjustmentCount,
    required this.sportsCorridorCount,
    required this.records,
    required this.fetchedAt,
    required this.sourceUri,
  });

  /// 早操次数。
  final int morningExerciseCount;

  /// 课外活动次数。
  final int extracurricularActivityCount;

  /// 次数调整。
  final int countAdjustmentCount;

  /// 体育长廊次数。
  final int sportsCorridorCount;

  /// 明细记录。
  final List<SportsAttendanceRecord> records;

  /// 查询时间。
  final DateTime fetchedAt;

  /// 明细页来源地址。
  final Uri sourceUri;

  /// issue #112 要求展示的总次数。
  int get totalCount {
    return morningExerciseCount +
        extracurricularActivityCount +
        countAdjustmentCount +
        sportsCorridorCount;
  }

  /// 按分类返回次数。
  int countOf(SportsAttendanceCategory category) {
    return switch (category) {
      SportsAttendanceCategory.morningExercise => morningExerciseCount,
      SportsAttendanceCategory.extracurricularActivity =>
        extracurricularActivityCount,
      SportsAttendanceCategory.countAdjustment => countAdjustmentCount,
      SportsAttendanceCategory.sportsCorridor => sportsCorridorCount,
      SportsAttendanceCategory.unknown => 0,
    };
  }
}

/// 体育部课外活动考勤查询结果。
class SportsAttendanceQueryResult {
  const SportsAttendanceQueryResult({
    required this.status,
    required this.message,
    required this.detail,
    required this.checkedAt,
    required this.entranceUri,
    this.finalUri,
    this.campusNetworkStatus,
    this.summary,
  });

  /// 结构化状态。
  final SportsAttendanceQueryStatus status;

  /// 面向用户的简短说明，不包含密码或 Cookie。
  final String message;

  /// 面向排查的安全详情，不包含密码或 Cookie。
  final String detail;

  /// 查询完成时间。
  final DateTime checkedAt;

  /// 体育部查询入口。
  final Uri entranceUri;

  /// 当前流程最终地址。
  final Uri? finalUri;

  /// 校园网 / VPN 前置检测结果。
  final CampusNetworkStatus? campusNetworkStatus;

  /// 成功时返回考勤汇总。
  final SportsAttendanceSummary? summary;

  /// 是否查询成功。
  bool get isSuccess => status == SportsAttendanceQueryStatus.success;
}
