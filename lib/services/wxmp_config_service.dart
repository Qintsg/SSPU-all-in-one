/*
 * 微信公众号平台配置文件服务 — 管理可手动编辑的 wxmp_config.toml
 * @Project : SSPU-all-in-one
 * @File : wxmp_config_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 微信公众号平台抓取配置。
class WxmpConfig {
  /// Cookie 覆盖值；为空时使用扫码登录保存的 Cookie。
  final String cookie;

  /// Token 覆盖值；为空时使用扫码登录保存的 Token。
  final String token;

  /// 可选 AppID，供公众号平台接口变体使用。
  final String appId;

  /// 请求 User-Agent。
  final String userAgent;

  /// 单次文章列表请求条数。
  final int perRequestArticleCount;

  /// 请求间隔毫秒数。
  final int requestDelayMs;

  const WxmpConfig({
    required this.cookie,
    required this.token,
    required this.appId,
    required this.userAgent,
    required this.perRequestArticleCount,
    required this.requestDelayMs,
  });

  /// 默认配置仅提供非敏感默认项，敏感字段留空由用户自行填写。
  factory WxmpConfig.defaults() {
    return const WxmpConfig(
      cookie: '',
      token: '',
      appId: '',
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
      perRequestArticleCount: 5,
      requestDelayMs: 3000,
    );
  }

  /// 从简单 TOML 文本读取配置；未知字段会被忽略。
  factory WxmpConfig.fromToml(String content) {
    final values = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('#') ||
          trimmedLine.startsWith('[')) {
        continue;
      }

      final separatorIndex = trimmedLine.indexOf('=');
      if (separatorIndex <= 0) continue;
      final key = trimmedLine.substring(0, separatorIndex).trim();
      final rawValue = trimmedLine.substring(separatorIndex + 1).trim();
      values[key] = _decodeTomlValue(rawValue);
    }

    final defaults = WxmpConfig.defaults();
    return WxmpConfig(
      cookie: values['cookie'] ?? defaults.cookie,
      token: values['token'] ?? defaults.token,
      appId: values['app_id'] ?? defaults.appId,
      userAgent: values['user_agent'] ?? defaults.userAgent,
      perRequestArticleCount: _readPositiveInt(
        values['per_request_article_count'],
        defaults.perRequestArticleCount,
        min: 1,
        max: 20,
      ),
      requestDelayMs: _readPositiveInt(
        values['request_delay_ms'],
        defaults.requestDelayMs,
        min: 0,
        max: 60000,
      ),
    );
  }

  /// 转为可读 TOML，便于用户直接编辑。
  String toToml() {
    return '''
# SSPU All-in-One 微信公众号平台配置
# 空字符串表示使用扫码登录保存的 Cookie / Token。
# 保存后可回到设置页点击“重新加载配置”立即生效。

[wxmp]
cookie = "${_escapeTomlString(cookie)}"
token = "${_escapeTomlString(token)}"
app_id = "${_escapeTomlString(appId)}"
user_agent = "${_escapeTomlString(userAgent)}"
per_request_article_count = $perRequestArticleCount
request_delay_ms = $requestDelayMs
''';
  }

  static String _decodeTomlValue(String rawValue) {
    final commentIndex = rawValue.indexOf('#');
    final withoutComment = commentIndex >= 0
        ? rawValue.substring(0, commentIndex).trim()
        : rawValue.trim();
    if (withoutComment.length >= 2 &&
        withoutComment.startsWith('"') &&
        withoutComment.endsWith('"')) {
      return withoutComment
          .substring(1, withoutComment.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\');
    }
    return withoutComment;
  }

  static String _escapeTomlString(String value) {
    return value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  }

  static int _readPositiveInt(
    String? value,
    int fallback, {
    required int min,
    required int max,
  }) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return fallback;
    return parsed.clamp(min, max);
  }
}

/// 微信公众号平台配置文件服务。
class WxmpConfigService {
  WxmpConfigService._();

  static final WxmpConfigService instance = WxmpConfigService._();

  String? _debugConfigPathOverride;

  /// 配置文件名固定，方便用户定位和备份。
  static const String fileName = 'wxmp_config.toml';

  /// 获取配置文件路径。
  Future<String> getConfigPath() async {
    if (_debugConfigPathOverride != null) return _debugConfigPathOverride!;
    return '${await _resolveConfigDirectory()}${Platform.pathSeparator}$fileName';
  }

  /// 测试专用：覆盖配置文件路径，避免读取用户真实配置。
  @visibleForTesting
  void debugSetConfigPathForTesting(String? configPath) {
    _debugConfigPathOverride = configPath;
  }

  /// 确保配置文件存在，并返回路径。
  Future<String> ensureConfigFile() async {
    final configPath = await getConfigPath();
    final configFile = File(configPath);
    if (!await configFile.exists()) {
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(WxmpConfig.defaults().toToml());
    }
    return configPath;
  }

  /// 读取当前配置；文件不存在时会先创建默认文件。
  Future<WxmpConfig> loadConfig() async {
    final configPath = await ensureConfigFile();
    final content = await File(configPath).readAsString();
    return WxmpConfig.fromToml(content);
  }

  /// 使用系统编辑器打开配置文件；优先尝试 VS Code。
  Future<void> openConfigFile() async {
    final configPath = await ensureConfigFile();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        await Process.start('code', [
          configPath,
        ], mode: ProcessStartMode.detached);
        return;
      } catch (_) {
        // 未安装 code 命令时交给系统默认应用处理。
      }
    }

    final fileUri = Uri.file(configPath);
    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<String> _resolveConfigDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台不支持本地配置文件');
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return '$appData${Platform.pathSeparator}SSPU-all-in-one';
      }
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return Directory.current.path;
    }
    if (Platform.isMacOS) {
      return '$home${Platform.pathSeparator}Library${Platform.pathSeparator}'
          'Application Support${Platform.pathSeparator}SSPU-all-in-one';
    }
    return '$home${Platform.pathSeparator}.config${Platform.pathSeparator}'
        'SSPU-all-in-one';
  }
}
