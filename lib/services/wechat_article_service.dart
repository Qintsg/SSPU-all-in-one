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
import 'message_state_service.dart';
import 'storage_service.dart';
import 'weread_api_service.dart';
import 'weread_auth_service.dart';
import 'wxmp_article_service.dart';

/// 微信公众号文章采集服务（单例）
/// 通过微信读书 API 获取关注的公众号推文，转换为 MessageItem 统一格式
class WechatArticleService {
  WechatArticleService._();

  static final WechatArticleService instance = WechatArticleService._();

  final WereadApiService _api = WereadApiService.instance;
  final WereadAuthService _auth = WereadAuthService.instance;
  final MessageStateService _stateService = MessageStateService.instance;

  /// 本地关注列表的存储键（JSON 格式：{bookId: name, ...}）
  static const String _keyFollowedMps = 'wechat_followed_mps';

  /// 每个公众号默认获取的文章条数
  static const int _perMpArticleCount = 10;

  // ==================== 本地关注管理 ====================

  /// 获取本地存储的关注公众号列表
  /// :return: {bookId: name} 映射
  Future<Map<String, String>> getLocalFollowedMps() async {
    final json = await StorageService.getString(_keyFollowedMps);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// 保存本地关注列表
  Future<void> _saveLocalFollowedMps(Map<String, String> mps) async {
    await StorageService.setString(_keyFollowedMps, jsonEncode(mps));
  }

  /// 通过搜索关注公众号（虚拟关注，不依赖微信读书书架）
  /// 搜索公众号名称 → 获取 bookId → 存本地
  /// [keyword] 公众号名称
  /// :return: 关注结果 {bookId, name}; 失败返回 null
  Future<Map<String, String>?> followMpBySearch(String keyword) async {
    final hasCookie = await _auth.hasCookies();
    if (!hasCookie) return null;

    final searchResult = await _api.search(keyword);
    if (searchResult == null) return null;

    // 从搜索结果中找第一个公众号（bookId 以 MP_WXS_ 开头）
    final books = searchResult['books'] as List<dynamic>?;
    if (books == null || books.isEmpty) return null;

    for (final item in books) {
      final bookInfo = (item is Map) ? item['bookInfo'] as Map<String, dynamic>? : null;
      if (bookInfo == null) continue;

      final bookId = bookInfo['bookId']?.toString();
      final title = bookInfo['title']?.toString();
      if (bookId != null && bookId.startsWith('MP_WXS_') && title != null) {
        // 存入本地关注列表
        final mps = await getLocalFollowedMps();
        mps[bookId] = title;
        await _saveLocalFollowedMps(mps);
        return {'bookId': bookId, 'name': title};
      }
    }

    return null;
  }

  /// 从微信读书书架同步公众号到本地关注列表
  /// 调用书架API，提取 MP_WXS_ 开头的 bookId，合并到本地
  /// :return: 新增的公众号数量；失败返回 -1
  Future<int> syncFromShelf() async {
    final hasCookie = await _auth.hasCookies();
    if (!hasCookie) return -1;

    // 获取书架中的公众号 bookId
    final shelfMpIds = await _api.getFollowedMpBookIds();
    if (shelfMpIds.isEmpty) return 0;

    final localMps = await getLocalFollowedMps();
    var addedCount = 0;

    for (final bookId in shelfMpIds) {
      if (localMps.containsKey(bookId)) continue;

      // 尝试从API获取名称
      String mpName = bookId;
      final info = await _api.getBookInfo(bookId);
      if (info != null) {
        mpName = _extractString(info, 'title') ?? bookId;
      }

      localMps[bookId] = mpName;
      addedCount++;
    }

    if (addedCount > 0) {
      await _saveLocalFollowedMps(localMps);
    }
    return addedCount;
  }

  /// 直接用已知 bookId 和名称关注（用于 SSPU 推荐列表快速关注）
  /// [bookId] 公众号 bookId
  /// [name] 公众号名称
  Future<void> followMpDirectly(String bookId, String name) async {
    final mps = await getLocalFollowedMps();
    mps[bookId] = name;
    await _saveLocalFollowedMps(mps);
  }

  /// 取消关注公众号
  /// [bookId] 公众号 bookId
  Future<void> unfollowMp(String bookId) async {
    final mps = await getLocalFollowedMps();
    mps.remove(bookId);
    await _saveLocalFollowedMps(mps);
  }

  /// 检查是否已关注
  Future<bool> isFollowed(String bookId) async {
    final mps = await getLocalFollowedMps();
    return mps.containsKey(bookId);
  }

  // ==================== 公开接口 ====================

  /// 当前使用的获取方式存储键
  static const String _keyFetchMethod = 'wechat_fetch_method';

  /// 获取当前选择的获取方式
  /// :return: 'weread'（默认） 或 'wxmp'
  static Future<String> getFetchMethod() async {
    return (await StorageService.getString(_keyFetchMethod)) ?? 'weread';
  }

  /// 设置获取方式
  static Future<void> setFetchMethod(String method) async {
    await StorageService.setString(_keyFetchMethod, method);
  }

  /// 获取所有已关注公众号的最新文章
  /// 根据当前选择的方式委托给对应的服务
  /// [maxCount] 最终返回的最大文章总数
  /// :return: 统一格式的消息列表
  Future<List<MessageItem>> fetchArticles({int maxCount = 50}) async {
    // 方式路由：根据用户选择的方式委托
    final method = await getFetchMethod();
    if (method == 'wxmp') {
      return WxmpArticleService.instance.fetchArticles(maxCount: maxCount);
    }

    // 方式一：微信读书（默认）
    // 检查认证状态
    final hasCookie = await _auth.hasCookies();
    if (!hasCookie) return [];

    // 从本地存储获取关注的公众号 bookId 列表
    final followedMps = await getLocalFollowedMps();
    if (followedMps.isEmpty) return [];

    final allMessages = <MessageItem>[];

    // 逐个公众号获取文章（跳过通知关闭的公众号）
    for (final entry in followedMps.entries) {
      final bookId = entry.key;
      final mpName = entry.value;
      if (allMessages.length >= maxCount) break;

      // 检查该公众号的通知开关，关闭则跳过采集
      final mpEnabled = await _stateService.isMpNotificationEnabled(bookId);
      if (!mpEnabled) continue;

      final articles = await _api.getAllArticles(
        bookId,
        maxCount: _perMpArticleCount,
      );

      for (final article in articles) {
        if (allMessages.length >= maxCount) break;

        final msgItem = _articleToMessageItem(article, mpName, bookId);
        if (msgItem != null) {
          allMessages.add(msgItem);
        }
      }
    }

    return allMessages;
  }

  /// 获取已关注的公众号列表（用于设置页展示）
  /// 从本地存储读取，不再依赖微信读书书架
  /// :return: 公众号信息列表 [{bookId, name, intro, cover}]
  Future<List<Map<String, String>>> getFollowedMpList() async {
    final followedMps = await getLocalFollowedMps();
    if (followedMps.isEmpty) return [];

    final mpList = <Map<String, String>>[];

    // 尝试从 API 获取详细信息（如果有 Cookie）
    final hasCookie = await _auth.hasCookies();

    for (final entry in followedMps.entries) {
      final bookId = entry.key;
      final localName = entry.value;

      if (hasCookie) {
        final info = await _api.getBookInfo(bookId);
        if (info != null) {
          mpList.add({
            'bookId': bookId,
            'name': _extractString(info, 'title') ?? localName,
            'intro': _extractString(info, 'intro') ?? '',
            'cover': _extractString(info, 'cover') ?? '',
          });
          continue;
        }
      }

      // API 不可用时用本地名称
      mpList.add({
        'bookId': bookId,
        'name': localName,
        'intro': '',
        'cover': '',
      });
    }

    return mpList;
  }

  // ==================== 内部转换方法 ====================

  /// 将 API 返回的文章数据转换为 MessageItem
  /// 适配微信读书 book/articles 接口的多种返回格式
  /// [article] 单篇文章的 JSON 数据
  /// [mpName] 公众号名称（用于兜底来源显示）
  /// [bookId] 公众号 bookId（用于 per-account 标识）
  /// :return: MessageItem 实例，无法解析时返回 null
  MessageItem? _articleToMessageItem(
    Map<String, dynamic> article,
    String mpName,
    String bookId,
  ) {
    // 文章标题 — 可能在 review.mpInfo.title 或直接 title
    final title = _extractArticleTitle(article);
    if (title == null || title.isEmpty) return null;

    // 文章 URL — 微信读书可能提供 url 或 mp_url 字段
    final url = _extractArticleUrl(article, bookId);
    if (url == null || url.isEmpty) return null;

    // 发布日期 — Unix 时间戳转 YYYY-MM-DD
    final dateInfo = _extractArticleDateInfo(article);

    // 使用 URL 的 MD5 作为唯一 ID（与其他渠道保持一致）
    final id = md5.convert(utf8.encode(url)).toString();

    return MessageItem(
      id: id,
      title: title,
      date: dateInfo.date,
      url: url,
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
      mpBookId: bookId,
      mpName: mpName,
      timestamp: dateInfo.timestampMs,
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
  String? _extractArticleUrl(Map<String, dynamic> article, String bookId) {
    // 格式 1: review 嵌套结构 — 尝试 mpInfo 中的直接 URL 字段
    final review = article['review'] as Map<String, dynamic>?;
    if (review != null) {
      final mpInfo = review['mpInfo'] as Map<String, dynamic>?;
      if (mpInfo != null) {
        final mpUrl = mpInfo['originalUrl']?.toString();
        if (mpUrl != null && mpUrl.isNotEmpty) return mpUrl;
        final docUrl = mpInfo['doc_url']?.toString();
        if (docUrl != null && docUrl.isNotEmpty) return docUrl;
      }
    }

    // 格式 2: 用 bookId 编码构造微信读书 MP Reader URL
    final reviewId = article['reviewId']?.toString() ??
        review?['reviewId']?.toString();
    if (reviewId != null && reviewId.isNotEmpty) {
      final bookStrId = calculateBookStrId(bookId);
      return 'https://weread.qq.com/web/mp/reader/$bookStrId?reviewId=${Uri.encodeComponent(reviewId)}';
    }

    // 格式 3: 直接字段
    final url =
        article['url']?.toString() ??
        article['originalUrl']?.toString() ??
        article['mp_url']?.toString();
    return url;
  }

  /// 从文章数据中提取发布日期和精确时间戳
  /// [article] 文章 JSON 数据
  /// :return: ({date: 'YYYY-MM-DD', timestampMs: int?})
  ({String date, int? timestampMs}) _extractArticleDateInfo(Map<String, dynamic> article) {
    // 尝试多个时间戳字段
    int? timestamp;

    final review = article['review'] as Map<String, dynamic>?;
    if (review != null) {
      final mpInfo = review['mpInfo'] as Map<String, dynamic>?;
      if (mpInfo != null) {
        timestamp = _toInt(mpInfo['time'] ?? mpInfo['create_time'] ?? mpInfo['publish_time']);
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
      final date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      return (date: date, timestampMs: ms);
    }

    // 兜底：返回当天日期和当前时间戳
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return (date: date, timestampMs: now.millisecondsSinceEpoch);
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

  // ==================== bookId 编码 ====================

  /// 将 bookId 编码为微信读书 reader URL 中的 infoId
  static String calculateBookStrId(String bookId) {
    final digest = md5.convert(utf8.encode(bookId)).toString();
    final buf = StringBuffer(digest.substring(0, 3));

    final (code, transformedIds) = _transformId(bookId);
    buf.write(code);
    buf.write('2');
    buf.write(digest.substring(digest.length - 2));

    for (var i = 0; i < transformedIds.length; i++) {
      var hexLen = transformedIds[i].length.toRadixString(16);
      if (hexLen.length == 1) hexLen = '0$hexLen';
      buf.write(hexLen);
      buf.write(transformedIds[i]);
      if (i < transformedIds.length - 1) buf.write('g');
    }

    var result = buf.toString();
    if (result.length < 20) {
      result += digest.substring(0, 20 - result.length);
    }
    result += md5.convert(utf8.encode(result)).toString().substring(0, 3);
    return result;
  }

  static (String, List<String>) _transformId(String bookId) {
    final isNumeric = bookId.codeUnits.every((c) => c >= 48 && c <= 57);
    if (isNumeric) {
      final ary = <String>[];
      for (var i = 0; i < bookId.length; i += 9) {
        final end = (i + 9 > bookId.length) ? bookId.length : i + 9;
        ary.add(int.parse(bookId.substring(i, end)).toRadixString(16));
      }
      return ('3', ary);
    }
    final buf = StringBuffer();
    for (var i = 0; i < bookId.length; i++) {
      buf.write(bookId.codeUnitAt(i).toRadixString(16));
    }
    return ('4', [buf.toString()]);
  }
}
