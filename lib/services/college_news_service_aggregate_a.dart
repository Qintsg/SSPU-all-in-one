part of 'college_news_service.dart';

Future<List<MessageItem>> _fetchCollegeCsNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeCsCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeCsListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 智控学院使用三个列表页聚合成三个分类。
Future<List<MessageItem>> _fetchCollegeImNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeImCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeImListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 资环学院使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCollegeReNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeReCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeReListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 能材学院使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCollegeEmNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeEmCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeEmListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 经管学院使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCollegeEconNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeEconCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeEconListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 文传学院使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCollegeLangNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeLangCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeLangListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 数统学院使用四个列表页聚合成四个分类，并进入文章页读取精确时间。
Future<List<MessageItem>> _fetchCollegeMathNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeMathCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeMathListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 职师学院使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchCollegeVteNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeVteCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeVteListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 国教中心使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchCenterIntlNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _centerIntlCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCenterIntlListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 继续教育学院使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchCollegeCeNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeCeCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeCeListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 职业技术学院使用两个列表页聚合成两个分类。
Future<List<MessageItem>> _fetchCollegeVtNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeVtCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeVtListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 马克思主义学院使用四个列表页聚合成四个分类。
Future<List<MessageItem>> _fetchCollegeMarxNews(
  CollegeNewsService service, {
  int maxCount = 20,
  Set<String>? knownMessageIds,
}) async {
  final messages = <MessageItem>[];
  final seenIds = <String>{...?(knownMessageIds)};

  for (final entry in _collegeMarxCategoryPaths.entries) {
    for (final relativePath in entry.value) {
      final pageMessages = await _fetchCollegeMarxListPage(
        service,
        relativePath: relativePath,
        category: entry.key,
        knownMessageIds: seenIds,
      );
      for (final message in pageMessages) {
        if (seenIds.add(message.id)) {
          messages.add(message);
        }
      }
    }
  }

  messages.sort((a, b) {
    final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
    final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
    return right.compareTo(left);
  });

  return messages;
}

/// 工程训练与创新教育中心使用两个列表页聚合成两个分类。
