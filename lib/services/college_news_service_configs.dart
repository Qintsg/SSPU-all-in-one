part of 'college_news_service.dart';

/// 智控学院的三个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeImCategoryPaths = {
  MessageCategory.collegeImNews: ['/4015/list.htm'],
  MessageCategory.collegeImTeachingResearch: ['/4016/list.htm'],
  MessageCategory.collegeImNotice: ['/4017/list.htm'],
};

/// 资环学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeReCategoryPaths = {
  MessageCategory.collegeReNews: ['/2229/list.htm'],
  MessageCategory.collegeReNotice: ['/2230/list.htm'],
  MessageCategory.collegeReResearchService: ['/2220/list.htm'],
  MessageCategory.collegeRePartyIdeology: ['/2221/list.htm'],
};

/// 能材学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeEmCategoryPaths = {
  MessageCategory.collegeEmNews: ['/155/list.htm'],
  MessageCategory.collegeEmNotice: ['/141/list.htm'],
  MessageCategory.collegeEmStudentDevelopment: ['/156/list.htm'],
  MessageCategory.collegeEmResearch: ['/5805/list.htm'],
};

/// 集成电路学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeIcCategoryPaths = {
  MessageCategory.collegeIcNews: ['/_s155/5962/list.psp'],
  MessageCategory.collegeIcNotice: ['/_s155/5963/list.psp'],
  MessageCategory.collegeIcAcademic: ['/_s155/xshd/list.psp'],
  MessageCategory.collegeIcResearch: ['/_s155/5982/list.psp'],
};

/// 智能医学与健康工程学院的两个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeImheCategoryPaths = {
  MessageCategory.collegeImheNews: ['/6006/list.htm'],
  MessageCategory.collegeImheNotice: ['/6007/list.htm'],
};

/// 经管学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeEconCategoryPaths = {
  MessageCategory.collegeEconNews: ['/_s33/1083/list.psp'],
  MessageCategory.collegeEconNotice: ['/_s33/1084/list.psp'],
  MessageCategory.collegeEconStudentDevelopment: ['/_s33/5205/list.psp'],
  MessageCategory.collegeEconPartyLeadership: ['/_s33/5204/list.psp'],
};

/// 文传学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeLangCategoryPaths = {
  MessageCategory.collegeLangNews: ['/527/list.htm'],
  MessageCategory.collegeLangNotice: ['/528/list.htm'],
  MessageCategory.collegeLangStudentActivities: ['/529/list.htm'],
  MessageCategory.collegeLangLecture: ['/jzxx/list.htm'],
};

/// 数统学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeMathCategoryPaths = {
  MessageCategory.collegeMathNews: ['/2604/list.htm'],
  MessageCategory.collegeMathNotice: ['/2605/list.htm'],
  MessageCategory.collegeMathAcademic: ['/xsdt2/list.htm'],
  MessageCategory.collegeMathStudentDevelopment: ['/2607/list.htm'],
};

/// 艺术与设计学院的聚合分类配置。
const Map<MessageCategory, List<String>> _collegeArtCategoryPaths = {
  MessageCategory.collegeArtNews: ['/2738/list.htm'],
};

/// 职师学院的两个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeVteCategoryPaths = {
  MessageCategory.collegeVteNews: ['/2903/list.htm'],
  MessageCategory.collegeVteNotice: ['/2930/list.htm'],
};

/// 职业技术学院的两个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeVtCategoryPaths = {
  MessageCategory.collegeVtNews: ['/585/list.htm'],
  MessageCategory.collegeVtNotice: ['/586/list.htm'],
};

/// 马克思主义学院的四个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeMarxCategoryPaths = {
  MessageCategory.collegeMarxNews: ['/250/list.htm'],
  MessageCategory.collegeMarxNotice: ['/251/list.htm'],
  MessageCategory.collegeMarxResearch: ['/252/list.htm'],
  MessageCategory.collegeMarxTeaching: ['/247/list.htm'],
};

/// 继续教育学院的两个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeCeCategoryPaths = {
  MessageCategory.collegeCeNews: ['/1687/list.htm'],
  MessageCategory.collegeCeNotice: ['/xygg/list.htm'],
};

/// 艺术教育中心的两个聚合分类配置。
const Map<MessageCategory, List<String>> _centerArtEduCategoryPaths = {
  MessageCategory.centerArtEduNews: ['/351/list.htm'],
  MessageCategory.centerArtEduLecture: ['/354/list.htm'],
};

/// 国教中心的两个聚合分类配置。
const Map<MessageCategory, List<String>> _centerIntlCategoryPaths = {
  MessageCategory.centerIntlNews: ['/5894/list.htm'],
  MessageCategory.centerIntlNotice: ['/649/list.htm'],
};

