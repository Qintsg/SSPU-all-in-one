/*
 * 消息列表项组件 — 从 info_page.dart 提取的消息展示行
 * @Project : SSPU-all-in-one
 * @File : message_tile.dart
 * @Author : Qintsg
 * @Date : 2026-07-17
 */

import 'package:fluent_ui/fluent_ui.dart';
import '../models/message_item.dart';

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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // 未读指示点
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead ? Colors.transparent : Colors.blue,
                ),
              ),

              // 标题 + 标签区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 消息标题
                    Text(
                      message.title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 标签行：tag1 来源类型 + tag2 来源名称 + tag3 内容分类
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildTag(
                          message.sourceType.label,
                          Colors.blue,
                        ),
                        _buildTag(
                          message.sourceName.label,
                          Colors.teal,
                        ),
                        _buildTag(
                          message.category.label,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 右侧：日期 + 操作按钮
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 日期
                  Text(
                    message.date,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 操作按钮行
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 跳转按钮
                      Tooltip(
                        message: '在浏览器中打开',
                        child: IconButton(
                          icon: const Icon(
                            FluentIcons.open_in_new_window,
                            size: 14,
                          ),
                          onPressed: onTap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 标为已读按钮
                      if (!isRead)
                        Tooltip(
                          message: '标为已读',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.read,
                              size: 14,
                            ),
                            onPressed: onMarkRead,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建标签 badge
  /// [text] 标签文字
  /// [color] 标签颜色
  Widget _buildTag(String text, AccentColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? color.lighter : color.dark,
        ),
      ),
    );
  }
}
