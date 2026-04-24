/*
 * 微信推文设置控制器 — 管理公众号平台认证、刷新设置与 SSPU 微信矩阵状态
 * @Project : SSPU-all-in-one
 * @File : settings_wechat_controller.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../models/sspu_wechat_accounts.dart';
import '../services/auto_refresh_service.dart';
import '../services/message_state_service.dart';
import '../services/storage_service.dart';
import '../services/wechat_article_service.dart';
import '../services/wxmp_article_service.dart';
import '../services/wxmp_auth_service.dart';
import '../services/wxmp_config_service.dart';
import '../utils/wechat_followed_account_matcher.dart';

/// 微信推文设置操作反馈。
class SettingsWechatFeedback {
  /// 提示标题。
  final String title;

  /// 提示正文。
  final String? content;

  /// 提示等级。
  final InfoBarSeverity severity;

  const SettingsWechatFeedback({
    required this.title,
    this.content,
    required this.severity,
  });
}

/// 设置页微信推文分区控制器。
class SettingsWechatController extends ChangeNotifier {
  final MessageStateService _messageState = MessageStateService.instance;
  final WechatArticleService _wechatService = WechatArticleService.instance;
  final WxmpAuthService _wxmpAuth = WxmpAuthService.instance;
  final WxmpArticleService _wxmpService = WxmpArticleService.instance;
  final WxmpConfigService _wxmpConfigService = WxmpConfigService.instance;
  final AutoRefreshService _autoRefresh = AutoRefreshService.instance;

  bool _isLoading = true;
  bool _initialized = false;
  bool _wxmpAuthenticated = false;
  WxmpAuthStatus? _wxmpAuthStatus;
  String _wxmpConfigPath = '';
  String _stateFilePath = '';
  String _wxmpConfigMessage = '';
  bool _wechatAutoRefreshEnabled = false;
  int _wechatRefreshInterval = 120;
  int _wechatManualFetchCount = 20;
  int _wechatAutoFetchCount = 20;
  List<Map<String, String>> _wxmpFollowedMps = [];
  Map<String, bool> _wxmpMpNotificationEnabled = {};
  bool _wxmpValidating = false;
  String _wxmpFollowingAccountId = '';
  bool _wxmpBatchFollowing = false;
  String _wxmpBatchProgress = '';

  bool get isLoading => _isLoading;
  bool get wxmpAuthenticated => _wxmpAuthenticated;
  WxmpAuthStatus? get wxmpAuthStatus => _wxmpAuthStatus;
  String get wxmpConfigPath => _wxmpConfigPath;
  String get stateFilePath => _stateFilePath;
  String get wxmpConfigMessage => _wxmpConfigMessage;
  bool get wechatAutoRefreshEnabled => _wechatAutoRefreshEnabled;
  int get wechatRefreshInterval => _wechatRefreshInterval;
  int get wechatManualFetchCount => _wechatManualFetchCount;
  int get wechatAutoFetchCount => _wechatAutoFetchCount;
  List<Map<String, String>> get wxmpFollowedMps =>
      List.unmodifiable(_wxmpFollowedMps);
  Map<String, bool> get wxmpMpNotificationEnabled =>
      Map.unmodifiable(_wxmpMpNotificationEnabled);
  bool get wxmpValidating => _wxmpValidating;
  String get wxmpFollowingAccountId => _wxmpFollowingAccountId;
  bool get wxmpBatchFollowing => _wxmpBatchFollowing;
  String get wxmpBatchProgress => _wxmpBatchProgress;

  /// 初始化微信推文设置状态。
  Future<void> load() async {
    if (_initialized) return;
    _initialized = true;

    await _messageState.init();
    await _wechatService.clearLegacyWereadState();

    final stateFilePath = await StorageService.getStateFilePath();
    var wxmpConfigPath = '';
    var wxmpConfigMessage = '配置文件已就绪';
    try {
      wxmpConfigPath = await _wxmpConfigService.ensureConfigFile();
    } catch (error) {
      wxmpConfigMessage = '配置文件初始化失败：$error';
    }

    final authStatus = await _wxmpAuth.getAuthStatus();
    _wxmpAuthenticated = authStatus.isUsable;
    _wxmpAuthStatus = authStatus;
    _wxmpConfigPath = wxmpConfigPath;
    _stateFilePath = stateFilePath;
    _wxmpConfigMessage = wxmpConfigMessage;
    _wechatAutoRefreshEnabled = await _messageState.isChannelAutoRefreshEnabled(
      'wechat_public',
    );
    _wechatRefreshInterval = await _messageState.getChannelDisplayInterval(
      'wechat_public',
      defaultValue: 120,
    );
    _wechatManualFetchCount = await _messageState.getChannelManualFetchCount(
      'wechat_public',
    );
    _wechatAutoFetchCount = await _messageState.getChannelAutoFetchCount(
      'wechat_public',
    );

    if (_wxmpAuthenticated) {
      await _loadWxmpFollowedMps();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 修改手动刷新条数。
  Future<void> setManualFetchCount(int count) async {
    final normalized = count.clamp(1, 200);
    await _messageState.setChannelManualFetchCount('wechat_public', normalized);
    _wechatManualFetchCount = normalized;
    notifyListeners();
  }

  /// 切换自动刷新状态。
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    if (enabled) {
      final interval = _wechatRefreshInterval <= 0
          ? 120
          : _wechatRefreshInterval;
      await _messageState.setChannelInterval('wechat_public', interval);
      _wechatAutoRefreshEnabled = true;
      _wechatRefreshInterval = interval;
    } else {
      await _messageState.setChannelAutoRefreshEnabled('wechat_public', false);
      _wechatAutoRefreshEnabled = false;
    }
    notifyListeners();
    await _autoRefresh.reloadChannel('wechat_public');
  }

  /// 修改自动刷新频率。
  Future<void> setRefreshInterval(int minutes) async {
    await _messageState.setChannelInterval('wechat_public', minutes);
    _wechatRefreshInterval = minutes;
    _wechatAutoRefreshEnabled = minutes > 0;
    notifyListeners();
    await _autoRefresh.reloadChannel('wechat_public');
  }

  /// 修改自动刷新条数。
  Future<void> setAutoFetchCount(int count) async {
    final normalized = count.clamp(1, 200);
    await _messageState.setChannelAutoFetchCount('wechat_public', normalized);
    _wechatAutoFetchCount = normalized;
    notifyListeners();
    await _autoRefresh.reloadChannel('wechat_public');
  }

  /// 使用系统默认应用打开认证配置文件。
  Future<SettingsWechatFeedback> openConfigFile() async {
    try {
      await _wxmpConfigService.openConfigFile();
      _wxmpConfigPath = await _wxmpConfigService.getConfigPath();
      _wxmpConfigMessage = '已打开配置文件';
      notifyListeners();
      return const SettingsWechatFeedback(
        title: '已打开配置文件',
        severity: InfoBarSeverity.success,
      );
    } catch (error) {
      _wxmpConfigMessage = '打开配置文件失败：$error';
      notifyListeners();
      return SettingsWechatFeedback(
        title: '打开配置文件失败',
        content: '$error',
        severity: InfoBarSeverity.error,
      );
    }
  }

  /// 读取认证配置文件原文，供设置页内置编辑器展示。
  Future<String> loadConfigFileText() async {
    _wxmpConfigPath = await _wxmpConfigService.getConfigPath();
    return _wxmpConfigService.loadConfigText();
  }

  /// 保存内置编辑器内容，并刷新设置页认证状态。
  Future<SettingsWechatFeedback> saveConfigFileText(String content) async {
    try {
      await _wxmpConfigService.saveConfigText(content);
      final authStatus = await _wxmpAuth.getAuthStatus();
      _wxmpAuthenticated = authStatus.isUsable;
      _wxmpAuthStatus = authStatus;
      _wxmpConfigPath = await _wxmpConfigService.getConfigPath();
      _wxmpConfigMessage = '配置文件已保存并重新加载';
      notifyListeners();
      return const SettingsWechatFeedback(
        title: '配置文件已保存',
        severity: InfoBarSeverity.success,
      );
    } catch (error) {
      _wxmpConfigMessage = '保存配置文件失败：$error';
      notifyListeners();
      return SettingsWechatFeedback(
        title: '保存配置文件失败',
        content: '$error',
        severity: InfoBarSeverity.error,
      );
    }
  }

  /// 打开认证配置文件目录。
  Future<SettingsWechatFeedback> openConfigDirectory() async {
    try {
      await _wxmpConfigService.openConfigDirectory();
      _wxmpConfigPath = await _wxmpConfigService.getConfigPath();
      _wxmpConfigMessage = '已打开配置文件目录';
      notifyListeners();
      return const SettingsWechatFeedback(
        title: '已打开配置文件目录',
        severity: InfoBarSeverity.success,
      );
    } catch (error) {
      _wxmpConfigMessage = '打开配置文件目录失败：$error';
      notifyListeners();
      return SettingsWechatFeedback(
        title: '打开配置文件目录失败',
        content: '$error',
        severity: InfoBarSeverity.error,
      );
    }
  }

  /// 重新加载认证配置文件。
  Future<SettingsWechatFeedback> reloadConfigFile() async {
    try {
      final config = await _wxmpConfigService.loadConfig();
      final authStatus = await _wxmpAuth.getAuthStatus();
      _wxmpAuthenticated = authStatus.isUsable;
      _wxmpAuthStatus = authStatus;
      _wxmpConfigMessage =
          '已重新加载：单次请求 ${config.perRequestArticleCount} 条，间隔 ${config.requestDelayMs}ms';
      notifyListeners();
      return SettingsWechatFeedback(
        title: '配置已重新加载',
        content: _wxmpConfigMessage,
        severity: InfoBarSeverity.success,
      );
    } catch (error) {
      _wxmpConfigMessage = '重新加载配置失败：$error';
      notifyListeners();
      return SettingsWechatFeedback(
        title: '重新加载配置失败',
        content: '$error',
        severity: InfoBarSeverity.error,
      );
    }
  }

  /// 校验公众号平台认证有效性。
  Future<SettingsWechatFeedback> validateAuth() async {
    if (_wxmpValidating) {
      return const SettingsWechatFeedback(
        title: '正在校验中',
        severity: InfoBarSeverity.info,
      );
    }

    _wxmpValidating = true;
    notifyListeners();

    final validation = await _wechatService.validateSource();
    final authStatus = await _wxmpAuth.getAuthStatus();
    _wxmpValidating = false;
    _wxmpAuthenticated = validation.isValid && authStatus.isUsable;
    _wxmpAuthStatus = authStatus;
    _wxmpConfigMessage = validation.message;
    notifyListeners();

    return SettingsWechatFeedback(
      title: validation.isValid ? '认证有效' : '认证不可用',
      content: validation.message,
      severity: validation.isValid
          ? InfoBarSeverity.success
          : InfoBarSeverity.warning,
    );
  }

  /// 一键切换微信分区全部相关开关。
  Future<SettingsWechatFeedback> setWechatPageEnabled(bool enabled) async {
    await setAutoRefreshEnabled(enabled);
    for (final mp in _wxmpFollowedMps) {
      final fakeid = mp['fakeid'] ?? '';
      if (fakeid.isEmpty) continue;
      await _messageState.setMpNotificationEnabled(fakeid, enabled);
      _wxmpMpNotificationEnabled[fakeid] = enabled;
    }
    notifyListeners();
    return SettingsWechatFeedback(
      title: enabled ? '已启用微信推文页全部开关' : '已关闭微信推文页全部开关',
      severity: enabled ? InfoBarSeverity.success : InfoBarSeverity.info,
    );
  }

  /// 扫码登录成功后的状态同步。
  Future<SettingsWechatFeedback> handleLoginSuccess() async {
    final authStatus = await _wxmpAuth.getAuthStatus();
    _wxmpAuthenticated = authStatus.isUsable;
    _wxmpAuthStatus = authStatus;
    _wxmpConfigPath = await _wxmpConfigService.getConfigPath();
    _wxmpConfigMessage = '扫码登录已自动更新配置文件';
    if (authStatus.isUsable) {
      await _loadWxmpFollowedMps();
    }
    notifyListeners();
    return const SettingsWechatFeedback(
      title: '公众号平台登录成功',
      severity: InfoBarSeverity.success,
    );
  }

  /// 清除公众号平台认证。
  Future<SettingsWechatFeedback> clearAuth() async {
    await _wxmpAuth.clearAuth();
    _wxmpAuthenticated = false;
    _wxmpAuthStatus = const WxmpAuthStatus(
      state: WxmpAuthState.missingCookie,
      lastUpdate: null,
    );
    _wxmpFollowedMps = [];
    _wxmpMpNotificationEnabled = {};
    notifyListeners();
    return const SettingsWechatFeedback(
      title: '公众号平台认证已清除',
      severity: InfoBarSeverity.info,
    );
  }

  /// 修改单个公众号的通知开关。
  Future<void> setMpNotificationEnabled(String fakeid, bool enabled) async {
    await _messageState.setMpNotificationEnabled(fakeid, enabled);
    _wxmpMpNotificationEnabled[fakeid] = enabled;
    notifyListeners();
  }

  /// 在已关注列表中查找推荐账号。
  Map<String, String>? findFollowedSspuAccount(SspuWechatAccount account) {
    return findFollowedWechatAccount(account, _wxmpFollowedMps);
  }

  /// 关注单个 SSPU 微信矩阵账号。
  Future<SettingsWechatFeedback> followSspuAccount(
    SspuWechatAccount account,
  ) async {
    if (_wxmpFollowingAccountId.isNotEmpty) {
      return const SettingsWechatFeedback(
        title: '正在处理上一次关注请求',
        severity: InfoBarSeverity.info,
      );
    }

    final validation = await _wechatService.validateSource();
    if (!validation.isValid) {
      return SettingsWechatFeedback(
        title: '公众号平台认证不可用',
        content: validation.message,
        severity: InfoBarSeverity.warning,
      );
    }

    _wxmpFollowingAccountId = account.wxAccount;
    notifyListeners();
    try {
      final results = await _wxmpService.searchMp(account.name, count: 3);
      final matched = _selectBestSspuAccountMatch(account, results);
      if (matched == null) {
        throw StateError('未找到匹配的公众号');
      }

      final fakeid = matched['fakeid'] ?? '';
      if (fakeid.isEmpty) {
        throw StateError('公众号标识为空');
      }
      await _wxmpService.followMp(
        fakeid,
        matched['nickname'] ?? account.name,
        alias: matched['alias'],
        avatar: matched['round_head_img'],
        recommendedName: account.name,
        recommendedWxAccount: account.wxAccount,
      );
      await _loadWxmpFollowedMps();
      return SettingsWechatFeedback(
        title: '已关注「${account.name}」',
        severity: InfoBarSeverity.success,
      );
    } on WxmpSessionExpiredException {
      _wxmpAuthenticated = false;
      return const SettingsWechatFeedback(
        title: '会话已过期，请重新扫码登录',
        severity: InfoBarSeverity.error,
      );
    } on WxmpFrequencyLimitException {
      return const SettingsWechatFeedback(
        title: '请求频率过快，请稍后再试',
        severity: InfoBarSeverity.warning,
      );
    } catch (error) {
      return SettingsWechatFeedback(
        title: '关注失败',
        content: '$error',
        severity: InfoBarSeverity.warning,
      );
    } finally {
      _wxmpFollowingAccountId = '';
      notifyListeners();
    }
  }

  /// 一键关注 SSPU 推荐公众号。
  Future<SettingsWechatFeedback> batchFollowSspuWxmp() async {
    if (_wxmpBatchFollowing) {
      return const SettingsWechatFeedback(
        title: '批量关注正在进行中',
        severity: InfoBarSeverity.info,
      );
    }

    final validation = await _wechatService.validateSource();
    if (!validation.isValid) {
      return SettingsWechatFeedback(
        title: '公众号平台认证不可用',
        content: validation.message,
        severity: InfoBarSeverity.warning,
      );
    }

    _wxmpBatchFollowing = true;
    _wxmpBatchProgress = '准备中...';
    notifyListeners();

    int added = 0;
    int skipped = 0;
    int failed = 0;
    bool rateLimited = false;

    for (int i = 0; i < sspuWechatAccounts.length; i++) {
      final account = sspuWechatAccounts[i];
      _wxmpBatchProgress =
          '正在处理 ${i + 1}/${sspuWechatAccounts.length}：${account.name}';
      notifyListeners();
      try {
        final results = await _wxmpService.searchMp(account.name, count: 3);
        if (results.isEmpty) {
          failed++;
          continue;
        }

        final mp = _selectBestSspuAccountMatch(account, results);
        if (mp == null) {
          failed++;
          continue;
        }

        final fakeid = mp['fakeid'] ?? '';
        if (fakeid.isEmpty) {
          failed++;
          continue;
        }

        if (await _wxmpService.isFollowed(fakeid)) {
          skipped++;
          continue;
        }

        await _wxmpService.followMp(
          fakeid,
          mp['nickname'] ?? account.name,
          alias: mp['alias'],
          avatar: mp['round_head_img'],
          recommendedName: account.name,
          recommendedWxAccount: account.wxAccount,
        );
        added++;
        if (i < sspuWechatAccounts.length - 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      } on WxmpSessionExpiredException {
        _wxmpAuthenticated = false;
        _wxmpBatchFollowing = false;
        _wxmpBatchProgress = '';
        notifyListeners();
        return const SettingsWechatFeedback(
          title: '会话已过期，请重新扫码登录后重试',
          severity: InfoBarSeverity.error,
        );
      } on WxmpFrequencyLimitException {
        rateLimited = true;
        break;
      } catch (_) {
        failed++;
      }
    }

    await _loadWxmpFollowedMps();
    _wxmpBatchFollowing = false;
    _wxmpBatchProgress = '';
    notifyListeners();

    final summary = StringBuffer();
    if (added > 0) summary.write('新关注 $added 个');
    if (skipped > 0) {
      if (summary.isNotEmpty) summary.write('，');
      summary.write('已关注跳过 $skipped 个');
    }
    if (failed > 0) {
      if (summary.isNotEmpty) summary.write('，');
      summary.write('搜索失败 $failed 个');
    }
    if (rateLimited) {
      if (summary.isNotEmpty) summary.write('，');
      summary.write('因频率限制提前结束');
    }

    return SettingsWechatFeedback(
      title: summary.isEmpty ? '已完成' : summary.toString(),
      severity: rateLimited
          ? InfoBarSeverity.warning
          : (failed > 0 ? InfoBarSeverity.warning : InfoBarSeverity.success),
    );
  }

  Future<void> _loadWxmpFollowedMps() async {
    final mps = await _wxmpService.getFollowedMpList();
    final enabledMap = <String, bool>{};
    for (final mp in mps) {
      final fakeid = mp['fakeid'] ?? '';
      if (fakeid.isNotEmpty) {
        enabledMap[fakeid] = await _messageState.isMpNotificationEnabled(
          fakeid,
        );
      }
    }
    _wxmpFollowedMps = mps;
    _wxmpMpNotificationEnabled = enabledMap;
  }

  Map<String, String>? _selectBestSspuAccountMatch(
    SspuWechatAccount account,
    List<Map<String, String>> results,
  ) {
    for (final result in results) {
      if ((result['alias'] ?? '') == account.wxAccount) return result;
    }
    for (final result in results) {
      if ((result['nickname'] ?? '') == account.name) return result;
    }
    return results.isEmpty ? null : results.first;
  }
}
