/*
 * 渠道列表组件 — 在设置页中直接展示渠道开关与刷新配置
 * @Project : SSPU-all-in-one
 * @File : channel_list_section.dart
 * @Author : Qintsg
 * @Date : 2025-07-17
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../models/channel_config.dart';
import '../models/message_item.dart';
import '../services/auto_refresh_service.dart';
import '../services/message_state_service.dart';
import 'settings_widgets.dart';

/// 渠道列表组件
/// 展示一组渠道的启用/禁用开关、刷新间隔与子分类开关
/// 同时支持已实现和未实现（占位）的渠道
class ChannelListSection extends StatefulWidget {
  /// 分组标题
  final String title;

  /// 分组内的渠道配置列表
  final List<ChannelConfig> channels;

  const ChannelListSection({
    super.key,
    required this.title,
    required this.channels,
  });

  @override
  State<ChannelListSection> createState() => _ChannelListSectionState();
}

class _ChannelListSectionState extends State<ChannelListSection> {
  /// 消息状态服务
  final MessageStateService _messageState = MessageStateService.instance;

  /// 自动刷新服务
  final AutoRefreshService _autoRefresh = AutoRefreshService.instance;

  /// 各渠道启用状态缓存（channelId → enabled）
  final Map<String, bool> _enabledMap = {};

  /// 各渠道刷新间隔缓存（channelId → minutes）
  final Map<String, int> _intervalMap = {};

  /// 各子分类启用状态缓存（categoryName → enabled）
  final Map<String, bool> _categoryEnabledMap = {};

  /// 是否正在加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannelStates();
  }

  /// 从存储中加载所有渠道的启用状态、刷新间隔和子分类开关
  Future<void> _loadChannelStates() async {
    for (final channel in widget.channels) {
      _enabledMap[channel.id] = await _messageState.isChannelEnabled(
        channel.id,
        defaultValue: channel.defaultEnabled,
      );
      _intervalMap[channel.id] = await _messageState.getChannelInterval(
        channel.id,
        defaultValue: channel.defaultInterval,
      );
    }

    for (final channel in widget.channels) {
      final subcategories = channelSubcategories[channel.id];
      if (subcategories == null) continue;

      for (final subcategory in subcategories) {
        _categoryEnabledMap[subcategory.category.name] = await _messageState
            .isCategoryEnabled(subcategory.category.name);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    return _buildListPage(context);
  }

  /// 构建渠道列表页
  Widget _buildListPage(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: theme.typography.subtitle),
        const SizedBox(height: 4),
        Text(
          '共 ${widget.channels.length} 个渠道，'
          '已启用 ${_enabledMap.values.where((enabled) => enabled).length} 个',
          style: theme.typography.caption,
        ),
        const SizedBox(height: 16),
        ...widget.channels.map((channel) => _buildChannelRow(context, channel)),
      ],
    );
  }

  /// 构建单个渠道行 — 图标、名称、描述、开关、刷新间隔与子分类开关
  Widget _buildChannelRow(BuildContext context, ChannelConfig channel) {
    final theme = FluentTheme.of(context);
    final enabled = _enabledMap[channel.id] ?? false;
    final interval = _intervalMap[channel.id] ?? 0;
    final subtitle = channel.implemented
        ? channel.description
        : '${channel.description}（暂未接入）';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.inactiveColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(channel.icon, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(channel.name, style: theme.typography.bodyStrong),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.typography.caption),
                    ],
                  ),
                ),
                ToggleSwitch(
                  checked: enabled,
                  onChanged: (value) => _onChannelToggled(channel, value),
                ),
              ],
            ),
            if (channel.implemented) ...[
              const SizedBox(height: 8),
              buildIntervalSelector(
                context: context,
                currentValue: interval,
                enabled: enabled,
                onChanged: (minutes) => _onIntervalChanged(channel, minutes),
              ),
              if (channelSubcategories.containsKey(channel.id)) ...[
                const SizedBox(height: 10),
                _buildSubcategoryToggles(context, channel),
              ],
            ],
            if (!channel.implemented) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  '此渠道数据源尚未接入，启用开关仅作预配置用途',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建子分类开关区域
  /// 显示渠道下所有子分类的独立开关
  Widget _buildSubcategoryToggles(BuildContext context, ChannelConfig channel) {
    final theme = FluentTheme.of(context);
    final subcategories = channelSubcategories[channel.id]!;
    final channelEnabled = _enabledMap[channel.id] ?? false;

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('内容分类', style: theme.typography.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: subcategories.map((subcategory) {
              final categoryEnabled =
                  _categoryEnabledMap[subcategory.category.name] ?? true;
              return SizedBox(
                width: 180,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        subcategory.name,
                        style: theme.typography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ToggleSwitch(
                      checked: categoryEnabled,
                      // 渠道关闭时保留配置展示，但禁止修改子分类以避免状态误判。
                      onChanged: channelEnabled
                          ? (value) =>
                                _onCategoryToggled(subcategory.category, value)
                          : null,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 渠道开关变更处理
  /// [channel] 渠道配置
  /// [enabled] 新的启用状态
  Future<void> _onChannelToggled(ChannelConfig channel, bool enabled) async {
    await _messageState.setChannelEnabled(channel.id, enabled);
    setState(() => _enabledMap[channel.id] = enabled);

    if (channel.implemented) {
      await _autoRefresh.reloadChannel(channel.id);
    }

    if (mounted) {
      final message = enabled
          ? '已启用「${channel.name}」，请到信息中心刷新获取该渠道消息'
          : '已关闭「${channel.name}」，该渠道消息将不再显示';
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: Text(message),
          severity: enabled ? InfoBarSeverity.success : InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  /// 刷新间隔变更处理
  /// [channel] 渠道配置
  /// [minutes] 新的间隔分钟数
  Future<void> _onIntervalChanged(ChannelConfig channel, int minutes) async {
    await _messageState.setChannelInterval(channel.id, minutes);
    setState(() => _intervalMap[channel.id] = minutes);

    if (channel.implemented) {
      await _autoRefresh.reloadChannel(channel.id);
    }
  }

  /// 子分类开关变更处理
  /// [category] 消息分类枚举值
  /// [enabled] 新的启用状态
  Future<void> _onCategoryToggled(
    MessageCategory category,
    bool enabled,
  ) async {
    await _messageState.setCategoryEnabled(category.name, enabled);
    setState(() => _categoryEnabledMap[category.name] = enabled);
  }
}
