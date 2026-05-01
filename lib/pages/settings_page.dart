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
import '../services/message_state_service.dart';
import '../services/password_service.dart';
import '../services/sports_attendance_service.dart';
import '../services/storage_service.dart';
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

class _SettingsPageState extends State<SettingsPage> {
  /// 是否已设置密码保护。
  bool _isPasswordEnabled = false;

  /// 是否已启用系统快速验证。
  bool _isQuickAuthEnabled = false;

  /// 当前平台/设备是否支持系统快速验证。
  bool _isQuickAuthAvailable = false;

  /// 是否正在处理系统快速验证开关。
  bool _isQuickAuthBusy = false;

  /// 是否正在加载设置。
  bool _isLoading = true;

  /// 关闭按钮行为偏好（ask / minimize / exit）。
  String _closeBehavior = 'ask';

  /// 消息推送总开关。
  bool _notificationEnabled = true;

  /// 勿扰模式开关。
  bool _dndEnabled = false;

  /// 勿扰开始时间。
  int _dndStartHour = 22;
  int _dndStartMinute = 0;

  /// 勿扰结束时间。
  int _dndEndHour = 7;
  int _dndEndMinute = 0;

  /// 校园网 / VPN 状态自动检测间隔，单位分钟。
  int _campusNetworkDetectionIntervalMinutes =
      CampusNetworkStatusService.defaultDetectionIntervalMinutes;

  /// 体育部课外活动考勤自动刷新开关。
  bool _sportsAttendanceAutoRefreshEnabled = false;

  /// 体育部课外活动考勤自动刷新间隔，单位分钟。
  int _sportsAttendanceAutoRefreshIntervalMinutes =
      SportsAttendanceService.defaultAutoRefreshIntervalMinutes;

  /// 校园卡余额自动刷新开关。
  bool _campusCardAutoRefreshEnabled = false;

  /// 校园卡余额自动刷新间隔，单位分钟。
  int _campusCardAutoRefreshIntervalMinutes =
      CampusCardService.defaultAutoRefreshIntervalMinutes;

  /// 当前选中的设置分区索引。
  /// 0=常规设置 1=自动刷新设置 2=安全设置 3=职能部门 4=教学单位 5=微信推文
  int _selectedTab = 0;

  /// 消息状态服务引用。
  final MessageStateService _messageState = MessageStateService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载页面级设置状态。
  Future<void> _loadSettings() async {
    final isSet = await PasswordService.isPasswordSet();
    final quickAuthEnabled = await PasswordService.isQuickAuthEnabled();
    final quickAuthAvailable = await SystemAuthService.instance.isAvailable();
    final behavior = await StorageService.getCloseBehavior();
    await _messageState.init();

    final notifEnabled = await _messageState.isNotificationEnabled();
    final dndOn = await _messageState.isDndEnabled();
    final dndStartHour = await _messageState.getDndStartHour();
    final dndStartMinute = await _messageState.getDndStartMinute();
    final dndEndHour = await _messageState.getDndEndHour();
    final dndEndMinute = await _messageState.getDndEndMinute();
    final campusNetworkDetectionInterval = await CampusNetworkStatusService
        .instance
        .getDetectionIntervalMinutes();
    final sportsAttendanceAutoRefreshEnabled = await SportsAttendanceService
        .instance
        .isAutoRefreshEnabled();
    final sportsAttendanceAutoRefreshInterval = await SportsAttendanceService
        .instance
        .getAutoRefreshIntervalMinutes();
    final campusCardAutoRefreshEnabled = await CampusCardService.instance
        .isAutoRefreshEnabled();
    final campusCardAutoRefreshInterval = await CampusCardService.instance
        .getAutoRefreshIntervalMinutes();

    if (!mounted) return;
    setState(() {
      _isPasswordEnabled = isSet;
      _isQuickAuthEnabled = isSet && quickAuthAvailable && quickAuthEnabled;
      _isQuickAuthAvailable = quickAuthAvailable;
      _closeBehavior = behavior;
      _notificationEnabled = notifEnabled;
      _dndEnabled = dndOn;
      _dndStartHour = dndStartHour;
      _dndStartMinute = dndStartMinute;
      _dndEndHour = dndEndHour;
      _dndEndMinute = dndEndMinute;
      _campusNetworkDetectionIntervalMinutes = campusNetworkDetectionInterval;
      _sportsAttendanceAutoRefreshEnabled = sportsAttendanceAutoRefreshEnabled;
      _sportsAttendanceAutoRefreshIntervalMinutes =
          sportsAttendanceAutoRefreshInterval;
      _campusCardAutoRefreshEnabled = campusCardAutoRefreshEnabled;
      _campusCardAutoRefreshIntervalMinutes = campusCardAutoRefreshInterval;
      _isLoading = false;
    });
  }

