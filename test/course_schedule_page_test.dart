/*
 * 课程表页面测试 — 校验独立课表页展示、自动刷新与错误状态
 * @Project : SSPU-all-in-one
 * @File : course_schedule_page_test.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/academic_eams.dart';
import 'package:sspu_all_in_one/pages/course_schedule_page.dart';
import 'package:sspu_all_in_one/services/academic_eams_service.dart';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  testWidgets('课程表页面自动刷新开启时会主动读取课表', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: CourseSchedulePage(
          academicEamsService: _FakeAcademicEamsClient(result: _successResult),
          autoRefreshEnabledOverride: true,
          autoRefreshIntervalOverride: 30,
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('高等数学'));

    expect(find.text('课程表'), findsOneWidget);
    expect(find.textContaining('自动刷新已开启'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.textContaining('周一 第1-2节'), findsOneWidget);
    expect(find.text('返回'), findsNothing);
  });

  testWidgets('课程表页面展示缺少 OA 密码提示', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: CourseSchedulePage(
          academicEamsService: _FakeAcademicEamsClient(
            result: _missingPassword,
          ),
          autoRefreshEnabledOverride: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('course-schedule-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('请先保存 OA 账号密码'), findsOneWidget);
    expect(find.textContaining('刷新 OA/CAS 会话'), findsOneWidget);
  });

  testWidgets('课程表页面作为二级页面打开时显示返回按钮', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: Navigator(
          onGenerateRoute: (_) =>
              FluentPageRoute(builder: (_) => const SizedBox.shrink()),
        ),
      ),
    );

    final context = tester.element(find.byType(SizedBox));
    Navigator.of(context).push(
      FluentPageRoute(
        builder: (_) => CourseSchedulePage(
          academicEamsService: _FakeAcademicEamsClient(result: _successResult),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('返回'), findsOneWidget);
  });
}

class _FakeAcademicEamsClient implements AcademicEamsClient {
  const _FakeAcademicEamsClient({required this.result});

  final AcademicEamsQueryResult result;

  @override
  Future<AcademicEamsQueryResult> fetchCourseTable() async {
    return result;
  }

  @override
  Future<AcademicEamsQueryResult> fetchOverview() async {
    return result;
  }
}

final AcademicEamsQueryResult _successResult = AcademicEamsQueryResult(
  status: AcademicEamsQueryStatus.success,
  message: '本专科教务只读查询成功',
  detail: '已读取当前学期课表。',
  checkedAt: DateTime(2026, 5, 2, 10, 0),
  entranceUri: Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
  ),
  snapshot: AcademicEamsSnapshot(
    fetchedAt: DateTime(2026, 5, 2, 10, 0),
    sourceUri: Uri.parse(
      'https://jx.sspu.edu.cn/eams/courseTableForStd.action',
    ),
    warnings: const [],
    hasCourseOfferingEntry: true,
    hasFreeClassroomEntry: true,
    profile: const AcademicEamsProfile(
      name: '张三',
      studentId: '20260001',
      department: '计算机与信息工程学院',
      major: '软件工程',
      className: '软件 241',
      rawFields: {'姓名': '张三'},
    ),
    courseTable: AcademicCourseTableSnapshot(
      termName: '2025-2026 第2学期',
      entries: const [
        AcademicCourseTableEntry(
          courseName: '高等数学',
          weekday: 1,
          startUnit: 1,
          endUnit: 2,
          timeText: '周一 第1-2节',
          teacher: '张老师',
          location: '综合楼 A101',
          weekDescription: '1-16周',
          rawText: '高等数学 张老师 综合楼 A101 1-16周',
        ),
      ],
      fetchedAt: DateTime(2026, 5, 2, 10, 0),
      sourceUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/courseTableForStd.action',
      ),
    ),
  ),
);

final AcademicEamsQueryResult _missingPassword = AcademicEamsQueryResult(
  status: AcademicEamsQueryStatus.missingOaPassword,
  message: '请先保存 OA 账号密码',
  detail: '本专科教务查询需要在登录态失效时刷新 OA/CAS 会话。',
  checkedAt: DateTime(2026, 5, 2, 10, 0),
  entranceUri: Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
  ),
);
