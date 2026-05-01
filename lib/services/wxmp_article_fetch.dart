/*
 * 微信公众号平台文章批量抓取 — 已关注账号分页读取与增量停止
 * @Project : SSPU-all-in-one
 * @File : wxmp_article_fetch.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'wxmp_article_service.dart';

extension WxmpArticleFetch on WxmpArticleService {
  /// 获取所有已关注公众号的最新文章，转为 MessageItem。
  /// [maxCount] 单个公众号最多读取的文章数上限。
  /// [knownMessageIds] 已持久化消息 ID，用于遇到旧文章时停止当前公众号解析。
  Future<List<MessageItem>> fetchArticles({
    int maxCount = 50,
    Set<String>? knownMessageIds,
    bool validateBeforeFetch = true,
    WxmpFetchProgressCallback? onAccountCompleted,
  }) async {
    final authStatus = await _auth.getAuthStatus();
    if (!authStatus.isUsable) return [];
    if (validateBeforeFetch) {
      final validation = await validateAuth();
      if (!validation.isValid) return [];
    }

    final followedMps = await getLocalFollowedMps();
    if (followedMps.isEmpty) return [];

    final enabledEntries = <MapEntry<String, Map<String, String>>>[];
    for (final entry in followedMps.entries) {
      if (await _stateService.isMpNotificationEnabled(entry.key)) {
        enabledEntries.add(entry);
      }
    }
    if (enabledEntries.isEmpty) return [];

    final storedMessageIds =
        knownMessageIds ??
        (await _stateService.loadMessages()).map((msg) => msg.id).toSet();
    final allMessages = <MessageItem>[];
    final config = await _loadConfigOrDefault();
    final perRequestLimit = config.perRequestArticleCount;
    final requestDelayMs = config.requestDelayMs;
    var completedAccounts = 0;
    for (final entry in enabledEntries) {
      final fakeid = entry.key;
      final mpInfo = entry.value;
      final mpName = _resolveAccountName(mpInfo, fakeid);
      final mpDisplayId = _resolveAccountDisplayId(mpInfo);
      final accountMessages = <MessageItem>[];
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
            final msgItem = _articleToMessageItem(
              article,
              mpName,
              fakeid,
              mpDisplayId: mpDisplayId,
            );
            if (msgItem == null) continue;
            if (storedMessageIds.contains(msgItem.id)) {
              reachedKnownMessage = true;
              break;
            }
            allMessages.add(msgItem);
            accountMessages.add(msgItem);
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
      } on WxmpSessionExpiredException {
        // Session 过期，停止后续请求。
        break;
      } on WxmpFrequencyLimitException {
        // 频率限制，停止后续请求。
        break;
      } on WxmpInvalidCsrfException {
        break;
      } catch (_) {
        // 单个公众号失败不影响其他。
      } finally {
        completedAccounts++;
        await onAccountCompleted?.call(
          accountMessages,
          completedAccounts,
          enabledEntries.length,
          mpName,
        );
      }
    }

    return allMessages;
  }
}
