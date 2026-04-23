/*
 * 渠道列表组件 — 分区级渠道状态与刷新配置入口
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
import 'channel_list_panels.dart';

/// 渠道列表组件。
/// 负责加载分区级状态，并将渠道卡片与刷新面板组合到同一页。
class ChannelListSection extends StatefulWidget {
  /// 分组标题。
  final String title;

  /// 分组内的渠道配置列表。
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
  final MessageStateService _messageState = MessageStateService.instance;
  final AutoRefreshService _autoRefresh = AutoRefreshService.instance;

  final Map<String, bool> _enabledMap = {};
  final Map<String, bool> _autoRefreshEnabledMap = {};
  final Map<String, int> _intervalMap = {};
  final Map<String, int> _manualCountMap = {};
  final Map<String, int> _autoCountMap = {};
  final Map<String, bool> _categoryEnabledMap = {};

  bool _groupAutoRefreshEnabled = false;
  int _groupInterval = 60;
  int _groupManualCount = 20;
  int _groupAutoCount = 20;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannelStates();
  }

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

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

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
        ChannelGroupRefreshPanel(
          enabled: hasEnabledImplementedChannel,
          hasImplementedChannel: implementedChannels.isNotEmpty,
          groupAutoRefreshEnabled: _groupAutoRefreshEnabled,
          groupInterval: _groupInterval,
          groupManualCount: _groupManualCount,
          groupAutoCount: _groupAutoCount,
          onGroupManualCountChanged: (value) =>
              _onGroupManualCountChanged(value),
          onGroupAutoRefreshToggled: (value) =>
              _onGroupAutoRefreshToggled(value),
          onGroupIntervalChanged: (value) => _onGroupIntervalChanged(value),
          onGroupAutoCountChanged: (value) => _onGroupAutoCountChanged(value),
        ),
        const SizedBox(height: FluentSpacing.m),
        ...widget.channels.map(
          (channel) => ChannelListItemCard(
            channel: channel,
            enabled: _enabledMap[channel.id] ?? false,
            onToggled: (value) => _onChannelToggled(channel, value),
            categoryEnabledMap: _categoryEnabledMap,
            onToggleCategory: (category) => _onCategoryToggled(
              category,
              !(_categoryEnabledMap[category.name] ?? true),
            ),
          ),
        ),
      ],
    );
  }

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

  Future<void> _onGroupManualCountChanged(int count) async {
    final normalized = count.clamp(1, 200);
    for (final channel in widget.channels.where((item) => item.implemented)) {
      await _messageState.setChannelManualFetchCount(channel.id, normalized);
      _manualCountMap[channel.id] = normalized;
    }
    setState(() => _groupManualCount = normalized);
  }

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

  Future<void> _onGroupAutoCountChanged(int count) async {
    final normalized = count.clamp(1, 200);
    for (final channel in widget.channels.where((item) => item.implemented)) {
      await _messageState.setChannelAutoFetchCount(channel.id, normalized);
      _autoCountMap[channel.id] = normalized;
      await _autoRefresh.reloadChannel(channel.id);
    }

    setState(() => _groupAutoCount = normalized);
  }

  Future<void> _onCategoryToggled(
    MessageCategory category,
    bool enabled,
  ) async {
    await _messageState.setCategoryEnabled(category.name, enabled);
    setState(() => _categoryEnabledMap[category.name] = enabled);
  }
}
