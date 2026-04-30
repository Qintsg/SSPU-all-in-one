/*
 * 教务凭据安全存储服务 — 保存 OA 账号及外部系统密码
 * @Project : SSPU-all-in-one
 * @File : academic_credentials_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-24
 */

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/academic_credentials.dart';
import '../models/academic_login_validation.dart';

/// 教务凭据安全存储服务。
/// 使用系统安全存储保存可解密凭据，供后续外部网站登录流程读取。
class AcademicCredentialsService {
  AcademicCredentialsService._();

  /// 全局单例。
  static final AcademicCredentialsService instance =
      AcademicCredentialsService._();

  /// OA 账号存储键。
  static const String _oaAccountKey = 'academic_credentials_oa_account';

  /// OA 账号密码存储键。
  static const String _oaPasswordKey = 'academic_credentials_oa_password';

  /// 体育部查询密码存储键。
  static const String _sportsQueryPasswordKey =
      'academic_credentials_sports_query_password';

  /// 邮箱密码存储键。
  static const String _emailPasswordKey = 'academic_credentials_email_password';

  /// OA 登录会话快照存储键，保存 Cookie 等可复用身份信息。
  static const String _oaLoginSessionKey = 'academic_login_session_snapshot';

  /// 系统安全存储实例。
  /// Android 上启用 EncryptedSharedPreferences，密钥仍由平台安全能力托管。
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 获取设置页展示所需的凭据状态。
  Future<AcademicCredentialsStatus> getStatus() async {
    final oaAccount = await _readValue(_oaAccountKey);
    final oaPassword = await _readValue(_oaPasswordKey);
    final sportsQueryPassword = await _readValue(_sportsQueryPasswordKey);
    final emailPassword = await _readValue(_emailPasswordKey);

    return AcademicCredentialsStatus(
      oaAccount: oaAccount ?? '',
      hasOaPassword: oaPassword != null && oaPassword.isNotEmpty,
      hasSportsQueryPassword:
          sportsQueryPassword != null && sportsQueryPassword.isNotEmpty,
      hasEmailPassword: emailPassword != null && emailPassword.isNotEmpty,
    );
  }

  /// 保存账号与本次填写的密码。
  /// 密码参数为 null 时表示不修改既有值，便于页面回访时保持密码框为空。
  Future<void> saveCredentials({
    required String oaAccount,
    String? oaPassword,
    String? sportsQueryPassword,
    String? emailPassword,
  }) async {
    final normalizedOaAccount = oaAccount.trim();
    final previousOaAccount = await _readValue(_oaAccountKey) ?? '';
    final shouldClearOaSession =
        previousOaAccount != normalizedOaAccount ||
        (oaPassword != null && oaPassword.isNotEmpty);

    await _writeOrDeleteWhenBlank(_oaAccountKey, normalizedOaAccount);
    await _writeWhenPresent(_oaPasswordKey, oaPassword);
    await _writeWhenPresent(_sportsQueryPasswordKey, sportsQueryPassword);
    await _writeWhenPresent(_emailPasswordKey, emailPassword);
    if (shouldClearOaSession) await clearOaLoginSession();
  }

  /// 读取指定密码字段原文，供后续登录外部网站使用。
  Future<String?> readSecret(AcademicCredentialSecret secret) async {
    return _readValue(_keyOf(secret));
  }

  /// 保存 OA 登录后返回的会话身份信息。
  Future<void> saveOaLoginSession(
    AcademicLoginSessionSnapshot sessionSnapshot,
  ) async {
    if (!sessionSnapshot.hasCookies) return;
    await _secureStorage.write(
      key: _oaLoginSessionKey,
      value: jsonEncode(sessionSnapshot.toJson()),
    );
  }

  /// 读取最近一次 OA 登录产生的会话快照。
  Future<AcademicLoginSessionSnapshot?> readOaLoginSession() async {
    final sessionPayload = await _readValue(_oaLoginSessionKey);
    if (sessionPayload == null || sessionPayload.trim().isEmpty) return null;
    try {
      final decodedPayload = jsonDecode(sessionPayload) as Map<String, dynamic>;
      return AcademicLoginSessionSnapshot.fromJson(decodedPayload);
    } catch (_) {
      await clearOaLoginSession();
      return null;
    }
  }

  /// 读取指定 OA 相关网页可用的 Cookie 请求头。
  Future<String?> readOaCookieHeaderFor(Uri targetUri) async {
    final sessionSnapshot = await readOaLoginSession();
    final cookieHeader = sessionSnapshot?.cookieHeaderFor(targetUri).trim();
    return cookieHeader == null || cookieHeader.isEmpty ? null : cookieHeader;
  }

  /// 清除已保存的 OA 登录会话，避免继续复用已失效身份。
  Future<void> clearOaLoginSession() async {
    await _secureStorage.delete(key: _oaLoginSessionKey);
  }

  /// 清除指定密码字段。
  Future<void> clearSecret(AcademicCredentialSecret secret) async {
    await _secureStorage.delete(key: _keyOf(secret));
    if (secret == AcademicCredentialSecret.oaPassword) {
      await clearOaLoginSession();
    }
  }

  /// 清除本服务管理的所有教务凭据。
  Future<void> clearAll() async {
    for (final key in _allKeys) {
      await _secureStorage.delete(key: key);
    }
  }

  /// 当前服务管理的全部安全存储键。
  static List<String> get _allKeys => const [
    _oaAccountKey,
    _oaPasswordKey,
    _sportsQueryPasswordKey,
    _emailPasswordKey,
    _oaLoginSessionKey,
  ];

  /// 读取单个安全存储值。
  Future<String?> _readValue(String key) async {
    return _secureStorage.read(key: key);
  }

  /// 写入非空值；空字符串表示用户没有为该密码输入新值。
  Future<void> _writeWhenPresent(String key, String? value) async {
    if (value == null || value.isEmpty) return;
    await _secureStorage.write(key: key, value: value);
  }

  /// 写入账号；账号为空时删除旧值，避免继续保留过期学工号。
  Future<void> _writeOrDeleteWhenBlank(String key, String value) async {
    if (value.isEmpty) {
      await _secureStorage.delete(key: key);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  /// 返回密码字段对应的安全存储键。
  String _keyOf(AcademicCredentialSecret secret) {
    return switch (secret) {
      AcademicCredentialSecret.oaPassword => _oaPasswordKey,
      AcademicCredentialSecret.sportsQueryPassword => _sportsQueryPasswordKey,
      AcademicCredentialSecret.emailPassword => _emailPasswordKey,
    };
  }
}
