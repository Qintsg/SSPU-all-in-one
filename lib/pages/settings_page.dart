/*
 * 设置页 — 应用设置与密码保护管理
 * @Project : SSPU-all-in-one
 * @File : settings_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../services/password_service.dart';
import '../services/storage_service.dart';
import '../services/message_state_service.dart';
import '../services/auto_refresh_service.dart';

/// 设置页面
/// 包含密码保护开关、密码设置/修改/移除功能、手动上锁、窗口行为设置
class SettingsPage extends StatefulWidget {
  /// 手动上锁回调
  final VoidCallback? onLock;

  const SettingsPage({super.key, this.onLock});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 是否已设置密码保护
  bool _isPasswordEnabled = false;

  /// 是否正在加载状态
  bool _isLoading = true;

  /// 关闭按钮行为偏好（ask / minimize / exit）
  String _closeBehavior = 'ask';

  /// 信息渠道开关状态
  bool _latestInfoEnabled = true;
  bool _noticeEnabled = true;
  bool _wechatPublicEnabled = false;
  bool _wechatServiceEnabled = false;

  /// 各渠道自动刷新间隔（分钟，0 = 关闭）
  int _latestInfoInterval = 0;
  int _noticeInterval = 0;
  int _wechatPublicInterval = 0;
  int _wechatServiceInterval = 0;

  /// 消息推送全局开关
  bool _notificationEnabled = true;

  /// 勿扰模式开关
  bool _dndEnabled = false;

  /// 勿扰时间段
  int _dndStartHour = 22;
  int _dndStartMinute = 0;
  int _dndEndHour = 7;
  int _dndEndMinute = 0;

  /// 当前选中的设置分区索引（0=安全 1=窗口行为 2=信息渠道 3=消息推送）
  int _selectedTab = 0;

  /// 消息状态服务引用
  final MessageStateService _messageState = MessageStateService.instance;

  /// 自动刷新服务引用
  final AutoRefreshService _autoRefresh = AutoRefreshService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 可选的自动刷新间隔（分钟 => 显示文本）
  static const Map<int, String> _intervalOptions = {
    0: '关闭',
    15: '15 分钟',
    30: '30 分钟',
    60: '1 小时',
    120: '2 小时',
    360: '6 小时',
    720: '12 小时',
    1440: '24 小时',
  };

  /// 构建自动刷新间隔选择器
  /// [currentValue] 当前间隔（分钟）
  /// [enabled] 渠道是否启用（未启用时灰色不可点）
  /// [onChanged] 选中新值后回调
  Widget _buildIntervalSelector({
    required int currentValue,
    required bool enabled,
    required Future<void> Function(int minutes) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 6),
      child: Row(
        children: [
          Icon(
            FluentIcons.sync,
            size: 14,
            color: enabled
                ? FluentTheme.of(context).inactiveColor
                : FluentTheme.of(context)
                    .inactiveColor
                    .withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            '自动刷新：',
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: enabled
                      ? null
                      : FluentTheme.of(context)
                          .inactiveColor
                          .withValues(alpha: 0.4),
                ),
          ),
          const SizedBox(width: 4),
          ComboBox<int>(
            value: _intervalOptions.containsKey(currentValue)
                ? currentValue
                : 0,
            items: _intervalOptions.entries
                .map(
                  (entry) => ComboBoxItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// 从本地存储加载密码保护状态和窗口行为偏好
  Future<void> _loadSettings() async {
    final isSet = await PasswordService.isPasswordSet();
    final behavior = await StorageService.getCloseBehavior();
    // 加载信息渠道开关状态
    await _messageState.init();
    final latestInfo = await _messageState.isLatestInfoEnabled();
    final notice = await _messageState.isNoticeEnabled();
    final wechatPub = await _messageState.isWechatPublicEnabled();
    final wechatSvc = await _messageState.isWechatServiceEnabled();
    // 加载自动刷新间隔
    final liInterval = await _messageState.getLatestInfoInterval();
    final ntInterval = await _messageState.getNoticeInterval();
    final wpInterval = await _messageState.getWechatPublicInterval();
    final wsInterval = await _messageState.getWechatServiceInterval();
    // 加载消息推送与勿扰配置
    final notifEnabled = await _messageState.isNotificationEnabled();
    final dndOn = await _messageState.isDndEnabled();
    final dndSH = await _messageState.getDndStartHour();
    final dndSM = await _messageState.getDndStartMinute();
    final dndEH = await _messageState.getDndEndHour();
    final dndEM = await _messageState.getDndEndMinute();
    if (mounted) {
      setState(() {
        _isPasswordEnabled = isSet;
        _closeBehavior = behavior;
        _latestInfoEnabled = latestInfo;
        _noticeEnabled = notice;
        _wechatPublicEnabled = wechatPub;
        _wechatServiceEnabled = wechatSvc;
        _latestInfoInterval = liInterval;
        _noticeInterval = ntInterval;
        _wechatPublicInterval = wpInterval;
        _wechatServiceInterval = wsInterval;
        _notificationEnabled = notifEnabled;
        _dndEnabled = dndOn;
        _dndStartHour = dndSH;
        _dndStartMinute = dndSM;
        _dndEndHour = dndEH;
        _dndEndMinute = dndEM;
        _isLoading = false;
      });
    }
  }

  /// 显示设置密码对话框
  Future<void> _showSetPasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return ContentDialog(
              title: const Text('设置密码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('设置密码后，每次重新打开应用时需要输入密码才能进入。'),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: '输入密码',
                    child: PasswordBox(
                      controller: passwordController,
                      placeholder: '请输入密码',
                      revealMode: PasswordRevealMode.peekAlways,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: '确认密码',
                    child: PasswordBox(
                      controller: confirmController,
                      placeholder: '请再次输入密码',
                      revealMode: PasswordRevealMode.peekAlways,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(errorMessage!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                ],
              ),
              actions: [
                Button(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
                FilledButton(
                  child: const Text('确认'),
                  onPressed: () {
                    final password = passwordController.text;
                    final confirm = confirmController.text;
                    if (password.isEmpty) {
                      setDialogState(() => errorMessage = '密码不能为空');
                      return;
                    }
                    if (password != confirm) {
                      setDialogState(() => errorMessage = '两次输入的密码不一致');
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await PasswordService.setPassword(passwordController.text);
      if (mounted) {
        setState(() => _isPasswordEnabled = true);
        _showSuccessBar('密码已设置');
      }
    }

    passwordController.dispose();
    confirmController.dispose();
  }

  /// 显示移除密码的确认对话框
  Future<void> _showRemovePasswordDialog() async {
    final passwordController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return ContentDialog(
              title: const Text('移除密码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('请输入当前密码以确认移除密码保护。'),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: '当前密码',
                    child: PasswordBox(
                      controller: passwordController,
                      placeholder: '请输入当前密码',
                      revealMode: PasswordRevealMode.peekAlways,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(errorMessage!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                ],
              ),
              actions: [
                Button(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
                FilledButton(
                  child: const Text('确认移除'),
                  onPressed: () async {
                    final isCorrect = await PasswordService.verifyPassword(
                      passwordController.text,
                    );
                    if (isCorrect) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } else {
                      setDialogState(() => errorMessage = '密码错误');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await PasswordService.removePassword();
      if (mounted) {
        setState(() => _isPasswordEnabled = false);
        _showSuccessBar('密码保护已移除');
      }
    }

    passwordController.dispose();
  }

  /// 显示修改密码对话框
  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return ContentDialog(
              title: const Text('修改密码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoLabel(
                    label: '当前密码',
                    child: PasswordBox(
                      controller: oldPasswordController,
                      placeholder: '请输入当前密码',
                      revealMode: PasswordRevealMode.peekAlways,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: '新密码',
                    child: PasswordBox(
                      controller: newPasswordController,
                      placeholder: '请输入新密码',
                      revealMode: PasswordRevealMode.peekAlways,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: '确认新密码',
                    child: PasswordBox(
                      controller: confirmController,
                      placeholder: '请再次输入新密码',
                      revealMode: PasswordRevealMode.peekAlways,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(errorMessage!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                ],
              ),
              actions: [
                Button(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
                FilledButton(
                  child: const Text('确认修改'),
                  onPressed: () async {
                    final oldPassword = oldPasswordController.text;
                    final newPassword = newPasswordController.text;
                    final confirm = confirmController.text;

                    final isOldCorrect =
                        await PasswordService.verifyPassword(oldPassword);
                    if (!isOldCorrect) {
                      setDialogState(() => errorMessage = '当前密码错误');
                      return;
                    }
                    if (newPassword.isEmpty) {
                      setDialogState(() => errorMessage = '新密码不能为空');
                      return;
                    }
                    if (newPassword != confirm) {
                      setDialogState(() => errorMessage = '两次输入的新密码不一致');
                      return;
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await PasswordService.setPassword(newPasswordController.text);
      if (mounted) {
        _showSuccessBar('密码已修改');
      }
    }

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmController.dispose();
  }

  /// 显示操作成功的提示条
  void _showSuccessBar(String message) {
    displayInfoBar(
      context,
      builder: (infoBarContext, close) => InfoBar(
        title: Text(message),
        severity: InfoBarSeverity.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ScaffoldPage(
        content: Center(child: ProgressRing()),
      );
    }

    return ScaffoldPage(
      header: const PageHeader(title: Text('设置')),
      content: Column(
        children: [
          // 设置分区导航栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildNavTab(0, FluentIcons.lock, '安全'),
                const SizedBox(width: 8),
                _buildNavTab(1, FluentIcons.chrome_close, '窗口行为'),
                const SizedBox(width: 8),
                _buildNavTab(2, FluentIcons.news, '信息渠道'),
                const SizedBox(width: 8),
                _buildNavTab(3, FluentIcons.ringer, '消息推送'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 根据选中分区显示内容（可滚动）
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
        // 安全设置卡片
        if (_selectedTab == 0)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '安全',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 16),
                // 密码保护开关行
                Row(
                  children: [
                    const Icon(FluentIcons.lock, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '密码保护',
                            style:
                                FluentTheme.of(context).typography.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isPasswordEnabled
                                ? '已开启 — 重新打开应用时需要输入密码'
                                : '未开启 — 任何人可直接进入应用',
                            style: FluentTheme.of(context).typography.caption,
                          ),
                        ],
                      ),
                    ),
                    ToggleSwitch(
                      checked: _isPasswordEnabled,
                      onChanged: (value) {
                        if (value) {
                          _showSetPasswordDialog();
                        } else {
                          _showRemovePasswordDialog();
                        }
                      },
                    ),
                  ],
                ),
                // 修改密码 + 手动上锁（仅在已设置密码时显示）
                if (_isPasswordEnabled) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Button(
                        child: const Text('修改密码'),
                        onPressed: () => _showChangePasswordDialog(),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: widget.onLock,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.lock, size: 14),
                            SizedBox(width: 6),
                            Text('立即上锁'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // 窗口行为设置卡片
        if (_selectedTab == 1)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '窗口行为',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 16),
                // 关闭按钮行为下拉选择
                Row(
                  children: [
                    const Icon(FluentIcons.chrome_close, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '关闭按钮行为',
                            style:
                                FluentTheme.of(context).typography.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '选择点击窗口关闭按钮时的操作',
                            style: FluentTheme.of(context).typography.caption,
                          ),
                        ],
                      ),
                    ),
                    ComboBox<String>(
                      value: _closeBehavior,
                      items: const [
                        ComboBoxItem(
                          value: 'ask',
                          child: Text('每次询问'),
                        ),
                        ComboBoxItem(
                          value: 'minimize',
                          child: Text('最小化到托盘'),
                        ),
                        ComboBoxItem(
                          value: 'exit',
                          child: Text('直接退出'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          await StorageService.setCloseBehavior(value);
                          setState(() => _closeBehavior = value);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 信息渠道设置卡片
        if (_selectedTab == 2)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '信息渠道',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 16),
                // 最新公开信息 (3148)
                _buildChannelToggle(
                  icon: FluentIcons.news,
                  title: '最新公开信息',
                  subtitle: '信息公开网 — 学校新闻动态',
                  value: _latestInfoEnabled,
                  onChanged: (value) async {
                    await _messageState.setLatestInfoEnabled(value);
                    setState(() => _latestInfoEnabled = value);
                    _showChannelChangedTip(value, '最新公开信息');
                    // 渠道开关变化后重新加载自动刷新定时器
                    await _autoRefresh.reloadChannel('latestInfo');
                  },
                ),
                _buildIntervalSelector(
                  currentValue: _latestInfoInterval,
                  enabled: _latestInfoEnabled,
                  onChanged: (minutes) async {
                    await _messageState.setLatestInfoInterval(minutes);
                    setState(() => _latestInfoInterval = minutes);
                    await _autoRefresh.reloadChannel('latestInfo');
                  },
                ),
                const SizedBox(height: 12),
                // 通知公示 (3149)
                _buildChannelToggle(
                  icon: FluentIcons.megaphone,
                  title: '通知公示',
                  subtitle: '信息公开网 — 通知公告与公示',
                  value: _noticeEnabled,
                  onChanged: (value) async {
                    await _messageState.setNoticeEnabled(value);
                    setState(() => _noticeEnabled = value);
                    _showChannelChangedTip(value, '通知公示');
                    await _autoRefresh.reloadChannel('notice');
                  },
                ),
                _buildIntervalSelector(
                  currentValue: _noticeInterval,
                  enabled: _noticeEnabled,
                  onChanged: (minutes) async {
                    await _messageState.setNoticeInterval(minutes);
                    setState(() => _noticeInterval = minutes);
                    await _autoRefresh.reloadChannel('notice');
                  },
                ),
                const SizedBox(height: 12),
                // 微信公众号（占位）
                _buildChannelToggle(
                  icon: FluentIcons.chat,
                  title: '微信公众号',
                  subtitle: '暂未接入',
                  value: _wechatPublicEnabled,
                  onChanged: (value) async {
                    await _messageState.setWechatPublicEnabled(value);
                    setState(() => _wechatPublicEnabled = value);
                    _showChannelChangedTip(value, '微信公众号');
                  },
                ),
                _buildIntervalSelector(
                  currentValue: _wechatPublicInterval,
                  enabled: _wechatPublicEnabled,
                  onChanged: (minutes) async {
                    await _messageState.setWechatPublicInterval(minutes);
                    setState(() => _wechatPublicInterval = minutes);
                  },
                ),
                const SizedBox(height: 12),
                // 微信服务号（占位）
                _buildChannelToggle(
                  icon: FluentIcons.chat,
                  title: '微信服务号',
                  subtitle: '暂未接入',
                  value: _wechatServiceEnabled,
                  onChanged: (value) async {
                    await _messageState.setWechatServiceEnabled(value);
                    setState(() => _wechatServiceEnabled = value);
                    _showChannelChangedTip(value, '微信服务号');
                  },
                ),
                _buildIntervalSelector(
                  currentValue: _wechatServiceInterval,
                  enabled: _wechatServiceEnabled,
                  onChanged: (minutes) async {
                    await _messageState.setWechatServiceInterval(minutes);
                    setState(() => _wechatServiceInterval = minutes);
                  },
                ),
              ],
            ),
          ),
        ),

        // 消息推送设置卡片
        if (_selectedTab == 3)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '消息推送',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 16),
                // 推送全局开关
                Row(
                  children: [
                    const Icon(FluentIcons.ringer, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '启用消息推送',
                            style: FluentTheme.of(context)
                                .typography
                                .bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '当自动刷新发现新消息时推送系统通知',
                            style:
                                FluentTheme.of(context).typography.caption,
                          ),
                        ],
                      ),
                    ),
                    ToggleSwitch(
                      checked: _notificationEnabled,
                      onChanged: (value) async {
                        await _messageState.setNotificationEnabled(value);
                        setState(() => _notificationEnabled = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 勿扰模式开关
                Row(
                  children: [
                    Icon(
                      FluentIcons.ringer_off,
                      size: 20,
                      color: _notificationEnabled
                          ? null
                          : FluentTheme.of(context)
                              .inactiveColor
                              .withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '勿扰时段',
                            style: FluentTheme.of(context)
                                .typography
                                .bodyStrong
                                ?.copyWith(
                                  color: _notificationEnabled
                                      ? null
                                      : FluentTheme.of(context)
                                          .inactiveColor
                                          .withValues(alpha: 0.4),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '在指定时间段内不推送通知',
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: _notificationEnabled
                                      ? null
                                      : FluentTheme.of(context)
                                          .inactiveColor
                                          .withValues(alpha: 0.4),
                                ),
                          ),
                        ],
                      ),
                    ),
                    ToggleSwitch(
                      checked: _dndEnabled,
                      onChanged: _notificationEnabled
                          ? (value) async {
                              await _messageState.setDndEnabled(value);
                              setState(() => _dndEnabled = value);
                            }
                          : null,
                    ),
                  ],
                ),
                // 勿扰时间段选择器
                if (_dndEnabled && _notificationEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 10),
                    child: Row(
                      children: [
                        _buildTimePicker(
                          label: '开始',
                          hour: _dndStartHour,
                          minute: _dndStartMinute,
                          onChanged: (h, m) async {
                            await _messageState.setDndTime(
                              startHour: h,
                              startMinute: m,
                              endHour: _dndEndHour,
                              endMinute: _dndEndMinute,
                            );
                            setState(() {
                              _dndStartHour = h;
                              _dndStartMinute = m;
                            });
                          },
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '—',
                            style: FluentTheme.of(context)
                                .typography
                                .bodyStrong,
                          ),
                        ),
                        _buildTimePicker(
                          label: '结束',
                          hour: _dndEndHour,
                          minute: _dndEndMinute,
                          onChanged: (h, m) async {
                            await _messageState.setDndTime(
                              startHour: _dndStartHour,
                              startMinute: _dndStartMinute,
                              endHour: h,
                              endMinute: m,
                            );
                            setState(() {
                              _dndEndHour = h;
                              _dndEndMinute = m;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建设置分区导航栏按钮
  /// [index] 分区索引
  /// [icon] 图标
  /// [label] 显示文本
  Widget _buildNavTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Button(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          backgroundColor: WidgetStatePropertyAll(
            isSelected
                ? theme.accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
        ),
        onPressed: () => setState(() => _selectedTab = index),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? theme.accentColor : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: isSelected
                  ? theme.typography.bodyStrong
                      ?.copyWith(color: theme.accentColor)
                  : theme.typography.body,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建时间选择器（小时 + 分钟 ComboBox）
  /// [label] 标签（如“开始”“结束”）
  /// [hour] 当前小时（0–23）
  /// [minute] 当前分钟（0/15/30/45）
  /// [onChanged] 选中新值后回调
  Widget _buildTimePicker({
    required String label,
    required int hour,
    required int minute,
    required Future<void> Function(int h, int m) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: FluentTheme.of(context).typography.caption,
        ),
        ComboBox<int>(
          value: hour,
          items: List.generate(
            24,
            (h) => ComboBoxItem<int>(
              value: h,
              child: Text(h.toString().padLeft(2, '0')),
            ),
          ),
          onChanged: (h) {
            if (h != null) onChanged(h, minute);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ':',
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
        ),
        ComboBox<int>(
          value: [0, 15, 30, 45].contains(minute) ? minute : 0,
          items: const [
            ComboBoxItem(value: 0, child: Text('00')),
            ComboBoxItem(value: 15, child: Text('15')),
            ComboBoxItem(value: 30, child: Text('30')),
            ComboBoxItem(value: 45, child: Text('45')),
          ],
          onChanged: (m) {
            if (m != null) onChanged(hour, m);
          },
        ),
      ],
    );
  }

  /// 构建信息渠道开关行
  Widget _buildChannelToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
        ),
        ToggleSwitch(
          checked: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 渠道开关变更时显示提示栏
  /// [enabled] 是否启用
  /// [channelName] 渠道名称
  void _showChannelChangedTip(bool enabled, String channelName) {
    final message = enabled
        ? '已启用「$channelName」，请到信息中心刷新获取该渠道消息'
        : '已关闭「$channelName」，该渠道消息将不再显示';
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: Text(message),
          severity: enabled
              ? InfoBarSeverity.success
              : InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }
}
