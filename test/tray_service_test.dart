/*
 * 托盘图标路径候选构建测试
 * @Project : SSPU-all-in-one
 * @File : tray_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-24
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/tray_service.dart';

void main() {
  group('buildTrayIconCandidates', () {
    test('windows 优先返回 flutter_assets 内 ico 与 png', () {
      final candidates = buildTrayIconCandidates(
        executableDir: r'C:\app',
        isWindows: true,
        isLinux: false,
        isMacOS: false,
      );

      expect(
        candidates,
        equals([
          r'C:\app\data\flutter_assets\assets\images\app_icon.ico',
          r'C:\app\data\flutter_assets\assets\images\app_icon.png',
          'assets/images/app_icon.png',
        ]),
      );
    });

    test('macOS 包含 app framework 与 resources 两条候选路径', () {
      final candidates = buildTrayIconCandidates(
        executableDir: '/Applications/SSPU.app/Contents/MacOS',
        isWindows: false,
        isLinux: false,
        isMacOS: true,
      );

      expect(
        candidates,
        equals([
          '/Applications/SSPU.app/Contents/MacOS/../Frameworks/App.framework/Resources/flutter_assets/assets/images/app_icon.png',
          '/Applications/SSPU.app/Contents/MacOS/../Resources/flutter_assets/assets/images/app_icon.png',
          'assets/images/app_icon.png',
        ]),
      );
    });

    test('linux 优先返回 bundle flutter_assets 图标路径', () {
      final candidates = buildTrayIconCandidates(
        executableDir: '/opt/sspu',
        isWindows: false,
        isLinux: true,
        isMacOS: false,
      );

      expect(
        candidates,
        equals([
          '/opt/sspu/data/flutter_assets/assets/images/app_icon.png',
          'assets/images/app_icon.png',
        ]),
      );
    });
  });
}
