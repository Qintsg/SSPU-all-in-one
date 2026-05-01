/*
 * 学校邮箱模型 — 描述只读收信与协议登录校验结果
 * @Project : SSPU-all-in-one
 * @File : email_mailbox.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

/// 学校邮箱支持的协议类型。
enum EmailProtocol {
  /// IMAP 只读收信协议。
  imap,

  /// POP 只读收信协议。
  pop,

  /// SMTP 仅用于登录认证与连通性校验。
  smtp,
}

/// 邮箱协议展示名称。
extension EmailProtocolLabel on EmailProtocol {
  /// 用户可读的协议名称。
  String get label {
    return switch (this) {
      EmailProtocol.imap => 'IMAP',
      EmailProtocol.pop => 'POP',
      EmailProtocol.smtp => 'SMTP',
    };
  }
}

/// 邮箱只读查询或协议校验状态。
enum EmailQueryStatus {
  /// 操作成功。
  success,

  /// 未保存学校邮箱账号。
  missingEmailAccount,

  /// 未保存学校邮箱密码。
  missingEmailPassword,

  /// 邮箱服务器拒绝登录或协议未启用。
  loginRejected,

  /// 邮箱内容解析失败。
  parseFailed,

  /// 网络连接、TLS 握手或超时失败。
  networkError,

  /// 未归类异常。
  unexpectedError,
}

/// 邮箱服务端点配置。
class EmailServerEndpoint {
  const EmailServerEndpoint({
    required this.host,
    required this.port,
    required this.isSecure,
  });

  /// 邮箱服务器域名。
  final String host;

  /// 邮箱服务端口。
  final int port;

  /// 是否从连接建立时即使用 TLS。
  final bool isSecure;
}

/// 单封邮件的只读展示快照。
class EmailMessageSnapshot {
  const EmailMessageSnapshot({
    required this.id,
    required this.subject,
    required this.senderName,
    required this.senderAddress,
    required this.preview,
    required this.body,
    this.receivedAt,
  });

  /// 邮件在当前协议结果中的稳定展示标识，不用于服务器写操作。
  final String id;

  /// 邮件标题，缺失时由服务层填充兜底文案。
  final String subject;

  /// 发件人显示名。
  final String senderName;

  /// 发件人邮箱地址。
  final String senderAddress;

  /// 正文摘要，便于列表快速浏览。
  final String preview;

  /// 已解析的正文文本，可能为空字符串。
  final String body;

  /// 邮件头中的发送时间。
  final DateTime? receivedAt;
}

/// 邮箱一次只读收信快照。
class EmailMailboxSnapshot {
  const EmailMailboxSnapshot({
    required this.protocol,
    required this.account,
    required this.messages,
    required this.fetchedAt,
    required this.endpoint,
  });

  /// 本次读取使用的协议。
  final EmailProtocol protocol;

  /// 规范化后的邮箱账号。
  final String account;

  /// 最近邮件列表，按新到旧展示。
  final List<EmailMessageSnapshot> messages;

  /// 本地读取完成时间。
  final DateTime fetchedAt;

  /// 本次读取使用的服务端点。
  final EmailServerEndpoint endpoint;
}

/// 邮箱只读收信结果。
class EmailMailboxQueryResult {
  const EmailMailboxQueryResult({
    required this.status,
    required this.protocol,
    required this.message,
    required this.detail,
    required this.checkedAt,
    required this.endpoint,
    this.snapshot,
  });

  /// 结构化状态，用于 UI 判断提示等级。
  final EmailQueryStatus status;

  /// 本次操作使用的协议。
  final EmailProtocol protocol;

  /// 面向用户的简短说明，不包含邮箱密码。
  final String message;

  /// 安全排查详情，不包含账号密码原文。
  final String detail;

  /// 本次操作完成时间。
  final DateTime checkedAt;

  /// 本次操作使用的服务端点。
  final EmailServerEndpoint endpoint;

  /// 成功读取时的邮件快照。
  final EmailMailboxSnapshot? snapshot;

  /// 是否操作成功。
  bool get isSuccess => status == EmailQueryStatus.success;
}

/// 邮箱协议登录校验结果。
class EmailLoginValidationResult {
  const EmailLoginValidationResult({
    required this.status,
    required this.protocol,
    required this.message,
    required this.detail,
    required this.checkedAt,
    required this.endpoint,
  });

  /// 结构化状态，用于 UI 判断提示等级。
  final EmailQueryStatus status;

  /// 本次校验使用的协议。
  final EmailProtocol protocol;

  /// 面向用户的简短说明，不包含邮箱密码。
  final String message;

  /// 安全排查详情，不包含账号密码原文。
  final String detail;

  /// 本次校验完成时间。
  final DateTime checkedAt;

  /// 本次校验使用的服务端点。
  final EmailServerEndpoint endpoint;

  /// 是否校验成功。
  bool get isSuccess => status == EmailQueryStatus.success;
}
