/*
 * 微信公众号平台文章采集服务 — 通过 mp.weixin.qq.com API 获取文章
 * 作为公众号平台链路的文章获取实现
 * 使用 Dio HTTP 客户端直接调用公众号管理平台 API
 * @Project : SSPU-all-in-one
 * @File : wxmp_article_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-22
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/message_item.dart';
import 'message_state_service.dart';
import 'storage_service.dart';
import 'wxmp_auth_service.dart';
import 'wxmp_config_service.dart';

/// 公众号平台 API 错误码
class WxmpApiError {
  static const int success = 0;
  static const int sessionExpired = 200003;
  static const int frequencyLimit = 200013;
}

/// 公众号平台认证有效性校验结果。
class WxmpAuthValidationResult {
  /// 是否通过本地字段和平台接口校验。
  final bool isValid;

  /// 面向用户展示的校验结论。
  final String message;

  const WxmpAuthValidationResult({
    required this.isValid,
    required this.message,
  });
}

/// 微信公众号平台文章采集服务（单例）
/// 通过 mp.weixin.qq.com 的 cgi-bin API 搜索公众号、获取文章列表
class WxmpArticleService {
  WxmpArticleService._();
  static final WxmpArticleService instance = WxmpArticleService._();

  final WxmpAuthService _auth = WxmpAuthService.instance;
  final MessageStateService _stateService = MessageStateService.instance;
  final WxmpConfigService _configService = WxmpConfigService.instance;
  final Dio _dio = Dio();

  /// 本地关注列表存储键（JSON：{fakeid: {name, alias, avatar}}）
  static const String _keyFollowedMps = 'wxmp_followed_mps';

  /// 标准 User-Agent
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

  // ==================== HTTP 请求 ====================

  /// 输出脱敏调试日志；Release 构建不输出。
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[WxmpArticleService] $message');
    }
  }

  /// 读取配置失败时使用默认值，避免配置文件损坏影响扫码登录链路。
  Future<WxmpConfig> _loadConfigOrDefault() async {
    try {
      return await _configService.loadConfig();
    } catch (error) {
      _debugLog('config fallback to defaults: $error');
      return WxmpConfig.defaults();
    }
  }

  /// 构造标准请求头
  Future<Map<String, String>> _buildHeaders() async {
    final cookie = await _auth.getCookie();
    final config = await _loadConfigOrDefault();
    return {
      'Cookie': cookie ?? '',
      'User-Agent': config.userAgent.isEmpty ? _userAgent : config.userAgent,
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': 'https://mp.weixin.qq.com/',
    };
  }

  /// 检查 API 响应的错误码
  /// 返回 ret 值；成功返回 0
  /// 如果 session 过期（200003）或频率限制（200013），抛出特定异常
  int _checkResponse(Map<String, dynamic> data) {
    final baseResp = data['base_resp'] as Map<String, dynamic>?;
    if (baseResp == null) return -1;
    final ret = baseResp['ret'] as int? ?? -1;
    if (ret == WxmpApiError.sessionExpired) {
      throw WxmpSessionExpiredException('Session 失效，请重新登录');
    }
    if (ret == WxmpApiError.frequencyLimit) {
      throw WxmpFrequencyLimitException('请求频率过快，请稍后再试');
    }
    return ret;
  }

  /// 校验当前 Cookie / Token 是否能访问公众号平台接口。
  /// 使用轻量搜索接口探测登录态，避免刷新文章时才暴露会话失效。
  Future<WxmpAuthValidationResult> validateAuth() async {
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      return WxmpAuthValidationResult(
        isValid: false,
        message: authStatus.message,
      );
    }

    try {
      final token = await _auth.getToken();
      final config = await _loadConfigOrDefault();
      final queryParameters = <String, Object?>{
        'action': 'search_biz',
        'begin': 0,
        'count': 1,
        'query': '上海第二工业大学',
        'token': token,
        'lang': 'zh_CN',
        'f': 'json',
        'ajax': '1',
      };
      if (config.appId.trim().isNotEmpty) {
        queryParameters['appid'] = config.appId.trim();
      }

      final response = await _dio.get(
        'https://mp.weixin.qq.com/cgi-bin/searchbiz',
        queryParameters: queryParameters,
        options: Options(headers: await _buildHeaders()),
      );
      final data = response.data as Map<String, dynamic>;
      final ret = _checkResponse(data);
      if (ret == WxmpApiError.success) {
        return const WxmpAuthValidationResult(
          isValid: true,
          message: '认证有效，可正常访问公众号平台接口',
        );
      }
      return WxmpAuthValidationResult(
        isValid: false,
        message: '公众号平台返回异常状态：$ret',
      );
    } on WxmpSessionExpiredException {
      return const WxmpAuthValidationResult(
        isValid: false,
        message: '会话已过期，请重新扫码登录',
      );
    } on WxmpFrequencyLimitException {
      return const WxmpAuthValidationResult(
        isValid: false,
        message: '平台限制了当前请求频率，请稍后再试',
      );
    } catch (error) {
      _debugLog('auth validation failed: $error');
      return WxmpAuthValidationResult(isValid: false, message: '认证校验失败：$error');
    }
  }

  // ==================== 搜索公众号 ====================

  /// 搜索公众号
  /// [keyword] 搜索关键词（公众号名称）
  /// [begin] 偏移量（分页用，默认 0）
  /// [count] 每页数量（默认 5）
  /// :return: 搜索结果列表 [{fakeid, nickname, alias, round_head_img}]
  Future<List<Map<String, String>>> searchMp(
    String keyword, {
    int begin = 0,
    int count = 5,
  }) async {
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('search skipped: ${authStatus.message}');
      return [];
    }

    final token = await _auth.getToken();
    final config = await _loadConfigOrDefault();
    final headers = await _buildHeaders();
    final queryParameters = <String, Object?>{
      'action': 'search_biz',
      'begin': begin,
      'count': count,
      'query': keyword,
      'token': token,
      'lang': 'zh_CN',
      'f': 'json',
      'ajax': '1',
    };
    if (config.appId.trim().isNotEmpty) {
      queryParameters['appid'] = config.appId.trim();
    }

    final response = await _dio.get(
      'https://mp.weixin.qq.com/cgi-bin/searchbiz',
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );

    final data = response.data as Map<String, dynamic>;
    final ret = _checkResponse(data);
    if (ret != WxmpApiError.success) return [];

    final list = data['list'] as List<dynamic>? ?? [];
    return list.map<Map<String, String>>((item) {
      final map = item as Map<String, dynamic>;
      return {
        'fakeid': map['fakeid']?.toString() ?? '',
        'nickname': map['nickname']?.toString() ?? '',
        'alias': map['alias']?.toString() ?? '',
        'round_head_img': map['round_head_img']?.toString() ?? '',
      };
    }).toList();
  }

  // ==================== 获取文章列表 ====================

  /// 获取指定公众号的文章列表
  /// [fakeid] 公众号唯一标识
  /// [page] 页码（从 0 开始）
  /// [count] 每页数量（默认 5）
  /// :return: 文章列表 [{aid, title, link, cover, digest, update_time, create_time}]
  Future<List<Map<String, dynamic>>> getArticles(
    String fakeid, {
    int page = 0,
    int count = 5,
  }) async {
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('article list skipped: ${authStatus.message}');
      return [];
    }

    final token = await _auth.getToken();
    final config = await _loadConfigOrDefault();
    final headers = await _buildHeaders();
    final queryParameters = <String, Object?>{
      'sub': 'list',
      'sub_action': 'list_ex',
      'begin': page * count,
      'count': count,
      'fakeid': fakeid,
      'token': token,
      'lang': 'zh_CN',
      'f': 'json',
      'ajax': 1,
    };
    if (config.appId.trim().isNotEmpty) {
      queryParameters['appid'] = config.appId.trim();
    }

    final response = await _dio.get(
      'https://mp.weixin.qq.com/cgi-bin/appmsgpublish',
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );

    final data = response.data as Map<String, dynamic>;
    final ret = _checkResponse(data);
    if (ret != WxmpApiError.success) return [];

    // publish_page 是 JSON 字符串，需二次解析
    final publishPageStr = data['publish_page'] as String?;
    if (publishPageStr == null || publishPageStr.isEmpty) return [];

    final publishPage = jsonDecode(publishPageStr) as Map<String, dynamic>;
    final publishList = publishPage['publish_list'] as List<dynamic>? ?? [];

    final articles = <Map<String, dynamic>>[];
    for (final item in publishList) {
      final itemMap = item as Map<String, dynamic>;
      // publish_info 也是 JSON 字符串，需再次解析
      final publishInfoStr = itemMap['publish_info'] as String?;
      if (publishInfoStr == null || publishInfoStr.isEmpty) continue;

      final publishInfo = jsonDecode(publishInfoStr) as Map<String, dynamic>;
      final appmsgex = publishInfo['appmsgex'] as List<dynamic>? ?? [];

      for (final article in appmsgex) {
        final artMap = article as Map<String, dynamic>;
        // 跳过已删除文章
        if (artMap['is_deleted'] == true) continue;
        articles.add(artMap);
      }
    }

    return articles;
  }

  // ==================== 统一获取文章 ====================

  /// 获取所有已关注公众号的最新文章，转为 MessageItem
  /// [maxCount] 单个公众号最多读取的文章数上限
  /// [knownMessageIds] 已持久化消息 ID，用于遇到旧文章时停止当前公众号解析
  Future<List<MessageItem>> fetchArticles({
    int maxCount = 50,
    Set<String>? knownMessageIds,
    bool validateBeforeFetch = true,
  }) async {
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('refresh skipped: ${authStatus.message}');
      return [];
    }
    if (validateBeforeFetch) {
      final validation = await validateAuth();
      if (!validation.isValid) {
        _debugLog('refresh skipped: ${validation.message}');
        return [];
      }
    }

    final followedMps = await getLocalFollowedMps();
    if (followedMps.isEmpty) return [];

    final storedMessageIds =
        knownMessageIds ??
        (await _stateService.loadMessages()).map((msg) => msg.id).toSet();
    final allMessages = <MessageItem>[];
    final config = await _loadConfigOrDefault();
    final perRequestLimit = config.perRequestArticleCount;
    final requestDelayMs = config.requestDelayMs;
    for (final entry in followedMps.entries) {
      final fakeid = entry.key;
      final mpInfo = entry.value;
      final mpName = mpInfo['name'] ?? fakeid;
      final perRequestCount = maxCount > 0 && maxCount < perRequestLimit
          ? maxCount
          : perRequestLimit;
      var fetchedForMp = 0;
      var page = 0;
      var reachedKnownMessage = false;

      try {
        while (fetchedForMp < maxCount && !reachedKnownMessage) {
          final articles = await getArticles(
            fakeid,
            page: page,
            count: perRequestCount,
          );
          if (articles.isEmpty) break;

          for (final article in articles) {
            final msgItem = _articleToMessageItem(article, mpName, fakeid);
            if (msgItem == null) continue;
            if (storedMessageIds.contains(msgItem.id)) {
              reachedKnownMessage = true;
              break;
            }
            allMessages.add(msgItem);
            fetchedForMp++;
            if (fetchedForMp >= maxCount) break;
          }

          if (articles.length < perRequestCount) break;
          page++;

          // 翻页请求同样需要限速，避免单个公众号连续请求触发平台限制。
          if (fetchedForMp < maxCount && !reachedKnownMessage) {
            await Future.delayed(Duration(milliseconds: requestDelayMs));
          }
        }

        // 请求间隔，避免频率限制
        if (followedMps.length > 1 && requestDelayMs > 0) {
          await Future.delayed(Duration(milliseconds: requestDelayMs));
        }
      } on WxmpSessionExpiredException {
        _debugLog('refresh stopped: session expired');
        // Session 过期，停止后续请求
        break;
      } on WxmpFrequencyLimitException {
        _debugLog('refresh stopped: frequency limited');
        // 频率限制，停止后续请求
        break;
      } catch (error) {
        _debugLog('refresh skipped one account "$mpName": $error');
        // 单个公众号失败不影响其他
        continue;
      }
    }

    return allMessages;
  }

  // ==================== 本地关注管理 ====================

  /// 获取本地关注的公众号列表
  /// :return: {fakeid: {name, alias, avatar}}
  Future<Map<String, Map<String, String>>> getLocalFollowedMps() async {
    final json = await StorageService.getString(_keyFollowedMps);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) {
        final info = v as Map<String, dynamic>;
        return MapEntry(k, info.map((ik, iv) => MapEntry(ik, iv.toString())));
      });
    } catch (_) {
      return {};
    }
  }

  /// 关注公众号
  Future<void> followMp(
    String fakeid,
    String name, {
    String? alias,
    String? avatar,
  }) async {
    final mps = await getLocalFollowedMps();
    mps[fakeid] = {'name': name, 'alias': alias ?? '', 'avatar': avatar ?? ''};
    await StorageService.setString(_keyFollowedMps, jsonEncode(mps));
  }

  /// 取消关注
  Future<void> unfollowMp(String fakeid) async {
    final mps = await getLocalFollowedMps();
    mps.remove(fakeid);
    await StorageService.setString(_keyFollowedMps, jsonEncode(mps));
  }

  /// 检查是否已关注
  Future<bool> isFollowed(String fakeid) async {
    final mps = await getLocalFollowedMps();
    return mps.containsKey(fakeid);
  }

  /// 获取已关注公众号的展示列表
  Future<List<Map<String, String>>> getFollowedMpList() async {
    final mps = await getLocalFollowedMps();
    return mps.entries.map((e) {
      return {
        'fakeid': e.key,
        'name': e.value['name'] ?? '',
        'alias': e.value['alias'] ?? '',
        'avatar': e.value['avatar'] ?? '',
      };
    }).toList();
  }

  // ==================== 内部转换 ====================

  /// 将公众号平台 API 返回的文章数据转为 MessageItem
  MessageItem? _articleToMessageItem(
    Map<String, dynamic> article,
    String mpName,
    String fakeid,
  ) {
    final title = article['title']?.toString();
    if (title == null || title.isEmpty) return null;

    final link = article['link']?.toString();
    if (link == null || link.isEmpty) return null;

    // 日期处理
    final rawTimestamp = article['update_time'] ?? article['create_time'];
    String date;
    int? timestampMs;
    if (rawTimestamp is int && rawTimestamp > 0) {
      final ms = rawTimestamp < 10000000000
          ? rawTimestamp * 1000
          : rawTimestamp;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      date =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      timestampMs = ms;
    } else {
      final now = DateTime.now();
      date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      timestampMs = now.millisecondsSinceEpoch;
    }

    final id = md5.convert(utf8.encode(link)).toString();

    return MessageItem(
      id: id,
      title: title,
      date: date,
      url: link,
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
      mpBookId: fakeid,
      mpName: mpName,
      timestamp: timestampMs,
    );
  }
}

/// Session 过期异常
class WxmpSessionExpiredException implements Exception {
  final String message;
  WxmpSessionExpiredException(this.message);
  @override
  String toString() => message;
}

/// 频率限制异常
class WxmpFrequencyLimitException implements Exception {
  final String message;
  WxmpFrequencyLimitException(this.message);
  @override
  String toString() => message;
}
