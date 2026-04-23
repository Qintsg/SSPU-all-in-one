part of 'message_state_service.dart';

mixin MessageStateServiceLegacyIntervals {
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
}
