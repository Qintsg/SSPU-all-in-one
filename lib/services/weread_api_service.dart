#!/user/bin/env dart
// -*- coding: UTF-8 -*-
/*
 * 微信读书 API 服务 — 封装 weread.qq.com 的 HTTP API 调用
 * 提供书架获取、公众号搜索、文章列表、书籍详情等接口
 * 所有请求自动注入 Cookie 认证头
 * @Project : SSPU-all-in-one
 * @File : weread_api_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-20
 */

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'weread_auth_service.dart';
import 'weread_webview_service.dart';

/// 微信读书 API 服务（单例）
/// 封装对 i.weread.qq.com 的 REST API 请求
class WereadApiService {
  WereadApiService._();

  static final WereadApiService instance = WereadApiService._();

  final WereadAuthService _auth = WereadAuthService.instance;
  final WereadWebViewService _webViewService = WereadWebViewService.instance;

  /// 微信读书 Web 端 API 基础 URL
  /// 使用 weread.qq.com/web 路径（同源）— 书架、公众号文章、书籍信息等接口
  static const String _apiBase = 'https://weread.qq.com/web';

  // ==================== 书架相关 ====================

  /// 获取用户书架数据
  /// 书架中 bookId 以 "MP_WXS_" 开头的是公众号
  /// :return: 书架原始 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> getShelf() async {
    return _getJson(
      '$_apiBase/shelf/sync',
      queryParameters: {'synckey': 0, 'teenmode': 0, 'album': 1},
    );
  }

  /// 从书架数据中提取已关注的公众号列表
  /// :return: 公众号 bookId 列表（格式：MP_WXS_xxxxxxxxxx）
  Future<List<String>> getFollowedMpBookIds() async {
    final shelf = await getShelf();
    if (shelf == null) return [];

    final bookIds = <String>[];

    // 书架数据结构：books 数组中每项有 bookId 字段
    final books = shelf['books'] as List<dynamic>?;
    if (books != null) {
      for (final item in books) {
        final bookId = (item is Map) ? item['bookId']?.toString() : null;
        // 公众号的 bookId 以 MP_WXS_ 开头
        if (bookId != null && bookId.startsWith('MP_WXS_')) {
          bookIds.add(bookId);
        }
      }
    }

    return bookIds;
  }

  // ==================== 公众号文章 ====================

  /// 获取文章内容详情（含原始微信文章链接等信息）
  /// [reviewId] 文章的 reviewId
  /// :return: 文章内容 JSON，失败返回 null
  Future<Map<String, dynamic>?> getArticleContent(String reviewId) async {
    return _getJson(
      '$_apiBase/mp/content',
      queryParameters: {'reviewId': reviewId},
    );
  }

  /// 获取指定公众号的文章列表
  /// 使用 /web/mp/articles 接口（/web/book/articles 已下架）
  /// [bookId] 公众号 bookId（格式：MP_WXS_xxxxxxxxxx）
  /// [offset] 分页偏移量，默认 0
  /// [count] 每页条数，默认 20，最大 40
  /// :return: 文章列表原始 JSON，失败返回 null
  Future<Map<String, dynamic>?> getArticles(
    String bookId, {
    int offset = 0,
    int count = 20,
  }) async {
    return _getJson(
      '$_apiBase/mp/articles',
      queryParameters: {'bookId': bookId, 'offset': offset, 'count': count},
    );
  }

  /// 获取公众号的全部文章（自动翻页，限制最大条数）
  /// [bookId] 公众号 bookId
  /// [maxCount] 最大获取条数，防止无限翻页
  /// :return: 文章数据列表
  Future<List<Map<String, dynamic>>> getAllArticles(
    String bookId, {
    int maxCount = 50,
  }) async {
    final allArticles = <Map<String, dynamic>>[];
    var offset = 0;
    const pageSize = 20;

    while (allArticles.length < maxCount) {
      final data = await getArticles(bookId, offset: offset, count: pageSize);
      if (data == null) break;

      // 文章数据在 reviews 或 articles 字段中
      final articles = _extractArticleList(data);
      if (articles.isEmpty) break;

      allArticles.addAll(articles);
      offset += pageSize;

      // 如果返回的文章数少于 pageSize，说明已到末页
      if (articles.length < pageSize) break;
    }

    // 截断到 maxCount
    if (allArticles.length > maxCount) {
      return allArticles.sublist(0, maxCount);
    }
    return allArticles;
  }

  // ==================== 书籍/公众号信息 ====================

  /// 获取书籍（公众号）的详细信息
  /// [bookId] 书籍/公众号 bookId
  /// :return: 详情 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> getBookInfo(String bookId) async {
    return _getJson('$_apiBase/book/info', queryParameters: {'bookId': bookId});
  }

  // ==================== 搜索 ====================

  /// 在微信读书中搜索公众号/书籍
  /// [keyword] 搜索关键词
  /// [count] 结果数量，默认 20
  /// :return: 搜索结果 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> search(String keyword, {int count = 20}) async {
    return _getJson(
      '$_apiBase/mp/search',
      queryParameters: {'keyword': keyword, 'count': count},
    );
  }

  // ==================== 内部工具方法 ====================

  /// 通用 JSON GET 请求 — 通过 HeadlessInAppWebView 的 JS fetch 执行
  /// 微信读书 Cookie 与 WebView2 session 绑定，外部 HTTP 客户端无法使用
  /// [url] 完整请求 URL
  /// [queryParameters] URL 查询参数
  /// :return: 响应 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> _getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final cookie = await _auth.getCookieString();
    if (cookie == null || cookie.isEmpty) return null;

    // 拼接查询参数到 URL
    final uri = Uri.parse(url).replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );

    // 优先通过 WebView 内部 JS fetch 执行（Cookie session 绑定）
    final controller = _webViewService.controller;
    if (controller != null && _webViewService.isReady) {
      return _getJsonViaWebView(controller, uri.toString());
    }

    // WebView 未就绪时尝试初始化
    final initialized = await _webViewService.ensureInitialized();
    if (initialized && _webViewService.controller != null) {
      return _getJsonViaWebView(_webViewService.controller!, uri.toString());
    }

    debugPrint('[WereadApi] WebView 未就绪，无法执行 API 请求: $url');
    return null;
  }

  /// 通过 WebView JS fetch 执行 GET 请求
  /// 使用 callAsyncJavaScript 执行 fetch 并解析 JSON 响应
  /// [controller] WebView 控制器
  /// [fullUrl] 完整请求 URL（含查询参数）
  /// :return: 解析后的 JSON Map，失败返回 null
  Future<Map<String, dynamic>?> _getJsonViaWebView(
    InAppWebViewController controller,
    String fullUrl,
  ) async {
    try {
      final result = await controller.callAsyncJavaScript(
        functionBody: '''
          try {
            const resp = await fetch(url, {
              method: 'GET',
              credentials: 'include',
              headers: {
                'Accept': 'application/json, text/plain, */*'
              }
            });
            const status = resp.status;
            if (status !== 200) {
              return { __error: true, status: status };
            }
            const data = await resp.json();
            return data;
          } catch (e) {
            return { __error: true, message: e.toString() };
          }
        ''',
        arguments: {'url': fullUrl},
      );

      if (result == null || result.error != null) {
        debugPrint('[WereadApi] WebView JS 执行失败: ${result?.error}');
        return null;
      }

      final value = result.value;
      Map<String, dynamic>? data;

      if (value is Map<String, dynamic>) {
        data = value;
      } else if (value is String) {
        final decoded = json.decode(value);
        if (decoded is Map<String, dynamic>) data = decoded;
      }

      if (data == null) return null;

      // 检查内部错误标记
      if (data['__error'] == true) {
        debugPrint('[WereadApi] fetch 失败: $data');
        return null;
      }

      // 检查业务错误码
      final errCode = data['errCode'] ?? data['errcode'];
      if (errCode != null && errCode != 0) {
        debugPrint('[WereadApi] 业务错误: errCode=$errCode');
        return null;
      }

      return data;
    } catch (e) {
      debugPrint('[WereadApi] _getJsonViaWebView 异常: $e');
      return null;
    }
  }

  /// 从 API 响应中提取文章列表
  /// 微信读书 book/articles 接口的文章数据可能在不同字段中
  /// [data] API 响应 JSON
  /// :return: 文章数据列表
  List<Map<String, dynamic>> _extractArticleList(Map<String, dynamic> data) {
    // /web/mp/articles 返回格式：reviews[].subReviews[].review
    // 需要展平 subReviews 层级，提取每篇文章数据
    final reviews = data['reviews'] as List<dynamic>?;
    if (reviews != null && reviews.isNotEmpty) {
      final flatArticles = <Map<String, dynamic>>[];
      for (final reviewGroup in reviews) {
        if (reviewGroup is! Map<String, dynamic>) continue;
        // subReviews 内含实际文章条目
        final subReviews = reviewGroup['subReviews'] as List<dynamic>?;
        if (subReviews != null) {
          for (final sub in subReviews) {
            if (sub is Map<String, dynamic>) {
              flatArticles.add(sub);
            }
          }
        } else {
          // 兜底：无 subReviews 时直接作为文章条目
          flatArticles.add(reviewGroup);
        }
      }
      if (flatArticles.isNotEmpty) return flatArticles;
    }

    // 兜底：尝试 articles / data 字段
    final articles = data['articles'] as List<dynamic>?;
    if (articles != null && articles.isNotEmpty) {
      return articles.whereType<Map<String, dynamic>>().toList();
    }
    final nested = data['data'] as List<dynamic>?;
    if (nested != null && nested.isNotEmpty) {
      return nested.whereType<Map<String, dynamic>>().toList();
    }

    return [];
  }
}
