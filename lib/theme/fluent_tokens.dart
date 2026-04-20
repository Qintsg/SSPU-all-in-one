/*
 * Fluent 2 Design Token 体系 — 统一管理颜色、排版、间距、圆角等视觉参数
 * 参考 https://fluent2.microsoft.design/ 设计规范
 * @Project : SSPU-all-in-one
 * @File : fluent_tokens.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
 */

import 'package:fluent_ui/fluent_ui.dart';

// ==================== 颜色 Token ====================

/// Fluent 2 语义色 — 亮色主题
/// 品牌色采用 Brand Blue #0078D4 体系
class FluentLightColors {
  FluentLightColors._();

  // --- 品牌色 ---
  /// 主品牌色（按钮、链接、高亮）
  static const Color brandPrimary = Color(0xFF0078D4);
  /// 品牌色悬停态
  static const Color brandHover = Color(0xFF106EBE);
  /// 品牌色按下态
  static const Color brandPressed = Color(0xFF005A9E);

  // --- 背景色 ---
  /// 应用主背景（Scaffold）
  static const Color backgroundDefault = Color(0xFFF5F5F5);
  /// 卡片/面板背景
  static const Color backgroundCard = Color(0xFFFFFFFF);
  /// 侧边栏背景
  static const Color backgroundSidebar = Color(0xFFFAFAFA);
  /// 次要背景（分区块）
  static const Color backgroundSecondary = Color(0xFFF0F0F0);

  // --- 前景/文字色 ---
  /// 主文字
  static const Color textPrimary = Color(0xFF242424);
  /// 次要文字
  static const Color textSecondary = Color(0xFF616161);
  /// 占位/禁用文字
  static const Color textDisabled = Color(0xFFA0A0A0);

  // --- 边框/分隔线 ---
  /// 卡片边框
  static const Color borderSubtle = Color(0xFFE0E0E0);
  /// 分隔线
  static const Color divider = Color(0xFFE8E8E8);

  // --- 状态色 ---
  /// 成功/确认
  static const Color statusSuccess = Color(0xFF0F7B0F);
  /// 警告/注意
  static const Color statusWarning = Color(0xFFD83B01);
  /// 错误/危险
  static const Color statusError = Color(0xFFC42B1C);
  /// 信息/提示
  static const Color statusInfo = Color(0xFF0078D4);

  // --- 交互状态色 ---
  /// 悬停填充（列表项/卡片 hover）
  static const Color hoverFill = Color(0x0A000000);
  /// 按下填充
  static const Color activeFill = Color(0x06000000);
  /// 未读指示器
  static const Color unreadIndicator = Color(0xFF0078D4);
}

/// Fluent 2 语义色 — 暗色主题
class FluentDarkColors {
  FluentDarkColors._();

  // --- 品牌色 ---
  static const Color brandPrimary = Color(0xFF4CC2FF);
  static const Color brandHover = Color(0xFF62CDFF);
  static const Color brandPressed = Color(0xFF2899D4);

  // --- 背景色 ---
  static const Color backgroundDefault = Color(0xFF1F1F1F);
  /// 卡片背景（稍亮于主背景，增强层级区分）
  static const Color backgroundCard = Color(0xFF2D2D2D);
  static const Color backgroundSidebar = Color(0xFF252525);
  static const Color backgroundSecondary = Color(0xFF363636);

  // --- 前景/文字色 ---
  /// 主文字（提亮至接近纯白，WCAG AA 对比度）
  static const Color textPrimary = Color(0xFFE8E8E8);
  /// 次要文字（提亮以保证可读性）
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textDisabled = Color(0xFF5C5C5C);

  // --- 边框/分隔线 ---
  static const Color borderSubtle = Color(0xFF3D3D3D);
  static const Color divider = Color(0xFF383838);

  // --- 状态色 ---
  /// 成功/确认（暗色下提亮以保证对比度）
  static const Color statusSuccess = Color(0xFF6CCB5F);
  /// 警告/注意
  static const Color statusWarning = Color(0xFFFCE100);
  /// 错误/危险
  static const Color statusError = Color(0xFFFF99A4);
  /// 信息/提示
  static const Color statusInfo = Color(0xFF4CC2FF);

  // --- 交互状态色 ---
  /// 悬停填充（列表项/卡片 hover）
  static const Color hoverFill = Color(0x0AFFFFFF);
  /// 按下填充
  static const Color activeFill = Color(0x06FFFFFF);
  /// 未读指示器
  static const Color unreadIndicator = Color(0xFF4CC2FF);
}

// ==================== 阴影/浮层 Token ====================

/// Fluent 2 浮层阴影系统
class FluentElevation {
  FluentElevation._();

