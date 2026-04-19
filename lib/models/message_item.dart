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

  /// 校区建设办
  construction('校区建设办'),

  /// 新闻网
  newsCenter('新闻网'),

  /// 学生处
  studentAffairs('学生处'),

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
  /// 最新公开信息 (3148)
  latestInfo('最新公开信息'),

  /// 通知公示 (3149)
  notice('通知公示'),

  /// 教务处学生专栏 (897)
  jwcStudent('教务处学生专栏'),

  /// 教务处教师专栏 (898)
  jwcTeacher('教务处教师专栏'),

  /// 信息技术中心资讯 (zxxx)
  itcNews('信息技术中心'),

  /// 学校官网通知公告 (2965)
  sspuNotice('学校通知公告'),

  /// 学校官网学术活动讲座 (xsjz)
  sspuActivity('学术活动讲座'),

  /// 体育部通知公告 (342)
  sportsNotice('体育部通知'),

  /// 体育部赛事通知 (343)
  sportsEvent('体育赛事'),

  /// 保卫处平安动态 (1019)
  securityNews('平安动态'),

  /// 保卫处宣教专栏 (1023)
  securityEducation('安全宣教'),

  /// 校区建设办要闻 (405)
  constructionNews('建设要闻'),

  /// 校区建设办通知 (406)
  constructionNotice('建设通知'),

  /// 新闻网综合新闻 (1432)
  campusNews('综合新闻'),

  /// 学生处学工要闻 (489)
  studentNews('学工要闻'),

  /// 学生处通知公告 (490)
  studentNotice('学生通知'),

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

  const MessageItem({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
    required this.sourceType,
    required this.sourceName,
    required this.category,
  });

  /// 从 JSON 反序列化
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
      };
}
