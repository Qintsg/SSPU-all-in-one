/*
 * 系统托盘服务 — 管理 Windows 任务栏托盘图标与右键菜单
 * @Project : SSPU-all-in-one
 * @File : tray_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:io';
import 'package:tray_manager/tray_manager.dart';

/// 系统托盘服务（单例）
/// 负责创建托盘图标、设置右键菜单、销毁托盘资源
class TrayService {
  TrayService._();

  static final TrayService instance = TrayService._();

  bool _initialized = false;

  /// 初始化系统托盘图标和右键菜单
  /// 应在 windowManager 初始化之后调用
  Future<void> init() async {
    if (_initialized) return;

    final iconPath = _resolveIconPath();
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('SSPU All-in-One');

    // 右键菜单：显示主窗口 / 退出
    final menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: '显示主窗口'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: '退出'),
      ],
    );
    await trayManager.setContextMenu(menu);
    _initialized = true;
  }

  /// 根据运行环境解析托盘图标的文件系统路径
  /// release 模式：flutter_assets 内; debug 模式：项目根目录回退
  String _resolveIconPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    // 优先使用 flutter_assets 内的 ICO
    final icoPath =
        '$exeDir\\data\\flutter_assets\\assets\\images\\app_icon.ico';
    if (File(icoPath).existsSync()) return icoPath;
    // 其次尝试 PNG
    final pngPath =
        '$exeDir\\data\\flutter_assets\\assets\\images\\app_icon.png';
    if (File(pngPath).existsSync()) return pngPath;
    // 开发阶段回退到项目根目录相对路径
    return 'assets/images/app_icon.png';
  }

  /// 销毁托盘图标（应用退出前调用）
  Future<void> destroy() async {
    if (!_initialized) return;
    await trayManager.destroy();
    _initialized = false;
  }
}
