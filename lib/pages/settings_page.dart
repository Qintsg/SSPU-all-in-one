/*
 * 设置页 — 应用设置与密码保护管理
 * @Project : SSPU-all-in-one
 * @File : settings_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_exit_service.dart';
import '../models/channel_config.dart';
import '../services/auto_refresh_service.dart';
import '../services/password_service.dart';
import '../services/storage_service.dart';
import '../services/message_state_service.dart';
import '../widgets/password_dialogs.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/channel_list_section.dart';
import '../services/wechat_article_service.dart';
import '../services/wxmp_auth_service.dart';
import '../services/wxmp_article_service.dart';
import '../models/sspu_wechat_accounts.dart';
import '../theme/fluent_tokens.dart';
import '../utils/webview_env.dart';
import 'wxmp_login_page.dart';

/// 设置页面
/// 包含密码保护、窗口行为、消息推送、职能部门/教学单位渠道管理与微信公众号配置
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
  /// 0=常规设置 1=安全设置 2=职能部门 3=教学单位 4=微信推文
  int _selectedTab = 0;

  /// 消息状态服务引用
  final MessageStateService _messageState = MessageStateService.instance;

  /// 微信文章采集服务引用
  final WechatArticleService _wechatService = WechatArticleService.instance;

  /// 公众号平台认证服务引用
  final WxmpAuthService _wxmpAuth = WxmpAuthService.instance;

  /// 公众号平台文章服务引用
  final WxmpArticleService _wxmpService = WxmpArticleService.instance;

  /// 自动刷新服务引用，用于设置变更后即时重载微信公众号定时器。
  final AutoRefreshService _autoRefresh = AutoRefreshService.instance;

  /// 公众号平台是否已认证
  bool _wxmpAuthenticated = false;

  /// 公众号平台认证诊断状态。
  WxmpAuthStatus? _wxmpAuthStatus;

  /// 微信推文获取总开关。
  bool _wechatChannelEnabled = false;

  /// 微信推文自动刷新开关。
  bool _wechatAutoRefreshEnabled = false;

  /// 微信推文自动刷新间隔。
  int _wechatRefreshInterval = 120;

  /// 微信推文手动刷新文章个数。
  int _wechatManualFetchCount = 20;

  /// 微信推文自动刷新文章个数。
  int _wechatAutoFetchCount = 20;

  /// 公众号平台已关注的公众号列表
  List<Map<String, String>> _wxmpFollowedMps = [];

  /// 公众号平台公众号通知开关缓存（key = fakeid）
  Map<String, bool> _wxmpMpNotificationEnabled = {};

  /// 搜索公众号的输入框控制器
  final TextEditingController _wxmpSearchController = TextEditingController();

  /// 搜索结果
  List<Map<String, String>> _wxmpSearchResults = [];

  /// 是否正在搜索
  bool _wxmpSearching = false;
  bool _wxmpBatchFollowing = false;
  String _wxmpBatchProgress = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _wxmpSearchController.dispose();
    super.dispose();
  }

  /// 从本地存储加载密码保护状态、窗口行为偏好和推送配置
  Future<void> _loadSettings() async {
    final isSet = await PasswordService.isPasswordSet();
    final behavior = await StorageService.getCloseBehavior();
    // 加载消息推送与勿扰配置
    await _messageState.init();
    await _wechatService.clearLegacyWereadState();
    final notifEnabled = await _messageState.isNotificationEnabled();
    final dndOn = await _messageState.isDndEnabled();
    final dndSH = await _messageState.getDndStartHour();
    final dndSM = await _messageState.getDndStartMinute();
    final dndEH = await _messageState.getDndEndHour();
    final dndEM = await _messageState.getDndEndMinute();
    final wxmpAuthStatus = await _wxmpAuth.getAuthStatus();
    final wxmpHasAuth = wxmpAuthStatus.isUsable;
    final wechatEnabled = await _messageState.isChannelEnabled(
      'wechat_public',
      defaultValue: false,
    );
    final wechatAutoEnabled = await _messageState.isChannelAutoRefreshEnabled(
      'wechat_public',
    );
    final wechatInterval = await _messageState.getChannelDisplayInterval(
      'wechat_public',
      defaultValue: 120,
    );
    final wechatManualCount = await _messageState.getChannelManualFetchCount(
      'wechat_public',
    );
    final wechatAutoCount = await _messageState.getChannelAutoFetchCount(
      'wechat_public',
    );
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
        _wxmpAuthenticated = wxmpHasAuth;
        _wxmpAuthStatus = wxmpAuthStatus;
        _wechatChannelEnabled = wechatEnabled;
        _wechatAutoRefreshEnabled = wechatAutoEnabled;
        _wechatRefreshInterval = wechatInterval;
        _wechatManualFetchCount = wechatManualCount;
        _wechatAutoFetchCount = wechatAutoCount;
        _isLoading = false;
      });
    }
    if (wxmpHasAuth) await _loadWxmpFollowedMps();
  }

  /// 显示操作成功的提示条
  void _showSuccessBar(String message) {
    displayInfoBar(
      context,
      builder: (infoBarContext, close) =>
          InfoBar(title: Text(message), severity: InfoBarSeverity.success),
    );
  }

  /// 打开外部链接。
  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (infoBarContext, close) => InfoBar(
        title: const Text('无法打开链接'),
        content: Text(url),
        severity: InfoBarSeverity.warning,
      ),
    );
  }

  /// 切换微信推文获取总开关。
  Future<void> _onWechatChannelToggled(bool enabled) async {
    await _messageState.setChannelEnabled('wechat_public', enabled);
    setState(() => _wechatChannelEnabled = enabled);
    await _autoRefresh.reloadChannel('wechat_public');
  }

  /// 修改微信推文手动刷新条数。
  Future<void> _onWechatManualFetchCountChanged(int count) async {
    final normalized = count.clamp(1, 200);
    await _messageState.setChannelManualFetchCount('wechat_public', normalized);
    setState(() => _wechatManualFetchCount = normalized);
  }

  /// 切换微信推文自动刷新状态。
  Future<void> _onWechatAutoRefreshToggled(bool enabled) async {
    if (enabled) {
      final interval = _wechatRefreshInterval <= 0
          ? 120
          : _wechatRefreshInterval;
      await _messageState.setChannelInterval('wechat_public', interval);
      setState(() {
        _wechatAutoRefreshEnabled = true;
        _wechatRefreshInterval = interval;
      });
    } else {
      await _messageState.setChannelAutoRefreshEnabled('wechat_public', false);
      setState(() => _wechatAutoRefreshEnabled = false);
    }
    await _autoRefresh.reloadChannel('wechat_public');
  }

  /// 修改微信推文自动刷新频率。
  Future<void> _onWechatRefreshIntervalChanged(int minutes) async {
    await _messageState.setChannelInterval('wechat_public', minutes);
    setState(() {
      _wechatRefreshInterval = minutes;
      _wechatAutoRefreshEnabled = minutes > 0;
    });
    await _autoRefresh.reloadChannel('wechat_public');
  }

  /// 修改微信推文自动刷新条数。
  Future<void> _onWechatAutoFetchCountChanged(int count) async {
    final normalized = count.clamp(1, 200);
    await _messageState.setChannelAutoFetchCount('wechat_public', normalized);
    setState(() => _wechatAutoFetchCount = normalized);
    await _autoRefresh.reloadChannel('wechat_public');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Text(
                      '系统设置',
                      style: FluentTheme.of(context).typography.caption
                          ?.copyWith(
                            color: FluentTheme.of(
                              context,
                            ).resources.textFillColorSecondary,
                          ),
                    ),
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
                    child: Text(
                      '消息推送设置',
                      style: FluentTheme.of(context).typography.caption
                          ?.copyWith(
                            color: FluentTheme.of(
                              context,
                            ).resources.textFillColorSecondary,
                          ),
                    ),
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
              child: _buildContentPanel(context)
                  .animate(key: ValueKey(_selectedTab))
                  .fadeIn(
                    duration: FluentDuration.slow,
                    curve: FluentEasing.decelerate,
                  )
                  .slideY(begin: 0.02, end: 0),
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
        return _buildGeneralSection(context);
      case 1:
        return _buildSecuritySection(context);
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
        return _buildWechatSection(context);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 常规设置内容（窗口行为 + 消息推送）
  Widget _buildGeneralSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWindowBehaviorSection(context),
        const SizedBox(height: FluentSpacing.l),
        _buildNotificationSection(context),
      ],
    );
  }

  /// 安全设置内容
  Widget _buildSecuritySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            // 密码保护开关行
            Row(
              children: [
                const Icon(FluentIcons.lock, size: 20),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '密码保护',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                      const SizedBox(height: FluentSpacing.xxs),
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
              const SizedBox(height: FluentSpacing.m),
              Row(
                children: [
                  Button(
                    child: const Text('修改密码'),
                    onPressed: () =>
                        showChangePasswordDialog(context).then((ok) {
                          if (ok && mounted) _showSuccessBar('密码已修改');
                        }),
                  ),
                  const SizedBox(width: FluentSpacing.m),
                  FilledButton(
                    onPressed: widget.onLock,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.lock, size: 14),
                        SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
                        Text('立即上锁'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: FluentSpacing.xl),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            // 数据管理
            Text('数据管理', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '清理信息中心缓存的消息，不影响登录信息和设置',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            Button(
              onPressed: () => _showClearMessageCacheDialog(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.broom, size: 14),
                  SizedBox(width: 6),
                  Text('清理信息中心缓存'),
                ],
              ),
            ),
            const SizedBox(height: FluentSpacing.l),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            Text(
              '清除所有本地数据（包括登录信息、设置、缓存等），应用将退出',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            Button(
              onPressed: () => _showClearAllDataDialog(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14),
                  SizedBox(width: 6),
                  Text('清除所有数据'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 窗口行为设置内容
  Widget _buildWindowBehaviorSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('窗口行为', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            Row(
              children: [
                const Icon(FluentIcons.chrome_close, size: 20),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '关闭按钮行为',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                      const SizedBox(height: FluentSpacing.xxs),
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
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('消息推送', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            // 推送全局开关
            Row(
              children: [
                const Icon(FluentIcons.ringer, size: 20),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '启用消息推送',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '当自动刷新发现新消息时推送系统通知',
                        style: FluentTheme.of(context).typography.caption,
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
            const SizedBox(height: FluentSpacing.l),
            // 勿扰模式开关
            Row(
              children: [
                Icon(
                  FluentIcons.ringer_off,
                  size: 20,
                  color: _notificationEnabled
                      ? null
                      : FluentTheme.of(
                          context,
                        ).inactiveColor.withValues(alpha: 0.4),
                ),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '勿扰时段',
                        style: FluentTheme.of(context).typography.bodyStrong
                            ?.copyWith(
                              color: _notificationEnabled
                                  ? null
                                  : FluentTheme.of(
                                      context,
                                    ).inactiveColor.withValues(alpha: 0.4),
                            ),
                      ),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '在指定时间段内不推送通知',
                        style: FluentTheme.of(context).typography.caption
                            ?.copyWith(
                              color: _notificationEnabled
                                  ? null
                                  : FluentTheme.of(
                                      context,
                                    ).inactiveColor.withValues(alpha: 0.4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '—',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ),
                    buildTimePicker(
                      context: context,
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
    );
  }

  /// 微信栏目设置内容 — 展示刷新设置、公众号平台认证与 SSPU 微信矩阵。
  Widget _buildWechatSection(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('微信推文消息获取', style: theme.typography.subtitle),
        const SizedBox(height: FluentSpacing.l),
        _buildWechatRefreshSettings(context),
        const SizedBox(height: FluentSpacing.l),
        _buildWechatFetchMethodCard(context),
        const SizedBox(height: FluentSpacing.l),
        ..._buildWxmpAuthUI(context),
        _buildSspuRecommendedAccounts(context),
      ],
    );
  }

  /// 构建微信推文刷新设置卡片。
  Widget _buildWechatRefreshSettings(BuildContext context) {
    final theme = FluentTheme.of(context);
    final disabledColor = theme.resources.textFillColorSecondary.withValues(
      alpha: 0.7,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('刷新设置', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.s),
            Wrap(
              spacing: FluentSpacing.l,
              runSpacing: FluentSpacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                buildCountNumberBox(
                  context: context,
                  label: '手动刷新文章个数',
                  value: _wechatManualFetchCount,
                  enabled: _wechatChannelEnabled,
                  onChanged: _onWechatManualFetchCountChanged,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '启用自动刷新：',
                      style: theme.typography.caption?.copyWith(
                        color: _wechatChannelEnabled ? null : disabledColor,
                      ),
                    ),
                    const SizedBox(width: FluentSpacing.xs),
                    ToggleSwitch(
                      checked: _wechatAutoRefreshEnabled,
                      onChanged: _wechatChannelEnabled
                          ? _onWechatAutoRefreshToggled
                          : null,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '自动刷新频率：',
                      style: theme.typography.caption?.copyWith(
                        color:
                            _wechatChannelEnabled && _wechatAutoRefreshEnabled
                            ? null
                            : disabledColor,
                      ),
                    ),
                    const SizedBox(width: FluentSpacing.xs),
                    ComboBox<int>(
                      value:
                          kIntervalOptions.containsKey(_wechatRefreshInterval)
                          ? _wechatRefreshInterval
                          : 120,
                      items: kIntervalOptions.entries
                          .where((entry) => entry.key > 0)
                          .map(
                            (entry) => ComboBoxItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _wechatChannelEnabled && _wechatAutoRefreshEnabled
                          ? (value) {
                              if (value != null) {
                                _onWechatRefreshIntervalChanged(value);
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                buildCountNumberBox(
                  context: context,
                  label: '自动刷新文章个数',
                  value: _wechatAutoFetchCount,
                  enabled: _wechatChannelEnabled && _wechatAutoRefreshEnabled,
                  onChanged: _onWechatAutoFetchCountChanged,
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.s),
            Text(
              '注意：若频率过快，可能会触发微信公众平台的接口频率限制。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建公众号平台获取方式卡片。
  Widget _buildWechatFetchMethodCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(FluentIcons.cloud_download, size: 20),
            const SizedBox(width: FluentSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('获取方式：微信公众平台', style: theme.typography.bodyStrong),
                  const SizedBox(height: FluentSpacing.xs),
                  Text(
                    '通过微信公众平台 API 获取推文，需要先注册并登录公众号平台账号。应用不再提供微信读书接入方式。',
                    style: theme.typography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: FluentSpacing.m),
            ToggleSwitch(
              checked: _wechatChannelEnabled,
              onChanged: _onWechatChannelToggled,
            ),
          ],
        ),
      ),
    );
  }

  /// 公众号平台认证区域
  List<Widget> _buildWxmpAuthUI(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return [
      // 使用指引
      Expander(
        header: const Text('微信公众平台注册方式 >'),
        icon: const Icon(FluentIcons.help, size: 16),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('适用人群', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '• 想直接在本应用里搜索任意公众号、批量关注推荐公众号，并统一使用公众号平台链路。',
              style: theme.typography.body,
            ),
            Text(
              '• 能接受先注册一个微信公众号账号，再回来用该账号登录公众平台。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('前置条件', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 需要一个可以登录微信公众平台的公众号账号。', style: theme.typography.body),
            Text(
              '• 注册时通常需要：一个未用于公众号注册的邮箱、一个实名认证微信作为管理员微信，以及按平台页面要求填写的主体信息。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('如何注册微信公众平台账号', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '根据微信公众平台首页和微信开放社区现有流程说明：先在电脑浏览器打开 mp.weixin.qq.com，点击右上角“立即注册”。',
              style: theme.typography.body,
            ),
            Text(
              '常见顺序为：1）选择账号类型；2）填写并激活邮箱；3）完成信息登记；4）填写公众号名称、简介和运营地区。',
              style: theme.typography.body,
            ),
            Text(
              '个人使用场景通常会先看“公众号 / 订阅号”路线；具体账号能力与限制请以注册页当时显示的官方说明为准。',
              style: theme.typography.body,
            ),
            Text(
              '如果扫码登录时页面提示“该微信还未注册公众平台账号”，说明当前微信下没有可登录的公众号，需要先完成上面的注册流程。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.s),
            Button(
              onPressed: () => _openExternalUrl('https://mp.weixin.qq.com/'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('打开微信公众平台官网'),
                  SizedBox(width: 6),
                  Icon(FluentIcons.open_in_new_window, size: 12),
                ],
              ),
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('在本应用中的配置步骤', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '1. 先确保你已经能在浏览器正常进入 mp.weixin.qq.com 后台。',
              style: theme.typography.body,
            ),
            Text('2. 回到本应用，进入「设置 → 微信」。', style: theme.typography.body),
            Text('3. 点击下方「扫码登录」，使用管理员微信完成登录。', style: theme.typography.body),
            Text(
              '4. 登录成功后，应用会自动提取 Cookie 和 Token，状态显示为「已认证」。',
              style: theme.typography.body,
            ),
            Text(
              '5. 之后你可以在下方搜索公众号，或直接使用 SSPU 推荐列表中的「一键全部关注」。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('搜索与关注方式', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '• 手动方式：在「搜索公众号」输入名称，确认搜索结果后点击「关注」。',
              style: theme.typography.body,
            ),
            Text(
              '• 批量方式：对 SSPU 推荐公众号可直接点击「一键全部关注」，系统会逐个搜索并自动跳过已关注项。',
              style: theme.typography.body,
            ),
            Text(
              '• 已关注列表中的通知开关只影响本应用是否抓取/提醒，不会改动公众平台后台本身。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('失败排查', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '• 扫码页提示没有可登录账号：先去官网完成注册，再回来扫码。',
              style: theme.typography.body,
            ),
            Text(
              '• 注册后仍无法登录：确认账号信息已经填写完成，并且你能在普通浏览器中正常进入后台首页。',
              style: theme.typography.body,
            ),
            Text(
              '• 搜索或批量关注中断：通常是会话过期或接口频率限制，重新扫码后稍等一会儿再试。',
              style: theme.typography.body,
            ),
            Text(
              '• 搜到的第一个结果不对：可以手动搜索后确认名称/微信号，再点击关注，而不是完全依赖批量流程。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('是否推荐使用', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 如果你追求“搜索更全、应用内直接关注”，这一方式更强。', style: theme.typography.body),
            Text(
              '• 当前应用已统一保留这一条链路，完成一次认证后即可持续使用。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.m),
            Text('FAQ', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：个人一定要完成额外认证才能用吗？', style: theme.typography.bodyStrong),
            Text(
              'A：本应用需要的是“你能正常登录公众平台后台并拿到登录态”。是否还需要做后续认证，取决于你自己的运营需求和平台当时规则。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：为什么这一方式要先注册公众号？', style: theme.typography.bodyStrong),
            Text(
              'A：因为应用调用的是公众平台后台接口，必须先有一个能登录后台的账号作为入口。',
              style: theme.typography.body,
            ),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：为什么现在只保留这一种方式？', style: theme.typography.bodyStrong),
            Text(
              'A：为减少配置分叉与维护成本，应用已统一保留公众号平台链路，并围绕该链路提供搜索、关注和刷新能力。',
              style: theme.typography.body,
            ),
          ],
        ),
      ),
      const SizedBox(height: FluentSpacing.l),

      // 公众号平台认证卡片
      Card(
        child: Padding(
          padding: const EdgeInsets.all(FluentSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('公众号平台认证', style: theme.typography.bodyStrong),
              const SizedBox(height: FluentSpacing.xs),
              Text(
                '通过公众号管理平台 (mp.weixin.qq.com) 获取推文，需拥有公众号（个人订阅号即可）',
                style: theme.typography.caption,
              ),
              if (_wxmpAuthStatus != null) ...[
                const SizedBox(height: FluentSpacing.xs),
                Text(
                  _wxmpAuthStatus!.message,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
              const SizedBox(height: FluentSpacing.m),

              // 认证状态
              Row(
                children: [
                  Icon(
                    _wxmpAuthenticated
                        ? FluentIcons.check_mark
                        : FluentIcons.warning,
                    size: 16,
                    color: _wxmpAuthenticated
                        ? (isDark
                              ? FluentDarkColors.statusSuccess
                              : FluentLightColors.statusSuccess)
                        : (isDark
                              ? FluentDarkColors.statusWarning
                              : FluentLightColors.statusWarning),
                  ),
                  const SizedBox(width: FluentSpacing.s),
                  Text(
                    _wxmpAuthenticated ? '已认证' : '未认证',
                    style: theme.typography.body,
                  ),
                ],
              ),
              const SizedBox(height: FluentSpacing.m),

              // 操作按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _openWxmpLogin(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.q_r_code, size: 14),
                        SizedBox(width: 6),
                        Text('扫码登录'),
                      ],
                    ),
                  ),
                  if (_wxmpAuthenticated)
                    Button(
                      onPressed: _clearWxmpAuth,
                      child: const Text('清除认证'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: FluentSpacing.l),

      // 搜索并关注公众号
      if (_wxmpAuthenticated) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('搜索公众号', style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.xs),
                Text('搜索并关注公众号，关注后可自动获取推文', style: theme.typography.caption),
                const SizedBox(height: FluentSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: _wxmpSearchController,
                        placeholder: '输入公众号名称搜索',
                        onSubmitted: (_) => _searchWxmpMp(),
                      ),
                    ),
                    const SizedBox(width: FluentSpacing.s),
                    Button(
                      onPressed: _wxmpSearching ? null : _searchWxmpMp,
                      child: _wxmpSearching
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Text('搜索'),
                    ),
                  ],
                ),
                // 搜索结果
                if (_wxmpSearchResults.isNotEmpty) ...[
                  const SizedBox(height: FluentSpacing.m),
                  ...(_wxmpSearchResults.map(
                    (mp) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            FluentIcons.chat,
                            size: 16,
                            color: theme.accentColor,
                          ),
                          const SizedBox(width: FluentSpacing.s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mp['nickname'] ?? '',
                                  style: theme.typography.body,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((mp['alias'] ?? '').isNotEmpty)
                                  Text(
                                    '微信号：${mp['alias']}',
                                    style: theme.typography.caption,
                                  ),
                              ],
                            ),
                          ),
                          Button(
                            onPressed: () => _followWxmpMp(mp),
                            child: const Text('关注'),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.l),
      ],

      // 已关注公众号列表
      if (_wxmpAuthenticated && _wxmpFollowedMps.isNotEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('已关注公众号', style: theme.typography.bodyStrong),
                    const Spacer(),
                    Button(
                      onPressed: _loadWxmpFollowedMps,
                      child: const Text('刷新列表'),
                    ),
                  ],
                ),
                const SizedBox(height: FluentSpacing.s),
                ...(_wxmpFollowedMps.map(
                  (mp) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          FluentIcons.chat,
                          size: 16,
                          color: theme.accentColor,
                        ),
                        const SizedBox(width: FluentSpacing.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mp['name'] ?? '',
                                style: theme.typography.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((mp['alias'] ?? '').isNotEmpty)
                                Text(
                                  '微信号：${mp['alias']}',
                                  style: theme.typography.caption,
                                ),
                            ],
                          ),
                        ),
                        // 通知开关
                        Tooltip(
                          message: '控制是否接收该公众号的推文通知',
                          child: ToggleSwitch(
                            checked:
                                _wxmpMpNotificationEnabled[mp['fakeid']] ??
                                true,
                            onChanged: (value) async {
                              final fakeid = mp['fakeid'] ?? '';
                              if (fakeid.isEmpty) return;
                              await MessageStateService.instance
                                  .setMpNotificationEnabled(fakeid, value);
                              setState(() {
                                _wxmpMpNotificationEnabled[fakeid] = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: FluentSpacing.xs),
                        // 取消关注
                        Tooltip(
                          message: '取消关注',
                          child: IconButton(
                            icon: const Icon(FluentIcons.cancel, size: 14),
                            onPressed: () =>
                                _unfollowWxmpMp(mp['fakeid'] ?? ''),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.l),
      ],
    ];
  }

  /// 清除所有本地数据（带二次确认对话框），确认后退出应用
  /// 清理信息中心缓存对话框
  Future<void> _showClearMessageCacheDialog(BuildContext context) async {
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
      // 清除持久化的消息列表和已读状态
      await StorageService.remove(MessageChannelKeys.persistedMessages);
      await StorageService.remove(MessageChannelKeys.readMessageIds);
      if (mounted) {
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
  }

  Future<void> _showClearAllDataDialog(BuildContext context) async {
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

  /// 打开公众号平台扫码登录页
  Future<void> _openWxmpLogin(BuildContext context) async {
    final success = await Navigator.of(context).push<bool>(
      FluentPageRoute(
        builder: (_) =>
            WxmpLoginPage(webViewEnvironment: globalWebViewEnvironment),
      ),
    );

    if (success == true && mounted) {
      final authStatus = await _wxmpAuth.getAuthStatus();
      setState(() {
        _wxmpAuthenticated = authStatus.isUsable;
        _wxmpAuthStatus = authStatus;
      });
      if (authStatus.isUsable) await _loadWxmpFollowedMps();
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('公众号平台登录成功'),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    }
  }

  /// 清除公众号平台认证
  Future<void> _clearWxmpAuth() async {
    await _wxmpAuth.clearAuth();
    if (mounted) {
      setState(() {
        _wxmpAuthenticated = false;
        _wxmpAuthStatus = const WxmpAuthStatus(
          state: WxmpAuthState.missingCookie,
          lastUpdate: null,
        );
        _wxmpFollowedMps = [];
        _wxmpSearchResults = [];
      });
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('公众号平台认证已清除'),
            severity: InfoBarSeverity.info,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    }
  }

  /// 搜索公众号（公众号平台方式）
  Future<void> _searchWxmpMp() async {
    final keyword = _wxmpSearchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _wxmpSearching = true;
      _wxmpSearchResults = [];
    });

    try {
      final results = await _wxmpService.searchMp(keyword);
      if (mounted) {
        setState(() {
          _wxmpSearchResults = results;
          _wxmpSearching = false;
        });
        if (results.isEmpty) {
          displayInfoBar(
            context,
            builder: (ctx, close) {
              return InfoBar(
                title: const Text('未找到匹配的公众号'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              );
            },
          );
        }
      }
    } on WxmpSessionExpiredException {
      if (mounted) {
        setState(() {
          _wxmpSearching = false;
          _wxmpAuthenticated = false;
        });
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('Session 已失效，请重新登录'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } on WxmpFrequencyLimitException {
      if (mounted) {
        setState(() => _wxmpSearching = false);
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('请求频率过快，请稍后再试'),
              severity: InfoBarSeverity.warning,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _wxmpSearching = false);
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: Text('搜索失败：$e'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    }
  }

  /// 关注公众号（公众号平台方式）
  Future<void> _followWxmpMp(Map<String, String> mp) async {
    final fakeid = mp['fakeid'] ?? '';
    final name = mp['nickname'] ?? '';
    if (fakeid.isEmpty || name.isEmpty) return;

    await _wxmpService.followMp(
      fakeid,
      name,
      alias: mp['alias'],
      avatar: mp['round_head_img'],
    );
    await _loadWxmpFollowedMps();

    if (mounted) {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: Text('已关注「$name」'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    }
  }

  /// 取消关注（公众号平台方式）
  Future<void> _unfollowWxmpMp(String fakeid) async {
    if (fakeid.isEmpty) return;
    await _wxmpService.unfollowMp(fakeid);
    await _loadWxmpFollowedMps();
  }

  /// 加载公众号平台已关注列表
  Future<void> _loadWxmpFollowedMps() async {
    final mps = await _wxmpService.getFollowedMpList();
    final stateService = MessageStateService.instance;
    final enabledMap = <String, bool>{};
    for (final mp in mps) {
      final fakeid = mp['fakeid'] ?? '';
      if (fakeid.isNotEmpty) {
        enabledMap[fakeid] = await stateService.isMpNotificationEnabled(fakeid);
      }
    }
    if (mounted) {
      setState(() {
        _wxmpFollowedMps = mps;
        _wxmpMpNotificationEnabled = enabledMap;
      });
    }
  }

  /// 一键关注所有 SSPU 推荐公众号（公众号平台方式）
  Future<void> _batchFollowSspuWxmp(BuildContext context) async {
    if (_wxmpBatchFollowing) return;

    final hasAuth = await _wxmpAuth.hasAuth();
    if (!hasAuth) {
      if (context.mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('请先扫码登录公众号平台'),
            severity: InfoBarSeverity.warning,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _wxmpBatchFollowing = true;
      _wxmpBatchProgress = '准备中...';
    });

    int added = 0;
    int skipped = 0;
    int failed = 0;
    bool rateLimited = false;

    for (int i = 0; i < sspuWechatAccounts.length; i++) {
      if (!mounted) break;
      final account = sspuWechatAccounts[i];

      setState(() {
        _wxmpBatchProgress =
            '正在处理 ${i + 1}/${sspuWechatAccounts.length}：${account.name}';
      });

      try {
        // 搜索公众号
        final results = await _wxmpService.searchMp(account.name, count: 3);
        if (results.isEmpty) {
          failed++;
          continue;
        }

        // 取第一个结果
        final mp = results.first;
        final fakeid = mp['fakeid'] ?? '';
        if (fakeid.isEmpty) {
          failed++;
          continue;
        }

        // 检查是否已关注
        final alreadyFollowed = await _wxmpService.isFollowed(fakeid);
        if (alreadyFollowed) {
          skipped++;
          continue;
        }

        // 关注
        await _wxmpService.followMp(
          fakeid,
          mp['nickname'] ?? account.name,
          alias: mp['alias'],
          avatar: mp['round_head_img'],
        );
        added++;

        // 请求间隔，避免频率限制
        if (i < sspuWechatAccounts.length - 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      } on WxmpSessionExpiredException {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (ctx, close) => InfoBar(
              title: const Text('会话已过期，请重新扫码登录后重试'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            ),
          );
        }
        break;
      } on WxmpFrequencyLimitException {
        rateLimited = true;
        break;
      } catch (_) {
        failed++;
        continue;
      }
    }

    // 刷新已关注列表
    await _loadWxmpFollowedMps();

    if (mounted) {
      setState(() {
        _wxmpBatchFollowing = false;
        _wxmpBatchProgress = '';
      });

      final msg = StringBuffer();
      if (added > 0) msg.write('新关注 $added 个');
      if (skipped > 0) {
        if (msg.isNotEmpty) msg.write('，');
        msg.write('已关注跳过 $skipped 个');
      }
      if (failed > 0) {
        if (msg.isNotEmpty) msg.write('，');
        msg.write('搜索失败 $failed 个');
      }
      if (rateLimited) {
        if (msg.isNotEmpty) msg.write('，');
        msg.write('因频率限制提前结束');
      }

      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: Text(msg.isEmpty ? '已完成' : msg.toString()),
          severity: rateLimited
              ? InfoBarSeverity.warning
              : (failed > 0
                    ? InfoBarSeverity.warning
                    : InfoBarSeverity.success),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  /// 在已关注列表中查找推荐公众号对应的公众号平台记录。
  Map<String, String>? _findFollowedSspuAccount(SspuWechatAccount account) {
    for (final mp in _wxmpFollowedMps) {
      final name = mp['name'] ?? '';
      final alias = mp['alias'] ?? '';
      if (name == account.name ||
          name == account.wxAccount ||
          alias == account.wxAccount) {
        return mp;
      }
    }
    return null;
  }

  /// 构建 SSPU 微信矩阵卡片。
  Widget _buildSspuRecommendedAccounts(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('SSPU 微信矩阵', style: theme.typography.bodyStrong),
                const SizedBox(width: FluentSpacing.s),
                Text(
                  '来源：校园+微信矩阵·共 ${sspuWechatAccounts.length} 个',
                  style: theme.typography.caption,
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.s),
            Text('以下为上海第二工业大学官方认可的微信公众号', style: theme.typography.caption),
            const SizedBox(height: FluentSpacing.s),
            Text(
              '已关注的公众号可在此直接控制是否获取推文；未关注项仅展示状态。',
              style: theme.typography.caption,
            ),
            const SizedBox(height: FluentSpacing.s),
            Row(
              children: [
                FilledButton(
                  onPressed: !_wxmpAuthenticated || _wxmpBatchFollowing
                      ? null
                      : () => _batchFollowSspuWxmp(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_wxmpBatchFollowing)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          ),
                        ),
                      const Text('一键全部关注'),
                    ],
                  ),
                ),
                if (_wxmpBatchFollowing && _wxmpBatchProgress.isNotEmpty) ...[
                  const SizedBox(width: FluentSpacing.m),
                  Flexible(
                    child: Text(
                      _wxmpBatchProgress,
                      style: theme.typography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: FluentSpacing.m),
            Wrap(
              spacing: FluentSpacing.m,
              runSpacing: FluentSpacing.s,
              children: sspuWechatAccounts.map((account) {
                final followed = _findFollowedSspuAccount(account);
                final fakeid = followed?['fakeid'] ?? '';
                final enabled = fakeid.isEmpty
                    ? false
                    : (_wxmpMpNotificationEnabled[fakeid] ?? true);

                return SizedBox(
                  width: 340,
                  child: Container(
                    padding: const EdgeInsets.all(FluentSpacing.s),
                    decoration: BoxDecoration(
                      color: theme.inactiveColor.withValues(alpha: 0.035),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            account.iconUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              FluentIcons.chat,
                              size: 28,
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: FluentSpacing.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: theme.typography.bodyStrong,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account.wxAccount,
                                style: theme.typography.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: FluentSpacing.s),
                        if (!_wxmpAuthenticated)
                          Text(
                            '未认证',
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                          )
                        else if (followed == null)
                          Text(
                            '未关注',
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                          )
                        else
                          Tooltip(
                            message: '控制是否获取该公众号推文',
                            child: ToggleSwitch(
                              checked: enabled,
                              onChanged: (value) async {
                                await MessageStateService.instance
                                    .setMpNotificationEnabled(fakeid, value);
                                setState(() {
                                  _wxmpMpNotificationEnabled[fakeid] = value;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
