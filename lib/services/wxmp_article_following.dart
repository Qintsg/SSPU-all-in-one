/*
 * 微信公众号平台关注管理 — 本地关注列表与文章模型转换
 * @Project : SSPU-all-in-one
 * @File : wxmp_article_following.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'wxmp_article_service.dart';

extension WxmpArticleFollowing on WxmpArticleService {
  /// 获取本地关注的公众号列表。
  /// :return: {fakeid: {name, alias, avatar}}
  Future<Map<String, Map<String, String>>> getLocalFollowedMps() async {
    final json = await StorageService.getString(
      WxmpArticleService._keyFollowedMps,
    );
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

  /// 关注公众号。
  Future<void> followMp(
    String fakeid,
    String name, {
    String? alias,
    String? avatar,
    String? recommendedName,
    String? recommendedWxAccount,
  }) async {
    final mps = await getLocalFollowedMps();
    mps[fakeid] = {
      'name': name,
      'alias': alias ?? '',
      'avatar': avatar ?? '',
      'recommended_name': recommendedName ?? '',
      'recommended_wx_account': recommendedWxAccount ?? '',
    };
    await StorageService.setString(
      WxmpArticleService._keyFollowedMps,
      jsonEncode(mps),
    );
  }

  /// 取消关注。
  Future<void> unfollowMp(String fakeid) async {
    final mps = await getLocalFollowedMps();
    mps.remove(fakeid);
    await StorageService.setString(
      WxmpArticleService._keyFollowedMps,
      jsonEncode(mps),
    );
  }

  /// 检查是否已关注。
  Future<bool> isFollowed(String fakeid) async {
    final mps = await getLocalFollowedMps();
    return mps.containsKey(fakeid);
  }

  /// 获取已关注公众号的展示列表。
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

  /// 将公众号平台 API 返回的文章数据转为 MessageItem。
  MessageItem? _articleToMessageItem(
    Map<String, dynamic> article,
    String mpName,
    String fakeid, {
    String? mpDisplayId,
  }) {
    final title = article['title']?.toString();
    if (title == null || title.isEmpty) return null;

    final link = article['link']?.toString();
    if (link == null || link.isEmpty) return null;

    // 日期处理同时兼容秒级与毫秒级时间戳。
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
      mpDisplayId: _trimToNull(mpDisplayId),
      timestamp: timestampMs,
    );
  }

  String _resolveAccountName(Map<String, String> mpInfo, String fakeid) {
    assert(fakeid.isNotEmpty, 'fakeid must not be empty');
    return _firstNonEmpty([mpInfo['recommended_name'], mpInfo['name']]) ??
        '公众号名称未知';
  }

  String? _resolveAccountDisplayId(Map<String, String> mpInfo) {
    return _firstNonEmpty([mpInfo['recommended_wx_account'], mpInfo['alias']]);
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = _trimToNull(value);
      if (trimmed != null) return trimmed;
    }
    return null;
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
