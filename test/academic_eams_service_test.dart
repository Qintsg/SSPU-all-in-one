/*
 * 本专科教务服务测试 — 校验 OA 会话、只读摘要、开课检索与空闲教室查询
 * @Project : SSPU-all-in-one
 * @File : academic_eams_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/academic_eams.dart';
import 'package:sspu_all_in_one/models/academic_login_validation.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/academic_eams_service.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    StorageService.debugUseSharedPreferencesStorageForTesting(true);
  });

  tearDown(() {
    StorageService.debugUseSharedPreferencesStorageForTesting(null);
    SharedPreferences.setMockInitialValues({});
  });

  test('本专科教务自动刷新设置默认关闭并可持久化间隔', () async {
    final service = _buildService(
      gateway: _FakeAcademicEamsGateway(),
      campusReachable: true,
    );

    expect(await service.isAutoRefreshEnabled(), isFalse);
    expect(
      await service.getAutoRefreshIntervalMinutes(),
      AcademicEamsService.defaultAutoRefreshIntervalMinutes,
    );

    await service.setAutoRefreshEnabled(true);
    await service.setAutoRefreshIntervalMinutes(60);

    expect(await service.isAutoRefreshEnabled(), isTrue);
    expect(await service.getAutoRefreshIntervalMinutes(), 60);
  });

  test('未保存学工号时不访问本专科教务入口', () async {
    final gateway = _FakeAcademicEamsGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchOverview();

    expect(result.status, AcademicEamsQueryStatus.missingOaAccount);
    expect(gateway.openCount, 0);
  });

  test('校园网或 VPN 不可达时停止本专科教务查询', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicEamsGateway();
    final service = _buildService(gateway: gateway, campusReachable: false);

    final result = await service.fetchOverview();

    expect(result.status, AcademicEamsQueryStatus.campusNetworkUnavailable);
    expect(gateway.openCount, 0);
  });

  test('OA 会话失效时刷新登录态后解析教务摘要与课表', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    var refreshCount = 0;
    final gateway = _FakeAcademicEamsGateway(requireAuthFirst: true);
    final service = _buildService(
      gateway: gateway,
      campusReachable: true,
      refreshOaLogin: () async {
        refreshCount++;
        await AcademicCredentialsService.instance.saveOaLoginSession(
          _sessionSnapshot,
        );
        return AcademicLoginValidationResult(
          status: AcademicLoginValidationStatus.success,
          message: 'OA 登录校验通过',
          detail: '已刷新 OA 会话',
          checkedAt: DateTime(2026, 5, 2),
          entranceUri: _oaEntranceUri,
          finalUri: _oaEntranceUri,
          sessionSnapshot: _sessionSnapshot,
        );
      },
    );

    final result = await service.fetchOverview();

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(refreshCount, 1);
    expect(gateway.openCount, 2);
    expect(gateway.resetCookieHeaders.last['oa.sspu.edu.cn'], contains('OA='));
    expect(result.snapshot?.profile?.name, '张三');
    expect(result.snapshot?.courseTable?.entries.length, 1);
    expect(result.snapshot?.grades?.historyRecords.length, 1);
    expect(result.snapshot?.programCompletion?.completedCredits, 3);
    expect(result.snapshot?.exams?.records.single.location, '综合楼 A201');
    expect(result.snapshot?.hasCourseOfferingEntry, isTrue);
    expect(result.snapshot?.hasFreeClassroomEntry, isTrue);
  });

  test('独立课表读取只解析当前学期课表', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final service = _buildService(
      gateway: _FakeAcademicEamsGateway(),
      campusReachable: true,
    );

    final result = await service.fetchCourseTable();

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(result.snapshot?.courseTable?.entries.single.courseName, '高等数学');
    expect(result.snapshot?.grades, isNull);
    expect(result.snapshot?.programPlan, isNull);
  });

  test('开课检索会提交只读查询表单并解析列表', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeAcademicEamsGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.searchCourseOfferings(
      const AcademicCourseOfferingSearchCriteria(
        termName: '2025-2026-2',
        courseName: '高等数学',
        teacher: '张老师',
      ),
    );

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(gateway.lastSubmittedMethod, 'GET');
    expect(gateway.lastSubmittedFields?['semester'], '2025-2026-2');
    expect(gateway.lastSubmittedFields?['courseName'], '高等数学');
    expect(gateway.lastSubmittedFields?['teacherName'], '张老师');
    expect(result.courseOfferings?.records.single.locationText, '综合楼 A101');
  });

  test('空闲教室查询会提交只读表单并解析结果', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeAcademicEamsGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.searchFreeClassrooms(
      const AcademicFreeClassroomSearchCriteria(
        campus: '金海',
        building: '综合楼',
        dateText: '2026-05-02',
        lessonFrom: 1,
        lessonTo: 2,
      ),
    );

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(gateway.lastSubmittedFields?['campus'], '金海');
    expect(gateway.lastSubmittedFields?['building'], '综合楼');
    expect(gateway.lastSubmittedFields?['date'], '2026-05-02');
    expect(gateway.lastSubmittedFields?['startUnit'], '1');
    expect(gateway.lastSubmittedFields?['endUnit'], '2');
    expect(result.freeClassrooms?.records.single.roomName, '综合楼 A301');
  });
}

AcademicEamsService _buildService({
  required _FakeAcademicEamsGateway gateway,
  required bool campusReachable,
  AcademicEamsOaLoginRefresher? refreshOaLogin,
}) {
  return AcademicEamsService(
    gateway: gateway,
    refreshOaLogin: refreshOaLogin,
    campusNetworkStatusService: CampusNetworkStatusService(
      probeUri: Uri.parse('https://jx.sspu.edu.cn/'),
      probe: (probeUri, timeout) async => CampusNetworkProbeResult(
        reachable: campusReachable,
        detail: campusReachable ? '校园网可达' : '校园网不可达',
        statusCode: campusReachable ? 200 : null,
      ),
    ),
  );
}

class _FakeAcademicEamsGateway implements AcademicEamsGateway {
  _FakeAcademicEamsGateway({this.requireAuthFirst = false});

  final bool requireAuthFirst;
  final List<Map<String, String>> resetCookieHeaders = [];
  int openCount = 0;
  String? lastSubmittedMethod;
  Map<String, String>? lastSubmittedFields;

  @override
  Future<void> resetSession(Map<String, String> cookieHeadersByHost) async {
    resetCookieHeaders.add(cookieHeadersByHost);
  }

  @override
  Future<AcademicEamsHttpSnapshot> openEntryPage(
    Uri entranceUri,
    Duration timeout,
  ) async {
    openCount++;
    if (requireAuthFirst && openCount == 1) return _casSnapshot;
    return _homeSnapshot;
  }

  @override
  Future<AcademicEamsHttpSnapshot> fetchPage(
    Uri pageUri,
    Duration timeout,
  ) async {
    final path = pageUri.path;
    if (path.contains('home!submenus.action') &&
        pageUri.queryParameters['menu.id'] == '5') {
      return _submenuSnapshot;
    }
    if (path.contains('home!submenus.action')) {
      return _emptySubmenuSnapshot;
    }
    if (path.contains('home!index.action')) {
      return _homeSnapshot;
    }
    if (path.contains('courseTableForStd.action')) {
      return _courseTableSnapshot;
    }
    if (path.contains('/teach/grade/course/person.action') &&
        !path.contains('historyCourseGrade')) {
      return _currentGradeSnapshot;
    }
    if (path.contains('historyCourseGrade')) {
      return _historyGradeSnapshot;
    }
    if (path.contains('/teach/program/student/myPlan.action')) {
      return _programPlanSnapshot;
    }
    if (path.contains('stdExamTable.action')) {
      return _examSnapshot;
    }
    if (path.contains('publicSearch.action')) {
      return _courseOfferingEntrySnapshot;
    }
    if (path.contains('freeClassroom.action')) {
      return _freeClassroomEntrySnapshot;
    }
    return AcademicEamsHttpSnapshot(
      finalUri: pageUri,
      statusCode: 404,
      body: 'not found',
    );
  }

  @override
  Future<AcademicEamsHttpSnapshot> submitForm({
    required Uri formUri,
    required String method,
    required Map<String, String> fields,
    required Duration timeout,
  }) async {
    lastSubmittedMethod = method;
    lastSubmittedFields = fields;
    if (formUri.path.contains('publicSearch!search.action')) {
      return _courseOfferingResultSnapshot;
    }
    if (formUri.path.contains('freeClassroom!search.action')) {
      return _freeClassroomResultSnapshot;
    }
    return AcademicEamsHttpSnapshot(
      finalUri: formUri,
      statusCode: 404,
      body: 'not found',
    );
  }
}

final AcademicLoginSessionSnapshot _sessionSnapshot =
    AcademicLoginSessionSnapshot(
      cookieHeadersByHost: const {
        'oa.sspu.edu.cn': 'OA=fake-oa-session',
        'id.sspu.edu.cn': 'CASTGC=fake-cas-session',
      },
      authenticatedAt: DateTime(2026, 5, 2),
      entranceUri: _oaEntranceUri,
      finalUri: _oaEntranceUri,
    );

final Uri _oaEntranceUri = Uri.parse(
  'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
);

final AcademicEamsHttpSnapshot _casSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse('https://id.sspu.edu.cn/cas/login'),
  statusCode: 200,
  body: '<html><title>统一身份认证</title></html>',
);

final AcademicEamsHttpSnapshot _homeSnapshot = AcademicEamsHttpSnapshot(
  finalUri: AcademicEamsService.defaultHomeUri,
  statusCode: 200,
  body: '''
<html>
  <head><title>EAMS 3.0.0</title></head>
  <body>
    <table>
      <tr><td>姓名</td><td>张三</td></tr>
      <tr><td>学号</td><td>20260001</td></tr>
      <tr><td>院系</td><td>计算机与信息工程学院</td></tr>
      <tr><td>专业</td><td>软件工程</td></tr>
      <tr><td>班级</td><td>软件 241</td></tr>
    </table>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _emptySubmenuSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/home!submenus.action'),
  statusCode: 200,
  body: '<html><body></body></html>',
);

final AcademicEamsHttpSnapshot _submenuSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse(
    'https://jx.sspu.edu.cn/eams/home!submenus.action?menu.id=5',
  ),
  statusCode: 200,
  body: '''
<html>
  <body>
    <a href="/eams/freeClassroom.action">空闲教室查询</a>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _courseTableSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/courseTableForStd.action'),
  statusCode: 200,
  body: '''
<html>
  <body>
    <div>2025-2026 第2学期</div>
    <table>
      <tr>
        <th>节次</th><th>周一</th><th>周二</th><th>周三</th>
        <th>周四</th><th>周五</th><th>周六</th><th>周日</th>
      </tr>
      <tr>
        <td>1</td>
        <td rowspan="2">高等数学<br/>张老师<br/>综合楼 A101<br/>1-16周</td>
        <td></td><td></td><td></td><td></td><td></td><td></td>
      </tr>
      <tr>
        <td>2</td>
        <td></td><td></td><td></td><td></td><td></td><td></td>
      </tr>
    </table>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _currentGradeSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse(
    'https://jx.sspu.edu.cn/eams/teach/grade/course/person.action',
  ),
  statusCode: 200,
  body: '''
<html>
  <body>
    <table>
      <tr><th>课程名称</th><th>总评成绩</th><th>学分</th><th>学年学期</th></tr>
      <tr><td>高等数学</td><td>92</td><td>3</td><td>2025-2026-2</td></tr>
    </table>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _historyGradeSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse(
    'https://jx.sspu.edu.cn/eams/teach/grade/course/person!historyCourseGrade.action?projectType=MAJOR',
  ),
  statusCode: 200,
  body: '''
<html>
  <body>
    <table>
      <tr><th>课程名称</th><th>成绩</th><th>学分</th><th>学年学期</th></tr>
      <tr><td>程序设计基础</td><td>85</td><td>4</td><td>2025-2026-1</td></tr>
    </table>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _programPlanSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse(
    'https://jx.sspu.edu.cn/eams/teach/program/student/myPlan.action',
  ),
  statusCode: 200,
  body: '''
<html>
  <body>
    <h2>培养计划</h2>
    <table>
      <tr><th>模块</th><th>课程代码</th><th>课程名称</th><th>学分</th><th>建议学期</th></tr>
      <tr><td>公共基础</td><td>MATH101</td><td>高等数学</td><td>3</td><td>2025-2026-2</td></tr>
      <tr><td>专业基础</td><td>CS100</td><td>程序设计基础</td><td>4</td><td>2025-2026-1</td></tr>
    </table>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _examSnapshot = AcademicEamsHttpSnapshot(
  finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/stdExamTable.action'),
  statusCode: 200,
  body: '''
<html>
  <body>
    <table>
      <tr><th>课程名称</th><th>考试时间</th><th>考试地点</th><th>座位号</th></tr>
      <tr><td>高等数学</td><td>2026-06-20 08:30</td><td>综合楼 A201</td><td>18</td></tr>
    </table>
  </body>
</html>
''',
);

final AcademicEamsHttpSnapshot _courseOfferingEntrySnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/publicSearch.action'),
      statusCode: 200,
      body: '''
<html>
  <body>
    <form action="publicSearch!search.action" method="get">
      <input type="hidden" name="pageNo" value="1" />
      <input type="text" name="semester" value="" />
      <input type="text" name="courseName" value="" />
      <input type="text" name="teacherName" value="" />
      <input type="text" name="courseCode" value="" />
    </form>
    <table>
      <tr><th>课程名称</th><th>教师</th></tr>
      <tr><td>软件工程导论</td><td>王老师</td></tr>
    </table>
  </body>
</html>
''',
    );

final AcademicEamsHttpSnapshot _courseOfferingResultSnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/publicSearch!search.action',
      ),
      statusCode: 200,
      body: '''
<html>
  <body>
    <table>
      <tr><th>课程代码</th><th>课程名称</th><th>教师</th><th>学分</th><th>容量</th><th>地点</th><th>上课时间</th></tr>
      <tr><td>MATH101</td><td>高等数学</td><td>张老师</td><td>3</td><td>60</td><td>综合楼 A101</td><td>周一 1-2 节</td></tr>
    </table>
  </body>
</html>
''',
    );

final AcademicEamsHttpSnapshot _freeClassroomEntrySnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/freeClassroom.action'),
      statusCode: 200,
      body: '''
<html>
  <body>
    <form action="freeClassroom!search.action" method="post">
      <input type="text" name="campus" value="" />
      <input type="text" name="building" value="" />
      <input type="text" name="date" value="" />
      <input type="text" name="startUnit" value="1" />
      <input type="text" name="endUnit" value="2" />
    </form>
  </body>
</html>
''',
    );

final AcademicEamsHttpSnapshot _freeClassroomResultSnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/freeClassroom!search.action',
      ),
      statusCode: 200,
      body: '''
<html>
  <body>
    <table>
      <tr><th>校区</th><th>楼宇</th><th>教室</th><th>容量</th><th>日期</th><th>节次</th></tr>
      <tr><td>金海</td><td>综合楼</td><td>综合楼 A301</td><td>80</td><td>2026-05-02</td><td>1-2</td></tr>
    </table>
  </body>
</html>
''',
    );
