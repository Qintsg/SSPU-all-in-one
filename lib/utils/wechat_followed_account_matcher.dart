/*
 * 微信关注账号匹配工具 — 统一判断推荐账号与已关注公众号是否为同一项
 * @Project : SSPU-all-in-one
 * @File : wechat_followed_account_matcher.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import '../models/sspu_wechat_accounts.dart';

String _normalizeWechatIdentity(String value) => value.trim().toLowerCase();

/// 在已关注列表中查找与推荐账号对应的公众号记录。
/// 兼容历史数据和新持久化的推荐账号元信息，避免关注后 UI 仍显示“关注”按钮。
Map<String, String>? findFollowedWechatAccount(
  SspuWechatAccount account,
  List<Map<String, String>> followedMps,
) {
  final expectedIdentities = {
    _normalizeWechatIdentity(account.name),
    _normalizeWechatIdentity(account.wxAccount),
  }..remove('');

  for (final mp in followedMps) {
    final candidateIdentities = {
      _normalizeWechatIdentity(mp['name'] ?? ''),
      _normalizeWechatIdentity(mp['alias'] ?? ''),
      _normalizeWechatIdentity(mp['recommended_name'] ?? ''),
      _normalizeWechatIdentity(mp['recommended_wx_account'] ?? ''),
    }..remove('');

    if (candidateIdentities.any(expectedIdentities.contains)) {
      return mp;
    }
  }
  return null;
}
