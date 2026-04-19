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
import 'package:dio/dio.dart';

import 'http_service.dart';
import 'weread_auth_service.dart';

/// 微信读书 API 服务（单例）
/// 封装对 i.weread.qq.com 的 REST API 请求
class WereadApiService {
  WereadApiService._();

  static final WereadApiService instance = WereadApiService._();

  final HttpService _http = HttpService.instance;
  final WereadAuthService _auth = WereadAuthService.instance;

  /// 微信读书 API 基础 URL
  static const String _apiBase = 'https://i.weread.qq.com';

  // ==================== 书架相关 ====================

  /// 获取用户书架数据
  /// 书架中 bookId 以 "MP_WXS_" 开头的是公众号
  /// :return: 书架原始 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> getShelf() async {
    return _getJson('$_apiBase/shelf/sync', queryParameters: {
      'synckey': 0,
      'teenmode': 0,
      'album': 1,
    });
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

  /// 获取指定公众号的文章列表
  /// [bookId] 公众号 bookId（格式：MP_WXS_xxxxxxxxxx）
  /// [offset] 分页偏移量，默认 0
  /// [count] 每页条数，默认 20，最大 40
  /// :return: 文章列表原始 JSON，失败返回 null
  Future<Map<String, dynamic>?> getArticles(
    String bookId, {
    int offset = 0,
    int count = 20,
  }) async {
    return _getJson('$_apiBase/book/articles', queryParameters: {
      'bookId': bookId,
      'offset': offset,
      'count': count,
    });
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
    return _getJson('$_apiBase/book/info', queryParameters: {
      'bookId': bookId,
    });
  }

  // ==================== 搜索 ====================

  /// 在微信读书中搜索公众号/书籍
  /// [keyword] 搜索关键词
  /// [count] 结果数量，默认 20
  /// :return: 搜索结果 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> search(
    String keyword, {
    int count = 20,
  }) async {
    return _getJson('$_apiBase/mp/search', queryParameters: {
      'keyword': keyword,
      'count': count,
    });
  }

  // ==================== 内部工具方法 ====================

  /// 通用 JSON GET 请求
  /// 自动注入 Cookie 认证头，处理错误
  /// [url] 完整请求 URL
  /// [queryParameters] URL 查询参数
  /// :return: 响应 JSON 数据，失败返回 null
  Future<Map<String, dynamic>?> _getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final cookie = await _auth.getCookieString();
    if (cookie == null || cookie.isEmpty) return null;

    try {
      final response = await _http.get<dynamic>(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Cookie': cookie,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://weread.qq.com/',
            'Origin': 'https://weread.qq.com',
          },
          responseType: ResponseType.json,
        ),
      );

      // 响应可能是 Map 或需要 JSON 解码的字符串
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // 检查业务错误码
        final errCode = data['errCode'] ?? data['errcode'];
        if (errCode != null && errCode != 0) return null;
        return data;
      }
      if (data is String) {
        final decoded = json.decode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } on DioException {
      // 网络错误静默失败，由调用方处理
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从 API 响应中提取文章列表
  /// 微信读书 book/articles 接口的文章数据可能在不同字段中
  /// [data] API 响应 JSON
  /// :return: 文章数据列表
  List<Map<String, dynamic>> _extractArticleList(Map<String, dynamic> data) {
    // 尝试 reviews 字段（weread v2 接口常用格式）
    final reviews = data['reviews'] as List<dynamic>?;
    if (reviews != null && reviews.isNotEmpty) {
      return reviews
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    // 尝试 articles 字段
    final articles = data['articles'] as List<dynamic>?;
    if (articles != null && articles.isNotEmpty) {
      return articles
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    // 尝试 data 嵌套字段
    final nested = data['data'] as List<dynamic>?;
    if (nested != null && nested.isNotEmpty) {
      return nested
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return [];
  }
}
