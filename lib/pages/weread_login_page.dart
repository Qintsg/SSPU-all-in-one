/*
 * 微信读书扫码登录页 — 内嵌 WebView 实现免手动粘贴 Cookie
 * 用户通过微信扫码完成登录后，自动提取浏览器 Cookie 并保存
 * @Project : SSPU-all-in-one
 * @File : weread_login_page.dart
 * @Author : Qintsg
 * @Date : 2026-07-21
 */

import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:webview_windows/webview_windows.dart';

import '../services/weread_auth_service.dart';
import '../theme/fluent_tokens.dart';

/// 微信读书 Web 版登录 URL
const String _wereadLoginUrl = 'https://weread.qq.com/#login';

/// 微信读书首页 URL 前缀（登录成功后跳转目标）
const String _wereadHomePrefix = 'https://weread.qq.com/web/shelf';

/// 微信读书扫码登录页面
/// 加载微信读书 Web 版登录页，用户扫码后自动提取 Cookie
class WereadLoginPage extends StatefulWidget {
  const WereadLoginPage({super.key});

  @override
  State<WereadLoginPage> createState() => _WereadLoginPageState();
}

class _WereadLoginPageState extends State<WereadLoginPage> {
  /// WebView 控制器
  final WebviewController _controller = WebviewController();

  /// 各 stream 订阅
  final List<StreamSubscription> _subscriptions = [];

  /// WebView 是否初始化完成
  bool _isReady = false;

  /// 初始化是否失败
  bool _initFailed = false;

  /// 当前页面标题
  String _title = '微信读书登录';

  /// 是否正在提取 Cookie
  bool _extracting = false;

