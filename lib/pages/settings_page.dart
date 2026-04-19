/*
 * 设置页 — 应用设置与密码保护管理
 * @Project : SSPU-all-in-one
 * @File : settings_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../models/channel_config.dart';
import '../services/password_service.dart';
import '../services/storage_service.dart';
import '../services/message_state_service.dart';
import '../widgets/password_dialogs.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/channel_list_section.dart';

/// 设置页面
/// 包含密码保护、窗口行为、消息推送、职能部门/教学单位渠道管理、微信占位
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

  /// 消息推送全局开关
  bool _notificationEnabled = true;

  /// 勿扰模式开关
  bool _dndEnabled = false;

  /// 勿扰时间段
  int _dndStartHour = 22;
  int _dndStartMinute = 0;
  int _dndEndHour = 7;
  int _dndEndMinute = 0;

  /// 当前选中的设置分区索引
  /// 0=安全 1=窗口行为 2=消息推送 3=职能部门 4=教学单位 5=微信
  int _selectedTab = 0;

  /// 消息状态服务引用
  final MessageStateService _messageState = MessageStateService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 从本地存储加载密码保护状态、窗口行为偏好和推送配置
  Future<void> _loadSettings() async {
    final isSet = await PasswordService.isPasswordSet();
    final behavior = await StorageService.getCloseBehavior();
    // 加载消息推送与勿扰配置
    await _messageState.init();
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
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧垂直导航栏
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基础设置组
                  buildSettingsNavItem(context: context, index: 0, selectedIndex: _selectedTab, icon: FluentIcons.lock, label: '安全', onTap: () => setState(() => _selectedTab = 0)),
                  const SizedBox(height: 2),
                  buildSettingsNavItem(context: context, index: 1, selectedIndex: _selectedTab, icon: FluentIcons.chrome_close, label: '窗口行为', onTap: () => setState(() => _selectedTab = 1)),
                  const SizedBox(height: 2),
                  buildSettingsNavItem(context: context, index: 2, selectedIndex: _selectedTab, icon: FluentIcons.ringer, label: '消息推送', onTap: () => setState(() => _selectedTab = 2)),
                  // 分隔线
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Divider(),
                  ),
                  // 渠道设置组
                  buildSettingsNavItem(context: context, index: 3, selectedIndex: _selectedTab, icon: FluentIcons.education, label: '职能部门', onTap: () => setState(() => _selectedTab = 3)),
                  const SizedBox(height: 2),
                  buildSettingsNavItem(context: context, index: 4, selectedIndex: _selectedTab, icon: FluentIcons.library, label: '教学单位', onTap: () => setState(() => _selectedTab = 4)),
                  // 分隔线
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Divider(),
                  ),
                  buildSettingsNavItem(context: context, index: 5, selectedIndex: _selectedTab, icon: FluentIcons.chat, label: '微信', onTap: () => setState(() => _selectedTab = 5)),
                ],
              ),
            ),
          ),
          // 左侧分隔线
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(direction: Axis.vertical),
          ),
          // 右侧内容区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildContentPanel(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据当前选中的导航项构建右侧内容面板
  Widget _buildContentPanel(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return _buildSecuritySection(context);
      case 1:
        return _buildWindowBehaviorSection(context);
      case 2:
        return _buildNotificationSection(context);
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
        return _buildWechatPlaceholder(context);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 安全设置内容
  Widget _buildSecuritySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全', style: FluentTheme.of(context).typography.subtitle),
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
                      Text('密码保护', style: FluentTheme.of(context).typography.bodyStrong),
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
                      showSetPasswordDialog(context).then((ok) {
                        if (ok && mounted) {
                          setState(() => _isPasswordEnabled = true);
                          _showSuccessBar('密码已设置');
                        }
                      });
                    } else {
                      showRemovePasswordDialog(context).then((ok) {
                        if (ok && mounted) {
                          setState(() => _isPasswordEnabled = false);
                          _showSuccessBar('密码保护已移除');
                        }
                      });
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
                    onPressed: () => showChangePasswordDialog(context).then((ok) {
                      if (ok && mounted) _showSuccessBar('密码已修改');
                    }),
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
    );
  }

  /// 窗口行为设置内容
  Widget _buildWindowBehaviorSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('窗口行为', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(FluentIcons.chrome_close, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('关闭按钮行为', style: FluentTheme.of(context).typography.bodyStrong),
                      const SizedBox(height: 2),
                      Text('选择点击窗口关闭按钮时的操作', style: FluentTheme.of(context).typography.caption),
                    ],
                  ),
                ),
                ComboBox<String>(
                  value: _closeBehavior,
                  items: const [
                    ComboBoxItem(value: 'ask', child: Text('每次询问')),
                    ComboBoxItem(value: 'minimize', child: Text('最小化到托盘')),
                    ComboBoxItem(value: 'exit', child: Text('直接退出')),
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
    );
  }

  /// 消息推送设置内容
  Widget _buildNotificationSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('消息推送', style: FluentTheme.of(context).typography.subtitle),
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
                      Text('启用消息推送', style: FluentTheme.of(context).typography.bodyStrong),
                      const SizedBox(height: 2),
                      Text('当自动刷新发现新消息时推送系统通知', style: FluentTheme.of(context).typography.caption),
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
                      : FluentTheme.of(context).inactiveColor.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '勿扰时段',
                        style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                          color: _notificationEnabled
                              ? null
                              : FluentTheme.of(context).inactiveColor.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '在指定时间段内不推送通知',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: _notificationEnabled
                              ? null
                              : FluentTheme.of(context).inactiveColor.withValues(alpha: 0.4),
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
                    buildTimePicker(
                      context: context,
                      label: '开始',
                      hour: _dndStartHour,
                      minute: _dndStartMinute,
                      onChanged: (h, m) async {
                        await _messageState.setDndTime(
                          startHour: h, startMinute: m,
                          endHour: _dndEndHour, endMinute: _dndEndMinute,
                        );
                        setState(() { _dndStartHour = h; _dndStartMinute = m; });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('—', style: FluentTheme.of(context).typography.bodyStrong),
                    ),
                    buildTimePicker(
                      context: context,
                      label: '结束',
                      hour: _dndEndHour,
                      minute: _dndEndMinute,
                      onChanged: (h, m) async {
                        await _messageState.setDndTime(
                          startHour: _dndStartHour, startMinute: _dndStartMinute,
                          endHour: h, endMinute: m,
                        );
                        setState(() { _dndEndHour = h; _dndEndMinute = m; });
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 微信栏目占位内容
  Widget _buildWechatPlaceholder(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('微信', style: theme.typography.subtitle),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(FluentIcons.chat, size: 48, color: theme.inactiveColor.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('微信渠道尚未接入', style: theme.typography.bodyStrong),
                const SizedBox(height: 4),
                Text('微信公众号和服务号的消息接入将在后续版本支持', style: theme.typography.caption),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
