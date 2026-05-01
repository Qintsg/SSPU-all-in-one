/*
 * 学工报表服务测试 — 校验 OA 会话、校园网前置检测与第二课堂学分解析
 * @Project : SSPU-all-in-one
 * @File : student_report_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/academic_login_validation.dart';
import 'package:sspu_all_in_one/models/student_report.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';
import 'package:sspu_all_in_one/services/student_report_service.dart';

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

  test('第二课堂学分自动刷新设置默认关闭并可持久化间隔', () async {
    final service = _buildService(
      gateway: _FakeStudentReportGateway(),
      campusReachable: true,
    );

    expect(await service.isAutoRefreshEnabled(), isFalse);
    expect(
      await service.getAutoRefreshIntervalMinutes(),
      StudentReportService.defaultAutoRefreshIntervalMinutes,
    );

    await service.setAutoRefreshEnabled(true);
    await service.setAutoRefreshIntervalMinutes(60);

    expect(await service.isAutoRefreshEnabled(), isTrue);
    expect(await service.getAutoRefreshIntervalMinutes(), 60);
  });

  test('未保存学工号时不访问学工报表入口', () async {
    final gateway = _FakeStudentReportGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchSecondClassroomCredits();

    expect(result.status, StudentReportQueryStatus.missingOaAccount);
    expect(gateway.openCount, 0);
  });

  test('校园网或 VPN 不可达时停止学工报表查询', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeStudentReportGateway();
    final service = _buildService(gateway: gateway, campusReachable: false);

    final result = await service.fetchSecondClassroomCredits();

    expect(result.status, StudentReportQueryStatus.campusNetworkUnavailable);
    expect(gateway.openCount, 0);
  });

  test('OA 会话失效时刷新登录态后解析第二课堂学分', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    var refreshCount = 0;
    final gateway = _FakeStudentReportGateway(requireAuthFirst: true);
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
          checkedAt: DateTime(2026, 5, 1),
          entranceUri: _oaEntranceUri,
          finalUri: _oaEntranceUri,
          sessionSnapshot: _sessionSnapshot,
        );
      },
    );

    final result = await service.fetchSecondClassroomCredits();

    expect(result.status, StudentReportQueryStatus.success);
    expect(refreshCount, 1);
    expect(gateway.openCount, 2);
    expect(gateway.resetCookieHeaders.last['oa.sspu.edu.cn'], contains('OA='));
    expect(result.summary?.records.first.credit, 1.5);
    expect(result.summary?.records.first.category, '思想成长');
    expect(result.summary?.records.last.itemName, '创新训练项目');
  });

  test('登录状态校验不读取第二课堂学分明细页', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeStudentReportGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateLoginStatus();

    expect(result.status, StudentReportQueryStatus.success);
    expect(result.summary, isNull);
    expect(gateway.fetchCount, 0);
  });

  test('OA 门户页包含学工报表 SSO 链接时先换取业务会话', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeStudentReportGateway(entryPage: _oaPortalSnapshot);
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateLoginStatus();

    expect(result.status, StudentReportQueryStatus.success);
    expect(gateway.fetchedUris, hasLength(1));
    expect(gateway.fetchedUris.single.path, '/sharedc/sso/fore-login.do');
  });

  test('学工报表 SSO 链路超时时返回网络错误状态', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeStudentReportGateway(
      entryPage: _oaPortalSnapshot,
      timeoutReportEntry: true,
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateLoginStatus();

    expect(result.status, StudentReportQueryStatus.networkError);
    expect(result.message, '学工报表查询超时');
  });

  test('有效首页包含前端错误脚本时不误判为系统不可用', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeStudentReportGateway(entryPage: _clientErrorHome);
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateLoginStatus();

    expect(result.status, StudentReportQueryStatus.success);
  });

  test('从第二学堂学分查询菜单 onclick 定位明细页', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeStudentReportGateway(entryPage: _onclickHome);
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchSecondClassroomCredits();

    expect(result.status, StudentReportQueryStatus.success);
    expect(
      gateway.fetchedUris.single.path,
      '/sharedc/dc/studentxfform/index.do',
    );
    expect(result.summary?.records, hasLength(2));
  });
}

StudentReportService _buildService({
  required _FakeStudentReportGateway gateway,
  required bool campusReachable,
  StudentReportOaLoginRefresher? refreshOaLogin,
}) {
  return StudentReportService(
    gateway: gateway,
    refreshOaLogin: refreshOaLogin,
    campusNetworkStatusService: CampusNetworkStatusService(
      probeUri: Uri.parse('https://xgbb.sspu.edu.cn/'),
      probe: (probeUri, timeout) async => CampusNetworkProbeResult(
        reachable: campusReachable,
        detail: campusReachable ? '校园网可达' : '校园网不可达',
        statusCode: campusReachable ? 200 : null,
      ),
    ),
  );
}

class _FakeStudentReportGateway implements StudentReportGateway {
  _FakeStudentReportGateway({
    this.requireAuthFirst = false,
    StudentReportHttpSnapshot? entryPage,
    StudentReportHttpSnapshot? creditPage,
    StudentReportHttpSnapshot? reportEntryPage,
    this.timeoutReportEntry = false,
  }) : entryPage = entryPage ?? _snapshot(_homeHtml),
       creditPage = creditPage ?? _snapshot(_creditHtml),
       reportEntryPage = reportEntryPage ?? _snapshot(_homeHtml);

  final bool requireAuthFirst;
  final bool timeoutReportEntry;
  final StudentReportHttpSnapshot entryPage;
  final StudentReportHttpSnapshot creditPage;
  final StudentReportHttpSnapshot reportEntryPage;
  final List<Map<String, String>> resetCookieHeaders = [];
  final List<Uri> fetchedUris = [];
  int openCount = 0;
  int fetchCount = 0;

  @override
  Future<void> resetSession(Map<String, String> cookieHeadersByHost) async {
    resetCookieHeaders.add(cookieHeadersByHost);
  }

  @override
  Future<StudentReportHttpSnapshot> openEntryPage(
    Uri entranceUri,
    Duration timeout,
  ) async {
    openCount++;
    if (requireAuthFirst && openCount == 1) return _casSnapshot;
    return entryPage;
  }

  @override
  Future<StudentReportHttpSnapshot> fetchPage(
    Uri pageUri,
    Duration timeout,
  ) async {
    fetchCount++;
    fetchedUris.add(pageUri);
    if (pageUri.path.contains('/sharedc/sso/')) {
      if (timeoutReportEntry) throw TimeoutException('SSO timeout');
      return reportEntryPage;
    }
    if (pageUri.path.contains('/studentxfform/')) return creditPage;
    if (pageUri.path.contains('secondClassroom')) return creditPage;
    return StudentReportHttpSnapshot(
      finalUri: pageUri,
      statusCode: 404,
      body: 'not found',
    );
  }
}

StudentReportHttpSnapshot _snapshot(String body) {
  return StudentReportHttpSnapshot(
    finalUri: Uri.parse('https://xgbb.sspu.edu.cn/sharedc/core/home/index.do'),
    statusCode: 200,
    body: body,
  );
}

final StudentReportHttpSnapshot _casSnapshot = StudentReportHttpSnapshot(
  finalUri: Uri.parse('https://id.sspu.edu.cn/cas/login'),
  statusCode: 200,
  body: '<html><title>登录 - 上海第二工业大学</title></html>',
);

final StudentReportHttpSnapshot _oaPortalSnapshot = StudentReportHttpSnapshot(
  finalUri: Uri.parse('https://oa.sspu.edu.cn/interface/Entrance.jsp'),
  statusCode: 200,
  body: '''
<html>
  <body>
    <a href="https://xgbb.sspu.edu.cn/sharedc/sso/fore-login.do">学工报表</a>
  </body>
</html>
''',
);

final AcademicLoginSessionSnapshot _sessionSnapshot =
    AcademicLoginSessionSnapshot(
      cookieHeadersByHost: const {
        'oa.sspu.edu.cn': 'OA=fake-oa-session',
        'id.sspu.edu.cn': 'CASTGC=fake-cas-session',
      },
      authenticatedAt: DateTime(2026, 5, 1),
      entranceUri: _oaEntranceUri,
      finalUri: _oaEntranceUri,
    );

final Uri _oaEntranceUri = Uri.parse(
  'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=xgreport',
);

const String _homeHtml = '''
<html>
  <body>
    <a href="/sharedc/core/home/secondClassroom.do">第二课堂学分查询</a>
  </body>
</html>
''';

const String _creditHtml = '''
<html>
  <body>
    <table>
      <tr><th>类别</th><th>项目名称</th><th>认定时间</th><th>状态</th><th>学分</th></tr>
      <tr><td>思想成长</td><td>主题团日</td><td>2026-04-20</td><td>已认定</td><td>1.5</td></tr>
      <tr><td>创新创业</td><td>创新训练项目</td><td>2026-04-25</td><td>通过</td><td>2</td></tr>
    </table>
  </body>
</html>
''';

final StudentReportHttpSnapshot _clientErrorHome = _snapshot('''
<html>
  <head><title>学工报表</title></head>
  <body>
    <script>console.error('client fallback');</script>
    <a href="/sharedc/core/home/secondClassroom.do">第二课堂学分查询</a>
  </body>
</html>
''');

final StudentReportHttpSnapshot _onclickHome = _snapshot('''
<html>
  <body>
    <nav>第二课堂</nav>
    <a href="javascript:void(0)" onclick="toMainUrl('dc/studentxfform/index.do','',true)">
      <span>第二学堂学分查询</span>
    </a>
  </body>
</html>
''');