  /// Cookie 提取结果
  _CookieResult? _result;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// 初始化 WebView 并加载登录页
  /// 监听 URL 变化以检测登录成功
  Future<void> _initWebView() async {
    try {
      await _controller.initialize();

      // 监听标题变化
      _subscriptions.add(
        _controller.title.listen((newTitle) {
          if (mounted && newTitle.isNotEmpty) {
            setState(() => _title = newTitle);
          }
        }),
      );

      // 监听 URL 变化 — 登录成功后会跳转到书架页
      _subscriptions.add(
        _controller.url.listen((newUrl) {
          if (mounted) {
            // 检测是否已跳转到登录后页面
            _checkLoginSuccess(newUrl);
          }
        }),
      );

      await _controller.loadUrl(_wereadLoginUrl);

      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _initFailed = true);
      }
    }
  }

  /// 检测 URL 变化判断登录是否成功
  /// 微信读书登录成功后会从 #login 跳转到 /web/shelf 等页面
  void _checkLoginSuccess(String url) {
    // 避免重复提取
    if (_extracting || _result != null) return;

    // 判断是否已离开登录页（URL 不再包含 #login 且非空白页）
    final isLoggedIn = url.startsWith(_wereadHomePrefix) ||
        (url.startsWith('https://weread.qq.com/') &&
            !url.contains('#login') &&
            url != 'https://weread.qq.com/' &&
            url != 'https://weread.qq.com');

    if (isLoggedIn) {
      _extractCookies();
    }
  }

  /// 最大重试次数（每次间隔递增，覆盖 Cookie 延迟写入场景）
  static const int _maxRetries = 6;

  /// 通过 executeScript 提取 document.cookie 并保存
  /// wr_skey/wr_vid 在微信读书中非 HttpOnly，可通过 JS 获取
  /// 采用多次重试策略应对 Cookie 延迟写入
  Future<void> _extractCookies() async {
    if (_extracting) return;
    setState(() => _extracting = true);

    try {
      String? lastCookie;

      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        // 递增等待：1s, 2s, 3s, 4s, 5s, 6s — 总计最多 21s
        await Future.delayed(Duration(seconds: attempt));
        if (!mounted) return;

        // 执行 JS 获取 document.cookie
        final raw = await _controller.executeScript('document.cookie');
        final cleaned = _cleanJsResult(raw ?? '');
        lastCookie = cleaned;

        // 检查关键字段是否已出现
        if (cleaned.contains('wr_skey') && cleaned.contains('wr_vid')) {
          // 关键字段就绪，尝试保存
          final saved = await WereadAuthService.instance.saveCookies(cleaned);
          if (saved && mounted) {
            setState(() {
              _extracting = false;
              _result = _CookieResult(
                success: true,
                message: 'Cookie 提取并保存成功！',
              );
            });
            return;
          }
        }
      }

      // 所有重试均未获取到完整 Cookie
      if (mounted) {
        // 诊断信息：列出实际获取到的 Cookie 键
        final keys = (lastCookie ?? '')
            .split(';')
            .map((p) => p.trim().split('=').first)
            .where((k) => k.isNotEmpty)
            .toList();
        final keyInfo = keys.isEmpty ? '无' : keys.join(', ');
        setState(() {
          _extracting = false;
          _result = _CookieResult(
            success: false,
            message: '未获取到 wr_skey/wr_vid（已获取字段：$keyInfo）。'
                '请确认已完成微信扫码并等待页面跳转到书架',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _extracting = false;
          _result = _CookieResult(
            success: false,
            message: '提取失败：$error',
          );
        });
      }
    }
  }

  /// 清理 executeScript 返回的 JS 字符串
  /// WebView2 的 executeScript 返回值可能被 JSON 编码（带外层引号）
  String _cleanJsResult(String raw) {
    var result = raw.trim();
    // 移除外层 JSON 引号
    if (result.startsWith('"') && result.endsWith('"')) {
      result = result.substring(1, result.length - 1);
    }
    // 反转义
    result = result
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\/', '/');
    return result;
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaffoldPage(
      header: PageHeader(
        title: Text(_title),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 显示提取状态
            if (_extracting)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('正在提取 Cookie...'),
                  ],
                ),
              ),
            // Cookie 提取结果提示
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _result!.success
                          ? FluentIcons.check_mark
                          : FluentIcons.warning,
                      size: 16,
                      color: _result!.success
                          ? (isDark
                              ? FluentDarkColors.statusSuccess
                              : FluentLightColors.statusSuccess)
                          : (isDark
                              ? FluentDarkColors.statusError
                              : FluentLightColors.statusError),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _result!.success ? '登录成功' : '提取失败',
                      style: theme.typography.body,
                    ),
                  ],
                ),
              ),
            // 手动提取按钮（登录后未自动成功时备用，失败后也可重试）
            if (_isReady && !_extracting)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Button(
                  onPressed: () {
                    // 重置结果以允许重新提取
                    setState(() => _result = null);
                    _extractCookies();
                  },
                  child: Text(_result == null ? '手动提取 Cookie' : '重试提取'),
                ),
              ),
            // 返回按钮
            Button(
              onPressed: () => Navigator.of(context).pop(_result?.success ?? false),
              child: Text(_result?.success == true ? '完成' : '返回'),
            ),
          ],
        ),
      ),
      content: _buildContent(context),
    );
  }

  /// 构建主体内容
  Widget _buildContent(BuildContext context) {
    final theme = FluentTheme.of(context);

    // 初始化失败
    if (_initFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.warning, size: 48, color: theme.inactiveColor),
            const SizedBox(height: 12),
            Text('WebView 初始化失败', style: theme.typography.bodyStrong),
            const SizedBox(height: 8),
            Text('请确保系统已安装 Microsoft Edge WebView2 运行时',
                style: theme.typography.caption),
          ],
        ),
      );
    }

    // 加载中
    if (!_isReady) {
      return const Center(child: ProgressRing());
    }

    // WebView 主体 + 底部提示
    return Column(
      children: [
        // 提取成功后的结果横幅
        if (_result != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: FluentSpacing.l,
              vertical: FluentSpacing.s,
            ),
            color: _result!.success
                ? FluentLightColors.statusSuccess.withValues(alpha: 0.12)
                : FluentLightColors.statusError.withValues(alpha: 0.12),
            child: Text(
              _result!.message,
              style: theme.typography.body?.copyWith(
                color: _result!.success
                    ? FluentLightColors.statusSuccess
                    : FluentLightColors.statusError,
              ),
            ),
          ),
        // WebView 区域
        Expanded(
          child: Webview(_controller),
        ),
        // 底部操作提示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FluentSpacing.m),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
          ),
          child: Text(
            '请使用微信扫描页面中的二维码完成登录，登录成功后将自动提取 Cookie',
            style: theme.typography.caption,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Cookie 提取结果
class _CookieResult {
  /// 是否成功
  final bool success;

  /// 结果描述
  final String message;

  const _CookieResult({required this.success, required this.message});
}
