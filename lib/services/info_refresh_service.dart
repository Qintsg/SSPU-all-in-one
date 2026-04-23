/*
 * 信息中心刷新服务 — 保持官网与微信推文刷新进度和后台任务
 * @Project : SSPU-all-in-one
 * @File : info_refresh_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../models/message_item.dart';
import 'auto_refresh_service.dart';
import 'message_state_service.dart';
import 'wechat_article_service.dart';

enum InfoRefreshKind { schoolWebsite, wechat }

class InfoRefreshSnapshot {
  final bool isRefreshing;
  final InfoRefreshKind? kind;
  final String text;
  final int completed;
  final int total;

  const InfoRefreshSnapshot({
    required this.isRefreshing,
    required this.kind,
    required this.text,
    required this.completed,
    required this.total,
  });

  const InfoRefreshSnapshot.idle()
    : isRefreshing = false,
      kind = null,
      text = '',
      completed = 0,
      total = 0;
}

/// 信息中心刷新协调器。
/// 切换页面时任务仍在单例服务内运行，页面返回后可继续读取当前进度。
class InfoRefreshService extends ChangeNotifier {
  InfoRefreshService._();

  static final InfoRefreshService instance = InfoRefreshService._();

  final MessageStateService _stateService = MessageStateService.instance;
  final AutoRefreshService _autoRefreshService = AutoRefreshService.instance;

  InfoRefreshSnapshot _snapshot = const InfoRefreshSnapshot.idle();
  Future<void>? _runningTask;

  InfoRefreshSnapshot get snapshot => _snapshot;

  bool get isRefreshing => _snapshot.isRefreshing;
  bool get isRefreshingSchoolWebsite =>
      _snapshot.kind == InfoRefreshKind.schoolWebsite && _snapshot.isRefreshing;
  bool get isRefreshingWechat =>
      _snapshot.kind == InfoRefreshKind.wechat && _snapshot.isRefreshing;

  Future<bool> startSchoolWebsiteRefresh() async {
    if (_runningTask != null) return false;
    _runningTask = _runSchoolWebsiteRefresh();
    notifyListeners();
    await _runningTask;
    return true;
  }

  Future<bool> startWechatRefresh() async {
    if (_runningTask != null) return false;
    _runningTask = _runWechatRefresh();
    notifyListeners();
    await _runningTask;
    return true;
  }

  Future<void> _runSchoolWebsiteRefresh() async {
    _update(
      const InfoRefreshSnapshot(
        isRefreshing: true,
        kind: InfoRefreshKind.schoolWebsite,
        text: '正在准备刷新官网消息...',
        completed: 0,
        total: 0,
      ),
    );

    try {
      final fetched = await _autoRefreshService
          .fetchEnabledSchoolWebsiteMessages(
            onBatchCompleted: (messages, completed, total) async {
              await _mergeAndPersist(messages);
              _update(
                InfoRefreshSnapshot(
                  isRefreshing: true,
                  kind: InfoRefreshKind.schoolWebsite,
                  text: '已完成 $completed / $total 个渠道，新增 ${messages.length} 条',
                  completed: completed,
                  total: total,
                ),
              );
            },
          );
      _update(
        InfoRefreshSnapshot(
          isRefreshing: true,
          kind: InfoRefreshKind.schoolWebsite,
          text: '官网消息刷新完成，获取 ${fetched.length} 条候选消息',
          completed: _snapshot.total,
          total: _snapshot.total,
        ),
      );
    } catch (error) {
      _update(
        InfoRefreshSnapshot(
          isRefreshing: true,
          kind: InfoRefreshKind.schoolWebsite,
          text: '官网消息刷新失败：$error',
          completed: _snapshot.completed,
          total: _snapshot.total,
        ),
      );
    } finally {
      _finishSoon();
    }
  }

  Future<void> _runWechatRefresh() async {
    _update(
      const InfoRefreshSnapshot(
        isRefreshing: true,
        kind: InfoRefreshKind.wechat,
        text: '正在刷新最新微信推文...',
        completed: 0,
        total: 0,
      ),
    );

    try {
      final persistedMessages = await _stateService.loadMessages();
      final maxCount = await _stateService.getChannelManualFetchCount(
        'wechat_public',
        defaultValue: 10,
      );
      final articles = await WechatArticleService.instance.fetchArticles(
        maxCount: maxCount,
        knownMessageIds: persistedMessages.map((msg) => msg.id).toSet(),
        validateBeforeFetch: true,
        onAccountCompleted: (messages, completed, total, accountName) async {
          await _mergeAndPersist(messages);
          _update(
            InfoRefreshSnapshot(
              isRefreshing: true,
              kind: InfoRefreshKind.wechat,
              text:
                  '已完成 $completed / $total 个公众号：$accountName，新增 ${messages.length} 条',
              completed: completed,
              total: total,
            ),
          );
        },
      );
      if (articles.isEmpty && _snapshot.total == 0) {
        _update(
          const InfoRefreshSnapshot(
            isRefreshing: true,
            kind: InfoRefreshKind.wechat,
            text: '未获取到新的微信推文',
            completed: 0,
            total: 0,
          ),
        );
      } else {
        _update(
          InfoRefreshSnapshot(
            isRefreshing: true,
            kind: InfoRefreshKind.wechat,
            text: '微信推文刷新完成，新增 ${articles.length} 条',
            completed: _snapshot.total,
            total: _snapshot.total,
          ),
        );
      }
    } catch (error) {
      _update(
        InfoRefreshSnapshot(
          isRefreshing: true,
          kind: InfoRefreshKind.wechat,
          text: '微信推文刷新失败：$error',
          completed: _snapshot.completed,
          total: _snapshot.total,
        ),
      );
    } finally {
      _finishSoon();
    }
  }

  Future<void> _mergeAndPersist(List<MessageItem> messages) async {
    if (messages.isEmpty) return;
    final existingMessages = await _stateService.loadMessages();
    final merged = _stateService.mergeMessages(existingMessages, messages);
    await _stateService.saveMessages(merged);
  }

  void _update(InfoRefreshSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  void _finishSoon() {
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      _snapshot = const InfoRefreshSnapshot.idle();
      _runningTask = null;
      notifyListeners();
    });
  }
}
