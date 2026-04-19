/*
 * 学校官网消息解析服务 — 抓取 SSPU 官网的通知公告与学术活动列表
 * 支持 2965（通知公告）和 xsjz（学术活动讲座）两个栏目
 * 官网使用 div 嵌套结构：.col_news_con ul.news_list li.news > a > div.news_meta + div.news_title
 * 注意：需限定 .col_news_con 容器，排除页脚 .foot-left 中的固定栏目小部件
 * @Project : SSPU-all-in-one
 * @File : sspu_official_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import 'http_service.dart';

/// 学校官网消息解析服务（单例）
/// 从 www.sspu.edu.cn 抓取通知公告和学术活动讲座
class SspuOfficialService {
  SspuOfficialService._();

  static final SspuOfficialService instance = SspuOfficialService._();

  /// 官网基础 URL
  static const String _baseUrl = 'https://www.sspu.edu.cn';

  /// 通知公告栏目路径
  static const String _noticePath = '/2965';

  /// 学术活动讲座栏目路径
  static const String _activityPath = '/xsjz';

  final HttpService _http = HttpService.instance;

  /// 获取通知公告
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNotices({int maxCount = 20}) async {
    return _fetchFromColumn(
      columnPath: _noticePath,
      category: MessageCategory.sspuNotice,
      maxCount: maxCount,
    );
  }

  /// 获取学术活动讲座
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchActivities({int maxCount = 20}) async {
    return _fetchFromColumn(
      columnPath: _activityPath,
      category: MessageCategory.sspuActivity,
      maxCount: maxCount,
    );
  }

  /// 根据页码生成列表页 URL
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
    int maxPages = 20,
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
  /// 官网解析模式: .col_news_con ul.news_list li.news > a.news_box1 > div.news_meta + div.news_title
  /// 限定 .col_news_con 以排除页脚固定栏目（人才招聘/课程思政等）
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
    required MessageCategory category,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      // 官网列表: .col_news_con 限定主内容区，排除页脚 .foot-left 中的固定栏目
      final newsItems = document.querySelectorAll('.col_news_con ul.news_list li.news');
      final messages = <MessageItem>[];

      for (final item in newsItems) {
        // 提取链接（整个 li 内的 a 标签）
        final anchor = item.querySelector('a');
        if (anchor == null) continue;

        final href = anchor.attributes['href'] ?? '';
        if (href.isEmpty) continue;

        // 提取标题（div.news_title）
        final titleEl = item.querySelector('div.news_title');
        final title = titleEl?.text.trim() ?? '';
        if (title.isEmpty) continue;

        // 拼接完整 URL
        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        // 提取日期（div.news_meta）
        final dateEl = item.querySelector('div.news_meta');
        final date = dateEl?.text.trim() ?? '';

        // 基于 URL 的 MD5 生成唯一 ID
        final messageId = _generateId(fullUrl);

        messages.add(MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.sspuOfficial,
          category: category,
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
