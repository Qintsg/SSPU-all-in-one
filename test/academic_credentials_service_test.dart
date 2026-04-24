/*
 * 教务凭据安全存储服务测试 — 校验本地可解密凭据的保存与清除语义
 * @Project : SSPU-all-in-one
 * @File : academic_credentials_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-24
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/academic_credentials.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';

void main() {
  final service = AcademicCredentialsService.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('保存教务凭据后返回账号与密码填写状态', () async {
    await service.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
      sportsQueryPassword: 'sports-pass',
      emailPassword: 'mail-pass',
    );

    final status = await service.getStatus();

    expect(status.oaAccount, '20260001');
    expect(status.hasOaPassword, isTrue);
    expect(status.hasSportsQueryPassword, isTrue);
    expect(status.hasEmailPassword, isTrue);
    expect(
      await service.readSecret(AcademicCredentialSecret.oaPassword),
      'oa-pass',
    );
  });

  test('空密码输入不会覆盖已有密码', () async {
    await service.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
      sportsQueryPassword: 'sports-pass',
      emailPassword: 'mail-pass',
    );

    await service.saveCredentials(
      oaAccount: '20260002',
      oaPassword: null,
      sportsQueryPassword: null,
      emailPassword: null,
    );

    final status = await service.getStatus();

    expect(status.oaAccount, '20260002');
    expect(status.hasOaPassword, isTrue);
    expect(
      await service.readSecret(AcademicCredentialSecret.oaPassword),
      'oa-pass',
    );
    expect(
      await service.readSecret(AcademicCredentialSecret.sportsQueryPassword),
      'sports-pass',
    );
    expect(
      await service.readSecret(AcademicCredentialSecret.emailPassword),
      'mail-pass',
    );
  });

  test('可以单独清除指定密码字段', () async {
    await service.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
      sportsQueryPassword: 'sports-pass',
      emailPassword: 'mail-pass',
    );

    await service.clearSecret(AcademicCredentialSecret.sportsQueryPassword);

    final status = await service.getStatus();

    expect(status.hasOaPassword, isTrue);
    expect(status.hasSportsQueryPassword, isFalse);
    expect(status.hasEmailPassword, isTrue);
    expect(
      await service.readSecret(AcademicCredentialSecret.sportsQueryPassword),
      isNull,
    );
  });

  test('清除所有教务凭据时逐项删除安全存储键', () async {
    await service.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
      sportsQueryPassword: 'sports-pass',
      emailPassword: 'mail-pass',
    );

    await service.clearAll();

    final status = await service.getStatus();

    expect(status.oaAccount, isEmpty);
    expect(status.hasOaPassword, isFalse);
    expect(status.hasSportsQueryPassword, isFalse);
    expect(status.hasEmailPassword, isFalse);
  });
}
