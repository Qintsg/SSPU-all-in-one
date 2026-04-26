/*
 * 密码相关对话框 — 设置、移除、修改密码
 * @Project : SSPU-all-in-one
 * @File : password_dialogs.dart
 * @Author : Qintsg
 * @Date : 2026-04-17
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../services/password_service.dart';

/// 显示设置密码对话框
/// 返回 true 表示密码设置成功
Future<bool> showSetPasswordDialog(BuildContext context) async {
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
    passwordController.dispose();
    confirmController.dispose();
    return true;
  }

  passwordController.dispose();
  confirmController.dispose();
  return false;
}

/// 显示移除密码的确认对话框
/// 返回 true 表示密码移除成功
Future<bool> showRemovePasswordDialog(BuildContext context) async {
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
    passwordController.dispose();
    return true;
  }

  passwordController.dispose();
  return false;
}

/// 显示当前密码确认对话框。
/// 返回 true 表示当前密码验证成功。
Future<bool> showConfirmCurrentPasswordDialog(
  BuildContext context, {
  String title = '确认当前密码',
  String message = '请输入当前密码以继续。',
  String confirmLabel = '确认',
}) async {
  final passwordController = TextEditingController();
  String? errorMessage;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (builderContext, setDialogState) {
          return ContentDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
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
                child: Text(confirmLabel),
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

  passwordController.dispose();
  return result == true;
}

/// 显示修改密码对话框
/// 返回 true 表示密码修改成功
Future<bool> showChangePasswordDialog(BuildContext context) async {
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

                  final isOldCorrect = await PasswordService.verifyPassword(
                    oldPassword,
                  );
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
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmController.dispose();
    return true;
  }

  oldPasswordController.dispose();
  newPasswordController.dispose();
  confirmController.dispose();
  return false;
}
