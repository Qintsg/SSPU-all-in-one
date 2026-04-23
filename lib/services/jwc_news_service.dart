/*
 * 教务处消息解析服务 — 抓取并解析教务处网站的消息列表
 * 支持 895（教学动态）、897（学生专栏）和 898（教师专栏）三个栏目
 * 与信息公开网使用相同 CMS，共用 .col_news_con ul.news_list 解析模式
 * 列表页只提供日期，精确发布时间需进入文章页读取 .arti_update
 * @Project : SSPU-all-in-one
 * @File : jwc_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 教务处消息解析服务（单例）
/// 从 jwc.sspu.edu.cn 抓取教学动态、学生专栏和教师专栏消息
class JwcNewsService {
  JwcNewsService._();

  static final JwcNewsService instance = JwcNewsService._();

  /// 教务处基础 URL
  static const String _baseUrl = 'https://jwc.sspu.edu.cn';

  /// 教学动态路径
  static const String _teachingPath = '/895';

  /// 学生专栏路径
  static const String _studentPath = '/897';

  /// 教师专栏路径
  static const String _teacherPath = '/898';

  final HttpService _http = HttpService.instance;

  /// 获取教学动态消息
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchTeachingNews({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _teachingPath,
      category: MessageCategory.jwcTeaching,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取学生专栏消息
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchStudentNews({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _studentPath,
      category: MessageCategory.jwcStudent,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取教师专栏消息
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchTeacherNews({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _teacherPath,
      category: MessageCategory.jwcTeacher,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 根据页码生成栏目列表页 URL
  /// 第 1 页: /xxx/list.htm，第 N 页 (N>=2): /xxx/listN.htm
  String _buildPageUrl(String columnPath, int page) {
    if (page <= 1) return '$_baseUrl$columnPath/list.htm';
    return '$_baseUrl$columnPath/list$page.htm';
  }

  /// 从指定栏目抓取消息，支持自动翻页
  /// [columnPath] 栏目基础路径
  /// [category] 内容分类
  /// [maxCount] 目标获取条数
  /// [maxPages] 最大翻页数（安全保护）
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

      for (final msg in pageMessages) {
        if (messages.length >= maxCount) break;
        messages.add(msg);
      }

      currentPage++;
    }

    return messages;
  }

  /// 抓取单页内所有消息项
  /// 解析模式: ul.news_list li.news → span.news_title a[title] + span.news_meta
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

        final title = anchor.attributes['title']?.trim() ?? anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        // 拼接完整 URL（相对路径补全域名）
        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        // 基于 URL 的 MD5 生成唯一 ID
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        // 列表页日期用于回退，精确发布时间从文章页读取。
        final dateMeta = item.querySelector('span.news_meta');
        final fallbackDate = normalizeDate(dateMeta?.text.trim() ?? '');
        final publishTime = await _fetchArticlePublishTime(fullUrl);
        final date = publishTime?.date ?? fallbackDate;

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.jwc,
            category: category,
            timestamp:
                publishTime?.timestamp ?? MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (error) {
      // 网络或解析异常返回空列表，由调用方处理
      return [];
    }
  }

  /// 从文章页提取精确发布时间。
  /// 页面格式通常为：发布时间：2026-04-22 09:38:56
  Future<_ArticlePublishTime?> _fetchArticlePublishTime(
    String articleUrl,
  ) async {
    try {
      final htmlText = await _http.fetchText(articleUrl);
      final document = html_parser.parse(htmlText);
      final updateText = document.querySelector('.arti_update')?.text ?? '';
      final match = RegExp(
        r'(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}:\d{2}))?',
      ).firstMatch(updateText);
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