/// 创新创业教育中心的四个聚合分类配置。
const Map<MessageCategory, List<String>> _centerInnovCategoryPaths = {
  MessageCategory.centerInnovNews: ['/5744/list.htm'],
  MessageCategory.centerInnovNotice: ['/5749/list.htm'],
  MessageCategory.centerInnovCompetition: ['/5745/list.htm'],
  MessageCategory.centerInnovPractice: ['/5746/list.htm'],
};

/// 工程训练与创新教育中心的两个聚合分类配置。
const Map<MessageCategory, List<String>> _centerTrainingCategoryPaths = {
  MessageCategory.centerTrainingNews: ['/3840/list.htm'],
  MessageCategory.centerTrainingNotice: ['/3841/list.htm'],
};

/// 图书馆的三个聚合分类配置。
const Map<MessageCategory, List<String>> _libCenterCategoryPaths = {
  MessageCategory.libCenterNews: ['/2631/list.htm'],
  MessageCategory.libCenterNotice: ['/2632/list.htm'],
  MessageCategory.libCenterLecture: ['/2633/list.htm'],
};

/// 后勤服务中心的两个聚合分类配置。
const Map<MessageCategory, List<String>> _logisticsCenterCategoryPaths = {
  MessageCategory.logisticsNotice: ['/1996/list.htm'],
  MessageCategory.logisticsNews: ['/5690/list.htm'],
};

/// 外国留学生事务办公室的两个聚合分类配置。
const Map<MessageCategory, List<String>> _foreignStudentOfficeCategoryPaths = {
  MessageCategory.foreignStudentNotice: ['/749/list.htm'],
  MessageCategory.foreignStudentNews: ['/750/list.htm'],
};

/// 国际交流处的两个聚合分类配置。
const Map<MessageCategory, List<String>> _intlExchangeOfficeCategoryPaths = {
  MessageCategory.intlExchangeNews: ['/179/list.htm'],
  MessageCategory.intlExchangeNotice: ['/180/list.htm'],
};

/// 研究生处的聚合分类配置。
const Map<MessageCategory, List<String>> _graduateCategoryPaths = {
  MessageCategory.graduateNews: ['/2897/list.htm'],
};

/// 招生办的聚合分类配置。
const Map<MessageCategory, List<String>> _admissionsOfficeCategoryPaths = {
  MessageCategory.admissionsNews: ['/3076/list.htm'],
};

/// 人事处的三个聚合分类配置。
const Map<MessageCategory, List<String>> _hrOfficeCategoryPaths = {
  MessageCategory.hrNews: ['/5242/list.htm'],
  MessageCategory.hrRecruitment: ['/rczp/list.htm'],
  MessageCategory.hrNotice: ['/tzgg/list.htm'],
};

/// 科研处的三个聚合分类配置。
const Map<MessageCategory, List<String>> _researchOfficeCategoryPaths = {
  MessageCategory.researchInfo: ['/873/list.htm'],
  MessageCategory.researchNotice: ['/kygg/list.htm'],
  MessageCategory.researchAchievement: ['/kycgxx/list.htm'],
};

/// 校工会的三个聚合分类配置。
const Map<MessageCategory, List<String>> _unionCategoryPaths = {
  MessageCategory.unionNews: ['/475/list.htm'],
  MessageCategory.unionPartyLeadership: ['/djyl/list.htm'],
  MessageCategory.unionNotice: ['/469/list.htm'],
};

/// 党委组织部的两个聚合分类配置。
const Map<MessageCategory, List<String>> _partyOrgDeptCategoryPaths = {
  MessageCategory.partyOrgNews: ['/418/list.htm'],
  MessageCategory.partyOrgNotice: ['/419/list.htm'],
};

/// 党委统战部的三个聚合分类配置。
const Map<MessageCategory, List<String>> _unitedFrontDeptCategoryPaths = {
  MessageCategory.unitedFrontNews: ['/5301/list.htm'],
  MessageCategory.unitedFrontVoice: ['/5302/list.htm'],
  MessageCategory.unitedFrontStyle: ['/5303/list.htm'],
};

/// 党委办公室的聚合分类配置。
const Map<MessageCategory, List<String>> _partyOfficeCategoryPaths = {
  MessageCategory.partyOfficeNews: ['/2477/list.htm'],
};

/// 校团委的三个聚合分类配置。
const Map<MessageCategory, List<String>> _youthLeagueCategoryPaths = {
  MessageCategory.youthLeagueHighlights: ['/4570/list.htm'],
  MessageCategory.youthLeagueNotice: ['/4569/list.htm'],
  MessageCategory.youthLeagueGrassroots: ['/4571/list.htm'],
};

/// 资产与实验管理处的两个聚合分类配置。
const Map<MessageCategory, List<String>> _assetsLabOfficeCategoryPaths = {
  MessageCategory.assetsLabNews: ['/1320/list.htm'],
  MessageCategory.assetsLabNotice: ['/1321/list.htm'],
};

/// 计信学院的三个聚合分类配置。
const Map<MessageCategory, List<String>> _collegeCsCategoryPaths = {
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
const Map<String, CollegeConfig> configs = {
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
