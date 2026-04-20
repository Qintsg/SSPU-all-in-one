/*
 * 日期规范化工具 — 统一各信息源的日期格式为 YYYY-MM-DD
 * 支持多种输入格式：YYYY-MM-DD、MM-DD、YYYY/MM/DD、MM/DD 等
 * 对仅有 MM-DD 的日期，通过与当前日期比较自动补全年份
 * @Project : SSPU-all-in-one
 * @File : date_utils.dart
 * @Author : Qintsg
 * @Date : 2025-07-20
 */

/// 将各种日期格式规范化为 YYYY-MM-DD
///
/// 支持的输入格式：
/// - `YYYY-MM-DD` / `YYYY/MM/DD` — 直接规范化分隔符并补零
/// - `MM-DD` / `M-D` / `MM/DD` — 补全年份，超过当前日期则视为去年
/// - 空字符串或无法识别的格式 — 原样返回
///
/// :param rawDate: 原始日期字符串
/// :return: 规范化后的 YYYY-MM-DD 字符串，或无法识别时返回原值
String normalizeDate(String rawDate) {
  // 清理非数字、非分隔符字符（如中文括号、空白等）
  final cleaned = rawDate.replaceAll(RegExp(r'[^\d/\-]'), '').trim();
  if (cleaned.isEmpty) return rawDate.trim();

  // 完整格式: YYYY-MM-DD 或 YYYY/MM/DD
  final fullMatch =
      RegExp(r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})$').firstMatch(cleaned);
  if (fullMatch != null) {
    final year = fullMatch.group(1)!;
    final month = int.parse(fullMatch.group(2)!).toString().padLeft(2, '0');
    final day = int.parse(fullMatch.group(3)!).toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // 短格式: MM-DD 或 MM/DD，需补全年份
  final shortMatch =
      RegExp(r'^(\d{1,2})[/\-](\d{1,2})$').firstMatch(cleaned);
  if (shortMatch != null) {
    final month = int.parse(shortMatch.group(1)!);
    final day = int.parse(shortMatch.group(2)!);
    final now = DateTime.now();

    // 该日期超过今天 → 视为去年的消息
    var year = now.year;
    if (month > now.month || (month == now.month && day > now.day)) {
      year = now.year - 1;
    }

    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  // 无法识别的格式，返回去除首尾空白的原值
  return rawDate.trim();
}
