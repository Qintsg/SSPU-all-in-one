/*
 * SSPU 信息公开网解析服务 — 抓取并解析学校信息公开网站的消息列表
 * 支持 3148（最新公开信息）和 3149（通知公示）两个栏目
 * @Project : SSPU-all-in-one
 * @File : sspu_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
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

  /// 最新公开信息栏目 URL 模板，{page} 为页码
  static const String _latestInfoUrl = '$_baseUrl/3148/list.htm';

  /// 通知公示栏目 URL 模板
  static const String _noticeUrl = '$_baseUrl/3149/list.htm';

  final HttpService _http = HttpService.instance;

  /// 获取最新公开信息（3148 栏目）
  /// [maxCount] 最大获取条数，默认 20 条
  /// 返回解析后的消息列表
  Future<List<MessageItem>> fetchLatestInfo({int maxCount = 20}) async {
    return _fetchFromColumn(
      url: _latestInfoUrl,
      category: MessageCategory.latestInfo,
      maxCount: maxCount,
    );
  }

  /// 获取通知公示（3149 栏目）
  /// [maxCount] 最大获取条数，默认 20 条
  Future<List<MessageItem>> fetchNotices({int maxCount = 20}) async {
    return _fetchFromColumn(
      url: _noticeUrl,
      category: MessageCategory.notice,
      maxCount: maxCount,
    );
  }

  /// 从指定栏目页抓取并解析消息列表
  /// [url] 栏目列表页 URL
  /// [category] 内容分类
  /// [maxCount] 最大获取条数
  Future<List<MessageItem>> _fetchFromColumn({
    required String url,
    required MessageCategory category,
    required int maxCount,
  }) async {
    try {
      final htmlText = await _http.fetchText(url);
      final document = html_parser.parse(htmlText);

      // 选取消息列表项：每项为 <li class="news"> 内含标题和日期
      final newsItems = document.querySelectorAll('ul.news_list li.news');
      final messages = <MessageItem>[];

      for (final item in newsItems) {
        if (messages.length >= maxCount) break;

        // 提取标题和链接
        final anchor = item.querySelector('span.news_title a');
        if (anchor == null) continue;

        // 优先使用 title 属性（完整标题），否则用文本内容
        final title = anchor.attributes['title']?.trim() ??
            anchor.text.trim();
        final href = anchor.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        // 拼接完整 URL（相对路径需补全域名）
        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        // 提取日期并规范化格式
        final dateMeta = item.querySelector('span.news_meta');
        final date = normalizeDate(dateMeta?.text.trim() ?? '');

        // 生成唯一 ID（基于 URL 的 MD5 哈希，确保去重）
        final messageId = _generateId(fullUrl);

        messages.add(MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: MessageSourceName.infoDisclosure,
          category: category,
        ));
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
