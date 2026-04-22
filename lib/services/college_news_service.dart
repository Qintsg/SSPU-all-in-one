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
/// 通过 [CollegeConfig] 配置表驱动 20 个教学单位首页新闻抓取
class CollegeNewsService {
  CollegeNewsService._();

  static final CollegeNewsService instance = CollegeNewsService._();

  final HttpService _http = HttpService.instance;

  /// 智控学院的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeImCategoryPaths = {
    MessageCategory.collegeImNews: ['/4015/list.htm'],
    MessageCategory.collegeImTeachingResearch: ['/4016/list.htm'],
    MessageCategory.collegeImNotice: ['/4017/list.htm'],
  };

  /// 资环学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeReCategoryPaths = {
    MessageCategory.collegeReNews: ['/2229/list.htm'],
    MessageCategory.collegeReNotice: ['/2230/list.htm'],
    MessageCategory.collegeReResearchService: ['/2220/list.htm'],
    MessageCategory.collegeRePartyIdeology: ['/2221/list.htm'],
  };

  /// 能材学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeEmCategoryPaths = {
    MessageCategory.collegeEmNews: ['/155/list.htm'],
    MessageCategory.collegeEmNotice: ['/141/list.htm'],
    MessageCategory.collegeEmStudentDevelopment: ['/156/list.htm'],
    MessageCategory.collegeEmResearch: ['/5805/list.htm'],
  };

  /// 集成电路学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeIcCategoryPaths = {
    MessageCategory.collegeIcNews: ['/_s155/5962/list.psp'],
    MessageCategory.collegeIcNotice: ['/_s155/5963/list.psp'],
    MessageCategory.collegeIcAcademic: ['/_s155/xshd/list.psp'],
    MessageCategory.collegeIcResearch: ['/_s155/5982/list.psp'],
  };

  /// 智能医学与健康工程学院的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeImheCategoryPaths = {
    MessageCategory.collegeImheNews: ['/6006/list.htm'],
    MessageCategory.collegeImheNotice: ['/6007/list.htm'],
  };

  /// 经管学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeEconCategoryPaths = {
    MessageCategory.collegeEconNews: ['/_s33/1083/list.psp'],
    MessageCategory.collegeEconNotice: ['/_s33/1084/list.psp'],
    MessageCategory.collegeEconStudentDevelopment: ['/_s33/5205/list.psp'],
    MessageCategory.collegeEconPartyLeadership: ['/_s33/5204/list.psp'],
  };

  /// 文传学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeLangCategoryPaths = {
    MessageCategory.collegeLangNews: ['/527/list.htm'],
    MessageCategory.collegeLangNotice: ['/528/list.htm'],
    MessageCategory.collegeLangStudentActivities: ['/529/list.htm'],
    MessageCategory.collegeLangLecture: ['/jzxx/list.htm'],
  };

  /// 数统学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeMathCategoryPaths = {
    MessageCategory.collegeMathNews: ['/2604/list.htm'],
    MessageCategory.collegeMathNotice: ['/2605/list.htm'],
    MessageCategory.collegeMathAcademic: ['/xsdt2/list.htm'],
    MessageCategory.collegeMathStudentDevelopment: ['/2607/list.htm'],
  };

  /// 艺术与设计学院的聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeArtCategoryPaths = {
    MessageCategory.collegeArtNews: ['/2738/list.htm'],
  };

  /// 职师学院的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeVteCategoryPaths = {
    MessageCategory.collegeVteNews: ['/2903/list.htm'],
    MessageCategory.collegeVteNotice: ['/2930/list.htm'],
  };

  /// 职业技术学院的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeVtCategoryPaths = {
    MessageCategory.collegeVtNews: ['/585/list.htm'],
    MessageCategory.collegeVtNotice: ['/586/list.htm'],
  };

  /// 马克思主义学院的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeMarxCategoryPaths = {
    MessageCategory.collegeMarxNews: ['/250/list.htm'],
    MessageCategory.collegeMarxNotice: ['/251/list.htm'],
    MessageCategory.collegeMarxResearch: ['/252/list.htm'],
    MessageCategory.collegeMarxTeaching: ['/247/list.htm'],
  };

  /// 继续教育学院的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _collegeCeCategoryPaths = {
    MessageCategory.collegeCeNews: ['/1687/list.htm'],
    MessageCategory.collegeCeNotice: ['/xygg/list.htm'],
  };

  /// 艺术教育中心的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _centerArtEduCategoryPaths = {
    MessageCategory.centerArtEduNews: ['/351/list.htm'],
    MessageCategory.centerArtEduLecture: ['/354/list.htm'],
  };

  /// 国教中心的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _centerIntlCategoryPaths = {
    MessageCategory.centerIntlNews: ['/5894/list.htm'],
    MessageCategory.centerIntlNotice: ['/649/list.htm'],
  };

  /// 创新创业教育中心的四个聚合分类配置。
  static const Map<MessageCategory, List<String>> _centerInnovCategoryPaths = {
    MessageCategory.centerInnovNews: ['/5744/list.htm'],
    MessageCategory.centerInnovNotice: ['/5749/list.htm'],
    MessageCategory.centerInnovCompetition: ['/5745/list.htm'],
    MessageCategory.centerInnovPractice: ['/5746/list.htm'],
  };

  /// 工程训练与创新教育中心的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _centerTrainingCategoryPaths =
      {
        MessageCategory.centerTrainingNews: ['/3840/list.htm'],
        MessageCategory.centerTrainingNotice: ['/3841/list.htm'],
      };

  /// 图书馆的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _libCenterCategoryPaths = {
    MessageCategory.libCenterNews: ['/2631/list.htm'],
    MessageCategory.libCenterNotice: ['/2632/list.htm'],
    MessageCategory.libCenterLecture: ['/2633/list.htm'],
  };

  /// 后勤服务中心的两个聚合分类配置。
  static const Map<MessageCategory, List<String>>
  _logisticsCenterCategoryPaths = {
    MessageCategory.logisticsNotice: ['/1996/list.htm'],
    MessageCategory.logisticsNews: ['/5690/list.htm'],
  };

  /// 外国留学生事务办公室的两个聚合分类配置。
  static const Map<MessageCategory, List<String>>
  _foreignStudentOfficeCategoryPaths = {
    MessageCategory.foreignStudentNotice: ['/749/list.htm'],
    MessageCategory.foreignStudentNews: ['/750/list.htm'],
  };

  /// 国际交流处的两个聚合分类配置。
  static const Map<MessageCategory, List<String>>
  _intlExchangeOfficeCategoryPaths = {
    MessageCategory.intlExchangeNews: ['/179/list.htm'],
    MessageCategory.intlExchangeNotice: ['/180/list.htm'],
  };

  /// 研究生处的聚合分类配置。
  static const Map<MessageCategory, List<String>> _graduateCategoryPaths = {
    MessageCategory.graduateNews: ['/2897/list.htm'],
  };

  /// 招生办的聚合分类配置。
  static const Map<MessageCategory, List<String>>
  _admissionsOfficeCategoryPaths = {
    MessageCategory.admissionsNews: ['/3076/list.htm'],
  };

  /// 人事处的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _hrOfficeCategoryPaths = {
    MessageCategory.hrNews: ['/5242/list.htm'],
    MessageCategory.hrRecruitment: ['/rczp/list.htm'],
    MessageCategory.hrNotice: ['/tzgg/list.htm'],
  };

  /// 科研处的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _researchOfficeCategoryPaths =
      {
        MessageCategory.researchInfo: ['/873/list.htm'],
        MessageCategory.researchNotice: ['/kygg/list.htm'],
        MessageCategory.researchAchievement: ['/kycgxx/list.htm'],
      };

  /// 校工会的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _unionCategoryPaths = {
    MessageCategory.unionNews: ['/475/list.htm'],
    MessageCategory.unionPartyLeadership: ['/djyl/list.htm'],
    MessageCategory.unionNotice: ['/469/list.htm'],
  };

  /// 党委组织部的两个聚合分类配置。
  static const Map<MessageCategory, List<String>> _partyOrgDeptCategoryPaths = {
    MessageCategory.partyOrgNews: ['/418/list.htm'],
    MessageCategory.partyOrgNotice: ['/419/list.htm'],
  };

  /// 党委统战部的三个聚合分类配置。
  static const Map<MessageCategory, List<String>>
  _unitedFrontDeptCategoryPaths = {
    MessageCategory.unitedFrontNews: ['/5301/list.htm'],
    MessageCategory.unitedFrontVoice: ['/5302/list.htm'],
    MessageCategory.unitedFrontStyle: ['/5303/list.htm'],
  };

  /// 党委办公室的聚合分类配置。
  static const Map<MessageCategory, List<String>> _partyOfficeCategoryPaths = {
    MessageCategory.partyOfficeNews: ['/2477/list.htm'],
  };

  /// 校团委的三个聚合分类配置。
  static const Map<MessageCategory, List<String>> _youthLeagueCategoryPaths = {
    MessageCategory.youthLeagueHighlights: ['/4570/list.htm'],
    MessageCategory.youthLeagueNotice: ['/4569/list.htm'],
    MessageCategory.youthLeagueGrassroots: ['/4571/list.htm'],
  };

  /// 资产与实验管理处的两个聚合分类配置。
  static const Map<MessageCategory, List<String>>
  _assetsLabOfficeCategoryPaths = {
    MessageCategory.assetsLabNews: ['/1320/list.htm'],
    MessageCategory.assetsLabNotice: ['/1321/list.htm'],
  };

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
      newsListTitleSelector: 'span.news_title a',
      newsListDateSelector: 'span.news_meta',
      newsListLinkSelector: 'a',
    ),

    // --- 5.13 马克思主义学院 (模板A) ---
    'college_marx': CollegeConfig(
      baseUrl: 'https://mkszyxy.sspu.edu.cn',
      template: CollegeTemplate.newsListB,
      sourceName: MessageSourceName.collegeMarx,
      category: MessageCategory.collegeMarxNews,
      newsListContainerSelector: 'ul.news_list',
      newsListTitleSelector: 'div.item-right a',
      newsListDateSelector: 'div.item-time',
      newsListLinkSelector: 'div.item-right a',
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

    // --- 5.18 工程训练与创新教育中心 (模板A) ---
    'center_training': CollegeConfig(
      baseUrl: 'https://training.sspu.edu.cn',
      template: CollegeTemplate.listA,
      sourceName: MessageSourceName.centerTraining,
      category: MessageCategory.centerTrainingNews,
      listContainerSelector: 'div.content ul',
      listItemSelector: 'li',
      dateSelector: 'span.riqi',
      titleSelector: 'a',
      titleFromAttribute: true,
    ),

    // --- 5.19 研究生处 (模板A) ---
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

    // --- 5.20 图书馆 (模板A，MM-DD短日期) ---
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
    if (channelId == 'college_im') {
      return _fetchCollegeImNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_re') {
      return _fetchCollegeReNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_em') {
      return _fetchCollegeEmNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_ic') {
      return _fetchCollegeIcNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_imhe') {
      return _fetchCollegeImheNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_econ') {
      return _fetchCollegeEconNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_lang') {
      return _fetchCollegeLangNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_math') {
      return _fetchCollegeMathNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_art') {
      return _fetchCollegeArtNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_vte') {
      return _fetchCollegeVteNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_vt') {
      return _fetchCollegeVtNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_marx') {
      return _fetchCollegeMarxNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'college_ce') {
      return _fetchCollegeCeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'center_art_edu') {
      return _fetchCenterArtEduNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'center_intl') {
      return _fetchCenterIntlNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'center_innov') {
      return _fetchCenterInnovNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'center_training') {
      return _fetchCenterTrainingNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'logistics_center') {
      return _fetchLogisticsCenterNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'foreign_student_office') {
      return _fetchForeignStudentOfficeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'intl_exchange_office') {
      return _fetchIntlExchangeOfficeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'graduate') {
      return _fetchGraduateNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'lib_center') {
      return _fetchLibCenterNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'admissions_office') {
      return _fetchAdmissionsOfficeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'hr_office') {
      return _fetchHrOfficeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'research_office') {
      return _fetchResearchOfficeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'union') {
      return _fetchUnionNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'party_org_dept') {
      return _fetchPartyOrgDeptNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'united_front_dept') {
      return _fetchUnitedFrontDeptNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'party_office') {
      return _fetchPartyOfficeNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'youth_league') {
      return _fetchYouthLeagueNews(knownMessageIds: knownMessageIds);
    }
    if (channelId == 'assets_lab_office') {
      return _fetchAssetsLabOfficeNews(knownMessageIds: knownMessageIds);
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

  /// 智控学院使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchCollegeImNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeImCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeImListPage(
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

  /// 资环学院使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCollegeReNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeReCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeReListPage(
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

  /// 能材学院使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCollegeEmNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeEmCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeEmListPage(
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

  /// 经管学院使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCollegeEconNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeEconCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeEconListPage(
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

  /// 文传学院使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCollegeLangNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeLangCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeLangListPage(
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

  /// 数统学院使用四个列表页聚合成四个分类，并进入文章页读取精确时间。
  Future<List<MessageItem>> _fetchCollegeMathNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeMathCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeMathListPage(
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

  /// 职师学院使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCollegeVteNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeVteCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeVteListPage(
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

  /// 国教中心使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCenterIntlNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _centerIntlCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCenterIntlListPage(
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

  /// 继续教育学院使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCollegeCeNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeCeCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeCeListPage(
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

  /// 职业技术学院使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCollegeVtNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeVtCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeVtListPage(
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

  /// 马克思主义学院使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCollegeMarxNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _collegeMarxCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCollegeMarxListPage(
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

  /// 工程训练与创新教育中心使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCenterTrainingNews({
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in _centerTrainingCategoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await _fetchCenterTrainingListPage(
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

  /// 集成电路学院使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCollegeIcNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _collegeIcCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://sic.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.collegeIc,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 智能医学与健康工程学院使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCollegeImheNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _collegeImheCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://imhe.sspu.edu.cn',
          template: CollegeTemplate.customD,
          sourceName: MessageSourceName.collegeImhe,
          category: category,
          customItemSelector: 'a.btt-3',
          customTitleSelector: 'div.btt-4',
          customDateSelector: 'div.time-1',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 艺术与设计学院使用指定列表页聚合成学院动态分类。
  Future<List<MessageItem>> _fetchCollegeArtNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _collegeArtCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://design.sspu.edu.cn',
          template: CollegeTemplate.customD,
          sourceName: MessageSourceName.collegeArt,
          category: category,
          customItemSelector: 'div.xydt_list2_box',
          customTitleSelector: 'div.xydt_list2_title',
          customDateSelector: 'div.xydt_list2_bottom span',
          customLinkSelector: 'div.xydt_list2_con > a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 艺术教育中心使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchCenterArtEduNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _centerArtEduCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://education.sspu.edu.cn',
          template: CollegeTemplate.customD,
          sourceName: MessageSourceName.centerArtEdu,
          category: category,
          customItemSelector: 'div.ListContent ul li',
          customTitleSelector: 'span.first',
          customDateSelector: 'span.last',
          customLinkSelector: 'a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 创新创业教育中心使用四个列表页聚合成四个分类。
  Future<List<MessageItem>> _fetchCenterInnovNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _centerInnovCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://cxcy.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.centerInnov,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 图书馆使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchLibCenterNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _libCenterCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://library.sspu.edu.cn',
          template: CollegeTemplate.listA,
          sourceName: MessageSourceName.libCenter,
          category: category,
          listContainerSelector: 'div.newslists ul',
          listItemSelector: 'li.news.clearfix',
          dateSelector: 'span.nowdate',
          titleSelector: 'a[title]',
          titleFromAttribute: true,
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 后勤服务中心使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchLogisticsCenterNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _logisticsCenterCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://hqgl.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.logisticsCenter,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 外国留学生事务办公室使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchForeignStudentOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _foreignStudentOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://lxs.sspu.edu.cn',
          template: CollegeTemplate.customD,
          sourceName: MessageSourceName.foreignStudentOffice,
          category: category,
          customItemSelector: 'div.list-1 a.item',
          customTitleSelector: 'p.item-tit',
          customDateSelector: 'div.item-time',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 国际交流处使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchIntlExchangeOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _intlExchangeOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://gjjlc.sspu.edu.cn',
          template: CollegeTemplate.customD,
          sourceName: MessageSourceName.intlExchangeOffice,
          category: category,
          customItemSelector: 'div.rightlist ul li',
          customTitleSelector: 'a',
          customDateSelector: 'span',
          customLinkSelector: 'a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 研究生处使用指定列表页聚合成动态分类。
  Future<List<MessageItem>> _fetchGraduateNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _graduateCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://yjs.sspu.edu.cn',
          template: CollegeTemplate.listA,
          sourceName: MessageSourceName.graduate,
          category: category,
          listContainerSelector: 'div.tyList ul',
          listItemSelector: 'li',
          dateSelector: 'span.riqi',
          titleSelector: 'a',
          titleFromAttribute: true,
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 招生办使用指定列表页聚合成招生动态分类。
  Future<List<MessageItem>> _fetchAdmissionsOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _admissionsOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://zsb.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.admissionsOffice,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 人事处使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchHrOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _hrOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://hr.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.hrOffice,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 科研处使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchResearchOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _researchOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://kyc.sspu.edu.cn',
          template: CollegeTemplate.listA,
          sourceName: MessageSourceName.researchOffice,
          category: category,
          listContainerSelector: 'div.rightlist ul',
          listItemSelector: 'li',
          dateSelector: 'span',
          titleSelector: 'a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 校工会使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchUnionNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _unionCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://gh.sspu.edu.cn',
          template: CollegeTemplate.customD,
          sourceName: MessageSourceName.union,
          category: category,
          customItemSelector: 'div.jzlb.clearfix',
          customTitleSelector: 'div.btt3 a',
          customDateSelector: 'div.fbsj4',
          customLinkSelector: 'div.btt3 a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 党委组织部使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchPartyOrgDeptNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _partyOrgDeptCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://zzb.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.partyOrgDept,
          category: category,
          newsListContainerSelector: 'ul.news_list',
          newsListTitleSelector: 'div.item-right a',
          newsListDateSelector: 'div.item-time',
          newsListLinkSelector: 'div.item-right a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 党委统战部使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchUnitedFrontDeptNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _unitedFrontDeptCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://tzb.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.unitedFrontDept,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 党委办公室使用指定列表页聚合成工作动态分类。
  Future<List<MessageItem>> _fetchPartyOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _partyOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://db.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.partyOffice,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 校团委使用三个列表页聚合成三个分类。
  Future<List<MessageItem>> _fetchYouthLeagueNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _youthLeagueCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://tuanwei.sspu.edu.cn',
          template: CollegeTemplate.newsListB,
          sourceName: MessageSourceName.youthLeague,
          category: category,
          newsListContainerSelector: 'ul.news_list.list2',
          newsListTitleSelector: 'span.news_title a',
          newsListDateSelector: 'span.news_meta',
          newsListLinkSelector: 'span.news_title a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 资产与实验管理处使用两个列表页聚合成两个分类。
  Future<List<MessageItem>> _fetchAssetsLabOfficeNews({
    Set<String>? knownMessageIds,
  }) async {
    return _fetchMergedCategoryPages(
      _assetsLabOfficeCategoryPaths,
      (relativePath, category, ids) => _fetchConfiguredListPage(
        relativePath: relativePath,
        config: CollegeConfig(
          baseUrl: 'https://zc.sspu.edu.cn',
          template: CollegeTemplate.listA,
          sourceName: MessageSourceName.assetsLabOffice,
          category: category,
          listContainerSelector: 'div.listbody div.list_news ul',
          listItemSelector: 'li',
          dateSelector: 'span',
          titleSelector: 'a',
        ),
        knownMessageIds: ids,
      ),
      knownMessageIds: knownMessageIds,
    );
  }

  /// 通用的多分类聚合抓取逻辑。
  Future<List<MessageItem>> _fetchMergedCategoryPages(
    Map<MessageCategory, List<String>> categoryPaths,
    Future<List<MessageItem>> Function(
      String relativePath,
      MessageCategory category,
      Set<String> knownMessageIds,
    )
    fetchPage, {
    Set<String>? knownMessageIds,
  }) async {
    final messages = <MessageItem>[];
    final seenIds = <String>{...?(knownMessageIds)};

    for (final entry in categoryPaths.entries) {
      for (final relativePath in entry.value) {
        final pageMessages = await fetchPage(relativePath, entry.key, seenIds);
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

  /// 使用临时配置抓取指定列表页，复用现有模板解析逻辑。
  Future<List<MessageItem>> _fetchConfiguredListPage({
    required String relativePath,
    required CollegeConfig config,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText('${config.baseUrl}$relativePath');
      final document = html_parser.parse(htmlText);

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
      return [];
    }
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

  /// 抓取智控学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeImListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://imce.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final items = document.querySelectorAll('div.jzlb');
      final messages = <MessageItem>[];

      for (final item in items) {
        final titleElement = item.querySelector('div.xysbt a');
        final dateElement = item.querySelector('div.xyssj');
        if (titleElement == null || dateElement == null) continue;

        final href = titleElement.attributes['href'] ?? '';
        final title =
            titleElement.attributes['title']?.trim() ??
            titleElement.text.trim();
        if (href.isEmpty || title.isEmpty) continue;

        final fullUrl = _buildFullUrl(href, 'https://imce.sspu.edu.cn');
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
            sourceName: MessageSourceName.collegeIm,
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

  /// 抓取资环学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeReListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://zihuan.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final items = document.querySelectorAll('div.listbody ul li');
      final messages = <MessageItem>[];

      for (final item in items) {
        final titleElement = item.querySelector('a');
        final dateElement = item.querySelector('span');
        if (titleElement == null || dateElement == null) continue;

        final href = titleElement.attributes['href'] ?? '';
        final title =
            titleElement.attributes['title']?.trim() ??
            titleElement.text.trim();
        if (href.isEmpty || title.isEmpty) continue;

        final fullUrl = _buildFullUrl(href, 'https://zihuan.sspu.edu.cn');
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
            sourceName: MessageSourceName.collegeRe,
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

  /// 抓取能材学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeEmListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://sem.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://sem.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.collegeEm,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      );

      return _parseNewsListB(
        document,
        config,
        knownMessageIds: knownMessageIds,
      );
    } catch (_) {
      return [];
    }
  }

  /// 抓取经管学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeEconListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://jjglxy.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://jjglxy.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.collegeEcon,
        category: category,
        newsListContainerSelector: 'ul.news_list.list2',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'span.news_title a',
      );

      return _parseNewsListB(
        document,
        config,
        knownMessageIds: knownMessageIds,
      );
    } catch (_) {
      return [];
    }
  }

  /// 抓取文传学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeLangListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://wywh.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final items = document.querySelectorAll('div.right_list ul li');
      final messages = <MessageItem>[];

      for (final item in items) {
        final dateElement = item.querySelector('span');
        if (dateElement == null) continue;

        Element? titleElement;
        for (final link in item.querySelectorAll('a')) {
          final href = link.attributes['href'] ?? '';
          final title = link.attributes['title']?.trim() ?? link.text.trim();
          if (href.isNotEmpty && title.isNotEmpty) {
            titleElement = link;
            break;
          }
        }
        if (titleElement == null) continue;

        final href = titleElement.attributes['href'] ?? '';
        final title =
            titleElement.attributes['title']?.trim() ??
            titleElement.text.trim();
        if (href.isEmpty || title.isEmpty) continue;

        final fullUrl = _buildFullUrl(href, 'https://wywh.sspu.edu.cn');
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
            sourceName: MessageSourceName.collegeLang,
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

  /// 抓取数统学院某个子栏目列表页，并进入文章页补齐精确发布时间。
  Future<List<MessageItem>> _fetchCollegeMathListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://sltj.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final items = document.querySelectorAll('div.listbody ul li');
      final messages = <MessageItem>[];

      for (final item in items) {
        final dateElement = item.querySelector('span');
        if (dateElement == null) continue;

        Element? titleElement;
        for (final link in item.querySelectorAll('a')) {
          final href = link.attributes['href'] ?? '';
          final rawTitle = link.attributes['title']?.trim() ?? '';
          final title = rawTitle.isNotEmpty ? rawTitle : link.text.trim();
          if (href.isEmpty || title.isEmpty) continue;
          if (rawTitle.contains('<') || rawTitle.contains('href=')) continue;
          titleElement = link;
          break;
        }
        if (titleElement == null) continue;

        final href = titleElement.attributes['href'] ?? '';
        final title =
            titleElement.attributes['title']?.trim() ??
            titleElement.text.trim();
        if (href.isEmpty || title.isEmpty) continue;

        final fullUrl = _buildFullUrl(href, 'https://sltj.sspu.edu.cn');
        final messageId = _generateId(fullUrl);
        if (knownMessageIds?.contains(messageId) ?? false) break;

        final fallbackDate = normalizeDate(dateElement.text.trim());
        final publishTime = await _fetchCollegeMathPublishTime(fullUrl);
        final date = publishTime?.date ?? fallbackDate;

        messages.add(
          MessageItem(
            id: messageId,
            title: title,
            date: date,
            url: fullUrl,
            sourceType: MessageSourceType.schoolWebsite,
            sourceName: MessageSourceName.collegeMath,
            category: category,
            timestamp:
                publishTime?.timestamp ?? MessageItem.computeTimestamp(date),
          ),
        );
      }

      return messages;
    } catch (_) {
      return [];
    }
  }

  /// 抓取职师学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeVteListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://stes.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://stes.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.collegeVte,
        category: category,
        customItemSelector: 'div.list-1 a.item',
        customTitleSelector: 'div.tit',
        customDateSelector: 'div.time-2',
        customDateComposite: true,
        customDateYearMonthSelector: 'div.time-1',
      );

      return _parseCustomD(document, config, knownMessageIds: knownMessageIds);
    } catch (_) {
      return [];
    }
  }

  /// 抓取国教中心某个子栏目列表页。
  Future<List<MessageItem>> _fetchCenterIntlListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://sie.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://sie.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.centerIntl,
        category: category,
        customItemSelector: 'div.list-1 a.item',
        customTitleSelector: 'p.item-tit',
        customDateSelector: 'div.item-time',
      );

      return _parseCustomD(document, config, knownMessageIds: knownMessageIds);
    } catch (_) {
      return [];
    }
  }

  /// 抓取继续教育学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeCeListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://adult.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://adult.sspu.edu.cn',
        template: CollegeTemplate.customD,
        sourceName: MessageSourceName.collegeCe,
        category: category,
        customItemSelector: 'div.ListContent li',
        customTitleSelector: 'span.first',
        customDateSelector: 'span.last',
        customLinkSelector: 'a',
      );

      return _parseCustomD(document, config, knownMessageIds: knownMessageIds);
    } catch (_) {
      return [];
    }
  }

  /// 抓取职业技术学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeVtListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://cive.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://cive.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.collegeVt,
        category: category,
        newsListContainerSelector: 'ul.news_list',
        newsListTitleSelector: 'span.news_title a',
        newsListDateSelector: 'span.news_meta',
        newsListLinkSelector: 'a',
      );

      return _parseNewsListB(
        document,
        config,
        knownMessageIds: knownMessageIds,
      );
    } catch (_) {
      return [];
    }
  }

  /// 抓取马克思主义学院某个子栏目列表页。
  Future<List<MessageItem>> _fetchCollegeMarxListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://mkszyxy.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://mkszyxy.sspu.edu.cn',
        template: CollegeTemplate.newsListB,
        sourceName: MessageSourceName.collegeMarx,
        category: category,
        newsListContainerSelector: 'ul.news_list',
        newsListTitleSelector: 'div.item-right a',
        newsListDateSelector: 'div.item-time',
        newsListLinkSelector: 'div.item-right a',
      );

      return _parseNewsListB(
        document,
        config,
        knownMessageIds: knownMessageIds,
      );
    } catch (_) {
      return [];
    }
  }

  /// 抓取工程训练与创新教育中心某个子栏目列表页。
  Future<List<MessageItem>> _fetchCenterTrainingListPage({
    required String relativePath,
    required MessageCategory category,
    Set<String>? knownMessageIds,
  }) async {
    try {
      final htmlText = await _http.fetchText(
        'https://training.sspu.edu.cn$relativePath',
      );
      final document = html_parser.parse(htmlText);
      final config = CollegeConfig(
        baseUrl: 'https://training.sspu.edu.cn',
        template: CollegeTemplate.listA,
        sourceName: MessageSourceName.centerTraining,
        category: category,
        listContainerSelector: 'div.content ul',
        listItemSelector: 'li',
        dateSelector: 'span.riqi',
        titleSelector: 'a',
        titleFromAttribute: true,
      );

      return _parseListA(document, config, knownMessageIds: knownMessageIds);
    } catch (_) {
      return [];
    }
  }

  /// 从数统学院文章页提取精确发布时间。
  /// 优先解析常规正文时间节点，失败后回退到微信样式页面中的 create_time。
  Future<_CollegeArticlePublishTime?> _fetchCollegeMathPublishTime(
    String articleUrl,
  ) async {
    try {
      final htmlText = await _http.fetchText(articleUrl);
      final document = html_parser.parse(htmlText);

      for (final selector in const ['.arti_update', '.time']) {
        final timeText = document.querySelector(selector)?.text ?? '';
        final match = RegExp(
          r'(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}:\d{2}))?',
        ).firstMatch(timeText);
        if (match == null) continue;

        final date = normalizeDate(match.group(1) ?? '');
        final time = match.group(2);
        final timestamp = time == null
            ? MessageItem.computeTimestamp(date)
            : DateTime.parse('$date $time').millisecondsSinceEpoch;
        return _CollegeArticlePublishTime(date: date, timestamp: timestamp);
      }

      final timestampMatch = RegExp(
        "(?:create_time|oriCreateTime|ct)\\s*[:=]\\s*['\\\"]?(\\d{10,13})",
      ).firstMatch(htmlText);
      if (timestampMatch != null) {
        final rawTimestamp = int.tryParse(timestampMatch.group(1) ?? '');
        if (rawTimestamp != null && rawTimestamp > 0) {
          final timestamp = rawTimestamp < 10000000000
              ? rawTimestamp * 1000
              : rawTimestamp;
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final date = normalizeDate(
            '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
          );
          return _CollegeArticlePublishTime(date: date, timestamp: timestamp);
        }
      }

      return null;
    } catch (_) {
      return null;
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

/// 文章页发布时间解析结果。
class _CollegeArticlePublishTime {
  final String date;
  final int timestamp;

  const _CollegeArticlePublishTime({
    required this.date,
    required this.timestamp,
  });
}
