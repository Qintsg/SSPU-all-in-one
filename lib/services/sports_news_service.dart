/*
 * 体育部消息解析服务 — 抓取体育部网站的通知公告与部门动态
 * 支持 342（通知公告）和 343（部门动态）两个栏目
 * 体育部使用 table 布局列表：table.wp_article_list_table ul li > span + a
 * 列表页只提供日期，精确发布时间需进入文章页读取 .time
 * @Project : SSPU-all-in-one
 * @File : sports_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 体育部消息解析服务（单例）
/// 从 pe2016.sspu.edu.cn 抓取通知公告和部门动态
class SportsNewsService {
  SportsNewsService._();

  static final SportsNewsService instance = SportsNewsService._();

  /// 体育部基础 URL
  static const String _baseUrl = 'https://pe2016.sspu.edu.cn';

  /// 通知公告栏目路径
  static const String _noticePath = '/342';

  /// 部门动态栏目路径
  static const String _eventPath = '/343';

  final HttpService _http = HttpService.instance;

  /// 获取通知公告
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNotices({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _noticePath,
      category: MessageCategory.sportsNotice,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取部门动态
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchEvents({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _eventPath,
      category: MessageCategory.sportsEvent,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 根据页码生成列表页 URL
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
    int maxPages = 10,
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

      for (final msg in pageMessages) {
        if (messages.length >= maxCount) break;
        messages.add(msg);
      }

      currentPage++;
    }

    return messages;
  }

  /// 抓取单页内所有消息项
  /// 体育部解析模式: table 内 ul li → span(日期) + a[title](标题)
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      // 体育部列表在 table 内的 ul li 中
      final listItems = document.querySelectorAll(
        'table.wp_article_list_table li',
      );
      final messages = <MessageItem>[];

      for (final item in listItems) {
        // 提取链接和标题
        final anchor = item.querySelector('a');
        if (anchor == null) continue;

        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        // 列表页日期用于回退，精确发布时间从文章页读取。
        final dateSpan = item.querySelector('span');
        final fallbackDate = normalizeDate(dateSpan?.text.trim() ?? '');
        final publishTime = await _fetchArticlePublishTime(fullUrl);
        final date = publishTime?.date ?? fallbackDate;

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.sports,
            category: category,
            timestamp:
                publishTime?.timestamp ?? MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (error) {
      return [];
    }
  }

  /// 从文章页提取精确发布时间。
  /// 页面格式通常为：发布时间：2025-09-17 08:46:05
  Future<_ArticlePublishTime?> _fetchArticlePublishTime(
    String articleUrl,
  ) async {
    try {
      final htmlText = await _http.fetchText(articleUrl);
      final document = html_parser.parse(htmlText);
      final timeText = document.querySelector('.time')?.text ?? '';
      final match = RegExp(
        r'(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}:\d{2}))?',
      ).firstMatch(timeText);
      if (match == null) return null;

      final date = normalizeDate(match.group(1) ?? '');
      final time = match.group(2);
      final timestamp = time == null
          ? MessageItem.computeTimestamp(date)
          : DateTime.parse('$date $time').millisecondsSinceEpoch;
      return _ArticlePublishTime(date: date, timestamp: timestamp);
    } catch (_) {
      return null;
    }
  }

  /// 基于 URL 生成稳定的消息唯一 ID
  String _generateId(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}

/// 文章页发布时间解析结果
class _ArticlePublishTime {
  final String date;
  final int timestamp;

  const _ArticlePublishTime({required this.date, required this.timestamp});
}
