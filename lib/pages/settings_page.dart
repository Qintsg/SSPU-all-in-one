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
import 'package:window_manager/window_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/channel_config.dart';
import '../services/password_service.dart';
import '../services/storage_service.dart';
import '../services/message_state_service.dart';
import '../widgets/password_dialogs.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/channel_list_section.dart';
import '../services/weread_auth_service.dart';
import '../services/weread_webview_service.dart';
import '../services/wechat_article_service.dart';
import '../services/wxmp_auth_service.dart';
import '../services/wxmp_article_service.dart';
import '../models/sspu_wechat_accounts.dart';
import '../theme/fluent_tokens.dart';
import '../utils/webview_env.dart';
import 'weread_login_page.dart';
import 'wxmp_login_page.dart';

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
  /// 0=常规设置 1=安全设置 2=职能部门 3=教学单位 4=微信推文
  int _selectedTab = 0;

  /// 消息状态服务引用
  final MessageStateService _messageState = MessageStateService.instance;

  /// 微信读书认证服务引用
  final WereadAuthService _wereadAuth = WereadAuthService.instance;

  /// 微信文章采集服务引用
  final WechatArticleService _wechatService = WechatArticleService.instance;

  /// 微信读书 Cookie 是否已配置
  bool _wereadAuthenticated = false;

  /// 是否正在检查微信读书认证
  bool _wereadChecking = false;

  /// 已关注的公众号列表
  List<Map<String, String>> _followedMps = [];

  /// 单个公众号通知开关状态缓存（key = bookId）
  Map<String, bool> _mpNotificationEnabled = {};

  /// 当前选择的获取方式 ('weread' 或 'wxmp')
  String _fetchMethod = 'weread';

  /// 公众号平台认证服务引用
  final WxmpAuthService _wxmpAuth = WxmpAuthService.instance;

  /// 公众号平台文章服务引用
  final WxmpArticleService _wxmpService = WxmpArticleService.instance;

  /// 公众号平台是否已认证
  bool _wxmpAuthenticated = false;

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
    final notifEnabled = await _messageState.isNotificationEnabled();
    final dndOn = await _messageState.isDndEnabled();
    final dndSH = await _messageState.getDndStartHour();
    final dndSM = await _messageState.getDndStartMinute();
    final dndEH = await _messageState.getDndEndHour();
    final dndEM = await _messageState.getDndEndMinute();
    // 检查微信读书认证状态
    final wereadHasCookie = await _wereadAuth.hasCookies();
    // Windows 上避免在设置页加载阶段抢跑创建 HeadlessInAppWebView。
    // 该初始化改为真正按需触发：
    // - 微信读书 API 请求时由 WereadApiService.ensureInitialized() 拉起
    // - 手动配置 Cookie 后由 reinitialize() 拉起
    // - 校验/刷新在无控制器时回退到 Dio 验证
    // 这样可避免与用户主动打开的可见 WebView 并发创建，降低
    // flutter_inappwebview_windows 在部分机器上的 RPC_E_DISCONNECTED 风险。
    // 加载获取方式偏好和公众号平台认证状态
    final method = await WechatArticleService.getFetchMethod();
    final wxmpHasAuth = await _wxmpAuth.hasAuth();
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
        _wereadAuthenticated = wereadHasCookie;
        _fetchMethod = method;
        _wxmpAuthenticated = wxmpHasAuth;
        _isLoading = false;
      });
    }
  }

  /// 显示操作成功的提示条
  void _showSuccessBar(String message) {
    displayInfoBar(
      context,
      builder: (infoBarContext, close) =>
          InfoBar(title: Text(message), severity: InfoBarSeverity.success),
    );
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

  /// 微信栏目设置内容 — 方式选择、认证、公众号列表、渠道开关
  Widget _buildWechatSection(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('微信', style: theme.typography.subtitle),
        const SizedBox(height: FluentSpacing.l),

        // 获取方式选择卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('获取方式', style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.xs),
                Text(
                  '选择微信公众号推文的获取来源（两种方式二选一）',
                  style: theme.typography.caption,
                ),
                const SizedBox(height: FluentSpacing.m),
                RadioGroup<String>(
                  groupValue: _fetchMethod,
                  onChanged: (value) async {
                    if (value == null) return;
                    await WechatArticleService.setFetchMethod(value);
                    setState(() => _fetchMethod = value);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioButton<String>(
                        value: 'weread',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('方式一：微信读书',
                                style: theme.typography.body),
                            Text('通过微信读书 Web API 获取公众号推文',
                                style: theme.typography.caption),
                          ],
                        ),
                      ),
                      const SizedBox(height: FluentSpacing.s),
                      RadioButton<String>(
                        value: 'wxmp',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('方式二：公众号平台',
                                style: theme.typography.body),
                            Text('通过 mp.weixin.qq.com API 获取（需有公众号）',
                                style: theme.typography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.l),

        // 根据选择的方式显示不同认证和管理 UI
        if (_fetchMethod == 'weread') ..._buildWereadAuthUI(context),
        if (_fetchMethod == 'wxmp') ..._buildWxmpAuthUI(context),

        // 渠道开关（两种方式共享）
        ChannelListSection(title: '微信渠道', channels: wechatChannels),
        const SizedBox(height: FluentSpacing.l),

        // SSPU 推荐公众号列表（两种方式共享）
        _buildSspuRecommendedAccounts(context),
      ],
    );
  }

  /// 方式一：微信读书认证区域
  List<Widget> _buildWereadAuthUI(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return [
      // 使用指引
      Expander(
        header: const Text('使用指引：微信读书方式'),
        icon: const Icon(FluentIcons.help, size: 16),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('适用人群', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 只是想尽快把微信公众号文章接进应用，不想额外注册公众号账号', style: theme.typography.body),
            Text('• 平时已经在用微信读书阅读公众号文集，或者愿意先把公众号加入微信读书书架', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('前置条件', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 已安装并登录微信读书（通常直接用微信登录即可）', style: theme.typography.body),
            Text('• 至少有一个目标公众号已经进入微信读书，并被你加入书架', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('如何把公众号加入微信读书', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('常见做法 A：在微信里打开目标公众号任意文章，尝试使用右上角菜单中的“在微信读书中阅读”；跳转到微信读书后，将该公众号文集/文章加入书架。', style: theme.typography.body),
            Text('常见做法 B：直接打开微信读书 App，在“书城”或顶部搜索框中搜索公众号名称；进入公众号文集后点击“加入书架”。', style: theme.typography.body),
            Text('若你当前微信/微信读书版本界面名称略有不同，以“公众号 / 文集 / 加入书架”为准。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('在本应用中的配置步骤', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('1. 先在微信读书中完成公众号关注/加入书架。', style: theme.typography.body),
            Text('2. 回到本应用，进入「设置 → 微信 → 方式一：微信读书」。', style: theme.typography.body),
            Text('3. 点击下方「扫码登录」，在弹出的 WebView 中完成微信读书登录。', style: theme.typography.body),
            Text('4. 登录成功后，点击「从书架同步公众号」，把微信读书书架中的公众号导入到本应用。', style: theme.typography.body),
            Text('5. 确认下方「已关注公众号」列表中已经出现目标公众号。', style: theme.typography.body),
            Text('6. 最后回到信息中心刷新微信公众号文章。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('失败排查', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 扫码成功但同步结果为 0：通常说明你在微信里关注了公众号，但还没有把它加入微信读书书架。', style: theme.typography.body),
            Text('• 只有部分公众号能同步：微信读书的公众号覆盖并不一定完整，部分号可能在微信里有、在微信读书里没有。', style: theme.typography.body),
            Text('• 登录后仍提示 Cookie 失效：重新扫码一次，或者使用「刷新 Cookie / 手动配置 Cookie」重试。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('是否推荐使用', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 对大多数普通用户，我默认更推荐这一方式：门槛低、无需自己注册公众号。', style: theme.typography.body),
            Text('• 如果你的目标公众号很多，且微信读书里搜不到，才建议切到下方“公众号平台方式”。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('FAQ', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：我在微信里已经关注公众号了，为什么应用里还是没有？', style: theme.typography.bodyStrong),
            Text('A：因为本方式依赖的是“微信读书书架”，不是微信通讯录里的公众号关注状态。你需要把公众号文章导入微信读书，并在微信读书里加入书架。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：为什么推荐列表里的公众号没有一键全部关注？', style: theme.typography.bodyStrong),
            Text('A：微信读书方式的关注入口在微信读书内部，本应用只能负责“同步书架”，不能直接代替微信读书完成关注动作。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：什么时候应该切换到公众号平台方式？', style: theme.typography.bodyStrong),
            Text('A：当你需要搜索更完整的公众号库，或者希望直接在本应用里一键关注推荐公众号时，可以考虑切换。', style: theme.typography.body),
          ],
        ),
      ),
      const SizedBox(height: FluentSpacing.l),

      // 微信读书 Cookie 配置卡片
      Card(
        child: Padding(
          padding: const EdgeInsets.all(FluentSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('微信读书认证', style: theme.typography.bodyStrong),
              const SizedBox(height: FluentSpacing.xs),
              Text(
                '通过微信读书 Web 版 Cookie 获取已关注的公众号推文',
                style: theme.typography.caption,
              ),
              const SizedBox(height: FluentSpacing.m),

              // 认证状态指示
              Row(
                children: [
                  Icon(
                    _wereadAuthenticated
                        ? FluentIcons.check_mark
                        : FluentIcons.warning,
                    size: 16,
                    color: _wereadAuthenticated
                        ? (isDark
                              ? FluentDarkColors.statusSuccess
                              : FluentLightColors.statusSuccess)
                        : (isDark
                              ? FluentDarkColors.statusWarning
                              : FluentLightColors.statusWarning),
                  ),
                  const SizedBox(width: FluentSpacing.s),
                  Text(
                    _wereadAuthenticated ? 'Cookie 已配置' : 'Cookie 未配置',
                    style: theme.typography.body,
                  ),
                  if (_wereadChecking) ...[
                    const SizedBox(width: FluentSpacing.m),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                    const SizedBox(
                      width: FluentSpacing.xs + FluentSpacing.xxs,
                    ),
                    Text('校验中...', style: theme.typography.caption),
                  ],
                ],
              ),
              const SizedBox(height: FluentSpacing.m),

              // 操作按钮行
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _openWereadLogin(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.q_r_code, size: 14),
                        SizedBox(width: 6),
                        Text('扫码登录'),
                      ],
                    ),
                  ),
                  Button(
                    onPressed: () => _showCookieInputDialog(context),
                    child: const Text('手动配置 Cookie'),
                  ),
                  if (_wereadAuthenticated) ...[
                    Button(
                      onPressed: _wereadChecking ? null : _checkWereadAuth,
                      child: const Text('校验有效性'),
                    ),
                    Button(
                      onPressed: _wereadChecking
                          ? null
                          : _refreshWereadCookie,
                      child: const Text('刷新 Cookie'),
                    ),
                    Button(
                      onPressed: _clearWereadCookie,
                      child: const Text('清除 Cookie'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: FluentSpacing.l),

      // 已关注公众号列表
      if (_wereadAuthenticated && _followedMps.isNotEmpty) ...[
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
                      onPressed: _loadFollowedMps,
                      child: const Text('刷新列表'),
                    ),
                  ],
                ),
                const SizedBox(height: FluentSpacing.s),
                ...(_followedMps.map(
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
                          child: Text(
                            mp['name'] ?? '',
                            style: theme.typography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((mp['intro'] ?? '').isNotEmpty)
                          Flexible(
                            child: Text(
                              mp['intro'] ?? '',
                              style: theme.typography.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(width: FluentSpacing.s),
                        Tooltip(
                          message: '控制是否接收该公众号的推文通知',
                          child: ToggleSwitch(
                            checked:
                                _mpNotificationEnabled[mp['bookId']] ?? true,
                            onChanged: (value) async {
                              final bookId = mp['bookId'] ?? '';
                              if (bookId.isEmpty) return;
                              await MessageStateService.instance
                                  .setMpNotificationEnabled(bookId, value);
                              setState(() {
                                _mpNotificationEnabled[bookId] = value;
                              });
                            },
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

  /// 方式二：公众号平台认证区域
  List<Widget> _buildWxmpAuthUI(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return [
      // 使用指引
      Expander(
        header: const Text('使用指引：公众号平台方式'),
        icon: const Icon(FluentIcons.help, size: 16),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('适用人群', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 想直接在本应用里搜索任意公众号、批量关注推荐公众号，而不依赖微信读书书架。', style: theme.typography.body),
            Text('• 能接受先注册一个微信公众号账号，再回来用该账号登录公众平台。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('前置条件', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 需要一个可以登录微信公众平台的公众号账号。', style: theme.typography.body),
            Text('• 注册时通常需要：一个未用于公众号注册的邮箱、一个实名认证微信作为管理员微信，以及按平台页面要求填写的主体信息。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('如何注册微信公众平台账号', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('根据微信公众平台首页和微信开放社区现有流程说明：先在电脑浏览器打开 mp.weixin.qq.com，点击右上角“立即注册”。', style: theme.typography.body),
            Text('常见顺序为：1）选择账号类型；2）填写并激活邮箱；3）完成信息登记；4）填写公众号名称、简介和运营地区。', style: theme.typography.body),
            Text('个人使用场景通常会先看“公众号 / 订阅号”路线；具体账号能力与限制请以注册页当时显示的官方说明为准。', style: theme.typography.body),
            Text('如果扫码登录时页面提示“该微信还未注册公众平台账号”，说明当前微信下没有可登录的公众号，需要先完成上面的注册流程。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('在本应用中的配置步骤', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('1. 先确保你已经能在浏览器正常进入 mp.weixin.qq.com 后台。', style: theme.typography.body),
            Text('2. 回到本应用，进入「设置 → 微信 → 方式二：公众号平台」。', style: theme.typography.body),
            Text('3. 点击下方「扫码登录」，使用管理员微信完成登录。', style: theme.typography.body),
            Text('4. 登录成功后，应用会自动提取 Cookie 和 Token，状态显示为「已认证」。', style: theme.typography.body),
            Text('5. 之后你可以在下方搜索公众号，或直接使用 SSPU 推荐列表中的「一键全部关注」。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('搜索与关注方式', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 手动方式：在「搜索公众号」输入名称，确认搜索结果后点击「关注」。', style: theme.typography.body),
            Text('• 批量方式：对 SSPU 推荐公众号可直接点击「一键全部关注」，系统会逐个搜索并自动跳过已关注项。', style: theme.typography.body),
            Text('• 已关注列表中的通知开关只影响本应用是否抓取/提醒，不会改动公众平台后台本身。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('失败排查', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 扫码页提示没有可登录账号：先去官网完成注册，再回来扫码。', style: theme.typography.body),
            Text('• 注册后仍无法登录：确认账号信息已经填写完成，并且你能在普通浏览器中正常进入后台首页。', style: theme.typography.body),
            Text('• 搜索或批量关注中断：通常是会话过期或接口频率限制，重新扫码后稍等一会儿再试。', style: theme.typography.body),
            Text('• 搜到的第一个结果不对：可以手动搜索后确认名称/微信号，再点击关注，而不是完全依赖批量流程。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('是否推荐使用', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('• 如果你追求“搜索更全、应用内直接关注”，这一方式更强。', style: theme.typography.body),
            Text('• 如果你只是想快速接入少量公众号，通常还是微信读书方式更省事。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.m),
            Text('FAQ', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：个人一定要完成额外认证才能用吗？', style: theme.typography.bodyStrong),
            Text('A：本应用需要的是“你能正常登录公众平台后台并拿到登录态”。是否还需要做后续认证，取决于你自己的运营需求和平台当时规则。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：为什么这一方式要先注册公众号？', style: theme.typography.bodyStrong),
            Text('A：因为应用调用的是公众平台后台接口，必须先有一个能登录后台的账号作为入口。', style: theme.typography.body),
            const SizedBox(height: FluentSpacing.xs),
            Text('Q：为什么它比微信读书方式复杂？', style: theme.typography.bodyStrong),
            Text('A：门槛更高，但换来的是更强的搜索和批量关注能力；两种方式各有侧重。', style: theme.typography.body),
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
                Text(
                  '搜索并关注公众号，关注后可自动获取推文',
                  style: theme.typography.caption,
                ),
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
                                _wxmpMpNotificationEnabled[mp['fakeid']] ?? true,
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
                            onPressed: () => _unfollowWxmpMp(mp['fakeid'] ?? ''),
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

  /// 校验微信读书 Cookie 有效性
  Future<void> _checkWereadAuth() async {
    setState(() => _wereadChecking = true);
    try {
      final valid = await _wereadAuth.validateCookie(
        webViewController: WereadWebViewService.instance.controller,
      );
      if (mounted) {
        setState(() {
          _wereadAuthenticated = valid;
          _wereadChecking = false;
        });
        // 有效时加载公众号列表
        if (valid) {
          await _loadFollowedMps();
          if (mounted) {
            displayInfoBar(
              context,
              builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Cookie 有效'),
                  severity: InfoBarSeverity.success,
                  action: IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: close,
                  ),
                );
              },
            );
          }
        } else {
          if (mounted) {
            displayInfoBar(
              context,
              builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Cookie 已失效，请重新配置'),
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
    } catch (_) {
      if (mounted) setState(() => _wereadChecking = false);
    }
  }

  /// 刷新微信读书 Cookie
  Future<void> _refreshWereadCookie() async {
    setState(() => _wereadChecking = true);
    try {
      final success = await _wereadAuth.renewCookie(
        webViewController: WereadWebViewService.instance.controller,
      );
      if (mounted) {
        setState(() => _wereadChecking = false);
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: Text(success ? 'Cookie 刷新成功' : 'Cookie 刷新失败'),
              severity: success
                  ? InfoBarSeverity.success
                  : InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _wereadChecking = false);
    }
  }

  /// 清除微信读书 Cookie
  Future<void> _clearWereadCookie() async {
    await _wereadAuth.clearCookies();
    if (mounted) {
      setState(() {
        _wereadAuthenticated = false;
        _followedMps = [];
      });
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('Cookie 已清除'),
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
      await windowManager.destroy();
    }
  }

  /// 弹出 Cookie 输入对话框
  Future<void> _showCookieInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('配置微信读书 Cookie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请从浏览器开发者工具中复制 weread.qq.com 的 Cookie\n'
              '必须包含 wr_skey 和 wr_vid 字段',
              style: FluentTheme.of(ctx).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            TextBox(
              controller: controller,
              placeholder: 'wr_skey=xxx; wr_vid=xxx; RK=xxx; ...',
              maxLines: 5,
              minLines: 3,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final success = await _wereadAuth.saveCookies(controller.text);
      if (mounted) {
        if (success) {
          setState(() => _wereadAuthenticated = true);
          // Cookie 变更后重新初始化 WebView 以注入新 Cookie
          await WereadWebViewService.instance.reinitialize();
          // 保存成功后自动加载公众号列表
          await _loadFollowedMps();
          if (mounted) {
            displayInfoBar(
              context,
              builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Cookie 保存成功'),
                  severity: InfoBarSeverity.success,
                  action: IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: close,
                  ),
                );
              },
            );
          }
        } else {
          if (mounted) {
            displayInfoBar(
              context,
              builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Cookie 格式无效，缺少 wr_skey 或 wr_vid'),
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
    }
    controller.dispose();
  }

  /// 加载已关注的公众号列表及其通知开关状态
  Future<void> _loadFollowedMps() async {
    final mps = await _wechatService.getFollowedMpList();
    // 加载每个公众号的通知开关状态
    final stateService = MessageStateService.instance;
    final enabledMap = <String, bool>{};
    for (final mp in mps) {
      final bookId = mp['bookId'] ?? '';
      if (bookId.isNotEmpty) {
        enabledMap[bookId] = await stateService.isMpNotificationEnabled(bookId);
      }
    }
    if (mounted) {
      setState(() {
        _followedMps = mps;
        _mpNotificationEnabled = enabledMap;
      });
    }
  }

  /// 打开微信读书扫码登录页
  /// 登录成功后自动提取 Cookie 并保存
  Future<void> _openWereadLogin(BuildContext context) async {
    final success = await Navigator.of(
      context,
    ).push<bool>(
      FluentPageRoute(
        builder: (_) => WereadLoginPage(
          webViewEnvironment: globalWebViewEnvironment,
        ),
      ),
    );

    // 登录成功后刷新状态
    if (success == true && mounted) {
      setState(() => _wereadAuthenticated = true);
      await _loadFollowedMps();
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('扫码登录成功，Cookie 已保存'),
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

  /// 打开公众号平台扫码登录页
  Future<void> _openWxmpLogin(BuildContext context) async {
    final success = await Navigator.of(
      context,
    ).push<bool>(
      FluentPageRoute(
        builder: (_) => WxmpLoginPage(
          webViewEnvironment: globalWebViewEnvironment,
        ),
      ),
    );

    if (success == true && mounted) {
      setState(() => _wxmpAuthenticated = true);
      await _loadWxmpFollowedMps();
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
              : (failed > 0 ? InfoBarSeverity.warning : InfoBarSeverity.success),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  /// 从微信读书书架同步公众号到本地关注列表
  /// 微信读书已下架搜索API，改用书架同步方式
  /// [context] 构建上下文
  Future<void> _syncMpsFromShelf(BuildContext context) async {
    // 显示加载状态
    if (context.mounted) {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('正在从书架同步公众号...'),
            severity: InfoBarSeverity.info,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    }

    final addedCount = await WechatArticleService.instance.syncFromShelf();

    if (!context.mounted) return;

    if (addedCount > 0) {
      await _loadFollowedMps();
      if (context.mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: Text('已从书架同步 $addedCount 个公众号'),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } else if (addedCount == 0) {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('书架中没有新的公众号，请先在微信读书App中添加公众号文章到书架'),
            severity: InfoBarSeverity.warning,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    } else {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return InfoBar(
            title: const Text('同步失败，请检查 Cookie 是否有效'),
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

  /// 构建 SSPU 推荐公众号卡片
  /// 展示校园+微信矩阵中的所有官方公众号
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
                Text('SSPU 推荐公众号', style: theme.typography.bodyStrong),
                const SizedBox(width: FluentSpacing.s),
                Text(
                  '来源：校园+微信矩阵·共 ${sspuWechatAccounts.length} 个',
                  style: theme.typography.caption,
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.s),
            Text(
              '以下为上海第二工业大学官方认可的微信公众号',
              style: theme.typography.caption,
            ),
            const SizedBox(height: FluentSpacing.s),
            // 根据当前获取方式显示不同的操作按钮
            if (_fetchMethod == 'weread') ...[              Text(
                '请先在微信读书 App 中将公众号文章添加到书架，再点击同步',
                style: theme.typography.caption,
              ),
              const SizedBox(height: FluentSpacing.s),
              FilledButton(
                onPressed: () => _syncMpsFromShelf(context),
                child: const Text('从书架同步公众号'),
              ),
            ],
            if (_fetchMethod == 'wxmp') ...[              Text(
                '点击下方按钮可自动搜索并关注全部推荐公众号（已关注的会自动跳过）',
                style: theme.typography.caption,
              ),
              const SizedBox(height: FluentSpacing.s),
              Row(
                children: [
                  FilledButton(
                    onPressed: _wxmpBatchFollowing
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
                  if (_wxmpBatchFollowing && _wxmpBatchProgress.isNotEmpty) ...[                    const SizedBox(width: FluentSpacing.m),
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
            ],
            const SizedBox(height: FluentSpacing.m),
            // 公众号网格列表（每行 3 个）
            Wrap(
              spacing: FluentSpacing.m,
              runSpacing: FluentSpacing.s,
              children: sspuWechatAccounts.map((account) {
                return SizedBox(
                  width: 240,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          FluentIcons.chat,
                          size: 14,
                          color: theme.accentColor,
                        ),
                        const SizedBox(width: FluentSpacing.xs),
                        Expanded(
                          child: Text(
                            account.name,
                            style: theme.typography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 微信读书已下架搜索关注，仅展示名称
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
