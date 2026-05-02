/*
 * 快速跳转组件 — 链接磁贴与配色角色
 * @Project : SSPU-all-in-one
 * @File : quick_links_widgets.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'quick_links_page.dart';

enum _QuickLinkColorRole {
  brand,
  brandAlt,
  info,
  success,
  caution,
  neutral,
  critical,
}

/// 快捷链接砖块组件。
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final String url;
  final Future<void> Function(String) onTap;

  /// 磁贴宽度（响应式调整）。
  final double width;

  const _LinkTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.url,
    required this.onTap,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return HoverButton(
      onPressed: () => onTap(url),
      builder: (context, states) {
        final isHovered = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: width,
          constraints: const BoxConstraints(minHeight: 122),
          padding: const EdgeInsets.all(FluentSpacing.l),
          decoration: BoxDecoration(
            color: isHovered
                ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                : isDark
                ? FluentDarkColors.hoverFill
                : theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(FluentRadius.xLarge),
            border: Border.all(
              color: isHovered
                  ? color.withValues(alpha: 0.3)
                  : isDark
                  ? FluentDarkColors.borderSubtle
                  : FluentLightColors.borderSubtle,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: FluentSpacing.s),
              Text(
                label,
                style: theme.typography.body?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: subtitle == null ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: FluentSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
