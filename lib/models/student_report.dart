/*
 * 学工报表模型 — 描述第二课堂学分只读查询结果
 * @Project : SSPU-all-in-one
 * @File : student_report.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'campus_network_status.dart';

/// 学工报表系统查询状态。
enum StudentReportQueryStatus {
  /// 查询或登录校验成功。
  success,

  /// 未保存学工号 / OA 账号。
  missingOaAccount,

  /// 未保存 OA 密码。
  missingOaPassword,

  /// 校园网 / VPN 前置检测不可达。
  campusNetworkUnavailable,

  /// OA/CAS 登录状态不可用，无法进入学工报表系统。
  oaLoginRequired,

  /// 学工报表系统页面不可用或仍停留本地登录页。
  reportSystemUnavailable,

  /// 未找到第二课堂学分查询入口。
  secondClassroomEntryUnavailable,

  /// 页面结构无法解析为第二课堂学分。
  parseFailed,

  /// 网络请求失败或超时。
  networkError,

  /// 未归类异常。
  unexpectedError,
}

/// 第二课堂学分明细记录。
class SecondClassroomCreditRecord {
  const SecondClassroomCreditRecord({
    required this.category,
    required this.itemName,
    required this.credit,
    required this.rawCells,
    this.occurredAt,
    this.status,
  });

  /// 学分类别或模块名称。
  final String category;

  /// 活动、项目或课程名称。
  final String itemName;

  /// 认定学分。
  final double credit;

  /// 发生或认定时间，保持页面原始格式。
  final String? occurredAt;

  /// 审核、认定或记录状态。
  final String? status;

  /// 原始表格单元格，页面变化时用于兜底展示。
  final List<String> rawCells;
}

/// 第二课堂学分统计快照。
class SecondClassroomCreditSummary {
  const SecondClassroomCreditSummary({
    required this.totalCredit,
    required this.creditsByCategory,
    required this.records,
    required this.fetchedAt,
    required this.sourceUri,
  });

  /// 明细记录累计总学分。
  final double totalCredit;

  /// 按类别聚合的学分。
  final Map<String, double> creditsByCategory;

  /// 第二课堂学分明细。
  final List<SecondClassroomCreditRecord> records;

  /// 本地解析完成时间。
  final DateTime fetchedAt;

  /// 产生该快照的最后一个业务页面地址。
  final Uri sourceUri;
}

/// 学工报表只读查询或登录校验结果。
class StudentReportQueryResult {
  const StudentReportQueryResult({
    required this.status,
    required this.message,
    required this.detail,
    required this.checkedAt,
    required this.entranceUri,
    this.finalUri,
    this.campusNetworkStatus,
    this.summary,
  });

  /// 结构化状态，用于 UI 判断展示级别。
  final StudentReportQueryStatus status;

  /// 面向用户的简短说明，不包含 Cookie、Ticket 等敏感值。
  final String message;

  /// 面向排查的安全详情，不包含凭据原文。
  final String detail;

  /// 本次查询完成时间。
  final DateTime checkedAt;

  /// 学工报表 OA 入口地址。
  final Uri entranceUri;

  /// 查询结束时的最终地址。
  final Uri? finalUri;

  /// 校园网 / VPN 前置检测结果。
  final CampusNetworkStatus? campusNetworkStatus;

  /// 成功读取时的第二课堂学分统计。
  final SecondClassroomCreditSummary? summary;

  /// 是否操作成功。
  bool get isSuccess => status == StudentReportQueryStatus.success;
}
