/*
 * 内嵌 WebView 页面 — 在应用内展示网页内容
 * 使用 flutter_inappwebview 实现跨平台内嵌浏览（Windows/macOS/Android/iOS/Linux）
 * @Project : SSPU-all-in-one
 * @File : webview_page.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
 */

import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// 内嵌 WebView 页面
/// 在应用内打开网页链接，提供导航栏（返回/前进/刷新/外部浏览器）
class WebViewPage extends StatefulWidget {
  /// 要加载的目标 URL
  final String url;

  /// 页面标题（WebView 加载完成前的临时标题）
  final String initialTitle;

  /// Windows 平台需要的 WebViewEnvironment（可选，由外部传入）
  final WebViewEnvironment? webViewEnvironment;

  const WebViewPage({
    super.key,
    required this.url,
    this.initialTitle = '加载中…',
    this.webViewEnvironment,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  /// InAppWebView 控制器
  InAppWebViewController? _controller;

  /// 当前页面标题
  String _title = '';

  /// 当前加载的 URL
  String _currentUrl = '';

  /// 是否可后退
  bool _canGoBack = false;

  /// 是否可前进
  bool _canGoForward = false;

  /// WebView 是否已创建
  bool _isReady = false;

  /// 初始化是否失败（触发 fallback）
  bool _initFailed = false;

  /// 加载进度（0.0 ~ 1.0）
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _currentUrl = widget.url;
  }

  /// 更新导航按钮状态（前进/后退可用性）
  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    final canBack = await _controller!.canGoBack();
    final canForward = await _controller!.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canForward;
      });
    }
  }

  /// 使用系统默认浏览器打开当前 URL（fallback 方案）
  Future<void> _fallbackToExternalBrowser() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // 初始化失败时显示提示界面
    if (_initFailed) {
      return ScaffoldPage(
        header: PageHeader(
          title: Text(widget.initialTitle),
          commandBar: IconButton(
            icon: const Icon(FluentIcons.chrome_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        content: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.warning, size: 48, color: theme.inactiveColor),
              const SizedBox(height: 12),
              Text('WebView 初始化失败', style: theme.typography.bodyStrong),
              const SizedBox(height: 8),
              Text('已在默认浏览器中打开链接', style: theme.typography.caption),
              const SizedBox(height: 16),
              Button(
                child: const Text('返回'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return ScaffoldPage(
      // 顶部导航栏：返回按钮 + 标题 + 操作按钮
      header: PageHeader(
        title: Row(
          children: [
            // 返回到上一个 Flutter 页面
            IconButton(
              icon: const Icon(FluentIcons.chrome_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            // 页面标题（自动截断）
            Expanded(
              child: Text(
                _title,
                style: theme.typography.subtitle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WebView 内后退
            IconButton(
              icon: Icon(
                FluentIcons.back,
                color: _canGoBack
                    ? null
                    : theme.inactiveColor.withValues(alpha: 0.4),
              ),
              onPressed: _canGoBack ? () => _controller?.goBack() : null,
            ),
            // WebView 内前进
            IconButton(
              icon: Icon(
                FluentIcons.forward,
                color: _canGoForward
                    ? null
                    : theme.inactiveColor.withValues(alpha: 0.4),
              ),
              onPressed: _canGoForward ? () => _controller?.goForward() : null,
            ),
            // 刷新
            IconButton(
              icon: const Icon(FluentIcons.refresh),
              onPressed: _isReady ? () => _controller?.reload() : null,
            ),
            const SizedBox(width: 8),
            // 在外部浏览器中打开
            Tooltip(
              message: '在浏览器中打开',
              child: IconButton(
                icon: const Icon(FluentIcons.open_in_new_window),
                onPressed: () => _fallbackToExternalBrowser(),
              ),
            ),
          ],
        ),
      ),
      content: Stack(
        children: [
          // WebView 主体
          InAppWebView(
            webViewEnvironment: widget.webViewEnvironment,
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              isInspectable: kDebugMode,
              // 桌面端浏览器 UA
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
              if (url != null && mounted) {
                setState(() => _currentUrl = url.toString());
                _updateNavigationState();
              }
            },
            onLoadStop: (controller, url) {
              if (url != null && mounted) {
                setState(() => _currentUrl = url.toString());
                _updateNavigationState();
              }
            },
            onProgressChanged: (controller, progress) {
              if (mounted) {
                setState(() => _progress = progress / 100.0);
              }
            },
            onReceivedError: (controller, request, error) {
              // 仅主框架加载失败时触发 fallback
              if (request.isForMainFrame == true && mounted) {
                setState(() => _initFailed = true);
                _fallbackToExternalBrowser();
              }
            },
          ),
          // 加载进度条（顶部细条）
          if (_progress > 0 && _progress < 1.0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ProgressBar(value: _progress * 100),
            ),
        ],
      ),
    );
  }
}
