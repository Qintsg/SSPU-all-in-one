/*
 * 微信公众号平台文章采集服务 — 通过 mp.weixin.qq.com API 获取文章
 * 作为公众号平台链路的文章获取实现
 * 使用 Dio HTTP 客户端直接调用公众号管理平台 API
 * @Project : SSPU-all-in-one
 * @File : wxmp_article_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
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
  static const int invalidCsrfToken = 200040;
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

@visibleForTesting
WxmpAuthValidationResult debugValidationResultForRet(int ret) {
  return WxmpArticleService.validationResultForRet(ret);
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

  /// 对 fakeid 做脱敏，日志只保留排查所需的定位能力。
  String _maskFakeid(String fakeid) {
    if (fakeid.length <= 8) return '***';
    return '${fakeid.substring(0, 4)}***${fakeid.substring(fakeid.length - 4)}';
  }

  /// 记录公众号平台响应状态，不输出 Cookie / Token 等敏感字段。
  void _logApiRet(String endpoint, Map<String, dynamic> data) {
    final baseResp = data['base_resp'] as Map<String, dynamic>?;
    final ret = baseResp?['ret'];
    final errMsg = baseResp?['err_msg'];
    _debugLog('$endpoint response ret=$ret err_msg=$errMsg');
  }

  /// 使用当前 Cookie 打开公众平台首页并提取最新 token。
  /// 公众号平台 token 会变化；Cookie 仍有效时可从首页恢复新的 token。
  Future<String> _refreshTokenFromCookie() async {
    final cookie = await _auth.getCookie();
    if (cookie == null || cookie.trim().isEmpty) {
      throw WxmpInvalidCsrfException('缺少 Cookie，无法刷新 Token');
    }

    final config = await _loadConfigOrDefault();
    final response = await _dio.get(
      'https://mp.weixin.qq.com/',
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Cookie': cookie,
          'User-Agent': config.userAgent.isEmpty
              ? _userAgent
              : config.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );

    final htmlText = response.data?.toString() ?? '';
    final urlTokenMatch = RegExp(r'token=(\d+)').firstMatch(htmlText);
    final jsonTokenMatch = RegExp(
      r'"token"\s*:\s*"?(\d+)"?',
    ).firstMatch(htmlText);
    final freshToken = urlTokenMatch?.group(1) ?? jsonTokenMatch?.group(1);
    if (freshToken == null || freshToken.isEmpty) {
      throw WxmpInvalidCsrfException('Cookie 有效性不足，无法从首页提取 Token');
    }

    await _auth.saveAuth(cookie, freshToken);
    _debugLog('token refreshed from mp home page');
    return freshToken;
  }

  /// 当前 token 失效时自动刷新 token 并重试一次。
  Future<T> _withTokenRefreshRetry<T>(
    String operationName,
    Future<T> Function(String token) request,
  ) async {
    final currentToken = await _auth.getToken();
    try {
      return await request(currentToken ?? '');
    } on WxmpInvalidCsrfException {
      _debugLog('$operationName invalid csrf; refreshing token and retrying');
      final freshToken = await _refreshTokenFromCookie();
      return request(freshToken);
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
  /// 如果 session 过期（200003）、频率限制（200013）或 CSRF 失效（200040），抛出特定异常
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
    if (ret == WxmpApiError.invalidCsrfToken) {
      throw WxmpInvalidCsrfException('CSRF Token 无效，请重新扫码登录');
    }
    return ret;
  }

  /// 将公众号平台业务错误码转换为认证校验结果。
  /// 200040 表示 Cookie 与 Token 不匹配，通常是扫码页提取的路径 Cookie 不完整。
  @visibleForTesting
  static WxmpAuthValidationResult validationResultForRet(int ret) {
    if (ret == WxmpApiError.success) {
      return const WxmpAuthValidationResult(
        isValid: true,
        message: '认证有效，可正常访问公众号平台接口',
      );
    }
    if (ret == WxmpApiError.invalidCsrfToken) {
      return const WxmpAuthValidationResult(
        isValid: false,
        message: '公众号平台 CSRF 校验失败，请重新扫码登录以刷新完整 Cookie',
      );
    }
    return WxmpAuthValidationResult(
      isValid: false,
      message: '公众号平台返回异常状态：$ret',
    );
  }

  /// 校验当前 Cookie / Token 是否能访问公众号平台接口。
  /// 使用轻量搜索接口探测登录态，避免刷新文章时才暴露会话失效。
  Future<WxmpAuthValidationResult> validateAuth() async {
    _debugLog('validate auth start');
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('validate auth skipped: ${authStatus.message}');
      return WxmpAuthValidationResult(
        isValid: false,
        message: authStatus.message,
      );
    }

    try {
      final config = await _loadConfigOrDefault();
      final ret = await _withTokenRefreshRetry('validate/searchbiz', (
        token,
      ) async {
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
        _logApiRet('validate/searchbiz', data);
        return _checkResponse(data);
      });
      final result = validationResultForRet(ret);
      _debugLog(
        'validate auth result valid=${result.isValid} message=${result.message}',
      );
      return result;
    } on WxmpSessionExpiredException {
      _debugLog('validate auth failed: session expired');
      return const WxmpAuthValidationResult(
        isValid: false,
        message: '会话已过期，请重新扫码登录',
      );
    } on WxmpFrequencyLimitException {
      _debugLog('validate auth failed: frequency limited');
      return const WxmpAuthValidationResult(
        isValid: false,
        message: '平台限制了当前请求频率，请稍后再试',
      );
    } on WxmpInvalidCsrfException {
      _debugLog('validate auth failed: invalid csrf token');
      return validationResultForRet(WxmpApiError.invalidCsrfToken);
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
    _debugLog('search mp start keyword="$keyword" begin=$begin count=$count');
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('search skipped: ${authStatus.message}');
      return [];
    }

    final config = await _loadConfigOrDefault();
    final data = await _withTokenRefreshRetry('searchbiz', (token) async {
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
      return response.data as Map<String, dynamic>;
    });

    _logApiRet('searchbiz', data);
    final ret = _checkResponse(data);
    if (ret != WxmpApiError.success) {
      _debugLog('search mp returned non-success ret=$ret');
      return [];
    }

    final list = data['list'] as List<dynamic>? ?? [];
    _debugLog('search mp success result_count=${list.length}');
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
    _debugLog(
      'get articles start fakeid=${_maskFakeid(fakeid)} page=$page count=$count',
    );
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('article list skipped: ${authStatus.message}');
      return [];
    }

    final config = await _loadConfigOrDefault();
    final data = await _withTokenRefreshRetry('appmsgpublish', (token) async {
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
      return response.data as Map<String, dynamic>;
    });

    _logApiRet('appmsgpublish', data);
    final ret = _checkResponse(data);
    if (ret != WxmpApiError.success) {
      _debugLog(
        'get articles non-success ret=$ret fakeid=${_maskFakeid(fakeid)}',
      );
      return [];
    }

    // publish_page 是 JSON 字符串，需二次解析
    final publishPageStr = data['publish_page'] as String?;
    if (publishPageStr == null || publishPageStr.isEmpty) {
      _debugLog(
        'get articles empty publish_page fakeid=${_maskFakeid(fakeid)}',
      );
      return [];
    }

    final publishPage = jsonDecode(publishPageStr) as Map<String, dynamic>;
    final publishList = publishPage['publish_list'] as List<dynamic>? ?? [];
    _debugLog(
      'get articles publish_list_count=${publishList.length} fakeid=${_maskFakeid(fakeid)}',
    );

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

    _debugLog(
      'get articles parsed_count=${articles.length} fakeid=${_maskFakeid(fakeid)} page=$page',
    );
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
    _debugLog(
      'refresh start maxCount=$maxCount known=${knownMessageIds?.length ?? -1} validate=$validateBeforeFetch',
    );
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
      _debugLog('refresh skipped: ${authStatus.message}');
      return [];
    }
    if (validateBeforeFetch) {
      final validation = await validateAuth();
      _debugLog(
        'refresh validation valid=${validation.isValid} message=${validation.message}',
      );
      if (!validation.isValid) {
        _debugLog('refresh skipped: ${validation.message}');
        return [];
      }
    }

    final followedMps = await getLocalFollowedMps();
    _debugLog('refresh followed account count=${followedMps.length}');
    if (followedMps.isEmpty) {
      _debugLog('refresh skipped: no followed mp accounts');
      return [];
    }

    final storedMessageIds =
        knownMessageIds ??
        (await _stateService.loadMessages()).map((msg) => msg.id).toSet();
    final allMessages = <MessageItem>[];
    final config = await _loadConfigOrDefault();
    final perRequestLimit = config.perRequestArticleCount;
    final requestDelayMs = config.requestDelayMs;
    _debugLog(
      'refresh config perRequestLimit=$perRequestLimit requestDelayMs=$requestDelayMs',
    );
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
        _debugLog(
          'refresh account start name="$mpName" fakeid=${_maskFakeid(fakeid)} perRequestCount=$perRequestCount',
        );
        while (fetchedForMp < maxCount && !reachedKnownMessage) {
          final articles = await getArticles(
            fakeid,
            page: page,
            count: perRequestCount,
          );
          _debugLog(
            'refresh account page result name="$mpName" page=$page articles=${articles.length}',
          );
          if (articles.isEmpty) break;

          for (final article in articles) {
            final msgItem = _articleToMessageItem(article, mpName, fakeid);
            if (msgItem == null) continue;
            if (storedMessageIds.contains(msgItem.id)) {
              _debugLog(
                'refresh account reached known message name="$mpName" title="${msgItem.title}"',
              );
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
        _debugLog(
          'refresh account done name="$mpName" fetched=$fetchedForMp reachedKnown=$reachedKnownMessage',
        );

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
      } on WxmpInvalidCsrfException {
        _debugLog('refresh stopped: invalid csrf token');
        break;
      } catch (error) {
        _debugLog('refresh skipped one account "$mpName": $error');
        // 单个公众号失败不影响其他
        continue;
      }
    }

    _debugLog('refresh done total_new=${allMessages.length}');
    return allMessages;
  }

  // ==================== 本地关注管理 ====================

  /// 获取本地关注的公众号列表
  /// :return: {fakeid: {name, alias, avatar}}
  Future<Map<String, Map<String, String>>> getLocalFollowedMps() async {
    final json = await StorageService.getString(_keyFollowedMps);
    if (json == null || json.isEmpty) {
      _debugLog('followed mp storage empty');
      return {};
    }
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final result = decoded.map((k, v) {
        final info = v as Map<String, dynamic>;
        return MapEntry(k, info.map((ik, iv) => MapEntry(ik, iv.toString())));
      });
      _debugLog('followed mp storage loaded count=${result.length}');
      return result;
    } catch (error) {
      _debugLog('followed mp storage parse failed: $error');
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

/// CSRF Token 无效异常
class WxmpInvalidCsrfException implements Exception {
  final String message;
  WxmpInvalidCsrfException(this.message);
  @override
  String toString() => message;
}
