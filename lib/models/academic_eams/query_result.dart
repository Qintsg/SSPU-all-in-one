/*
 * 本专科教务系统查询结果模型
 * @Project : SSPU-all-in-one
 * @File : query_result.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import '../campus_network_status.dart';
import 'course_offerings.dart';
import 'free_classrooms.dart';
import 'query_status.dart';
import 'snapshot.dart';

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
