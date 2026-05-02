/*
 * 消息列表项组件测试 — 校验微信推文元信息展示
 * @Project : SSPU-all-in-one
 * @File : message_tile_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-25
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/message_item.dart';
import 'package:sspu_all_in_one/theme/fluent_tokens.dart';
import 'package:sspu_all_in_one/widgets/message_tile.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester,
    MessageItem message, {
    double width = 900,
  }) async {
    final theme = FluentTokenTheme.light();
    await tester.pumpWidget(
      FluentApp(
        theme: theme,
        home: ScaffoldPage(
          content: SizedBox(
            width: width,
            child: MessageTile(
              message: message,
              isRead: false,
              isDark: false,
              theme: theme,
              onTap: () {},
              onMarkRead: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('微信推文只展示来源类型和公众号名称标签', (tester) async {
    const message = MessageItem(
      id: 'wechat-1',
      title: '微信测试标题',
      date: '2026-04-25',
      url: 'https://mp.weixin.qq.com/s/test',
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
      mpBookId: 'fakeid-1',
      mpName: '青春二工大',
      mpDisplayId: 'ssputw',
    );

    await pumpTile(tester, message);

    expect(find.text('微信推文'), findsOneWidget);
    expect(find.text('青春二工大'), findsOneWidget);
    expect(find.text('微信号：ssputw'), findsNothing);
  });

  testWidgets('微信账号名缺失时展示明确 fallback', (tester) async {
    const message = MessageItem(
      id: 'wechat-2',
      title: '微信 fallback 测试',
      date: '2026-04-25',
      url: 'https://mp.weixin.qq.com/s/fallback',
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
    );

    await pumpTile(tester, message);

    expect(find.text('微信推文'), findsOneWidget);
    expect(find.text('公众号名称未知'), findsOneWidget);
    expect(find.text('微信号未知'), findsNothing);
  });

  testWidgets('非微信消息仍展示所有不同来源和分类标签', (tester) async {
    const message = MessageItem(
      id: 'school-1',
      title: '官网测试标题',
      date: '2026-04-25',
      url: 'https://www.sspu.edu.cn/test',
      sourceType: MessageSourceType.schoolWebsite,
      sourceName: MessageSourceName.jwc,
      category: MessageCategory.jwcStudent,
    );

    await pumpTile(tester, message);

    expect(find.text('学校官网'), findsOneWidget);
    expect(find.text('教务处'), findsOneWidget);
    expect(find.text('学生专栏'), findsOneWidget);
  });

  testWidgets('窄屏消息卡片保持微信账号 fallback 与操作区可布局', (tester) async {
    const message = MessageItem(
      id: 'wechat-narrow',
      title: '这是一条用于覆盖窄屏布局的微信推文标题，标题较长但不应挤压右侧操作按钮',
      date: '2026-04-25',
      url: 'https://mp.weixin.qq.com/s/narrow',
      sourceType: MessageSourceType.wechatPublic,
      sourceName: MessageSourceName.wechatPublicPlaceholder,
      category: MessageCategory.wechatArticle,
      mpName: '青春二工大',
      mpDisplayId: 'sspu-super-long-wechat-display-id-for-responsive-layout',
    );

    await pumpTile(tester, message, width: 320);

    expect(find.text('微信推文'), findsOneWidget);
    expect(find.text('青春二工大'), findsOneWidget);
    expect(find.byIcon(FluentIcons.open_in_new_window), findsOneWidget);
    expect(find.byIcon(FluentIcons.read), findsOneWidget);
  });
}
