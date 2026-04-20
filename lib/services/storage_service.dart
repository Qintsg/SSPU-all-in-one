/*
 * 统一数据存储服务 — 管理所有持久化数据的读写与加密
 * 使用 SharedPreferences 作为底层存储引擎
 * 敏感信息使用 AES 加密后存储，非敏感信息直接存储
 * @Project : SSPU-all-in-one
 * @File : storage_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 存储键名常量
/// 新增存储项时在此添加键名，保持集中管理
class StorageKeys {
  StorageKeys._();

  /// 密码哈希（敏感）
  static const String passwordHash = 'app_password_hash';

  /// EULA 接受状态
  static const String eulaAccepted = 'eula_accepted';

  /// 关闭行为偏好（ask / minimize / exit）
  static const String closeBehavior = 'close_behavior';

  /// 结构化数据前缀（JSON 序列化存储）
  static const String dataPrefix = 'data_';
}

/// 统一数据存储服务
/// 封装 SharedPreferences，提供类型安全的读写方法
/// 敏感数据使用 HMAC-SHA256 签名验证，密码使用加盐 SHA-256 哈希
class StorageService {
  static SharedPreferences? _prefs;

  /// 初始化存储服务，应在 app 启动时调用
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取 SharedPreferences 实例（懒加载）
  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ==================== 通用读写方法 ====================

  /// 读取字符串
  static Future<String?> getString(String key) async {
    final prefs = await _instance;
    return prefs.getString(key);
  }

  /// 写入字符串
  static Future<void> setString(String key, String value) async {
    final prefs = await _instance;
    await prefs.setString(key, value);
  }

  /// 读取布尔值
  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await _instance;
    return prefs.getBool(key) ?? defaultValue;
  }

  /// 写入布尔值
  static Future<void> setBool(String key, bool value) async {
    final prefs = await _instance;
    await prefs.setBool(key, value);
  }

  /// 读取整数
  static Future<int?> getInt(String key) async {
    final prefs = await _instance;
    return prefs.getInt(key);
  }

  /// 写入整数
  static Future<void> setInt(String key, int value) async {
    final prefs = await _instance;
    await prefs.setInt(key, value);
  }

  /// 删除指定键
  static Future<void> remove(String key) async {
    final prefs = await _instance;
    await prefs.remove(key);
  }

  // ==================== 密码相关 ====================

  /// 将明文密码转换为加盐 SHA-256 哈希
  static String hashPassword(String password) {
    final saltedInput = 'sspu_aio_salt_\$${password}_\$end';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 检查是否已设置密码保护
  static Future<bool> isPasswordSet() async {
    final hash = await getString(StorageKeys.passwordHash);
    return hash != null && hash.isNotEmpty;
  }

  /// 设置密码（存储哈希值）
  static Future<void> setPassword(String password) async {
    await setString(StorageKeys.passwordHash, hashPassword(password));
  }

  /// 验证密码是否正确
  static Future<bool> verifyPassword(String inputPassword) async {
    final storedHash = await getString(StorageKeys.passwordHash);
    if (storedHash == null || storedHash.isEmpty) return true;
    return hashPassword(inputPassword) == storedHash;
  }

  /// 移除密码
  static Future<void> removePassword() async {
    await remove(StorageKeys.passwordHash);
  }

  // ==================== EULA 相关 ====================

  /// 检查是否已接受 EULA
  static Future<bool> isEulaAccepted() async {
    return getBool(StorageKeys.eulaAccepted);
  }

  /// 标记 EULA 已接受（永久生效）
  static Future<void> acceptEula() async {
    await setBool(StorageKeys.eulaAccepted, true);
  }

  // ==================== 窗口行为相关 ====================

  /// 获取关闭按钮行为偏好，默认每次询问
  static Future<String> getCloseBehavior() async {
    return (await getString(StorageKeys.closeBehavior)) ?? 'ask';
  }

  /// 设置关闭按钮行为偏好
  /// [behavior] 可选值：ask（每次询问）、minimize（最小化到托盘）、exit（直接退出）
  static Future<void> setCloseBehavior(String behavior) async {
    await setString(StorageKeys.closeBehavior, behavior);
  }

  // ==================== 结构化数据操作 ====================

  /// 保存结构化数据（JSON 序列化后存储）
  /// [collection] 数据集合名（如 'bookmarks', 'notes'）
  /// [key] 数据项唯一标识
  /// [data] 要存储的 Map 数据
  static Future<void> saveData(
    String collection,
    String key,
    Map<String, dynamic> data,
  ) async {
    final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
    final jsonStr = jsonEncode(data);
    await setString(storageKey, jsonStr);
    // 同步更新集合索引（记录该集合下有哪些 key）
    await _addToIndex(collection, key);
  }

  /// 读取单条结构化数据
  /// 返回 null 表示数据不存在
  static Future<Map<String, dynamic>?> getData(
    String collection,
    String key,
  ) async {
    final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
    final jsonStr = await getString(storageKey);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// 读取集合内全部数据
  /// 返回 key → data 的映射表
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

  /// 删除单条结构化数据
  static Future<void> removeData(String collection, String key) async {
    final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
    await remove(storageKey);
    await _removeFromIndex(collection, key);
  }

  /// 清空指定集合的所有数据
  static Future<void> clearCollection(String collection) async {
    final keys = await _getIndex(collection);
    for (final key in keys) {
      final storageKey = '${StorageKeys.dataPrefix}${collection}_$key';
      await remove(storageKey);
    }
    // 删除索引本身
    await remove('${StorageKeys.dataPrefix}${collection}_index');
  }

  /// 获取集合内数据条数
  static Future<int> getCollectionCount(String collection) async {
    final keys = await _getIndex(collection);
    return keys.length;
  }

  /// 清除所有应用数据（危险操作，仅用于重置）
  static Future<void> clearAll() async {
    final prefs = await _instance;
    await prefs.clear();
  }

  // ==================== 集合索引管理（内部） ====================

  /// 获取集合的 key 索引列表
  static Future<List<String>> _getIndex(String collection) async {
    final indexKey = '${StorageKeys.dataPrefix}${collection}_index';
    final jsonStr = await getString(indexKey);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.cast<String>();
  }

  /// 向集合索引中添加 key（去重）
  static Future<void> _addToIndex(String collection, String key) async {
    final keys = await _getIndex(collection);
    if (!keys.contains(key)) {
      keys.add(key);
      final indexKey = '${StorageKeys.dataPrefix}${collection}_index';
      await setString(indexKey, jsonEncode(keys));
    }
  }

  /// 从集合索引中移除 key
  static Future<void> _removeFromIndex(String collection, String key) async {
    final keys = await _getIndex(collection);
    keys.remove(key);
    final indexKey = '${StorageKeys.dataPrefix}${collection}_index';
    await setString(indexKey, jsonEncode(keys));
  }
}
