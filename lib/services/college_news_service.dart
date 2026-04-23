/*
 * 学院/部门通用新闻解析服务 — 配置驱动的首页新闻抓取
 * 支持多种 CMS 模板：A(标准列表)、B(图文卡片)、C(swiper)、D(自定义)
 * 每个学院通过 CollegeConfig 描述域名与解析规则，统一入口调用
 * @Project : SSPU-all-in-one
 * @File : college_news_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../models/message_item.dart';
import '../utils/date_utils.dart';
import 'http_service.dart';

part 'college_news_service_configs.dart';
part 'college_news_service_dispatch.dart';
part 'college_news_service_aggregate_a.dart';
part 'college_news_service_aggregate_b.dart';
part 'college_news_service_aggregate_c.dart';
part 'college_news_service_common_fetch.dart';
part 'college_news_service_list_pages_a.dart';
part 'college_news_service_list_pages_b.dart';
part 'college_news_service_parsers.dart';

/// 学院首页新闻解析的 HTML 模板类型
enum CollegeTemplate {
  /// 模板A: ul 列表 — li > span(日期) + a(标题)
  /// 代表: jxxy, zihuan, sltj, mkszyxy, wywh, yjs, adult, library
  listA,

  /// 模板B: ul.news_list — li.news 图文卡片
  /// 代表: sem, sic, jjglxy, design, cive, cxcy
  newsListB,

  /// 模板C: swiper 卡片轮播
  /// 代表: imce
  swiperC,

  /// 模板D: 其他自定义结构
  /// 代表: imhe, stes, education, sie
  customD,
}

/// 单个学院/部门的抓取配置
class CollegeConfig {
  /// 学院基础 URL（含协议，无末尾斜杠）
  final String baseUrl;

  /// HTML 模板类型
  final CollegeTemplate template;

  /// 消息来源名称（tag2）
  final MessageSourceName sourceName;

  /// 消息分类（tag3）
  final MessageCategory category;

  /// ---- 模板A参数 ----
  /// 列表容器选择器（如 'ul.list', 'div.tyList ul', 'ul.tylist', 'ul.currency'）
  final String? listContainerSelector;

  /// 列表项选择器（如 'li.ui-preDot', 'li'）
  final String? listItemSelector;

  /// 日期选择器（如 'span.time', 'span.riqi', 'span'）
  final String? dateSelector;

  /// 标题选择器（如 'a.text-overflow', 'a', 'span.news_title a'）
  final String? titleSelector;

  /// 是否从 title 属性获取标题（否则取 text content）
  final bool titleFromAttribute;

  /// 日期是否为短格式 MM-DD（需补年份）
  final bool shortDateFormat;

  /// ---- 模板B参数 ----
  /// news_list 中标题选择器（如 'div.news_title a', 'div.news_title'）
  final String? newsListTitleSelector;

  /// news_list 中日期选择器（如 'div.news_date', 'div.news_meta'）
  final String? newsListDateSelector;

  /// news_list 中链接选择器（如 'a.news_link', 'a'）— 若整个 li 内有统一 a
  final String? newsListLinkSelector;

  /// news_list 容器选择器（默认 'ul.news_list'）
  final String? newsListContainerSelector;

  /// ---- 模板C参数 ----
  /// swiper 容器选择器
  final String? swiperContainerSelector;

  /// ---- 模板D参数 ----
  /// 自定义项目选择器（直接 querySelectorAll 整页）
  final String? customItemSelector;

  /// 自定义标题选择器（在项目内查找）
  final String? customTitleSelector;

  /// 自定义日期选择器（在项目内查找）
  final String? customDateSelector;

  /// 自定义链接选择器（在项目内查找，null 则用 item 本身的 href）
  final String? customLinkSelector;

  /// 自定义日期格式（如 'YYYY/MM/DD' 需替换斜杠）
  final bool customDateSlashFormat;

  /// 自定义日期需要拼合（day + year-month 两个元素）
  final bool customDateComposite;

  /// 自定义日期年月选择器（拼合模式下）
  final String? customDateYearMonthSelector;

  const CollegeConfig({
    required this.baseUrl,
    required this.template,
    required this.sourceName,
    required this.category,
    this.listContainerSelector,
    this.listItemSelector,
    this.dateSelector,
    this.titleSelector,
    this.titleFromAttribute = false,
    this.shortDateFormat = false,
    this.newsListTitleSelector,
    this.newsListDateSelector,
    this.newsListLinkSelector,
    this.newsListContainerSelector,
    this.customItemSelector,
    this.customTitleSelector,
    this.customDateSelector,
    this.customLinkSelector,
    this.customDateSlashFormat = false,
    this.customDateComposite = false,
    this.customDateYearMonthSelector,
    this.swiperContainerSelector,
  });
}

/// 学院/部门通用新闻解析服务（单例）
/// 通过 [CollegeConfig] 配置表驱动 20 个教学单位首页新闻抓取
class CollegeNewsService {
  CollegeNewsService._();

  static final CollegeNewsService instance = CollegeNewsService._();

  final HttpService _http = HttpService.instance;

  /// 根据 channelId 获取该学院/部门的首页新闻列表
  /// [channelId] 对应 channel_config.dart 中的 id（如 'college_cs'）
  Future<List<MessageItem>> fetchNews(
    String channelId, {
    int maxCount = 20,
    Set<String>? knownMessageIds,
  }) => _fetchCollegeNews(
    this,
    channelId,
    maxCount: maxCount,
    knownMessageIds: knownMessageIds,
  );
}

/// 文章页发布时间解析结果。
class _CollegeArticlePublishTime {
  final String date;
  final int timestamp;

  const _CollegeArticlePublishTime({
    required this.date,
    required this.timestamp,
  });
}
