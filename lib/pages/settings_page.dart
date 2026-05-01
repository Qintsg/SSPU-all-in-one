/*
 * 设置页 — 页面级状态与分区切换入口
 * @Project : SSPU-all-in-one
 * @File : settings_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

// ignore_for_file: use_build_context_synchronously

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/channel_config.dart';
import '../services/app_exit_service.dart';
import '../services/academic_credentials_service.dart';
import '../services/campus_card_service.dart';
import '../services/campus_network_status_service.dart';
import '../services/email_service.dart';
import '../services/message_state_service.dart';
import '../services/password_service.dart';
import '../services/sports_attendance_service.dart';
import '../services/storage_service.dart';
import '../services/student_report_service.dart';
import '../services/system_auth_service.dart';
import '../theme/fluent_tokens.dart';
import '../widgets/channel_list_section.dart';
import '../widgets/password_dialogs.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/settings_auto_refresh_section.dart';
import '../widgets/settings_general_section.dart';
import '../widgets/settings_security_section.dart';
import '../widgets/settings_wechat_section.dart';
import '../widgets/settings_widgets.dart';

part 'settings_page_actions.dart';
part 'settings_page_layout.dart';

/// 设置页面。
/// 页面本身只负责分区切换、常规/安全状态与顶部布局；
/// 微信推文等复杂模块交由独立组件维护，降低入口文件耦合度。
class SettingsPage extends StatefulWidget {
  /// 手动上锁回调。
  final VoidCallback? onLock;

  const SettingsPage({super.key, this.onLock});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with _SettingsPageActions, _SettingsPageLayout {
  /// 是否已设置密码保护。
  @override
  bool _isPasswordEnabled = false;

  /// 是否已启用系统快速验证。
  @override
  bool _isQuickAuthEnabled = false;

  /// 当前平台/设备是否支持系统快速验证。
  @override
  bool _isQuickAuthAvailable = false;

  /// 是否正在处理系统快速验证开关。
  @override
  bool _isQuickAuthBusy = false;

  /// 是否正在加载设置。
  @override
  bool _isLoading = true;

  /// 关闭按钮行为偏好（ask / minimize / exit）。
  @override
  String _closeBehavior = 'ask';

  /// 消息推送总开关。
  @override
  bool _notificationEnabled = true;

  /// 勿扰模式开关。
  @override
  bool _dndEnabled = false;

  /// 勿扰开始时间。
  @override
  int _dndStartHour = 22;
  @override
  int _dndStartMinute = 0;

  /// 勿扰结束时间。
  @override
  int _dndEndHour = 7;
  @override
  int _dndEndMinute = 0;

  /// 校园网 / VPN 状态自动检测间隔，单位分钟。
  @override
  int _campusNetworkDetectionIntervalMinutes =
      CampusNetworkStatusService.defaultDetectionIntervalMinutes;

  /// 体育部课外活动考勤自动刷新开关。
  @override
  bool _sportsAttendanceAutoRefreshEnabled = false;

  /// 体育部课外活动考勤自动刷新间隔，单位分钟。
  @override
  int _sportsAttendanceAutoRefreshIntervalMinutes =
      SportsAttendanceService.defaultAutoRefreshIntervalMinutes;

  /// 校园卡余额自动刷新开关。
  @override
  bool _campusCardAutoRefreshEnabled = false;

  /// 校园卡余额自动刷新间隔，单位分钟。
  @override
  int _campusCardAutoRefreshIntervalMinutes =
      CampusCardService.defaultAutoRefreshIntervalMinutes;

  /// 学校邮箱自动刷新开关。
  @override
  bool _emailAutoRefreshEnabled = false;

  /// 学校邮箱自动刷新间隔，单位分钟。
  @override
  int _emailAutoRefreshIntervalMinutes =
      EmailService.defaultAutoRefreshIntervalMinutes;

  /// 第二课堂学分自动刷新开关。
  @override
  bool _studentReportAutoRefreshEnabled = false;

  /// 第二课堂学分自动刷新间隔，单位分钟。
  @override
  int _studentReportAutoRefreshIntervalMinutes =
      StudentReportService.defaultAutoRefreshIntervalMinutes;

  /// 当前选中的设置分区索引。
  /// 0=常规设置 1=自动刷新设置 2=安全设置 3=职能部门 4=教学单位 5=微信推文
  @override
  int _selectedTab = 0;

  /// 消息状态服务引用。
  @override
  final MessageStateService _messageState = MessageStateService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    return ScaffoldPage(
      header: const PageHeader(title: Text('设置')),
      content: ResponsiveBuilder(
        builder: (context, deviceType, constraints) {
          return deviceType == DeviceType.phone
              ? _buildNarrowSettingsLayout(context)
              : _buildWideSettingsLayout(context);
        },
      ),
    );
  }
}
