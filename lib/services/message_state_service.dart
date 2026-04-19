/*
 * 消息状态管理服务 — 管理消息已读状态和渠道开关配置
 * 使用 StorageService 持久化已读消息集合和渠道启用状态
 * @Project : SSPU-all-in-one
 * @File : message_state_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
 */

import 'dart:convert';
import '../models/message_item.dart';
import '../services/storage_service.dart';

/// 消息渠道配置键名
class MessageChannelKeys {
  MessageChannelKeys._();

  /// 最新公开信息(3148) 开关
  static const String latestInfoEnabled = 'channel_latest_info_enabled';

  /// 通知公示(3149) 开关
  static const String noticeEnabled = 'channel_notice_enabled';

  /// 微信公众号开关（占位）
  static const String wechatPublicEnabled = 'channel_wechat_public_enabled';

  /// 微信服务号开关（占位）
  static const String wechatServiceEnabled = 'channel_wechat_service_enabled';

  /// 已读消息 ID 集合
  static const String readMessageIds = 'read_message_ids';

  /// 持久化的消息列表（JSON 数组）
  static const String persistedMessages = 'persisted_messages';
}

/// 消息状态管理服务（单例）
/// 管理已读/未读状态持久化和渠道开关
class MessageStateService {
  MessageStateService._();

  static final MessageStateService instance = MessageStateService._();

  /// 内存中缓存的已读消息 ID 集合，减少频繁读取存储
  Set<String> _readIds = {};

  /// 是否已从存储加载过已读状态
  bool _loaded = false;

  /// 初始化：从存储加载已读 ID 集合到内存
  Future<void> init() async {
    if (_loaded) return;
    final stored = await StorageService.getString(
      MessageChannelKeys.readMessageIds,
    );
    if (stored != null && stored.isNotEmpty) {
      // 以逗号分隔存储的 ID 列表
      _readIds = stored.split(',').toSet();
    }
    _loaded = true;
  }

  /// 判断消息是否已读
  bool isRead(String messageId) => _readIds.contains(messageId);

  /// 标记单条消息为已读
  Future<void> markAsRead(String messageId) async {
    _readIds.add(messageId);
    await _persistReadIds();
  }

  /// 批量标记所有消息为已读
  /// [messageIds] 要标记的消息 ID 列表
  Future<void> markAllAsRead(List<String> messageIds) async {
    _readIds.addAll(messageIds);
    await _persistReadIds();
  }

  /// 获取未读消息数量
  int countUnread(List<String> allMessageIds) {
    return allMessageIds.where((id) => !_readIds.contains(id)).length;
  }

  /// 持久化已读 ID 集合到存储
  Future<void> _persistReadIds() async {
    await StorageService.setString(
      MessageChannelKeys.readMessageIds,
      _readIds.join(','),
    );
  }

  // ==================== 渠道开关管理 ====================

  /// 获取最新公开信息渠道是否启用（默认启用）
  Future<bool> isLatestInfoEnabled() async {
    return await StorageService.getBool(
      MessageChannelKeys.latestInfoEnabled,
      defaultValue: true,
    );
  }

  /// 设置最新公开信息渠道启用状态
  Future<void> setLatestInfoEnabled(bool enabled) async {
    await StorageService.setBool(
      MessageChannelKeys.latestInfoEnabled,
      enabled,
    );
  }

  /// 获取通知公示渠道是否启用（默认启用）
  Future<bool> isNoticeEnabled() async {
    return await StorageService.getBool(
      MessageChannelKeys.noticeEnabled,
      defaultValue: true,
    );
  }

  /// 设置通知公示渠道启用状态
  Future<void> setNoticeEnabled(bool enabled) async {
    await StorageService.setBool(
      MessageChannelKeys.noticeEnabled,
      enabled,
    );
  }

  /// 获取微信公众号渠道是否启用（默认关闭 — 占位）
  Future<bool> isWechatPublicEnabled() async {
    return await StorageService.getBool(
      MessageChannelKeys.wechatPublicEnabled,
    );
  }

  /// 设置微信公众号渠道启用状态
  Future<void> setWechatPublicEnabled(bool enabled) async {
    await StorageService.setBool(
      MessageChannelKeys.wechatPublicEnabled,
      enabled,
    );
  }

  /// 获取微信服务号渠道是否启用（默认关闭 — 占位）
  Future<bool> isWechatServiceEnabled() async {
    return await StorageService.getBool(
      MessageChannelKeys.wechatServiceEnabled,
    );
  }

  /// 设置微信服务号渠道启用状态
  Future<void> setWechatServiceEnabled(bool enabled) async {
    await StorageService.setBool(
      MessageChannelKeys.wechatServiceEnabled,
      enabled,
    );
  }

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

  /// 将新抓取的消息与已有消息合并（按 ID 去重）
  /// [existingMessages] 已有消息列表
  /// [newMessages] 新抓取的消息列表
  /// 返回合并后的列表（新消息覆盖同 ID 旧消息）
  List<MessageItem> mergeMessages(
    List<MessageItem> existingMessages,
    List<MessageItem> newMessages,
  ) {
    final messageMap = <String, MessageItem>{};
    // 先放旧消息
    for (final msg in existingMessages) {
      messageMap[msg.id] = msg;
    }
    // 新消息覆盖同 ID 的旧消息
    for (final msg in newMessages) {
      messageMap[msg.id] = msg;
    }
    return messageMap.values.toList();
  }
}
