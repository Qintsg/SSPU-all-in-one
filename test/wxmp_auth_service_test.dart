/*
 * 微信公众号平台认证服务测试 — 校验认证状态诊断
 * @Project : SSPU-all-in-one
 * @File : wxmp_auth_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';
import 'package:sspu_all_in_one/services/wxmp_auth_service.dart';

void main() {
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
}
