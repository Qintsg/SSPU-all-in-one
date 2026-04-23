/*
 * 应用信息服务 — 读取运行时包名、版本号与构建号
 * @Project : SSPU-all-in-one
 * @File : app_info_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:package_info_plus/package_info_plus.dart';

/// 关于页使用的应用版本信息。
class AppVersionInfo {
  final String version;
  final String buildNumber;

  const AppVersionInfo({required this.version, required this.buildNumber});

  String get displayText =>
      buildNumber.isEmpty ? '版本 $version' : '版本 $version+$buildNumber';
}

/// 统一读取应用包信息，避免页面直接依赖平台插件。
class AppInfoService {
  AppInfoService._();

  static final AppInfoService instance = AppInfoService._();

  Future<AppVersionInfo> loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }
}
