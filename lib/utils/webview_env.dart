/*
 * WebView2 环境全局单例 — Windows 平台 WebViewEnvironment 持有者
 * flutter_inappwebview 在 Windows 上要求所有 WebView 实例共享同一个
 * WebViewEnvironment，必须在 runApp() 之前完成初始化。
 * 其他文件通过导入本文件访问 globalWebViewEnvironment。
 * @Project : SSPU-all-in-one
 * @File : webview_env.dart
 * @Author : Qintsg
 * @Date : 2026-04-21
 */

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Windows 平台全局 WebViewEnvironment 实例
/// 在 main() 中初始化，非 Windows 平台始终为 null
WebViewEnvironment? globalWebViewEnvironment;
