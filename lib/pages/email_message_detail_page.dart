/*
 * 邮件正文详情页 — 展示邮箱只读收信结果中的正文快照
 * @Project : SSPU-all-in-one
 * @File : email_message_detail_page.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'email_page.dart';

/// 邮件正文详情页。
class EmailMessageDetailPage extends StatelessWidget {
  /// 列表页传入的邮件快照。
  final EmailMessageSnapshot message;

  const EmailMessageDetailPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('邮件正文'),
        commandBar: Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.subject, style: theme.typography.bodyStrong),
                const SizedBox(height: FluentSpacing.s),
                Text('发件人：${_senderLabel(message)}'),
                Text('时间：${_formatOptionalDateTime(message.receivedAt)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        const InfoBar(
          title: Text('只读正文快照'),
          content: Text('正文来自本次收信结果，不会执行回复、转发、删除、移动或标记已读操作。'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
        const SizedBox(height: FluentSpacing.m),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FluentSpacing.l),
            child: SelectableText(
              message.body.isEmpty ? '无可展示正文。' : message.body,
            ),
          ),
        ),
      ],
    );
  }

  String _senderLabel(EmailMessageSnapshot message) {
    if (message.senderName.isEmpty) return message.senderAddress;
    return '${message.senderName} <${message.senderAddress}>';
  }

  String _formatOptionalDateTime(DateTime? dateTime) {
    if (dateTime == null) return '时间未知';
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
