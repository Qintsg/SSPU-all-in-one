/*
 * 应用主体 — NavigationView 导航结构与页面切换动画
 * 使用 Fluent UI NavigationView 实现侧边栏导航
 * @Project : SSPU-all-in-one
 * @File : app.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'pages/home_page.dart';
import 'pages/academic_page.dart';
import 'pages/info_page.dart';
import 'pages/quick_links_page.dart';
import 'pages/settings_page.dart';

/// 应用主体骨架
/// 管理侧边栏导航与各页面的切换及过渡动画
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 当前选中的导航项索引
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      transitionBuilder: (child, animation) {
        return EntrancePageTransition(
          animation: animation,
          child: child,
        );
      },
      pane: NavigationPane(
        selected: _selectedIndex,
        onChanged: (index) => setState(() => _selectedIndex = index),
        // 自动响应屏幕宽度切换显示模式（展开/折叠/最小化）
        displayMode: PaneDisplayMode.auto,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('主页'),
            body: const HomePage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.education),
            title: const Text('教务中心'),
            body: const AcademicPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.info),
            title: const Text('信息中心'),
            body: const InfoPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.link),
            title: const Text('快速跳转'),
            body: const QuickLinksPage(),
          ),
        ],
        // 设置项放在导航栏底部
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('设置'),
            body: const SettingsPage(),
          ),
        ],
      ),
    );
  }
}
