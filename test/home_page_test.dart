/*
 * 首页测试 — 校验校园卡余额卡片展示、手动刷新和详情入口
 * @Project : SSPU-all-in-one
 * @File : home_page_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/campus_card.dart';
import 'package:sspu_all_in_one/pages/home_page.dart';
import 'package:sspu_all_in_one/services/campus_card_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

/// 等待目标组件出现，避免页面异步加载尚未完成时提前断言。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// 首页存在入场动画和 Fluent 点击态短计时器，测试结束前统一清理。
Future<void> disposeHomePage(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.debugUseSharedPreferencesStorageForTesting(true);
  });

  tearDown(() {
    StorageService.debugUseSharedPreferencesStorageForTesting(null);
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('首页校园卡卡片可手动刷新并进入详情页', (tester) async {
    final service = _FakeCampusCardClient(result: _successResult);
    await tester.pumpWidget(
      FluentApp(
        home: HomePage(
          campusCardService: service,
          campusCardAutoRefreshEnabledOverride: false,
          campusCardAutoRefreshIntervalOverride: 30,
        ),
      ),
    );

    expect(find.text('校园卡余额'), findsOneWidget);
    expect(find.textContaining('自动刷新未开启'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.refresh));
    await pumpUntilFound(tester, find.text('¥23.45'));

    expect(service.fetchCount, 1);
    expect(find.text('账户余额'), findsOneWidget);
    expect(find.text('卡状态：冻结'), findsOneWidget);
    expect(find.textContaining('2026-04-29'), findsOneWidget);
    expect(find.text('上次刷新：2026-04-30 10:20'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('校园卡详情'), findsOneWidget);
    expect(find.text('余额：¥23.45'), findsOneWidget);
    expect(find.text('交易记录查询'), findsOneWidget);
    await disposeHomePage(tester);
  });

  testWidgets('校园卡自动刷新开启时会主动读取余额', (tester) async {
    final service = _FakeCampusCardClient(result: _successResult);
    await tester.pumpWidget(
      FluentApp(
        home: HomePage(
          campusCardService: service,
          campusCardAutoRefreshEnabledOverride: true,
          campusCardAutoRefreshIntervalOverride: 30,
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('¥23.45'));

    expect(service.fetchCount, 1);
    await disposeHomePage(tester);
  });
}

class _FakeCampusCardClient implements CampusCardBalanceClient {
  _FakeCampusCardClient({required this.result});

  final CampusCardQueryResult result;
  int fetchCount = 0;

  @override
  Future<CampusCardQueryResult> fetchCampusCard({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    fetchCount++;
    return result;
  }
}

final CampusCardQueryResult _successResult = CampusCardQueryResult(
  status: CampusCardQueryStatus.success,
  message: '校园卡查询成功',
  detail: '已读取校园卡余额、卡状态和交易记录。',
  checkedAt: DateTime(2026, 4, 30, 10, 20),
  entranceUri: Uri.parse(
    'https://oa.sspu.edu.cn//interface/Entrance.jsp?id=xykxt',
  ),
  finalUri: Uri.parse('https://card.sspu.edu.cn/epay/'),
  snapshot: CampusCardSnapshot(
    balance: 23.45,
    status: '冻结',
    fetchedAt: DateTime(2026, 4, 30, 10, 20),
    sourceUri: Uri.parse('https://card.sspu.edu.cn/epay/'),
    records: const [
      CampusCardTransactionRecord(
        occurredAt: '2026-04-29 12:10',
        amount: -12.5,
        merchant: '一食堂',
        type: '消费',
        balanceAfter: 23.45,
        rawCells: ['2026-04-29 12:10', '消费', '一食堂', '-12.50', '23.45'],
      ),
    ],
  ),
);
