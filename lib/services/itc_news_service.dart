/*
 * 信息技术中心消息解析服务 — 抓取 ITC 网站的最新消息列表
 * 支持 zxxx（最新消息）栏目
 * ITC 页面使用不同于信息公开网的列表结构：li.nN > span(日期) + a(标题)
 * @Project : SSPU-all-in-one
 * @File : itc_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import 'http_service.dart';

/// 信息技术中心消息解析服务（单例）
/// 从 itc.sspu.edu.cn 抓取最新消息
class ItcNewsService {
  ItcNewsService._();

  static final ItcNewsService instance = ItcNewsService._();

  /// ITC 基础 URL
  static const String _baseUrl = 'https://itc.sspu.edu.cn';

  /// 最新消息栏目路径
  static const String _newsPath = '/zxxx';

  final HttpService _http = HttpService.instance;

  /// 获取最新消息
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNews({int maxCount = 20}) async {
    return _fetchFromColumn(
      columnPath: _newsPath,
      maxCount: maxCount,
    );
  }

  /// 根据页码生成列表页 URL
  /// 第 1 页: /zxxx/list.htm，第 N 页 (N>=2): /zxxx/listN.htm
  String _buildPageUrl(String columnPath, int page) {
    if (page <= 1) return '$_baseUrl$columnPath/list.htm';
    return '$_baseUrl$columnPath/list$page.htm';
  }

  /// 从指定栏目抓取消息，支持自动翻页
  /// [columnPath] 栏目路径
  /// [maxCount] 目标获取条数
  /// [maxPages] 最大翻页数（安全保护）
  Future<List<MessageItem>> _fetchFromColumn({
    required String columnPath,
    required int maxCount,
    int maxPages = 10,
  }) async {
    final messages = <MessageItem>[];
    var currentPage = 1;

    while (messages.length < maxCount && currentPage <= maxPages) {
      final pageMessages = await _fetchSinglePage(
        url: _buildPageUrl(columnPath, currentPage),
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
  /// ITC 解析模式: li 元素中包含 <span>日期</span> 和 <a href title>标题</a>
  /// 选择器: 匹配 class 以 'n' 开头的 li 元素（n1, n2, n3...）
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      // ITC 列表项: li 元素 class 为 n1/n2/n3...，内含 span(日期) 和 a(标题链接)
      final listItems = document.querySelectorAll('li[class^="n"]');
      final messages = <MessageItem>[];

      for (final item in listItems) {
        // 提取链接和标题
        final anchor = item.querySelector('a');
        if (anchor == null) continue;

        final title =
            anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        // 拼接完整 URL
        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        // 提取日期（span 元素中的文本）
        final dateSpan = item.querySelector('span');
        final date = dateSpan?.text.trim() ?? '';

        // 基于 URL 的 MD5 生成唯一 ID
        final messageId = _generateId(fullUrl);

        messages.add(MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.itc,
          category: MessageCategory.itcNews,
        ));
      }

      return messages;
    } catch (error) {
      // 网络或解析异常返回空列表
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
