/*
 * 学校邮箱协议网关 — 封装 IMAP / POP / SMTP 只读与认证边界
 * @Project : SSPU-all-in-one
 * @File : email_gateway.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'email_service.dart';

/// enough_mail 低层协议适配器，封装只读命令边界。
class EnoughMailGateway implements EmailGateway {
  @override
  Future<List<EmailMessageSnapshot>> fetchImapMessages({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required int messageCount,
    required Duration timeout,
  }) async {
    final client = ImapClient(defaultResponseTimeout: timeout);
    try {
      await client.connectToServer(
        endpoint.host,
        endpoint.port,
        isSecure: endpoint.isSecure,
        timeout: timeout,
      );
      await client.login(account, password).timeout(timeout);
      final inbox = await _findInboxMailbox(client, timeout);
      await client.examineMailbox(inbox).timeout(timeout);
      final fetchResult = await client.fetchRecentMessages(
        messageCount: messageCount,
        criteria: '(FLAGS BODY.PEEK[])',
        responseTimeout: timeout,
      );

      return _buildSnapshots(
        protocol: EmailProtocol.imap,
        messages: fetchResult.messages.reversed.take(messageCount),
      );
    } finally {
      await _logoutImapSilently(client);
    }
  }

  @override
  Future<List<EmailMessageSnapshot>> fetchPopMessages({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required int messageCount,
    required Duration timeout,
  }) async {
    final client = PopClient();
    try {
      await client.connectToServer(
        endpoint.host,
        endpoint.port,
        isSecure: endpoint.isSecure,
        timeout: timeout,
      );
      await client.login(account, password).timeout(timeout);
      final listings = await client.list().timeout(timeout);
      final recentListings = listings.reversed.take(messageCount).toList();
      final messages = <MimeMessage>[];
      for (final listing in recentListings) {
        messages.add(await client.retrieve(listing.id).timeout(timeout));
      }

      return _buildSnapshots(protocol: EmailProtocol.pop, messages: messages);
    } finally {
      await _quitPopSilently(client);
    }
  }

  @override
  Future<void> validateImapLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  }) async {
    final client = ImapClient(defaultResponseTimeout: timeout);
    try {
      await client.connectToServer(
        endpoint.host,
        endpoint.port,
        isSecure: endpoint.isSecure,
        timeout: timeout,
      );
      await client.login(account, password).timeout(timeout);
    } finally {
      await _logoutImapSilently(client);
    }
  }

  @override
  Future<void> validatePopLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  }) async {
    final client = PopClient();
    try {
      await client.connectToServer(
        endpoint.host,
        endpoint.port,
        isSecure: endpoint.isSecure,
        timeout: timeout,
      );
      await client.login(account, password).timeout(timeout);
    } finally {
      await _quitPopSilently(client);
    }
  }

  @override
  Future<void> validateSmtpLogin({
    required EmailServerEndpoint endpoint,
    required String account,
    required String password,
    required Duration timeout,
  }) async {
    final client = SmtpClient(EmailService.defaultDomain);
    try {
      await client.connectToServer(
        endpoint.host,
        endpoint.port,
        isSecure: endpoint.isSecure,
        timeout: timeout,
      );
      await client.ehlo().timeout(timeout);
      await client
          .authenticate(account, password, _preferredSmtpAuthMechanism(client))
          .timeout(timeout);
    } finally {
      await _quitSmtpSilently(client);
    }
  }

  Future<Mailbox> _findInboxMailbox(ImapClient client, Duration timeout) async {
    final mailboxes = await client.listMailboxes().timeout(timeout);
    for (final mailbox in mailboxes) {
      if (mailbox.isInbox || mailbox.path.toUpperCase() == 'INBOX') {
        return mailbox;
      }
    }

    return Mailbox(
      encodedName: 'INBOX',
      encodedPath: 'INBOX',
      pathSeparator: client.serverInfo.pathSeparator ?? '/',
      flags: [MailboxFlag.inbox],
    );
  }

  AuthMechanism _preferredSmtpAuthMechanism(SmtpClient client) {
    final serverInfo = client.serverInfo;
    if (serverInfo.supportsAuth(AuthMechanism.plain)) {
      return AuthMechanism.plain;
    }
    if (serverInfo.supportsAuth(AuthMechanism.login)) {
      return AuthMechanism.login;
    }
    if (serverInfo.supportsAuth(AuthMechanism.cramMd5)) {
      return AuthMechanism.cramMd5;
    }
    return AuthMechanism.plain;
  }

  List<EmailMessageSnapshot> _buildSnapshots({
    required EmailProtocol protocol,
    required Iterable<MimeMessage> messages,
  }) {
    var index = 0;
    return messages.map((message) {
      final snapshot = _buildSnapshot(protocol, message, index);
      index++;
      return snapshot;
    }).toList();
  }

  EmailMessageSnapshot _buildSnapshot(
    EmailProtocol protocol,
    MimeMessage message,
    int index,
  ) {
    final sender = message.from?.isNotEmpty == true
        ? message.from!.first
        : null;
    final body = _extractBodyText(message);
    return EmailMessageSnapshot(
      id: _messageId(protocol, message, index),
      subject: _normalizeText(message.decodeSubject() ?? '').ifEmpty('无主题'),
      senderName: _normalizeText(sender?.personalName ?? ''),
      senderAddress: _normalizeText(sender?.email ?? '未知发件人'),
      receivedAt: message.decodeDate(),
      preview: _buildPreview(body),
      body: body,
    );
  }

  String _messageId(EmailProtocol protocol, MimeMessage message, int index) {
    final headerMessageId = message.getHeaderValue('message-id')?.trim();
    if (headerMessageId != null && headerMessageId.isNotEmpty) {
      return '${protocol.label}:$headerMessageId';
    }
    final uid = message.uid ?? message.sequenceId;
    return '${protocol.label}:${uid ?? index}';
  }

  String _extractBodyText(MimeMessage message) {
    final plainText = message.decodeTextPlainPart();
    if (plainText != null && plainText.trim().isNotEmpty) {
      return _normalizeText(plainText);
    }

    final htmlText = message.decodeTextHtmlPart();
    if (htmlText == null || htmlText.trim().isEmpty) return '';
    return _normalizeText(html_parser.parse(htmlText).body?.text ?? htmlText);
  }

  String _buildPreview(String body) {
    if (body.isEmpty) return '无正文摘要';
    if (body.length <= 140) return body;
    return '${body.substring(0, 140)}...';
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _logoutImapSilently(ImapClient client) async {
    try {
      if (client.isLoggedIn) await client.logout();
    } catch (_) {
      // 登出失败不改变主操作结果；随后仍会关闭 socket。
    }
    await client.disconnect();
  }

  Future<void> _quitPopSilently(PopClient client) async {
    try {
      if (client.isLoggedIn) await client.quit();
    } catch (_) {
      // POP 未执行 delete，quit 仅结束会话；失败后直接关闭连接。
    }
    await client.disconnect();
  }

  Future<void> _quitSmtpSilently(SmtpClient client) async {
    try {
      if (client.isLoggedIn) await client.quit();
    } catch (_) {
      // SMTP 仅完成认证校验，不发送邮件；退出失败时关闭连接即可。
    }
    await client.disconnect();
  }
}
