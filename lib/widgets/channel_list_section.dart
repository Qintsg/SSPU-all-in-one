/*
 * 渠道列表组件 — 在设置页中展示渠道分组列表与二级详情页
 * @Project : SSPU-all-in-one
 * @File : channel_list_section.dart
 * @Author : Qintsg
 * @Date : 2025-07-17
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../models/channel_config.dart';
import '../models/message_item.dart';
import '../services/message_state_service.dart';
import '../services/auto_refresh_service.dart';
import 'settings_widgets.dart';

/// 渠道列表组件
/// 展示一组渠道的启用/禁用开关，点击渠道可进入二级详情页
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

  /// 当前正在查看详情的渠道 ID（null 表示在列表页）
  String? _detailChannelId;

  /// 是否正在加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannelStates();
  }

  /// 从存储中加载所有渠道的启用状态和刷新间隔
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
    // 加载子分类启用状态
    for (final channel in widget.channels) {
      final subcats = channelSubcategories[channel.id];
      if (subcats != null) {
        for (final sub in subcats) {
          _categoryEnabledMap[sub.category.name] = await _messageState
              .isCategoryEnabled(sub.category.name);
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    // 如果正在查看某个渠道的详情页，显示详情
    if (_detailChannelId != null) {
      final channel = widget.channels.firstWhere(
        (c) => c.id == _detailChannelId,
      );
      return _buildDetailPage(context, channel);
    }

    // 渠道列表页
    return _buildListPage(context);
  }

  /// 构建渠道列表页
  Widget _buildListPage(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Text(widget.title, style: theme.typography.subtitle),
        const SizedBox(height: 4),
        Text(
          '共 ${widget.channels.length} 个渠道，'
          '已启用 ${_enabledMap.values.where((v) => v).length} 个',
          style: theme.typography.caption,
        ),
        const SizedBox(height: 16),
        // 渠道列表
        ...widget.channels.map((channel) => _buildChannelRow(context, channel)),
      ],
    );
  }

  /// 构建单个渠道行 — 图标+名称+描述+开关+详情入口
  Widget _buildChannelRow(BuildContext context, ChannelConfig channel) {
    final theme = FluentTheme.of(context);
    final enabled = _enabledMap[channel.id] ?? false;
    // 未实现的渠道，描述显示"暂未接入"
    final subtitle = channel.implemented
        ? channel.description
        : '${channel.description}（暂未接入）';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverButton(
        onPressed: () => setState(() => _detailChannelId = channel.id),
        builder: (context, states) {
          // 悬停时显示浅灰色背景
          final hovered = states.isHovered || states.isPressed;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hovered
                  ? theme.inactiveColor.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
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
                // 启用/禁用开关
                ToggleSwitch(
                  checked: enabled,
                  onChanged: (value) => _onChannelToggled(channel, value),
                ),
                const SizedBox(width: 8),
                // 详情入口箭头
                Icon(
                  FluentIcons.open_file,
                  size: 12,
                  color: theme.inactiveColor.withValues(alpha: 0.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建渠道详情页 — 返回按钮+渠道开关+刷新间隔选择器
  Widget _buildDetailPage(BuildContext context, ChannelConfig channel) {
    final theme = FluentTheme.of(context);
    final enabled = _enabledMap[channel.id] ?? false;
    final interval = _intervalMap[channel.id] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部返回导航
        Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back, size: 16),
              onPressed: () => setState(() => _detailChannelId = null),
            ),
            const SizedBox(width: 8),
            Text(channel.name, style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: 16),
        // 渠道开关
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 启用开关行
                buildChannelToggle(
                  context: context,
                  icon: channel.icon,
                  title: channel.name,
                  subtitle: channel.implemented
                      ? channel.description
                      : '${channel.description}（暂未接入，启用后不会产生实际数据）',
                  value: enabled,
                  onChanged: (value) => _onChannelToggled(channel, value),
                ),
                if (channel.implemented) ...[
                  const SizedBox(height: 8),
                  // 自动刷新间隔选择器（仅已实现的渠道显示）
                  buildIntervalSelector(
                    context: context,
                    currentValue: interval,
                    enabled: enabled,
                    onChanged: (minutes) =>
                        _onIntervalChanged(channel, minutes),
                  ),
                  // 子分类开关（仅有多子分类的渠道显示）
                  if (channelSubcategories.containsKey(channel.id)) ...[
                    const SizedBox(height: 16),
                    _buildSubcategoryToggles(context, channel),
                  ],
                ],
                if (!channel.implemented) ...[
                  const SizedBox(height: 16),
                  // 未实现渠道提示
                  InfoBar(
                    title: const Text('此渠道数据源尚未接入'),
                    content: const Text('后续版本将陆续支持，启用开关仅作预配置用途。'),
                    severity: InfoBarSeverity.warning,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 渠道开关变更处理
  /// [channel] 渠道配置
  /// [enabled] 新的启用状态
  Future<void> _onChannelToggled(ChannelConfig channel, bool enabled) async {
    await _messageState.setChannelEnabled(channel.id, enabled);
    setState(() => _enabledMap[channel.id] = enabled);
    // 已实现的渠道触发自动刷新重载
    if (channel.implemented) {
      await _autoRefresh.reloadChannel(channel.id);
    }
    // 显示提示
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

  /// 构建子分类开关区域
  /// 显示渠道下所有子分类的独立开关
  Widget _buildSubcategoryToggles(BuildContext context, ChannelConfig channel) {
    final theme = FluentTheme.of(context);
    final subcats = channelSubcategories[channel.id]!;
    final channelEnabled = _enabledMap[channel.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 区域标题
        Text('内容分类', style: theme.typography.bodyStrong),
        const SizedBox(height: 4),
        Text('单独控制每个分类的显示，关闭后该分类消息将不再展示', style: theme.typography.caption),
        const SizedBox(height: 8),
        // 每个子分类一行（名称 + 开关）
        ...subcats.map((sub) {
          final catEnabled = _categoryEnabledMap[sub.category.name] ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(sub.name, style: theme.typography.body)),
                ToggleSwitch(
                  checked: catEnabled,
                  // 渠道未启用时子分类开关置灰不可操作
                  onChanged: channelEnabled
                      ? (value) => _onCategoryToggled(sub.category, value)
                      : null,
                ),
              ],
            ),
          );
        }),
      ],
    );
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
