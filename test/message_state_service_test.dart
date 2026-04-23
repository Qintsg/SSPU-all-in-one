/*
 * 消息状态服务测试 — 校验渠道默认启用状态和自动刷新间隔
 * @Project : SSPU-all-in-one
 * @File : message_state_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/services/message_state_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

void main() {
  late Directory storageDirectory;

  setUp(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'message_state_storage_',
    );
    StorageService.debugSetStateFilePathForTesting(
      '${storageDirectory.path}${Platform.pathSeparator}app_state.json',
    );
  });

  tearDown(() async {
    StorageService.debugSetStateFilePathForTesting(null);
    if (await storageDirectory.exists()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  test('未写入存储时使用渠道配置中的默认启用状态', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final stateService = MessageStateService.instance;

    // 自动刷新服务不传默认值时，也应和设置页展示的默认状态一致。
    expect(await stateService.isChannelEnabled('jwc'), isTrue);
    expect(await stateService.isChannelEnabled('news_center'), isTrue);
    expect(await stateService.isChannelEnabled('college_cs'), isFalse);
    expect(await stateService.isChannelEnabled('wechat_public'), isTrue);
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

  test('自动刷新关闭后保留最近一次有效间隔并可恢复', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final stateService = MessageStateService.instance;

    // 设置页关闭自动刷新时仍需要保留原间隔，重新开启时恢复用户选择。
    await stateService.setChannelInterval('jwc', 30);
    expect(await stateService.isChannelAutoRefreshEnabled('jwc'), isTrue);

    await stateService.setChannelAutoRefreshEnabled('jwc', false);
    expect(await stateService.getChannelInterval('jwc'), 0);
    expect(await stateService.getChannelDisplayInterval('jwc'), 30);

    await stateService.setChannelAutoRefreshEnabled('jwc', true);
    expect(await stateService.getChannelInterval('jwc'), 30);
    expect(await stateService.isChannelAutoRefreshEnabled('jwc'), isTrue);
  });

  test('刷新条数配置限制在正整数安全范围内', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final stateService = MessageStateService.instance;

    // 数字框只允许正整数；服务层额外兜底，避免异常值进入刷新链路。
    await stateService.setChannelManualFetchCount('jwc', -5);
    await stateService.setChannelAutoFetchCount('jwc', 250);

    expect(await stateService.getChannelManualFetchCount('jwc'), 1);
    expect(await stateService.getChannelAutoFetchCount('jwc'), 200);
  });
}
