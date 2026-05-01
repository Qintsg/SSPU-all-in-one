/*
 * 体育部考勤服务内部结构 — 登录表单字段组装
 * @Project : SSPU-all-in-one
 * @File : sports_attendance_support.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'sports_attendance_service.dart';

class _SportsLoginForm {
  const _SportsLoginForm({required this.actionUri, required this.hiddenFields});

  final Uri actionUri;
  final Map<String, String> hiddenFields;

  Map<String, String> toFields({
    required String studentId,
    required String sportsPassword,
  }) {
    return {
      ...hiddenFields,
      'dlljs': 'st',
      'txtuser': studentId,
      'txtpwd': sportsPassword,
      'btnok.x': '20',
      'btnok.y': '10',
    };
  }
}
