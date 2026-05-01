/*
 * 学校邮箱服务测试 — 校验凭据读取、协议边界与账号规范化
 * @Project : SSPU-all-in-one
 * @File : email_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/email_mailbox.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/email_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    StorageService.debugUseSharedPreferencesStorageForTesting(true);
  });

  tearDown(() {
    StorageService.debugUseSharedPreferencesStorageForTesting(null);
    SharedPreferences.setMockInitialValues({});
  });

  test('邮箱自动刷新设置默认关闭并可持久化间隔', () async {
    final service = EmailService(gateway: _FakeEmailGateway());

    expect(await service.isAutoRefreshEnabled(), isFalse);
    expect(
      await service.getAutoRefreshIntervalMinutes(),
      EmailService.defaultAutoRefreshIntervalMinutes,
    );

    await service.setAutoRefreshEnabled(true);
    await service.setAutoRefreshIntervalMinutes(60);

    expect(await service.isAutoRefreshEnabled(), isTrue);
    expect(await service.getAutoRefreshIntervalMinutes(), 60);
  });

  test('未保存学工号时不访问邮箱协议网关', () async {
    final gateway = _FakeEmailGateway();
    final service = EmailService(gateway: gateway);

    final result = await service.fetchMessages(protocol: EmailProtocol.imap);

    expect(result.status, EmailQueryStatus.missingEmailAccount);
    expect(gateway.fetchImapCount, 0);
  });

  test('未保存邮箱密码时停止只读收信', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
    );
    final gateway = _FakeEmailGateway();
    final service = EmailService(gateway: gateway);

    final result = await service.fetchMessages(protocol: EmailProtocol.pop);

    expect(result.status, EmailQueryStatus.missingEmailPassword);
    expect(gateway.fetchPopCount, 0);
  });

  test('IMAP 只读收信会由学工号派生邮箱账号并返回邮件快照', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      emailPassword: 'mail-pass',
    );
    final gateway = _FakeEmailGateway(messages: [_mailSnapshot]);
    final service = EmailService(gateway: gateway);

    final result = await service.fetchMessages(protocol: EmailProtocol.imap);

    expect(result.status, EmailQueryStatus.success);
    expect(gateway.fetchImapCount, 1);
    expect(gateway.lastAccount, '20260001@sspu.edu.cn');
    expect(result.snapshot?.messages.single.subject, '教务通知');
  });

  test('SMTP 仅允许登录校验不允许收信', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      emailPassword: 'mail-pass',
    );
    final gateway = _FakeEmailGateway();
    final service = EmailService(gateway: gateway);

    final fetchResult = await service.fetchMessages(
      protocol: EmailProtocol.smtp,
    );
    final validationResult = await service.validateLogin(EmailProtocol.smtp);

    expect(fetchResult.status, EmailQueryStatus.loginRejected);
    expect(validationResult.status, EmailQueryStatus.success);
    expect(gateway.validateSmtpCount, 1);
    expect(gateway.fetchImapCount + gateway.fetchPopCount, 0);
  });
}

class _FakeEmailGateway implements EmailGateway {
  _FakeEmailGateway({this.messages = const []});

  final List<EmailMessageSnapshot> messages;
  int fetchImapCount = 0;
  int fetchPopCount = 0;
  int validateSmtpCount = 0;
  String? lastAccount;

  @override
  Future<List<EmailMessageSnapshot>> fetchImapMessages({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required int messageCount,
    required Duration timeout,
  }) async {
    fetchImapCount++;
    lastAccount = account;
    return messages;
  }

  @override
  Future<List<EmailMessageSnapshot>> fetchPopMessages({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required int messageCount,
    required Duration timeout,
  }) async {
    fetchPopCount++;
    lastAccount = account;
    return messages;
  }

  @override
  Future<void> validateImapLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  }) async {
    lastAccount = account;
  }

  @override
  Future<void> validatePopLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  }) async {
    lastAccount = account;
  }

  @override
  Future<void> validateSmtpLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  }) async {
    validateSmtpCount++;
    lastAccount = account;
  }
}

const EmailMessageSnapshot _mailSnapshot = EmailMessageSnapshot(
  id: 'IMAP:1',
  subject: '教务通知',
  senderName: '教务处',
  senderAddress: 'notice@sspu.edu.cn',
  preview: '请查看最新通知。',
  body: '请查看最新通知。',
);
