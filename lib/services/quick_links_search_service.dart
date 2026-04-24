/*
 * 快捷跳转搜索服务 — 为快捷入口提供精确、模糊与意图匹配
 * @Project : SSPU-all-in-one
 * @File : quick_links_search_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-24
 */

import 'quick_links_config_service.dart';

/// 快捷链接匹配类型。
enum QuickLinkMatchType {
  /// 名称完全一致。
  exactName,

  /// URL 或域名完全一致。
  exactUrl,

  /// 名称包含或近似匹配。
  fuzzyName,

  /// URL 包含或近似匹配。
  fuzzyUrl,

  /// 通过同义词、用途和场景推断出的匹配。
  intelligent,
}

/// 快捷链接搜索结果。
class QuickLinkSearchResult {
  /// 所属分组。
  final QuickLinkGroupConfig group;

  /// 命中的链接条目。
  final QuickLinkItemConfig item;

  /// 匹配类型，用于界面说明和测试断言。
  final QuickLinkMatchType matchType;

  /// 分数越高排序越靠前。
  final int score;

  const QuickLinkSearchResult({
    required this.group,
    required this.item,
    required this.matchType,
    required this.score,
  });
}

/// 快捷跳转搜索服务。
class QuickLinksSearchService {
  QuickLinksSearchService._();

  /// 常用校园服务意图词表，覆盖用户不输入完整站点名称的场景。
  static const Map<String, List<String>> _intentWords = {
    '教务': ['成绩', '选课', '考试', '课表', '课程', '本科', '研究生', 'jw', 'jwc'],
    '邮箱': ['mail', 'email', '邮件', '信箱', '电子邮件'],
    'OA': ['办公', '门户', '审批', '办事', 'oa'],
    '图书': ['图书馆', '借书', '还书', 'library', '档案'],
    '校园卡': ['一卡通', '饭卡', '卡余额', '充值'],
    '财务': ['缴费', '报销', '工资', '发票'],
    '体育': ['体测', '跑步', '体育成绩', '运动'],
    '就业': ['招聘', '实习', 'career', '工作'],
    '招生': ['录取', '报考', '高考'],
    '保卫': ['安全', '报警', '门禁'],
    '国际': ['留学', '外事', '交换生'],
    '新闻': ['通知', '公告', '资讯', '宣传'],
    '信息技术': ['网络', '电脑', 'it', 'itc', '信息化'],
  };

