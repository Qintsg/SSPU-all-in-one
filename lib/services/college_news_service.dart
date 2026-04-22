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
/// 通过 [CollegeConfig] 配置表驱动 19 个学院的首页新闻抓取
class CollegeNewsService {
  CollegeNewsService._();

  static final CollegeNewsService instance = CollegeNewsService._();

  final HttpService _http = HttpService.instance;

  /// 计信学院的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeCsCategoryPaths = {
    MessageCategory.collegeCsNews: ['/1216/list.htm'],
    MessageCategory.collegeCsTeacherWork: [
      '/2059/list.htm',
      '/2062/list.htm',
      '/2063/list.htm',
      '/2064/list.htm',
      '/2065/list.htm',
      '/2066/list.htm',
      '/2068/list.htm',
      '/2069/list.htm',
      '/2070/list.htm',
    ],
    MessageCategory.collegeCsStudentWork: [
      '/2075/list.htm',
      '/xshd/list.htm',
      '/2084/list.htm',
      '/2085/list.htm',
      '/2086/list.htm',
    ],
  };

  // ==================== 19 个学院/部门的配置表 ====================

  /// 全部学院配置，key 为 channel_config 中的 channelId
  static const Map<String, CollegeConfig> configs = {
    // --- 5.1 计算机与信息工程学院 (模板A) ---
    'college_cs': CollegeConfig(
      baseUrl: 'https://jxxy.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.collegeCs,
      category: MessageCategory.collegeCsNews,
      listContainerSelector: 'div.m-gzdt ul.list',
      listItemSelector: 'li.ui-preDot',
      dateSelector: 'span.time',
      titleSelector: 'a.text-overflow',
    ),

    // --- 5.2 智能制造与控制工程学院 (模板C: swiper) ---
    'college_im': CollegeConfig(
      baseUrl: 'https://imce.sspu.edu.cn',
      template: CollegeTemplate.swiperC,
      sourceName: MessageSourceName.collegeIm,
      category: MessageCategory.collegeImNews,
      swiperContainerSelector: 'div.news div.swiper-wrapper',
    ),

    // --- 5.3 资源与环境工程学院 (模板A) ---
    'college_re': CollegeConfig(
      baseUrl: 'https://zihuan.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.collegeRe,
      category: MessageCategory.collegeReNews,
      listContainerSelector: 'ul.list',
      listItemSelector: 'li.ui-preDot',
      dateSelector: 'span.time',
      titleSelector: 'a.text-overflow',
    ),

    // --- 5.4 能源与材料学院 (模板B: news_list) ---
    'college_em': CollegeConfig(
      baseUrl: 'https://sem.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeEm,
      category: MessageCategory.collegeEmNews,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.news_title a',
      newsListDateSelector: 'div.news_meta',
      newsListLinkSelector: 'div.news_title a',
    ),

    // --- 5.5 集成电路学院 (模板B) ---
    'college_ic': CollegeConfig(
      baseUrl: 'https://sic.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeIc,
      category: MessageCategory.collegeIcNews,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.news_title',
      newsListDateSelector: 'div.news_date',
      newsListLinkSelector: 'a.news_link',
    ),

    // --- 5.6 智能医学与健康工程学院 (模板D) ---
    'college_imhe': CollegeConfig(
      baseUrl: 'https://imhe.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.collegeImhe,
      category: MessageCategory.collegeImheNews,
      customItemSelector: 'a.btt-3',
      customTitleSelector: 'div.btt-4',
      customDateSelector: 'div.time-1',
    ),

    // --- 5.7 经济与管理学院 (模板B) ---
    'college_econ': CollegeConfig(
      baseUrl: 'https://jjglxy.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeEcon,
      category: MessageCategory.collegeEconNews,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.news_title',
      newsListDateSelector: 'div.news_meta',
      newsListLinkSelector: 'a',
    ),

    // --- 5.8 语言与文化传播学院 (模板A，MM-DD短日期) ---
    'college_lang': CollegeConfig(
      baseUrl: 'https://wywh.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.collegeLang,
      category: MessageCategory.collegeLangNews,
      listContainerSelector: 'ul.tylist',
      listItemSelector: 'li',
      dateSelector: 'span.riqi',
      titleSelector: 'a',
      titleFromAttribute: true,
      shortDateFormat: true,
    ),

    // --- 5.9 数理与统计学院 (模板A) ---
    'college_math': CollegeConfig(
      baseUrl: 'https://sltj.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.collegeMath,
      category: MessageCategory.collegeMathNews,
      listContainerSelector: 'div.m-xwzx-2 ul.list',
      listItemSelector: 'li.ui-preDot',
      dateSelector: 'span.time',
      titleSelector: 'a',
      titleFromAttribute: true,
    ),

    // --- 5.10 艺术与设计学院 (模板B: 图文卡片) ---
    'college_art': CollegeConfig(
      baseUrl: 'https://design.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeArt,
      category: MessageCategory.collegeArtNews,
      newsListContainerSelector: 'div.index_list2',
      newsListTitleSelector: 'div.list2_title',
      newsListDateSelector: 'div.list2_bottom span',
      newsListLinkSelector: 'a',
    ),

    // --- 5.11 职业技术教师教育学院 (模板D: 日期拼合) ---
    'college_vte': CollegeConfig(
      baseUrl: 'https://stes.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.collegeVte,
      category: MessageCategory.collegeVteNews,
      customItemSelector: 'div.m-tzgg a.item',
      customTitleSelector: 'div.tit',
      customDateSelector: 'div.time-2',
      customDateComposite: true,
      customDateYearMonthSelector: 'div.time-1',
    ),

    // --- 5.12 职业技术学院 (模板B) ---
    'college_vt': CollegeConfig(
      baseUrl: 'https://cive.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeVt,
      category: MessageCategory.collegeVtNews,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.news_title a',
      newsListDateSelector: 'div.news_meta',
      newsListLinkSelector: 'a',
    ),

    // --- 5.13 马克思主义学院 (模板A) ---
    'college_marx': CollegeConfig(
      baseUrl: 'https://mkszyxy.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.collegeMarx,
      category: MessageCategory.collegeMarxNews,
      listContainerSelector: 'ul.list',
      listItemSelector: 'li.ui-preDot',
      dateSelector: 'span.time',
      titleSelector: 'span.news_title a',
      titleFromAttribute: true,
    ),

    // --- 5.14 继续教育学院 (模板A，MM-DD短日期) ---
    'college_ce': CollegeConfig(
      baseUrl: 'https://adult.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.collegeCe,
      category: MessageCategory.collegeCeNews,
      listContainerSelector: 'ul.currency',
      listItemSelector: 'li',
      dateSelector: 'span',
      titleSelector: 'a',
      titleFromAttribute: true,
      shortDateFormat: true,
    ),

    // --- 5.15 艺术教育中心 (模板D) ---
    'center_art_edu': CollegeConfig(
      baseUrl: 'https://education.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.centerArtEdu,
      category: MessageCategory.centerArtEduNews,
      customItemSelector: 'div.focusImg_nax li',
      customTitleSelector: 'span.first a',
      customDateSelector: 'span.last',
      customDateSlashFormat: false,
    ),

    // --- 5.16 国际教育中心 (模板D，斜杠日期) ---
    'center_intl': CollegeConfig(
      baseUrl: 'https://sie.sspu.edu.cn',
      template: CollegeTemplate.customD,
      sourceName: MessageSourceName.centerIntl,
      category: MessageCategory.centerIntlNews,
      customItemSelector: 'div.m-news div.item',
      customTitleSelector: 'a.tit',
      customDateSelector: 'div.time',
      customDateSlashFormat: true,
    ),

    // --- 5.17 创新创业教育中心 (模板B) ---
    'center_innov': CollegeConfig(
      baseUrl: 'https://cxcy.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.centerInnov,
      category: MessageCategory.centerInnovNews,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.news_title a',
      newsListDateSelector: 'div.news_date',
      newsListLinkSelector: 'a',
    ),

    // --- 5.18 研究生处 (模板A) ---
    'graduate': CollegeConfig(
      baseUrl: 'https://yjs.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.graduate,
      category: MessageCategory.graduateNews,
      listContainerSelector: 'div.tyList ul',
      listItemSelector: 'li',
      dateSelector: 'span.riqi',
      titleSelector: 'a',
      titleFromAttribute: true,
    ),

    // --- 5.19 图书馆 (模板A，MM-DD短日期) ---
    'lib_center': CollegeConfig(
      baseUrl: 'https://library.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.libCenter,
      category: MessageCategory.libCenterNews,
      listContainerSelector: 'ul.list',
      listItemSelector: 'li.ui-preDot',
      dateSelector: 'span.time',
      titleSelector: 'a.text-overflow',
      shortDateFormat: true,
    ),
  };

  /// 根据 channelId 获取该学院/部门的首页新闻列表
  /// [channelId] 对应 channel_config.dart 中的 id（如 'college_cs'）
  Future<List<MessageItem>> fetchNews(
    String channelId, {
    Set<String>? knownMessageIds,
  }) async {
    if (channelId == 'college_cs') {
      return _fetchCollegeCsNews(knownMessageIds: knownMessageIds);
    }

    final config = configs[channelId];
    if (config == null) return [];

    try {
      final htmlText = await _http.fetchText(config.baseUrl);
      final document = html_parser.parse(htmlText);

      // 根据模板类型分派解析
      switch (config.template) {
        case CollegeTemplate.listA:
          return _parseListA(
            document,
            config,
            knownMessageIds: knownMessageIds,
          );
        case CollegeTemplate.newsListB:
          return _parseNewsListB(
            document,
            config,
            knownMessageIds: knownMessageIds,
          );
        case CollegeTemplate.swiperC:
          return _parseSwiperC(
            document,
            config,
            knownMessageIds: knownMessageIds,
          );
        case CollegeTemplate.customD:
          return _parseCustomD(
            document,
            config,
            knownMessageIds: knownMessageIds,
          );
      }
    } catch (_) {
      // 网络异常或解析失败，静默返回空列表
      return [];
    }
  }

  /// 计信学院使用多个子栏目拼成三个聚合分类。
  Future<List<MessageItem>> _fetchCollegeCsNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeCsCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeCsListPage(
          relativePath: relativePath,
          category: entry.key,
          knownMessageIds: seenIds,
        );
        for (final message in pageMessages) {
          if (seenIds.add(message.id)) {
            messages.add(message);
          }
        }
      }
    }

    messages.sort((a, b) {
      final left = a.timestamp ?? MessageItem.computeTimestamp(a.date);
      final right = b.timestamp ?? MessageItem.computeTimestamp(b.date);
      return right.compareTo(left);
    });

    return messages;
  }

  /// 抓取计信学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeCsListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://jxxy.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final items = document.querySelectorAll('li.ui-preDot');
      final messages = <MessageItem>[];

      for (final item in items) {
        final titleElement = item.querySelector('a.text-overflow');
        final dateElement = item.querySelector('span.time');
        if (titleElement == null || dateElement == null) continue;

        final href = titleElement.attributes['href'] ?? '';
        final title =
            titleElement.attributes['title']?.trim() ??
            titleElement.text.trim();
        if (href.isEmpty || title.isEmpty) continue;

        final fullUrl = _buildFullUrl(href, 'https://jxxy.sspu.edu.cn');
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        final date = normalizeDate(dateElement.text.trim());
        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.collegeCs,
            category: category,
            timestamp: MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (_) {
      return [];
    }
  }

  // ==================== 模板A: 标准列表解析 ====================

  /// 解析模板A: ul/div 列表内 li 项，包含日期 span + 标题 a
  List<MessageItem> _parseListA(
    Document document,
    CollegeConfig config, {
    Set<String>? knownMessageIds,
  }) {
    final container = document.querySelector(
      config.listContainerSelector ?? '',
    );
    if (container == null) return [];

    final items = container.querySelectorAll(config.listItemSelector ?? 'li');
    final messages = <MessageItem>[];

    for (final item in items) {
      // 提取标题和链接
      final titleEl = item.querySelector(config.titleSelector ?? 'a');
      if (titleEl == null) continue;

      final title = config.titleFromAttribute
          ? (titleEl.attributes['title']?.trim() ?? titleEl.text.trim())
          : titleEl.text.trim();

      final href = titleEl.attributes['href'] ?? '';
      if (title.isEmpty || href.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, config.baseUrl);
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      // 提取日期；选择器缺失时仍按当天消息兜底，避免信息中心日期空白。
      final dateEl = item.querySelector(config.dateSelector ?? 'span');
      final date = normalizeDate(dateEl?.text.trim() ?? '');

      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: config.sourceName,
          category: config.category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  }

  // ==================== 模板B: news_list 图文卡片解析 ====================

  /// 解析模板B: ul.news_list 内的 li.news 卡片
  List<MessageItem> _parseNewsListB(
    Document document,
    CollegeConfig config, {
    Set<String>? knownMessageIds,
  }) {
    final containerSelector =
        config.newsListContainerSelector ?? 'ul.news_list';
    final container = document.querySelector(containerSelector);
    if (container == null) return [];

    final items = container.querySelectorAll('li.news');
    // 如果没有 li.news，尝试用 div 子项（如艺术学院 div.index_list2_box）
    final actualItems = items.isNotEmpty
        ? items
        : container.children
              .where((e) => e.localName == 'div' || e.localName == 'li')
              .toList();

    final messages = <MessageItem>[];

    for (final item in actualItems) {
      // 提取链接
      String href = '';
      final linkEl = config.newsListLinkSelector != null
          ? item.querySelector(config.newsListLinkSelector!)
          : null;

      if (linkEl != null) {
        href = linkEl.attributes['href'] ?? '';
      }

      // 提取标题
      String title = '';
      final titleEl = config.newsListTitleSelector != null
          ? item.querySelector(config.newsListTitleSelector!)
          : null;

      if (titleEl != null) {
        // 优先取 title 属性，否则取文本
        title = titleEl.attributes['title']?.trim() ?? titleEl.text.trim();
        // 如果链接为空，尝试从标题元素获取
        if (href.isEmpty) {
          href = titleEl.attributes['href'] ?? '';
        }
      }

      if (title.isEmpty || href.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, config.baseUrl);
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      // 提取日期；部分官网模板当天条目可能只给时间或不给日期。
      String date = '';
      if (config.newsListDateSelector != null) {
        final dateEl = item.querySelector(config.newsListDateSelector!);
        date = dateEl?.text.trim() ?? '';
      }
      date = normalizeDate(date);

      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: config.sourceName,
          category: config.category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  }

  // ==================== 模板C: swiper 轮播解析 ====================

  /// 解析模板C: swiper-wrapper 内的 swiper-slide 卡片
  /// 智控学院特有：news_title(标题) + news_days(日) + news_years(YYYY.MM)
  List<MessageItem> _parseSwiperC(
    Document document,
    CollegeConfig config, {
    Set<String>? knownMessageIds,
  }) {
    final container = document.querySelector(
      config.swiperContainerSelector ?? 'div.swiper-wrapper',
    );
    if (container == null) return [];

    final slides = container.querySelectorAll('div.swiper-slide');
    final messages = <MessageItem>[];

    for (final slide in slides) {
      // 提取链接（slide 内第一个 a 标签）
      final anchor = slide.querySelector('a');
      final href = anchor?.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, config.baseUrl);
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      // 提取标题
      final titleEl = slide.querySelector('div.news_title');
      final title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) continue;

      // 拼合日期: news_days(DD) + news_years(YYYY.MM)
      final daysEl = slide.querySelector('div.news_days');
      final yearsEl = slide.querySelector('div.news_years');
      String date = '';
      if (daysEl != null && yearsEl != null) {
        final day = daysEl.text.trim().padLeft(2, '0');
        final yearMonth = yearsEl.text.trim().replaceAll('.', '-');
        date = '$yearMonth-$day';
      }
      date = normalizeDate(date);

      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: config.sourceName,
          category: config.category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  }

  // ==================== 模板D: 自定义结构解析 ====================

  /// 解析模板D: 各种非标准 HTML 结构
  /// 支持: imhe(a.btt-3), stes(a.item拼合日期), education(span.first+last), sie(div.item斜杠日期)
  List<MessageItem> _parseCustomD(
    Document document,
    CollegeConfig config, {
    Set<String>? knownMessageIds,
  }) {
    if (config.customItemSelector == null) return [];

    final items = document.querySelectorAll(config.customItemSelector!);
    final messages = <MessageItem>[];

    for (final item in items) {
      // 提取链接
      String href = '';
      if (config.customLinkSelector != null) {
        final linkEl = item.querySelector(config.customLinkSelector!);
        href = linkEl?.attributes['href'] ?? '';
      } else {
        // 项目本身就是 a 标签，或内部第一个 a
        href = item.attributes['href'] ?? '';
        if (href.isEmpty) {
          final innerA = item.querySelector('a');
          href = innerA?.attributes['href'] ?? '';
        }
      }
      if (href.isEmpty) continue;

      final fullUrl = _buildFullUrl(href, config.baseUrl);
      final messageId = _generateId(fullUrl);
      if (knownMessageIds?.contains(messageId) ?? false) break;

      // 提取标题
      String title = '';
      if (config.customTitleSelector != null) {
        final titleEl = item.querySelector(config.customTitleSelector!);
        if (titleEl != null) {
          // 优先 title 属性
          title = titleEl.attributes['title']?.trim() ?? titleEl.text.trim();
        }
      }
      if (title.isEmpty) continue;

      // 提取日期；解析失败时使用当天日期，保持 MessageItem.date 可展示。
      String date = '';
      if (config.customDateComposite &&
          config.customDateYearMonthSelector != null) {
        // 拼合模式: day(customDateSelector) + yearMonth(customDateYearMonthSelector)
        final dayEl = item.querySelector(config.customDateSelector ?? '');
        final ymEl = item.querySelector(config.customDateYearMonthSelector!);
        if (dayEl != null && ymEl != null) {
          final day = dayEl.text.trim().padLeft(2, '0');
          final yearMonth = ymEl.text.trim();
          date = '$yearMonth-$day';
        }
      } else if (config.customDateSelector != null) {
        final dateEl = item.querySelector(config.customDateSelector!);
        date = dateEl?.text.trim() ?? '';
      }
      date = normalizeDate(date);

      messages.add(
        MessageItem(
          id: messageId,
          title: title,
          date: date,
          url: fullUrl,
          sourceType: MessageSourceType.schoolWebsite,
          sourceName: config.sourceName,
          category: config.category,
          timestamp: MessageItem.computeTimestamp(date),
        ),
      );
    }

    return messages;
  }

  // ==================== 工具方法 ====================

  /// 构建完整 URL：相对路径拼接 baseUrl，绝对路径直接返回
  String _buildFullUrl(String href, String baseUrl) {
    if (href.startsWith('http')) return href;
    return '$baseUrl$href';
  }

  /// 基于 URL 生成稳定的消息唯一 ID（MD5 哈希）
  String _generateId(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}
