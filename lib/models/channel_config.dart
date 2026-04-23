/*
 * 信息渠道配置模型 — 定义所有数据源渠道的元数据与分组
 * @Project : SSPU-all-in-one
 * @File : channel_config.dart
 * @Author : Qintsg
 * @Date : 2025-04-17
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'message_item.dart';

part 'channel_config_department.dart';
part 'channel_config_teaching.dart';
part 'channel_config_wechat.dart';
part 'channel_config_subcategories.dart';

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
