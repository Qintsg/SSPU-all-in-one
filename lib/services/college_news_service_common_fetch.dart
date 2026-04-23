part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchMergedCategoryPages(
  Map<MessageCategory, List<String>> categoryPaths,
  Future<List<MessageItem>> Function(
    String relativePath,
    MessageCategory category,
    Set<String> knownMessageIds,
  )
  fetchPage, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in categoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await fetchPage(relativePath, entry.key, seenIds);
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
          if (messages.length >= maxCount) break;
        }
      }
      if (messages.length >= maxCount) break;
    }
    if (messages.length >= maxCount) break;
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });
  return messages.take(maxCount).toList();
}

/// 使用临时配置抓取指定列表页，复用现有模板解析逻辑。
