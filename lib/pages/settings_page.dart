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
import '../services/weread_auth_service.dart';
import '../services/wechat_article_service.dart';

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
    // 检查微信读书认证状态
    final wereadHasCookie = await _wereadAuth.hasCookies();
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
        return _buildWechatSection(context);
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

  /// 微信栏目设置内容 — Cookie 配置、认证状态、公众号列表、渠道开关
  Widget _buildWechatSection(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('微信', style: theme.typography.subtitle),
        const SizedBox(height: 16),

        // 微信读书 Cookie 配置卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('微信读书认证', style: theme.typography.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  '通过微信读书 Web 版 Cookie 获取已关注的公众号推文',
                  style: theme.typography.caption,
                ),
                const SizedBox(height: 12),

                // 认证状态指示
                Row(
                  children: [
                    Icon(
                      _wereadAuthenticated
                          ? FluentIcons.check_mark
                          : FluentIcons.warning,
                      size: 16,
                      color: _wereadAuthenticated
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _wereadAuthenticated ? 'Cookie 已配置' : 'Cookie 未配置',
                      style: theme.typography.body,
                    ),
                    if (_wereadChecking) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                      Text('校验中...', style: theme.typography.caption),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // 操作按钮行
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Button(
                      onPressed: () => _showCookieInputDialog(context),
                      child: const Text('配置 Cookie'),
                    ),
                    if (_wereadAuthenticated) ...[
                      Button(
                        onPressed: _wereadChecking ? null : _checkWereadAuth,
                        child: const Text('校验有效性'),
                      ),
                      Button(
                        onPressed: _wereadChecking ? null : _refreshWereadCookie,
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
        const SizedBox(height: 16),

        // 已关注公众号列表
        if (_wereadAuthenticated && _followedMps.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                  const SizedBox(height: 8),
                  ...(_followedMps.map((mp) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(FluentIcons.chat, size: 16,
                            color: theme.accentColor),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                  ))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 渠道开关
        ChannelListSection(
          title: '微信渠道',
          channels: wechatChannels,
        ),
      ],
    );
  }

  /// 校验微信读书 Cookie 有效性
  Future<void> _checkWereadAuth() async {
    setState(() => _wereadChecking = true);
    try {
      final valid = await _wereadAuth.validateCookie();
      if (mounted) {
        setState(() {
          _wereadAuthenticated = valid;
          _wereadChecking = false;
        });
        // 有效时加载公众号列表
        if (valid) {
          await _loadFollowedMps();
          if (mounted) {
            displayInfoBar(context, builder: (ctx, close) {
              return InfoBar(
                title: const Text('Cookie 有效'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              );
            });
          }
        } else {
          if (mounted) {
            displayInfoBar(context, builder: (ctx, close) {
              return InfoBar(
                title: const Text('Cookie 已失效，请重新配置'),
                severity: InfoBarSeverity.error,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              );
            });
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
      final success = await _wereadAuth.renewCookie();
      if (mounted) {
        setState(() => _wereadChecking = false);
        displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: Text(success ? 'Cookie 刷新成功' : 'Cookie 刷新失败'),
            severity: success ? InfoBarSeverity.success : InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        });
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
      displayInfoBar(context, builder: (ctx, close) {
        return InfoBar(
          title: const Text('Cookie 已清除'),
          severity: InfoBarSeverity.info,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      });
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
            const SizedBox(height: 12),
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
          // 保存成功后自动加载公众号列表
          await _loadFollowedMps();
          if (mounted) {
            displayInfoBar(context, builder: (ctx, close) {
              return InfoBar(
                title: const Text('Cookie 保存成功'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              );
            });
          }
        } else {
          if (mounted) {
            displayInfoBar(context, builder: (ctx, close) {
              return InfoBar(
                title: const Text('Cookie 格式无效，缺少 wr_skey 或 wr_vid'),
                severity: InfoBarSeverity.error,
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
              );
            });
          }
        }
      }
    }
    controller.dispose();
  }

  /// 加载已关注的公众号列表
  Future<void> _loadFollowedMps() async {
    final mps = await _wechatService.getFollowedMpList();
    if (mounted) {
      setState(() => _followedMps = mps);
    }
  }
}
