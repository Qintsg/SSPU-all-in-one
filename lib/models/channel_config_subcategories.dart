part of 'channel_config.dart';

// ==================== 渠道子分类配置（tag3） ====================

/// 渠道子分类定义
/// 表示一个渠道下的具体内容分类（tag3），可独立启用/禁用
class SubCategory {
  /// 消息分类枚举值
  final MessageCategory category;

  /// 显示名称
  final String name;

  const SubCategory(this.category, this.name);
}

/// 渠道子分类映射 — 仅列出有多个子分类的渠道
/// 单分类渠道不需要子开关，渠道主开关即可控制
const Map<String, List<SubCategory>> channelSubcategories = {
  'college_cs': [
    SubCategory(MessageCategory.collegeCsNews, '工作动态'),
    SubCategory(MessageCategory.collegeCsTeacherWork, '教师工作'),
    SubCategory(MessageCategory.collegeCsStudentWork, '学生工作'),
  ],
  'college_im': [
    SubCategory(MessageCategory.collegeImNews, '学院动态'),
    SubCategory(MessageCategory.collegeImTeachingResearch, '教学科研'),
    SubCategory(MessageCategory.collegeImNotice, '通知公告'),
  ],
  'college_re': [
    SubCategory(MessageCategory.collegeReNews, '新闻资讯'),
    SubCategory(MessageCategory.collegeReNotice, '通知公告'),
    SubCategory(MessageCategory.collegeReResearchService, '科研与服务'),
    SubCategory(MessageCategory.collegeRePartyIdeology, '党建思政'),
  ],
  'college_em': [
    SubCategory(MessageCategory.collegeEmNews, '新闻资讯'),
    SubCategory(MessageCategory.collegeEmNotice, '通知与公告'),
    SubCategory(MessageCategory.collegeEmStudentDevelopment, '育人园地'),
    SubCategory(MessageCategory.collegeEmResearch, '科学研究'),
  ],
  'college_ic': [
    SubCategory(MessageCategory.collegeIcNews, '学院动态'),
    SubCategory(MessageCategory.collegeIcNotice, '通知公告'),
    SubCategory(MessageCategory.collegeIcAcademic, '学术活动'),
    SubCategory(MessageCategory.collegeIcResearch, '科研动态'),
  ],
  'college_imhe': [
    SubCategory(MessageCategory.collegeImheNews, '学院新闻'),
    SubCategory(MessageCategory.collegeImheNotice, '通知公告'),
  ],
  'college_econ': [
    SubCategory(MessageCategory.collegeEconNews, '学院动态'),
    SubCategory(MessageCategory.collegeEconNotice, '通知公告'),
    SubCategory(MessageCategory.collegeEconStudentDevelopment, '育人园地'),
    SubCategory(MessageCategory.collegeEconPartyLeadership, '党群引领'),
  ],
  'college_lang': [
    SubCategory(MessageCategory.collegeLangNews, '新闻动态'),
    SubCategory(MessageCategory.collegeLangNotice, '学院公告'),
    SubCategory(MessageCategory.collegeLangStudentActivities, '学生活动'),
    SubCategory(MessageCategory.collegeLangLecture, '讲座信息'),
  ],
  'college_math': [
    SubCategory(MessageCategory.collegeMathNews, '学院新闻'),
    SubCategory(MessageCategory.collegeMathNotice, '学院公告'),
    SubCategory(MessageCategory.collegeMathAcademic, '学术动态'),
    SubCategory(MessageCategory.collegeMathStudentDevelopment, '育人园地'),
  ],
  'college_vte': [
    SubCategory(MessageCategory.collegeVteNews, '新闻动态'),
    SubCategory(MessageCategory.collegeVteNotice, '通知公告'),
  ],
  'college_vt': [
    SubCategory(MessageCategory.collegeVtNews, '学院新闻'),
    SubCategory(MessageCategory.collegeVtNotice, '学院公告'),
  ],
  'college_marx': [
    SubCategory(MessageCategory.collegeMarxNews, '学院新闻'),
    SubCategory(MessageCategory.collegeMarxNotice, '通知公告'),
    SubCategory(MessageCategory.collegeMarxResearch, '学术科研'),
    SubCategory(MessageCategory.collegeMarxTeaching, '教育教学'),
  ],
  'college_ce': [
    SubCategory(MessageCategory.collegeCeNews, '学院新闻'),
    SubCategory(MessageCategory.collegeCeNotice, '学院公告'),
  ],
  'center_art_edu': [
    SubCategory(MessageCategory.centerArtEduNews, '新闻动态'),
    SubCategory(MessageCategory.centerArtEduLecture, '讲座演出'),
  ],
  'center_intl': [
    SubCategory(MessageCategory.centerIntlNews, '新闻'),
    SubCategory(MessageCategory.centerIntlNotice, '公告'),
  ],
  'center_innov': [
    SubCategory(MessageCategory.centerInnovNews, '双创教育'),
    SubCategory(MessageCategory.centerInnovNotice, '通知公告'),
    SubCategory(MessageCategory.centerInnovCompetition, '实践竞赛'),
    SubCategory(MessageCategory.centerInnovPractice, '创业实践'),
  ],
  'center_training': [
    SubCategory(MessageCategory.centerTrainingNews, '中心动态'),
    SubCategory(MessageCategory.centerTrainingNotice, '通知公告'),
  ],
  'lib_center': [
    SubCategory(MessageCategory.libCenterNews, '新闻动态'),
    SubCategory(MessageCategory.libCenterNotice, '通知公告'),
    SubCategory(MessageCategory.libCenterLecture, '讲座培训'),
  ],
  'logistics_center': [
    SubCategory(MessageCategory.logisticsNotice, '通知'),
    SubCategory(MessageCategory.logisticsNews, '新闻动态'),
  ],
  'foreign_student_office': [
    SubCategory(MessageCategory.foreignStudentNotice, '公告'),
    SubCategory(MessageCategory.foreignStudentNews, '新闻'),
  ],
  'intl_exchange_office': [
    SubCategory(MessageCategory.intlExchangeNews, '各项新闻'),
    SubCategory(MessageCategory.intlExchangeNotice, '通知公告'),
  ],
  'hr_office': [
    SubCategory(MessageCategory.hrNews, '新闻动态'),
    SubCategory(MessageCategory.hrRecruitment, '人才招聘'),
    SubCategory(MessageCategory.hrNotice, '通知公告'),
  ],
  'research_office': [
    SubCategory(MessageCategory.researchInfo, '科研信息'),
    SubCategory(MessageCategory.researchNotice, '科研公告'),
    SubCategory(MessageCategory.researchAchievement, '科研成果喜讯'),
  ],
  'union': [
    SubCategory(MessageCategory.unionNews, '工会动态'),
    SubCategory(MessageCategory.unionPartyLeadership, '党建引领'),
    SubCategory(MessageCategory.unionNotice, '公告通知'),
  ],
  'party_org_dept': [
    SubCategory(MessageCategory.partyOrgNews, '党建动态'),
    SubCategory(MessageCategory.partyOrgNotice, '通知公告'),
  ],
  'united_front_dept': [
    SubCategory(MessageCategory.unitedFrontNews, '工作动态'),
    SubCategory(MessageCategory.unitedFrontVoice, '党派之声'),
    SubCategory(MessageCategory.unitedFrontStyle, '团体风采'),
  ],
  'youth_league': [
    SubCategory(MessageCategory.youthLeagueHighlights, '工作要讯'),
    SubCategory(MessageCategory.youthLeagueNotice, '通知公告'),
    SubCategory(MessageCategory.youthLeagueGrassroots, '基层动态'),
  ],
  'assets_lab_office': [
    SubCategory(MessageCategory.assetsLabNews, '部门新闻'),
    SubCategory(MessageCategory.assetsLabNotice, '通知公告'),
  ],
  'jwc': [
    SubCategory(MessageCategory.jwcTeaching, '教学动态'),
    SubCategory(MessageCategory.jwcStudent, '学生专栏'),
    SubCategory(MessageCategory.jwcTeacher, '教师专栏'),
  ],
  'sports': [
    SubCategory(MessageCategory.sportsNotice, '通知公告'),
    SubCategory(MessageCategory.sportsEvent, '部门动态'),
  ],
  'security_dept': [
    SubCategory(MessageCategory.securityNews, '动态/通知'),
    SubCategory(MessageCategory.securityEducation, '宣教专栏'),
  ],
  'construction': [
    SubCategory(MessageCategory.constructionNews, '建设要闻'),
    SubCategory(MessageCategory.constructionNotice, '通知公告'),
  ],
  'student_affairs': [
    SubCategory(MessageCategory.studentNews, '学生新闻'),
    SubCategory(MessageCategory.studentNotice, '通知公告'),
  ],
};
