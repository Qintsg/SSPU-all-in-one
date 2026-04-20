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

  /// 最新公开信息自动刷新间隔（分钟，0 = 关闭）
  static const String latestInfoInterval = 'channel_latest_info_interval';

  /// 通知公示自动刷新间隔（分钟，0 = 关闭）
  static const String noticeInterval = 'channel_notice_interval';

  /// 微信公众号自动刷新间隔（分钟，0 = 关闭）
  static const String wechatPublicInterval = 'channel_wechat_public_interval';

  /// 微信服务号自动刷新间隔（分钟，0 = 关闭）
  static const String wechatServiceInterval = 'channel_wechat_service_interval';

  /// 消息推送全局开关
  static const String notificationEnabled = 'notification_enabled';

  /// 勿扰模式开关
  static const String dndEnabled = 'dnd_enabled';

  /// 勿扰开始时间 — 小时（0–23）
  static const String dndStartHour = 'dnd_start_hour';

  /// 勿扰开始时间 — 分钟（0–59）
  static const String dndStartMinute = 'dnd_start_minute';

  /// 勿扰结束时间 — 小时（0–23）
  static const String dndEndHour = 'dnd_end_hour';

  /// 勿扰结束时间 — 分钟（0–59）
  static const String dndEndMinute = 'dnd_end_minute';

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
    await StorageService.setBool(MessageChannelKeys.latestInfoEnabled, enabled);
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
    await StorageService.setBool(MessageChannelKeys.noticeEnabled, enabled);
  }

  /// 获取微信公众号渠道是否启用（默认关闭 — 占位）
  Future<bool> isWechatPublicEnabled() async {
    return await StorageService.getBool(MessageChannelKeys.wechatPublicEnabled);
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

  // ==================== 单个公众号通知开关 ====================

  /// 生成公众号通知开关的存储键名
  /// [mpBookId] 公众号的 bookId（如 MP_WXS_xxx）
  static String _mpNotificationKey(String mpBookId) =>
      'mp_${mpBookId}_notification_enabled';

  /// 获取指定公众号的通知开关（默认开启）
  /// [mpBookId] 公众号 bookId
  /// :return: 是否启用该公众号的通知
  Future<bool> isMpNotificationEnabled(String mpBookId) async {
    return await StorageService.getBool(
      _mpNotificationKey(mpBookId),
      defaultValue: true,
    );
  }

  /// 设置指定公众号的通知开关
  /// [mpBookId] 公众号 bookId
  /// [enabled] 是否启用
  Future<void> setMpNotificationEnabled(String mpBookId, bool enabled) async {
    await StorageService.setBool(_mpNotificationKey(mpBookId), enabled);
  }

  // ==================== 通用渠道开关与间隔管理 ====================

  /// 生成渠道启用状态的存储键名
  /// [channelId] 渠道唯一标识（snake_case）
  static String _channelEnabledKey(String channelId) =>
      'channel_${channelId}_enabled';

  /// 生成渠道自动刷新间隔的存储键名
  static String _channelIntervalKey(String channelId) =>
      'channel_${channelId}_interval';

  /// 获取指定渠道是否启用
  /// [channelId] 渠道唯一标识
  /// [defaultValue] 默认值，未设置时返回此值
  /// :return: 渠道启用状态
  Future<bool> isChannelEnabled(
    String channelId, {
    bool defaultValue = false,
  }) async {
    return await StorageService.getBool(
      _channelEnabledKey(channelId),
      defaultValue: defaultValue,
    );
  }

  /// 设置指定渠道的启用状态
  /// [channelId] 渠道唯一标识
  /// [enabled] 是否启用
  Future<void> setChannelEnabled(String channelId, bool enabled) async {
    await StorageService.setBool(_channelEnabledKey(channelId), enabled);
  }

  // ==================== 子分类（tag3）开关管理 ====================

  /// 生成子分类启用状态的存储键名
  /// [categoryName] MessageCategory 枚举的 .name 值
  static String _categoryEnabledKey(String categoryName) =>
      'category_${categoryName}_enabled';

  /// 获取指定子分类是否启用
  /// 默认为 true（渠道启用时所有子分类默认开启）
  /// [categoryName] MessageCategory 枚举的 .name 值
  /// [defaultValue] 未设置时的默认值
  /// :return: 子分类启用状态
  Future<bool> isCategoryEnabled(
    String categoryName, {
    bool defaultValue = true,
  }) async {
    return await StorageService.getBool(
      _categoryEnabledKey(categoryName),
      defaultValue: defaultValue,
    );
  }

  /// 设置指定子分类的启用状态
  /// [categoryName] MessageCategory 枚举的 .name 值
  /// [enabled] 是否启用
  Future<void> setCategoryEnabled(String categoryName, bool enabled) async {
    await StorageService.setBool(_categoryEnabledKey(categoryName), enabled);
  }

  /// 获取指定渠道的自动刷新间隔
  /// [channelId] 渠道唯一标识
  /// [defaultValue] 默认间隔（分钟，0 = 关闭）
  /// :return: 自动刷新间隔（分钟）
  Future<int> getChannelInterval(
    String channelId, {
    int defaultValue = 0,
  }) async {
    return (await StorageService.getInt(_channelIntervalKey(channelId))) ??
        defaultValue;
  }

  /// 设置指定渠道的自动刷新间隔
  /// [channelId] 渠道唯一标识
  /// [minutes] 间隔分钟数（0 = 关闭）
  Future<void> setChannelInterval(String channelId, int minutes) async {
    await StorageService.setInt(_channelIntervalKey(channelId), minutes);
  }

  // ==================== 自动刷新间隔管理（旧接口，保持兼容） ====================

  /// 获取最新公开信息自动刷新间隔（分钟，0 = 关闭，默认 60）
  Future<int> getLatestInfoInterval() async {
    return (await StorageService.getInt(
          MessageChannelKeys.latestInfoInterval,
        )) ??
        60;
  }

  /// 设置最新公开信息自动刷新间隔（分钟）
  Future<void> setLatestInfoInterval(int minutes) async {
    await StorageService.setInt(MessageChannelKeys.latestInfoInterval, minutes);
  }

  /// 获取通知公示自动刷新间隔（分钟，0 = 关闭，默认 60）
  Future<int> getNoticeInterval() async {
    return (await StorageService.getInt(MessageChannelKeys.noticeInterval)) ??
        60;
  }

  /// 设置通知公示自动刷新间隔（分钟）
  Future<void> setNoticeInterval(int minutes) async {
    await StorageService.setInt(MessageChannelKeys.noticeInterval, minutes);
  }

  /// 获取微信公众号自动刷新间隔（分钟，0 = 关闭，默认 0）
  Future<int> getWechatPublicInterval() async {
    return (await StorageService.getInt(
          MessageChannelKeys.wechatPublicInterval,
        )) ??
        0;
  }

  /// 设置微信公众号自动刷新间隔（分钟）
  Future<void> setWechatPublicInterval(int minutes) async {
    await StorageService.setInt(
      MessageChannelKeys.wechatPublicInterval,
      minutes,
    );
  }

  /// 获取微信服务号自动刷新间隔（分钟，0 = 关闭，默认 0）
  Future<int> getWechatServiceInterval() async {
    return (await StorageService.getInt(
          MessageChannelKeys.wechatServiceInterval,
        )) ??
        0;
  }

  /// 设置微信服务号自动刷新间隔（分钟）
  Future<void> setWechatServiceInterval(int minutes) async {
    await StorageService.setInt(
      MessageChannelKeys.wechatServiceInterval,
      minutes,
    );
  }

  // ==================== 消息推送与勿扰模式 ====================

  /// 获取消息推送全局开关（默认开启）
  Future<bool> isNotificationEnabled() async {
    return await StorageService.getBool(
      MessageChannelKeys.notificationEnabled,
      defaultValue: true,
    );
  }

  /// 设置消息推送全局开关
  Future<void> setNotificationEnabled(bool enabled) async {
    await StorageService.setBool(
      MessageChannelKeys.notificationEnabled,
      enabled,
    );
  }

  /// 获取勿扰模式是否开启（默认关闭）
  Future<bool> isDndEnabled() async {
    return await StorageService.getBool(MessageChannelKeys.dndEnabled);
  }

  /// 设置勿扰模式开关
  Future<void> setDndEnabled(bool enabled) async {
    await StorageService.setBool(MessageChannelKeys.dndEnabled, enabled);
  }

  /// 获取勿扰开始时间（默认 22:00）
  Future<int> getDndStartHour() async {
    return (await StorageService.getInt(MessageChannelKeys.dndStartHour)) ?? 22;
  }

  /// 获取勿扰开始分钟（默认 0）
  Future<int> getDndStartMinute() async {
    return (await StorageService.getInt(MessageChannelKeys.dndStartMinute)) ??
        0;
  }

  /// 获取勿扰结束时间（默认 7:00）
  Future<int> getDndEndHour() async {
    return (await StorageService.getInt(MessageChannelKeys.dndEndHour)) ?? 7;
  }

  /// 获取勿扰结束分钟（默认 0）
  Future<int> getDndEndMinute() async {
    return (await StorageService.getInt(MessageChannelKeys.dndEndMinute)) ?? 0;
  }

  /// 设置勿扰时间段（一次性保存开始和结束时间）
  Future<void> setDndTime({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    await StorageService.setInt(MessageChannelKeys.dndStartHour, startHour);
    await StorageService.setInt(MessageChannelKeys.dndStartMinute, startMinute);
    await StorageService.setInt(MessageChannelKeys.dndEndHour, endHour);
    await StorageService.setInt(MessageChannelKeys.dndEndMinute, endMinute);
  }

  /// 判断当前时间是否在勿扰时段内
  /// 支持跨午夜时段（如 22:00–7:00）
  Future<bool> isInDndPeriod() async {
    final enabled = await isDndEnabled();
    if (!enabled) return false;

    final startH = await getDndStartHour();
    final startM = await getDndStartMinute();
    final endH = await getDndEndHour();
    final endM = await getDndEndMinute();

    final now = DateTime.now();
    // 将时间转为当天分钟数以便比较
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startH * 60 + startM;
    final endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      // 同天时段，如 8:00–12:00
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // 跨午夜时段，如 22:00–7:00
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
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
