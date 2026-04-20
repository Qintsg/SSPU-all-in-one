/*
 * 保卫处消息解析服务 — 抓取保卫处网站的平安动态与宣教专栏
 * 支持 1019（平安动态）和 1023（宣教专栏）两个栏目
 * 保卫处列表结构: ul li > span(日期) + a[title](标题)
 * @Project : SSPU-all-in-one
 * @File : security_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 保卫处消息解析服务（单例）
/// 从 bwwz.sspu.edu.cn 抓取平安动态和宣教专栏
class SecurityNewsService {
  SecurityNewsService._();

  static final SecurityNewsService instance = SecurityNewsService._();

  /// 保卫处基础 URL
  static const String _baseUrl = 'https://bwwz.sspu.edu.cn';

  /// 平安动态栏目路径
  static const String _newsPath = '/1019';

  /// 宣教专栏栏目路径
  static const String _educationPath = '/1023';

  final HttpService _http = HttpService.instance;

  /// 获取平安动态
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNews({int maxCount = 20}) async {
    return _fetchFromColumn(
      columnPath: _newsPath,
      category: MessageCategory.securityNews,
      maxCount: maxCount,
    );
  }

  /// 获取宣教专栏
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchEducation({int maxCount = 20}) async {
    return _fetchFromColumn(
      columnPath: _educationPath,
      category: MessageCategory.securityEducation,
      maxCount: maxCount,
    );
  }

  /// 根据页码生成列表页 URL（保卫处使用 .psp 后缀）
  String _buildPageUrl(String columnPath, int page) {
    if (page <= 1) return '$_baseUrl$columnPath/list.psp';
    return '$_baseUrl$columnPath/list$page.psp';
  }

  /// 从指定栏目抓取消息，支持自动翻页
  Future<List<MessageItem>> _fetchFromColumn({
    required String columnPath,
    required MessageCategory category,
    required int maxCount,
    int maxPages = 10,
  }) async {
    final messages = <MessageItem>[];
    var currentPage = 1;

    while (messages.length < maxCount && currentPage <= maxPages) {
      final pageMessages = await _fetchSinglePage(
        url: _buildPageUrl(columnPath, currentPage),
        category: category,
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
  /// 保卫处解析模式: ul li → span(日期) + a[title](标题)
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
    required MessageCategory category,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      // 保卫处内容区的列表项
      final listItems = document.querySelectorAll('ul li');
      final messages = <MessageItem>[];

      for (final item in listItems) {
        // 提取链接和标题
        final anchor = item.querySelector('a[title]');
        if (anchor == null) continue;

        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        // 提取日期并规范化格式
        final dateSpan = item.querySelector('span');
        final rawDate = dateSpan?.text.trim() ?? '';
        // 跳过非日期格式的项（导航等杂项）
        if (!RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(rawDate)) continue;
        final date = normalizeDate(rawDate);

        final messageId = _generateId(fullUrl);

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.securityDept,
            category: category,
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