  /// 卡片阴影（微弱）
  static const List<BoxShadow> cardRest = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// 卡片悬停阴影（稍强）
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// 弹窗/浮层阴影
  static const List<BoxShadow> dialog = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 21,
      offset: Offset(0, 8),
    ),
  ];

  /// 暗色主题卡片阴影（取消阴影，改用边框区分层级）
  static const List<BoxShadow> cardRestDark = [];

  /// 暗色主题卡片悬停阴影
  static const List<BoxShadow> cardHoverDark = [
    BoxShadow(
      color: Color(0x20000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

// ==================== 间距 Token ====================

/// Fluent 2 间距系统 — 4px 基准网格
class FluentSpacing {
  FluentSpacing._();

  /// 2px — 极小间距（图标与文字间隙）
  static const double xxs = 2.0;
  /// 4px — 紧凑间距
  static const double xs = 4.0;
  /// 8px — 元素内间距
  static const double s = 8.0;
  /// 12px — 行间距
  static const double m = 12.0;
  /// 16px — 分组间距
  static const double l = 16.0;
  /// 20px — 卡片内边距
  static const double xl = 20.0;
  /// 24px — 区域间距
  static const double xxl = 24.0;
  /// 32px — 大段间距
  static const double xxxl = 32.0;

  /// 卡片内边距
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  /// 页面水平边距
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: xxl);
  /// 列表项垂直间距
  static const EdgeInsets listItemVertical = EdgeInsets.symmetric(vertical: s);
}

// ==================== 圆角 Token ====================

/// Fluent 2 圆角系统
class FluentRadius {
  FluentRadius._();

  /// 2px — 按钮/小元素
  static const double small = 2.0;
  /// 4px — 标签/徽章
  static const double medium = 4.0;
  /// 6px — 输入框
  static const double large = 6.0;
  /// 8px — 卡片
  static const double xLarge = 8.0;
  /// 12px — 弹窗/模态框
  static const double xxLarge = 12.0;
  /// 完全圆形
  static const double circular = 9999.0;

  /// 卡片圆角
  static const BorderRadius card = BorderRadius.all(Radius.circular(xLarge));
  /// 按钮圆角
  static const BorderRadius button = BorderRadius.all(Radius.circular(medium));
  /// 标签圆角
  static const BorderRadius tag = BorderRadius.all(Radius.circular(medium));
}

// ==================== 排版 Token ====================

/// Fluent 2 排版尺寸参考（实际排版通过 FluentThemeData.typography 控制）
/// 此处仅定义语义别名，方便引用
class FluentTypographySize {
  FluentTypographySize._();

  /// 标题
  static const double title = 20.0;
  /// 副标题
  static const double subtitle = 16.0;
  /// 正文加粗
  static const double bodyStrong = 14.0;
  /// 正文
  static const double body = 14.0;
  /// 辅助文字
  static const double caption = 12.0;
  /// 极小文字
  static const double overline = 10.0;
}

// ==================== 动效 Token ====================

/// Fluent 2 动效时长
class FluentDuration {
  FluentDuration._();

  /// 快速过渡（hover、focus 反馈）
  static const Duration fast = Duration(milliseconds: 100);
  /// 常规过渡（展开、切换）
  static const Duration normal = Duration(milliseconds: 200);
  /// 慢速过渡（页面切换、大面积动画）
  static const Duration slow = Duration(milliseconds: 300);
}

/// Fluent 2 缓动曲线
class FluentEasing {
  FluentEasing._();

  /// 标准缓动（大多数交互）
  static const Curve standard = Curves.easeInOut;
  /// 加速离开
  static const Curve decelerate = Curves.easeOut;
  /// 弹性进入
  static const Curve accelerate = Curves.easeIn;
}

// ==================== 响应式断点 Token ====================

/// 响应式布局断点——根据窗口宽度判断设备类型
class FluentBreakpoints {
  FluentBreakpoints._();

  /// 手机上限
  static const double compact = 640.0;
  /// 平板上限
  static const double medium = 1024.0;
  /// 桐面上限（超过即为宽屏）
  static const double expanded = 1440.0;

  /// 根据宽度返回当前设备类型
  static DeviceType fromWidth(double width) {
    if (width < compact) return DeviceType.phone;
    if (width < medium) return DeviceType.tablet;
    return DeviceType.desktop;
  }
}

/// 设备类型枚举
enum DeviceType {
  /// 手机（< 640px）
  phone,
  /// 平板（640–1024px）
  tablet,
  /// 桌面（≥ 1024px）
  desktop,
}

// ==================== 主题工厂 ====================

/// 基于 Fluent 2 Token 构建完整的 FluentThemeData
class FluentTokenTheme {
  FluentTokenTheme._();

  /// 字体族
  static const String fontFamily = 'MiSans';

  /// 亮色主题
  static FluentThemeData light() {
    return FluentThemeData(
      accentColor: Colors.blue,
      brightness: Brightness.light,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: FluentLightColors.backgroundDefault,
      typography: Typography.fromBrightness(
        brightness: Brightness.light,
        color: FluentLightColors.textPrimary,
      ).apply(fontFamily: fontFamily),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: FluentLightColors.backgroundSidebar,
      ),
    );
  }

  /// 暗色主题
  static FluentThemeData dark() {
    return FluentThemeData(
      accentColor: Colors.blue,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: FluentDarkColors.backgroundDefault,
      typography: Typography.fromBrightness(
        brightness: Brightness.dark,
        color: FluentDarkColors.textPrimary,
      ).apply(fontFamily: fontFamily),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: FluentDarkColors.backgroundSidebar,
      ),
    );
  }
}
