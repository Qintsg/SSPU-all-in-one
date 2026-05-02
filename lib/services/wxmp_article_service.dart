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

part 'wxmp_article_fetch.dart';
part 'wxmp_article_following.dart';

typedef WxmpFetchProgressCallback =
    Future<void> Function(
      List<MessageItem> messages,
      int completed,
      int total,
      String accountName,
    );

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

@visibleForTesting
String debugResolveWxmpAccountName(Map<String, String> mpInfo, String fakeid) {
  return WxmpArticleService.instance._resolveAccountName(mpInfo, fakeid);
}

@visibleForTesting
String? debugResolveWxmpAccountDisplayId(Map<String, String> mpInfo) {
  return WxmpArticleService.instance._resolveAccountDisplayId(mpInfo);
}

@visibleForTesting
MessageItem? debugArticleToMessageItem(
  Map<String, dynamic> article, {
  required String mpName,
  required String fakeid,
  String? mpDisplayId,
}) {
  return WxmpArticleService.instance._articleToMessageItem(
    article,
    mpName,
    fakeid,
    mpDisplayId: mpDisplayId,
  );
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
    return freshToken;
  }

  /// 当前 token 失效时自动刷新 token 并重试一次。
  Future<T> _withTokenRefreshRetry<T>(
    String operationName,
    Future<T> Function(String token) request,
  ) async {
    assert(operationName.isNotEmpty, 'operationName must not be empty');
    final currentToken = await _auth.getToken();
    try {
      return await request(currentToken ?? '');
    } on WxmpInvalidCsrfException {
      final freshToken = await _refreshTokenFromCookie();
      return request(freshToken);
    }
  }

  /// 读取配置失败时使用默认值，避免配置文件损坏影响扫码登录链路。
  Future<WxmpConfig> _loadConfigOrDefault() async {
    try {
      return await _configService.loadConfig();
    } catch (error) {
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
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) {
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
        return _checkResponse(data);
      });
      return validationResultForRet(ret);
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
    } on WxmpInvalidCsrfException {
      return validationResultForRet(WxmpApiError.invalidCsrfToken);
    } catch (error) {
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
    if (!authStatus.isUsable) return [];

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
    if (!authStatus.isUsable) return [];

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
