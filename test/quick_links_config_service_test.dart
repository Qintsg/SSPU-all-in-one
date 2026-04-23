/*
 * 快捷跳转配置服务测试 — 校验 YAML 分组解析与自定义图标字段
 * @Project : SSPU-all-in-one
 * @File : quick_links_config_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/quick_links_config_service.dart';

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
}
