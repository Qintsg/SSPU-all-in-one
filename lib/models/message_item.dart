/*
 * 消息数据模型 — 信息中心统一消息结构
 * 定义消息项、消息来源类型、来源名称和内容分类
 * @Project : SSPU-all-in-one
 * @File : message_item.dart
 * @Author : Qintsg
 * @Date : 2026-07-19
 */

/// 消息来源类型（tag1）
enum MessageSourceType {
  /// 学校官网
  schoolWebsite('学校官网'),

  /// 微信公众号
  wechatPublic('微信公众号'),

  /// 微信服务号
  wechatService('微信服务号');

  const MessageSourceType(this.label);

  /// 显示名称
  final String label;
}

/// 消息来源名称（tag2）
enum MessageSourceName {
  /// 信息公开网
  infoDisclosure('信息公开网'),

  /// 教务处
  jwc('教务处'),

  /// 信息技术中心
  itc('信息技术中心'),

  /// 学校官网（通知公告/学术活动）
  sspuOfficial('学校官网'),

  /// 体育部
  sports('体育部'),

  /// 保卫处
  securityDept('保卫处'),

  /// 基建处
  construction('基建处'),

  /// 新闻网
  newsCenter('新闻网'),

  /// 学生处
  studentAffairs('学生处'),

  /// 后勤服务中心
  logisticsCenter('后勤服务中心'),

  /// 外国留学生事务办公室
  foreignStudentOffice('外国留学生事务办公室'),

  /// 国际交流处
  intlExchangeOffice('国际交流处'),

  /// 招生办
  admissionsOffice('招生办'),

  /// 人事处
  hrOffice('人事处'),

  /// 科研处
  researchOffice('科研处'),

  /// 校工会
  union('校工会'),

  /// 党委组织部
  partyOrgDept('党委组织部'),

  /// 党委统战部
  unitedFrontDept('党委统战部'),

  /// 党委办公室
  partyOffice('党委办公室'),

  /// 校团委
  youthLeague('校团委'),

  /// 资产与实验管理处
  assetsLabOffice('资产与实验管理处'),

  /// 计算机与信息工程学院
  collegeCs('计算机与信息工程学院'),

  /// 智能制造与控制工程学院
  collegeIm('智能制造与控制工程学院'),

  /// 资源与环境工程学院
  collegeRe('资源与环境工程学院'),

  /// 能源与材料学院
  collegeEm('能源与材料学院'),

  /// 集成电路学院
  collegeIc('集成电路学院'),

  /// 智能医学与健康工程学院
  collegeImhe('智能医学与健康工程学院'),

  /// 经济与管理学院
  collegeEcon('经济与管理学院'),

  /// 语言与文化传播学院
  collegeLang('语言与文化传播学院'),

  /// 数理与统计学院
  collegeMath('数理与统计学院'),

  /// 艺术与设计学院
  collegeArt('艺术与设计学院'),

  /// 职业技术教师教育学院
  collegeVte('职业技术教师教育学院'),

  /// 职业技术学院
  collegeVt('职业技术学院'),

  /// 马克思主义学院
  collegeMarx('马克思主义学院'),

  /// 继续教育学院
  collegeCe('继续教育学院'),

  /// 艺术教育中心
  centerArtEdu('艺术教育中心'),

  /// 国际教育中心
  centerIntl('国际教育中心'),

  /// 创新创业教育中心
  centerInnov('创新创业教育中心'),

  /// 工程训练与创新教育中心
  centerTraining('工程训练与创新教育中心'),

  /// 研究生处
  graduate('研究生处'),

  /// 图书馆
  libCenter('图书馆'),

  /// 微信公众号占位
  wechatPublicPlaceholder('微信公众号'),

  /// 微信服务号占位
  wechatServicePlaceholder('微信服务号');

  const MessageSourceName(this.label);

  /// 显示名称
  final String label;
}

/// 消息内容分类（tag3）
enum MessageCategory {
  /// 公开信息 (3148，对应网站“最新公开信息”)
  latestInfo('公开信息'),

  /// 通知公示 (3149)
  notice('通知公示'),

  /// 教务处学生专栏 (897)
  jwcStudent('学生专栏'),

  /// 教务处教师专栏 (898)
  jwcTeacher('教师专栏'),

  /// 信息技术中心消息 (zxxx)
  itcNews('消息'),

  /// 教务处教学动态 (895)
  jwcTeaching('教学动态'),

  /// 学校官网学校新闻 (2964)
  sspuNews('学校新闻'),

  /// 学校官网通知公告 (2965)
  sspuNotice('学校通知公告'),

  /// 学校官网校内活动 (xsjz)
  sspuActivity('校内活动'),

  /// 体育部通知公告 (342)
  sportsNotice('通知公告'),

  /// 体育部部门动态 (343)
  sportsEvent('部门动态'),

  /// 保卫处动态/通知 (1019)
  securityNews('动态/通知'),

