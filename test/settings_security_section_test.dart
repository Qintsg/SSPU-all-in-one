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
  Future<void> configureNarrowView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(320, 720));
  }

  Future<void> resetView(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  }

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
              isQuickAuthEnabled: false,
              isQuickAuthAvailable: false,
              isQuickAuthBusy: false,
              onQuickAuthChanged: (_) {},
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

  testWidgets('系统快速验证在可用时显示开关，不可用时显示密码兜底提示', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: SingleChildScrollView(
            child: SettingsSecuritySection(
              isPasswordEnabled: false,
              onPasswordProtectionChanged: (_) {},
              onChangePassword: () {},
              isQuickAuthEnabled: false,
              isQuickAuthAvailable: true,
              isQuickAuthBusy: false,
              onQuickAuthChanged: (_) {},
              onLock: null,
              onClearMessageCache: () {},
              onClearAllData: () {},
            ),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('学工号（OA账号）'));

    expect(find.text('系统快速验证'), findsNothing);

    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: SingleChildScrollView(
            child: SettingsSecuritySection(
              isPasswordEnabled: true,
              onPasswordProtectionChanged: (_) {},
              onChangePassword: () {},
              isQuickAuthEnabled: true,
              isQuickAuthAvailable: false,
              isQuickAuthBusy: false,
              onQuickAuthChanged: (_) {},
              onLock: null,
              onClearMessageCache: () {},
              onClearAllData: () {},
            ),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('学工号（OA账号）'));

    expect(find.text('系统快速验证不可用'), findsOneWidget);
    expect(find.textContaining('仍可使用应用密码手动解锁'), findsOneWidget);

    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: SingleChildScrollView(
            child: SettingsSecuritySection(
              isPasswordEnabled: true,
              onPasswordProtectionChanged: (_) {},
              onChangePassword: () {},
              isQuickAuthEnabled: true,
              isQuickAuthAvailable: true,
              isQuickAuthBusy: false,
              onQuickAuthChanged: (_) {},
              onLock: null,
              onClearMessageCache: () {},
              onClearAllData: () {},
            ),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('系统快速验证'));

    expect(find.text('系统快速验证'), findsOneWidget);
    expect(find.textContaining('仍可输入密码解锁'), findsOneWidget);
  });

  testWidgets('窄屏安全设置堆叠 quick auth 与数据管理操作', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await configureNarrowView(tester);

    try {
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: SingleChildScrollView(
              child: SettingsSecuritySection(
                isPasswordEnabled: true,
                onPasswordProtectionChanged: (_) {},
                onChangePassword: () {},
                isQuickAuthEnabled: true,
                isQuickAuthAvailable: true,
                isQuickAuthBusy: true,
                onQuickAuthChanged: (_) {},
                onLock: null,
                onClearMessageCache: () {},
                onClearAllData: () {},
              ),
            ),
          ),
        ),
      );
      await pumpUntilFound(tester, find.text('系统快速验证'));

      expect(find.text('系统快速验证'), findsOneWidget);
      expect(find.text('立即上锁'), findsOneWidget);
      expect(find.text('清理信息中心缓存'), findsOneWidget);
      expect(find.text('清除所有数据'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await resetView(tester);
    }
  });
}
