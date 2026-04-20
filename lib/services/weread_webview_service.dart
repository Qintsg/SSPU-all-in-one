#!/user/bin/env dart
// -*- coding: UTF-8 -*-
/*
 * 微信读书 WebView 会话服务 — 维持后台 HeadlessInAppWebView 以保持登录态
 * 微信读书 Cookie 与 WebView2 session 绑定，无法通过外部 HTTP 客户端使用
 * 本服务通过 HeadlessInAppWebView 保持会话存活，供校验和刷新 Cookie 使用
 * @Project : SSPU-all-in-one
 * @File : weread_webview_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-22
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'weread_auth_service.dart';

/// 微信读书 WebView 会话服务（单例）
/// 维持一个后台 HeadlessInAppWebView 实例，保持微信读书登录态
/// 用于在设置页等无可见 WebView 的场景下执行 Cookie 校验和刷新
class WereadWebViewService {
  WereadWebViewService._();

  static final WereadWebViewService instance = WereadWebViewService._();

  /// 后台 HeadlessInAppWebView 实例
  HeadlessInAppWebView? _headlessWebView;

  /// WebView 控制器（用于执行 JS）
  InAppWebViewController? _controller;

  /// 是否已初始化并加载完成
  bool _isReady = false;

  /// 初始化锁，防止并发初始化
  Completer<bool>? _initCompleter;

  /// 获取当前 WebView 控制器（可能为 null）
  InAppWebViewController? get controller => _controller;

  /// WebView 会话是否已就绪
  bool get isReady => _isReady && _controller != null;

  // ==================== 生命周期管理 ====================

  /// 初始化后台 WebView 并加载微信读书首页以激活 Cookie session
  /// 如果已初始化则跳过；支持并发调用安全
  /// :return: 是否初始化成功
  Future<bool> ensureInitialized() async {
    // 已就绪直接返回
    if (_isReady && _controller != null) return true;

    // 正在初始化中，等待结果
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<bool>();

    try {
      // 创建 HeadlessInAppWebView，加载微信读书首页
      final completer = Completer<bool>();

      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('https://weread.qq.com/')),
        initialSettings: InAppWebViewSettings(
          // 允许 JavaScript 执行
          javaScriptEnabled: true,
          // debug 模式下启用检查器
          isInspectable: kDebugMode,
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
          debugPrint('[WereadWebViewService] HeadlessInAppWebView 已创建');
        },
        onLoadStop: (controller, url) {
          debugPrint('[WereadWebViewService] 页面加载完成: $url');
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('[WereadWebViewService] 加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      // 启动后台 WebView
      await _headlessWebView!.run();

      // 等待页面加载完成（最多 30 秒超时）
      final loaded = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );

      // 页面加载后注入存储的 Cookie 到 WebView CookieManager
      // 确保手动粘贴的 Cookie 也能在 WebView fetch 中生效
      if (loaded) {
        await _injectStoredCookies();
      }

      _isReady = loaded;
      _initCompleter!.complete(loaded);

      debugPrint('[WereadWebViewService] 初始化${loaded ? "成功" : "失败"}');
      return loaded;
    } catch (e) {
      debugPrint('[WereadWebViewService] 初始化异常: $e');
      _isReady = false;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete(false);
      }
      return false;
    }
  }

  /// 销毁后台 WebView，释放资源
  Future<void> dispose() async {
    _isReady = false;
    _controller = null;
    _initCompleter = null;

    if (_headlessWebView != null) {
      await _headlessWebView!.dispose();
      _headlessWebView = null;
      debugPrint('[WereadWebViewService] 已销毁');
    }
  }

  /// 重新初始化（先销毁再创建）
  /// 适用于登录状态变化后需要刷新 WebView session 的场景
  /// :return: 是否成功
  Future<bool> reinitialize() async {
    await dispose();
    return ensureInitialized();
  }

  // ==================== 内部工具方法 ====================

  /// 将 SharedPreferences 中存储的 Cookie 注入到 WebView 的 CookieManager
  /// 解决手动粘贴 Cookie 时 WebView 内无认证信息的问题
  Future<void> _injectStoredCookies() async {
    try {
      final cookieStr = await WereadAuthService.instance.getCookieString();
      if (cookieStr == null || cookieStr.isEmpty) return;

      final cookieManager = CookieManager.instance();
      // 解析 Cookie 键值对并逐个注入到两个域
      final pairs = cookieStr.split(';');
      final domains = [
        WebUri('https://weread.qq.com/'),
        WebUri('https://i.weread.qq.com/'),
      ];

      for (final pair in pairs) {
        final trimmed = pair.trim();
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex <= 0) continue;

        final name = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();
        if (name.isEmpty) continue;

        for (final url in domains) {
          await cookieManager.setCookie(
            url: url,
            name: name,
            value: value,
            domain: '.weread.qq.com',
            path: '/',
            isSecure: true,
          );
        }
      }

      debugPrint('[WereadWebViewService] Cookie 注入完成');

      // 注入后重新加载页面以激活 Cookie session
      if (_controller != null) {
        await _controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri('https://weread.qq.com/')),
        );
        // 等待重新加载完成
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('[WereadWebViewService] Cookie 注入异常: $e');
    }
  }
}
