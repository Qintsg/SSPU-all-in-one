/*
 * 校园卡页面解析器 — 提取余额、状态与交易记录
 * @Project : SSPU-all-in-one
 * @File : campus_card_page_parser.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'campus_card_service.dart';

/// 校园卡页面解析器；支持普通 HTML 和同类 epay 系统的 XML/CDATA 表格。
class CampusCardPageParser {
  CampusCardPageParser._();

  /// 从多个候选页面中提取余额、状态和交易记录。
  static CampusCardSnapshot? parse(List<CampusCardHttpSnapshot> snapshots) {
    double? balance;
    var status = '';
    final records = <CampusCardTransactionRecord>[];

    for (final snapshot in snapshots) {
      for (final fragment in _extractHtmlFragments(snapshot.body)) {
        final document = html_parser.parse(fragment);
        balance ??= _parseBalance(document);
        if (status.isEmpty) status = _parseStatus(document) ?? '';
        records.addAll(_parseRecords(document));
      }
    }

    final uniqueRecords = _deduplicateRecords(records);
    if (balance == null && status.isEmpty && uniqueRecords.isEmpty) return null;

    return CampusCardSnapshot(
      balance: balance,
      status: status,
      records: List.unmodifiable(uniqueRecords),
      fetchedAt: DateTime.now(),
      sourceUri: snapshots.last.finalUri,
    );
  }

  static List<String> _extractHtmlFragments(String body) {
    final fragments = <String>[body];
    final cdataPattern = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
    for (final match in cdataPattern.allMatches(body)) {
      final fragment = match.group(1);
      if (fragment != null && fragment.trim().isNotEmpty) {
        fragments.add(fragment);
      }
    }
    return fragments;
  }

  static double? _parseBalance(html_dom.Document document) {
    final tableValue = _labelValue(document, const [
      '账户余额',
      '卡余额',
      '当前余额',
      '余额',
    ]);
    final tableBalance = _parseMoney(tableValue ?? '');
    if (tableBalance != null) return tableBalance;

    final text = _cleanText(document.body?.text ?? document.outerHtml);
    final patterns = [
      RegExp(r'(?:账户余额|卡余额|当前余额|余额)[^0-9+\-]{0,16}([+\-]?\d+(?:\.\d{1,2})?)'),
      RegExp(r'([+\-]?\d+(?:\.\d{1,2})?)\s*元[^，。；;]{0,8}(?:余额|账户余额|卡余额)'),
    ];
    for (final pattern in patterns) {
      final value = _parseMoney(pattern.firstMatch(text)?.group(1) ?? '');
      if (value != null) return value;
    }
    return null;
  }

  static String? _parseStatus(html_dom.Document document) {
    final tableValue = _labelValue(document, const ['卡状态', '账户状态', '状态']);
    if (tableValue != null && tableValue.isNotEmpty) return tableValue;

    final text = _cleanText(document.body?.text ?? document.outerHtml);
    final match = RegExp(
      r'(?:卡状态|账户状态|状态)\s*[:：]?\s*([^，。；;\s]{1,12})',
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String? _labelValue(html_dom.Document document, List<String> labels) {
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .toList();
      for (var index = 0; index < cells.length; index++) {
        if (!labels.any(cells[index].contains)) continue;
        if (index + 1 < cells.length && cells[index + 1].isNotEmpty) {
          return cells[index + 1];
        }
      }
    }
    return null;
  }

  static List<CampusCardTransactionRecord> _parseRecords(
    html_dom.Document document,
  ) {
    final records = <CampusCardTransactionRecord>[];
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .where((cellText) => cellText.isNotEmpty)
          .toList();
      if (cells.length < 3) continue;

      final joinedCells = cells.join(' ');
      final occurredAt = _datePattern.firstMatch(joinedCells)?.group(0);
      if (occurredAt == null || !_hasTransactionHint(joinedCells)) continue;

      final amount = _parseRecordAmount(cells);
      if (amount == null) continue;
      records.add(
        CampusCardTransactionRecord(
          occurredAt: occurredAt,
          amount: amount,
          merchant: _parseMerchant(cells),
          type: _parseType(joinedCells),
          balanceAfter: _parseBalanceAfter(cells),
          rawCells: List.unmodifiable(cells),
        ),
      );
    }
    return records;
  }

  static bool _hasTransactionHint(String text) {
    return text.contains('消费') ||
        text.contains('充值') ||
        text.contains('补助') ||
        text.contains('圈存') ||
        text.contains('退款') ||
        text.contains('交易') ||
        text.contains('扣款') ||
        text.contains('收入') ||
        text.contains('支出');
  }

  static double? _parseRecordAmount(List<String> cells) {
    for (final cell in cells.reversed) {
      if (_datePattern.hasMatch(cell)) continue;
      final amount = _parseMoney(cell);
      if (amount != null && (cell.contains('+') || cell.contains('-'))) {
        return amount;
      }
    }
    for (final cell in cells) {
      if (_datePattern.hasMatch(cell)) continue;
      final amount = _parseMoney(cell);
      if (amount != null) return amount;
    }
    return null;
  }

  static double? _parseBalanceAfter(List<String> cells) {
    for (final cell in cells.reversed) {
      if (_datePattern.hasMatch(cell)) continue;
      if (cell.contains('+') || cell.contains('-')) continue;
      final amount = _parseMoney(cell);
      if (amount != null) return amount;
    }
    return null;
  }

  static String? _parseMerchant(List<String> cells) {
    for (final cell in cells) {
      if (_datePattern.hasMatch(cell)) continue;
      if (_parseMoney(cell) != null) continue;
      if (_parseType(cell) != null) continue;
      if (cell.contains('余额') || cell.contains('状态')) continue;
      return cell;
    }
    return null;
  }

  static String? _parseType(String text) {
    const types = ['消费', '充值', '补助', '圈存', '退款', '扣款', '收入', '支出'];
    for (final type in types) {
      if (text.contains(type)) return type;
    }
    return null;
  }

  static List<CampusCardTransactionRecord> _deduplicateRecords(
    List<CampusCardTransactionRecord> records,
  ) {
    final seen = <String>{};
    final uniqueRecords = <CampusCardTransactionRecord>[];
    for (final record in records) {
      final key =
          '${record.occurredAt}|${record.amount}|${record.rawCells.join('|')}';
      if (!seen.add(key)) continue;
      uniqueRecords.add(record);
    }
    return uniqueRecords;
  }

  static double? _parseMoney(String text) {
    final normalizedText = text.replaceAll(',', '').replaceAll('￥', '');
    final match = RegExp(
      r'([+\-]?\d+(?:\.\d{1,2})?)',
    ).firstMatch(normalizedText);
    return double.tryParse(match?.group(1) ?? '');
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final RegExp _datePattern = RegExp(
    r'\d{4}[-/]\d{1,2}[-/]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?',
  );
}
