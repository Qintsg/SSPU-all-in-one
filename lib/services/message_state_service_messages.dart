part of 'message_state_service.dart';

mixin MessageStateServiceMessages {
  // ==================== 消息持久化管理 ====================

  /// 保存消息列表到本地存储
  Future<void> saveMessages(List<MessageItem> messages) async {
    final jsonList = messages.map((msg) => msg.toJson()).toList();
    await StorageService.setString(
      MessageChannelKeys.persistedMessages,
      jsonEncode(jsonList),
    );
  }

  /// 从本地存储加载消息列表
  Future<List<MessageItem>> loadMessages() async {
    final stored = await StorageService.getString(
      MessageChannelKeys.persistedMessages,
    );
    if (stored == null || stored.isEmpty) return [];
    try {
      final jsonList = jsonDecode(stored) as List<dynamic>;
      return jsonList
          .map((json) => MessageItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 存储数据损坏时返回空列表
      return [];
    }
  }

  /// 清除所有微信公众号类型的预存文章
  /// 保留其他渠道的消息不受影响
  /// :return: 被清除的文章数量
  Future<int> clearWechatArticles() async {
    final messages = await loadMessages();
    final before = messages.length;
    messages.removeWhere(
      (msg) => msg.sourceType == MessageSourceType.wechatPublic,
    );
    await saveMessages(messages);
    return before - messages.length;
  }

  /// 将新抓取的消息与已有消息合并（按 ID 去重）
  /// [existingMessages] 已有消息列表
  /// [newMessages] 新抓取的消息列表
  /// 返回合并后的列表（已存消息保持原样，避免刷新覆盖原始时间）
  List<MessageItem> mergeMessages(
    List<MessageItem> existingMessages,
    List<MessageItem> newMessages,
  ) {
    final messageMap = <String, MessageItem>{};
    // 先放旧消息，保留首次获取时记录的时间与字段。
    for (final msg in existingMessages) {
      messageMap[msg.id] = msg;
    }
    // 只补充新增消息，已有文章不再被新抓取结果覆盖。
    for (final msg in newMessages) {
      messageMap.putIfAbsent(msg.id, () => msg);
    }
    return messageMap.values.toList();
  }
}
