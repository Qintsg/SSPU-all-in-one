/*
 * 学校邮箱页面测试 — 校验只读收信、正文详情与 SMTP 校验入口
 * @Project : SSPU-all-in-one
 * @File : email_page_test.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/email_mailbox.dart';
import 'package:sspu_all_in_one/pages/email_page.dart';
import 'package:sspu_all_in_one/services/email_service.dart';

/// 等待目标组件出现，覆盖异步收信和动画后的首帧。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  testWidgets('邮箱页面可读取 IMAP 邮件并进入正文详情', (tester) async {
    final service = _FakeEmailClient();
    await tester.pumpWidget(
      FluentApp(
        home: EmailPage(
          emailService: service,
          emailAutoRefreshEnabledOverride: false,
          emailAutoRefreshIntervalOverride: 30,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SSPU 邮箱只读收件箱'), findsOneWidget);
    expect(find.textContaining('SMTP 仅用于认证与连通性校验'), findsOneWidget);

    await tester.tap(find.text('读取最近邮件'));
    await pumpUntilFound(tester, find.text('教务通知'));

    expect(service.fetchCount, 1);
    expect(find.text('IMAP 最近邮件：1 封'), findsOneWidget);
    expect(find.text('教务处 <notice@sspu.edu.cn>'), findsOneWidget);

    await tester.ensureVisible(find.text('查看正文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看正文'));
    await tester.pumpAndSettle();

    expect(find.text('邮件正文'), findsOneWidget);
    expect(find.text('请查看最新通知。'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('邮箱页面可触发 SMTP 登录校验但不读取邮件', (tester) async {
    final service = _FakeEmailClient();
    await tester.pumpWidget(
      FluentApp(
        home: EmailPage(
          emailService: service,
          emailAutoRefreshEnabledOverride: false,
          emailAutoRefreshIntervalOverride: 30,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('校验 SMTP'));
    await pumpUntilFound(tester, find.text('SMTP 登录校验通过'));

    expect(service.validateCount, 1);
    expect(service.lastValidatedProtocol, EmailProtocol.smtp);
    expect(service.fetchCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('邮箱自动刷新开启时会主动读取 IMAP 邮件', (tester) async {
    final service = _FakeEmailClient();
    await tester.pumpWidget(
      FluentApp(
        home: EmailPage(
          emailService: service,
          emailAutoRefreshEnabledOverride: true,
          emailAutoRefreshIntervalOverride: 30,
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('教务通知'));

    expect(service.fetchCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
  });
}

class _FakeEmailClient implements EmailMailboxClient {
  int fetchCount = 0;
  int validateCount = 0;
  EmailProtocol? lastValidatedProtocol;

  @override
  Future<EmailMailboxQueryResult> fetchMessages({
    required EmailProtocol protocol,
    int messageCount = 10,
  }) async {
    fetchCount++;
    return EmailMailboxQueryResult(
      status: EmailQueryStatus.success,
      protocol: protocol,
      message: '${protocol.label} 邮件读取完成',
      detail: '已读取最近邮件。',
      checkedAt: DateTime(2026, 5, 1, 9, 30),
      endpoint: _endpoint,
      snapshot: EmailMailboxSnapshot(
        protocol: protocol,
        account: 'student@sspu.edu.cn',
        messages: const [_message],
        fetchedAt: DateTime(2026, 5, 1, 9, 30),
        endpoint: _endpoint,
      ),
    );
  }

  @override
  Future<EmailLoginValidationResult> validateLogin(
    EmailProtocol protocol,
  ) async {
    validateCount++;
    lastValidatedProtocol = protocol;
    return EmailLoginValidationResult(
      status: EmailQueryStatus.success,
      protocol: protocol,
      message: '${protocol.label} 登录校验通过',
      detail: protocol == EmailProtocol.smtp
          ? 'SMTP 仅完成认证与连通性校验，未发送邮件。'
          : '${protocol.label} 已完成登录校验，未修改邮件状态。',
      checkedAt: DateTime(2026, 5, 1, 9, 30),
      endpoint: _endpoint,
    );
  }
}

const EmailServerEndpoint _endpoint = EmailServerEndpoint(
  host: 'imap.exmail.qq.com',
  port: 993,
  isSecure: true,
);

const EmailMessageSnapshot _message = EmailMessageSnapshot(
  id: 'IMAP:1',
  subject: '教务通知',
  senderName: '教务处',
  senderAddress: 'notice@sspu.edu.cn',
  preview: '请查看最新通知。',
  body: '请查看最新通知。',
  receivedAt: null,
);
