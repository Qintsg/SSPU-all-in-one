#!/user/bin/env dart
// -*- coding: UTF-8 -*-
/*
 * 微信公众号文章采集服务 — 通过微信读书 API 获取公众号文章并转为 MessageItem
 * 作为微信公众号渠道的数据源实现
 * 获取用户书架中已关注公众号 → 逐个拉取文章列表 → 转为统一消息格式
 * @Project : SSPU-all-in-one
 * @File : wechat_article_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-20
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../models/message_item.dart';
import 'weread_api_service.dart';
import 'weread_auth_service.dart';

/// 微信公众号文章采集服务（单例）
/// 通过微信读书 API 获取关注的公众号推文，转换为 MessageItem 统一格式
class WechatArticleService {
  WechatArticleService._();

  static final WechatArticleService instance = WechatArticleService._();

  final WereadApiService _api = WereadApiService.instance;
  final WereadAuthService _auth = WereadAuthService.instance;

  /// 每个公众号默认获取的文章条数
  static const int _perMpArticleCount = 10;

  // ==================== 公开接口 ====================

  /// 获取所有已关注公众号的最新文章
  /// 遍历书架中的公众号，逐个拉取文章列表
  /// [maxCount] 最终返回的最大文章总数
  /// :return: 统一格式的消息列表
  Future<List<MessageItem>> fetchArticles({int maxCount = 50}) async {
    // 检查认证状态
    final hasCookie = await _auth.hasCookies();
    if (!hasCookie) return [];

    // 获取已关注的公众号 bookId 列表
    final mpBookIds = await _api.getFollowedMpBookIds();
    if (mpBookIds.isEmpty) return [];

    final allMessages = <MessageItem>[];

    // 逐个公众号获取文章
    for (final bookId in mpBookIds) {
      if (allMessages.length >= maxCount) break;

      final articles = await _api.getAllArticles(
        bookId,
        maxCount: _perMpArticleCount,
      );

      // 获取公众号名称（用作来源显示）
      final mpName = await _getMpName(bookId);

      for (final article in articles) {
        if (allMessages.length >= maxCount) break;

        final msgItem = _articleToMessageItem(article, mpName);
        if (msgItem != null) {
          allMessages.add(msgItem);
        }
      }
    }

    return allMessages;
  }

  /// 获取已关注的公众号列表（用于设置页展示）
  /// :return: 公众号信息列表 [{bookId, name, intro, cover}]
  Future<List<Map<String, String>>> getFollowedMpList() async {
    final hasCookie = await _auth.hasCookies();
    if (!hasCookie) return [];

    final mpBookIds = await _api.getFollowedMpBookIds();
    final mpList = <Map<String, String>>[];

    for (final bookId in mpBookIds) {
      final info = await _api.getBookInfo(bookId);
      if (info != null) {
        mpList.add({
          'bookId': bookId,
          'name': _extractString(info, 'title') ?? bookId,
          'intro': _extractString(info, 'intro') ?? '',
          'cover': _extractString(info, 'cover') ?? '',
        });
      } else {
        // 没有详情也保留条目
        mpList.add({'bookId': bookId, 'name': bookId, 'intro': '', 'cover': ''});
      }
    }

    return mpList;
  }

  // ==================== 内部转换方法 ====================

  /// 获取公众号名称
  /// 优先从 bookInfo 接口获取，失败则用 bookId 截断显示
  /// [bookId] 公众号 bookId
  /// :return: 公众号名称
  Future<String> _getMpName(String bookId) async {
    final info = await _api.getBookInfo(bookId);
    if (info != null) {
      return _extractString(info, 'title') ?? bookId;
    }
    return bookId;
  }

  /// 将 API 返回的文章数据转换为 MessageItem
  /// 适配微信读书 book/articles 接口的多种返回格式
  /// [article] 单篇文章的 JSON 数据
  /// [mpName] 公众号名称（用于兜底来源显示）
  /// :return: MessageItem 实例，无法解析时返回 null
  MessageItem? _articleToMessageItem(
    Map<String, dynamic> article,
    String mpName,
  ) {
    // 文章标题 — 可能在 review.mpInfo.title 或直接 title
    final title = _extractArticleTitle(article);
    if (title == null || title.isEmpty) return null;

    // 文章 URL — 微信读书可能提供 url 或 mp_url 字段
    final url = _extractArticleUrl(article);
    if (url == null || url.isEmpty) return null;

    // 发布日期 — Unix 时间戳转 YYYY-MM-DD
    final date = _extractArticleDate(article);

    // 使用 URL 的 MD5 作为唯一 ID（与其他渠道保持一致）
    final id = md5.convert(utf8.encode(url)).toString();

    return MessageItem(
      id: id,
      title: title,
      date: date,
      url: url,
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
    );
  }

  /// 从文章数据中提取标题
  /// 适配多种数据结构：
  /// - reviews[].review.mpInfo.title
  /// - reviews[].review.content
  /// - articles[].title
  /// - title
  /// [article] 文章 JSON 数据
  /// :return: 标题字符串
  String? _extractArticleTitle(Map<String, dynamic> article) {
    // 格式 1: review 嵌套结构
    final review = article['review'] as Map<String, dynamic>?;
    if (review != null) {
      final mpInfo = review['mpInfo'] as Map<String, dynamic>?;
      if (mpInfo != null) {
        final title = mpInfo['title']?.toString();
        if (title != null && title.isNotEmpty) return title;
      }
      // review.content 可能是标题
      final content = review['content']?.toString();
      if (content != null && content.isNotEmpty) return content;
    }

    // 格式 2: 直接 title 字段
    final directTitle = article['title']?.toString();
    if (directTitle != null && directTitle.isNotEmpty) return directTitle;

    return null;
  }

  /// 从文章数据中提取 URL
  /// 适配多种数据结构
  /// [article] 文章 JSON 数据
  /// :return: URL 字符串
  String? _extractArticleUrl(Map<String, dynamic> article) {
    // 格式 1: review 嵌套结构
    final review = article['review'] as Map<String, dynamic>?;
    if (review != null) {
      final mpInfo = review['mpInfo'] as Map<String, dynamic>?;
      if (mpInfo != null) {
        final mpUrl = mpInfo['originalUrl']?.toString();
        if (mpUrl != null && mpUrl.isNotEmpty) return mpUrl;
      }
    }

    // 格式 2: 直接字段
    final url = article['url']?.toString() ??
        article['originalUrl']?.toString() ??
        article['mp_url']?.toString();
    return url;
  }

  /// 从文章数据中提取发布日期并格式化为 YYYY-MM-DD
  /// [article] 文章 JSON 数据
  /// :return: 日期字符串，默认当天
  String _extractArticleDate(Map<String, dynamic> article) {
    // 尝试多个时间戳字段
    int? timestamp;

    final review = article['review'] as Map<String, dynamic>?;
    if (review != null) {
      final mpInfo = review['mpInfo'] as Map<String, dynamic>?;
      if (mpInfo != null) {
        timestamp = _toInt(mpInfo['create_time'] ?? mpInfo['publish_time']);
      }
      // review 自身的创建时间
      timestamp ??= _toInt(review['createTime'] ?? review['create_time']);
    }

    // 直接字段
    timestamp ??= _toInt(
      article['create_time'] ??
          article['publish_time'] ??
          article['createTime'],
    );

    if (timestamp != null && timestamp > 0) {
      // 微信时间戳为秒级（10位），需转为毫秒
      final ms = timestamp < 10000000000 ? timestamp * 1000 : timestamp;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    // 兜底：返回当天日期
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 安全提取 Map 中的字符串值
  /// [data] 数据 Map
  /// [key] 键名
  /// :return: 字符串值，不存在返回 null
  String? _extractString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  /// 安全转换为 int
  /// [value] 可能是 int、double 或 String
  /// :return: int 值，无法转换返回 null
  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
