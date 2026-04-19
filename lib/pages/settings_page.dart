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

  /// 消息状态服务引用
  final MessageStateService _messageState = MessageStateService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
    if (mounted) {
      setState(() {
        _isPasswordEnabled = isSet;
        _closeBehavior = behavior;
        _latestInfoEnabled = latestInfo;
        _noticeEnabled = notice;
        _wechatPublicEnabled = wechatPub;
        _wechatServiceEnabled = wechatSvc;
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

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('设置')),
      children: [
        // 密码保护设置卡片
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

        const SizedBox(height: 16),

        // 窗口行为设置卡片
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

        const SizedBox(height: 16),

        // 信息渠道设置卡片
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
              ],
            ),
          ),
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
