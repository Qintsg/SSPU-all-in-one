/*
 * 微信关注账号匹配工具测试 — 校验推荐账号与已关注公众号的映射规则
 * @Project : SSPU-all-in-one
 * @File : wechat_followed_account_matcher_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/sspu_wechat_accounts.dart';
import 'package:sspu_all_in_one/utils/wechat_followed_account_matcher.dart';

void main() {
  test('优先使用推荐账号元信息匹配已关注公众号', () {
    const account = SspuWechatAccount(
      name: '上海第二工业大学马克思主义学院',
      wxAccount: '上海第二工业大学马克思主义学院',
      iconUrl: '',
      articleUrl: '',
    );

    final followed = findFollowedWechatAccount(account, [
      {
        'fakeid': 'fakeid-1',
        'name': '上二工马院',
        'alias': 'siergongmayuan',
        'recommended_name': '上海第二工业大学马克思主义学院',
        'recommended_wx_account': '上海第二工业大学马克思主义学院',
      },
    ]);

    expect(followed, isNotNull);
    expect(followed?['fakeid'], 'fakeid-1');
  });

  test('历史数据仍可通过微信号别名匹配推荐账号', () {
    const account = SspuWechatAccount(
      name: '青春二工大',
      wxAccount: 'ssputw',
      iconUrl: '',
      articleUrl: '',
    );

    final followed = findFollowedWechatAccount(account, [
      {'fakeid': 'fakeid-2', 'name': '青春二工大', 'alias': 'ssputw'},
    ]);

    expect(followed, isNotNull);
    expect(followed?['fakeid'], 'fakeid-2');
  });
}
