/*
 * 基础冒烟测试与移动端导航回归测试
 * @Project : SSPU-all-in-one
 * @File : widget_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/app.dart';
import 'package:sspu_all_in_one/main.dart';

void main() {
  testWidgets('应用启动冒烟测试', (WidgetTester tester) async {
    // 构建应用并渲染首帧
    await tester.pumpWidget(const SSPUApp());
    // 首屏包含持续动画的 ProgressRing，固定推进一帧即可验证启动。
    await tester.pump(const Duration(milliseconds: 100));

    // 验证应用能正常渲染（不崩溃即通过）
    expect(find.byType(SSPUApp), findsOneWidget);
  });

  testWidgets('手机竖屏显示底部导航栏', (WidgetTester tester) async {
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    try {
      await tester.pumpWidget(const FluentApp(home: AppShell()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);

      // 首页使用 flutter_animate，补一段时间让一次性动画定时器自然完成。
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}
