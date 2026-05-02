/*
 * 校园卡查询服务测试 — 校验 OA 会话、自动刷新设置与余额明细解析
 * @Project : SSPU-all-in-one
 * @File : campus_card_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/academic_login_validation.dart';
import 'package:sspu_all_in_one/models/campus_card.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/campus_card_service.dart';
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

  test('校园卡自动刷新设置默认关闭并可持久化间隔', () async {
    final service = _buildService(
      gateway: _FakeCampusCardGateway(),
      campusReachable: true,
    );

    expect(await service.isAutoRefreshEnabled(), isFalse);
    expect(
      await service.getAutoRefreshIntervalMinutes(),
      CampusCardService.defaultAutoRefreshIntervalMinutes,
    );

    await service.setAutoRefreshEnabled(true);
    await service.setAutoRefreshIntervalMinutes(60);

    expect(await service.isAutoRefreshEnabled(), isTrue);
    expect(await service.getAutoRefreshIntervalMinutes(), 60);
  });

  test('未保存学工号时不访问校园卡入口', () async {
    final gateway = _FakeCampusCardGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchCampusCard();

    expect(result.status, CampusCardQueryStatus.missingOaAccount);
    expect(gateway.openCount, 0);
  });

  test('校园网或 VPN 不可达时停止校园卡查询', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeCampusCardGateway();
    final service = _buildService(gateway: gateway, campusReachable: false);

    final result = await service.fetchCampusCard();

    expect(result.status, CampusCardQueryStatus.campusNetworkUnavailable);
    expect(gateway.openCount, 0);
  });

  test('OA 会话失效时刷新登录态后解析余额状态和记录', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    var refreshCount = 0;
    final gateway = _FakeCampusCardGateway(requireAuthFirst: true);
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
          checkedAt: DateTime(2026, 4, 30),
          entranceUri: _oaEntranceUri,
          finalUri: _oaEntranceUri,
          sessionSnapshot: _sessionSnapshot,
        );
      },
    );

    final result = await service.fetchCampusCard();

    expect(result.status, CampusCardQueryStatus.success);
    expect(refreshCount, 1);
    expect(gateway.openCount, 2);
    expect(gateway.resetCookieHeaders.last['oa.sspu.edu.cn'], contains('OA='));
    expect(result.snapshot?.balance, 23.45);
    expect(result.snapshot?.status, '正常');
    expect(result.snapshot?.records.length, 1);
    expect(result.snapshot?.records.single.merchant, '一食堂');
  });

  test('交易记录查询会携带日期范围和 CSRF 并解析 XML 表格', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      _sessionSnapshot,
    );
    final gateway = _FakeCampusCardGateway(
      queryPage: CampusCardHttpSnapshot(
        finalUri: CampusCardService.defaultTransactionQueryUri,
        statusCode: 200,
        body: '''
<ajax-response><![CDATA[
<table>
  <tr><td>2026-04-28 08:12</td><td>充值</td><td>线上充值</td><td>+50.00</td><td>73.45</td></tr>
</table>
]]></ajax-response>
''',
      ),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.fetchCampusCard(
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 30),
    );

    expect(result.status, CampusCardQueryStatus.success);
    expect(gateway.submittedFields?['starttime'], '2026-04-01');
    expect(gateway.submittedFields?['endtime'], '2026-04-30');
    expect(gateway.submittedFields?['_csrf'], 'csrf-token');
    expect(result.snapshot?.records.length, 2);
    expect(result.snapshot?.records.last.type, '充值');
    expect(result.snapshot?.records.last.amount, 50.00);
  });
}

CampusCardService _buildService({
  required _FakeCampusCardGateway gateway,
  required bool campusReachable,
  CampusCardOaLoginRefresher? refreshOaLogin,
}) {
  return CampusCardService(
    gateway: gateway,
    refreshOaLogin: refreshOaLogin,
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

class _FakeCampusCardGateway implements CampusCardGateway {
  _FakeCampusCardGateway({
    this.requireAuthFirst = false,
    CampusCardHttpSnapshot? entryPage,
    CampusCardHttpSnapshot? homePage,
    CampusCardHttpSnapshot? transactionPage,
    CampusCardHttpSnapshot? queryPage,
  }) : entryPage = entryPage ?? _cardSnapshot(_balanceHtml),
       homePage = homePage ?? _cardSnapshot(_balanceHtml),
       transactionPage =
           transactionPage ??
           CampusCardHttpSnapshot(
             finalUri: CampusCardService.defaultTransactionIndexUri,
             statusCode: 200,
             body: _transactionHtml,
           ),
       queryPage = queryPage ?? _cardSnapshot(_transactionHtml);

  final bool requireAuthFirst;
  final CampusCardHttpSnapshot entryPage;
  final CampusCardHttpSnapshot homePage;
  final CampusCardHttpSnapshot transactionPage;
  final CampusCardHttpSnapshot queryPage;
  final List<Map<String, String>> resetCookieHeaders = [];
  int openCount = 0;
  Map<String, String>? submittedFields;

  @override
  Future<void> resetSession(Map<String, String> cookieHeadersByHost) async {
    resetCookieHeaders.add(cookieHeadersByHost);
  }

  @override
  Future<CampusCardHttpSnapshot> openEntryPage(
    Uri entranceUri,
    Duration timeout,
  ) async {
    openCount++;
    if (requireAuthFirst && openCount == 1) return _casSnapshot;
    return entryPage;
  }

  @override
  Future<CampusCardHttpSnapshot> fetchPage(
    Uri pageUri,
    Duration timeout,
  ) async {
    if (pageUri.path.contains('/myepay/')) return homePage;
    if (pageUri.path.contains('/consume/')) return transactionPage;
    return CampusCardHttpSnapshot(
      finalUri: pageUri,
      statusCode: 404,
      body: 'not found',
    );
  }

  @override
  Future<CampusCardHttpSnapshot> queryTransactions({
    required Uri queryUri,
    required Map<String, String> fields,
    required Duration timeout,
  }) async {
    submittedFields = fields;
    return queryPage;
  }
}

CampusCardHttpSnapshot _cardSnapshot(String body) {
  return CampusCardHttpSnapshot(
    finalUri: Uri.parse('https://card.sspu.edu.cn/epay/'),
    statusCode: 200,
    body: body,
  );
}

final CampusCardHttpSnapshot _casSnapshot = CampusCardHttpSnapshot(
  finalUri: Uri.parse('https://id.sspu.edu.cn/cas/login'),
  statusCode: 200,
  body: '<html><title>登录 - 上海第二工业大学</title></html>',
);

final AcademicLoginSessionSnapshot _sessionSnapshot =
    AcademicLoginSessionSnapshot(
      cookieHeadersByHost: const {
        'oa.sspu.edu.cn': 'OA=fake-oa-session',
        'id.sspu.edu.cn': 'CASTGC=fake-cas-session',
      },
      authenticatedAt: DateTime(2026, 4, 30),
      entranceUri: _oaEntranceUri,
      finalUri: _oaEntranceUri,
    );

final Uri _oaEntranceUri = Uri.parse(
  'https://oa.sspu.edu.cn//interface/Entrance.jsp?id=xykxt',
);

const String _balanceHtml = '''
<html>
  <body>
    <table>
      <tr><td>账户余额</td><td>23.45 元</td></tr>
      <tr><td>卡状态</td><td>正常</td></tr>
    </table>
  </body>
</html>
''';

const String _transactionHtml = '''
<html>
  <head><meta name="_csrf" content="csrf-token" /></head>
  <body>
    <table>
      <tr><th>时间</th><th>类型</th><th>商户</th><th>金额</th><th>余额</th></tr>
      <tr><td>2026-04-29 12:10</td><td>消费</td><td>一食堂</td><td>-12.50</td><td>23.45</td></tr>
    </table>
  </body>
</html>
''';
