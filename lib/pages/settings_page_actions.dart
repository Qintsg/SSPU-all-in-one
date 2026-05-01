/*
 * 设置页操作逻辑 — 加载设置、保存偏好与执行安全动作
 * @Project : SSPU-all-in-one
 * @File : settings_page_actions.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'settings_page.dart';

mixin _SettingsPageActions on State<SettingsPage> {
  bool get _isPasswordEnabled;
  set _isPasswordEnabled(bool value);

  bool get _isQuickAuthEnabled;
  set _isQuickAuthEnabled(bool value);

  bool get _isQuickAuthAvailable;
  set _isQuickAuthAvailable(bool value);

  bool get _isQuickAuthBusy;
  set _isQuickAuthBusy(bool value);

  set _isLoading(bool value);

  String get _closeBehavior;
  set _closeBehavior(String value);

  bool get _notificationEnabled;
  set _notificationEnabled(bool value);

  bool get _dndEnabled;
  set _dndEnabled(bool value);

  int get _dndStartHour;
  set _dndStartHour(int value);

  int get _dndStartMinute;
  set _dndStartMinute(int value);

  int get _dndEndHour;
  set _dndEndHour(int value);

  int get _dndEndMinute;
  set _dndEndMinute(int value);

  int get _campusNetworkDetectionIntervalMinutes;
  set _campusNetworkDetectionIntervalMinutes(int value);

  bool get _sportsAttendanceAutoRefreshEnabled;
  set _sportsAttendanceAutoRefreshEnabled(bool value);

  int get _sportsAttendanceAutoRefreshIntervalMinutes;
  set _sportsAttendanceAutoRefreshIntervalMinutes(int value);

  bool get _campusCardAutoRefreshEnabled;
  set _campusCardAutoRefreshEnabled(bool value);

  int get _campusCardAutoRefreshIntervalMinutes;
  set _campusCardAutoRefreshIntervalMinutes(int value);

  bool get _emailAutoRefreshEnabled;
  set _emailAutoRefreshEnabled(bool value);

  int get _emailAutoRefreshIntervalMinutes;
  set _emailAutoRefreshIntervalMinutes(int value);

  bool get _studentReportAutoRefreshEnabled;
  set _studentReportAutoRefreshEnabled(bool value);

  int get _studentReportAutoRefreshIntervalMinutes;
  set _studentReportAutoRefreshIntervalMinutes(int value);

  MessageStateService get _messageState;

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
    final emailAutoRefreshEnabled = await EmailService.instance
        .isAutoRefreshEnabled();
    final emailAutoRefreshInterval = await EmailService.instance
        .getAutoRefreshIntervalMinutes();
    final studentReportAutoRefreshEnabled = await StudentReportService.instance
        .isAutoRefreshEnabled();
    final studentReportAutoRefreshInterval = await StudentReportService.instance
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
      _emailAutoRefreshEnabled = emailAutoRefreshEnabled;
      _emailAutoRefreshIntervalMinutes = emailAutoRefreshInterval;
      _studentReportAutoRefreshEnabled = studentReportAutoRefreshEnabled;
      _studentReportAutoRefreshIntervalMinutes =
          studentReportAutoRefreshInterval;
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

  /// 修改学校邮箱自动刷新开关。
  Future<void> _onEmailAutoRefreshChanged(bool enabled) async {
    await EmailService.instance.setAutoRefreshEnabled(enabled);
    if (!mounted) return;
    setState(() => _emailAutoRefreshEnabled = enabled);
  }

  /// 修改学校邮箱自动刷新间隔。
  Future<void> _onEmailAutoRefreshIntervalChanged(int minutes) async {
    await EmailService.instance.setAutoRefreshIntervalMinutes(minutes);
    if (!mounted) return;
    setState(() => _emailAutoRefreshIntervalMinutes = minutes);
  }

  /// 修改第二课堂学分自动刷新开关。
  Future<void> _onStudentReportAutoRefreshChanged(bool enabled) async {
    await StudentReportService.instance.setAutoRefreshEnabled(enabled);
    if (!mounted) return;
    setState(() => _studentReportAutoRefreshEnabled = enabled);
  }

  /// 修改第二课堂学分自动刷新间隔。
  Future<void> _onStudentReportAutoRefreshIntervalChanged(int minutes) async {
    await StudentReportService.instance.setAutoRefreshIntervalMinutes(minutes);
    if (!mounted) return;
    setState(() => _studentReportAutoRefreshIntervalMinutes = minutes);
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
}
