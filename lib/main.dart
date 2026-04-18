/*
 * 应用入口 — 初始化 FluentApp 并处理密码保护逻辑
 * @Project : SSPU-all-in-one
 * @File : main.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'app.dart';
import 'pages/lock_page.dart';
import 'services/password_service.dart';

/// 全局字体族名称
const String kFontFamily = 'MiSans';

void main() {
  // 确保 Flutter 引擎绑定初始化完成
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    _checkPasswordProtection();
  }

  /// 检查是否设置了密码保护
  /// 如果未设置密码，直接进入主界面；否则显示锁定页
  Future<void> _checkPasswordProtection() async {
    final hasPassword = await PasswordService.isPasswordSet();
    if (mounted) {
      setState(() {
        _isUnlocked = !hasPassword;
        _isInitialized = true;
      });
    }
  }

  /// 手动上锁，从设置页触发
  void _lockApp() {
    setState(() => _isUnlocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'SSPU All-in-One',
      // 浅色主题
      theme: FluentThemeData(
        accentColor: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: kFontFamily,
      ),
      // 深色主题
      darkTheme: FluentThemeData(
        accentColor: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: kFontFamily,
      ),
      // 跟随系统主题模式
      themeMode: ThemeMode.system,
      // 国际化支持
      localizationsDelegates: FluentLocalizations.localizationsDelegates,
      supportedLocales: FluentLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: _buildHome(),
    );
  }

  /// 根据初始化和密码验证状态构建首屏
  Widget _buildHome() {
    // 初始化未完成时显示加载指示器
    if (!_isInitialized) {
      return const ScaffoldPage(
        content: Center(child: ProgressRing()),
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
