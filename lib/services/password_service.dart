/*
 * 密码管理服务 — 本地密码保护功能的核心逻辑
 * 委托 StorageService 进行数据持久化
 * 所有数据仅保留在设备本地，不上传至任何云端
 * @Project : SSPU-all-in-one
 * @File : password_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'storage_service.dart';

/// 密码管理服务
/// 负责密码的设置、验证、删除及状态查询
/// 密码以 SHA-256 哈希形式存储，原始密码不落盘
class PasswordService {
  /// 检查是否已设置密码保护
  static Future<bool> isPasswordSet() => StorageService.isPasswordSet();

  /// 设置新密码
  static Future<void> setPassword(String password) =>
      StorageService.setPassword(password);

  /// 验证输入的密码是否正确
  static Future<bool> verifyPassword(String inputPassword) =>
      StorageService.verifyPassword(inputPassword);

  /// 移除密码保护
  static Future<void> removePassword() => StorageService.removePassword();

  /// 检查是否已启用系统快速验证。
  static Future<bool> isQuickAuthEnabled() =>
      StorageService.isQuickAuthEnabled();

  /// 设置系统快速验证开关。
  static Future<void> setQuickAuthEnabled(bool enabled) =>
      StorageService.setQuickAuthEnabled(enabled);

  /// 清除系统快速验证配置。
  static Future<void> clearQuickAuth() => StorageService.clearQuickAuth();
}