  /// 显示操作成功提示。
  void _showSuccessBar(String message) {
    displayInfoBar(
      context,
      builder: (ctx, close) =>
          InfoBar(title: Text(message), severity: InfoBarSeverity.success),
    );
  }

  /// 显示操作失败提示。
  void _showErrorBar(String message) {
    displayInfoBar(
      context,
      builder: (ctx, close) =>
          InfoBar(title: Text(message), severity: InfoBarSeverity.error),
    );
  }

  /// 修改关闭按钮行为。
  Future<void> _onCloseBehaviorChanged(String behavior) async {
    await StorageService.setCloseBehavior(behavior);
    if (!mounted) return;
    setState(() => _closeBehavior = behavior);
  }

  /// 修改消息推送总开关。
  Future<void> _onNotificationChanged(bool enabled) async {
    await _messageState.setNotificationEnabled(enabled);
    if (!mounted) return;
    setState(() => _notificationEnabled = enabled);
  }

  /// 修改勿扰模式开关。
  Future<void> _onDndChanged(bool enabled) async {
    await _messageState.setDndEnabled(enabled);
    if (!mounted) return;
    setState(() => _dndEnabled = enabled);
  }

  /// 修改勿扰开始时间。
  Future<void> _onDndStartChanged(int hour, int minute) async {
    await _messageState.setDndTime(
      startHour: hour,
      startMinute: minute,
      endHour: _dndEndHour,
      endMinute: _dndEndMinute,
    );
    if (!mounted) return;
    setState(() {
      _dndStartHour = hour;
      _dndStartMinute = minute;
    });
  }

  /// 修改勿扰结束时间。
  Future<void> _onDndEndChanged(int hour, int minute) async {
    await _messageState.setDndTime(
      startHour: _dndStartHour,
      startMinute: _dndStartMinute,
      endHour: hour,
      endMinute: minute,
    );
    if (!mounted) return;
    setState(() {
      _dndEndHour = hour;
      _dndEndMinute = minute;
    });
  }

  /// 修改校园网 / VPN 状态检测间隔。
  Future<void> _onCampusNetworkDetectionIntervalChanged(int minutes) async {
    await CampusNetworkStatusService.instance.setDetectionIntervalMinutes(
      minutes,
    );
    if (!mounted) return;
    setState(() => _campusNetworkDetectionIntervalMinutes = minutes);
  }

  /// 修改体育部课外活动考勤自动刷新开关。
  Future<void> _onSportsAttendanceAutoRefreshChanged(bool enabled) async {
    await SportsAttendanceService.instance.setAutoRefreshEnabled(enabled);
    if (!mounted) return;
    setState(() => _sportsAttendanceAutoRefreshEnabled = enabled);
  }

  /// 修改体育部课外活动考勤自动刷新间隔。
  Future<void> _onSportsAttendanceAutoRefreshIntervalChanged(
    int minutes,
  ) async {
    await SportsAttendanceService.instance.setAutoRefreshIntervalMinutes(
      minutes,
    );
    if (!mounted) return;
    setState(() => _sportsAttendanceAutoRefreshIntervalMinutes = minutes);
  }

  /// 修改校园卡余额自动刷新开关。
  Future<void> _onCampusCardAutoRefreshChanged(bool enabled) async {
    await CampusCardService.instance.setAutoRefreshEnabled(enabled);
    if (!mounted) return;
    setState(() => _campusCardAutoRefreshEnabled = enabled);
  }

  /// 修改校园卡余额自动刷新间隔。
  Future<void> _onCampusCardAutoRefreshIntervalChanged(int minutes) async {
    await CampusCardService.instance.setAutoRefreshIntervalMinutes(minutes);
    if (!mounted) return;
    setState(() => _campusCardAutoRefreshIntervalMinutes = minutes);
  }

  /// 切换密码保护。
  Future<void> _onPasswordProtectionChanged(bool enabled) async {
    if (enabled) {
      final ok = await showSetPasswordDialog(context);
      if (ok && mounted) {
        setState(() {
          _isPasswordEnabled = true;
          _isQuickAuthEnabled = false;
        });
        _showSuccessBar('密码已设置');
      }
      return;
    }

    final ok = await showRemovePasswordDialog(context);
    if (ok && mounted) {
      setState(() {
        _isPasswordEnabled = false;
        _isQuickAuthEnabled = false;
      });
      _showSuccessBar('密码保护已移除');
    }
  }

  /// 修改密码。
  Future<void> _onChangePassword() async {
    final ok = await showChangePasswordDialog(context);
    if (ok && mounted) {
      setState(() => _isQuickAuthEnabled = false);
      _showSuccessBar('密码已修改');
    }
  }

