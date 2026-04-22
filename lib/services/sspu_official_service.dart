/*
 * 学校官网消息解析服务 — 抓取 SSPU 官网学校新闻、通知公告与校内活动
 * 支持 2964（学校新闻）、2965（通知公告）和 xsjz（校内活动）栏目
 * 官网使用 div 嵌套结构：.col_news_con ul.news_list li.news > a > div.news_meta + div.news_title
 * 校内活动由官网 JS 通过 _wp3services/generalQuery 动态加载
 * 注意：需限定 .col_news_con 容器，排除页脚 .foot-left 中的固定栏目小部件
 * @Project : SSPU-all-in-one
 * @File : sspu_official_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

/// 学校官网消息解析服务（单例）
/// 从 www.sspu.edu.cn 抓取学校新闻、通知公告和校内活动
class SspuOfficialService {
  SspuOfficialService._();

  static final SspuOfficialService instance = SspuOfficialService._();

  /// 官网基础 URL
  static const String _baseUrl = 'https://www.sspu.edu.cn';

  /// 学校新闻栏目路径
  static const String _newsPath = '/2964';

  /// 通知公告栏目路径
  static const String _noticePath = '/2965';

  /// 校内活动动态接口栏目 ID
  static const int _activityColumnId = 3042;

  final HttpService _http = HttpService.instance;

  /// 获取学校新闻
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNews({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _newsPath,
      category: MessageCategory.sspuNews,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取通知公告
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNotices({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchFromColumn(
      columnPath: _noticePath,
      category: MessageCategory.sspuNotice,
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
    );
  }

  /// 获取学术活动讲座
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchActivities({
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) async {
    return _fetchActivitiesFromApi(
      maxCount: maxCount,
      knownMessageIds: knownMessageIds,
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
  /// 官网解析模式: .col_news_con ul.news_list li.news > a.news_box1 > div.news_meta + div.news_title
  /// 限定 .col_news_con 以排除页脚固定栏目（人才招聘/课程思政等）
  Future<List<MessageItem>> _fetchSinglePage({
    required String url,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      // 官网列表: .col_news_con 限定主内容区，排除页脚 .foot-left 中的固定栏目
      final newsItems = document.querySelectorAll(
        '.col_news_con ul.news_list li.news',
      );
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

        // 基于 URL 的 MD5 生成唯一 ID
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        // 提取日期（div.news_meta）并规范化格式
        final dateEl = item.querySelector('div.news_meta');
        final date = normalizeDate(dateEl?.text.trim() ?? '');

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.sspuOfficial,
            category: category,
            timestamp: MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (error) {
      // 网络或解析异常返回空列表
      return [];
    }
  }

  /// 通过官网动态接口抓取校内活动列表
  /// xsjz 页面首屏只有占位模板，真实列表由 activity.js 调用此接口渲染。
  Future<List<MessageItem>> _fetchActivitiesFromApi({
    required int maxCount,
    Set<String>? knownMessageIds,
    int maxPages = 20,
  }) async {
    final messages = <MessageItem>[];
    var currentPage = 1;

    while (messages.length < maxCount && currentPage <= maxPages) {
      final pageMessages = await _fetchActivityPageFromApi(
        pageIndex: currentPage,
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

  /// 抓取校内活动动态接口的单页数据
  Future<List<MessageItem>> _fetchActivityPageFromApi({
    required int pageIndex,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final response = await _http.post<Map<String, dynamic>>(
        '$_baseUrl/_wp3services/generalQuery?queryObj=articles',
        options: Options(contentType: Headers.formUrlEncodedContentType),
        data: {
          'siteId': 2,
          'columnId': _activityColumnId,
          'pageIndex': pageIndex,
          'rows': 14,
          'orders': jsonEncode([
            {'field': 'f5', 'type': 'desc'},
            {'field': 'publishTime', 'type': 'desc'},
          ]),
          'returnInfos': jsonEncode([
            {'field': 'title', 'name': 'title'},
            {'field': 'f1', 'name': 'f1'},
            {'field': 'f2', 'name': 'f2'},
            {'field': 'f3', 'name': 'f3'},
            {'field': 'f4', 'name': 'f4'},
            {
              'field': 'publishTime',
              'pattern': [
                {'name': 'd', 'value': 'yyyy-MM-dd'},
              ],
              'name': 'publishTime',
            },
            {'field': 'f5', 'name': 'f5'},
          ]),
          'conditions': jsonEncode([
            {'field': 'scope', 'value': 0, 'judge': '='},
          ]),
        },
      );

      final responseBody = response.data;
      final activityRows = responseBody?['data'];
      if (activityRows is! List) return [];

      final messages = <MessageItem>[];
      for (final row in activityRows) {
        if (row is! Map<String, dynamic>) continue;

        final title = (row['title'] as String?)?.trim() ?? '';
        final rawUrl = (row['url'] as String?)?.trim() ?? '';
        if (title.isEmpty || rawUrl.isEmpty) continue;

        final fullUrl = rawUrl.startsWith('http') ? rawUrl : '$_baseUrl$rawUrl';
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        final activityTime = (row['f5'] as String?)?.trim() ?? '';
        final publishTime = (row['publishTime'] as String?)?.trim() ?? '';
        final date = normalizeDate(
          activityTime.isNotEmpty ? activityTime.split(' ').first : publishTime,
        );

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.sspuOfficial,
            category: MessageCategory.sspuActivity,
            timestamp: _computeActivityTimestamp(activityTime, date),
          ),
        );
      }

      return messages;
    } catch (_) {
      return [];
    }
  }

  /// 校内活动优先使用活动开始时间排序，缺失时回退到日期时间戳。
  int _computeActivityTimestamp(String activityTime, String date) {
    try {
      if (activityTime.isNotEmpty) {
        return DateTime.parse(activityTime).millisecondsSinceEpoch;
      }
    } catch (_) {
      // 动态接口时间异常时继续回退到日期，避免丢弃消息。
    }
    return MessageItem.computeTimestamp(date);
  }

  /// 基于 URL 生成稳定的消息唯一 ID
  String _generateId(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}
