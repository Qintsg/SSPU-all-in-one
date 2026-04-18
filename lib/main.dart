/*
 * 应用入口 — 初始化 FluentApp 并处理 EULA 和密码保护逻辑
 * @Project : SSPU-all-in-one
 * @File : main.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'app.dart';
import 'pages/lock_page.dart';
import 'pages/agreement_page.dart';
import 'services/password_service.dart';
import 'services/storage_service.dart';

/// 全局字体族名称
const String kFontFamily = 'MiSans';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const SSPUApp());
}

/// 应用根 Widget
/// 配置 Fluent 主题、暗色模式支持、国际化代理
class SSPUApp extends StatefulWidget {
  const SSPUApp({super.key});

  @override
  State<SSPUApp> createState() => _SSPUAppState();
}

class _SSPUAppState extends State<SSPUApp> {
  /// 是否已通过密码验证（或无需密码）
  bool _isUnlocked = false;

  /// 初始化检查是否已完成
  bool _isInitialized = false;

  /// 是否已接受 EULA
  bool _eulaAccepted = false;

  @override
  void initState() {
    super.initState();
    _initApp();
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

  /// 显示首次启动的 EULA 弹窗
  void _showEulaDialog(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return ContentDialog(
            title: const Text('使用协议'),
            content: SizedBox(
              width: 500,
              height: 400,
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
                  exit(0);
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
        if (accepted == true) {
          await StorageService.acceptEula();
          if (mounted) {
            setState(() => _eulaAccepted = true);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'SSPU All-in-One',
      theme: FluentThemeData(
        accentColor: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: kFontFamily,
      ),
      darkTheme: FluentThemeData(
        accentColor: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: kFontFamily,
      ),
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
      return const ScaffoldPage(
        content: Center(child: ProgressRing()),
      );
    }

    // 未接受 EULA 时显示空白页并弹出协议对话框
    if (!_eulaAccepted) {
      return Builder(
        builder: (context) {
          _showEulaDialog(context);
          return const ScaffoldPage(
            content: Center(child: ProgressRing()),
          );
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
