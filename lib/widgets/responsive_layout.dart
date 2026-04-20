/*
 * 响应式布局工具组件 — 根据窗口宽度自动切换布局策略
 * @Project : SSPU-all-in-one
 * @File : responsive_layout.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../theme/fluent_tokens.dart';

/// 响应式布局构建器
/// 根据可用宽度自动判断设备类型，回调 [builder] 传入设备类型与约束
class ResponsiveBuilder extends StatelessWidget {
  /// 布局构建回调
  final Widget Function(
    BuildContext context,
    DeviceType deviceType,
    BoxConstraints constraints,
  ) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = FluentBreakpoints.fromWidth(constraints.maxWidth);
        return builder(context, deviceType, constraints);
      },
    );
  }
}

/// 响应式页面内边距 — 根据设备类型自动调整
/// 手机: 12px, 平板: 20px, 桌面: 24px
class ResponsivePadding extends StatelessWidget {
  /// 子组件
  final Widget child;

  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType, constraints) {
        final padding = switch (deviceType) {
          DeviceType.phone => const EdgeInsets.all(FluentSpacing.m),
          DeviceType.tablet => const EdgeInsets.all(FluentSpacing.xl),
          DeviceType.desktop => const EdgeInsets.all(FluentSpacing.xxl),
        };
        return Padding(padding: padding, child: child);
      },
    );
  }
}

/// 响应式网格列数 — 根据设备类型返回合适的列数
/// [phoneCols] 手机列数（默认 2）
/// [tabletCols] 平板列数（默认 3）
/// [desktopCols] 桌面列数（默认 4）
int responsiveGridColumns(
  DeviceType deviceType, {
  int phoneCols = 2,
  int tabletCols = 3,
  int desktopCols = 4,
}) {
  return switch (deviceType) {
    DeviceType.phone => phoneCols,
    DeviceType.tablet => tabletCols,
    DeviceType.desktop => desktopCols,
  };
}
