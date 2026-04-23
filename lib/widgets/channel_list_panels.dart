/*
 * 渠道列表面板组件 — 顶部刷新设置卡片与单渠道卡片
 * @Project : SSPU-all-in-one
 * @File : channel_list_panels.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../models/channel_config.dart';
import '../models/message_item.dart';
import '../theme/fluent_tokens.dart';
import 'settings_widgets.dart';

/// 分组级刷新设置面板。
class ChannelGroupRefreshPanel extends StatelessWidget {
  final bool enabled;
  final bool hasImplementedChannel;
  final bool groupAutoRefreshEnabled;
  final int groupInterval;
  final int groupManualCount;
  final int groupAutoCount;
  final ValueChanged<int> onGroupManualCountChanged;
  final ValueChanged<bool> onGroupAutoRefreshToggled;
  final ValueChanged<int> onGroupIntervalChanged;
  final ValueChanged<int> onGroupAutoCountChanged;

  const ChannelGroupRefreshPanel({
    super.key,
    required this.enabled,
    required this.hasImplementedChannel,
    required this.groupAutoRefreshEnabled,
    required this.groupInterval,
    required this.groupManualCount,
    required this.groupAutoCount,
    required this.onGroupManualCountChanged,
    required this.onGroupAutoRefreshToggled,
    required this.onGroupIntervalChanged,
    required this.onGroupAutoCountChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                value: groupManualCount,
                enabled: hasImplementedChannel,
                onChanged: onGroupManualCountChanged,
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
                    checked: groupAutoRefreshEnabled,
                    onChanged: hasImplementedChannel
                        ? onGroupAutoRefreshToggled
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
                      color: enabled && groupAutoRefreshEnabled
                          ? null
                          : foreground,
                    ),
                  ),
                  const SizedBox(width: FluentSpacing.xs),
                  ComboBox<int>(
                    value: kIntervalOptions.containsKey(groupInterval)
                        ? groupInterval
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
                    onChanged: enabled && groupAutoRefreshEnabled
                        ? (value) {
                            if (value != null) {
                              onGroupIntervalChanged(value);
                            }
                          }
                        : null,
                  ),
                ],
              ),
              buildCountNumberBox(
                context: context,
                label: '自动刷新文章个数',
                value: groupAutoCount,
                enabled: enabled && groupAutoRefreshEnabled,
                onChanged: onGroupAutoCountChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单个渠道卡片。
class ChannelListItemCard extends StatelessWidget {
  final ChannelConfig channel;
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final Map<String, bool> categoryEnabledMap;
  final ValueChanged<MessageCategory> onToggleCategory;

  const ChannelListItemCard({
    super.key,
    required this.channel,
    required this.enabled,
    required this.onToggled,
    required this.categoryEnabledMap,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
                ToggleSwitch(checked: enabled, onChanged: onToggled),
              ],
            ),
            if (channel.implemented &&
                channelSubcategories.containsKey(channel.id)) ...[
              const SizedBox(height: FluentSpacing.s),
              _ChannelSubcategoryButtons(
                channelId: channel.id,
                channelEnabled: enabled,
                categoryEnabledMap: categoryEnabledMap,
                onToggleCategory: onToggleCategory,
              ),
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
}

class _ChannelSubcategoryButtons extends StatelessWidget {
  final String channelId;
  final bool channelEnabled;
  final Map<String, bool> categoryEnabledMap;
  final ValueChanged<MessageCategory> onToggleCategory;

  const _ChannelSubcategoryButtons({
    required this.channelId,
    required this.channelEnabled,
    required this.categoryEnabledMap,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final subcategories = channelSubcategories[channelId]!;
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
                  categoryEnabledMap[subcategory.category.name] ?? true;
              return _ChannelSubcategoryButton(
                name: subcategory.name,
                enabled: isEnabled,
                interactive: channelEnabled,
                onPressed: () => onToggleCategory(subcategory.category),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChannelSubcategoryButton extends StatelessWidget {
  final String name;
  final bool enabled;
  final bool interactive;
  final VoidCallback onPressed;

  const _ChannelSubcategoryButton({
    required this.name,
    required this.enabled,
    required this.interactive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
}
