/*
 * 密码管理服务 — 本地密码保护功能的核心逻辑
 * 使用 shared_preferences 本地存储 + SHA-256 哈希
 * 所有数据仅保留在设备本地，不上传至任何云端
 * @Project : SSPU-all-in-one
 * @File : password_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 密码管理服务
/// 负责密码的设置、验证、删除及状态查询
/// 密码以 SHA-256 哈希形式存储，原始密码不落盘
class PasswordService {
  /// SharedPreferences 中存储密码哈希的键名
  static const String _passwordKey = 'app_password_hash';

  /// 将明文密码转换为 SHA-256 哈希字符串
  /// 加盐处理，防止彩虹表攻击
  static String _hashPassword(String password) {
    // 固定盐值 + 密码拼接后哈希
    final saltedInput = 'sspu_aio_salt_\$${password}_\$end';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 检查是否已设置密码保护
  /// 返回 true 表示需要在启动时验证密码
  static Future<bool> isPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_passwordKey);
    return storedHash != null && storedHash.isNotEmpty;
  }

  /// 设置新密码
  /// [password] 用户输入的明文密码（不存储原始值）
  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPassword = _hashPassword(password);
    await prefs.setString(_passwordKey, hashedPassword);
  }

  /// 验证输入的密码是否正确
  /// 返回 true 表示密码匹配
  static Future<bool> verifyPassword(String inputPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_passwordKey);
    if (storedHash == null || storedHash.isEmpty) {
      // 未设置密码时视为无需验证
      return true;
    }
    final inputHash = _hashPassword(inputPassword);
    return inputHash == storedHash;
  }

  /// 移除密码保护
  /// 清除本地存储的密码哈希
  static Future<void> removePassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passwordKey);
  }
}
