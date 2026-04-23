part of 'channel_config.dart';

// ==================== 微信渠道 ====================

/// 微信渠道配置列表
/// wechat_public 通过公众号平台获取已关注公众号的推文
const List<ChannelConfig> wechatChannels = [
  ChannelConfig(
    id: 'wechat_public',
    name: '微信公众号',
    description: '通过公众号平台获取已关注公众号的推文',
    icon: FluentIcons.chat,
    group: ChannelGroup.wechat,
    implemented: true,
    defaultInterval: 120,
    defaultEnabled: true,
  ),
  ChannelConfig(
    id: 'wechat_service',
    name: '微信服务号',
    description: '暂未接入',
    icon: FluentIcons.chat,
    group: ChannelGroup.wechat,
  ),
];
