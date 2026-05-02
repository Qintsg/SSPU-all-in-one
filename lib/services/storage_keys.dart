/*
 * 统一数据存储键 — 管理所有持久化键名
 * @Project : SSPU-all-in-one
 * @File : storage_keys.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'storage_service.dart';

/// 存储键名常量。
/// 新增存储项时在此添加键名，保持集中管理。
class StorageKeys {
  StorageKeys._();

  /// 密码哈希。
  static const String passwordHash = 'app_password_hash';

  /// 系统快速验证开关，仅表示用户是否允许使用本机系统认证解锁应用。
  static const String quickAuthEnabled = 'app_quick_auth_enabled';

  /// EULA 接受状态。
  static const String eulaAccepted = 'eula_accepted';

  /// 关闭行为偏好（ask / minimize / exit）。
  static const String closeBehavior = 'close_behavior';

  /// 校园网 / VPN 状态检测间隔（分钟，0 = 关闭自动检测）。
  static const String campusNetworkDetectionIntervalMinutes =
      'campus_network_detection_interval_minutes';

  /// 体育部课外活动考勤自动刷新开关。
  static const String sportsAttendanceAutoRefreshEnabled =
      'sports_attendance_auto_refresh_enabled';

  /// 体育部课外活动考勤自动刷新间隔（分钟）。
  static const String sportsAttendanceAutoRefreshIntervalMinutes =
      'sports_attendance_auto_refresh_interval_minutes';

  /// 校园卡余额自动刷新开关。
  static const String campusCardAutoRefreshEnabled =
      'campus_card_auto_refresh_enabled';

  /// 校园卡余额自动刷新间隔（分钟）。
  static const String campusCardAutoRefreshIntervalMinutes =
      'campus_card_auto_refresh_interval_minutes';

  /// 学校邮箱自动刷新开关。
  static const String emailAutoRefreshEnabled = 'email_auto_refresh_enabled';

  /// 学校邮箱自动刷新间隔（分钟）。
  static const String emailAutoRefreshIntervalMinutes =
      'email_auto_refresh_interval_minutes';

  /// 第二课堂学分自动刷新开关。
  static const String studentReportAutoRefreshEnabled =
      'student_report_auto_refresh_enabled';

  /// 第二课堂学分自动刷新间隔（分钟）。
  static const String studentReportAutoRefreshIntervalMinutes =
      'student_report_auto_refresh_interval_minutes';

  /// 本专科教务只读能力自动刷新开关。
  static const String academicEamsAutoRefreshEnabled =
      'academic_eams_auto_refresh_enabled';

  /// 本专科教务只读能力自动刷新间隔（分钟）。
  static const String academicEamsAutoRefreshIntervalMinutes =
      'academic_eams_auto_refresh_interval_minutes';

  /// 结构化数据前缀（JSON 序列化存储）。
  static const String dataPrefix = 'data_';
}
