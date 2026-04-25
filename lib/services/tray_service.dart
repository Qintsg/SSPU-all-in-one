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
/// [executableDir] 当前运行可执行文件所在目录。
/// [isWindows] 是否为 Windows 平台，用于拼接 `data/flutter_assets` 图标路径。
/// [isLinux] 是否为 Linux 平台，用于拼接 bundle 内图标路径。
/// [isMacOS] 是否为 macOS 平台，用于拼接 App.framework/Resources 图标路径。
/// @returns 按优先级排序的候选路径列表，最后一项始终是 `assets/images/app_icon.png` 回退路径。
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

  // 统一回退到项目相对路径，避免任何模式下路径解析失败时直接崩溃。
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
    } catch (error, stackTrace) {
      // 托盘初始化异常不应阻断主窗口启动。
      debugPrint('TrayService 初始化失败，已降级为无托盘模式。错误：${error.toString()}');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
    }
  }

  /// 根据当前平台解析托盘图标路径。
  /// 按候选顺序选择第一个存在的路径，全部不存在时回退到项目相对路径。
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
    // setIcon 允许相对路径；即使文件暂不可见，仍保留最后回退值避免空路径。
    return candidates.last;
  }

  /// 销毁托盘图标（应用退出前调用）
  Future<void> destroy() async {
    if (!_initialized) return;
    await trayManager.destroy();
    _initialized = false;
  }
}