  /// 保卫处宣教专栏 (1023)
  securityEducation('宣教专栏'),

  /// 基建处建设要闻 (405)
  constructionNews('建设要闻'),

  /// 基建处通知公告 (406)
  constructionNotice('通知公告'),

  /// 新闻网综合新闻 (1432)
  campusNews('综合新闻'),

  /// 学生处学工要闻 (489)
  studentNews('学工要闻'),

  /// 学生处通知公告 (490)
  studentNotice('通知公告'),

  /// 后勤服务中心通知
  logisticsNotice('通知'),

  /// 后勤服务中心新闻动态
  logisticsNews('新闻动态'),

  /// 外国留学生事务办公室公告
  foreignStudentNotice('公告'),

  /// 外国留学生事务办公室新闻
  foreignStudentNews('新闻'),

  /// 国际交流处各项新闻
  intlExchangeNews('各项新闻'),

  /// 国际交流处通知公告
  intlExchangeNotice('通知公告'),

  /// 招生办招生动态
  admissionsNews('招生动态'),

  /// 人事处新闻动态
  hrNews('新闻动态'),

  /// 人事处人才招聘
  hrRecruitment('人才招聘'),

  /// 人事处通知公告
  hrNotice('通知公告'),

  /// 科研处科研信息
  researchInfo('科研信息'),

  /// 科研处科研公告
  researchNotice('科研公告'),

  /// 科研处科研成果喜讯
  researchAchievement('科研成果喜讯'),

  /// 校工会工会动态
  unionNews('工会动态'),

  /// 校工会党建引领
  unionPartyLeadership('党建引领'),

  /// 校工会公告通知
  unionNotice('公告通知'),

  /// 党委组织部党建动态
  partyOrgNews('党建动态'),

  /// 党委组织部通知公告
  partyOrgNotice('通知公告'),

  /// 党委统战部工作动态
  unitedFrontNews('工作动态'),

  /// 党委统战部党派之声
  unitedFrontVoice('党派之声'),

  /// 党委统战部团体风采
  unitedFrontStyle('团体风采'),

  /// 党委办公室工作动态
  partyOfficeNews('工作动态'),

  /// 校团委工作要讯
  youthLeagueHighlights('工作要讯'),

  /// 校团委通知公告
  youthLeagueNotice('通知公告'),

  /// 校团委基层动态
  youthLeagueGrassroots('基层动态'),

  /// 资产与实验管理处部门新闻
  assetsLabNews('部门新闻'),

  /// 资产与实验管理处通知公告
  assetsLabNotice('通知公告'),

  /// 计算机与信息工程学院工作动态
  collegeCsNews('工作动态'),

  /// 计算机与信息工程学院教师工作
  collegeCsTeacherWork('教师工作'),

  /// 计算机与信息工程学院学生工作
  collegeCsStudentWork('学生工作'),

  /// 智能制造与控制工程学院学院动态
  collegeImNews('学院动态'),

  /// 智能制造与控制工程学院教学科研
  collegeImTeachingResearch('教学科研'),

  /// 智能制造与控制工程学院通知公告
  collegeImNotice('通知公告'),

  /// 资源与环境工程学院新闻资讯
  collegeReNews('新闻资讯'),

  /// 资源与环境工程学院通知公告
  collegeReNotice('通知公告'),

  /// 资源与环境工程学院科研与服务
  collegeReResearchService('科研与服务'),

  /// 资源与环境工程学院党建思政
  collegeRePartyIdeology('党建思政'),

  /// 能源与材料学院新闻资讯
  collegeEmNews('新闻资讯'),

  /// 能源与材料学院通知与公告
  collegeEmNotice('通知与公告'),

  /// 能源与材料学院育人园地
  collegeEmStudentDevelopment('育人园地'),

  /// 能源与材料学院科学研究
  collegeEmResearch('科学研究'),

  /// 集成电路学院学院动态
  collegeIcNews('学院动态'),

  /// 集成电路学院通知公告
  collegeIcNotice('通知公告'),

  /// 集成电路学院学术活动
  collegeIcAcademic('学术活动'),

  /// 集成电路学院科研动态
  collegeIcResearch('科研动态'),

  /// 智能医学与健康工程学院学院新闻
  collegeImheNews('学院新闻'),

  /// 智能医学与健康工程学院通知公告
  collegeImheNotice('通知公告'),

  /// 经济与管理学院学院动态
  collegeEconNews('学院动态'),

  /// 经济与管理学院通知公告
  collegeEconNotice('通知公告'),

  /// 经济与管理学院育人园地
  collegeEconStudentDevelopment('育人园地'),

  /// 经济与管理学院党群引领
  collegeEconPartyLeadership('党群引领'),

  /// 语言与文化传播学院新闻动态
  collegeLangNews('新闻动态'),

  /// 语言与文化传播学院学院公告
  collegeLangNotice('学院公告'),

  /// 语言与文化传播学院学生活动
  collegeLangStudentActivities('学生活动'),