  /// 修改系统快速验证开关。
  Future<void> _onQuickAuthChanged(bool enabled) async {
    if (!_isPasswordEnabled || _isQuickAuthBusy) return;

    if (!enabled) {
      await PasswordService.setQuickAuthEnabled(false);
      if (!mounted) return;
      setState(() => _isQuickAuthEnabled = false);
      _showSuccessBar('系统快速验证已关闭');
      return;
    }

    if (!_isQuickAuthAvailable) {
      _showErrorBar('当前平台或设备不支持系统快速验证');
      return;
    }

    final passwordConfirmed = await showConfirmCurrentPasswordDialog(
      context,
      title: '启用系统快速验证',
      message: '请输入当前密码。通过后将调用系统认证完成启用确认。',
      confirmLabel: '继续',
    );
    if (!passwordConfirmed || !mounted) return;

    setState(() => _isQuickAuthBusy = true);
    final authResult = await SystemAuthService.instance.authenticate(
      localizedReason: '验证身份以启用 SSPU All-in-One 系统快速解锁',
    );
    if (!mounted) return;

    if (authResult == SystemAuthResult.success) {
      await PasswordService.setQuickAuthEnabled(true);
      if (!mounted) return;
      setState(() {
        _isQuickAuthEnabled = true;
        _isQuickAuthBusy = false;
      });
      _showSuccessBar('系统快速验证已启用');
      return;
    }

    await PasswordService.setQuickAuthEnabled(false);
    if (!mounted) return;
    setState(() {
      _isQuickAuthEnabled = false;
      _isQuickAuthBusy = false;
    });
    _showErrorBar('系统认证未完成，已保留手动密码解锁');
  }

