/*
 * 教务中心页面测试 — 校验体育部课外活动考勤汇总与明细展示
 * @Project : SSPU-all-in-one
 * @File : academic_page_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/sports_attendance.dart';
import 'package:sspu_all_in_one/pages/academic_page.dart';
import 'package:sspu_all_in_one/services/sports_attendance_service.dart';

/// 等待异步考勤卡片加载完成。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// 推进页面动画和 Fluent 点击态短计时器，避免组件卸载后残留 timer。
Future<void> disposeAcademicPage(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 420));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  testWidgets('教务中心展示体育部考勤总次数并可进入明细页', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          sportsAttendanceAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    expect(find.textContaining('自动刷新未开启'), findsOneWidget);
    await tester.tap(find.byIcon(FluentIcons.refresh));
    await pumpUntilFound(tester, find.text('8'));

    expect(find.text('课外活动考勤'), findsOneWidget);
    expect(find.text('总次数'), findsOneWidget);
    expect(find.text('早操 2 次'), findsOneWidget);
    expect(find.text('课外活动 3 次'), findsOneWidget);
    expect(find.text('次数调整 -1 次'), findsOneWidget);
    expect(find.text('体育长廊 4 次'), findsOneWidget);
    expect(find.text('上次刷新：2026-04-30 00:00'), findsOneWidget);

    await tester.tap(find.text('查看考勤记录'));
    await tester.pumpAndSettle();

    expect(find.text('课外活动考勤记录'), findsOneWidget);
    expect(find.textContaining('明细 2 条'), findsOneWidget);
    expect(find.textContaining('2026-04-01'), findsWidgets);
    expect(find.textContaining('体育长廊'), findsWidgets);
    await disposeAcademicPage(tester);
  });

  testWidgets('教务中心展示体育部登录失败状态', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: SportsAttendanceQueryResult(
              status: SportsAttendanceQueryStatus.missingSportsPassword,
              message: '请先保存体育部查询密码',
              detail: '体育部查询系统密码与 OA 密码不同，需单独配置。',
              checkedAt: DateTime(2026, 4, 30),
              entranceUri: Uri.parse('https://tygl.sspu.edu.cn/sportscore/'),
            ),
          ),
          sportsAttendanceAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.refresh));
    await pumpUntilFound(tester, find.text('请先保存体育部查询密码'));

    expect(find.text('请先保存体育部查询密码'), findsOneWidget);
    expect(find.textContaining('OA 密码不同'), findsOneWidget);
    expect(find.text('上次刷新：2026-04-30 00:00'), findsOneWidget);
    await disposeAcademicPage(tester);
  });

  testWidgets('教务中心自动刷新开启时会主动读取体育考勤', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          sportsAttendanceAutoRefreshEnabledOverride: true,
          sportsAttendanceAutoRefreshIntervalOverride: 30,
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('8'));

    expect(find.text('总次数'), findsOneWidget);
    await disposeAcademicPage(tester);
  });

  testWidgets('教务中心展示校园网或 VPN 不可用状态', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: SportsAttendanceQueryResult(
              status: SportsAttendanceQueryStatus.campusNetworkUnavailable,
              message: '校园网 / VPN 不可用，无法访问体育部查询系统',
              detail: '无法访问 tygl.sspu.edu.cn',
              checkedAt: DateTime(2026, 4, 30),
              entranceUri: Uri.parse('https://tygl.sspu.edu.cn/sportscore/'),
            ),
          ),
          sportsAttendanceAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.refresh));
    await pumpUntilFound(tester, find.textContaining('校园网 / VPN 不可用'));

    expect(find.textContaining('无法访问体育部查询系统'), findsOneWidget);
    await disposeAcademicPage(tester);
  });
}

class _FakeSportsAttendanceClient implements SportsAttendanceClient {
  const _FakeSportsAttendanceClient({required this.result});

  final SportsAttendanceQueryResult result;

  @override
  Future<SportsAttendanceQueryResult> fetchAttendanceSummary() async {
    return result;
  }
}

final SportsAttendanceQueryResult _successResult = SportsAttendanceQueryResult(
  status: SportsAttendanceQueryStatus.success,
  message: '体育部考勤查询成功',
  detail: '已读取课外活动考勤总次数与明细记录。',
  checkedAt: DateTime(2026, 4, 30),
  entranceUri: Uri.parse('https://tygl.sspu.edu.cn/sportscore/'),
  finalUri: Uri.parse(
    'https://tygl.sspu.edu.cn/sportscore/stScore.aspx?item=1',
  ),
  summary: SportsAttendanceSummary(
    morningExerciseCount: 2,
    extracurricularActivityCount: 3,
    countAdjustmentCount: -1,
    sportsCorridorCount: 4,
    fetchedAt: DateTime(2026, 4, 30),
    sourceUri: Uri.parse(
      'https://tygl.sspu.edu.cn/sportscore/stScore.aspx?item=1',
    ),
    records: [
      const SportsAttendanceRecord(
        category: SportsAttendanceCategory.morningExercise,
        count: 1,
        occurredAt: '2026-04-01 06:50',
        project: '晨跑',
        location: '操场',
        cells: ['2026-04-01 06:50', '早操', '晨跑', '操场', '1次'],
      ),
      const SportsAttendanceRecord(
        category: SportsAttendanceCategory.sportsCorridor,
        count: 4,
        occurredAt: '2026-04-05',
        project: '长廊学习',
        location: '体育长廊',
        cells: ['2026-04-05', '体育长廊', '长廊学习', '体育长廊', '4次'],
      ),
    ],
  ),
);