  /// 语言与文化传播学院讲座信息
  collegeLangLecture('讲座信息'),

  /// 数理与统计学院学院新闻
  collegeMathNews('学院新闻'),

  /// 数理与统计学院学院公告
  collegeMathNotice('学院公告'),

  /// 数理与统计学院学术动态
  collegeMathAcademic('学术动态'),

  /// 数理与统计学院育人园地
  collegeMathStudentDevelopment('育人园地'),

  /// 艺术与设计学院学院动态
  collegeArtNews('学院动态'),

  /// 职业技术教师教育学院新闻动态
  collegeVteNews('新闻动态'),

  /// 职业技术教师教育学院通知公告
  collegeVteNotice('通知公告'),

  /// 职业技术学院动态
  collegeVtNews('学院新闻'),

  /// 职业技术学院学院公告
  collegeVtNotice('学院公告'),

  /// 马克思主义学院动态
  collegeMarxNews('学院新闻'),

  /// 马克思主义学院通知公告
  collegeMarxNotice('通知公告'),

  /// 马克思主义学院学术科研
  collegeMarxResearch('学术科研'),

  /// 马克思主义学院教育教学
  collegeMarxTeaching('教育教学'),

  /// 继续教育学院动态
  collegeCeNews('学院新闻'),

  /// 继续教育学院学院公告
  collegeCeNotice('学院公告'),

  /// 艺术教育中心新闻动态
  centerArtEduNews('新闻动态'),

  /// 艺术教育中心讲座演出
  centerArtEduLecture('讲座演出'),

  /// 国际教育中心新闻
  centerIntlNews('新闻'),

  /// 国际教育中心公告
  centerIntlNotice('公告'),

  /// 创新创业教育中心双创教育
  centerInnovNews('双创教育'),

  /// 创新创业教育中心通知公告
  centerInnovNotice('通知公告'),

  /// 创新创业教育中心实践竞赛
  centerInnovCompetition('实践竞赛'),

  /// 创新创业教育中心创业实践
  centerInnovPractice('创业实践'),

  /// 工程训练与创新教育中心中心动态
  centerTrainingNews('中心动态'),

  /// 工程训练与创新教育中心通知公告
  centerTrainingNotice('通知公告'),

  /// 研究生处动态
  graduateNews('动态'),

  /// 图书馆新闻动态
  libCenterNews('新闻动态'),

  /// 图书馆通知公告
  libCenterNotice('通知公告'),

  /// 图书馆讲座培训
  libCenterLecture('讲座培训'),

  /// 微信推文占位
  wechatArticle('微信推文');

  const MessageCategory(this.label);

  /// 显示名称
  final String label;
}

/// 统一消息数据项
class MessageItem {
  /// 唯一标识（由来源URL的哈希生成，用于已读状态跟踪）
  final String id;

  /// 消息标题
  final String title;

  /// 消息发布日期（YYYY-MM-DD 格式）
  final String date;

  /// 跳转链接
  final String url;

  /// 来源类型（tag1）
  final MessageSourceType sourceType;

  /// 来源名称（tag2）
  final MessageSourceName sourceName;

  /// 内容分类（tag3）
  final MessageCategory category;

  /// 微信公众号 bookId（仅微信渠道有值，用于 per-account 通知控制）
  final String? mpBookId;

  /// 微信公众号名称（仅微信渠道有值，用于来源显示）
  final String? mpName;

  /// 精确时间戳（毫秒，可选；用于显示精确到分钟的时间）
  final int? timestamp;

  const MessageItem({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
    required this.sourceType,
    required this.sourceName,
    required this.category,
    this.mpBookId,
    this.mpName,
    this.timestamp,
  });

  /// 从 JSON 反序列化（兼容旧数据中无 mpBookId/mpName 的情况）
  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      url: json['url'] as String,
      sourceType: MessageSourceType.values.firstWhere(
        (sourceType) => sourceType.name == json['sourceType'],
      ),
      sourceName: MessageSourceName.values.firstWhere(
        (sourceName) => sourceName.name == json['sourceName'],
      ),
      category: MessageCategory.values.firstWhere(
        (category) => category.name == json['category'],
      ),
      mpBookId: json['mpBookId'] as String?,
      mpName: json['mpName'] as String?,
      timestamp: json['timestamp'] as int?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'url': url,
    'sourceType': sourceType.name,
    'sourceName': sourceName.name,
    'category': category.name,
    if (mpBookId != null) 'mpBookId': mpBookId,
    if (mpName != null) 'mpName': mpName,
    if (timestamp != null) 'timestamp': timestamp,
  };

  /// 根据日期字符串计算时间戳
  /// 当天消息返回当前时间，非当天消息返回该日 00:00
  static int computeTimestamp(String date) {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (date == today) {
      return now.millisecondsSinceEpoch;
    }
    try {
      return DateTime.parse(date).millisecondsSinceEpoch;
    } catch (_) {
      return now.millisecondsSinceEpoch;
    }
  }
}
