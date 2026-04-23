/*
 * 渠道列表组件 — 在设置页中展示官网渠道开关、刷新配置与内容分类按钮
 * @Project : SSPU-all-in-one
 * @File : channel_list_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../models/channel_config.dart';
import '../models/message_item.dart';
import '../services/auto_refresh_service.dart';
import '../services/message_state_service.dart';
import '../theme/fluent_tokens.dart';
import 'settings_widgets.dart';

/// 渠道列表组件
/// 展示一组渠道的启用状态、刷新设置与子分类交互。
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

  /// 各渠道自动刷新状态缓存（channelId → enabled）
  final Map<String, bool> _autoRefreshEnabledMap = {};

  /// 各渠道展示用刷新间隔缓存（channelId → minutes）
  final Map<String, int> _intervalMap = {};

  /// 各渠道手动刷新条数缓存（channelId → count）
  final Map<String, int> _manualCountMap = {};

  /// 各渠道自动刷新条数缓存（channelId → count）
  final Map<String, int> _autoCountMap = {};

  /// 分组级自动刷新状态，用于批量控制当前设置分区内的官网渠道。
  bool _groupAutoRefreshEnabled = false;

  /// 分组级刷新间隔，写入时会同步到当前分区内所有已接入渠道。
  int _groupInterval = 60;

  /// 分组级手动刷新条数，写入时会同步到当前分区内所有已接入渠道。
  int _groupManualCount = 20;

  /// 分组级自动刷新条数，写入时会同步到当前分区内所有已接入渠道。
  int _groupAutoCount = 20;

  /// 各子分类启用状态缓存（categoryName → enabled）
  final Map<String, bool> _categoryEnabledMap = {};

  /// 是否正在加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannelStates();
  }

  /// 从存储中加载所有渠道状态。
  Future<void> _loadChannelStates() async {
    for (final channel in widget.channels) {
      _enabledMap[channel.id] = await _messageState.isChannelEnabled(
        channel.id,
        defaultValue: channel.defaultEnabled,
      );
      _autoRefreshEnabledMap[channel.id] = await _messageState
          .isChannelAutoRefreshEnabled(channel.id);
      _intervalMap[channel.id] = await _messageState.getChannelDisplayInterval(
        channel.id,
        defaultValue: channel.defaultInterval,
      );
      _manualCountMap[channel.id] = await _messageState
          .getChannelManualFetchCount(channel.id);
      _autoCountMap[channel.id] = await _messageState.getChannelAutoFetchCount(
        channel.id,
      );
    }

    _syncGroupRefreshState();

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

  /// 根据当前分区的渠道状态生成顶部刷新设置的初始展示值。
  void _syncGroupRefreshState() {
    ChannelConfig? sourceChannel;
    for (final channel in widget.channels) {
      if (!channel.implemented) continue;
      sourceChannel ??= channel;
      if ((_autoRefreshEnabledMap[channel.id] ?? false) &&
          (_intervalMap[channel.id] ?? 0) > 0) {
        sourceChannel = channel;
        break;
      }
    }

    if (sourceChannel == null) return;
    _groupAutoRefreshEnabled = widget.channels.any(
      (channel) =>
          channel.implemented && (_autoRefreshEnabledMap[channel.id] ?? false),
    );
    _groupInterval =
        _intervalMap[sourceChannel.id] ?? sourceChannel.defaultInterval;
    _groupManualCount = _manualCountMap[sourceChannel.id] ?? 20;
    _groupAutoCount = _autoCountMap[sourceChannel.id] ?? 20;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    return _buildListPage(context);
  }

  /// 构建渠道列表页。
  Widget _buildListPage(BuildContext context) {
    final theme = FluentTheme.of(context);
    final enabledCount = _enabledMap.values.where((enabled) => enabled).length;
    final autoEnabledCount = widget.channels
        .where(
          (channel) =>
              (_enabledMap[channel.id] ?? false) &&
              (_autoRefreshEnabledMap[channel.id] ?? false),
        )
        .length;
    final implementedChannels = widget.channels
        .where((channel) => channel.implemented)
        .toList(growable: false);
    final hasEnabledImplementedChannel = implementedChannels.any(
      (channel) => _enabledMap[channel.id] ?? false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(widget.title, style: theme.typography.subtitle),
            FilledButton(
              onPressed: () => _setAllChannelsEnabled(true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.check_mark, size: 14),
                  SizedBox(width: 6),
                  Text('一键全开'),
                ],
              ),
            ),
            Button(
              onPressed: () => _setAllChannelsEnabled(false),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.blocked, size: 14),
                  SizedBox(width: 6),
                  Text('一键全关'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: FluentSpacing.xxs),
        Text(
          '共 ${widget.channels.length} 个渠道，已启用 $enabledCount 个，自动刷新开启 $autoEnabledCount 个。',
          style: theme.typography.caption,
        ),
        const SizedBox(height: FluentSpacing.m),
        _buildGroupRefreshSettings(
          context,
          enabled: hasEnabledImplementedChannel,
          hasImplementedChannel: implementedChannels.isNotEmpty,
        ),
        const SizedBox(height: FluentSpacing.m),
        ...widget.channels.map(
          (channel) => _buildChannelCard(context, channel),
        ),
      ],
    );
  }

  /// 构建单个渠道卡片。
  Widget _buildChannelCard(BuildContext context, ChannelConfig channel) {
    final theme = FluentTheme.of(context);
    final enabled = _enabledMap[channel.id] ?? false;
    final subtitle = channel.implemented
        ? channel.description
        : '${channel.description}（暂未接入）';

    return Padding(
      padding: const EdgeInsets.only(bottom: FluentSpacing.s),
      child: Container(
        padding: const EdgeInsets.all(FluentSpacing.m),
        decoration: BoxDecoration(
          color: theme.inactiveColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(channel.icon, size: 20),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(channel.name, style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        subtitle,
                        style: theme.typography.caption?.copyWith(
                          color: enabled
                              ? null
                              : theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FluentSpacing.s),
                ToggleSwitch(
                  checked: enabled,
                  onChanged: (value) => _onChannelToggled(channel, value),
                ),
              ],
            ),
            if (channel.implemented &&
                channelSubcategories.containsKey(channel.id)) ...[
              const SizedBox(height: FluentSpacing.s),
              _buildSubcategoryButtons(context, channel, enabled),
            ],
            if (!channel.implemented) ...[
              const SizedBox(height: FluentSpacing.s),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  '此渠道数据源尚未接入，开关仅作为预配置使用。',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建分组级刷新设置区域。
  Widget _buildGroupRefreshSettings(
    BuildContext context, {
    required bool enabled,
    required bool hasImplementedChannel,
  }) {
    final theme = FluentTheme.of(context);
    final foreground = enabled
        ? null
        : theme.resources.textFillColorSecondary.withValues(alpha: 0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FluentSpacing.m),
      decoration: BoxDecoration(
        color: theme.inactiveColor.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('刷新设置', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text(
            '这些设置会应用到本分区内每个已接入的内容渠道。',
            style: theme.typography.caption?.copyWith(color: foreground),
          ),
          const SizedBox(height: FluentSpacing.s),
          Wrap(
            spacing: FluentSpacing.l,
            runSpacing: FluentSpacing.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              buildCountNumberBox(
                context: context,
                label: '手动刷新文章个数',
                value: _groupManualCount,
                enabled: hasImplementedChannel,
                onChanged: _onGroupManualCountChanged,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '自动刷新：',
                    style: theme.typography.caption?.copyWith(
                      color: hasImplementedChannel ? null : foreground,
                    ),
                  ),
                  const SizedBox(width: FluentSpacing.xs),
                  ToggleSwitch(
                    checked: _groupAutoRefreshEnabled,
                    onChanged: hasImplementedChannel
                        ? _onGroupAutoRefreshToggled
                        : null,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '自动刷新间隔：',
                    style: theme.typography.caption?.copyWith(
                      color: enabled && _groupAutoRefreshEnabled
                          ? null
                          : foreground,
                    ),
                  ),
                  const SizedBox(width: FluentSpacing.xs),
                  ComboBox<int>(
                    value: kIntervalOptions.containsKey(_groupInterval)
                        ? _groupInterval
                        : 60,
                    items: kIntervalOptions.entries
                        .where((entry) => entry.key > 0)
                        .map(
                          (entry) => ComboBoxItem<int>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: enabled && _groupAutoRefreshEnabled
                        ? (value) {
                            if (value != null) {
                              _onGroupIntervalChanged(value);
                            }
                          }
                        : null,
                  ),
                ],
              ),
              buildCountNumberBox(
                context: context,
                label: '自动刷新文章个数',
                value: _groupAutoCount,
                enabled: enabled && _groupAutoRefreshEnabled,
                onChanged: _onGroupAutoCountChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建子分类按钮区域。
  Widget _buildSubcategoryButtons(
    BuildContext context,
    ChannelConfig channel,
    bool channelEnabled,
  ) {
    final theme = FluentTheme.of(context);
    final subcategories = channelSubcategories[channel.id]!;
    final labelColor = channelEnabled
        ? null
        : theme.resources.textFillColorSecondary.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '内容分类',
            style: theme.typography.caption?.copyWith(color: labelColor),
          ),
          const SizedBox(height: FluentSpacing.xs),
          Wrap(
            spacing: FluentSpacing.s,
            runSpacing: FluentSpacing.s,
            children: subcategories.map((subcategory) {
              final isEnabled =
                  _categoryEnabledMap[subcategory.category.name] ?? true;
              return _buildCategoryButton(
                context,
                name: subcategory.name,
                enabled: isEnabled,
                interactive: channelEnabled,
                onPressed: () =>
                    _onCategoryToggled(subcategory.category, !isEnabled),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建单个子分类按钮。
  Widget _buildCategoryButton(
    BuildContext context, {
    required String name,
    required bool enabled,
    required bool interactive,
    required VoidCallback onPressed,
  }) {
    final theme = FluentTheme.of(context);
    final background = !interactive
        ? theme.inactiveColor.withValues(alpha: 0.18)
        : enabled
        ? Colors.green
        : theme.inactiveColor.withValues(alpha: 0.7);

    return Button(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(background),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      ),
      onPressed: interactive ? onPressed : null,
      child: Text(name),
    );
  }

  /// 渠道开关变更处理。
  Future<void> _onChannelToggled(ChannelConfig channel, bool enabled) async {
    await _messageState.setChannelEnabled(channel.id, enabled);
    setState(() => _enabledMap[channel.id] = enabled);

    if (channel.implemented) {
      await _autoRefresh.reloadChannel(channel.id);
    }

    if (!mounted) return;
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

  /// 批量切换当前分区全部渠道；全开时同步恢复所有内容分类。
  Future<void> _setAllChannelsEnabled(bool enabled) async {
    for (final channel in widget.channels) {
      await _messageState.setChannelEnabled(channel.id, enabled);
      _enabledMap[channel.id] = enabled;
      if (channel.implemented) {
        await _autoRefresh.reloadChannel(channel.id);
      }
    }

    if (enabled) {
      for (final subcategoryList in channelSubcategories.values) {
        for (final subcategory in subcategoryList) {
          await _messageState.setCategoryEnabled(
            subcategory.category.name,
            true,
          );
          _categoryEnabledMap[subcategory.category.name] = true;
        }
      }
    }

    if (!mounted) return;
    setState(() {});
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: Text(enabled ? '已启用当前分区全部渠道' : '已关闭当前分区全部渠道'),
        severity: enabled ? InfoBarSeverity.success : InfoBarSeverity.info,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  /// 分组级手动刷新条数变更处理。
  Future<void> _onGroupManualCountChanged(int count) async {
    final normalized = count.clamp(1, 200);
    for (final channel in widget.channels.where((item) => item.implemented)) {
      await _messageState.setChannelManualFetchCount(channel.id, normalized);
      _manualCountMap[channel.id] = normalized;
    }
    setState(() => _groupManualCount = normalized);
  }

  /// 分组级自动刷新开关变更处理。
  Future<void> _onGroupAutoRefreshToggled(bool enabled) async {
    final interval = _groupInterval <= 0 ? 60 : _groupInterval;
    for (final channel in widget.channels.where((item) => item.implemented)) {
      if (enabled) {
        await _messageState.setChannelInterval(channel.id, interval);
      } else {
        await _messageState.setChannelAutoRefreshEnabled(channel.id, false);
      }
      _autoRefreshEnabledMap[channel.id] = enabled;
      _intervalMap[channel.id] = interval;
      await _autoRefresh.reloadChannel(channel.id);
    }

    setState(() {
      _groupAutoRefreshEnabled = enabled;
      _groupInterval = interval;
    });
  }

  /// 分组级刷新间隔变更处理。
  Future<void> _onGroupIntervalChanged(int minutes) async {
    for (final channel in widget.channels.where((item) => item.implemented)) {
      await _messageState.setChannelInterval(channel.id, minutes);
      _intervalMap[channel.id] = minutes;
      _autoRefreshEnabledMap[channel.id] = minutes > 0;
      await _autoRefresh.reloadChannel(channel.id);
    }

    setState(() {
      _groupInterval = minutes;
      _groupAutoRefreshEnabled = minutes > 0;
    });
  }

  /// 分组级自动刷新条数变更处理。
  Future<void> _onGroupAutoCountChanged(int count) async {
    final normalized = count.clamp(1, 200);
    for (final channel in widget.channels.where((item) => item.implemented)) {
      await _messageState.setChannelAutoFetchCount(channel.id, normalized);
      _autoCountMap[channel.id] = normalized;
      await _autoRefresh.reloadChannel(channel.id);
    }

    setState(() => _groupAutoCount = normalized);
  }

  /// 子分类开关变更处理。
  Future<void> _onCategoryToggled(
    MessageCategory category,
    bool enabled,
  ) async {
    await _messageState.setCategoryEnabled(category.name, enabled);
    setState(() => _categoryEnabledMap[category.name] = enabled);
  }
}
