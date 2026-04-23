/*
 * 微信公众号平台认证服务测试 — 校验认证状态诊断
 * @Project : SSPU-all-in-one
 * @File : wxmp_auth_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';
import 'package:sspu_all_in_one/services/wxmp_auth_service.dart';
import 'package:sspu_all_in_one/services/wxmp_config_service.dart';

void main() {
  late Directory configDirectory;

  setUp(() async {
    configDirectory = await Directory.systemTemp.createTemp('wxmp_auth_test_');
    WxmpConfigService.instance.debugSetConfigPathForTesting(
      '${configDirectory.path}${Platform.pathSeparator}wxmp_config.toml',
    );
    StorageService.debugSetStateFilePathForTesting(
      '${configDirectory.path}${Platform.pathSeparator}app_state.json',
    );
  });

  tearDown(() async {
    WxmpConfigService.instance.debugSetConfigPathForTesting(null);
    StorageService.debugSetStateFilePathForTesting(null);
    if (await configDirectory.exists()) {
      await configDirectory.delete(recursive: true);
    }
  });

  test('缺少 Cookie 或 Token 时返回不可用认证状态', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final authService = WxmpAuthService.instance;

    await authService.clearAuth();
    final missingCookie = await authService.getAuthStatus();
    expect(missingCookie.state, WxmpAuthState.missingCookie);
    expect(missingCookie.isUsable, isFalse);

    await authService.saveAuth('appmsg_token=abc;', '');
    final missingToken = await authService.getAuthStatus();
    expect(missingToken.state, WxmpAuthState.missingToken);
    expect(missingToken.isUsable, isFalse);
  });

  test('Token 格式异常时拒绝作为有效认证', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final authService = WxmpAuthService.instance;

    await authService.saveAuth('appmsg_token=abc;', 'not-a-number');
    final status = await authService.getAuthStatus();

    // 公众平台 token 正常为数字，异常字符串通常来自提取失败或页面变更。
    expect(status.state, WxmpAuthState.malformedToken);
    expect(status.isUsable, isFalse);
    expect(await authService.hasAuth(), isFalse);
  });

  test('Cookie 与数字 Token 同时存在时认证可用', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final authService = WxmpAuthService.instance;

    await authService.saveAuth('appmsg_token=abc;', '123456');
    final status = await authService.getAuthStatus();

    expect(status.state, WxmpAuthState.ready);
    expect(status.isUsable, isTrue);
    expect(await authService.hasAuth(), isTrue);
    expect(status.message, '认证信息可用');
  });

  test('配置文件中的 Cookie 与 Token 优先于扫码缓存', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final authService = WxmpAuthService.instance;
    await authService.saveAuth('stored-cookie', 'stored-token');
    await WxmpConfigService.instance.ensureConfigFile();
    await File(await WxmpConfigService.instance.getConfigPath()).writeAsString(
      '''
[wxmp]
cookie = "file-cookie"
token = "654321"
''',
    );

    // 高级配置用于 WebView 不可用时手动接管认证信息。
    expect(await authService.getCookie(), 'file-cookie');
    expect(await authService.getToken(), '654321');
    expect((await authService.getAuthStatus()).isUsable, isTrue);
  });
}
