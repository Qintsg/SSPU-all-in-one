/*
 * 基础冒烟测试 — 验证应用能正常启动
 * @Project : SSPU-all-in-one
 * @File : widget_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:flutter_test/flutter_test.dart';
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
}
