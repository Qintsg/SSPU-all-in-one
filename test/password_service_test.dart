/*
 * 密码服务测试 — 校验系统快速验证配置随密码状态安全清理
 * @Project : SSPU-all-in-one
 * @File : password_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-25
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/services/password_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

void main() {
  late Directory storageDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageDirectory = await Directory.systemTemp.createTemp(
      'password_service_storage_',
    );
    StorageService.debugSetStateFilePathForTesting(
      '${storageDirectory.path}${Platform.pathSeparator}app_state.json',
    );
    await StorageService.init();
  });

  tearDown(() async {
    StorageService.debugSetStateFilePathForTesting(null);
    if (await storageDirectory.exists()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  test('未设置密码时不能持久启用系统快速验证', () async {
    await PasswordService.setQuickAuthEnabled(true);

    expect(await PasswordService.isQuickAuthEnabled(), isFalse);
    expect(await StorageService.getBool(StorageKeys.quickAuthEnabled), isFalse);
  });

  test('修改密码会清除系统快速验证配置', () async {
    await PasswordService.setPassword('old-password');
    await PasswordService.setQuickAuthEnabled(true);

    expect(await PasswordService.isQuickAuthEnabled(), isTrue);

    await PasswordService.setPassword('new-password');

    expect(await PasswordService.verifyPassword('new-password'), isTrue);
    expect(await PasswordService.isQuickAuthEnabled(), isFalse);
    expect(await StorageService.getBool(StorageKeys.quickAuthEnabled), isFalse);
  });

  test('移除密码保护会清除系统快速验证配置', () async {
    await PasswordService.setPassword('password');
    await PasswordService.setQuickAuthEnabled(true);

    expect(await PasswordService.isQuickAuthEnabled(), isTrue);

    await PasswordService.removePassword();

    expect(await PasswordService.isPasswordSet(), isFalse);
    expect(await PasswordService.isQuickAuthEnabled(), isFalse);
    expect(await StorageService.getBool(StorageKeys.quickAuthEnabled), isFalse);
  });
}
