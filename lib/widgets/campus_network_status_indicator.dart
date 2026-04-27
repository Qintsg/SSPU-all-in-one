/*
 * 校园网状态徽标 — 在导航栏展示校园网 / VPN 检测结果
 * @Project : SSPU-all-in-one
 * @File : campus_network_status_indicator.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../models/campus_network_status.dart';
import '../services/campus_network_status_service.dart';
import '../theme/fluent_tokens.dart';

/// 应用级校园网 / VPN 状态徽标。
class CampusNetworkStatusIndicator extends StatefulWidget {
  const CampusNetworkStatusIndicator({super.key, this.service});

  /// 检测服务；测试或后续平台差异化检测可注入自定义实现。
  final CampusNetworkStatusService? service;

  @override
  State<CampusNetworkStatusIndicator> createState() =>
      _CampusNetworkStatusIndicatorState();
}

class _CampusNetworkStatusIndicatorState
    extends State<CampusNetworkStatusIndicator> {
  late CampusNetworkStatus _status;

  /// 当前自动检测间隔；0 表示只允许手动点击刷新。
  int _detectionIntervalMinutes =
      CampusNetworkStatusService.defaultDetectionIntervalMinutes;

  /// 自动检测定时器，按设置页配置重排。
  Timer? _refreshTimer;

  /// 防止用户连续点击刷新造成重复探测。
  bool _isChecking = false;

  CampusNetworkStatusService get _service {
    return widget.service ?? CampusNetworkStatusService.instance;
  }

  @override
  void initState() {
    super.initState();
    _status = CampusNetworkStatus.unknown(probeUri: _service.probeUri);
    _service.addListener(_onServiceSettingsChanged);
    unawaited(_loadIntervalAndRefresh());
  }

  @override
  void didUpdateWidget(CampusNetworkStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      final oldService =
          oldWidget.service ?? CampusNetworkStatusService.instance;
      oldService.removeListener(_onServiceSettingsChanged);
      _service.addListener(_onServiceSettingsChanged);
      _status = CampusNetworkStatus.unknown(probeUri: _service.probeUri);
      unawaited(_loadIntervalAndRefresh());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _service.removeListener(_onServiceSettingsChanged);
    super.dispose();
  }

  void _onServiceSettingsChanged() {
    unawaited(_reloadDetectionInterval());
  }

  Future<void> _loadIntervalAndRefresh() async {
    final interval = await _service.getDetectionIntervalMinutes();
    if (!mounted) return;
    setState(() => _detectionIntervalMinutes = interval);
    await _refreshStatus();
  }

  Future<void> _reloadDetectionInterval() async {
    final interval = await _service.getDetectionIntervalMinutes();
    if (!mounted) return;
    setState(() => _detectionIntervalMinutes = interval);
    _scheduleNextRefresh();
  }

  Future<void> _refreshStatus() async {
    if (_isChecking) return;
    _refreshTimer?.cancel();
    setState(() => _isChecking = true);
    final nextStatus = await _service.checkStatus();
    if (!mounted) return;
    setState(() {
      _status = nextStatus;
      _isChecking = false;
    });
    _scheduleNextRefresh();
  }

  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();
    if (_detectionIntervalMinutes <= 0) return;

    _refreshTimer = Timer(Duration(minutes: _detectionIntervalMinutes), () {
      unawaited(_refreshStatus());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final foregroundColor = _foregroundColor(theme);
    final fillColor = foregroundColor.withValues(alpha: 0.10);
    final borderColor = foregroundColor.withValues(alpha: 0.28);

    return Tooltip(
      message: _tooltipMessage,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabel = constraints.maxWidth >= 96;
          return HoverButton(
            key: const Key('campus-network-status-indicator'),
            onPressed: _isChecking ? null : _refreshStatus,
            builder: (context, states) {
              final isActive = states.isHovered || states.isPressed;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                constraints: BoxConstraints(
                  minWidth: showLabel ? 0 : 28,
                  minHeight: 28,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: showLabel ? 10 : 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? fillColor.withValues(alpha: 0.18)
                      : fillColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(FluentRadius.circular),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusIcon(foregroundColor),
                    if (showLabel) ...[
                      const SizedBox(width: FluentSpacing.s),
                      Flexible(
                        child: Text(
                          _isChecking ? '检测中' : _status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(Color foregroundColor) {
    if (_isChecking) {
      return SizedBox(
        width: 12,
        height: 12,
        child: ProgressRing(strokeWidth: 2, activeColor: foregroundColor),
      );
    }

    return Icon(_statusIcon, size: 12, color: foregroundColor);
  }

  IconData get _statusIcon {
    return switch (_status.accessMode) {
      CampusNetworkAccessMode.campus ||
      CampusNetworkAccessMode.vpn ||
      CampusNetworkAccessMode.campusOrVpn => FluentIcons.plug_connected,
      CampusNetworkAccessMode.unavailable => FluentIcons.plug_disconnected,
      CampusNetworkAccessMode.unknown => FluentIcons.sync_status,
    };
  }

  Color _foregroundColor(FluentThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return switch (_status.accessMode) {
      CampusNetworkAccessMode.campus ||
      CampusNetworkAccessMode.vpn ||
      CampusNetworkAccessMode.campusOrVpn =>
        isDark
            ? FluentDarkColors.statusSuccess
            : FluentLightColors.statusSuccess,
      CampusNetworkAccessMode.unavailable =>
        isDark
            ? FluentDarkColors.statusWarning
            : FluentLightColors.statusWarning,
      CampusNetworkAccessMode.unknown => theme.accentColor,
    };
  }

  String get _tooltipMessage {
    final checkedAt = _status.checkedAt;
    final checkedAtLabel = checkedAt == null
        ? '尚未完成检测'
        : '检测时间：${checkedAt.hour.toString().padLeft(2, '0')}'
              ':${checkedAt.minute.toString().padLeft(2, '0')}'
              ':${checkedAt.second.toString().padLeft(2, '0')}';

    final intervalLabel = _detectionIntervalMinutes <= 0
        ? '自动检测：已关闭'
        : '自动检测：每 $_detectionIntervalMinutes 分钟';

    return '${_status.description}\n${_status.detail}\n$checkedAtLabel\n$intervalLabel\n点击可重新检测';
  }
}
