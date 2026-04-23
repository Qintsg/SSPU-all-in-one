/*
 * 微信公众号平台文章服务测试 — 校验认证探针错误码处理
 * @Project : SSPU-all-in-one
 * @File : wxmp_article_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/services/wxmp_article_service.dart';

void main() {
  test('searchbiz 返回 200040 时不判定认证失效', () {
    final result = debugValidationResultForRet(WxmpApiError.searchUnavailable);

    // 200040 是搜索接口探针的业务状态，不应阻断刷新链路的文章接口验证。
    expect(result.isValid, isTrue);
    expect(result.message, contains('搜索接口暂时不可用'));
  });

  test('未知公众号平台错误码仍判定为不可用', () {
    final result = debugValidationResultForRet(999999);

    expect(result.isValid, isFalse);
    expect(result.message, contains('999999'));
  });
}
