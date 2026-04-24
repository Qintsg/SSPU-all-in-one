/*
 * 应用数据目录服务 — 统一解析用户级配置、缓存与运行态文件目录
 * @Project : SSPU-all-in-one
 * @File : app_data_directory_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 应用数据目录服务。
/// 桌面端使用用户目录，移动端使用系统分配的应用支持目录。
class AppDataDirectoryService {
  AppDataDirectoryService._();

  /// 统一目录名，保持桌面端和移动端逻辑一致。
  static const String directoryName = '.sspu-all-in-one';

  /// 测试专用目录覆盖，避免单元测试读写真实用户目录。
  static String? _debugDirectoryOverride;

  /// 测试专用：覆盖应用数据根目录。
  @visibleForTesting
  static void debugSetDirectoryForTesting(String? directoryPath) {
    _debugDirectoryOverride = directoryPath;
  }

  /// Android / iOS 沙盒不保证存在可写 HOME，必须使用系统分配目录。
  static bool get _requiresPlatformSupportDirectory =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 获取应用数据根目录路径；不存在时不会立即创建。
  static Future<String> getRootDirectoryPath() async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台不支持本地文件目录');
    }
    if (_debugDirectoryOverride != null) return _debugDirectoryOverride!;

    if (_requiresPlatformSupportDirectory) {
      final supportDirectory = await getApplicationSupportDirectory();
      return '${supportDirectory.path}${Platform.pathSeparator}$directoryName';
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return '${Directory.current.path}${Platform.pathSeparator}$directoryName';
    }
    return '$home${Platform.pathSeparator}$directoryName';
  }

  /// 确保并返回应用数据根目录。
  static Future<Directory> ensureRootDirectory() async {
    final directory = Directory(await getRootDirectoryPath());
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// 解析并确保指定子目录存在。
  static Future<String> ensureDirectoryPath(String relativePath) async {
    final root = await ensureRootDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$relativePath',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  /// 解析根目录下的文件路径，并确保父目录存在。
  static Future<String> ensureFilePath(String fileName) async {
    final root = await ensureRootDirectory();
    return '${root.path}${Platform.pathSeparator}$fileName';
  }
}