  /// 搜索所有快捷链接，空查询返回空结果以便页面回落到原始分组。
  static List<QuickLinkSearchResult> search(
    List<QuickLinkGroupConfig> groups,
    String query, {
    int limit = 60,
  }) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    final results = <_RankedQuickLinkSearchResult>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      for (var itemIndex = 0; itemIndex < group.items.length; itemIndex++) {
        final item = group.items[itemIndex];
        final candidate = _scoreCandidate(group, item, normalizedQuery);
        if (candidate == null) continue;
        results.add(
          _RankedQuickLinkSearchResult(
            result: QuickLinkSearchResult(
              group: group,
              item: item,
              matchType: candidate.matchType,
              score: candidate.score,
            ),
            groupIndex: groupIndex,
            itemIndex: itemIndex,
          ),
        );
      }
    }

    results.sort((left, right) {
      final scoreOrder = right.result.score.compareTo(left.result.score);
      if (scoreOrder != 0) return scoreOrder;
      final groupOrder = left.groupIndex.compareTo(right.groupIndex);
      if (groupOrder != 0) return groupOrder;
      return left.itemIndex.compareTo(right.itemIndex);
    });

    return List.unmodifiable(results.take(limit).map((entry) => entry.result));
  }

  static _QuickLinkScore? _scoreCandidate(
    QuickLinkGroupConfig group,
    QuickLinkItemConfig item,
    String normalizedQuery,
  ) {
    final normalizedName = _normalize(item.name);
    final normalizedCategory = _normalize(group.category);
    final normalizedUrl = _normalize(item.url);
    final normalizedHost = _normalize(_hostOf(item.url));

    if (normalizedName == normalizedQuery) {
      return const _QuickLinkScore(QuickLinkMatchType.exactName, 1000);
    }
    if (normalizedUrl == normalizedQuery || normalizedHost == normalizedQuery) {
      return const _QuickLinkScore(QuickLinkMatchType.exactUrl, 950);
    }

    final candidates = <_QuickLinkScore>[];
    if (normalizedName.contains(normalizedQuery)) {
      candidates.add(
        _QuickLinkScore(
          QuickLinkMatchType.fuzzyName,
          850 + normalizedQuery.length,
        ),
      );
    }
    if (normalizedUrl.contains(normalizedQuery) ||
        normalizedHost.contains(normalizedQuery)) {
      candidates.add(
        _QuickLinkScore(
          QuickLinkMatchType.fuzzyUrl,
          830 + normalizedQuery.length,
        ),
      );
    }

    final nameScore = _subsequenceScore(normalizedQuery, normalizedName);
    if (nameScore > 0) {
      candidates.add(
        _QuickLinkScore(QuickLinkMatchType.fuzzyName, 620 + nameScore),
      );
    }
    final urlScore = _subsequenceScore(normalizedQuery, normalizedUrl);
    if (urlScore > 0) {
      candidates.add(
        _QuickLinkScore(QuickLinkMatchType.fuzzyUrl, 560 + urlScore),
      );
    }

    final intentScore = _intentScore(
      normalizedQuery,
      '$normalizedCategory $normalizedName $normalizedUrl',
    );
    if (intentScore > 0) {
      candidates.add(
        _QuickLinkScore(QuickLinkMatchType.intelligent, 700 + intentScore),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort((left, right) => right.score.compareTo(left.score));
    return candidates.first;
  }

  /// 去掉大小写、空白和常见分隔符，让中英文与 URL 输入更稳定。
  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'[\s\-_./:：()（）?&=]+'), '');
  }

  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.host;
  }

  static int _subsequenceScore(String query, String candidate) {
    if (query.length < 2 || candidate.length < 2) return 0;
    var queryIndex = 0;
    var firstMatchIndex = -1;
    var lastMatchIndex = -1;

    for (
      var candidateIndex = 0;
      candidateIndex < candidate.length;
      candidateIndex++
    ) {
      if (candidate[candidateIndex] != query[queryIndex]) continue;
      firstMatchIndex = firstMatchIndex < 0 ? candidateIndex : firstMatchIndex;
      lastMatchIndex = candidateIndex;
      queryIndex++;
      if (queryIndex == query.length) break;
    }

    if (queryIndex != query.length) return 0;
    final span = lastMatchIndex - firstMatchIndex + 1;
    final compactBonus = (100 - (span - query.length) * 8).clamp(20, 100);
    return compactBonus + (query.length * 8);
  }

  static int _intentScore(String normalizedQuery, String normalizedCandidate) {
    var bestScore = 0;
    for (final entry in _intentWords.entries) {
      final normalizedIntent = _normalize(entry.key);
      final words = [normalizedIntent, ...entry.value.map(_normalize)];
      final queryHitsIntent = words.any(
        (word) => word.isNotEmpty && normalizedQuery.contains(word),
      );
      if (!queryHitsIntent) continue;

      final candidateHitsIntent = words.any(
        (word) => word.isNotEmpty && normalizedCandidate.contains(word),
      );
      if (!candidateHitsIntent) continue;
      bestScore = bestScore < 90 ? 90 : bestScore;
    }
    return bestScore;
  }
}

class _QuickLinkScore {
  final QuickLinkMatchType matchType;
  final int score;

  const _QuickLinkScore(this.matchType, this.score);
}

class _RankedQuickLinkSearchResult {
  final QuickLinkSearchResult result;
  final int groupIndex;
  final int itemIndex;

  const _RankedQuickLinkSearchResult({
    required this.result,
    required this.groupIndex,
    required this.itemIndex,
  });
}
