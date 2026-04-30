/*
 * 教务登录校验模型 — 描述本专科教务系统 OA 登录只读校验结果
 * @Project : SSPU-all-in-one
 * @File : academic_login_validation.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'campus_network_status.dart';

/// 本专科教务系统 OA 登录后的可复用会话快照。
class AcademicLoginSessionSnapshot {
  const AcademicLoginSessionSnapshot({
    required this.cookieHeadersByHost,
    required this.authenticatedAt,
    required this.entranceUri,
    required this.finalUri,
  });

  /// 按 Cookie 作用域保存的请求头；值不可展示给用户。
  final Map<String, String> cookieHeadersByHost;

  /// 会话写入时间，用于调用方判断低持久性登录是否需要刷新。
  final DateTime authenticatedAt;

  /// 触发登录的 OA 入口地址。
  final Uri entranceUri;

  /// 登录成功后最终停留地址。
  final Uri finalUri;

  /// 是否获得了后续网页请求可复用的 Cookie。
  bool get hasCookies {
    return cookieHeadersByHost.values.any(
      (cookieHeader) => cookieHeader.trim().isNotEmpty,
    );
  }

  /// 返回目标地址可用的 Cookie 请求头。
  String cookieHeaderFor(Uri targetUri) {
    final normalizedHost = targetUri.host.toLowerCase();
    final matchingCookieHeaders = <String>[];
    for (final entry in cookieHeadersByHost.entries) {
      final cookieHost = entry.key.toLowerCase();
      final cookieHeader = entry.value.trim();
      if (cookieHeader.isEmpty) continue;
      if (normalizedHost == cookieHost ||
          normalizedHost.endsWith('.$cookieHost')) {
        matchingCookieHeaders.add(cookieHeader);
      }
    }
    return matchingCookieHeaders.join('; ');
  }

  /// 序列化为安全存储中的 JSON 结构。
  Map<String, Object> toJson() {
    return {
      'cookieHeadersByHost': cookieHeadersByHost,
      'authenticatedAt': authenticatedAt.toIso8601String(),
      'entranceUri': entranceUri.toString(),
      'finalUri': finalUri.toString(),
    };
  }

  /// 从安全存储 JSON 结构恢复会话快照。
  factory AcademicLoginSessionSnapshot.fromJson(Map<String, Object?> payload) {
    final rawCookieHeaders = payload['cookieHeadersByHost'];
    if (rawCookieHeaders is! Map) {
      throw const FormatException('OA 登录会话缺少 Cookie 作用域');
    }

    final cookieHeadersByHost = <String, String>{};
    for (final entry in rawCookieHeaders.entries) {
      final host = entry.key.toString().trim().toLowerCase();
      final cookieHeader = entry.value?.toString().trim() ?? '';
      if (host.isEmpty || cookieHeader.isEmpty) continue;
      cookieHeadersByHost[host] = cookieHeader;
    }

    final authenticatedAt = DateTime.parse(
      payload['authenticatedAt']?.toString() ?? '',
    );
    return AcademicLoginSessionSnapshot(
      cookieHeadersByHost: Map.unmodifiable(cookieHeadersByHost),
      authenticatedAt: authenticatedAt,
      entranceUri: Uri.parse(payload['entranceUri']?.toString() ?? ''),
      finalUri: Uri.parse(payload['finalUri']?.toString() ?? ''),
    );
  }
}

/// 本专科教务系统 OA 登录校验状态。
enum AcademicLoginValidationStatus {
  /// 登录校验通过，CAS 已跳转到 OA / 本专科教务入口。
  success,

  /// 未保存 OA 账号。
  missingOaAccount,

  /// 未保存 OA 密码。
  missingOaPassword,

  /// 校园网 / VPN 前置检测不可达。
  campusNetworkUnavailable,

  /// CAS 登录页无法打开或关键字段缺失。
  loginPageUnavailable,

  /// 账号或密码未通过 CAS 校验。
  credentialsRejected,

  /// CAS 要求图形验证码，不能继续无交互校验。
  captchaRequired,

  /// CAS 要求 MFA / 安全验证，不能继续无交互校验。
  additionalVerificationRequired,

  /// 登录跳转链路和预期不一致。
  webFlowChanged,

  /// 网络请求失败或超时。
  networkError,

  /// 未归类异常。
  unexpectedError,
}

/// 本专科教务系统 OA 登录只读校验结果。
class AcademicLoginValidationResult {
  const AcademicLoginValidationResult({
    required this.status,
    required this.message,
    required this.detail,
    required this.checkedAt,
    required this.entranceUri,
    this.finalUri,
    this.campusNetworkStatus,
    this.sessionSnapshot,
  });

  /// 结构化状态，用于 UI 决定成功、警告或错误展示。
  final AcademicLoginValidationStatus status;

  /// 面向用户的简短说明，不包含账号或密码。
  final String message;

  /// 面向排查的安全详情，不包含 Cookie、Ticket、密码等敏感值。
  final String detail;

  /// 本次校验完成时间。
  final DateTime checkedAt;

  /// 本专科教务系统入口地址。
  final Uri entranceUri;

  /// 校验结束时停留的最终地址；只用于判断流程，不展示凭据。
  final Uri? finalUri;

  /// 校园网 / VPN 前置检测结果。
  final CampusNetworkStatus? campusNetworkStatus;

  /// 登录成功后保存的身份信息快照；失败结果始终为空。
  final AcademicLoginSessionSnapshot? sessionSnapshot;

  /// 是否通过登录校验。
  bool get isSuccess => status == AcademicLoginValidationStatus.success;
}
