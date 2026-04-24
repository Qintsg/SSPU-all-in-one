/*
 * 微信公众号平台配置文件服务测试 — 校验 TOML 配置解析与边界值
 * @Project : SSPU-all-in-one
 * @File : wxmp_config_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/wxmp_config_service.dart';

void main() {
  test('可以从 TOML 文本解析公众号平台配置', () {
    final config = WxmpConfig.fromToml('''
[wxmp]
cookie = "appmsg_token=abc;"
token = "123456"
app_id = "wx-test"
user_agent = "Custom UA"
per_request_article_count = 8
request_delay_ms = 1500
''');

    expect(config.cookie, 'appmsg_token=abc;');
    expect(config.token, '123456');
    expect(config.appId, 'wx-test');
    expect(config.userAgent, 'Custom UA');
    expect(config.perRequestArticleCount, 8);
    expect(config.requestDelayMs, 1500);
  });

  test('配置数值超出范围时会被限制到安全区间', () {
    final config = WxmpConfig.fromToml('''
[wxmp]
per_request_article_count = 99
request_delay_ms = -1
''');

    // 单次请求条数过高容易触发平台限制，服务层会限制上限。
    expect(config.perRequestArticleCount, 20);
    expect(config.requestDelayMs, 0);
  });

  test('保存原始 TOML 文本时保留用户注释', () async {
    final configDirectory = await Directory.systemTemp.createTemp(
      'wxmp_config_text_test_',
    );
    final configPath =
        '${configDirectory.path}${Platform.pathSeparator}wxmp_config.toml';
    final rawConfig = '''
[wxmp]
# 用户手动记录的来源说明
cookie = "manual-cookie"
token = "123456"
''';

    WxmpConfigService.instance.debugSetConfigPathForTesting(configPath);
    addTearDown(() async {
      WxmpConfigService.instance.debugSetConfigPathForTesting(null);
      if (await configDirectory.exists()) {
        await configDirectory.delete(recursive: true);
      }
    });

    await WxmpConfigService.instance.saveConfigText(rawConfig);
    final savedText = await WxmpConfigService.instance.loadConfigText();
    final parsed = await WxmpConfigService.instance.loadConfig();

    // 内置编辑器保存原文，避免移动端手动调整 Cookie 时丢失备注。
    expect(savedText, rawConfig);
    expect(parsed.cookie, 'manual-cookie');
  });
}
