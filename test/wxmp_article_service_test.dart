/*
 * 微信公众号平台文章服务测试 — 校验认证探针错误码处理
 * @Project : SSPU-all-in-one
 * @File : wxmp_article_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/message_item.dart';
import 'package:sspu_all_in_one/services/wxmp_article_service.dart';

void main() {
  test('searchbiz 返回 200040 时判定为 CSRF 认证失效', () {
    final result = debugValidationResultForRet(WxmpApiError.invalidCsrfToken);

    // 200040 表示 Cookie 与 Token 不匹配，刷新和关注接口都会被同样拦截。
    expect(result.isValid, isFalse);
    expect(result.message, contains('CSRF'));
  });

  test('未知公众号平台错误码仍判定为不可用', () {
    final result = debugValidationResultForRet(999999);

    expect(result.isValid, isFalse);
    expect(result.message, contains('999999'));
  });

  test('公众号账号显示名优先使用推荐名并显式处理缺失值', () {
    expect(
      debugResolveWxmpAccountName({
        'name': '平台昵称',
        'recommended_name': '青春二工大',
      }, 'fakeid-name'),
      '青春二工大',
    );
    expect(debugResolveWxmpAccountName({}, 'fakeid-missing'), '公众号名称未知');
  });

  test('公众号账号显示 ID 优先使用推荐微信号再回退 alias', () {
    expect(
      debugResolveWxmpAccountDisplayId({
        'alias': 'platform_alias',
        'recommended_wx_account': 'ssputw',
      }),
      'ssputw',
    );
    expect(
      debugResolveWxmpAccountDisplayId({'alias': 'platform_alias'}),
      'platform_alias',
    );
    expect(debugResolveWxmpAccountDisplayId({}), isNull);
  });

  test('文章转换为 MessageItem 时保留公众号显示 ID', () {
    final message = debugArticleToMessageItem(
      {
        'title': '微信文章标题',
        'link': 'https://mp.weixin.qq.com/s/article-id',
        'update_time': 1777075200,
      },
      mpName: '青春二工大',
      fakeid: 'fakeid-article',
      mpDisplayId: 'ssputw',
    );

    expect(message, isNotNull);
    expect(message?.sourceType, MessageSourceType.wechatPublic);
    expect(message?.mpBookId, 'fakeid-article');
    expect(message?.mpName, '青春二工大');
    expect(message?.mpDisplayId, 'ssputw');
  });
}
