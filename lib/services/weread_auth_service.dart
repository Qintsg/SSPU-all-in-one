#!/user/bin/env dart
// -*- coding: UTF-8 -*-
/*
 * 微信读书认证服务 — 管理 Web Cookie 的存储、校验与自动刷新
 * 微信读书 API 鉴权依赖三个关键 Cookie：wr_skey、wr_vid、RK
 * Cookie 来源：用户从浏览器开发者工具手动提取并粘贴到设置页
 * @Project : SSPU-all-in-one
 * @File : weread_auth_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-20
 */

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'http_service.dart';
import 'storage_service.dart';

/// 微信读书认证服务（单例）
/// 负责 Cookie 的持久化存储、有效性检查与自动续期
class WereadAuthService {
  WereadAuthService._();

  static final WereadAuthService instance = WereadAuthService._();

  final HttpService _http = HttpService.instance;

  // ==================== 存储键名 ====================

  /// Cookie 完整字符串的存储键
  static const String _keyCookieString = 'weread_cookie_string';

  /// wr_vid（用户标识）的存储键
  static const String _keyVid = 'weread_vid';

  /// wr_skey（会话密钥）的存储键
  static const String _keySkey = 'weread_skey';

  /// Cookie 最后更新时间戳（毫秒）
  static const String _keyLastUpdate = 'weread_cookie_last_update';

  /// 微信读书 Web 版基础域名
  static const String _baseUrl = 'https://weread.qq.com';

  /// 微信读书 API 域名
  static const String _apiBaseUrl = 'https://i.weread.qq.com';

  // ==================== Cookie 管理 ====================

