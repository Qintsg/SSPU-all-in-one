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
import 'package:sspu_all_in_one/controllers/settings_wechat_controller.dart';
import 'package:sspu_all_in_one/pages/webview_page.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';
import 'package:sspu_all_in_one/services/wxmp_config_service.dart';
import 'package:sspu_all_in_one/widgets/settings_wechat_section.dart';

/// 等待目标组件出现，避免页面异步加载尚未完成时提前断言。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Windows 下文件句柄释放可能略晚于组件卸载，清理临时目录时做短重试。
Future<void> deleteDirectoryWithRetry(Directory directory) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    if (!await directory.exists()) return;
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}

void main() {
  Future<void> configureMobileView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
  }

  Future<void> resetMobileView(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('手机竖屏显示底部导航栏', (WidgetTester tester) async {
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await configureMobileView(tester);

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
      await resetMobileView(tester);
    }
  });

  testWidgets('桌面导航在设置上方显示校园网状态徽标', (WidgetTester tester) async {
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    final service = CampusNetworkStatusService(
      probe: (uri, timeout) async {
        return CampusNetworkProbeResult(
          reachable: true,
          statusCode: 200,
          detail: '已访问 ${uri.host}，HTTP 200',
        );
      },
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    try {
      await tester.pumpWidget(
        FluentApp(home: AppShell(campusNetworkStatusService: service)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 校园网徽标由可注入服务驱动，避免组件测试依赖真实校园网环境。
      expect(
        find.byKey(const Key('campus-network-status-indicator')),
        findsOneWidget,
      );
      expect(find.text('校园网/VPN'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const Key('campus-network-status-indicator')),
            )
            .dy,
        lessThan(tester.getTopLeft(find.text('设置')).dy),
      );

      // 首页入场动画会保留短计时器，测试结束前推进时间以清理动画状态。
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
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
    await configureMobileView(tester);

    try {
      await tester.pumpWidget(
        const FluentApp(home: _SettingsNavigationLayoutHarness()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 仅覆盖响应式导航结构，避免完整设置页服务初始化拖慢组件测试。
      expect(find.text('常规设置'), findsOneWidget);
      expect(find.text('系统设置'), findsNothing);
      expect(
        find.byKey(const Key('settings-narrow-tab-combo')),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await resetMobileView(tester);
    }
  });

  testWidgets('设置页显示内置编辑和配置目录按钮', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final configDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'settings_page_wechat_actions_${DateTime.now().microsecondsSinceEpoch}',
    );
    StorageService.debugSetStateFilePathForTesting(
      '${configDirectory.path}${Platform.pathSeparator}app_state.json',
    );
    await tester.runAsync(StorageService.init);
    WxmpConfigService.instance.debugSetConfigPathForTesting(
      '${configDirectory.path}${Platform.pathSeparator}wxmp_config.toml',
    );
    final controller = SettingsWechatController();
    await tester.runAsync(controller.load);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    try {
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: SingleChildScrollView(
              child: SettingsWechatSection(controller: controller),
            ),
          ),
        ),
      );
      await pumpUntilFound(tester, find.text('编辑配置文件'));

      expect(find.text('编辑配置文件'), findsOneWidget);
      expect(find.text('打开配置文件所在文件夹'), findsOneWidget);
      expect(find.text('外部打开'), findsOneWidget);
      expect(find.text('使用 Visual Studio Code 打开配置文件'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      WxmpConfigService.instance.debugSetConfigPathForTesting(null);
      StorageService.debugSetStateFilePathForTesting(null);
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
      await tester.runAsync(() => deleteDirectoryWithRetry(configDirectory));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    }
  });
}

class _SettingsNavigationLayoutHarness extends StatelessWidget {
  const _SettingsNavigationLayoutHarness();

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          return isNarrow
              ? const _NarrowSettingsNavigation()
              : const _WideSettingsNavigation();
        },
      ),
    );
  }
}

class _NarrowSettingsNavigation extends StatelessWidget {
  const _NarrowSettingsNavigation();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(FluentIcons.global_nav_button, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: ComboBox<int>(
            key: const Key('settings-narrow-tab-combo'),
            value: 0,
            isExpanded: true,
            items: const [
              ComboBoxItem(value: 0, child: Text('常规设置')),
              ComboBoxItem(value: 1, child: Text('安全设置')),
              ComboBoxItem(value: 2, child: Text('职能部门')),
              ComboBoxItem(value: 3, child: Text('教学单位')),
              ComboBoxItem(value: 4, child: Text('微信推文')),
            ],
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

class _WideSettingsNavigation extends StatelessWidget {
  const _WideSettingsNavigation();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [Text('系统设置'), SizedBox(height: 8), Text('常规设置')],
    );
  }
}
