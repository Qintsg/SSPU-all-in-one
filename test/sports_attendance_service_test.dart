/*
 * 体育部课外活动考勤服务测试 — 校验独立登录、状态分类与考勤解析
 * @Project : SSPU-all-in-one
 * @File : sports_attendance_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/academic_credentials.dart';
import 'package:sspu_all_in_one/models/sports_attendance.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';
import 'package:sspu_all_in_one/services/sports_attendance_service.dart';
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

  test('体育查询自动刷新设置默认关闭并可持久化间隔', () async {
    final service = _buildService(
      gateway: _FakeSportsAttendanceGateway(),
      campusReachable: true,
    );

    expect(await service.isAutoRefreshEnabled(), isFalse);
    expect(
      await service.getAutoRefreshIntervalMinutes(),
      SportsAttendanceService.defaultAutoRefreshIntervalMinutes,
    );

    await service.setAutoRefreshEnabled(true);
    await service.setAutoRefreshIntervalMinutes(60);

    expect(await service.isAutoRefreshEnabled(), isTrue);
    expect(await service.getAutoRefreshIntervalMinutes(), 60);
  });

  test('未保存学工号时不访问体育部登录页', () async {
    final gateway = _FakeSportsAttendanceGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchAttendanceSummary();

    expect(result.status, SportsAttendanceQueryStatus.missingStudentId);
    expect(gateway.openCount, 0);
  });

  test('未保存体育部查询密码时不复用 OA 密码', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeSportsAttendanceGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchAttendanceSummary();

    expect(result.status, SportsAttendanceQueryStatus.missingSportsPassword);
    expect(
      await AcademicCredentialsService.instance.readSecret(
        AcademicCredentialSecret.sportsQueryPassword,
      ),
      isNull,
    );
    expect(gateway.openCount, 0);
  });

  test('校园网或 VPN 不可达时停止体育部登录', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      sportsQueryPassword: 'sports-pass',
    );
    final gateway = _FakeSportsAttendanceGateway();
    final service = _buildService(gateway: gateway, campusReachable: false);

    final result = await service.fetchAttendanceSummary();

    expect(result.status, SportsAttendanceQueryStatus.campusNetworkUnavailable);
    expect(gateway.openCount, 0);
  });

  test('体育部登录成功后解析四类考勤总次数和明细', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      sportsQueryPassword: 'sports-pass',
    );
    final gateway = _FakeSportsAttendanceGateway(
      scorePage: _scoreSnapshot(_scorePageHtml),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchAttendanceSummary();

    expect(result.status, SportsAttendanceQueryStatus.success);
    expect(gateway.submittedFields?['dlljs'], 'st');
    expect(gateway.submittedFields?['txtuser'], '20260001');
    expect(gateway.submittedFields?['txtpwd'], 'sports-pass');
    expect(gateway.submittedFields?['txtpwd'], isNot('oa-pass'));
    expect(result.summary?.morningExerciseCount, 2);
    expect(result.summary?.extracurricularActivityCount, 3);
    expect(result.summary?.countAdjustmentCount, -1);
    expect(result.summary?.sportsCorridorCount, 4);
    expect(result.summary?.totalCount, 8);
    expect(result.summary?.records.length, 5);
  });

  test('体育部登录失败时返回凭据未通过', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      sportsQueryPassword: 'bad-pass',
    );
    final gateway = _FakeSportsAttendanceGateway(
      submitPage: _loginSnapshot('''
<html>
  <body>
    <form action="default.aspx" method="post">
      <input type="hidden" name="__VIEWSTATE" value="state" />
      <input type="text" name="txtuser" />
      <input type="password" name="txtpwd" />
    </form>
    <script>alert('学生或密码错误!');</script>
  </body>
</html>
'''),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchAttendanceSummary();

    expect(result.status, SportsAttendanceQueryStatus.credentialsRejected);
  });

  test('登录后无法访问明细页时返回会话不可用', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      sportsQueryPassword: 'sports-pass',
    );
    final gateway = _FakeSportsAttendanceGateway(
      scorePage: SportsAttendanceHttpSnapshot(
        finalUri: Uri.parse('https://tygl.sspu.edu.cn/SportScore/errpage.aspx'),
        statusCode: 200,
        body: '<html><title>错误页面</title></html>',
      ),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchAttendanceSummary();

    expect(result.status, SportsAttendanceQueryStatus.sessionUnavailable);
  });
}

SportsAttendanceService _buildService({
  required _FakeSportsAttendanceGateway gateway,
  required bool campusReachable,
}) {
  return SportsAttendanceService(
    gateway: gateway,
    campusNetworkStatusService: CampusNetworkStatusService(
      probeUri: Uri.parse('https://tygl.sspu.edu.cn/'),
      probe: (probeUri, timeout) async => CampusNetworkProbeResult(
        reachable: campusReachable,
        detail: campusReachable ? '校园网可达' : '校园网不可达',
        statusCode: campusReachable ? 200 : null,
      ),
    ),
  );
}

SportsAttendanceHttpSnapshot _loginSnapshot(String body) {
  return SportsAttendanceHttpSnapshot(
    finalUri: Uri.parse('https://tygl.sspu.edu.cn/sportscore/default.aspx'),
    statusCode: 200,
    body: body,
  );
}

SportsAttendanceHttpSnapshot _scoreSnapshot(String body) {
  return SportsAttendanceHttpSnapshot(
    finalUri: Uri.parse(
      'https://tygl.sspu.edu.cn/sportscore/stScore.aspx?item=1',
    ),
    statusCode: 200,
    body: body,
  );
}

class _FakeSportsAttendanceGateway implements SportsAttendanceGateway {
  _FakeSportsAttendanceGateway({
    SportsAttendanceHttpSnapshot? loginPage,
    SportsAttendanceHttpSnapshot? submitPage,
    SportsAttendanceHttpSnapshot? scorePage,
  }) : loginPage =
           loginPage ??
           _loginSnapshot('''
<html>
  <body>
    <form action="default.aspx" method="post">
      <input type="hidden" name="__VIEWSTATE" value="state" />
      <input type="hidden" name="__EVENTVALIDATION" value="validation" />
      <select name="dlljs"><option value="st">学生</option></select>
      <input type="text" name="txtuser" />
      <input type="password" name="txtpwd" />
      <input type="image" name="btnok" />
    </form>
  </body>
</html>
'''),
       submitPage =
           submitPage ?? _loginSnapshot('<html><body>登录成功</body></html>'),
       scorePage = scorePage ?? _scoreSnapshot(_scorePageHtml);

  final SportsAttendanceHttpSnapshot loginPage;
  final SportsAttendanceHttpSnapshot submitPage;
  final SportsAttendanceHttpSnapshot scorePage;
  int openCount = 0;
  Map<String, String>? submittedFields;

  @override
  Future<void> resetSession() async {}

  @override
  Future<SportsAttendanceHttpSnapshot> openLoginPage(
    Uri entranceUri,
    Duration timeout,
  ) async {
    openCount++;
    return loginPage;
  }

  @override
  Future<SportsAttendanceHttpSnapshot> submitLogin({
    required Uri loginUri,
    required Map<String, String> fields,
    required Duration timeout,
  }) async {
    submittedFields = fields;
    return submitPage;
  }

  @override
  Future<SportsAttendanceHttpSnapshot> fetchScorePage(
    Uri scoreUri,
    Duration timeout,
  ) async {
    return scorePage;
  }
}

const String _scorePageHtml = '''
<html>
  <body>
    <table id="score">
      <tr><th>日期</th><th>类型</th><th>项目</th><th>地点</th><th>次数</th></tr>
      <tr><td>2026-04-01 06:50</td><td>早操</td><td>晨跑</td><td>操场</td><td>1次</td></tr>
      <tr><td>2026-04-02 06:50</td><td>早操</td><td>晨跑</td><td>操场</td><td>1次</td></tr>
      <tr><td>2026-04-03 16:20</td><td>课外活动</td><td>篮球</td><td>体育馆</td><td>3次</td></tr>
      <tr><td>2026-04-04</td><td>次数调整</td><td>补录</td><td>体育办公室</td><td>-1</td></tr>
      <tr><td>2026-04-05</td><td>体育长廊</td><td>长廊学习</td><td>体育长廊</td><td>4次</td></tr>
    </table>
  </body>
</html>
''';
