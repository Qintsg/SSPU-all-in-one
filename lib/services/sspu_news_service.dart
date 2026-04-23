/*
 * SSPU 信息公开网解析服务 — 抓取并解析学校信息公开网站的消息列表
 * 支持 3148（最新公开信息）和 3149（通知公示）两个栏目
 * 支持自动翻页，当单页不足目标条数时继续抓取下一页
 * @Project : SSPU-all-in-one
 * @File : sspu_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// SSPU 信息公开网解析服务（单例）
/// 负责从信息公开网抓取消息列表并转换为统一 MessageItem 结构
class SspuNewsService {
  SspuNewsService._();

  static final SspuNewsService instance = SspuNewsService._();

  /// 信息公开网基础 URL
  static const String _baseUrl = 'https://xxgk.sspu.edu.cn';

  /// 最新公开信息栏目基础路径
  static const String _latestInfoPath = '/3148';

  /// 通知公示栏目基础路径
  static const String _noticePath = '/3149';

  final HttpService _http = HttpService.instance;

  /// 获取最新公开信息（3148 栏目）
  /// [maxCount] 最大获取条数，默认 20 条
  /// 若当前页不足 maxCount，会自动翻页继续获取
  Future<List<MessageItem>> fetchLatestInfo({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _latestInfoPath,
      category: MessageCategory.latestInfo,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取通知公示（3149 栏目）
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNotices({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _noticePath,
      category: MessageCategory.notice,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 根据页码生成栏目列表页 URL
  /// 第 1 页: /xxxx/list.htm
  /// 第 N 页 (N>=2): /xxxx/listN.htm
  String _buildPageUrl(String columnPath, int page) {
    if (page <= 1) return '$_baseUrl$columnPath/list.htm';
    return '$_baseUrl$columnPath/list$page.htm';
  }

  /// 从指定栏目抓取消息，支持自动翻页
  /// [columnPath] 栏目基础路径（如 /3148）
  /// [category] 内容分类
  /// [maxCount] 目标获取条数
  /// [maxPages] 最大访问页数上限（安全保护，避免无限循环）
  Future<List<MessageItem>> _fetchFromColumn({
    required String columnPath,
    required MessageCategory category,
    required int maxCount,
    Set<String>? knownMessageIds,
    int maxPages = 20,
  }) async {
    final messages = <MessageItem>[];
    var currentPage = 1;

    // 持续翻页直到达到目标条数、页面无数据或达到最大页数
    while (messages.length < maxCount && currentPage <= maxPages) {
      final pageMessages = await _fetchSinglePage(
        url: _buildPageUrl(columnPath, currentPage),
        category: category,
        knownMessageIds: knownMessageIds,
      );

      // 当前页无数据，说明已到末尾
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
  /// 返回该页全部解析结果，不做数量截断
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      final newsItems = document.querySelectorAll(
        '.col_news_con ul.news_list li.news',
      );
      final messages = <MessageItem>[];

      for (final item in newsItems) {
        // 提取标题和链接
        final anchor = item.querySelector('span.news_title a');
        if (anchor == null) continue;

        // 优先使用 title 属性（完整标题），否则用文本内容
        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        // 拼接完整 URL
        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        // 生成唯一 ID（基于 URL 的 MD5 哈希，确保去重）
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        // 提取日期并规范化格式
        final dateMeta = item.querySelector('span.news_meta');
        final date = normalizeDate(dateMeta?.text.trim() ?? '');

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.infoDisclosure,
            category: category,
            timestamp: MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (error) {
      // 网络或解析异常时返回空列表，由调用方决定如何提示用户
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
