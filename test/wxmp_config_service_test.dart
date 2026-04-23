/*
 * 微信公众号平台配置文件服务测试 — 校验 TOML 配置解析与边界值
 * @Project : SSPU-all-in-one
 * @File : wxmp_config_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

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
}
