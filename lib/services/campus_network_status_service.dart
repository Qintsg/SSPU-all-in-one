/*
 * 校园网状态检测服务 — 通过可替换探针检测校园网 / VPN 可达性
 * @Project : SSPU-all-in-one
 * @File : campus_network_status_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/campus_network_status.dart';
import 'http_service.dart';
import 'storage_service.dart';

/// 校园网检测探针签名。
/// 后续若需要区分直连校园网与 VPN，只需替换探针实现，不影响调用方。
typedef CampusNetworkProbe =
    Future<CampusNetworkProbeResult> Function(Uri probeUri, Duration timeout);

/// 单次探针访问结果。
class CampusNetworkProbeResult {
  const CampusNetworkProbeResult({
    required this.reachable,
    required this.detail,
    this.statusCode,
  });

  /// 目标校园站点是否成功返回可用 HTTP 响应。
  final bool reachable;

  /// 探针结果说明。
  final String detail;

  /// HTTP 状态码；连接失败或超时时为空。
  final int? statusCode;
}

/// 校园网 / VPN 前置检测服务。
class CampusNetworkStatusService extends ChangeNotifier {
  CampusNetworkStatusService({
    CampusNetworkProbe? probe,
    Uri? probeUri,
    Duration? timeout,
  }) : _probe = probe ?? _defaultProbe,
       probeUri = probeUri ?? defaultProbeUri,
       timeout = timeout ?? const Duration(seconds: 5);

  /// 全局单例，供应用顶栏与后续受限入口共用。
  static final CampusNetworkStatusService instance =
      CampusNetworkStatusService();

  /// 默认检测目标：本专科教务系统域名。
  static final Uri defaultProbeUri = Uri.parse('https://tygl.sspu.edu.cn/');

  /// 默认检测间隔，兼顾状态新鲜度与校园站点访问频率。
  static const int defaultDetectionIntervalMinutes = 15;

  /// 实际检测目标地址。
  final Uri probeUri;

  /// 单次检测超时时间，避免启动后长期占用 UI 状态。
  final Duration timeout;

  final CampusNetworkProbe _probe;

  /// 执行一次校园网 / VPN 状态检测。
  Future<CampusNetworkStatus> checkStatus() async {
    try {
      final result = await _probe(probeUri, timeout);
      return CampusNetworkStatus(
        accessMode: result.reachable
            ? CampusNetworkAccessMode.campusOrVpn
            : CampusNetworkAccessMode.unavailable,
        probeUri: probeUri,
        checkedAt: DateTime.now(),
        detail: result.detail,
      );
    } catch (error) {
      return CampusNetworkStatus(
        accessMode: CampusNetworkAccessMode.unavailable,
        probeUri: probeUri,
        checkedAt: DateTime.now(),
        detail: '校园网检测失败：$error',
      );
    }
  }

  /// 读取校园网 / VPN 状态自动检测间隔。
  Future<int> getDetectionIntervalMinutes() async {
    final stored = await StorageService.getInt(
      StorageKeys.campusNetworkDetectionIntervalMinutes,
    );
    return _normalizeInterval(stored ?? defaultDetectionIntervalMinutes);
  }

  /// 保存校园网 / VPN 状态自动检测间隔并通知现有徽标立即重排定时器。
  Future<void> setDetectionIntervalMinutes(int minutes) async {
    final normalized = _normalizeInterval(minutes);
    await StorageService.setInt(
      StorageKeys.campusNetworkDetectionIntervalMinutes,
      normalized,
    );
    notifyListeners();
  }

  /// 间隔只接受非负分钟数；0 表示关闭自动检测但保留手动点击刷新。
  int _normalizeInterval(int minutes) {
    return minutes < 0 ? 0 : minutes;
  }

  /// 默认探针只发起只读 GET 请求；任何非 5xx HTTP 响应都表示内网域名可达。
  static Future<CampusNetworkProbeResult> _defaultProbe(
    Uri probeUri,
    Duration timeout,
  ) async {
    try {
      final response = await HttpService.instance.dio
          .getUri<Object>(
            probeUri,
            options: Options(
              followRedirects: false,
              receiveTimeout: timeout,
              responseType: ResponseType.plain,
              sendTimeout: timeout,
              validateStatus: (statusCode) => statusCode != null,
            ),
          )
          .timeout(timeout);
      final statusCode = response.statusCode;
      final reachable = statusCode != null && statusCode < 500;
      return CampusNetworkProbeResult(
        reachable: reachable,
        statusCode: statusCode,
        detail: reachable
            ? '已访问 ${probeUri.host}，HTTP $statusCode'
            : '${probeUri.host} 返回 HTTP $statusCode',
      );
    } on TimeoutException {
      return CampusNetworkProbeResult(
        reachable: false,
        detail: '访问 ${probeUri.host} 超时',
      );
    } on DioException catch (error) {
      return CampusNetworkProbeResult(
        reachable: false,
        statusCode: error.response?.statusCode,
        detail: HttpService.describeError(error),
      );
    }
  }
}
