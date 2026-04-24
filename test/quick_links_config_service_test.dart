/*
 * 快捷跳转配置服务测试 — 校验 YAML 分组解析与自定义图标字段
 * @Project : SSPU-all-in-one
 * @File : quick_links_config_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/quick_links_config_service.dart';
import 'package:sspu_all_in_one/services/quick_links_search_service.dart';

void main() {
  test('可以解析快捷跳转 YAML 分组和链接条目', () {
    final groups = QuickLinksConfigService.parseGroups('''
site_groups:
  - category: 常用入口
    items:
      - name: 学校官网
        url: https://www.sspu.edu.cn/
        icon: globe
      - name: OA办公
        url: https://oa.sspu.edu.cn/
  - category: 教学学习
    items:
      - name: 教务处
        url: https://jwc.sspu.edu.cn/
''');

    expect(groups, hasLength(2));
    expect(groups.first.category, '常用入口');
    expect(groups.first.items, hasLength(2));
    expect(groups.first.items.first.name, '学校官网');
    expect(groups.first.items.first.url, 'https://www.sspu.edu.cn/');
    expect(groups.first.items.first.icon, 'globe');
    expect(groups.last.items.single.name, '教务处');
  });

  test('快捷跳转搜索支持名称和 URL 精确匹配', () {
    final groups = _buildSearchFixture();

    final nameResults = QuickLinksSearchService.search(groups, 'OA办公');
    expect(nameResults.first.item.name, 'OA办公');
    expect(nameResults.first.matchType, QuickLinkMatchType.exactName);

    final urlResults = QuickLinksSearchService.search(groups, 'oa.sspu.edu.cn');
    expect(urlResults.first.item.name, 'OA办公');
    expect(urlResults.first.matchType, QuickLinkMatchType.exactUrl);
  });

  test('快捷跳转搜索支持名称和 URL 模糊匹配', () {
    final groups = _buildSearchFixture();

    final nameResults = QuickLinksSearchService.search(groups, '智慧');
    expect(nameResults.first.item.name, '智慧图书馆');
    expect(nameResults.first.matchType, QuickLinkMatchType.fuzzyName);

    final urlResults = QuickLinksSearchService.search(groups, 'career');
    expect(urlResults.first.item.name, '智慧就业创业中心');
    expect(urlResults.first.matchType, QuickLinkMatchType.fuzzyUrl);
  });

  test('快捷跳转搜索支持基于输入意图的智能匹配', () {
    final groups = _buildSearchFixture();

    final results = QuickLinksSearchService.search(groups, '查成绩');
    expect(results.first.item.name, '本专科教务系统（OA）');
    expect(results.first.matchType, QuickLinkMatchType.intelligent);
  });
}

List<QuickLinkGroupConfig> _buildSearchFixture() {
  return const [
    QuickLinkGroupConfig(
      category: '常用入口',
      items: [
        QuickLinkItemConfig(name: 'OA办公', url: 'https://oa.sspu.edu.cn/'),
        QuickLinkItemConfig(
          name: '本专科教务系统（OA）',
          url: 'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
        ),
      ],
    ),
    QuickLinkGroupConfig(
      category: '教学学习',
      items: [
        QuickLinkItemConfig(name: '智慧图书馆', url: 'https://library.sspu.edu.cn/'),
        QuickLinkItemConfig(
          name: '智慧就业创业中心',
          url: 'https://career.sspu.edu.cn/',
        ),
      ],
    ),
  ];
}
