/*
 * 系统通知服务 — Windows 本地消息通知推送
 * 封装 flutter_local_notifications，提供简洁的通知发送接口
 * 支持基本文本通知、带大文本的通知、定时清除
 * @Project : SSPU-all-in-one
 * @File : notification_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统通知服务（单例）
/// 通过 Windows 系统通知中心发送本地通知
/// 使用前需调用 init() 完成初始化
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 自增通知 ID，避免通知覆盖
  int _nextId = 0;

  /// 初始化通知插件
  /// 应在 app 启动时调用一次
  Future<void> init() async {
    if (_initialized) return;

    // Windows 平台初始化设置
    const initSettings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'SSPU All-in-One',
        appUserModelId: 'com.qintsg.sspu_all_in_one',
        guid: 'd3b6a890-5c2e-4f8a-b1d4-7e9c3f2a1b5e',
      ),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 发送简单文本通知
  /// [title] 通知标题
  /// [body] 通知内容
  /// 返回通知 ID，可用于后续取消
  Future<int> show({
    required String title,
    required String body,
  }) async {
    _ensureInitialized();
    final notificationId = _nextId++;
    await _plugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        windows: WindowsNotificationDetails(),
      ),
    );
    return notificationId;
  }

  /// 发送带详细内容的通知（大文本模式）
  /// [title] 通知标题
  /// [summary] 简短摘要
  /// [body] 详细内容
  Future<int> showDetailed({
    required String title,
    required String summary,
    required String body,
  }) async {
    _ensureInitialized();
    final notificationId = _nextId++;
    await _plugin.show(
      notificationId,
      title,
      '$summary\n$body',
      const NotificationDetails(
        windows: WindowsNotificationDetails(),
      ),
    );
    return notificationId;
  }

  /// 取消指定通知
  Future<void> cancel(int notificationId) async {
    _ensureInitialized();
    await _plugin.cancel(notificationId);
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// 确保已初始化，否则抛出异常
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'NotificationService 未初始化，请先调用 init()',
      );
    }
  }
}
