/*
 * 本专科教务服务测试支撑 — 提供 fake 网关、会话快照与页面样例
 * @Project : SSPU-all-in-one
 * @File : academic_eams_service_test_support.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'dart:async';

import 'package:sspu_all_in_one/models/academic_login_validation.dart';
import 'package:sspu_all_in_one/services/academic_eams_service.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';

AcademicEamsService buildAcademicEamsServiceForTest({
  required FakeAcademicEamsGateway gateway,
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

class FakeAcademicEamsGateway implements AcademicEamsGateway {
  FakeAcademicEamsGateway({
    this.requireAuthFirst = false,
    this.failFreeClassroomMenuOnce = false,
  });

  final bool requireAuthFirst;
  final bool failFreeClassroomMenuOnce;
  final List<Map<String, String>> resetCookieHeaders = [];
  int openCount = 0;
  String? lastSubmittedMethod;
  Map<String, String>? lastSubmittedFields;
  bool _hasFailedFreeClassroomMenu = false;

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
    if (requireAuthFirst && openCount == 1) return academicEamsCasSnapshot;
    return academicEamsHomeSnapshot;
  }

  @override
  Future<AcademicEamsHttpSnapshot> fetchPage(
    Uri pageUri,
    Duration timeout,
  ) async {
    final path = pageUri.path;
    if (path.contains('home!submenus.action') &&
        pageUri.queryParameters['menu.id'] == '5') {
      if (failFreeClassroomMenuOnce && !_hasFailedFreeClassroomMenu) {
        _hasFailedFreeClassroomMenu = true;
        throw TimeoutException('menu timeout');
      }
      return academicEamsSubmenuSnapshot;
    }
    if (path.contains('home!submenus.action')) {
      return academicEamsEmptySubmenuSnapshot;
    }
    if (path.contains('home!index.action')) return academicEamsHomeSnapshot;
    if (path.contains('courseTableForStd.action')) {
      return academicEamsCourseTableSnapshot;
    }
    if (path.contains('/teach/grade/course/person.action') &&
        !path.contains('historyCourseGrade')) {
      return academicEamsCurrentGradeSnapshot;
    }
    if (path.contains('historyCourseGrade')) {
      return academicEamsHistoryGradeSnapshot;
    }
    if (path.contains('/teach/program/student/myPlan.action')) {
      return academicEamsProgramPlanSnapshot;
    }
    if (path.contains('stdExamTable.action')) return academicEamsExamSnapshot;
    if (path.contains('publicSearch.action')) {
      return academicEamsCourseOfferingEntrySnapshot;
    }
    if (path.contains('freeClassroom.action')) {
      return academicEamsFreeClassroomEntrySnapshot;
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
      return academicEamsCourseOfferingResultSnapshot;
    }
    if (formUri.path.contains('freeClassroom!search.action')) {
      return academicEamsFreeClassroomResultSnapshot;
    }
    return AcademicEamsHttpSnapshot(
      finalUri: formUri,
      statusCode: 404,
      body: 'not found',
    );
  }
}

final AcademicLoginSessionSnapshot academicEamsSessionSnapshot =
    AcademicLoginSessionSnapshot(
      cookieHeadersByHost: const {
        'oa.sspu.edu.cn': 'OA=fake-oa-session',
        'id.sspu.edu.cn': 'CASTGC=fake-cas-session',
      },
      authenticatedAt: DateTime(2026, 5, 2),
      entranceUri: academicEamsOaEntranceUri,
      finalUri: academicEamsOaEntranceUri,
    );

final Uri academicEamsOaEntranceUri = Uri.parse(
  'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
);

final AcademicEamsHttpSnapshot academicEamsCasSnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse('https://id.sspu.edu.cn/cas/login'),
      statusCode: 200,
      body: '<html><title>统一身份认证</title></html>',
    );

final AcademicEamsHttpSnapshot academicEamsHomeSnapshot =
    AcademicEamsHttpSnapshot(
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

final AcademicEamsHttpSnapshot academicEamsEmptySubmenuSnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/home!submenus.action'),
      statusCode: 200,
      body: '<html><body></body></html>',
    );

final AcademicEamsHttpSnapshot academicEamsSubmenuSnapshot =
    AcademicEamsHttpSnapshot(
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

final AcademicEamsHttpSnapshot academicEamsCourseTableSnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse(
        'https://jx.sspu.edu.cn/eams/courseTableForStd.action',
      ),
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

final AcademicEamsHttpSnapshot academicEamsCurrentGradeSnapshot =
    AcademicEamsHttpSnapshot(
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

final AcademicEamsHttpSnapshot
academicEamsHistoryGradeSnapshot = AcademicEamsHttpSnapshot(
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

final AcademicEamsHttpSnapshot academicEamsProgramPlanSnapshot =
    AcademicEamsHttpSnapshot(
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

final AcademicEamsHttpSnapshot academicEamsExamSnapshot =
    AcademicEamsHttpSnapshot(
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

final AcademicEamsHttpSnapshot academicEamsCourseOfferingEntrySnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/publicSearch.action'),
      statusCode: 200,
      body: '''
<html>
  <body>
    <form action="publicSearch!search.action" method="get">
      <input type="hidden" name="pageNo" value="1" />
      <select name="semester">
        <option value="2025-2026-2">2025-2026-2</option>
        <option value="">全部学期</option>
      </select>
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

final AcademicEamsHttpSnapshot academicEamsCourseOfferingResultSnapshot =
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

final AcademicEamsHttpSnapshot academicEamsFreeClassroomEntrySnapshot =
    AcademicEamsHttpSnapshot(
      finalUri: Uri.parse('https://jx.sspu.edu.cn/eams/freeClassroom.action'),
      statusCode: 200,
      body: '''
<html>
  <body>
    <form action="freeClassroom!search.action" method="post">
      <select name="campus">
        <option value="JH">金海</option>
        <option value="">全部校区</option>
      </select>
      <input type="text" name="building" value="" />
      <input type="text" name="date" value="" />
      <input type="text" name="startUnit" value="1" />
      <input type="text" name="endUnit" value="2" />
    </form>
  </body>
</html>
''',
    );

final AcademicEamsHttpSnapshot academicEamsFreeClassroomResultSnapshot =
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
