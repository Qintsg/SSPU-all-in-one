/*
 * 消息状态服务测试 — 校验渠道默认启用状态和自动刷新间隔
 * @Project : SSPU-all-in-one
 * @File : message_state_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/services/message_state_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

void main() {
  test('未写入存储时使用渠道配置中的默认启用状态', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final stateService = MessageStateService.instance;

    // 自动刷新服务不传默认值时，也应和设置页展示的默认状态一致。
    expect(await stateService.isChannelEnabled('jwc'), isTrue);
    expect(await stateService.isChannelEnabled('news_center'), isTrue);
    expect(await stateService.isChannelEnabled('college_cs'), isFalse);
    expect(await stateService.isChannelEnabled('wechat_public'), isFalse);
  });

  test('未写入存储时使用渠道配置中的默认刷新间隔', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final stateService = MessageStateService.instance;

    // 官网和微信公众号可分别保留自己的默认刷新周期。
    expect(await stateService.getChannelInterval('jwc'), 60);
    expect(await stateService.getChannelInterval('sspu_activity'), 120);
    expect(await stateService.getChannelInterval('wechat_public'), 120);
    expect(await stateService.getChannelInterval('unknown_channel'), 0);
  });
}
