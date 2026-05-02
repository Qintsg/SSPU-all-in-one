/*
 * 教务中心页面测试 — 校验体育部课外活动考勤汇总与明细展示
 * @Project : SSPU-all-in-one
 * @File : academic_page_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/academic_eams.dart';
import 'package:sspu_all_in_one/models/sports_attendance.dart';
import 'package:sspu_all_in_one/models/student_report.dart';
import 'package:sspu_all_in_one/pages/academic_page.dart';
import 'package:sspu_all_in_one/services/academic_eams_service.dart';
import 'package:sspu_all_in_one/services/sports_attendance_service.dart';
import 'package:sspu_all_in_one/services/student_report_service.dart';

part 'academic_page_test_support.dart';

/// 等待异步卡片加载完成。
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
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: false,
          studentReportAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    expect(find.textContaining('自动刷新未开启'), findsWidgets);
    await tester.tap(find.byKey(const Key('academic-sports-refresh')));
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
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: SportsAttendanceQueryResult(
              status: SportsAttendanceQueryStatus.missingSportsPassword,
              message: '请先保存体育部查询密码',
              detail: '体育部查询系统密码与 OA 密码不同，需单独配置。',
              checkedAt: DateTime(2026, 4, 30),
              entranceUri: Uri.parse('https://tygl.sspu.edu.cn/sportscore/'),
            ),
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: false,
          studentReportAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('academic-sports-refresh')));
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
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: true,
          sportsAttendanceAutoRefreshIntervalOverride: 30,
          studentReportAutoRefreshEnabledOverride: false,
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
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: SportsAttendanceQueryResult(
              status: SportsAttendanceQueryStatus.campusNetworkUnavailable,
              message: '校园网 / VPN 不可用，无法访问体育部查询系统',
              detail: '无法访问 tygl.sspu.edu.cn',
              checkedAt: DateTime(2026, 4, 30),
              entranceUri: Uri.parse('https://tygl.sspu.edu.cn/sportscore/'),
            ),
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: false,
          studentReportAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('academic-sports-refresh')));
    await pumpUntilFound(tester, find.textContaining('校园网 / VPN 不可用'));

    expect(find.textContaining('无法访问体育部查询系统'), findsOneWidget);
    await disposeAcademicPage(tester);
  });

  testWidgets('教务中心展示第二课堂学分并可进入明细页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: false,
          studentReportAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    final studentReportRefresh = find.byKey(
      const Key('academic-student-report-refresh'),
    );
    await tester.ensureVisible(studentReportRefresh);
    await tester.tap(studentReportRefresh);
    await pumpUntilFound(tester, find.text('2'));

    expect(find.text('第二课堂学分'), findsOneWidget);
    expect(find.text('项得分记录'), findsOneWidget);
    expect(find.text('总学分'), findsNothing);
    expect(find.text('主题团日'), findsOneWidget);
    expect(find.text('创新训练项目'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('上次刷新：2026-05-01 00:00'), findsOneWidget);

    await tester.tap(find.text('主题团日'));
    await tester.pumpAndSettle();

    expect(find.text('得分详情'), findsOneWidget);
    expect(find.text('原始记录'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    final detailButton = find.text('查看全部得分记录');
    await tester.ensureVisible(detailButton);
    await tester.pumpAndSettle();
    await tester.tap(detailButton);
    await tester.pumpAndSettle();

    expect(find.text('第二课堂得分明细'), findsOneWidget);
    expect(find.textContaining('得分记录 2 项'), findsOneWidget);
    expect(find.textContaining('创新训练项目'), findsWidgets);
    await disposeAcademicPage(tester);
  });

  testWidgets('教务中心自动刷新开启时会主动读取第二课堂学分', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: false,
          studentReportAutoRefreshEnabledOverride: true,
          studentReportAutoRefreshIntervalOverride: 30,
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('2'));

    expect(find.text('项得分记录'), findsOneWidget);
    await disposeAcademicPage(tester);
  });

  testWidgets('教务中心展示本专科教务摘要并可进入课程表页', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: AcademicPage(
          academicEamsService: _FakeAcademicEamsClient(
            result: _academicEamsResult,
          ),
          sportsAttendanceService: _FakeSportsAttendanceClient(
            result: _successResult,
          ),
          studentReportService: _FakeStudentReportClient(result: _creditResult),
          academicEamsAutoRefreshEnabledOverride: false,
          sportsAttendanceAutoRefreshEnabledOverride: false,
          studentReportAutoRefreshEnabledOverride: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('academic-eams-refresh')));
    await pumpUntilFound(tester, find.textContaining('姓名：张三'));

    expect(find.text('本专科教务'), findsOneWidget);
    expect(find.textContaining('课表 1门'), findsOneWidget);
    expect(find.textContaining('开课检索：入口已识别'), findsOneWidget);

    final openCourseSchedule = find.byKey(const Key('open-course-schedule'));
    await tester.ensureVisible(openCourseSchedule);
    await tester.tap(openCourseSchedule);
    await tester.pumpAndSettle();

    expect(find.text('课程表'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.textContaining('周一 第1-2节'), findsOneWidget);
    await disposeAcademicPage(tester);
  });
}
