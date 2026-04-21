/*
 * 微信公众号平台认证服务 — 管理 mp.weixin.qq.com 的 Cookie/Token
 * 作为"方式二：公众号平台"的认证基础
 * @Project : SSPU-all-in-one
 * @File : wxmp_auth_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-22
 */

import 'storage_service.dart';

/// 微信公众号平台认证服务（单例）
/// 负责 Cookie 和 Token 的存储、读取、校验和清除
class WxmpAuthService {
  WxmpAuthService._();
  static final WxmpAuthService instance = WxmpAuthService._();

  /// 存储键名
  static const String _keyCookie = 'wxmp_cookie';
  static const String _keyToken = 'wxmp_token';
  static const String _keyLastUpdate = 'wxmp_last_update';

  /// 保存认证信息（Cookie + Token）
  Future<void> saveAuth(String cookie, String token) async {
    await StorageService.setString(_keyCookie, cookie);
    await StorageService.setString(_keyToken, token);
    await StorageService.setInt(
      _keyLastUpdate,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 获取 Cookie
  Future<String?> getCookie() async {
    return StorageService.getString(_keyCookie);
  }

  /// 获取 Token
  Future<String?> getToken() async {
    return StorageService.getString(_keyToken);
  }

  /// 检查是否已配置认证
  Future<bool> hasAuth() async {
    final cookie = await getCookie();
    final token = await getToken();
    return cookie != null &&
        cookie.isNotEmpty &&
        token != null &&
        token.isNotEmpty;
  }

  /// 清除所有认证信息
  Future<void> clearAuth() async {
    await StorageService.remove(_keyCookie);
    await StorageService.remove(_keyToken);
    await StorageService.remove(_keyLastUpdate);
  }

  /// 获取认证最后更新时间
  Future<DateTime?> getLastUpdate() async {
    final ms = await StorageService.getInt(_keyLastUpdate);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
