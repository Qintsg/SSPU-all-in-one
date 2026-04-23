/*
 * 微信公众号平台认证服务 — 管理 mp.weixin.qq.com 的 Cookie/Token
 * 作为公众号平台链路的认证基础
 * @Project : SSPU-all-in-one
 * @File : wxmp_auth_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-22
 */

import 'storage_service.dart';
import 'wxmp_config_service.dart';

/// 公众号平台认证状态。
enum WxmpAuthState {
  /// Cookie 和 Token 均可用。
  ready,

  /// 缺少 Cookie。
  missingCookie,

  /// 缺少 Token。
  missingToken,

  /// Token 不是公众平台常见的数字格式。
  malformedToken,
}

/// 公众号平台认证诊断结果。
class WxmpAuthStatus {
  /// 状态枚举。
  final WxmpAuthState state;

  /// 最后更新时间。
  final DateTime? lastUpdate;

  const WxmpAuthStatus({required this.state, required this.lastUpdate});

  /// 是否具备调用公众号平台接口的本地认证条件。
  bool get isUsable => state == WxmpAuthState.ready;

  /// 面向设置页和调试日志的状态说明，不包含 Cookie 或 Token。
  String get message {
    switch (state) {
      case WxmpAuthState.ready:
        return '认证信息可用';
      case WxmpAuthState.missingCookie:
        return '缺少 Cookie，请重新扫码登录';
      case WxmpAuthState.missingToken:
        return '缺少 Token，请重新扫码登录';
      case WxmpAuthState.malformedToken:
        return 'Token 格式异常，请重新扫码登录';
    }
  }
}

/// 微信公众号平台认证服务（单例）
/// 负责 Cookie 和 Token 的存储、读取、校验和清除
class WxmpAuthService {
  WxmpAuthService._();
  static final WxmpAuthService instance = WxmpAuthService._();

  /// 存储键名
  static const String _keyCookie = 'wxmp_cookie';
  static const String _keyToken = 'wxmp_token';
  static const String _keyLastUpdate = 'wxmp_last_update';

  final WxmpConfigService _configService = WxmpConfigService.instance;

  /// 保存认证信息（Cookie + Token）
  Future<void> saveAuth(String cookie, String token) async {
    await StorageService.setString(_keyCookie, cookie);
    await StorageService.setString(_keyToken, token);
    await StorageService.setInt(
      _keyLastUpdate,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _configService.updateAuthCredentials(cookie: cookie, token: token);
  }

  /// 获取 Cookie
  Future<String?> getCookie() async {
    try {
      final fileConfig = await _configService.loadConfig();
      if (fileConfig.cookie.trim().isNotEmpty) {
        return fileConfig.cookie.trim();
      }
    } catch (_) {
      // 配置文件不可读时回退到扫码登录缓存，避免认证检查阻塞设置页。
    }
    return StorageService.getString(_keyCookie);
  }

  /// 获取 Token
  Future<String?> getToken() async {
    try {
      final fileConfig = await _configService.loadConfig();
      if (fileConfig.token.trim().isNotEmpty) {
        return fileConfig.token.trim();
      }
    } catch (_) {
      // 配置文件不可读时回退到扫码登录缓存，避免认证检查阻塞设置页。
    }
    return StorageService.getString(_keyToken);
  }

  /// 检查是否已配置认证。
  Future<bool> hasAuth() async {
    return (await getAuthStatus()).isUsable;
  }

  /// 获取认证诊断状态，避免调用侧直接读取敏感字段。
  Future<WxmpAuthStatus> getAuthStatus() async {
    final cookie = await getCookie();
    final token = await getToken();
    final lastUpdate = await getLastUpdate();

    if (cookie == null || cookie.trim().isEmpty) {
      return WxmpAuthStatus(
        state: WxmpAuthState.missingCookie,
        lastUpdate: lastUpdate,
      );
    }
    if (token == null || token.trim().isEmpty) {
      return WxmpAuthStatus(
        state: WxmpAuthState.missingToken,
        lastUpdate: lastUpdate,
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(token.trim())) {
      return WxmpAuthStatus(
        state: WxmpAuthState.malformedToken,
        lastUpdate: lastUpdate,
      );
    }
    return WxmpAuthStatus(state: WxmpAuthState.ready, lastUpdate: lastUpdate);
  }

  /// 清除所有认证信息
  Future<void> clearAuth() async {
    await StorageService.remove(_keyCookie);
    await StorageService.remove(_keyToken);
    await StorageService.remove(_keyLastUpdate);
    await _configService.clearAuthCredentials();
  }

  /// 获取认证最后更新时间
  Future<DateTime?> getLastUpdate() async {
    final ms = await StorageService.getInt(_keyLastUpdate);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
