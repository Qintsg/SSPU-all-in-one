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
import 'package:sspu_all_in_one/pages/webview_page.dart';

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
