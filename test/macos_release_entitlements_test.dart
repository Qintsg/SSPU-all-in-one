/*
 * macOS Release entitlement 配置回归测试
 * @Project : SSPU-all-in-one
 * @File : macos_release_entitlements_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-26
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsigned macOS release 不携带受限 entitlement', () {
    final releaseEntitlements = File(
      'macos/Runner/Release.entitlements',
    ).readAsStringSync();

    // 当前公开 macOS 产物为 unsigned DMG，受限 entitlement 会导致 AMFI 拒绝启动。
    expect(releaseEntitlements, isNot(contains('com.apple.security.')));
    expect(releaseEntitlements, isNot(contains('keychain-access-groups')));
  });
}
