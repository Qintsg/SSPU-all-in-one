/*
 * 信息渠道配置模型 — 定义所有数据源渠道的元数据与分组
 * @Project : SSPU-all-in-one
 * @File : channel_config.dart
 * @Author : Qintsg
 * @Date : 2025-07-17
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 渠道分组类型
enum ChannelGroup {
  /// 职能部门
  department('职能部门'),

  /// 教学单位
  teaching('教学单位'),

  /// 微信（占位）
  wechat('微信');

  final String label;
  const ChannelGroup(this.label);
}

/// 信息渠道配置
/// 定义每个数据源渠道的标识、显示名称、描述、图标及实现状态
class ChannelConfig {
  /// 渠道唯一标识（用于存储键名，格式：snake_case）
  final String id;

  /// 渠道显示名称
  final String name;

  /// 渠道描述文本
  final String description;

  /// 渠道图标
  final IconData icon;

  /// 所属分组
  final ChannelGroup group;

  /// 是否已实现数据源抓取（未实现的显示"暂未接入"提示）
  final bool implemented;

  /// 默认刷新间隔（分钟，0 = 关闭自动刷新）
  final int defaultInterval;

  /// 默认启用状态
  final bool defaultEnabled;

  const ChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.group,
    this.implemented = false,
    this.defaultInterval = 0,
    this.defaultEnabled = false,
  });
}

// ==================== 职能部门渠道 ====================

/// 所有职能部门渠道配置列表
const List<ChannelConfig> departmentChannels = [
  ChannelConfig(
    id: 'latest_info',
    name: '最新公开信息',
    description: '信息公开网 — 学校新闻动态',
    icon: FluentIcons.news,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'notice',
    name: '通知公示',
    description: '信息公开网 — 通知公告与公示',
    icon: FluentIcons.megaphone,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'jwc',
    name: '教务处',
    description: '教务管理通知与公告',
    icon: FluentIcons.education,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'itc',
    name: '信息技术中心',
    description: '校园网与信息系统公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'sports',
    name: '体育部',
    description: '体育活动与赛事通知',
    icon: FluentIcons.globe,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'security_dept',
    name: '保卫处',
    description: '校园安全通知与公告',
    icon: FluentIcons.lock,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'construction',
    name: '校区建设办',
    description: '校区建设动态与公告',
    icon: FluentIcons.home,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'news_center',
    name: '新闻网',
    description: '学校新闻与宣传报道',
    icon: FluentIcons.news,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'student_affairs',
    name: '学生处',
    description: '学生管理与服务通知',
    icon: FluentIcons.mail,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'sspu_notice',
    name: '学校通知公告',
    description: '学校官网 — 通知公告',
    icon: FluentIcons.megaphone,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 60,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'sspu_activity',
    name: '学术活动讲座',
    description: '学校官网 — 学术活动与讲座预告',
    icon: FluentIcons.event,
    group: ChannelGroup.department,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
];

// ==================== 教学单位渠道 ====================

/// 所有教学单位渠道配置列表
const List<ChannelConfig> teachingChannels = [
  ChannelConfig(
    id: 'college_cs',
    name: '计算机与信息工程学院',
    description: '学院通知与公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_im',
    name: '智能制造与控制工程学院',
    description: '学院通知与公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_re',
    name: '资源与环境工程学院',
    description: '学院通知与公告',
    icon: FluentIcons.globe,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_em',
    name: '能源与材料学院',
    description: '学院通知与公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_ic',
    name: '集成电路学院',
    description: '学院通知与公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_imhe',
    name: '智能医学与健康工程学院',
    description: '学院通知与公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_econ',
    name: '经济与管理学院',
    description: '学院通知与公告',
    icon: FluentIcons.database,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_lang',
    name: '语言与文化传播学院',
    description: '学院通知与公告',
    icon: FluentIcons.read,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_math',
    name: '数理与统计学院',
    description: '学院通知与公告',
    icon: FluentIcons.education,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_art',
    name: '艺术与设计学院',
    description: '学院通知与公告',
    icon: FluentIcons.video,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_vte',
    name: '职业技术教师教育学院',
    description: '学院通知与公告',
    icon: FluentIcons.education,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_vt',
    name: '职业技术学院',
    description: '学院通知与公告',
    icon: FluentIcons.education,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_marx',
    name: '马克思主义学院',
    description: '学院通知与公告',
    icon: FluentIcons.library,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'college_ce',
    name: '继续教育学院',
    description: '学院通知与公告',
    icon: FluentIcons.education,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'center_art_edu',
    name: '艺术教育中心',
    description: '中心通知与公告',
    icon: FluentIcons.video,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'center_intl',
    name: '国际教育中心',
    description: '中心通知与公告',
    icon: FluentIcons.globe,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'center_innov',
    name: '创新创业教育中心',
    description: '中心通知与公告',
    icon: FluentIcons.settings,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'graduate',
    name: '研究生处',
    description: '研究生管理通知与公告',
    icon: FluentIcons.education,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'lib_center',
    name: '图书馆',
    description: '图书馆通知与服务公告',
    icon: FluentIcons.library,
    group: ChannelGroup.teaching,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
];

// ==================== 微信渠道 ====================

/// 微信渠道配置列表
/// wechat_public 通过微信读书 API 获取已关注的公众号推文
const List<ChannelConfig> wechatChannels = [
  ChannelConfig(
    id: 'wechat_public',
    name: '微信公众号',
    description: '通过微信读书获取已关注公众号的推文',
    icon: FluentIcons.chat,
    group: ChannelGroup.wechat,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: false,
  ),
  ChannelConfig(
    id: 'wechat_service',
    name: '微信服务号',
    description: '暂未接入',
    icon: FluentIcons.chat,
    group: ChannelGroup.wechat,
  ),
];
