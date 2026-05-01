/*
 * 学校邮箱服务内部结构 — 凭据读取结果与文本兜底扩展
 * @Project : SSPU-all-in-one
 * @File : email_support.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'email_service.dart';

class _EmailCredentials {
  const _EmailCredentials.success({
    required this.account,
    required this.password,
  }) : status = null,
       message = null,
       detail = null;

  const _EmailCredentials.failure({
    required this.status,
    required this.message,
    required this.detail,
  }) : account = '',
       password = '';

  final String account;
  final String password;
  final EmailQueryStatus? status;
  final String? message;
  final String? detail;

  bool get isSuccess => status == null;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
