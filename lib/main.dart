/*
 * 应用入口 — 初始化 FluentApp 并处理 EULA、密码保护、窗口关闭与托盘逻辑
 * @Project : SSPU-all-in-one
 * @File : main.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'app.dart';
import 'pages/lock_page.dart';
import 'pages/agreement_page.dart';
import 'services/password_service.dart';
import 'services/storage_service.dart';
import 'services/tray_service.dart';
import 'services/notification_service.dart';
import 'services/auto_refresh_service.dart';
import 'utils/webview_env.dart';

/// 全局字体族名称
import 'theme/fluent_tokens.dart';

/// 字体族常量（已迁移至 FluentTokenTheme.fontFamily，保留兼容引用）
const String kFontFamily = FluentTokenTheme.fontFamily;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 平台：在 runApp() 前初始化 WebView2 环境
  // 必须在任何 WebView 实例创建前完成，否则会触发 RPC_E_DISCONNECTED (-2147417848)
  if (!kIsWeb && Platform.isWindows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    if (availableVersion != null) {
      // 使用 LOCALAPPDATA 下的专属目录，避免安装到只读路径时崩溃
      final localAppData =
          Platform.environment['LOCALAPPDATA'] ?? Platform.localeName;
      globalWebViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: '$localAppData\\sspu_all_in_one\\WebView2',
        ),
      );
    }
  }

  await StorageService.init();

  // 初始化窗口管理器，拦截默认关闭行为
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  // 初始化系统托盘图标与菜单
  await TrayService.instance.init();

  // 初始化通知服务和自动刷新服务
  await NotificationService.instance.init();
  await AutoRefreshService.instance.init();

  runApp(const SSPUApp());
}

/// 应用根 Widget
/// 配置 Fluent 主题、暗色模式支持、国际化代理
/// 同时监听窗口关闭事件和系统托盘交互
class SSPUApp extends StatefulWidget {
  const SSPUApp({super.key});

  @override
  State<SSPUApp> createState() => _SSPUAppState();
}

class _SSPUAppState extends State<SSPUApp> with WindowListener, TrayListener {
  /// 是否已通过密码验证（或无需密码）
  bool _isUnlocked = false;

  /// 初始化检查是否已完成
  bool _isInitialized = false;

  /// 是否已接受 EULA
  bool _eulaAccepted = false;

  /// 防止 EULA 弹窗重复弹出
  bool _eulaDialogShowing = false;

  /// FluentApp 内部导航器 key，用于在 WindowListener 回调中弹出对话框
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initApp();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  /// 初始化应用状态：先检查 EULA，再检查密码
  Future<void> _initApp() async {
    final eulaOk = await StorageService.isEulaAccepted();
    final hasPassword = await PasswordService.isPasswordSet();
    if (mounted) {
      setState(() {
        _eulaAccepted = eulaOk;
        _isUnlocked = !hasPassword;
        _isInitialized = true;
      });
    }
  }

  /// 手动上锁，从设置页触发
  void _lockApp() {
    setState(() => _isUnlocked = false);
  }

  // ==================== 窗口关闭拦截 ====================

  /// 窗口关闭事件回调
  /// 根据用户偏好执行：最小化到托盘 / 直接退出 / 弹窗询问
  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) return;

    final behavior = await StorageService.getCloseBehavior();
    switch (behavior) {
      case 'minimize':
        // 隐藏窗口，保留托盘图标后台运行
        await windowManager.hide();
        return;
      case 'exit':
        // 直接销毁窗口并退出
        await windowManager.destroy();
        return;
      default:
        // 每次询问用户
        _showCloseConfirmDialog();
    }
  }

  /// 显示关闭确认对话框，提供最小化/退出两个选项
  /// 勾选"以后都使用此选项"可持久化用户选择
  void _showCloseConfirmDialog() {
    final ctx = _navigatorKey.currentContext;
    // 若导航器上下文不可用（极端情况），直接退出
    if (ctx == null) {
      windowManager.destroy();
      return;
    }

    bool rememberChoice = false;

    showDialog(
      context: ctx,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return ContentDialog(
              title: const Text('关闭应用'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择点击关闭按钮时的操作：'),
                  const SizedBox(height: 12),
                  Checkbox(
                    checked: rememberChoice,
                    onChanged: (value) {
                      setDialogState(() => rememberChoice = value ?? false);
                    },
                    content: const Text('以后都使用此选项'),
                  ),
                ],
              ),
              actions: [
                Button(
                  child: const Text('最小化到托盘'),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    if (rememberChoice) {
                      await StorageService.setCloseBehavior('minimize');
                    }
                    await windowManager.hide();
                  },
                ),
                FilledButton(
                  child: const Text('退出应用'),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    if (rememberChoice) {
                      await StorageService.setCloseBehavior('exit');
                    }
                    await windowManager.destroy();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== 系统托盘交互 ====================

  /// 左键单击托盘图标：显示并聚焦主窗口
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  /// 右键单击托盘图标：弹出右键菜单
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// 托盘右键菜单项点击回调
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
        windowManager.focus();
        break;
      case 'exit_app':
        windowManager.destroy();
        break;
    }
  }

  // ==================== EULA 弹窗 ====================

  /// 显示首次启动的 EULA 弹窗（仅弹出一次）
  void _showEulaDialog(BuildContext context) {
    if (_eulaDialogShowing) return;
    _eulaDialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return ContentDialog(
            title: const Text('使用协议'),
            constraints: const BoxConstraints(maxWidth: 680),
            content: SizedBox(
              height: 420,
              child: SingleChildScrollView(
                child: SelectableText(
                  kAgreementText.trim(),
                  style: FluentTheme.of(dialogContext).typography.body,
                ),
              ),
            ),
            actions: [
              Button(
                child: const Text('不同意'),
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                  // 不同意 EULA 时销毁窗口退出
                  windowManager.destroy();
                },
              ),
              FilledButton(
                child: const Text('同意'),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
              ),
            ],
          );
        },
      ).then((accepted) async {
        _eulaDialogShowing = false;
        if (accepted == true) {
          await StorageService.acceptEula();
          if (mounted) {
            setState(() => _eulaAccepted = true);
          }
        }
      });
    });
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      navigatorKey: _navigatorKey,
      title: 'SSPU All-in-One',
      theme: FluentTokenTheme.light(),
      darkTheme: FluentTokenTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: FluentLocalizations.localizationsDelegates,
      supportedLocales: FluentLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: _buildHome(),
    );
  }

  /// 根据初始化、EULA 和密码验证状态构建首屏
  Widget _buildHome() {
    if (!_isInitialized) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    // 未接受 EULA 时显示空白页并弹出协议对话框
    if (!_eulaAccepted) {
      return Builder(
        builder: (context) {
          _showEulaDialog(context);
          return const ScaffoldPage(content: Center(child: ProgressRing()));
        },
      );
    }

    // 需要密码验证时显示锁定页
    if (!_isUnlocked) {
      return LockPage(
        onUnlocked: () {
          setState(() => _isUnlocked = true);
        },
      );
    }

    // 已解锁，进入主界面
    return AppShell(onLock: _lockApp);
  }
}
