/*
 * 学生处消息解析服务 — 抓取学生处首页学工要闻和通知公告
 * 仅抓取首页内容，不翻页；日期仅有 MM-DD 格式，需补全年份
 * 学工要闻: ul#xgdt li > span.news_title a[title] + span.time(MM-DD)
 * 通知公告: ul.tzgg li > span.news_title a[title] + span.time(MM-DD)
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
/// 从 xsc.sspu.edu.cn 首页抓取学工要闻和通知公告
class StudentAffairsService {
  StudentAffairsService._();

  static final StudentAffairsService instance = StudentAffairsService._();

  /// 学生处基础 URL
  static const String _baseUrl = 'https://xsc.sspu.edu.cn';

  final HttpService _http = HttpService.instance;

  /// 获取学工要闻（首页 ul#xgdt 区块）
  Future<List<MessageItem>> fetchNews({Set<String>? knownMessageIds}) async {
    return _fetchFromHomepage(
      selector: 'ul#xgdt li',
      category: MessageCategory.studentNews,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取通知公告（首页 ul.tzgg 区块）
  Future<List<MessageItem>> fetchNotices({Set<String>? knownMessageIds}) async {
    return _fetchFromHomepage(
      selector: 'ul.tzgg li',
      category: MessageCategory.studentNotice,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 从首页抓取指定选择器区域的消息
  Future<List<MessageItem>> _fetchFromHomepage({
    required String selector,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(_baseUrl);
      final document = html_parser.parse(htmlText);

      final listItems = document.querySelectorAll(selector);
      final messages = <MessageItem>[];

      for (final item in listItems) {
        // 提取链接和标题（在 span.news_title 内的 a 标签）
        final anchor = item.querySelector('a[title]');
        if (anchor == null) continue;

        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        // 提取日期（span.time 内为 MM-DD 格式，通过统一工具补全年份）
        final dateSpan = item.querySelector('span.time');
        final rawDate = dateSpan?.text.trim() ?? '';
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
    } catch (error) {
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
