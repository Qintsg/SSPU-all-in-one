/*
 * 统一数据存储服务 — 管理所有持久化数据的读写与迁移
 * 使用 ~/.sspu-all-in-one/app_state.json 作为统一用户配置与缓存文件
 * @Project : SSPU-all-in-one
 * @File : storage_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data_directory_service.dart';

/// 存储键名常量。
/// 新增存储项时在此添加键名，保持集中管理。
class StorageKeys {
  StorageKeys._();

  /// 密码哈希。
  static const String passwordHash = 'app_password_hash';

  /// EULA 接受状态。
  static const String eulaAccepted = 'eula_accepted';

  /// 关闭行为偏好（ask / minimize / exit）。
  static const String closeBehavior = 'close_behavior';

  /// 结构化数据前缀（JSON 序列化存储）。
  static const String dataPrefix = 'data_';
}

/// 统一数据存储服务。
/// 通过一个 JSON 文件保存设置、认证缓存、文章缓存与集合索引。
class StorageService {
  /// 统一状态文件名。
  static const String _stateFileName = 'app_state.json';

  /// 旧版 SharedPreferences 实例，仅用于一次性迁移既有用户数据。
  static SharedPreferences? _legacyPrefs;

  /// 内存态缓存，避免每次读取都访问磁盘。
  static Map<String, Object?> _values = {};

  /// 当前状态文件。
  static File? _stateFile;

  /// 是否已经完成初始化。
  static bool _initialized = false;

  /// 测试专用文件覆盖。
  static String? _debugStateFilePath;

  /// 初始化存储服务，应在 app 启动时调用。
  static Future<void> init() async {
    if (_initialized) return;
    final stateFilePath =
        _debugStateFilePath ??
        await AppDataDirectoryService.ensureFilePath(_stateFileName);
    _stateFile = File(stateFilePath);
    if (!await _stateFile!.parent.exists()) {
      await _stateFile!.parent.create(recursive: true);
    }

    _initialized = true;
    _values = await _readStateFile(_stateFile!);
    await _migrateLegacyPreferencesIfNeeded();
  }

  /// 测试专用：覆盖状态文件路径，并重置内存缓存。
  @visibleForTesting
  static void debugSetStateFilePathForTesting(String? stateFilePath) {
    _debugStateFilePath = stateFilePath;
    _stateFile = null;
    _legacyPrefs = null;
    _values = {};
    _initialized = false;
  }

  /// 获取当前状态文件路径，供设置页展示。
  static Future<String> getStateFilePath() async {
    await init();
    return _stateFile!.path;
  }

  /// 确保服务已经初始化。
  static Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// 从 JSON 状态文件读取全部键值。
  static Future<Map<String, Object?>> _readStateFile(File stateFile) async {
    if (!await stateFile.exists()) return {};
    try {
      final content = await stateFile.readAsString();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return Map<String, Object?>.from(decoded);
    } catch (_) {
      // 文件损坏时保守回退为空配置，避免阻塞应用启动。
      return {};
    }
  }

  /// 将内存态写回统一状态文件。
  static Future<void> _persist() async {
    const encoder = JsonEncoder.withIndent('  ');
    await _stateFile!.writeAsString('${encoder.convert(_values)}\n');
  }

  /// 从旧 SharedPreferences 迁移数据到统一 JSON 文件。
  static Future<void> _migrateLegacyPreferencesIfNeeded() async {
    try {
      _legacyPrefs ??= await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }

    var migrated = false;
    for (final key in _legacyPrefs!.getKeys()) {
      if (_values.containsKey(key)) continue;
      final legacyValue = _legacyPrefs!.get(key);
      if (legacyValue is String ||
          legacyValue is bool ||
          legacyValue is int ||
          legacyValue is double ||
          legacyValue is List<String>) {
        _values[key] = legacyValue;
        migrated = true;
      }
    }
    if (migrated) await _persist();
  }

  // ==================== 通用读写方法 ====================

  /// 读取字符串。
  static Future<String?> getString(String key) async {
    await _ensureInitialized();
    final value = _values[key];
    return value is String ? value : null;
  }

  /// 写入字符串。
  static Future<void> setString(String key, String value) async {
    await _ensureInitialized();
    _values[key] = value;
    await _persist();
  }

  /// 读取布尔值。
  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    await _ensureInitialized();
    final value = _values[key];
    return value is bool ? value : defaultValue;
  }

  /// 写入布尔值。
  static Future<void> setBool(String key, bool value) async {
    await _ensureInitialized();
    _values[key] = value;
    await _persist();
  }

  /// 读取整数。
  static Future<int?> getInt(String key) async {
    await _ensureInitialized();
    final value = _values[key];
    if (value is int) return value;
    if (value is double) return value.round();
    return null;
  }

  /// 写入整数。
  static Future<void> setInt(String key, int value) async {
    await _ensureInitialized();
    _values[key] = value;
    await _persist();
  }

  /// 删除指定键。
  static Future<void> remove(String key) async {
    await _ensureInitialized();
    _values.remove(key);
    await _persist();
  }

  // ==================== 密码相关 ====================

  /// 将明文密码转换为加盐 SHA-256 哈希。
  static String hashPassword(String password) {
    final saltedInput = 'sspu_aio_salt_\$${password}_\$end';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 检查是否已设置密码保护。
  static Future<bool> isPasswordSet() async {
    final hash = await getString(StorageKeys.passwordHash);
    return hash != null && hash.isNotEmpty;
  }

  /// 设置密码（存储哈希值）。
  static Future<void> setPassword(String password) async {
    await setString(StorageKeys.passwordHash, hashPassword(password));
  }

  /// 验证密码是否正确。
  static Future<bool> verifyPassword(String inputPassword) async {
    final storedHash = await getString(StorageKeys.passwordHash);
    if (storedHash == null || storedHash.isEmpty) return true;
    return hashPassword(inputPassword) == storedHash;
  }

  /// 移除密码。
  static Future<void> removePassword() async {
    await remove(StorageKeys.passwordHash);
  }

  // ==================== EULA 相关 ====================

  /// 检查是否已接受 EULA。
  static Future<bool> isEulaAccepted() async {
    return getBool(StorageKeys.eulaAccepted);
  }

  /// 标记 EULA 已接受（永久生效）。
  static Future<void> acceptEula() async {
    await setBool(StorageKeys.eulaAccepted, true);
  }

  // ==================== 窗口行为相关 ====================

  /// 获取关闭按钮行为偏好，默认每次询问。
  static Future<String> getCloseBehavior() async {
    return (await getString(StorageKeys.closeBehavior)) ?? 'ask';
  }

  /// 设置关闭按钮行为偏好。
  /// [behavior] 可选值：ask（每次询问）、minimize（最小化到托盘）、exit（直接退出）。
  static Future<void> setCloseBehavior(String behavior) async {
    await setString(StorageKeys.closeBehavior, behavior);
  }

  // ==================== 结构化数据操作 ====================

  /// 保存结构化数据（JSON 序列化后存储）。
  static Future<void> saveData(
    String collection,
    String key,
    Map<String, dynamic> data,
  ) async {
    final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
    await setString(storageKey, jsonEncode(data));
    await _addToIndex(collection, key);
  }

  /// 读取单条结构化数据；返回 null 表示数据不存在。
  static Future<Map<String, dynamic>?> getData(
    String collection,
    String key,
  ) async {
    final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
    final jsonStr = await getString(storageKey);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// 读取集合内全部数据，返回 key 到 data 的映射表。
  static Future<Map<String, Map<String, dynamic>>> getAllData(
    String collection,
  ) async {
    final keys = await _getIndex(collection);
    final result = <String, Map<String, dynamic>>{};
    for (final key in keys) {
      final data = await getData(collection, key);
      if (data != null) result[key] = data;
    }
    return result;
  }

  /// 删除单条结构化数据。
  static Future<void> removeData(String collection, String key) async {
    final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
    await remove(storageKey);
    await _removeFromIndex(collection, key);
  }

  /// 清空指定集合的所有数据。
  static Future<void> clearCollection(String collection) async {
    final keys = await _getIndex(collection);
    for (final key in keys) {
      final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
      await remove(storageKey);
    }
    await remove('${StorageKeys.dataPrefix}${collection}_index');
  }

  /// 获取集合内数据条数。
  static Future<int> getCollectionCount(String collection) async {
    final keys = await _getIndex(collection);
    return keys.length;
  }

  /// 清除所有应用数据。
  static Future<void> clearAll() async {
    await _ensureInitialized();
    _values.clear();
    final dataDirectory = _stateFile!.parent;
    final isUnifiedAppDirectory =
        dataDirectory.path.endsWith(
          '${Platform.pathSeparator}${AppDataDirectoryService.directoryName}',
        ) ||
        _debugStateFilePath != null;
    if (isUnifiedAppDirectory && await dataDirectory.exists()) {
      await dataDirectory.delete(recursive: true);
    } else {
      await _persist();
    }
    _stateFile = null;
    _legacyPrefs = null;
    _initialized = false;
  }

  // ==================== 集合索引管理（内部） ====================

  /// 获取集合的 key 索引列表。
  static Future<List<String>> _getIndex(String collection) async {
    final indexKey = '${StorageKeys.dataPrefix}${collection}_index';
    final jsonStr = await getString(indexKey);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.cast<String>();
  }

  /// 向集合索引中添加 key（去重）。
  static Future<void> _addToIndex(String collection, String key) async {
    final keys = await _getIndex(collection);
    if (!keys.contains(key)) {
      keys.add(key);
      final indexKey = '${StorageKeys.dataPrefix}${collection}_index';
      await setString(indexKey, jsonEncode(keys));
    }
  }

  /// 从集合索引中移除 key。
  static Future<void> _removeFromIndex(String collection, String key) async {
    final keys = await _getIndex(collection);
    keys.remove(key);
    final indexKey = '${StorageKeys.dataPrefix}${collection}_index';
    await setString(indexKey, jsonEncode(keys));
  }
}
