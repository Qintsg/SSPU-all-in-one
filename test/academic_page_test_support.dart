/*
 * 教务中心页面测试支撑 — 提供 fake 服务与页面样例结果
 * @Project : SSPU-all-in-one
 * @File : academic_page_test_support.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_page_test.dart';

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
