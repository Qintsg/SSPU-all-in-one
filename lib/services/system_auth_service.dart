/*
 * 系统快速验证服务 — 封装 local_auth 平台能力并提供安全降级
 * @Project : SSPU-all-in-one
 * @File : system_auth_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-25
 */

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// 系统认证尝试结果。
enum SystemAuthResult {
  /// 系统认证通过。
  success,

  /// 用户取消、验证失败或系统认证超时。
  failed,

  /// 当前平台或设备不支持系统认证。
  unavailable,
}

/// 系统快速验证服务。
///
/// 仅在 Android / iOS / macOS / Windows 上尝试调用 local_auth；Linux 与 Web
/// 直接报告不可用，避免缺少平台实现时抛出插件异常。服务只返回认证结果，
/// 不读取、保存或记录任何生物识别、PIN、Face ID、Touch ID 原始数据。
class SystemAuthService {
  SystemAuthService._({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  static final SystemAuthService instance = SystemAuthService._();

  final LocalAuthentication _localAuthentication;

  /// 测试专用构造器，允许注入 mock LocalAuthentication。
  @visibleForTesting
  factory SystemAuthService.forTesting(
    LocalAuthentication localAuthentication,
  ) {
    return SystemAuthService._(localAuthentication: localAuthentication);
  }

  /// 当前运行平台是否有 local_auth 官方实现。
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows;
  }

  /// 当前设备是否可执行系统认证。
  Future<bool> isAvailable() async {
    if (!isPlatformSupported) return false;
    try {
      return await _localAuthentication.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// 请求系统认证。
  ///
  /// 不使用 `biometricOnly: true`，因此 Windows 可使用系统支持的认证方式；
  /// 认证失败、取消、超时或插件不可用均返回非 success，调用方应保留手动密码路径。
  Future<SystemAuthResult> authenticate({
    required String localizedReason,
  }) async {
    if (!await isAvailable()) return SystemAuthResult.unavailable;

    try {
      final didAuthenticate = await _localAuthentication.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate
          ? SystemAuthResult.success
          : SystemAuthResult.failed;
    } catch (_) {
      return SystemAuthResult.unavailable;
    }
  }
}
