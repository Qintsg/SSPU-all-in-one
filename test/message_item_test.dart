/*
 * 消息数据模型测试 — 校验微信账号显示字段兼容性
 * @Project : SSPU-all-in-one
 * @File : message_item_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-25
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/message_item.dart';

void main() {
  test('微信账号显示 ID 可序列化并反序列化', () {
    const message = MessageItem(
      id: 'wechat-json-1',
      title: '微信 JSON 测试',
      date: '2026-04-25',
      url: 'https://mp.weixin.qq.com/s/json',
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
      mpBookId: 'fakeid-json',
      mpName: '青春二工大',
      mpDisplayId: 'ssputw',
      timestamp: 1777075200000,
    );

    final json = message.toJson();
    final restored = MessageItem.fromJson(json);

    expect(json['mpDisplayId'], 'ssputw');
    expect(restored.mpDisplayId, 'ssputw');
    expect(restored.mpBookId, 'fakeid-json');
    expect(restored.mpName, '青春二工大');
  });

  test('旧缓存缺少微信账号显示 ID 时仍可读取', () {
    final restored = MessageItem.fromJson({
      'id': 'legacy-wechat-json',
      'title': '旧缓存微信文章',
      'date': '2026-04-25',
      'url': 'https://mp.weixin.qq.com/s/legacy',
      'sourceType': MessageSourceType.wechatPublic.name,
      'sourceName': MessageSourceName.wechatPublicPlaceholder.name,
      'category': MessageCategory.wechatArticle.name,
      'mpBookId': 'legacy-fakeid',
      'mpName': '旧公众号名',
    });

    expect(restored.mpDisplayId, isNull);
    expect(restored.mpBookId, 'legacy-fakeid');
    expect(restored.mpName, '旧公众号名');
  });
}
