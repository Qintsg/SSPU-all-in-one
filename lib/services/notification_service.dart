/*
 * 系统通知服务 — Windows 本地消息通知推送
 * 基于 local_notifier 包，提供简洁的通知发送接口
 * 支持基本文本通知、带副标题和正文的通知、带操作按钮的通知
 * @Project : SSPU-all-in-one
 * @File : notification_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'package:local_notifier/local_notifier.dart';

/// 系统通知服务（单例）
/// 通过 Windows 系统通知中心发送本地通知
/// 使用前需调用 init() 完成初始化
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  /// 初始化通知插件
  /// 应在 app 启动时调用一次
  Future<void> init() async {
    if (_initialized) return;

    // 设置应用名称，用于 Windows 通知中心显示
    await localNotifier.setup(
      appName: 'SSPU All-in-One',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    _initialized = true;
  }

  /// 发送简单文本通知
  /// [title] 通知标题
  /// [body] 通知内容（可选）
  /// 返回 LocalNotification 实例，可用于后续关闭或销毁
  Future<LocalNotification> show({required String title, String? body}) async {
    _ensureInitialized();

    final notification = LocalNotification(title: title, body: body);

    await localNotifier.notify(notification);
    return notification;
  }

  /// 发送带副标题的详细通知
  /// [title] 通知标题
  /// [subtitle] 副标题摘要
  /// [body] 详细正文内容
  Future<LocalNotification> showDetailed({
    required String title,
    String? subtitle,
    String? body,
  }) async {
    _ensureInitialized();

    final notification = LocalNotification(
      title: title,
      subtitle: subtitle,
      body: body,
    );

    await localNotifier.notify(notification);
    return notification;
  }

  /// 发送带操作按钮的通知
  /// [title] 通知标题
  /// [body] 通知内容
  /// [actions] 操作按钮列表
  Future<LocalNotification> showWithActions({
    required String title,
    String? body,
    required List<LocalNotificationAction> actions,
  }) async {
    _ensureInitialized();

    final notification = LocalNotification(
      title: title,
      body: body,
      actions: actions,
    );

    await localNotifier.notify(notification);
    return notification;
  }

  /// 关闭指定通知
  Future<void> close(LocalNotification notification) async {
    _ensureInitialized();
    await localNotifier.close(notification);
  }

  /// 销毁通知（关闭并移除监听器）
  Future<void> destroy(LocalNotification notification) async {
    _ensureInitialized();
    await localNotifier.destroy(notification);
  }

  /// 确保已初始化，否则抛出异常
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('NotificationService 未初始化，请先调用 init()');
    }
  }
}