  /// 清理信息中心缓存。
  Future<void> _showClearMessageCacheDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('清理信息中心缓存'),
        content: const Text(
          '此操作将清除信息中心缓存的所有消息（包括官网消息和微信公众号文章）。\n\n'
          '登录信息、设置和关注列表不受影响。\n'
          '是否继续？',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.remove(MessageChannelKeys.persistedMessages);
      await StorageService.remove(MessageChannelKeys.readMessageIds);
      if (!mounted) return;
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('信息中心缓存已清理'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  /// 清除所有本地数据并退出。
  Future<void> _showClearAllDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认清除所有数据'),
        content: const Text(
          '此操作将清除所有本地数据（包括登录信息、设置等），应用将退出。\n'
          '是否继续？',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认清除并退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AcademicCredentialsService.instance.clearAll();
        await StorageService.clearAll();
        await AppExitService.instance.exit();
      } catch (_) {
        if (!mounted) return;
        _showErrorBar('清除失败，请确认系统安全存储可用');
      }
    }
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

  /// 宽屏布局。
  Widget _buildWideSettingsLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Padding(
            padding: const EdgeInsets.only(
              left: FluentSpacing.l,
              top: FluentSpacing.s,
            ),
            child: _buildSettingsNavigation(context),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: FluentSpacing.s),
          child: Divider(direction: Axis.vertical),
        ),
        Expanded(
          child: _buildScrollableContent(
            responsivePagePadding(
              DeviceType.desktop,
              vertical: FluentSpacing.s,
            ),
          ),
        ),
      ],
    );
  }

  /// 窄屏布局。
  Widget _buildNarrowSettingsLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FluentSpacing.l,
            0,
            FluentSpacing.l,
            FluentSpacing.s,
          ),
          child: _buildSettingsTabCombo(context),
        ),
        const Divider(),
        Expanded(
          child: _buildScrollableContent(
            responsivePagePadding(DeviceType.phone, vertical: FluentSpacing.s),
          ),
        ),
      ],
    );
  }

  /// 左侧导航。
  Widget _buildSettingsNavigation(BuildContext context) {
    final theme = FluentTheme.of(context);
    final captionStyle = theme.typography.caption?.copyWith(
      color: theme.resources.textFillColorSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text('系统设置', style: captionStyle),
        ),
        buildSettingsNavItem(
          context: context,
          index: 0,
          selectedIndex: _selectedTab,
          icon: FluentIcons.settings,
          label: '常规设置',
          onTap: () => setState(() => _selectedTab = 0),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 1,
          selectedIndex: _selectedTab,
          icon: FluentIcons.sync,
          label: '自动刷新设置',
          onTap: () => setState(() => _selectedTab = 1),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 2,
          selectedIndex: _selectedTab,
          icon: FluentIcons.lock,
          label: '安全设置',
          onTap: () => setState(() => _selectedTab = 2),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text('消息推送设置', style: captionStyle),
        ),
        buildSettingsNavItem(
          context: context,
          index: 3,
          selectedIndex: _selectedTab,
          icon: FluentIcons.education,
          label: '职能部门',
          onTap: () => setState(() => _selectedTab = 3),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 4,
          selectedIndex: _selectedTab,
          icon: FluentIcons.library,
          label: '教学单位',
          onTap: () => setState(() => _selectedTab = 4),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 5,
          selectedIndex: _selectedTab,
          icon: FluentIcons.chat,
          label: '微信推文',
          onTap: () => setState(() => _selectedTab = 5),
        ),
      ],
    );
  }

  /// 窄屏顶部下拉。
  Widget _buildSettingsTabCombo(BuildContext context) {
    return Row(
      children: [
        const Icon(FluentIcons.global_nav_button, size: 16),
        const SizedBox(width: FluentSpacing.s),
        Expanded(
          child: ComboBox<int>(
            key: const Key('settings-narrow-tab-combo'),
            value: _selectedTab,
            isExpanded: true,
            items: const [
              ComboBoxItem(value: 0, child: Text('常规设置')),
              ComboBoxItem(value: 1, child: Text('自动刷新设置')),
              ComboBoxItem(value: 2, child: Text('安全设置')),
              ComboBoxItem(value: 3, child: Text('职能部门')),
              ComboBoxItem(value: 4, child: Text('教学单位')),
              ComboBoxItem(value: 5, child: Text('微信推文')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedTab = value);
            },
          ),
        ),
      ],
    );
  }

  /// 带动画的滚动内容区。
  Widget _buildScrollableContent(EdgeInsets padding) {
    return SingleChildScrollView(
      padding: padding,
      child: _buildContentPanel(context)
          .animate(key: ValueKey(_selectedTab))
          .fadeIn(duration: FluentDuration.slow, curve: FluentEasing.decelerate)
          .slideY(begin: 0.02, end: 0),
    );
  }

  /// 根据分区索引切换内容。
  Widget _buildContentPanel(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return SettingsGeneralSection(
          closeBehavior: _closeBehavior,
          notificationEnabled: _notificationEnabled,
          dndEnabled: _dndEnabled,
          dndStartHour: _dndStartHour,
          dndStartMinute: _dndStartMinute,
          dndEndHour: _dndEndHour,
          dndEndMinute: _dndEndMinute,
          onCloseBehaviorChanged: (value) => _onCloseBehaviorChanged(value),
          onNotificationChanged: (value) => _onNotificationChanged(value),
          onDndChanged: (value) => _onDndChanged(value),
          onDndStartChanged: _onDndStartChanged,
          onDndEndChanged: _onDndEndChanged,
        );
      case 1:
        return SettingsAutoRefreshSection(
          campusNetworkDetectionIntervalMinutes:
              _campusNetworkDetectionIntervalMinutes,
          onCampusNetworkDetectionIntervalChanged:
              _onCampusNetworkDetectionIntervalChanged,
          sportsAttendanceAutoRefreshEnabled:
              _sportsAttendanceAutoRefreshEnabled,
          sportsAttendanceAutoRefreshIntervalMinutes:
              _sportsAttendanceAutoRefreshIntervalMinutes,
          onSportsAttendanceAutoRefreshChanged:
              _onSportsAttendanceAutoRefreshChanged,
          onSportsAttendanceAutoRefreshIntervalChanged:
              _onSportsAttendanceAutoRefreshIntervalChanged,
          campusCardAutoRefreshEnabled: _campusCardAutoRefreshEnabled,
          campusCardAutoRefreshIntervalMinutes:
              _campusCardAutoRefreshIntervalMinutes,
          onCampusCardAutoRefreshChanged: _onCampusCardAutoRefreshChanged,
          onCampusCardAutoRefreshIntervalChanged:
              _onCampusCardAutoRefreshIntervalChanged,
          onOpenDepartmentRefreshSettings: () =>
              setState(() => _selectedTab = 3),
          onOpenTeachingRefreshSettings: () => setState(() => _selectedTab = 4),
          onOpenWechatRefreshSettings: () => setState(() => _selectedTab = 5),
        );
      case 2:
        return SettingsSecuritySection(
          isPasswordEnabled: _isPasswordEnabled,
          onPasswordProtectionChanged: (value) =>
              _onPasswordProtectionChanged(value),
          onChangePassword: _onChangePassword,
          isQuickAuthEnabled: _isQuickAuthEnabled,
          isQuickAuthAvailable: _isQuickAuthAvailable,
          isQuickAuthBusy: _isQuickAuthBusy,
          onQuickAuthChanged: (value) => _onQuickAuthChanged(value),
          onLock: widget.onLock,
          onClearMessageCache: _showClearMessageCacheDialog,
          onClearAllData: _showClearAllDataDialog,
        );
      case 3:
        return ChannelListSection(
          key: const ValueKey('department'),
          title: '职能部门',
          channels: departmentChannels,
        );
      case 4:
        return ChannelListSection(
          key: const ValueKey('teaching'),
          title: '教学单位',
          channels: teachingChannels,
        );
      case 5:
        return const SettingsWechatSection();
      default:
        return const SizedBox.shrink();
    }
  }
}
