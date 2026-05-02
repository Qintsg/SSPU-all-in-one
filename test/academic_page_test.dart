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

    await tester.tap(find.byKey(const Key('academic-student-report-refresh')));
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

    await tester.tap(find.byKey(const Key('open-course-schedule')));
    await tester.pumpAndSettle();

    expect(find.text('课程表'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.textContaining('周一 第1-2节'), findsOneWidget);
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

class _FakeStudentReportClient implements StudentReportClient {
  const _FakeStudentReportClient({required this.result});

  final StudentReportQueryResult result;

  @override
  Future<StudentReportQueryResult> fetchSecondClassroomCredits() async {
    return result;
  }

  @override
  Future<StudentReportQueryResult> validateLoginStatus() async {
    return result;
  }
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

final StudentReportQueryResult _creditResult = StudentReportQueryResult(
  status: StudentReportQueryStatus.success,
  message: '第二课堂学分查询成功',
  detail: '已读取第二课堂逐项得分明细，未将单项分值合并为总学分。',
  checkedAt: DateTime(2026, 5, 1),
  entranceUri: Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=xgreport',
  ),
  finalUri: Uri.parse(
    'https://xgbb.sspu.edu.cn/sharedc/core/home/secondClassroom.do',
  ),
  summary: SecondClassroomCreditSummary(
    fetchedAt: DateTime(2026, 5, 1),
    sourceUri: Uri.parse(
      'https://xgbb.sspu.edu.cn/sharedc/core/home/secondClassroom.do',
    ),
    records: const [
      SecondClassroomCreditRecord(
        category: '思想成长',
        itemName: '主题团日',
        credit: 1.5,
        occurredAt: '2026-04-20',
        status: '已认定',
        rawCells: ['思想成长', '主题团日', '2026-04-20', '已认定', '1.5'],
      ),
      SecondClassroomCreditRecord(
        category: '创新创业',
        itemName: '创新训练项目',
        credit: 2,
        occurredAt: '2026-04-25',
        status: '通过',
        rawCells: ['创新创业', '创新训练项目', '2026-04-25', '通过', '2'],
      ),
    ],
  ),
);

final AcademicEamsQueryResult _academicEamsResult = AcademicEamsQueryResult(
  status: AcademicEamsQueryStatus.success,
  message: '本专科教务只读查询成功',
  detail: '已读取课表、成绩、考试和培养计划。',
  checkedAt: DateTime(2026, 5, 2),
  entranceUri: Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
  ),
  finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/home!index.action'),
  snapshot: AcademicEamsSnapshot(
    fetchedAt: DateTime(2026, 5, 2),
    sourceUri: Uri.parse('https://jx.sspu.edu.cn/eams/home!index.action'),
    warnings: const [],
    hasCourseOfferingEntry: true,
    hasFreeClassroomEntry: true,
    profile: const AcademicEamsProfile(
      name: '张三',
      studentId: '20260001',
      department: '计算机与信息工程学院',
      major: '软件工程',
      className: '软件 241',
      rawFields: {'姓名': '张三', '学号': '20260001'},
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
      fetchedAt: DateTime(2026, 5, 2),
      sourceUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/courseTableForStd.action',
      ),
    ),
    grades: AcademicGradeSnapshot(
      currentTermRecords: const [
        AcademicGradeRecord(
          courseName: '高等数学',
          scoreText: '92',
          rawCells: ['高等数学', '92', '3'],
          credit: 3,
        ),
      ],
      historyRecords: const [],
      fetchedAt: DateTime(2026, 5, 2),
      sourceUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/teach/grade/course/person.action',
      ),
    ),
    programPlan: AcademicProgramPlanSnapshot(
      courses: const [
        AcademicProgramPlanCourse(
          courseName: '高等数学',
          rawCells: ['公共基础', '高等数学', '3'],
          credit: 3,
          moduleName: '公共基础',
        ),
      ],
      fetchedAt: DateTime(2026, 5, 2),
      sourceUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/teach/program/student/myPlan.action',
      ),
    ),
    programCompletion: const AcademicProgramCompletionSnapshot(
      completedCourseCount: 1,
      pendingCourseCount: 0,
      completedCredits: 3,
      pendingCredits: 0,
      moduleProgress: [
        AcademicProgramModuleProgress(
          moduleName: '公共基础',
          totalCourseCount: 1,
          completedCourseCount: 1,
          pendingCourseCount: 0,
          totalCredits: 3,
          completedCredits: 3,
          pendingCredits: 0,
        ),
      ],
    ),
    exams: AcademicExamSnapshot(
      records: const [
        AcademicExamRecord(
          courseName: '高等数学',
          rawCells: ['高等数学', '2026-06-20 08:30', '综合楼 A201', '18'],
          examTime: '2026-06-20 08:30',
          location: '综合楼 A201',
          seatNumber: '18',
        ),
      ],
      fetchedAt: DateTime(2026, 5, 2),
      sourceUri: Uri.parse('https://jx.sspu.edu.cn/eams/stdExamTable.action'),
    ),
  ),
);
