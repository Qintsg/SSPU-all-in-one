/*
 * Web 内容获取服务 — 网页内容抓取与 HTML 解析
 * 基于 http_service（dio）获取网页源码，使用 html 包解析 DOM
 * 提供标题提取、正文提取、链接收集等实用方法
 * @Project : SSPU-all-in-one
 * @File : web_content_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'http_service.dart';

/// Web 内容获取服务（单例）
/// 负责从指定 URL 抓取网页并解析其中的结构化信息
class WebContentService {
  WebContentService._();

  static final WebContentService instance = WebContentService._();

  /// HTTP 客户端引用（复用 HttpService 单例）
  final HttpService _http = HttpService.instance;

  /// 获取并解析指定 URL 的网页内容
  /// 返回解析后的 Document 对象，供调用方自由查询
  Future<Document> fetchDocument(String url) async {
    final htmlText = await _http.fetchText(url);
    return html_parser.parse(htmlText);
  }

  /// 提取网页标题
  /// 返回 <title> 标签内容，未找到则返回空字符串
  Future<String> fetchTitle(String url) async {
    final doc = await fetchDocument(url);
    return doc.head?.querySelector('title')?.text.trim() ?? '';
  }

  /// 提取网页中的纯文本正文
  /// 移除 script/style 标签后提取 body 内文本
  Future<String> fetchBodyText(String url) async {
    final doc = await fetchDocument(url);
    // 移除脚本和样式标签，避免干扰正文
    doc.querySelectorAll('script, style, noscript').forEach(
      (element) => element.remove(),
    );
    return doc.body?.text.trim() ?? '';
  }

  /// 提取网页中的所有链接
  /// 返回 Map 列表，每项包含 text（链接文字）和 href（链接地址）
  Future<List<Map<String, String>>> fetchLinks(String url) async {
    final doc = await fetchDocument(url);
    final links = <Map<String, String>>[];
    for (final anchor in doc.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'] ?? '';
      final text = anchor.text.trim();
      if (href.isNotEmpty) {
        links.add({'text': text, 'href': href});
      }
    }
    return links;
  }

  /// 通过 CSS 选择器提取网页中的特定内容
  /// [selector] CSS 选择器（如 '.article-content', '#main-body'）
  /// 返回匹配元素的文本内容列表
  Future<List<String>> fetchBySelector(String url, String selector) async {
    final doc = await fetchDocument(url);
    return doc
        .querySelectorAll(selector)
        .map((element) => element.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  /// 通过 CSS 选择器提取网页中匹配元素的 HTML 片段
  /// 适用于需要保留原始标记结构的场景
  Future<List<String>> fetchHtmlBySelector(String url, String selector) async {
    final doc = await fetchDocument(url);
    return doc
        .querySelectorAll(selector)
        .map((element) => element.outerHtml)
        .toList();
  }

  /// 提取网页 meta 标签信息
  /// 返回 name/property → content 的映射表
  Future<Map<String, String>> fetchMetaTags(String url) async {
    final doc = await fetchDocument(url);
    final metaTags = <String, String>{};
    for (final meta in doc.querySelectorAll('meta')) {
      final name = meta.attributes['name'] ?? meta.attributes['property'] ?? '';
      final content = meta.attributes['content'] ?? '';
      if (name.isNotEmpty && content.isNotEmpty) {
        metaTags[name] = content;
      }
    }
    return metaTags;
  }
}
