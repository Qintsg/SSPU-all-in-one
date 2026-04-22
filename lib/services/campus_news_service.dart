/*
 * 新闻网消息解析服务 — 抓取新闻网综合新闻列表
 * 通过栏目列表页解析，支持翻页与完整发布日期
 * 综合新闻结构: ul li > span.riqi1(YYYY-MM-DD) + a[title](标题)
 * @Project : SSPU-all-in-one
 * @File : campus_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 新闻网消息解析服务（单例）
/// 从 xww.sspu.edu.cn 抓取综合新闻
class CampusNewsService {
  CampusNewsService._();

  static final CampusNewsService instance = CampusNewsService._();

  /// 新闻网基础 URL
  static const String _baseUrl = 'https://xww.sspu.edu.cn';

  /// 综合新闻栏目路径
  static const String _campusNewsPath = '/1432';

  final HttpService _http = HttpService.instance;

  /// 获取综合新闻
  Future<List<MessageItem>> fetchCampusNews({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _campusNewsPath,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 根据页码生成栏目列表页 URL
  String _buildPageUrl(String columnPath, int page) {
    if (page <= 1) return '$_baseUrl$columnPath/list.htm';
    return '$_baseUrl$columnPath/list$page.htm';
  }

  /// 从综合新闻栏目抓取消息，支持自动翻页
  Future<List<MessageItem>> _fetchFromColumn({
    required String columnPath,
    required int maxCount,
    Set<String>? knownMessageIds,
    int maxPages = 20,
  }) async {
    final messages = <MessageItem>[];
    var currentPage = 1;

    while (messages.length < maxCount && currentPage <= maxPages) {
      final pageMessages = await _fetchSinglePage(
        url: _buildPageUrl(columnPath, currentPage),
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
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      final listItems = document.querySelectorAll('.mtsj_list li');
      final messages = <MessageItem>[];

      for (final item in listItems) {
        final anchor = item.querySelector('a[title]');
        if (anchor == null) continue;

        final rawDate =
            item.querySelector('span.riqi1')?.text.trim() ??
            item.querySelector('span.riqi')?.text.trim() ??
            '';
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
            sourceName: MessageSourceName.newsCenter,
            category: MessageCategory.campusNews,
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
