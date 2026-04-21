/*
 * 日期规范化工具 — 统一各信息源的日期格式为 YYYY-MM-DD
 * 支持多种输入格式：YYYY-MM-DD、MM-DD、YYYY/MM/DD、MM/DD 等
 * 对仅有 MM-DD 的日期，通过与当前日期比较自动补全年份
 * 对仅有时间（HH:MM）或含"今日/今天/today"的字符串，返回今天日期
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
/// - `HH:MM` / `HH:MM:SS`（仅时间）— 官网当天发布的消息常用，返回今天日期
/// - 含"今日"/"今天"/"today"的字符串 — 返回今天日期
/// - 空字符串或无法识别的格式 — 返回今天日期（无日期信息时视为当天消息）
///
/// :param rawDate: 原始日期字符串
/// :return: 规范化后的 YYYY-MM-DD 字符串
String normalizeDate(String rawDate) {
  // 辅助：返回今天的 YYYY-MM-DD 字符串
  String todayString() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  final trimmed = rawDate.trim();

  // 时间格式（如 "09:30"、"14:05:00"）→ 当天发布的消息，记录今天日期
  if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(trimmed)) {
    return todayString();
  }

  // 含"今日"/"今天"/"today" → 当天消息
  final lowerTrimmed = trimmed.toLowerCase();
  if (lowerTrimmed.contains('今日') ||
      lowerTrimmed.contains('今天') ||
      lowerTrimmed.contains('today')) {
    return todayString();
  }

  // 清理非数字、非分隔符字符（如中文括号、空白等）
  final cleaned = trimmed.replaceAll(RegExp(r'[^\d/\-]'), '').trim();
  // 无任何日期信息 → 视为当天消息
  if (cleaned.isEmpty) return todayString();

  // 完整格式: YYYY-MM-DD 或 YYYY/MM/DD
  final fullMatch = RegExp(
    r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})$',
  ).firstMatch(cleaned);
  if (fullMatch != null) {
    final year = fullMatch.group(1)!;
    final month = int.parse(fullMatch.group(2)!).toString().padLeft(2, '0');
    final day = int.parse(fullMatch.group(3)!).toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // 短格式: MM-DD 或 MM/DD，需补全年份
  final shortMatch = RegExp(r'^(\d{1,2})[/\-](\d{1,2})$').firstMatch(cleaned);
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

  // 无法识别的格式 → 视为当天消息（避免将错误字符串写入 date 字段）
  return todayString();
}
