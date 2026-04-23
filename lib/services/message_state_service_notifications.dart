part of 'message_state_service.dart';

mixin MessageStateServiceNotifications {
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
}
