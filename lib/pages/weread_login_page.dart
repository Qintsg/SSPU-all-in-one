/*
 * 微信读书扫码登录页 — 内嵌 WebView 实现免手动粘贴 Cookie
 * 使用 flutter_inappwebview 实现跨平台 Cookie 提取（含 HttpOnly）
 * @Project : SSPU-all-in-one
 * @File : weread_login_page.dart
 * @Author : Qintsg
 * @Date : 2026-07-21
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/weread_auth_service.dart';
import '../services/weread_webview_service.dart';
import '../theme/fluent_tokens.dart';

/// 微信读书 Web 版登录 URL
const String _wereadLoginUrl = 'https://weread.qq.com/#login';

/// 微信读书首页 URL 前缀（登录成功后跳转目标）
const String _wereadHomePrefix = 'https://weread.qq.com/web/shelf';

/// 微信读书扫码登录页面
/// 加载微信读书 Web 版登录页，用户扫码后通过原生 CookieManager 提取 Cookie
class WereadLoginPage extends StatefulWidget {
  /// Windows 平台需要的 WebViewEnvironment（由外部传入或内部创建）
  final WebViewEnvironment? webViewEnvironment;

  const WereadLoginPage({super.key, this.webViewEnvironment});

  @override
  State<WereadLoginPage> createState() => _WereadLoginPageState();
}

class _WereadLoginPageState extends State<WereadLoginPage> {
  /// InAppWebView 控制器
  InAppWebViewController? _controller;

  /// WebView 是否已创建
  bool _isReady = false;

  /// 初始化是否失败
  bool _initFailed = false;

  /// 当前页面标题
  String _title = '微信读书登录';

  /// 是否正在提取 Cookie
  bool _extracting = false;

  /// Cookie 提取结果
  _CookieResult? _result;

  /// 最大重试次数（每次间隔递增，覆盖 Cookie 延迟写入场景）
  static const int _maxRetries = 5;

  /// 检测 URL 变化判断登录是否成功
  /// 微信读书登录成功后会从 #login 跳转到 /web/shelf 等页面
  void _checkLoginSuccess(String url) {
    // 避免重复提取
    if (_extracting || _result != null) return;

    // 判断是否已离开登录页（URL 不再包含 #login 且非空白页）
    final isLoggedIn =
        url.startsWith(_wereadHomePrefix) ||
        (url.startsWith('https://weread.qq.com/') &&
            !url.contains('#login') &&
            url != 'https://weread.qq.com/' &&
            url != 'https://weread.qq.com');

    if (isLoggedIn) {
      _extractCookies();
    }
  }

  /// 通过原生 CookieManager 提取所有 Cookie（含 HttpOnly）并保存
  /// flutter_inappwebview 的 CookieManager 使用平台原生 API：
  /// - Windows: ICoreWebView2CookieManager
  /// - Android: android.webkit.CookieManager
  /// - iOS/macOS: WKHTTPCookieStore
  /// 均可获取 HttpOnly cookie（如 wr_skey、wr_vid）
  Future<void> _extractCookies() async {
    if (_extracting) return;
    setState(() => _extracting = true);

    try {
      final cookieManager = CookieManager.instance();
      // 同时获取主域和 API 子域的 Cookie，确保覆盖所有鉴权字段
      final urls = [
        WebUri('https://weread.qq.com/'),
        WebUri('https://i.weread.qq.com/'),
      ];
      String? lastCookieStr;

      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        // 递增等待：1s, 2s, 3s... 确保 Cookie 完全写入
        await Future.delayed(Duration(seconds: attempt));
        if (!mounted) return;

        // 收集所有域的 Cookie，去重（以 name 为键，后者覆盖前者）
        final cookieMap = <String, String>{};
        for (final url in urls) {
          final cookies = await cookieManager.getCookies(
            url: url,
            webViewController: _controller,
          );
          for (final c in cookies) {
            cookieMap[c.name] = c.value.toString();
          }
        }

        // 组装 Cookie 字符串
        final cookieStr = cookieMap.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; ');
        lastCookieStr = cookieStr;

        // DEBUG: 打印获取到的 Cookie 键名帮助诊断
        debugPrint(
          '[WereadLogin] 第 $attempt 次尝试，Cookie 键名: ${cookieMap.keys.toList()}',
        );

        // 检查关键字段
        final hasKey = cookieMap.containsKey('wr_skey');
        final hasVid = cookieMap.containsKey('wr_vid');

        if (hasKey && hasVid) {
          // 关键字段就绪，保存到本地
          final saved = await WereadAuthService.instance.saveCookies(cookieStr);
          if (saved && mounted) {
            debugPrint(
              '[WereadLogin] Cookie 保存成功，全部键名: ${cookieMap.keys.toList()}',
            );

            // 在 WebView 内直接验证 Cookie 有效性（避免 session 绑定问题）
            final valid = await WereadAuthService.instance.validateCookie(
              webViewController: _controller,
            );
            debugPrint('[WereadLogin] WebView 内验证结果: $valid');

            // 启动后台 HeadlessInAppWebView 保持微信读书登录态
            // 供设置页校验/刷新等操作使用
            unawaited(WereadWebViewService.instance.ensureInitialized());

            setState(() {
              _extracting = false;
              _result = _CookieResult(
                success: true,
                message: valid
                    ? 'Cookie 提取并验证成功！'
                    : 'Cookie 已保存，但验证未通过（可能需要重新扫码）',
              );
            });
            return;
          }
        }
      }

      // 所有重试均未获取到完整 Cookie
      if (mounted) {
        // 诊断信息：列出实际获取到的 Cookie 键名
        final keys = (lastCookieStr ?? '')
            .split(';')
            .map((p) => p.trim().split('=').first)
            .where((k) => k.isNotEmpty)
            .toList();
        final keyInfo = keys.isEmpty ? '无' : keys.join(', ');
        setState(() {
          _extracting = false;
          _result = _CookieResult(
            success: false,
            message:
                '未获取到 wr_skey/wr_vid（已获取字段：$keyInfo）。'
                '请确认已完成微信扫码并等待页面跳转到书架',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _extracting = false;
          _result = _CookieResult(success: false, message: '提取失败：$error');
        });
      }
    }
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
            // 提取状态指示
            if (_extracting)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
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
            // 手动提取按钮（失败后也可重试）
            if (_isReady && !_extracting)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Button(
                  onPressed: () {
                    setState(() => _result = null);
                    _extractCookies();
                  },
                  child: Text(_result == null ? '手动提取 Cookie' : '重试提取'),
                ),
              ),
            // 返回按钮
            Button(
              onPressed: () =>
                  Navigator.of(context).pop(_result?.success ?? false),
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
            Text(
              '请确保系统已安装 Microsoft Edge WebView2 运行时',
              style: theme.typography.caption,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 提取成功/失败横幅
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
        // WebView 区域 — 使用 InAppWebView 跨平台实现
        Expanded(
          child: InAppWebView(
            webViewEnvironment: widget.webViewEnvironment,
            initialUrlRequest: URLRequest(url: WebUri(_wereadLoginUrl)),
            initialSettings: InAppWebViewSettings(
              // 启用 JS 支持（微信读书登录页必需）
              javaScriptEnabled: true,
              // 开发模式下启用检查器
              isInspectable: kDebugMode,
              // 桌面端模拟浏览器 UA，避免被识别为 WebView
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              if (mounted) {
                setState(() => _isReady = true);
              }
            },
            onTitleChanged: (controller, title) {
              if (mounted && title != null && title.isNotEmpty) {
                setState(() => _title = title);
              }
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              // 检测 URL 变化判断登录成功
              if (url != null && mounted) {
                _checkLoginSuccess(url.toString());
              }
            },
            onLoadStop: (controller, url) {
              // 页面加载完成后也检测一次
              if (url != null && mounted) {
                _checkLoginSuccess(url.toString());
              }
            },
            onReceivedError: (controller, request, error) {
              // 仅主框架加载失败时标记
              if (request.isForMainFrame == true && mounted) {
                setState(() => _initFailed = true);
              }
            },
          ),
        ),
        // 底部操作提示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FluentSpacing.m),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
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
