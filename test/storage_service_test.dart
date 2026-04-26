/*
 * 统一存储服务测试 — 校验 Web 兼容状态后端不会访问本地文件目录
 * @Project : SSPU-all-in-one
 * @File : storage_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-25
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.debugUseSharedPreferencesStorageForTesting(true);
  });

  tearDown(() {
    StorageService.debugUseSharedPreferencesStorageForTesting(null);
    SharedPreferences.setMockInitialValues({});
  });

  test('SharedPreferences 状态后端可初始化并跨重启读取', () async {
    await StorageService.init();
    await StorageService.setString('sample_string', 'value');
    await StorageService.setBool('sample_bool', true);

    StorageService.debugUseSharedPreferencesStorageForTesting(true);
    await StorageService.init();

    expect(await StorageService.getString('sample_string'), 'value');
    expect(await StorageService.getBool('sample_bool'), isTrue);
    expect(
      await StorageService.getStateFilePath(),
      contains('SharedPreferences'),
    );
  });

  test('SharedPreferences 状态后端会迁移旧键值', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.eulaAccepted: true,
      'legacy_string': 'legacy-value',
    });
    StorageService.debugUseSharedPreferencesStorageForTesting(true);

    await StorageService.init();

    expect(await StorageService.isEulaAccepted(), isTrue);
    expect(await StorageService.getString('legacy_string'), 'legacy-value');
  });
}
