/*
 * OA/CAS 登录表单结构 — 组装只读登录校验所需字段
 * @Project : SSPU-all-in-one
 * @File : academic_login_form.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'academic_login_validation_service.dart';

class _CasLoginForm {
  const _CasLoginForm({
    required this.actionUri,
    required this.execution,
    required this.failN,
    required this.mfaState,
  });

  final Uri actionUri;
  final String execution;
  final String failN;
  final String mfaState;

  bool get requiresCaptcha {
    final failedCount = int.tryParse(failN);
    return failedCount != null && failedCount >= 3;
  }

  bool get requiresAdditionalVerification => mfaState.isNotEmpty;

  Map<String, String> toFields({
    required String oaAccount,
    required String encryptedPassword,
  }) {
    return {
      'username': oaAccount,
      'password': '__RSA__$encryptedPassword',
      'captcha': '',
      'rememberMe': 'false',
      'currentMenu': '1',
      'failN': failN.isEmpty ? '-1' : failN,
      'mfaState': mfaState,
      'execution': execution,
      '_eventId': 'submit',
      'geolocation': '',
      'fpVisitorId': '',
    };
  }
}
