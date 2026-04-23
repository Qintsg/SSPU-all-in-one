/*
 * 基础冒烟测试与移动端导航回归测试
 * @Project : SSPU-all-in-one
 * @File : widget_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/app.dart';
import 'package:sspu_all_in_one/main.dart';
import 'package:sspu_all_in_one/pages/settings_page.dart';
import 'package:sspu_all_in_one/pages/webview_page.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';
import 'package:sspu_all_in_one/services/wxmp_config_service.dart';

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
    await tester.binding.setSurfaceSize(const Size(390, 844));

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

  testWidgets('WebView 遇到无效链接时显示错误页', (WidgetTester tester) async {
    await tester.pumpWidget(
      const FluentApp(
        home: WebViewPage(
          url: 'https://wywh.sspu.edu.cnjavascript:void(0);',
          initialTitle: '无效链接',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 历史缓存中的非法 URL 不应继续传给 WebView 构造器。
    expect(find.text('链接无效，无法打开'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
  });

  testWidgets('设置页窄屏使用顶部下拉切换分区', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final configDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'settings_page_config_${DateTime.now().microsecondsSinceEpoch}',
    );
    WxmpConfigService.instance.debugSetConfigPathForTesting(
      '${configDirectory.path}${Platform.pathSeparator}wxmp_config.toml',
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    try {
      await tester.pumpWidget(const FluentApp(home: SettingsPage()));
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(ProgressRing).evaluate().isEmpty) break;
      }

      // 窄屏不渲染固定左侧导航，避免挤压设置内容。
      expect(find.text('常规设置'), findsOneWidget);
      expect(find.text('系统设置'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      WxmpConfigService.instance.debugSetConfigPathForTesting(null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
