/*
 * 新闻网消息解析服务 — 抓取校园新闻网首页综合新闻
 * 仅抓取首页内容，不翻页
 * 综合新闻结构: div.zhxw_list ul li > span.riqi(YYYY-MM-DD) + a[title](标题)
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
/// 从 xww.sspu.edu.cn 首页抓取综合新闻
class CampusNewsService {
  CampusNewsService._();

  static final CampusNewsService instance = CampusNewsService._();

  /// 新闻网基础 URL
  static const String _baseUrl = 'https://xww.sspu.edu.cn';

  final HttpService _http = HttpService.instance;

  /// 获取综合新闻（首页 1432 栏目区块）
  Future<List<MessageItem>> fetchCampusNews({
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(_baseUrl);
      final document = html_parser.parse(htmlText);

      // 综合新闻在 div.zhxw_list 区块内
      final newsContainer = document.querySelector('div.zhxw_list');
      if (newsContainer == null) return [];

      final listItems = newsContainer.querySelectorAll('li');
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

        // 提取日期（span.riqi 内为 YYYY-MM-DD）并规范化格式
        final dateSpan = item.querySelector('span.riqi');
        final date = normalizeDate(dateSpan?.text.trim() ?? '');

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
