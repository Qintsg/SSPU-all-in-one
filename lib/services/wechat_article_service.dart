/*
 * 微信公众号文章采集服务 — 统一封装公众号平台文章获取
 * Issue #47 起仅保留微信公众号平台方案，原微信读书链路仅做历史数据清理
 * @Project : SSPU-all-in-one
 * @File : wechat_article_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-20
 */

import '../models/message_item.dart';
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

  /// 获取所有已关注公众号的最新文章。
  /// 若尚未完成公众号平台认证，则直接返回空列表。
  Future<List<MessageItem>> fetchArticles({
    int maxCount = 50,
    Set<String>? knownMessageIds,
  }) async {
    await clearLegacyWereadState();
    if (!await _auth.hasAuth()) return [];

    return _wxmpService.fetchArticles(
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }
}
