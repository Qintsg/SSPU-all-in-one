/*
 * 教务凭据模型 — 描述 OA 账号及外部系统密码填写状态
 * @Project : SSPU-all-in-one
 * @File : academic_credentials.dart
 * @Author : Qintsg
 * @Date : 2026-04-24
 */

/// 可独立保存或清除的教务密码字段。
enum AcademicCredentialSecret {
  /// OA 账号密码。
  oaPassword,

  /// 体育部查询密码。
  sportsQueryPassword,

  /// 邮箱密码。
  emailPassword,
}

/// 教务凭据在设置页展示所需的状态快照。
class AcademicCredentialsStatus {
  /// OA 账号，也就是学工号。
  final String oaAccount;

  /// 由学工号派生的学校邮箱账号，格式为“学工号@sspu.edu.cn”。
  final String emailAccount;

  /// 是否已保存 OA 账号密码。
  final bool hasOaPassword;

  /// 是否已保存体育部查询密码。
  final bool hasSportsQueryPassword;

  /// 是否已保存邮箱密码。
  final bool hasEmailPassword;

  const AcademicCredentialsStatus({
    required this.oaAccount,
    required this.emailAccount,
    required this.hasOaPassword,
    required this.hasSportsQueryPassword,
    required this.hasEmailPassword,
  });

  /// 空状态，用于页面初始值和存储不可用时的保守展示。
  const AcademicCredentialsStatus.empty()
    : oaAccount = '',
      emailAccount = '',
      hasOaPassword = false,
      hasSportsQueryPassword = false,
      hasEmailPassword = false;

  /// 按字段查询密码是否已保存。
  bool hasSecret(AcademicCredentialSecret secret) {
    return switch (secret) {
      AcademicCredentialSecret.oaPassword => hasOaPassword,
      AcademicCredentialSecret.sportsQueryPassword => hasSportsQueryPassword,
      AcademicCredentialSecret.emailPassword => hasEmailPassword,
    };
  }
}
