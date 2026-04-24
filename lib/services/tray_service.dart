/*
 * 系统托盘服务 — 管理 Windows 任务栏托盘图标与右键菜单
 * @Project : SSPU-all-in-one
 * @File : tray_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// 构建不同平台下托盘图标候选路径（按优先级排序）。
@visibleForTesting
List<String> buildTrayIconCandidates({
  required String executableDir,
  required bool isWindows,
  required bool isLinux,
  required bool isMacOS,
}) {
  final candidates = <String>[];

  if (isWindows) {
    candidates.add('$executableDir\\data\\flutter_assets\\assets\\images\\app_icon.ico');
    candidates.add('$executableDir\\data\\flutter_assets\\assets\\images\\app_icon.png');
  } else if (isLinux) {
    candidates.add('$executableDir/data/flutter_assets/assets/images/app_icon.png');
  } else if (isMacOS) {
    candidates.add(
      '$executableDir/../Frameworks/App.framework/Resources/flutter_assets/assets/images/app_icon.png',
    );
    candidates.add(
      '$executableDir/../Resources/flutter_assets/assets/images/app_icon.png',
    );
  }

  // 开发阶段统一回退到项目相对路径，避免平台路径解析失败时直接崩溃。
  candidates.add('assets/images/app_icon.png');
  return candidates;
}

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

    try {
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
    } catch (error) {
      // 托盘初始化异常不应阻断主窗口启动。
      debugPrint('TrayService 初始化失败，已降级为无托盘模式：$error');
      _initialized = false;
    }
  }

  /// 根据运行环境解析托盘图标的文件系统路径
  /// release 模式：flutter_assets 内; debug 模式：项目根目录回退
  String _resolveIconPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = buildTrayIconCandidates(
      executableDir: exeDir,
      isWindows: Platform.isWindows,
      isLinux: Platform.isLinux,
      isMacOS: Platform.isMacOS,
    );
    for (final iconPath in candidates) {
      if (File(iconPath).existsSync()) return iconPath;
    }
    // setIcon 允许相对路径；即使文件暂不可见，也保留最后回退值避免空路径。
    return candidates.last;
  }

  /// 销毁托盘图标（应用退出前调用）
  Future<void> destroy() async {
    if (!_initialized) return;
    await trayManager.destroy();
    _initialized = false;
  }
}
