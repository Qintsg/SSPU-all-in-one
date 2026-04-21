/*
 * 微信公众号平台扫码登录页 — 内嵌 WebView 加载 mp.weixin.qq.com
 * 用户扫码登录后自动提取 Cookie 和 Token
 * @Project : SSPU-all-in-one
 * @File : wxmp_login_page.dart
 * @Author : Qintsg
 * @Date : 2026-07-22
 */

import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/wxmp_auth_service.dart';
import '../theme/fluent_tokens.dart';

/// 公众号平台登录 URL
const String _wxmpLoginUrl = 'https://mp.weixin.qq.com/';

/// 微信公众号平台扫码登录页
/// 加载 mp.weixin.qq.com，用户扫码后从 URL 提取 token，从 CookieManager 提取 Cookie
class WxmpLoginPage extends StatefulWidget {
  /// Windows 平台需要的 WebViewEnvironment（由外部传入）
  final WebViewEnvironment? webViewEnvironment;

  const WxmpLoginPage({super.key, this.webViewEnvironment});

  @override
  State<WxmpLoginPage> createState() => _WxmpLoginPageState();
}

class _WxmpLoginPageState extends State<WxmpLoginPage> {
  InAppWebViewController? _controller;
  bool _isReady = false;
  bool _initFailed = false;
  String _title = '公众号平台登录';
  bool _extracting = false;
  _LoginResult? _result;

  /// 监听 URL 变化，检测登录成功
  /// 登录成功后 URL 形如:
  /// https://mp.weixin.qq.com/cgi-bin/home?t=home/index&token=123456789&lang=zh_CN
  void _checkLoginSuccess(String url) {
    if (_extracting || _result != null) return;

    if (url.contains('mp.weixin.qq.com') && url.contains('token=')) {
      final tokenMatch = RegExp(r'token=(\d+)').firstMatch(url);
      if (tokenMatch != null) {
        final token = tokenMatch.group(1)!;
        _extractCookieAndSave(token);
      }
    }
  }

  /// 提取 Cookie 并与 Token 一起保存
  Future<void> _extractCookieAndSave(String token) async {
    if (_extracting) return;
    setState(() => _extracting = true);

    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(
        url: WebUri('https://mp.weixin.qq.com'),
        webViewController: _controller,
      );

      if (cookies.isEmpty) {
        if (mounted) {
          setState(() {
            _extracting = false;
            _result = _LoginResult(
              success: false,
              message: '未获取到 Cookie，请确认已完成扫码',
            );
          });
        }
        return;
      }

      // 拼接为标准 Cookie 字符串
      final cookieStr =
          cookies.map((c) => '${c.name}=${c.value}').join('; ');

      // 保存到 WxmpAuthService
      await WxmpAuthService.instance.saveAuth(cookieStr, token);

      debugPrint(
        '[WxmpLogin] 认证保存成功, Token: $token, Cookie 键名: '
        '${cookies.map((c) => c.name).toList()}',
      );

      if (mounted) {
        setState(() {
          _extracting = false;
          _result = _LoginResult(
            success: true,
            message: '登录成功，Token 和 Cookie 已保存',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _extracting = false;
          _result = _LoginResult(
            success: false,
            message: '提取失败：$error',
          );
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
                    Text('正在提取认证信息...'),
                  ],
                ),
              ),
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

  Widget _buildContent(BuildContext context) {
    final theme = FluentTheme.of(context);

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
        // 结果横幅
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
        // 提示信息
        if (!_isReady && _result == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: FluentSpacing.l,
              vertical: FluentSpacing.s,
            ),
            color: FluentLightColors.statusInfo.withValues(alpha: 0.08),
            child: Text(
              '请使用拥有公众号的微信账号扫码登录。'
              '个人订阅号即可（mp.weixin.qq.com 免费注册）。',
              style: theme.typography.caption,
            ),
          ),
        // WebView
        Expanded(
          child: InAppWebView(
            webViewEnvironment: widget.webViewEnvironment,
            initialUrlRequest:
                URLRequest(url: WebUri(_wxmpLoginUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              isInspectable: kDebugMode,
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              if (mounted) setState(() => _isReady = true);
            },
            onTitleChanged: (controller, title) {
              if (mounted && title != null && title.isNotEmpty) {
                setState(() => _title = title);
              }
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              if (url != null && mounted) {
                _checkLoginSuccess(url.toString());
              }
            },
            onLoadStop: (controller, url) {
              if (url != null && mounted) {
                _checkLoginSuccess(url.toString());
              }
            },
            onReceivedError: (controller, request, error) {
              debugPrint('[WxmpLogin] WebView 错误: ${error.description}');
            },
          ),
        ),
      ],
    );
  }
}

/// 登录结果
class _LoginResult {
  final bool success;
  final String message;
  _LoginResult({required this.success, required this.message});
}
