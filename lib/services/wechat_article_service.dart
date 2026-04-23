/*
 * 微信公众号文章采集服务 — 统一封装公众号平台文章获取
 * Issue #47 起仅保留微信公众号平台方案，原微信读书链路仅做历史数据清理
 * @Project : SSPU-all-in-one
 * @File : wechat_article_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-20
 */

import '../models/message_item.dart';
import 'package:flutter/foundation.dart';
import 'message_state_service.dart';
import 'storage_service.dart';
import 'wxmp_article_service.dart';
import 'wxmp_auth_service.dart';

/// 微信公众号文章采集服务（单例）
/// 对外保留统一入口，内部仅代理公众号平台实现。
class WechatArticleService {
  WechatArticleService._();

  static final WechatArticleService instance = WechatArticleService._();

  final WxmpAuthService _auth = WxmpAuthService.instance;
  final WxmpArticleService _wxmpService = WxmpArticleService.instance;
  final MessageStateService _stateService = MessageStateService.instance;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[WechatArticleService] $message');
    }
  }

  /// 历史微信读书方案遗留的存储键。
  static const List<String> _legacyWereadKeys = [
    'wechat_fetch_method',
    'wechat_followed_mps',
    'weread_cookie_string',
    'weread_vid',
    'weread_skey',
    'weread_cookie_last_update',
  ];

  /// 清理已废弃的微信读书本地状态，避免旧配置影响当前公众号平台链路。
  Future<void> clearLegacyWereadState() async {
    for (final storageKey in _legacyWereadKeys) {
      await StorageService.remove(storageKey);
    }
  }

  /// 是否已完成公众号平台认证。
  Future<bool> hasConfiguredSource() async {
    return _auth.hasAuth();
  }

  /// 校验公众号平台认证是否仍可访问接口。
  Future<WxmpAuthValidationResult> validateSource() async {
    return _wxmpService.validateAuth();
  }

  /// 是否存在启用中的微信推文抓取项。
  Future<bool> hasEnabledRefreshTarget() async {
    final channelEnabled = await _stateService.isChannelEnabled(
      'wechat_public',
      defaultValue: false,
    );
    if (!channelEnabled) return false;

    final followedMps = await _wxmpService.getLocalFollowedMps();
    for (final entry in followedMps.entries) {
      if (await _stateService.isMpNotificationEnabled(entry.key)) {
        return true;
      }
    }
    return false;
  }

  /// 获取所有已关注公众号的最新文章。
  /// 若尚未完成公众号平台认证，则直接返回空列表。
  Future<List<MessageItem>> fetchArticles({
    int maxCount = 50,
    Set<String>? knownMessageIds,
    bool validateBeforeFetch = true,
    WxmpFetchProgressCallback? onAccountCompleted,
  }) async {
    _debugLog(
      'fetch articles start maxCount=$maxCount known=${knownMessageIds?.length ?? -1} validate=$validateBeforeFetch',
    );
    await clearLegacyWereadState();
    if (!await _auth.hasAuth()) {
      _debugLog('fetch articles skipped: auth unavailable');
      return [];
    }

    final articles = await _wxmpService.fetchArticles(
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
      validateBeforeFetch: validateBeforeFetch,
      onAccountCompleted: onAccountCompleted,
    );
    _debugLog('fetch articles done count=${articles.length}');
    return articles;
  }
}
