/*
 * 学校邮箱服务 — 通过 IMAP / POP 只读收信，并用 SMTP 做登录校验
 * @Project : SSPU-all-in-one
 * @File : email_service.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/academic_credentials.dart';
import '../models/email_mailbox.dart';
import 'academic_credentials_service.dart';
import 'storage_service.dart';

part 'email_gateway.dart';
part 'email_support.dart';

/// 邮箱页面依赖的只读查询接口，便于 widget 测试替换。
abstract class EmailMailboxClient {
  /// 通过 IMAP 或 POP 读取最近邮件；SMTP 不允许用于收信。
  Future<EmailMailboxQueryResult> fetchMessages({
    required EmailProtocol protocol,
    int messageCount = 10,
  });

  /// 校验指定协议的登录状态；SMTP 只允许执行认证，不发送邮件。
  Future<EmailLoginValidationResult> validateLogin(EmailProtocol protocol);
}

/// 可替换的邮箱协议网关。
abstract class EmailGateway {
  /// 使用 IMAP 只读读取最近邮件。
  Future<List<EmailMessageSnapshot>> fetchImapMessages({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required int messageCount,
    required Duration timeout,
  });

  /// 使用 POP 只读读取最近邮件。
  Future<List<EmailMessageSnapshot>> fetchPopMessages({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required int messageCount,
    required Duration timeout,
  });

  /// 仅校验 IMAP 登录状态，不读取邮件正文。
  Future<void> validateImapLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  });

  /// 仅校验 POP 登录状态，不读取邮件正文。
  Future<void> validatePopLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  });

  /// 仅校验 SMTP 认证，不发送任何邮件。
  Future<void> validateSmtpLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  });
}

/// 学校邮箱只读服务。
class EmailService implements EmailMailboxClient {
  EmailService({
    AcademicCredentialsService? credentialsService,
    EmailGateway? gateway,
    EmailServerEndpoint? imapEndpoint,
    EmailServerEndpoint? popEndpoint,
    EmailServerEndpoint? smtpEndpoint,
    Duration? timeout,
  }) : _credentialsService =
           credentialsService ?? AcademicCredentialsService.instance,
       _gateway = gateway ?? EnoughMailGateway(),
       imapEndpoint = imapEndpoint ?? defaultImapEndpoint,
       popEndpoint = popEndpoint ?? defaultPopEndpoint,
       smtpEndpoint = smtpEndpoint ?? defaultSmtpEndpoint,
       timeout = timeout ?? const Duration(seconds: 20);

  /// 全局单例。
  static final EmailService instance = EmailService();

  /// 学校邮箱默认域名。
  static const String defaultDomain = 'sspu.edu.cn';

  /// 腾讯企业邮箱 IMAP SSL 端点。
  static const EmailServerEndpoint defaultImapEndpoint = EmailServerEndpoint(
    host: 'imap.exmail.qq.com',
    port: 993,
    isSecure: true,
  );

  /// 腾讯企业邮箱 POP SSL 端点。
  static const EmailServerEndpoint defaultPopEndpoint = EmailServerEndpoint(
    host: 'pop.exmail.qq.com',
    port: 995,
    isSecure: true,
  );

  /// 腾讯企业邮箱 SMTP SSL 端点；仅用于 AUTH 校验。
  static const EmailServerEndpoint defaultSmtpEndpoint = EmailServerEndpoint(
    host: 'smtp.exmail.qq.com',
    port: 465,
    isSecure: true,
  );

  /// 学校邮箱默认自动刷新间隔，单位分钟。
  static const int defaultAutoRefreshIntervalMinutes = 30;

  final AcademicCredentialsService _credentialsService;
  final EmailGateway _gateway;

  /// IMAP 只读收信端点。
  final EmailServerEndpoint imapEndpoint;

  /// POP 只读收信端点。
  final EmailServerEndpoint popEndpoint;

  /// SMTP 登录校验端点。
  final EmailServerEndpoint smtpEndpoint;

  /// 单次协议步骤超时时间。
  final Duration timeout;

  /// 读取学校邮箱自动刷新开关。
  Future<bool> isAutoRefreshEnabled() async {
    return StorageService.getBool(StorageKeys.emailAutoRefreshEnabled);
  }

  /// 保存学校邮箱自动刷新开关。
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    await StorageService.setBool(StorageKeys.emailAutoRefreshEnabled, enabled);
  }

  /// 读取学校邮箱自动刷新间隔。
  Future<int> getAutoRefreshIntervalMinutes() async {
    final stored = await StorageService.getInt(
      StorageKeys.emailAutoRefreshIntervalMinutes,
    );
    return _normalizeAutoRefreshInterval(
      stored ?? defaultAutoRefreshIntervalMinutes,
    );
  }

  /// 保存学校邮箱自动刷新间隔。
  Future<void> setAutoRefreshIntervalMinutes(int minutes) async {
    await StorageService.setInt(
      StorageKeys.emailAutoRefreshIntervalMinutes,
      _normalizeAutoRefreshInterval(minutes),
    );
  }

  /// 将邮箱用户名规范化为完整地址；已填写域名时保持原值。
  static String normalizeEmailAccount(String account) {
    final trimmedAccount = account.trim();
    if (trimmedAccount.isEmpty || trimmedAccount.contains('@')) {
      return trimmedAccount;
    }

    return '$trimmedAccount@$defaultDomain';
  }

  @override
  Future<EmailMailboxQueryResult> fetchMessages({
    required EmailProtocol protocol,
    int messageCount = 10,
  }) async {
    final endpoint = endpointFor(protocol);
    if (protocol == EmailProtocol.smtp) {
      return _buildMailboxResult(
        status: EmailQueryStatus.loginRejected,
        protocol: protocol,
        endpoint: endpoint,
        message: 'SMTP 不支持收信',
        detail: 'SMTP 在本应用中仅用于认证与连通性校验，不提供发送或收信入口。',
      );
    }

    final credentials = await _readCredentials();
    if (!credentials.isSuccess) {
      return _buildMailboxResult(
        status: credentials.status!,
        protocol: protocol,
        endpoint: endpoint,
        message: credentials.message!,
        detail: credentials.detail!,
      );
    }

    try {
      final safeMessageCount = messageCount.clamp(1, 30);
      final messages = switch (protocol) {
        EmailProtocol.imap => await _gateway.fetchImapMessages(
          endpoint: endpoint,
          account: credentials.account,
          password: credentials.password,
          messageCount: safeMessageCount,
          timeout: timeout,
        ),
        EmailProtocol.pop => await _gateway.fetchPopMessages(
          endpoint: endpoint,
          account: credentials.account,
          password: credentials.password,
          messageCount: safeMessageCount,
          timeout: timeout,
        ),
        EmailProtocol.smtp => const <EmailMessageSnapshot>[],
      };
      final fetchedAt = DateTime.now();
      return _buildMailboxResult(
        status: EmailQueryStatus.success,
        protocol: protocol,
        endpoint: endpoint,
        message: '${protocol.label} 邮件读取完成',
        detail: '已通过只读协议读取最近 ${messages.length} 封邮件。',
        checkedAt: fetchedAt,
        snapshot: EmailMailboxSnapshot(
          protocol: protocol,
          account: credentials.account,
          messages: messages,
          fetchedAt: fetchedAt,
          endpoint: endpoint,
        ),
      );
    } on TimeoutException {
      return _networkFailure(protocol, endpoint, '邮箱服务器响应超时');
    } on SocketException {
      return _networkFailure(protocol, endpoint, '邮箱服务器网络连接失败');
    } on HandshakeException {
      return _networkFailure(protocol, endpoint, '邮箱服务器 TLS 握手失败');
    } on ImapException {
      return _loginRejected(protocol, endpoint);
    } on PopException {
      return _loginRejected(protocol, endpoint);
    } on FormatException {
      return _buildMailboxResult(
        status: EmailQueryStatus.parseFailed,
        protocol: protocol,
        endpoint: endpoint,
        message: '邮件内容解析失败',
        detail: '邮箱服务器返回了无法解析为 MIME 邮件的内容。',
      );
    } catch (error) {
      return _buildMailboxResult(
        status: EmailQueryStatus.unexpectedError,
        protocol: protocol,
        endpoint: endpoint,
        message: '邮箱读取失败',
        detail: '未归类异常类型：${error.runtimeType}',
      );
    }
  }

  @override
  Future<EmailLoginValidationResult> validateLogin(
    EmailProtocol protocol,
  ) async {
    final endpoint = endpointFor(protocol);
    final credentials = await _readCredentials();
    if (!credentials.isSuccess) {
      return _buildValidationResult(
        status: credentials.status!,
        protocol: protocol,
        endpoint: endpoint,
        message: credentials.message!,
        detail: credentials.detail!,
      );
    }

    try {
      switch (protocol) {
        case EmailProtocol.imap:
          await _gateway.validateImapLogin(
            endpoint: endpoint,
            account: credentials.account,
            password: credentials.password,
            timeout: timeout,
          );
          break;
        case EmailProtocol.pop:
          await _gateway.validatePopLogin(
            endpoint: endpoint,
            account: credentials.account,
            password: credentials.password,
            timeout: timeout,
          );
          break;
        case EmailProtocol.smtp:
          await _gateway.validateSmtpLogin(
            endpoint: endpoint,
            account: credentials.account,
            password: credentials.password,
            timeout: timeout,
          );
          break;
      }

      return _buildValidationResult(
        status: EmailQueryStatus.success,
        protocol: protocol,
        endpoint: endpoint,
        message: '${protocol.label} 登录校验通过',
        detail: protocol == EmailProtocol.smtp
            ? 'SMTP 仅完成认证与连通性校验，未发送邮件。'
            : '${protocol.label} 已完成登录校验，未修改邮件状态。',
      );
    } on TimeoutException {
      return _validationNetworkFailure(protocol, endpoint, '邮箱服务器响应超时');
    } on SocketException {
      return _validationNetworkFailure(protocol, endpoint, '邮箱服务器网络连接失败');
    } on HandshakeException {
      return _validationNetworkFailure(protocol, endpoint, '邮箱服务器 TLS 握手失败');
    } on ImapException {
      return _validationLoginRejected(protocol, endpoint);
    } on PopException {
      return _validationLoginRejected(protocol, endpoint);
    } on SmtpException {
      return _validationLoginRejected(protocol, endpoint);
    } catch (error) {
      return _buildValidationResult(
        status: EmailQueryStatus.unexpectedError,
        protocol: protocol,
        endpoint: endpoint,
        message: '邮箱登录校验失败',
        detail: '未归类异常类型：${error.runtimeType}',
      );
    }
  }

  /// 返回协议对应的默认服务端点。
  EmailServerEndpoint endpointFor(EmailProtocol protocol) {
    return switch (protocol) {
      EmailProtocol.imap => imapEndpoint,
      EmailProtocol.pop => popEndpoint,
      EmailProtocol.smtp => smtpEndpoint,
    };
  }

  int _normalizeAutoRefreshInterval(int minutes) {
    return minutes <= 0 ? defaultAutoRefreshIntervalMinutes : minutes;
  }

  Future<_EmailCredentials> _readCredentials() async {
    final status = await _credentialsService.getStatus();
    final account = normalizeEmailAccount(status.emailAccount);
    if (account.isEmpty) {
      return const _EmailCredentials.failure(
        status: EmailQueryStatus.missingEmailAccount,
        message: '请先保存学校邮箱账号',
        detail: '学校邮箱可填写完整地址，也可只填写 @sspu.edu.cn 前的用户名。',
      );
    }

    final password = await _credentialsService.readSecret(
      AcademicCredentialSecret.emailPassword,
    );
    if (password == null || password.isEmpty) {
      return const _EmailCredentials.failure(
        status: EmailQueryStatus.missingEmailPassword,
        message: '请先保存邮箱密码',
        detail: '邮箱系统使用邮箱密码，不要求 OA 密码。',
      );
    }

    return _EmailCredentials.success(account: account, password: password);
  }

  EmailMailboxQueryResult _networkFailure(
    EmailProtocol protocol,
    EmailServerEndpoint endpoint,
    String message,
  ) {
    return _buildMailboxResult(
      status: EmailQueryStatus.networkError,
      protocol: protocol,
      endpoint: endpoint,
      message: message,
      detail: '${protocol.label} 端点 ${endpoint.host}:${endpoint.port} 无法完成连接。',
    );
  }

  EmailMailboxQueryResult _loginRejected(
    EmailProtocol protocol,
    EmailServerEndpoint endpoint,
  ) {
    return _buildMailboxResult(
      status: EmailQueryStatus.loginRejected,
      protocol: protocol,
      endpoint: endpoint,
      message: '${protocol.label} 登录或只读查询被拒绝',
      detail: '请确认邮箱账号、邮箱密码和 ${protocol.label} 客户端协议已启用。',
    );
  }

  EmailLoginValidationResult _validationNetworkFailure(
    EmailProtocol protocol,
    EmailServerEndpoint endpoint,
    String message,
  ) {
    return _buildValidationResult(
      status: EmailQueryStatus.networkError,
      protocol: protocol,
      endpoint: endpoint,
      message: message,
      detail: '${protocol.label} 端点 ${endpoint.host}:${endpoint.port} 无法完成连接。',
    );
  }

  EmailLoginValidationResult _validationLoginRejected(
    EmailProtocol protocol,
    EmailServerEndpoint endpoint,
  ) {
    return _buildValidationResult(
      status: EmailQueryStatus.loginRejected,
      protocol: protocol,
      endpoint: endpoint,
      message: '${protocol.label} 登录校验未通过',
      detail: '请确认邮箱账号、邮箱密码和 ${protocol.label} 客户端协议已启用。',
    );
  }

  EmailMailboxQueryResult _buildMailboxResult({
    required EmailQueryStatus status,
    required EmailProtocol protocol,
    required EmailServerEndpoint endpoint,
    required String message,
    required String detail,
    DateTime? checkedAt,
    EmailMailboxSnapshot? snapshot,
  }) {
    return EmailMailboxQueryResult(
      status: status,
      protocol: protocol,
      message: message,
      detail: detail,
      checkedAt: checkedAt ?? DateTime.now(),
      endpoint: endpoint,
      snapshot: snapshot,
    );
  }

  EmailLoginValidationResult _buildValidationResult({
    required EmailQueryStatus status,
    required EmailProtocol protocol,
    required EmailServerEndpoint endpoint,
    required String message,
    required String detail,
  }) {
    return EmailLoginValidationResult(
      status: status,
      protocol: protocol,
      message: message,
      detail: detail,
      checkedAt: DateTime.now(),
      endpoint: endpoint,
    );
  }
}
