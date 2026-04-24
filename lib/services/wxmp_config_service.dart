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

import 'app_data_directory_service.dart';

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

  /// 复制配置并替换指定字段，便于扫码登录后保留用户的非敏感高级参数。
  WxmpConfig copyWith({
    String? cookie,
    String? token,
    String? appId,
    String? userAgent,
    int? perRequestArticleCount,
    int? requestDelayMs,
  }) {
    return WxmpConfig(
      cookie: cookie ?? this.cookie,
      token: token ?? this.token,
      appId: appId ?? this.appId,
      userAgent: userAgent ?? this.userAgent,
      perRequestArticleCount:
          perRequestArticleCount ?? this.perRequestArticleCount,
      requestDelayMs: requestDelayMs ?? this.requestDelayMs,
    );
  }

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
# 文件位于 ~/.sspu-all-in-one/，扫码登录成功后会自动更新 Cookie / Token。
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

  /// 保存当前配置到统一配置目录。
  Future<void> saveConfig(WxmpConfig config) async {
    final configPath = await ensureConfigFile();
    await File(configPath).writeAsString(config.toToml());
  }

  /// 扫码登录成功后回写 Cookie / Token，同时保留用户手动配置的高级参数。
  Future<void> updateAuthCredentials({
    required String cookie,
    required String token,
  }) async {
    final currentConfig = await _loadConfigOrDefaults();
    await saveConfig(currentConfig.copyWith(cookie: cookie, token: token));
  }

  /// 清除配置文件中的认证字段，避免“清除认证”后仍被文件覆盖为可用状态。
  Future<void> clearAuthCredentials() async {
    final currentConfig = await _loadConfigOrDefaults();
    await saveConfig(currentConfig.copyWith(cookie: '', token: ''));
  }

  /// 使用 Visual Studio Code 打开配置文件。
  Future<void> openConfigFileWithVSCode() async {
    final configPath = await ensureConfigFile();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        await Process.start(
          'code',
          [configPath],
          mode: ProcessStartMode.detached,
        );
      } on ProcessException {
        throw StateError('未安装 Visual Studio Code 或 code 命令不可用，请确认 VS Code 已安装且 code 已加入 PATH');
      }
      return;
    }
    throw UnsupportedError('当前平台不支持通过 Visual Studio Code 打开配置文件');
  }

  /// 打开配置文件所在目录。
  Future<void> openConfigDirectory() async {
    final configPath = await ensureConfigFile();
    final configDirectoryPath = File(configPath).parent.path;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await _openDirectoryNative(configDirectoryPath);
      return;
    }

    final directoryUri = Uri.directory(
      configDirectoryPath,
      windows: !kIsWeb && Platform.isWindows,
    );
    if (await canLaunchUrl(directoryUri)) {
      await launchUrl(directoryUri, mode: LaunchMode.externalApplication);
      return;
    }
    throw StateError('无法打开配置文件目录：$configDirectoryPath');
  }

  /// 使用系统默认应用打开配置文件。
  Future<void> openConfigFile() async {
    final configPath = await ensureConfigFile();
    final fileUri = Uri.file(configPath);
    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      return;
    }
    throw StateError('无法打开配置文件：$configPath');
  }

  Future<void> _openDirectoryNative(String directoryPath) async {
    try {
      if (Platform.isWindows) {
        await Process.start(
          'explorer',
          [directoryPath],
          mode: ProcessStartMode.detached,
        );
        return;
      }
      if (Platform.isMacOS) {
        await Process.start(
          'open',
          [directoryPath],
          mode: ProcessStartMode.detached,
        );
        return;
      }
      if (Platform.isLinux) {
        await Process.start(
          'xdg-open',
          [directoryPath],
          mode: ProcessStartMode.detached,
        );
        return;
      }
      throw UnsupportedError('当前平台不支持打开配置目录');
    } on ProcessException {
      throw StateError('无法打开配置文件目录，请确认系统文件管理器可用');
    }
  }

  Future<String> _resolveConfigDirectory() async {
    return AppDataDirectoryService.getRootDirectoryPath();
  }

  /// 配置文件损坏或不可读时使用默认配置，避免登录回写失败。
  Future<WxmpConfig> _loadConfigOrDefaults() async {
    try {
      return await loadConfig();
    } catch (_) {
      return WxmpConfig.defaults();
    }
  }
}
