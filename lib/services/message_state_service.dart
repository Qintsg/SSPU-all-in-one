/*
 * 消息状态管理服务 — 管理消息已读状态和渠道开关配置
 * 使用 StorageService 持久化已读消息集合和渠道启用状态
 * @Project : SSPU-all-in-one
 * @File : message_state_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import '../models/channel_config.dart';
import '../models/message_item.dart';
import '../services/storage_service.dart';

part 'message_state_service_legacy.dart';
part 'message_state_service_notifications.dart';
part 'message_state_service_messages.dart';

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
class MessageStateService
    with
        MessageStateServiceLegacyIntervals,
        MessageStateServiceNotifications,
        MessageStateServiceMessages {
  MessageStateService._();

  static final MessageStateService instance = MessageStateService._();

  /// 渠道默认配置索引，确保服务层读取默认值时与设置页展示保持一致。
  static final Map<String, ChannelConfig> _channelDefaults = {
    for (final channel in [
      ...departmentChannels,
      ...teachingChannels,
      ...wechatChannels,
    ])
      channel.id: channel,
  };

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

  /// 记录最近一次非 0 刷新间隔，便于自动刷新重新开启时恢复用户配置。
  static String _channelLastIntervalKey(String channelId) =>
      'channel_${channelId}_last_interval';

  /// 手动刷新条数配置键。
  static String _channelManualFetchCountKey(String channelId) =>
      'channel_${channelId}_manual_fetch_count';

  /// 自动刷新条数配置键。
  static String _channelAutoFetchCountKey(String channelId) =>
      'channel_${channelId}_auto_fetch_count';

  /// 获取指定渠道是否启用
  /// [channelId] 渠道唯一标识
  /// [defaultValue] 默认值，未设置时优先使用此值，否则使用渠道配置默认值
  /// :return: 渠道启用状态
  Future<bool> isChannelEnabled(String channelId, {bool? defaultValue}) async {
    return await StorageService.getBool(
      _channelEnabledKey(channelId),
      defaultValue:
          defaultValue ?? _channelDefaults[channelId]?.defaultEnabled ?? false,
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
  /// [defaultValue] 默认间隔，未设置时优先使用此值，否则使用渠道配置默认值
  /// :return: 自动刷新间隔（分钟）
  Future<int> getChannelInterval(String channelId, {int? defaultValue}) async {
    return (await StorageService.getInt(_channelIntervalKey(channelId))) ??
        defaultValue ??
        _channelDefaults[channelId]?.defaultInterval ??
        0;
  }

  /// 设置指定渠道的自动刷新间隔
  /// [channelId] 渠道唯一标识
  /// [minutes] 间隔分钟数（0 = 关闭）
  Future<void> setChannelInterval(String channelId, int minutes) async {
    final normalized = minutes < 0 ? 0 : minutes;
    await StorageService.setInt(_channelIntervalKey(channelId), normalized);
    if (normalized > 0) {
      await StorageService.setInt(
        _channelLastIntervalKey(channelId),
        normalized,
      );
    }
  }

  /// 获取用于设置页展示的刷新间隔。
  /// 自动刷新关闭时回显最近一次非 0 间隔，避免重新开启后丢失原选择。
  Future<int> getChannelDisplayInterval(
    String channelId, {
    int? defaultValue,
  }) async {
    final current = await getChannelInterval(
      channelId,
      defaultValue: defaultValue,
    );
    if (current > 0) return current;
    return (await StorageService.getInt(_channelLastIntervalKey(channelId))) ??
        defaultValue ??
        _channelDefaults[channelId]?.defaultInterval ??
        60;
  }

  /// 判断指定渠道的自动刷新是否开启。
  Future<bool> isChannelAutoRefreshEnabled(String channelId) async {
    return (await getChannelInterval(channelId)) > 0;
  }

  /// 切换指定渠道的自动刷新状态。
  /// 关闭时将当前间隔落盘为最近一次有效值；开启时恢复最近一次有效值或默认值。
  Future<void> setChannelAutoRefreshEnabled(
    String channelId,
    bool enabled,
  ) async {
    if (enabled) {
      final restored = await getChannelDisplayInterval(channelId);
      await setChannelInterval(channelId, restored <= 0 ? 60 : restored);
      return;
    }

    final current = await getChannelInterval(channelId);
    if (current > 0) {
      await StorageService.setInt(_channelLastIntervalKey(channelId), current);
    }
    await StorageService.setInt(_channelIntervalKey(channelId), 0);
  }

  /// 获取指定渠道的手动刷新条数。
  Future<int> getChannelManualFetchCount(
    String channelId, {
    int defaultValue = 20,
  }) async {
    final effectiveDefault = channelId == 'wechat_public' ? 10 : defaultValue;
    final stored = await StorageService.getInt(
      _channelManualFetchCountKey(channelId),
    );
    return (stored ?? effectiveDefault).clamp(1, 200);
  }

  /// 设置指定渠道的手动刷新条数。
  Future<void> setChannelManualFetchCount(String channelId, int count) async {
    await StorageService.setInt(
      _channelManualFetchCountKey(channelId),
      count.clamp(1, 200),
    );
  }

  /// 获取指定渠道的自动刷新条数。
  Future<int> getChannelAutoFetchCount(
    String channelId, {
    int defaultValue = 20,
  }) async {
    final effectiveDefault = channelId == 'wechat_public' ? 10 : defaultValue;
    final stored = await StorageService.getInt(
      _channelAutoFetchCountKey(channelId),
    );
    return (stored ?? effectiveDefault).clamp(1, 200);
  }

  /// 设置指定渠道的自动刷新条数。
  Future<void> setChannelAutoFetchCount(String channelId, int count) async {
    await StorageService.setInt(
      _channelAutoFetchCountKey(channelId),
      count.clamp(1, 200),
    );
  }
}
