/*
 * 校区建设办消息解析服务 — 抓取校区建设办首页的要闻与通知
 * 仅抓取首页内容，不翻页；日期仅有 MM-DD 格式，需补全年份
 * 列表结构: ul.lis li > a[title](标题) + span(MM-DD)
 * @Project : SSPU-all-in-one
 * @File : construction_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 校区建设办消息解析服务（单例）
/// 从 xqjsb.sspu.edu.cn 首页抓取建设要闻和建设通知
class ConstructionNewsService {
  ConstructionNewsService._();

  static final ConstructionNewsService instance = ConstructionNewsService._();

  /// 校区建设办基础 URL
  static const String _baseUrl = 'https://xqjsb.sspu.edu.cn';

  final HttpService _http = HttpService.instance;

  /// 获取建设要闻（首页窗口4/c405区块）
  Future<List<MessageItem>> fetchNews({Set<String>? knownMessageIds}) async {
    return _fetchFromHomepage(
      category: MessageCategory.constructionNews,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取建设通知（首页窗口5/c406区块）
  Future<List<MessageItem>> fetchNotices({Set<String>? knownMessageIds}) async {
    return _fetchFromHomepage(
      category: MessageCategory.constructionNotice,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 从首页抓取指定分类的消息
  /// 因两个区块 HTML 结构相同（ul.lis），通过内容区域区分
  Future<List<MessageItem>> _fetchFromHomepage({
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(_baseUrl);
      final document = html_parser.parse(htmlText);

      // 所有 ul.lis 列表块
      final allLists = document.querySelectorAll('ul.lis');
      if (allLists.isEmpty) return [];

      // 首页有两个 ul.lis 区块：第一个是建设要闻，第二个是通知公告
      final targetIndex = category == MessageCategory.constructionNews ? 0 : 1;
      if (targetIndex >= allLists.length) return [];

      final targetList = allLists[targetIndex];
      final listItems = targetList.querySelectorAll('li');
      final messages = <MessageItem>[];

      for (final item in listItems) {
        // 提取链接和标题
        final anchor = item.querySelector('a[title]');
        if (anchor == null) continue;

        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        // 提取日期（仅 MM-DD，通过统一工具补全年份）
        final dateSpan = item.querySelector('span');
        final rawDate = dateSpan?.text.trim() ?? '';
        final date = normalizeDate(rawDate);

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.construction,
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
