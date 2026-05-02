/*
 * 本专科教务登录校验服务测试 — 校验 OA/CAS 只读登录状态分类
 * @Project : SSPU-all-in-one
 * @File : academic_login_validation_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/academic_login_validation.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/academic_login_validation_service.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';

const String _publicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1OWi0JWNagnRhJIpkPWZZbcXwvsLJ9pziJb00SwmjPDKeYTzlLsbU24WDPZlDSlH/E0FteYlkJnCgIAtS31SAy5LVGaecHYn4lsEo/ioT5vZpY7HrDQ/IIUUZa3YJuM26gZNdLcr0gm0+4yR3fix+aUyM3GML5bwjSm4EThrXJ2Fd9l+WlYvWJ4f4hyfFM245P7S7F56JCxjJeZDsFlvB+Ex/0xms/osbqCTrSoZd7jc7CbZhUbUzqn71e8oVhC6/eq+yV9pBgRiTMaAxcWTh7VRnhGCHNUs3HrAUfmPz72DMM+EQAwNbnh8qM9R7b1tW0KqYx0AKoEAFZ96xSpsNwIDAQAB
-----END PUBLIC KEY-----''';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('未保存 OA 账号时不访问校园网和登录页', () async {
    final gateway = _FakeAcademicLoginGateway();
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.missingOaAccount);
    expect(gateway.openCount, 0);
  });

  test('校园网或 VPN 不可达时停止登录校验', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicLoginGateway();
    final service = _buildService(gateway: gateway, campusReachable: false);

    final result = await service.validateSavedCredentials();

    expect(
      result.status,
      AcademicLoginValidationStatus.campusNetworkUnavailable,
    );
    expect(gateway.openCount, 0);
  });

  test('CAS 跳转到 OA 入口时返回登录校验通过', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicLoginGateway(
      loginPage: _casLoginSnapshot(),
      submitSnapshot: AcademicLoginHttpSnapshot(
        finalUri: _oaEntranceUri,
        statusCode: 200,
        body: '<html>OA</html>',
      ),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.success);
    expect(gateway.submittedFields?['username'], '20260001');
    expect(gateway.submittedFields?['execution'], 'execution-token');
    expect(gateway.submittedFields?['password'], startsWith('__RSA__'));

    final sessionSnapshot = await AcademicCredentialsService.instance
        .readOaLoginSession();
    final cookieHeader = await AcademicCredentialsService.instance
        .readOaCookieHeaderFor(_oaEntranceUri);
    expect(sessionSnapshot?.hasCookies, isTrue);
    expect(cookieHeader, contains('ecology_JSessionid='));
  });

  test('提交后仍停留 CAS 登录页时归类为凭据未通过', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicLoginGateway(
      loginPage: _casLoginSnapshot(),
      submitSnapshot: _casLoginSnapshot(),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.credentialsRejected);
  });

  test('CAS 未达到验证码阈值时保留凭据未通过状态', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicLoginGateway(
      loginPage: _casLoginSnapshot(),
      submitSnapshot: _casLoginSnapshot(failN: '1'),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.credentialsRejected);
  });

  test('凭据未通过时清除旧 OA 登录会话', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      AcademicLoginSessionSnapshot(
        cookieHeadersByHost: const {
          'oa.sspu.edu.cn': 'ecology_JSessionid=stale-session',
        },
        authenticatedAt: DateTime(2026, 4, 27),
        entranceUri: _oaEntranceUri,
        finalUri: _oaEntranceUri,
      ),
    );
    final gateway = _FakeAcademicLoginGateway(
      loginPage: _casLoginSnapshot(),
      submitSnapshot: _casLoginSnapshot(),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.credentialsRejected);
    expect(
      await AcademicCredentialsService.instance.readOaLoginSession(),
      isNull,
    );
  });

  test('登录成功但未获得 Cookie 时不保存不可复用会话', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicLoginGateway(sessionCookieHeadersByHost: {});
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.webFlowChanged);
    expect(
      await AcademicCredentialsService.instance.readOaLoginSession(),
      isNull,
    );
  });

  test('CAS 要求验证码时返回交互式验证码状态', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = _FakeAcademicLoginGateway(
      loginPage: _casLoginSnapshot(),
      submitSnapshot: _casLoginSnapshot(failN: '3'),
    );
    final service = _buildService(gateway: gateway, campusReachable: true);

    final result = await service.validateSavedCredentials();

    expect(result.status, AcademicLoginValidationStatus.captchaRequired);
  });
}

AcademicLoginValidationService _buildService({
  required _FakeAcademicLoginGateway gateway,
  required bool campusReachable,
}) {
  return AcademicLoginValidationService(
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

AcademicLoginHttpSnapshot _casLoginSnapshot({
  String failN = '-1',
  String mfaState = '',
}) {
  return AcademicLoginHttpSnapshot(
    finalUri: Uri.parse('https://id.sspu.edu.cn/cas/login'),
    statusCode: 200,
    body:
        '''
<html>
  <body>
    <form method="post" id="fm1" action="login">
      <input type="hidden" name="username" />
      <input type="hidden" name="password" />
      <input type="hidden" name="captcha" />
      <input type="hidden" name="rememberMe" />
      <input type="hidden" name="currentMenu" value="1" />
      <input type="hidden" name="failN" value="$failN" />
      <input type="hidden" name="mfaState" value="$mfaState" />
      <input type="hidden" name="execution" value="execution-token" />
      <input type="hidden" name="_eventId" value="submit" />
    </form>
  </body>
</html>
''',
  );
}

class _FakeAcademicLoginGateway implements AcademicLoginGateway {
  _FakeAcademicLoginGateway({
    AcademicLoginHttpSnapshot? loginPage,
    AcademicLoginHttpSnapshot? submitSnapshot,
    Map<String, String>? sessionCookieHeadersByHost,
  }) : loginPage = loginPage ?? _casLoginSnapshot(),
       submitSnapshot =
           submitSnapshot ??
           AcademicLoginHttpSnapshot(
             finalUri: _oaEntranceUri,
             statusCode: 200,
             body: '<html>OA</html>',
           ),
       sessionCookieHeadersByHost =
           sessionCookieHeadersByHost ??
           const {
             'oa.sspu.edu.cn': 'ecology_JSessionid=fake-oa-session',
             'id.sspu.edu.cn': 'CASTGC=fake-cas-ticket',
           };

  final AcademicLoginHttpSnapshot loginPage;
  final AcademicLoginHttpSnapshot submitSnapshot;
  final Map<String, String> sessionCookieHeadersByHost;
  int openCount = 0;
  Map<String, String>? submittedFields;

  @override
  Future<void> resetSession() async {}

  @override
  Future<AcademicLoginHttpSnapshot> openLoginPage(
    Uri entranceUri,
    Duration timeout,
  ) async {
    openCount++;
    return loginPage;
  }

  @override
  Future<String> fetchPublicKey(Duration timeout) async => _publicKeyPem;

  @override
  Future<AcademicLoginHttpSnapshot> submitLogin({
    required Uri loginUri,
    required Map<String, String> fields,
    required Duration timeout,
  }) async {
    submittedFields = fields;
    return submitSnapshot;
  }

  @override
  AcademicLoginSessionSnapshot currentSessionSnapshot({
    required Uri entranceUri,
    required Uri finalUri,
  }) {
    return AcademicLoginSessionSnapshot(
      cookieHeadersByHost: sessionCookieHeadersByHost,
      authenticatedAt: DateTime(2026, 4, 27),
      entranceUri: entranceUri,
      finalUri: finalUri,
    );
  }
}

final Uri _oaEntranceUri = Uri.parse(
  'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
);
