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
import '../services/message_state_service.dart';
import '../services/password_service.dart';
import '../services/storage_service.dart';
import '../theme/fluent_tokens.dart';
import '../widgets/channel_list_section.dart';
import '../widgets/password_dialogs.dart';
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

  /// 当前选中的设置分区索引。
  /// 0=常规设置 1=安全设置 2=职能部门 3=教学单位 4=微信推文
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
    final behavior = await StorageService.getCloseBehavior();
    await _messageState.init();

    final notifEnabled = await _messageState.isNotificationEnabled();
    final dndOn = await _messageState.isDndEnabled();
    final dndStartHour = await _messageState.getDndStartHour();
    final dndStartMinute = await _messageState.getDndStartMinute();
    final dndEndHour = await _messageState.getDndEndHour();
    final dndEndMinute = await _messageState.getDndEndMinute();

    if (!mounted) return;
    setState(() {
      _isPasswordEnabled = isSet;
      _closeBehavior = behavior;
      _notificationEnabled = notifEnabled;
      _dndEnabled = dndOn;
      _dndStartHour = dndStartHour;
      _dndStartMinute = dndStartMinute;
      _dndEndHour = dndEndHour;
      _dndEndMinute = dndEndMinute;
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

  /// 切换密码保护。
  Future<void> _onPasswordProtectionChanged(bool enabled) async {
    if (enabled) {
      final ok = await showSetPasswordDialog(context);
      if (ok && mounted) {
        setState(() => _isPasswordEnabled = true);
        _showSuccessBar('密码已设置');
      }
      return;
    }

    final ok = await showRemovePasswordDialog(context);
    if (ok && mounted) {
      setState(() => _isPasswordEnabled = false);
      _showSuccessBar('密码保护已移除');
    }
  }

  /// 修改密码。
  Future<void> _onChangePassword() async {
    final ok = await showChangePasswordDialog(context);
    if (ok && mounted) {
      _showSuccessBar('密码已修改');
    }
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
      await StorageService.clearAll();
      await AppExitService.instance.exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    return ScaffoldPage(
      header: const PageHeader(title: Text('设置')),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          return isNarrow
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
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: _buildSettingsNavigation(context),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(direction: Axis.vertical),
        ),
        Expanded(
          child: _buildScrollableContent(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _buildSettingsTabCombo(context),
        ),
        const Divider(),
        Expanded(
          child: _buildScrollableContent(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          icon: FluentIcons.lock,
          label: '安全设置',
          onTap: () => setState(() => _selectedTab = 1),
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
          index: 2,
          selectedIndex: _selectedTab,
          icon: FluentIcons.education,
          label: '职能部门',
          onTap: () => setState(() => _selectedTab = 2),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 3,
          selectedIndex: _selectedTab,
          icon: FluentIcons.library,
          label: '教学单位',
          onTap: () => setState(() => _selectedTab = 3),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 4,
          selectedIndex: _selectedTab,
          icon: FluentIcons.chat,
          label: '微信推文',
          onTap: () => setState(() => _selectedTab = 4),
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
            value: _selectedTab,
            isExpanded: true,
            items: const [
              ComboBoxItem(value: 0, child: Text('常规设置')),
              ComboBoxItem(value: 1, child: Text('安全设置')),
              ComboBoxItem(value: 2, child: Text('职能部门')),
              ComboBoxItem(value: 3, child: Text('教学单位')),
              ComboBoxItem(value: 4, child: Text('微信推文')),
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
        return SettingsSecuritySection(
          isPasswordEnabled: _isPasswordEnabled,
          onPasswordProtectionChanged: (value) =>
              _onPasswordProtectionChanged(value),
          onChangePassword: _onChangePassword,
          onLock: widget.onLock,
          onClearMessageCache: _showClearMessageCacheDialog,
          onClearAllData: _showClearAllDataDialog,
        );
      case 2:
        return ChannelListSection(
          key: const ValueKey('department'),
          title: '职能部门',
          channels: departmentChannels,
        );
      case 3:
        return ChannelListSection(
          key: const ValueKey('teaching'),
          title: '教学单位',
          channels: teachingChannels,
        );
      case 4:
        return const SettingsWechatSection();
      default:
        return const SizedBox.shrink();
    }
  }
}
