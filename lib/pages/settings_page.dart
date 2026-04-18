/*
 * 设置页 — 应用设置与密码保护管理
 * @Project : SSPU-all-in-one
 * @File : settings_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../services/password_service.dart';

/// 设置页面
/// 包含密码保护开关、密码设置/修改/移除功能
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 是否已设置密码保护
  bool _isPasswordEnabled = false;

  /// 是否正在加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPasswordState();
  }

  /// 从本地存储加载密码保护状态
  Future<void> _loadPasswordState() async {
    final isSet = await PasswordService.isPasswordSet();
    if (mounted) {
      setState(() {
        _isPasswordEnabled = isSet;
        _isLoading = false;
      });
    }
  }

  /// 显示设置密码对话框
  /// 要求用户输入密码并二次确认
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
                  // 错误提示
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
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                ),
                FilledButton(
                  child: const Text('确认'),
                  onPressed: () {
                    final password = passwordController.text;
                    final confirm = confirmController.text;

                    // 密码不能为空
                    if (password.isEmpty) {
                      setDialogState(() {
                        errorMessage = '密码不能为空';
                      });
                      return;
                    }

                    // 两次输入必须一致
                    if (password != confirm) {
                      setDialogState(() {
                        errorMessage = '两次输入的密码不一致';
                      });
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

    // 用户确认设置密码
    if (result == true) {
      await PasswordService.setPassword(passwordController.text);
      if (mounted) {
        setState(() => _isPasswordEnabled = true);
        _showSuccessBar('密码已设置');
      }
    }

    // 释放控制器资源
    passwordController.dispose();
    confirmController.dispose();
  }

  /// 显示移除密码的确认对话框
  /// 移除前需要验证当前密码
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
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
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
                      setDialogState(() {
                        errorMessage = '密码错误';
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    // 用户确认移除密码
    if (result == true) {
      await PasswordService.removePassword();
      if (mounted) {
        setState(() => _isPasswordEnabled = false);
        _showSuccessBar('密码保护已移除');
      }
    }

    passwordController.dispose();
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
    // 加载中状态
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
                          // 开启：设置密码
                          _showSetPasswordDialog();
                        } else {
                          // 关闭：验证后移除密码
                          _showRemovePasswordDialog();
                        }
                      },
                    ),
                  ],
                ),
                // 修改密码按钮（仅在已设置密码时显示）
                if (_isPasswordEnabled) ...[
                  const SizedBox(height: 12),
                  Button(
                    child: const Text('修改密码'),
                    onPressed: () => _showChangePasswordDialog(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 关于卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关于',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 12),
                Text(
                  'SSPU All-in-One v0.0.1-alpha',
                  style: FluentTheme.of(context).typography.body,
                ),
                const SizedBox(height: 4),
                Text(
                  '上海第二工业大学校园综合服务应用\n所有数据仅保留在本地，不上传至任何云端服务。',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示修改密码对话框
  /// 需要先验证旧密码，再设置新密码并二次确认
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
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                ),
                FilledButton(
                  child: const Text('确认修改'),
                  onPressed: () async {
                    final oldPassword = oldPasswordController.text;
                    final newPassword = newPasswordController.text;
                    final confirm = confirmController.text;

                    // 验证旧密码
                    final isOldCorrect =
                        await PasswordService.verifyPassword(oldPassword);
                    if (!isOldCorrect) {
                      setDialogState(() {
                        errorMessage = '当前密码错误';
                      });
                      return;
                    }

                    // 新密码不能为空
                    if (newPassword.isEmpty) {
                      setDialogState(() {
                        errorMessage = '新密码不能为空';
                      });
                      return;
                    }

                    // 二次确认
                    if (newPassword != confirm) {
                      setDialogState(() {
                        errorMessage = '两次输入的新密码不一致';
                      });
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

    // 用户确认修改
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
}
