/*
 * 学校邮箱页面 — 只读查看最近邮件并校验协议登录状态
 * @Project : SSPU-all-in-one
 * @File : email_page.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/email_mailbox.dart';
import '../services/email_service.dart';
import '../theme/fluent_tokens.dart';

part 'email_message_detail_page.dart';

/// 学校邮箱只读页面。
class EmailPage extends StatefulWidget {
  /// 邮箱只读服务，测试中可替换为 fake。
  final EmailMailboxClient? emailService;

  /// 测试专用：覆盖学校邮箱自动刷新开关，避免读取真实本地设置。
  final bool? emailAutoRefreshEnabledOverride;

  /// 测试专用：覆盖学校邮箱自动刷新间隔。
  final int? emailAutoRefreshIntervalOverride;

  const EmailPage({
    super.key,
    this.emailService,
    this.emailAutoRefreshEnabledOverride,
    this.emailAutoRefreshIntervalOverride,
  });

  @override
  State<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  EmailProtocol _selectedProtocol = EmailProtocol.imap;
  EmailProtocol? _validatingProtocol;
  EmailMailboxQueryResult? _mailboxResult;
  EmailLoginValidationResult? _validationResult;
  bool _isFetchingMessages = false;
  bool _emailAutoRefreshEnabled = false;
  int _emailAutoRefreshIntervalMinutes =
      EmailService.defaultAutoRefreshIntervalMinutes;
  Timer? _emailAutoRefreshTimer;

  EmailMailboxClient get _emailService {
    return widget.emailService ?? EmailService.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadEmailAutoRefreshSettings();
  }

  @override
  void dispose() {
    _emailAutoRefreshTimer?.cancel();
    super.dispose();
  }

  /// 读取邮箱自动刷新设置；默认不主动访问邮箱系统。
  Future<void> _loadEmailAutoRefreshSettings() async {
    final enabled =
        widget.emailAutoRefreshEnabledOverride ??
        await EmailService.instance.isAutoRefreshEnabled();
    final interval =
        widget.emailAutoRefreshIntervalOverride ??
        await EmailService.instance.getAutoRefreshIntervalMinutes();
    if (!mounted) return;
    setState(() {
      _emailAutoRefreshEnabled = enabled;
      _emailAutoRefreshIntervalMinutes = interval;
    });
    _restartEmailAutoRefreshTimer();
    if (enabled) unawaited(_fetchMessages());
  }

  /// 使用当前选择的只读协议读取最近邮件。
  Future<void> _fetchMessages() async {
    if (_isFetchingMessages || _selectedProtocol == EmailProtocol.smtp) return;
    setState(() => _isFetchingMessages = true);

    final result = await _emailService.fetchMessages(
      protocol: _selectedProtocol,
      messageCount: 10,
    );
    if (!mounted) return;
    setState(() {
      _mailboxResult = result;
      _isFetchingMessages = false;
    });
  }

  /// 根据设置重建邮箱自动刷新定时器。
  void _restartEmailAutoRefreshTimer() {
    _emailAutoRefreshTimer?.cancel();
    _emailAutoRefreshTimer = null;
    if (!_emailAutoRefreshEnabled) return;
    final intervalMinutes = _emailAutoRefreshIntervalMinutes;
    if (intervalMinutes <= 0) return;
    _emailAutoRefreshTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _fetchMessages(),
    );
  }

  /// 校验指定协议登录状态；SMTP 只认证，不发送邮件。
  Future<void> _validateLogin(EmailProtocol protocol) async {
    if (_validatingProtocol != null || _isFetchingMessages) return;
    setState(() => _validatingProtocol = protocol);

    final result = await _emailService.validateLogin(protocol);
    if (!mounted) return;
    setState(() {
      _validationResult = result;
      _validatingProtocol = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('学校邮箱')),
      children: [
        _buildOverviewCard(context)
            .animate()
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        _buildProtocolCard(context)
            .animate(delay: 80.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: FluentSpacing.m),
        _buildMailboxSection(context)
            .animate(delay: 160.ms)
            .fadeIn(
              duration: FluentDuration.slow,
              curve: FluentEasing.decelerate,
            )
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }

  /// 构建页面说明，强调只读边界。
  Widget _buildOverviewCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    FluentIcons.mail,
                    color: theme.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: FluentSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SSPU 邮箱只读收件箱', style: theme.typography.bodyStrong),
                      const SizedBox(height: FluentSpacing.xxs),
                      Text(
                        '在设置页保存学工号和邮箱密码后，可通过 IMAP 或 POP 读取最近邮件。',
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.l),
            const InfoBar(
              title: Text('只读访问边界'),
              content: Text('本页面不会发送邮件、删除邮件、移动邮件或主动标记已读；SMTP 仅用于认证与连通性校验。'),
              severity: InfoBarSeverity.info,
              isLong: true,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建协议选择与登录校验操作区。
  Widget _buildProtocolCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('协议操作', style: theme.typography.bodyStrong),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              'IMAP 使用 BODY.PEEK[] 读取，POP 仅 RETR 最近邮件；SMTP 不提供发送入口。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: FluentSpacing.m),
            Wrap(
              spacing: FluentSpacing.s,
              runSpacing: FluentSpacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  child: ComboBox<EmailProtocol>(
                    value: _selectedProtocol,
                    items: const [
                      ComboBoxItem(
                        value: EmailProtocol.imap,
                        child: Text('IMAP 收信'),
                      ),
                      ComboBoxItem(
                        value: EmailProtocol.pop,
                        child: Text('POP 收信'),
                      ),
                    ],
                    onChanged: _isFetchingMessages
                        ? null
                        : (protocol) {
                            if (protocol == null) return;
                            setState(() => _selectedProtocol = protocol);
                          },
                  ),
                ),
                FilledButton(
                  onPressed: _isFetchingMessages ? null : _fetchMessages,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFetchingMessages) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: ProgressRing(strokeWidth: 2),
                        ),
                      ] else ...[
                        const Icon(FluentIcons.refresh, size: 14),
                      ],
                      const SizedBox(width: 6),
                      const Text('读取最近邮件'),
                    ],
                  ),
                ),
                for (final protocol in EmailProtocol.values)
                  Button(
                    onPressed:
                        _validatingProtocol == null && !_isFetchingMessages
                        ? () => _validateLogin(protocol)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_validatingProtocol == protocol) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          ),
                        ] else ...[
                          const Icon(FluentIcons.plug_connected, size: 14),
                        ],
                        const SizedBox(width: 6),
                        Text('校验 ${protocol.label}'),
                      ],
                    ),
                  ),
              ],
            ),
            if (_validationResult != null) ...[
              const SizedBox(height: FluentSpacing.m),
              InfoBar(
                title: Text(_validationResult!.message),
                content: Text(_validationResult!.detail),
                severity: _severityOf(_validationResult!.status),
                isLong: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建邮件读取结果和列表。
  Widget _buildMailboxSection(BuildContext context) {
    final result = _mailboxResult;
    if (_isFetchingMessages) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FluentSpacing.xl),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: ProgressRing(strokeWidth: 2),
              ),
              SizedBox(width: FluentSpacing.s),
              Text('正在读取最近邮件...'),
            ],
          ),
        ),
      );
    }

    if (result == null) {
      return InfoBar(
        title: const Text('尚未读取邮箱'),
        content: Text(
          _emailAutoRefreshEnabled
              ? '邮箱自动刷新已开启，等待下一次读取；也可点击“读取最近邮件”立即刷新。'
              : '选择 IMAP 或 POP 后点击“读取最近邮件”，也可以先校验各协议登录状态。',
        ),
        severity: InfoBarSeverity.info,
        isLong: true,
      );
    }

    if (!result.isSuccess || result.snapshot == null) {
      return InfoBar(
        title: Text(result.message),
        content: Text(result.detail),
        severity: _severityOf(result.status),
        isLong: true,
      );
    }

    final snapshot = result.snapshot!;
    final messages = snapshot.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${snapshot.protocol.label} 最近邮件：${messages.length} 封',
                  ),
                ),
                Text('上次刷新：${_formatDateTime(snapshot.fetchedAt)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        if (messages.isEmpty)
          const InfoBar(
            title: Text('暂无可展示邮件'),
            content: Text('邮箱协议登录成功，但最近邮件列表为空。'),
            severity: InfoBarSeverity.info,
            isLong: true,
          )
        else
          ...messages.map(_buildMessageCard),
      ],
    );
  }

  /// 构建单封邮件摘要卡片。
  Widget _buildMessageCard(EmailMessageSnapshot message) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FluentSpacing.s),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(FluentSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.subject,
                      style: theme.typography.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: FluentSpacing.s),
                  Text(_formatOptionalDateTime(message.receivedAt)),
                ],
              ),
              const SizedBox(height: FluentSpacing.xs),
              Text(
                _senderLabel(message),
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              const SizedBox(height: FluentSpacing.s),
              Text(
                message.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: FluentSpacing.m),
              Align(
                alignment: Alignment.centerRight,
                child: Button(
                  onPressed: () => _openMessageDetail(message),
                  child: const Text('查看正文'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开邮件正文详情页；详情页仍只展示本地快照。
  void _openMessageDetail(EmailMessageSnapshot message) {
    Navigator.of(context).push(
      FluentPageRoute(builder: (_) => EmailMessageDetailPage(message: message)),
    );
  }

  InfoBarSeverity _severityOf(EmailQueryStatus status) {
    return switch (status) {
      EmailQueryStatus.success => InfoBarSeverity.success,
      EmailQueryStatus.missingEmailAccount ||
      EmailQueryStatus.missingEmailPassword => InfoBarSeverity.warning,
      EmailQueryStatus.loginRejected ||
      EmailQueryStatus.parseFailed ||
      EmailQueryStatus.networkError ||
      EmailQueryStatus.unexpectedError => InfoBarSeverity.error,
    };
  }

  String _senderLabel(EmailMessageSnapshot message) {
    if (message.senderName.isEmpty) return message.senderAddress;
    return '${message.senderName} <${message.senderAddress}>';
  }

  String _formatOptionalDateTime(DateTime? dateTime) {
    if (dateTime == null) return '时间未知';
    return _formatDateTime(dateTime);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
