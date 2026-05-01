/*
 * 微信推文设置关注操作 — SSPU 微信矩阵单个与批量关注流程
 * @Project : SSPU-all-in-one
 * @File : settings_wechat_follow_actions.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'settings_wechat_controller.dart';

extension SettingsWechatFollowActions on SettingsWechatController {
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
    _notifyStateChanged();
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
      _notifyStateChanged();
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
    _notifyStateChanged();

    int added = 0;
    int skipped = 0;
    int failed = 0;
    bool rateLimited = false;

    for (int i = 0; i < sspuWechatAccounts.length; i++) {
      final account = sspuWechatAccounts[i];
      _wxmpBatchProgress =
          '正在处理 ${i + 1}/${sspuWechatAccounts.length}：${account.name}';
      _notifyStateChanged();
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
        _notifyStateChanged();
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
    _notifyStateChanged();

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
}
