/*
 * 自动刷新服务测试 — 校验设置页渠道 ID 与内部定时器 key 的映射
 * @Project : SSPU-all-in-one
 * @File : auto_refresh_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-22
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/auto_refresh_service.dart';

void main() {
  test('设置页渠道 ID 可以映射到对应的自动刷新定时器', () {
    final service = AutoRefreshService.instance;

    // 多子栏目渠道共用一个设置项，重载时必须展开到所有内部定时器。
    expect(
      service.debugTimerKeysForChannel('jwc'),
      equals(['jwcStudent', 'jwcTeacher']),
    );
    expect(
      service.debugTimerKeysForChannel('sports'),
      equals(['sportsNotice', 'sportsEvent']),
    );
    expect(
      service.debugTimerKeysForChannel('security_dept'),
      equals(['securityNews', 'securityEducation']),
    );
    expect(
      service.debugTimerKeysForChannel('construction'),
      equals(['constructionNews', 'constructionNotice']),
    );
    expect(
      service.debugTimerKeysForChannel('student_affairs'),
      equals(['studentNews', 'studentNotice']),
    );
  });

  test('官网和微信公众号渠道使用设置页配置的逻辑渠道 ID', () {
    final service = AutoRefreshService.instance;

    // 单栏目渠道也要支持设置页 ID，确保间隔和开关变更能即时生效。
    expect(
      service.debugTimerKeysForChannel('latest_info'),
      equals(['latestInfo']),
    );
    expect(
      service.debugTimerKeysForChannel('sspu_notice'),
      equals(['sspuNotice']),
    );
    expect(
      service.debugTimerKeysForChannel('sspu_activity'),
      equals(['sspuActivity']),
    );
    expect(
      service.debugTimerKeysForChannel('news_center'),
      equals(['campusNews']),
    );
    expect(
      service.debugTimerKeysForChannel('wechat_public'),
      equals(['wechatPublic']),
    );
  });
}
