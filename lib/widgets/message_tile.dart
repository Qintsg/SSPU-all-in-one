/*
 * 消息列表项组件 — 从 info_page.dart 提取的消息展示行
 * @Project : SSPU-all-in-one
 * @File : message_tile.dart
 * @Author : Qintsg
 * @Date : 2026-04-17
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../models/message_item.dart';
import '../theme/fluent_tokens.dart';

/// 单条消息列表项组件
/// 展示消息标题、标签、日期、已读/未读状态、操作按钮
class MessageTile extends StatelessWidget {
  /// 消息数据
  final MessageItem message;

  /// 是否已读
  final bool isRead;

  /// 当前是否暗色主题
  final bool isDark;

  /// 当前 Fluent 主题
  final FluentThemeData theme;

  /// 点击跳转回调
  final VoidCallback onTap;

  /// 标为已读回调
  final VoidCallback onMarkRead;

  const MessageTile({
    super.key,
    required this.message,
    required this.isRead,
    required this.isDark,
    required this.theme,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    // 未读消息使用更醒目的样式
    final titleStyle = isRead
        ? theme.typography.body?.copyWith(
            color: theme.resources.textFillColorSecondary,
          )
        : theme.typography.bodyStrong;

    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        final isHovered = states.isHovered;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            vertical: FluentSpacing.s + FluentSpacing.xxs,
            horizontal: FluentSpacing.m,
          ),
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark
                      ? FluentDarkColors.hoverFill
                      : FluentLightColors.hoverFill)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FluentRadius.large),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow =
                  FluentBreakpoints.fromWidth(constraints.maxWidth) ==
                  DeviceType.phone;
              final content = _buildMessageContent(titleStyle);
              final actions = _buildDateAndActions(isNarrow: isNarrow);

              if (isNarrow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUnreadIndicator(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          content,
                          const SizedBox(height: FluentSpacing.s),
                          actions,
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _buildUnreadIndicator(),
                  Expanded(child: content),
                  const SizedBox(width: FluentSpacing.m),
                  actions,
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUnreadIndicator() {
    return Container(
      width: FluentSpacing.s,
      height: FluentSpacing.s,
      margin: const EdgeInsets.only(
        top: FluentSpacing.xs,
        right: FluentSpacing.s + FluentSpacing.xxs,
      ),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRead
            ? Colors.transparent
            : (isDark
                  ? FluentDarkColors.unreadIndicator
                  : FluentLightColors.unreadIndicator),
      ),
    );
  }

  Widget _buildMessageContent(TextStyle? titleStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.title,
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: FluentSpacing.xs + FluentSpacing.xxs),
        Wrap(
          spacing: FluentSpacing.xs + FluentSpacing.xxs,
          runSpacing: FluentSpacing.xs,
          children: _buildMetadataTags(),
        ),
      ],
    );
  }

  Widget _buildDateAndActions({required bool isNarrow}) {
    final dateText = Text(
      _formatDisplayDateTime(message),
      style: theme.typography.caption?.copyWith(
        color: theme.resources.textFillColorSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: _actionButtons,
    );

    if (isNarrow) {
      return Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [dateText, buttons],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: dateText,
        ),
        const SizedBox(height: FluentSpacing.xs + FluentSpacing.xxs),
        buttons,
      ],
    );
  }

  List<Widget> get _actionButtons {
    return [
      Tooltip(
        message: '在浏览器中打开',
        child: IconButton(
          icon: const Icon(FluentIcons.open_in_new_window, size: 14),
          onPressed: onTap,
        ),
      ),
      const SizedBox(width: FluentSpacing.xs),
      if (!isRead)
        Tooltip(
          message: '标为已读',
          child: IconButton(
            icon: const Icon(FluentIcons.read, size: 14),
            onPressed: onMarkRead,
          ),
        ),
    ];
  }

  /// 格式化消息展示日期时间，保证当天官网消息不会只显示时间。
  String _formatDisplayDateTime(MessageItem message) {
    final displayDate = message.date.trim().isNotEmpty
        ? message.date.trim()
        : message.timestamp != null
        ? _formatDate(message.timestamp!)
        : '';

    if (message.timestamp == null || displayDate.isEmpty) {
      return displayDate;
    }
    return '$displayDate ${_formatTime(message.timestamp!)}';
  }

  /// 格式化时间戳为 YYYY-MM-DD，用于修复旧缓存中的空日期。
  String _formatDate(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 格式化时间戳为 HH:mm
  String _formatTime(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 构建标签 badge
  /// [text] 标签文字
  /// [color] 标签颜色
  Widget _buildTag(String text, AccentColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FluentSpacing.xs + FluentSpacing.xxs,
        vertical: FluentSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(FluentRadius.medium),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          text,
          style: theme.typography.caption?.copyWith(
            fontSize: FluentTypographySize.caption - 1,
            color: isDark ? color.lighter : color.dark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  List<Widget> _buildMetadataTags() {
    final tags = <Widget>[];
    final seenSourceLabels = <String>{};

    void addSourceTag(String text, AccentColor color) {
      final trimmed = text.trim();
      if (trimmed.isEmpty || !seenSourceLabels.add(trimmed)) return;
      tags.add(_buildTag(trimmed, color));
    }

    if (_isWechatMessage) {
      addSourceTag(message.sourceType.label, Colors.blue);
      addSourceTag(_wechatAccountName, Colors.magenta);
    } else {
      addSourceTag(message.sourceType.label, Colors.blue);
      addSourceTag(message.sourceName.label, Colors.teal);
      addSourceTag(message.category.label, Colors.orange);

      final mpName = message.mpName?.trim();
      if (mpName != null && mpName.isNotEmpty) {
        tags.add(_buildTag(mpName, Colors.magenta));
      }
    }

    return tags;
  }

  bool get _isWechatMessage {
    return message.sourceType == MessageSourceType.wechatPublic ||
        message.sourceType == MessageSourceType.wechatService;
  }

  String get _wechatAccountName {
    final mpName = message.mpName?.trim();
    if (mpName == null || mpName.isEmpty) return '公众号名称未知';
    return mpName;
  }
}
