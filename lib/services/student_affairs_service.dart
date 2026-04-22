/*
 * 学生处消息解析服务 — 抓取学生处学工要闻和通知公告列表
 * 通过栏目列表页解析，支持翻页与完整发布日期
 * 列表结构: li.hovers > a[title](标题) + div.item-time(YYYY-MM-DD)
 * @Project : SSPU-all-in-one
 * @File : student_affairs_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 学生处消息解析服务（单例）
/// 从 xsc.sspu.edu.cn 抓取学工要闻和通知公告
class StudentAffairsService {
  StudentAffairsService._();

  static final StudentAffairsService instance = StudentAffairsService._();

  /// 学生处基础 URL
  static const String _baseUrl = 'https://xsc.sspu.edu.cn';

  /// 学工要闻栏目路径
  static const String _newsPath = '/489';

  /// 通知公告栏目路径
  static const String _noticePath = '/490';

  final HttpService _http = HttpService.instance;

  /// 获取学工要闻
  Future<List<MessageItem>> fetchNews({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _newsPath,
      category: MessageCategory.studentNews,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取通知公告
  Future<List<MessageItem>> fetchNotices({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _noticePath,
      category: MessageCategory.studentNotice,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 根据页码生成栏目列表页 URL
  String _buildPageUrl(String columnPath, int page) {
    if (page <= 1) return '$_baseUrl$columnPath/list.htm';
    return '$_baseUrl$columnPath/list$page.htm';
  }

  /// 从指定栏目抓取消息，支持自动翻页
  Future<List<MessageItem>> _fetchFromColumn({
    required String columnPath,
    required MessageCategory category,
    required int maxCount,
    Set<String>? knownMessageIds,
    int maxPages = 20,
  }) async {
    final messages = <MessageItem>[];
    var currentPage = 1;

    while (messages.length < maxCount && currentPage <= maxPages) {
      final pageMessages = await _fetchSinglePage(
        url: _buildPageUrl(columnPath, currentPage),
        category: category,
        knownMessageIds: knownMessageIds,
      );

      if (pageMessages.isEmpty) break;

      for (final message in pageMessages) {
        if (messages.length >= maxCount) break;
        messages.add(message);
      }

      currentPage++;
    }

    return messages;
  }

  /// 抓取栏目单页内所有消息项
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      final listItems = document.querySelectorAll('li.hovers');
      final messages = <MessageItem>[];

      for (final item in listItems) {
        final anchor = item.querySelector('a[title]');
        if (anchor == null) continue;

        final rawDate = item.querySelector('.item-time')?.text.trim() ?? '';
        if (!RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(rawDate)) continue;

        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        final date = normalizeDate(rawDate);
        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.studentAffairs,
            category: category,
            timestamp: MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (_) {
      return [];
    }
  }

  /// 基于 URL 生成稳定的消息唯一 ID
  String _generateId(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}
