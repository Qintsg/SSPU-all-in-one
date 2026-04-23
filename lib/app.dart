/*
 * 应用主体 — 根据设备形态切换侧边栏导航与底部导航
 * 桌面/平板继续使用 Fluent NavigationView，手机竖屏使用底部导航栏
 * @Project : SSPU-all-in-one
 * @File : app.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import 'pages/about_page.dart';
import 'pages/academic_page.dart';
import 'pages/home_page.dart';
import 'pages/info_page.dart';
import 'pages/quick_links_page.dart';
import 'pages/settings_page.dart';
import 'theme/fluent_tokens.dart';

/// 仅移动端原生平台需要启用竖屏底部导航。
bool get _supportsMobileBottomNavigation {
  if (kIsWeb) return false;

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

/// 应用主体骨架
/// 管理导航结构与页面切换
class AppShell extends StatefulWidget {
  /// 手动上锁回调
  final VoidCallback? onLock;

  const AppShell({super.key, this.onLock});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 当前选中的导航项索引
  int _selectedIndex = 0;

  List<_AppDestination> get _destinations => [
    const _AppDestination(
      title: '主页',
      icon: FluentIcons.home,
      body: HomePage(),
    ),
    const _AppDestination(
      title: '教务',
      icon: FluentIcons.education,
      body: AcademicPage(),
    ),
    const _AppDestination(
      title: '信息',
      icon: FluentIcons.info,
      body: InfoPage(),
    ),
    const _AppDestination(
      title: '跳转',
      icon: FluentIcons.link,
      body: QuickLinksPage(),
    ),
    _AppDestination(
      title: '设置',
      icon: FluentIcons.settings,
      body: SettingsPage(onLock: widget.onLock),
    ),
    const _AppDestination(
      title: '关于',
      icon: FluentIcons.info_solid,
      body: AboutPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final width = MediaQuery.sizeOf(context).width;
    final orientation = MediaQuery.orientationOf(context);
    final deviceType = FluentBreakpoints.fromWidth(width);
    final useBottomNavigation =
        _supportsMobileBottomNavigation &&
        deviceType == DeviceType.phone &&
        orientation == Orientation.portrait;

    if (useBottomNavigation) {
      return _MobileBottomNavigationShell(
        destinations: destinations,
        selectedIndex: _selectedIndex,
        onChanged: (index) => setState(() => _selectedIndex = index),
      );
    }

    // 规避 Flutter Windows 引擎已知的 AXTree 更新报错
    return ExcludeSemantics(
      child: NavigationView(
        transitionBuilder: (child, animation) {
          return EntrancePageTransition(animation: animation, child: child);
        },
        pane: NavigationPane(
          selected: _selectedIndex,
          onChanged: (index) => setState(() => _selectedIndex = index),
          // 自动响应屏幕宽度切换显示模式
          displayMode: PaneDisplayMode.auto,
          items: destinations.take(4).map(_buildPaneItem).toList(),
          footerItems: destinations.skip(4).map(_buildPaneItem).toList(),
        ),
      ),
    );
  }

  PaneItem _buildPaneItem(_AppDestination destination) {
    return PaneItem(
      icon: Icon(destination.icon),
      title: Text(destination.title),
      body: destination.body,
    );
  }
}

class _AppDestination {
  final String title;
  final IconData icon;
  final Widget body;

  const _AppDestination({
    required this.title,
    required this.icon,
    required this.body,
  });
}

class _MobileBottomNavigationShell extends StatelessWidget {
  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _MobileBottomNavigationShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? FluentDarkColors.backgroundSidebar
        : FluentLightColors.backgroundSidebar;
    final borderColor = isDark
        ? FluentDarkColors.borderSubtle
        : FluentLightColors.borderSubtle;

    return Column(
      children: [
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: destinations[selectedIndex].body,
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            key: const Key('mobile-bottom-navigation'),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _MobileNavigationItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onPressed: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileNavigationItem extends StatelessWidget {
  final _AppDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  const _MobileNavigationItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final hovered = states.isHovered || states.isPressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? theme.accentColor.withValues(alpha: 0.1)
                : hovered
                ? theme.inactiveColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.icon,
                size: 18,
                color: selected ? theme.accentColor : null,
              ),
              const SizedBox(height: 4),
              Text(
                destination.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: selected
                    ? theme.typography.caption?.copyWith(
                        color: theme.accentColor,
                        fontWeight: FontWeight.w600,
                      )
                    : theme.typography.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}