  /// 保存用户粘贴的 Cookie 字符串
  /// 解析并提取关键字段（wr_skey、wr_vid）分别存储
  /// [rawCookie] 浏览器复制的完整 Cookie 字符串
  /// :return: 是否解析成功（包含必要字段）
  Future<bool> saveCookies(String rawCookie) async {
    final trimmed = rawCookie.trim();
    if (trimmed.isEmpty) return false;

    // 解析 Cookie 键值对
    final parsed = _parseCookieString(trimmed);
    final vid = parsed['wr_vid'];
    final skey = parsed['wr_skey'];

    // wr_vid 和 wr_skey 是必须的
    if (vid == null || vid.isEmpty || skey == null || skey.isEmpty) {
      return false;
    }

    // 持久化存储
    await StorageService.setString(_keyCookieString, trimmed);
    await StorageService.setString(_keyVid, vid);
    await StorageService.setString(_keySkey, skey);
    await StorageService.setInt(
      _keyLastUpdate,
      DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  /// 获取完整的 Cookie 字符串（用于注入 HTTP 请求头）
  /// :return: Cookie 字符串，未配置时返回 null
  Future<String?> getCookieString() async {
    return StorageService.getString(_keyCookieString);
  }

  /// 获取 wr_vid（用户标识，部分 API 需要作为 query 参数）
  /// :return: vid 字符串，未配置时返回 null
  Future<String?> getVid() async {
    return StorageService.getString(_keyVid);
  }

  /// 检查是否已配置 Cookie（不验证有效性，仅检查本地是否有值）
  /// :return: 是否已保存过 Cookie
  Future<bool> hasCookies() async {
    final cookie = await getCookieString();
    return cookie != null && cookie.isNotEmpty;
  }

  /// 清除所有已存储的 Cookie 信息
  Future<void> clearCookies() async {
    await StorageService.remove(_keyCookieString);
    await StorageService.remove(_keyVid);
    await StorageService.remove(_keySkey);
    await StorageService.remove(_keyLastUpdate);
  }

  /// 获取 Cookie 最后更新时间
  /// :return: 上次更新的 DateTime，从未配置返回 null
  Future<DateTime?> getLastUpdateTime() async {
    final ts = await StorageService.getInt(_keyLastUpdate);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ==================== 有效性验证 ====================

  /// 在线验证 Cookie 是否仍然有效
  /// 优先通过 WebView 内执行 fetch 验证（避免 session 绑定问题），
  /// 若无可用 WebView 控制器则回退到 Dio 请求
  /// [webViewController] 可选的 InAppWebViewController 用于 WebView 内验证
  /// :return: Cookie 是否有效
  Future<bool> validateCookie({
    dynamic webViewController,
  }) async {
    // 优先使用 WebView 内 JS 验证（Cookie 自动携带，避免 session 绑定问题）
    if (webViewController != null) {
      return _validateViaWebView(webViewController);
    }

    // 回退：使用 Dio 外部请求验证
    return _validateViaDio();
  }

  /// 通过 WebView 内 JS fetch 验证 Cookie 有效性
  /// 使用 callAsyncJavaScript 正确处理 async/await（evaluateJavascript 对 Promise 返回 {})
  Future<bool> _validateViaWebView(dynamic controller) async {
    try {
      // callAsyncJavaScript 能正确等待 Promise resolve，返回 CallAsyncJavaScriptResult
      final callResult = await controller.callAsyncJavaScript(
        functionBody: '''
          try {
            const resp = await fetch(
              '/web/shelf/sync?synckey=0&teenmode=0',
              { credentials: 'include' }
            );
            if (!resp.ok) {
              return { status: resp.status, ok: false };
            }
            const data = await resp.json();
            const errcode = data.errcode || data.errCode;
            return {
              status: resp.status,
              ok: true,
              errcode: errcode || 0,
            };
          } catch (e) {
            return { status: -1, ok: false, error: e.message };
          }
        ''',
      );

      debugPrint('[WereadAuth] WebView 验证结果: ${callResult?.value}, error: ${callResult?.error}');
      if (callResult == null || callResult.error != null) return false;

      final value = callResult.value;
      if (value is Map) {
        final ok = value['ok'] == true;
        final errcode = value['errcode'];
        return ok && (errcode == null || errcode == 0);
      }
      return false;
    } catch (e) {
      debugPrint('[WereadAuth] WebView 验证异常: $e');
      return false;
    }
  }

  /// 通过 Dio 外部 HTTP 请求验证 Cookie（回退方案）
  Future<bool> _validateViaDio() async {
    final cookie = await getCookieString();
    if (cookie == null || cookie.isEmpty) return false;

    debugPrint('[WereadAuth] Dio 验证，Cookie 键名: ${cookie.split(';').map((p) => p.trim().split('=').first).toList()}');

    try {
      final response = await _http.get<Map<String, dynamic>>(
        '$_apiBaseUrl/shelf/sync',
        queryParameters: {'synckey': 0, 'teenmode': 0, 'album': 1},
        options: Options(
          headers: _buildHeaders(cookie),
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint('[WereadAuth] Dio 验证状态码: ${response.statusCode}');
      if (response.statusCode == 401) return false;

      final data = response.data;
      if (data == null) return false;
      final errCode = data['errCode'] ?? data['errcode'];
      if (errCode != null && errCode != 0) return false;
      return true;
    } catch (e) {
      debugPrint('[WereadAuth] Dio 验证异常: $e');
      return false;
    }
  }

  /// 尝试刷新 Cookie
  /// 优先通过 WebView 内执行 renewal 请求，若无可用 WebView 则回退到 Dio
  /// [webViewController] 可选的 InAppWebViewController
  /// :return: 刷新是否成功
  Future<bool> renewCookie({
    dynamic webViewController,
  }) async {
    if (webViewController != null) {
      return _renewViaWebView(webViewController);
    }
    return _renewViaDio();
  }

  /// 通过 WebView 内 JS fetch 刷新 Cookie
  /// 使用 callAsyncJavaScript 正确处理 async/await
  Future<bool> _renewViaWebView(dynamic controller) async {
    try {
      final callResult = await controller.callAsyncJavaScript(
        functionBody: '''
          try {
            const resp = await fetch('/web/login/renewal', {
              method: 'POST',
              credentials: 'include',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ rq: '%2Fweb%2Fbook%2Fread' })
            });
            const data = await resp.json();
            return { status: resp.status, succ: data.succ || 0 };
          } catch (e) {
            return { status: -1, error: e.message };
          }
        ''',
      );

      debugPrint('[WereadAuth] WebView renewal 结果: ${callResult?.value}, error: ${callResult?.error}');
      if (callResult == null || callResult.error != null) return false;

      final value = callResult.value;
      if (value is Map && value['succ'] == 1) {
        await StorageService.setInt(
          _keyLastUpdate,
          DateTime.now().millisecondsSinceEpoch,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[WereadAuth] WebView renewal 异常: $e');
      return false;
    }
  }

  /// 通过 Dio 外部 HTTP 请求刷新 Cookie（回退方案）
  Future<bool> _renewViaDio() async {
    final cookie = await getCookieString();
    if (cookie == null || cookie.isEmpty) return false;

    try {
      final response = await _http.post<Map<String, dynamic>>(
        '$_baseUrl/web/login/renewal',
        options: Options(
          headers: _buildHeaders(cookie),
          responseType: ResponseType.json,
        ),
      );

      final data = response.data;
      if (data == null) return false;

      // 刷新成功时更新 skey
      final succ = data['succ'] ?? 0;
      if (succ == 1) {
        // 如果响应头包含 Set-Cookie，更新本地存储
        final setCookies = response.headers['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          await _updateFromSetCookie(setCookies);
        }
        await StorageService.setInt(
          _keyLastUpdate,
          DateTime.now().millisecondsSinceEpoch,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ==================== 内部工具方法 ====================

  /// 构建微信读书 API 请求头
  /// [cookie] 完整 Cookie 字符串
  /// :return: 请求头 Map
  Map<String, dynamic> _buildHeaders(String cookie) {
    return {
      'Cookie': cookie,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': '$_baseUrl/',
      'Origin': _baseUrl,
      // 模拟浏览器跨域请求头，微信读书服务端校验这些字段
      'Sec-Fetch-Site': 'same-site',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Dest': 'empty',
      'Accept': 'application/json, text/plain, */*',
    };
  }

  /// 解析 Cookie 字符串为键值对 Map
  /// [cookieStr] 格式如 "key1=val1; key2=val2"
  /// :return: 键值对 Map
  Map<String, String> _parseCookieString(String cookieStr) {
    final result = <String, String>{};
    final pairs = cookieStr.split(';');
    for (final pair in pairs) {
      final trimmed = pair.trim();
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex > 0) {
        final key = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();
        result[key] = value;
      }
    }
    return result;
  }

  /// 从响应的 Set-Cookie 头更新本地 Cookie
  /// 合并新的 Cookie 值到已存储的完整字符串中
  /// [setCookieHeaders] 响应头中的 Set-Cookie 列表
  Future<void> _updateFromSetCookie(List<String> setCookieHeaders) async {
    final current = await getCookieString();
    if (current == null) return;

    final parsed = _parseCookieString(current);

    // 从 Set-Cookie 头提取新值
    for (final header in setCookieHeaders) {
      // Set-Cookie 格式: key=value; Path=/; ...
      final mainPart = header.split(';').first.trim();
      final eqIndex = mainPart.indexOf('=');
      if (eqIndex > 0) {
        final key = mainPart.substring(0, eqIndex).trim();
        final value = mainPart.substring(eqIndex + 1).trim();
        parsed[key] = value;
      }
    }

    // 重新组装 Cookie 字符串
    final newCookie =
        parsed.entries.map((e) => '${e.key}=${e.value}').join('; ');
    await StorageService.setString(_keyCookieString, newCookie);

    // 更新分离存储的关键字段
    if (parsed.containsKey('wr_vid')) {
      await StorageService.setString(_keyVid, parsed['wr_vid']!);
    }
    if (parsed.containsKey('wr_skey')) {
      await StorageService.setString(_keySkey, parsed['wr_skey']!);
    }
  }
}
