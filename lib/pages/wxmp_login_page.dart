/*
 * 微信公众号平台扫码登录页 — 内嵌 WebView 加载 mp.weixin.qq.com
 * 用户扫码登录后自动提取 Cookie 和 Token
 * @Project : SSPU-all-in-one
 * @File : wxmp_login_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/wxmp_article_service.dart';
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
  final bool _initFailed = false;
  String _title = '公众号平台登录';
  bool _extracting = false;
  bool _pageTokenCheckScheduled = false;
  _LoginResult? _result;

  /// 监听 URL 变化，检测登录成功
  /// 登录成功后 URL 形如:
  /// https://mp.weixin.qq.com/cgi-bin/home?t=home/index&token=123456789&lang=zh_CN
  void _checkLoginSuccess(String url) {
    if (_extracting || _result != null) return;

    if (!url.contains('mp.weixin.qq.com')) return;
    final urlToken = _extractTokenFromText(url);
    if (urlToken != null) {
      _extractCookieAndSave(urlToken, url);
      return;
    }

    _schedulePageTokenCheck(url);
  }

  /// URL 不含 token 时，从页面脚本变量和当前地址中补充识别登录态。
  void _schedulePageTokenCheck(String pageUrl) {
    if (_pageTokenCheckScheduled) return;
    _pageTokenCheckScheduled = true;
    Future<void>(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      _pageTokenCheckScheduled = false;
      if (!mounted || _extracting || _result != null) return;

      final pageToken = await _readTokenFromPage();
      if (pageToken != null) {
        _extractCookieAndSave(pageToken, pageUrl);
      }
    });
  }

  String? _extractTokenFromText(String text) {
    final tokenMatch = RegExp(
      r'''(?:[?&]token=|["']token["']\s*:\s*["']?)(\d+)''',
    ).firstMatch(text);
    return tokenMatch?.group(1);
  }

  Future<String?> _readTokenFromPage() async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      final tokenText = await controller.evaluateJavascript(
        source: '''
(() => {
  const candidates = [
    window.location.href,
    document.documentElement ? document.documentElement.innerHTML : '',
    document.body ? document.body.innerText : ''
  ];
  for (const candidate of candidates) {
    const match = String(candidate).match(/(?:[?&]token=|["']token["']\\s*:\\s*["']?)(\\d+)/);
    if (match) return match[1];
  }
  return '';
})()
''',
      );
      final token = tokenText?.toString() ?? '';
      return RegExp(r'^\d+$').hasMatch(token) ? token : null;
    } catch (error) {
      debugPrint('[WxmpLogin] 页面 token 读取失败: $error');
      return null;
    }
  }

  /// 提取 Cookie 并与 Token 一起保存
  Future<void> _extractCookieAndSave(String token, String successUrl) async {
    if (_extracting) return;
    setState(() => _extracting = true);

    try {
      _CookieReadResult? lastCookieReadResult;
      WxmpAuthValidationResult? lastValidation;

      for (var attempt = 0; attempt < 4; attempt++) {
        await Future.delayed(Duration(milliseconds: 500 + attempt * 500));
        lastCookieReadResult = await _readWxmpCookies(successUrl);
        if (lastCookieReadResult.cookieMap.isEmpty) continue;

        final cookieStr = lastCookieReadResult.cookieMap.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; ');

        await WxmpAuthService.instance.saveAuth(cookieStr, token);
        lastValidation = await WxmpArticleService.instance.validateAuth();
        if (lastValidation.isValid) {
          debugPrint(
            '[WxmpLogin] 认证保存成功, Cookie 数量: '
            '${lastCookieReadResult.cookieMap.length}, Cookie 键名: '
            '${lastCookieReadResult.cookieNames.toList()..sort()}',
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
          return;
        }
      }

      final cookieCount = lastCookieReadResult?.cookieMap.length ?? 0;
      final cookieNames = lastCookieReadResult?.cookieNames ?? <String>{};
      if (cookieCount == 0) {
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

      debugPrint(
        '[WxmpLogin] 认证保存后校验失败: ${lastValidation?.message}, Cookie 数量: $cookieCount, Cookie 键名: '
        '${cookieNames.toList()..sort()}',
      );
      if (mounted) {
        setState(() {
          _extracting = false;
          _result = _LoginResult(
            success: false,
            message: '认证校验失败：${lastValidation?.message ?? 'Cookie 不完整'}',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _extracting = false;
          _result = _LoginResult(success: false, message: '提取失败：$error');
        });
      }
    }
  }

  Future<_CookieReadResult> _readWxmpCookies(String successUrl) async {
    final cookieManager = CookieManager.instance();
    final cookieMap = <String, String>{};
    final cookieNames = <String>{};
    final currentUrl = await _controller?.getUrl();
    final cookieUrls = <String>{
      'https://mp.weixin.qq.com/',
      'https://mp.weixin.qq.com/cgi-bin/home',
      'https://mp.weixin.qq.com/cgi-bin/searchbiz',
      'https://mp.weixin.qq.com/cgi-bin/appmsg',
      'https://mp.weixin.qq.com/cgi-bin/appmsgpublish',
      if (currentUrl != null) currentUrl.toString(),
      successUrl,
    };

    for (final cookieUrl in cookieUrls) {
      final cookies = await cookieManager.getCookies(
        url: WebUri(cookieUrl),
        webViewController: _controller,
      );
      for (final cookie in cookies) {
        final cookieValue = cookie.value?.toString() ?? '';
        if (cookie.name.isEmpty || cookieValue.isEmpty) continue;
        cookieMap[cookie.name] = cookieValue;
        cookieNames.add(cookie.name);
      }
    }

    final documentCookie = await _readDocumentCookie();
    for (final cookiePart in documentCookie.split(';')) {
      final separatorIndex = cookiePart.indexOf('=');
      if (separatorIndex <= 0) continue;
      final cookieName = cookiePart.substring(0, separatorIndex).trim();
      final cookieValue = cookiePart.substring(separatorIndex + 1).trim();
      if (cookieName.isEmpty || cookieValue.isEmpty) continue;
      cookieMap[cookieName] = cookieValue;
      cookieNames.add(cookieName);
    }

    return _CookieReadResult(cookieMap: cookieMap, cookieNames: cookieNames);
  }

  Future<String> _readDocumentCookie() async {
    final controller = _controller;
    if (controller == null) return '';
    try {
      final cookieText = await controller.evaluateJavascript(
        source: 'document.cookie',
      );
      return cookieText?.toString() ?? '';
    } catch (error) {
      debugPrint('[WxmpLogin] document.cookie 读取失败: $error');
      return '';
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
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark
        ? FluentDarkColors.statusSuccess
        : FluentLightColors.statusSuccess;
    final errorColor = isDark
        ? FluentDarkColors.statusError
        : FluentLightColors.statusError;
    final infoColor = isDark
        ? FluentDarkColors.statusInfo
        : FluentLightColors.statusInfo;
    final resultColor = _result?.success == true ? successColor : errorColor;

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
            color: resultColor.withValues(alpha: isDark ? 0.18 : 0.12),
            child: Text(
              _result!.message,
              style: theme.typography.body?.copyWith(color: resultColor),
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
            color: infoColor.withValues(alpha: isDark ? 0.14 : 0.08),
            child: Text(
              '请使用拥有公众号的微信账号扫码登录。'
              '个人订阅号即可（mp.weixin.qq.com 免费注册）。',
              style: theme.typography.caption?.copyWith(color: infoColor),
            ),
          ),
        // WebView
        Expanded(
          child: InAppWebView(
            webViewEnvironment: widget.webViewEnvironment,
            initialUrlRequest: URLRequest(url: WebUri(_wxmpLoginUrl)),
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

class _CookieReadResult {
  final Map<String, String> cookieMap;
  final Set<String> cookieNames;

  _CookieReadResult({required this.cookieMap, required this.cookieNames});
}
