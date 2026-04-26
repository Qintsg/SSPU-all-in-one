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

  test('macOS DMG 打包前重新 ad-hoc 签名清理残留 entitlement', () {
    final releaseWorkflow = File('.github/workflows/release.yml').readAsStringSync();

    // Release workflow 必须先剥离构建产物签名中的残留权限，再执行发布前拦截。
    final adHocSigningIndex = releaseWorkflow.indexOf(
      'codesign --force --deep --sign -',
    );
    final entitlementCheckIndex = releaseWorkflow.indexOf(
      'unsigned macOS 产物不得携带',
    );

    expect(adHocSigningIndex, greaterThanOrEqualTo(0));
    expect(entitlementCheckIndex, greaterThan(adHocSigningIndex));
  });
}
