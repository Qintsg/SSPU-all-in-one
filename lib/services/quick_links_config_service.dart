/*
 * 快捷跳转配置服务 — 从 YAML 资产读取校园站点分组与链接
 * @Project : SSPU-all-in-one
 * @File : quick_links_config_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:flutter/services.dart';

/// 快捷链接条目配置。
class QuickLinkItemConfig {
  /// 页面显示名称。
  final String name;

  /// 外部跳转地址。
  final String url;

  /// 可选图标键名，用于后续通过 YAML 自定义图标。
  final String? icon;

  const QuickLinkItemConfig({required this.name, required this.url, this.icon});
}

/// 快捷链接分组配置。
class QuickLinkGroupConfig {
  /// 分组标题。
  final String category;

  /// 分组内链接条目。
  final List<QuickLinkItemConfig> items;

  const QuickLinkGroupConfig({required this.category, required this.items});
}

/// 快捷跳转 YAML 配置服务。
class QuickLinksConfigService {
  QuickLinksConfigService._();

  static final QuickLinksConfigService instance = QuickLinksConfigService._();

  static const String assetPath = 'assets/config/quick_links.yaml';

  /// 从资产文件读取快捷跳转配置。
  Future<List<QuickLinkGroupConfig>> loadGroups() async {
    final yamlText = await rootBundle.loadString(assetPath);
    return parseGroups(yamlText);
  }

  /// 解析当前仓库约定的简单 YAML 结构。
  /// 支持 item 级 `icon` 字段，未知字段会被忽略。
  static List<QuickLinkGroupConfig> parseGroups(String yamlText) {
    final groups = <QuickLinkGroupConfig>[];
    String? currentCategory;
    final currentItems = <QuickLinkItemConfig>[];
    final currentItemFields = <String, String>{};

    void flushItem() {
      final name = currentItemFields['name']?.trim() ?? '';
      final url = currentItemFields['url']?.trim() ?? '';
      final icon = currentItemFields['icon']?.trim();
      if (name.isNotEmpty && url.isNotEmpty) {
        currentItems.add(
          QuickLinkItemConfig(
            name: name,
            url: url,
            icon: icon == null || icon.isEmpty ? null : icon,
          ),
        );
      }
      currentItemFields.clear();
    }

    void flushGroup() {
      flushItem();
      if (currentCategory != null && currentItems.isNotEmpty) {
        groups.add(
          QuickLinkGroupConfig(
            category: currentCategory,
            items: List.unmodifiable(currentItems),
          ),
        );
      }
      currentItems.clear();
    }

    for (final rawLine in yamlText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line == 'site_groups:') {
        continue;
      }

      if (line.startsWith('- category:')) {
        flushGroup();
        currentCategory = _readValue(line);
        continue;
      }

      if (line == 'items:') continue;

      if (line.startsWith('- name:')) {
        flushItem();
        currentItemFields['name'] = _readValue(line);
        continue;
      }

      if (line.startsWith('url:')) {
        currentItemFields['url'] = _readValue(line);
        continue;
      }

      if (line.startsWith('icon:')) {
        currentItemFields['icon'] = _readValue(line);
      }
    }

    flushGroup();
    return List.unmodifiable(groups);
  }

  static String _readValue(String line) {
    final separatorIndex = line.indexOf(':');
    if (separatorIndex < 0 || separatorIndex == line.length - 1) return '';
    final rawValue = line.substring(separatorIndex + 1).trim();
    if (rawValue.length >= 2 &&
        ((rawValue.startsWith('"') && rawValue.endsWith('"')) ||
            (rawValue.startsWith("'") && rawValue.endsWith("'")))) {
      return rawValue.substring(1, rawValue.length - 1);
    }
    return rawValue;
  }
}
