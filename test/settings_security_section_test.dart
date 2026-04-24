/*
 * 安全设置分区测试 — 校验教务凭据展示状态与密码回访隐藏行为
 * @Project : SSPU-all-in-one
 * @File : settings_security_section_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-24
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/widgets/settings_security_section.dart';

/// 等待目标组件出现，覆盖安全存储异步加载后的首帧。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  testWidgets('安全设置页显示教务凭据状态但不回填密码', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
      sportsQueryPassword: 'sports-pass',
      emailPassword: 'mail-pass',
    );

    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: SingleChildScrollView(
            child: SettingsSecuritySection(
              isPasswordEnabled: false,
              onPasswordProtectionChanged: (_) {},
              onChangePassword: () {},
              onLock: null,
              onClearMessageCache: () {},
              onClearAllData: () {},
            ),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('学工号（OA账号）'));

    expect(find.text('教务凭据'), findsOneWidget);
    expect(find.text('数据均加密存储在本地，不会上传至云端；密码框留空时不修改已保存密码。'), findsOneWidget);
    expect(find.text('20260001'), findsOneWidget);
    expect(find.text('已填写'), findsNWidgets(3));
    expect(find.text('oa-pass'), findsNothing);
    expect(find.text('sports-pass'), findsNothing);
    expect(find.text('mail-pass'), findsNothing);
  });
}
