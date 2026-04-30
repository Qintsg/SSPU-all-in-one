/*
 * 本专科教务系统登录校验服务 — 通过 OA/CAS 只读登录流程验证凭据可用性
 * @Project : SSPU-all-in-one
 * @File : academic_login_validation_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../models/academic_credentials.dart';
import '../models/academic_login_validation.dart';
import '../models/campus_network_status.dart';
import 'academic_credentials_service.dart';
import 'campus_network_status_service.dart';
import 'http_service.dart';

/// OA 登录 HTTP 响应快照。
class AcademicLoginHttpSnapshot {
  const AcademicLoginHttpSnapshot({
    required this.finalUri,
    required this.statusCode,
    required this.body,
  });

  /// 请求完成后的最终地址。
  final Uri finalUri;

  /// HTTP 状态码。
  final int? statusCode;

  /// 响应正文。
  final String body;
}

/// 可替换的 OA 登录网关，测试中用 fake 避免访问真实校园系统。
abstract class AcademicLoginGateway {
  /// 重置 Cookie 会话，确保每次校验互不污染。
  Future<void> resetSession();

  /// 打开本专科教务入口并跟随跳转到 CAS 登录页。
  Future<AcademicLoginHttpSnapshot> openLoginPage(
    Uri entranceUri,
    Duration timeout,
  );

  /// 获取 CAS 登录页使用的 RSA 公钥。
  Future<String> fetchPublicKey(Duration timeout);

  /// 提交一次账号密码登录校验。
  Future<AcademicLoginHttpSnapshot> submitLogin({
    required Uri loginUri,
    required Map<String, String> fields,
    required Duration timeout,
  });

  /// 读取当前登录链路累计的 Cookie 会话快照。
  AcademicLoginSessionSnapshot currentSessionSnapshot({
    required Uri entranceUri,
    required Uri finalUri,
  });
}

/// 本专科教务系统 OA 登录只读校验服务。
class AcademicLoginValidationService {
  AcademicLoginValidationService({
    AcademicCredentialsService? credentialsService,
    CampusNetworkStatusService? campusNetworkStatusService,
    AcademicLoginGateway? gateway,
    Uri? entranceUri,
    Duration? timeout,
  }) : _credentialsService =
           credentialsService ?? AcademicCredentialsService.instance,
       _campusNetworkStatusService =
           campusNetworkStatusService ?? CampusNetworkStatusService.instance,
       _gateway = gateway ?? DioAcademicLoginGateway(),
       entranceUri = entranceUri ?? defaultEntranceUri,
       timeout = timeout ?? const Duration(seconds: 15);

  /// 全局单例。
  static final AcademicLoginValidationService instance =
      AcademicLoginValidationService();

  /// 本专科教务系统 OA 入口。
  static final Uri defaultEntranceUri = Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
  );

  final AcademicCredentialsService _credentialsService;
  final CampusNetworkStatusService _campusNetworkStatusService;
  final AcademicLoginGateway _gateway;

  /// 校验入口地址。
  final Uri entranceUri;

  /// 单次网络步骤超时时间。
  final Duration timeout;

  /// 使用本地已保存 OA 账号密码执行只读登录校验。
  Future<AcademicLoginValidationResult> validateSavedCredentials() async {
    CampusNetworkStatus? campusStatus;
    try {
      final credentialsStatus = await _credentialsService.getStatus();
      final oaAccount = credentialsStatus.oaAccount.trim();
      if (oaAccount.isEmpty) {
        return _buildResult(
          AcademicLoginValidationStatus.missingOaAccount,
          message: '请先保存学工号（OA账号）',
          detail: '本地安全存储中没有 OA 账号。',
        );
      }

      final oaPassword = await _credentialsService.readSecret(
        AcademicCredentialSecret.oaPassword,
      );
      if (oaPassword == null || oaPassword.isEmpty) {
        return _buildResult(
          AcademicLoginValidationStatus.missingOaPassword,
          message: '请先保存 OA 账号密码',
          detail: '本地安全存储中没有 OA 密码。',
        );
      }

      campusStatus = await _campusNetworkStatusService.checkStatus();
      if (!campusStatus.canAccessRestrictedServices) {
        return _buildResult(
          AcademicLoginValidationStatus.campusNetworkUnavailable,
          message: '校园网 / VPN 不可用，无法验证 OA 登录',
          detail: campusStatus.detail,
          campusNetworkStatus: campusStatus,
        );
      }

      final validationResult = await _validateCredentials(
        oaAccount: oaAccount,
        oaPassword: oaPassword,
        campusNetworkStatus: campusStatus,
      );
      if (validationResult.isSuccess &&
          validationResult.sessionSnapshot != null) {
        await _credentialsService.saveOaLoginSession(
          validationResult.sessionSnapshot!,
        );
      } else if (validationResult.status ==
          AcademicLoginValidationStatus.credentialsRejected) {
        await _credentialsService.clearOaLoginSession();
      }
      return validationResult;
    } on TimeoutException {
      return _buildResult(
        AcademicLoginValidationStatus.networkError,
        message: 'OA 登录校验超时',
        detail: '访问 OA / CAS 登录链路超时。',
        campusNetworkStatus: campusStatus,
      );
    } on DioException catch (error) {
      return _buildResult(
        AcademicLoginValidationStatus.networkError,
        message: 'OA 登录校验网络失败',
        detail: HttpService.describeError(error),
        finalUri: error.requestOptions.uri,
        campusNetworkStatus: campusStatus,
      );
    } catch (error) {
      return _buildResult(
        AcademicLoginValidationStatus.unexpectedError,
        message: 'OA 登录校验失败',
        detail: '未归类异常：$error',
        campusNetworkStatus: campusStatus,
      );
    }
  }

  Future<AcademicLoginValidationResult> _validateCredentials({
    required String oaAccount,
    required String oaPassword,
    required CampusNetworkStatus campusNetworkStatus,
  }) async {
    await _gateway.resetSession();
    final loginPage = await _gateway.openLoginPage(entranceUri, timeout);
    if (_hasReachedOa(loginPage)) {
      return _buildSuccessResult(
        message: 'OA 登录校验通过',
        detail: '入口已直接进入 OA 页面，当前会话已具备登录状态并保存了 Cookie。',
        successUri: loginPage.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final loginForm = _parseCasLoginForm(loginPage);
    if (loginForm == null) {
      return _buildResult(
        AcademicLoginValidationStatus.loginPageUnavailable,
        message: '无法识别 OA/CAS 登录页',
        detail: 'CAS 登录页缺少账号密码登录表单或 execution 字段。',
        finalUri: loginPage.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final publicKey = await _gateway.fetchPublicKey(timeout);
    final encryptedPassword = _RsaPkcs1Encryptor.encryptToBase64(
      oaPassword,
      publicKey,
    );
    final submitSnapshot = await _gateway.submitLogin(
      loginUri: loginForm.actionUri,
      fields: loginForm.toFields(
        oaAccount: oaAccount,
        encryptedPassword: encryptedPassword,
      ),
      timeout: timeout,
    );
    return _classifySubmitSnapshot(
      submitSnapshot,
      campusNetworkStatus: campusNetworkStatus,
    );
  }

  AcademicLoginValidationResult _classifySubmitSnapshot(
    AcademicLoginHttpSnapshot snapshot, {
    required CampusNetworkStatus campusNetworkStatus,
  }) {
    if (_hasReachedOa(snapshot)) {
      return _buildSuccessResult(
        message: 'OA 登录校验通过',
        detail: 'CAS 已跳转到 OA / 本专科教务入口，并保存了后续网页可复用的 Cookie。',
        successUri: snapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final loginForm = _parseCasLoginForm(snapshot);
    if (loginForm != null && loginForm.requiresAdditionalVerification) {
      return _buildResult(
        AcademicLoginValidationStatus.additionalVerificationRequired,
        message: 'OA 登录需要额外安全验证',
        detail: 'CAS 返回 MFA / 安全验证状态，当前只读校验不处理交互式验证。',
        finalUri: snapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (loginForm != null && loginForm.requiresCaptcha) {
      return _buildResult(
        AcademicLoginValidationStatus.captchaRequired,
        message: 'OA 登录需要图形验证码',
        detail: 'CAS 返回验证码状态，当前只读校验不处理交互式验证码。',
        finalUri: snapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (_isCasLoginPage(snapshot)) {
      return _buildResult(
        AcademicLoginValidationStatus.credentialsRejected,
        message: 'OA 账号或密码未通过校验',
        detail: '提交登录表单后仍停留在 CAS 登录页。',
        finalUri: snapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    return _buildResult(
      AcademicLoginValidationStatus.webFlowChanged,
      message: 'OA 登录跳转流程异常',
      detail: '最终地址不属于 CAS 登录页或 OA 入口，可能是网页流程发生变化。',
      finalUri: snapshot.finalUri,
      campusNetworkStatus: campusNetworkStatus,
    );
  }

  _CasLoginForm? _parseCasLoginForm(AcademicLoginHttpSnapshot snapshot) {
    final document = html_parser.parse(snapshot.body);
    for (final form in document.querySelectorAll('form')) {
      final currentMenu = _inputValue(form, 'currentMenu');
      final eventId = _inputValue(form, '_eventId');
      if (currentMenu != '1' || eventId != 'submit') continue;

      final execution = _inputValue(form, 'execution');
      final hasPasswordInput =
          form.querySelector('input[name="password"]') != null;
      if (execution.isEmpty || !hasPasswordInput) {
        return null;
      }

      final action = form.attributes['action']?.trim();
      return _CasLoginForm(
        actionUri: snapshot.finalUri.resolve(
          action == null || action.isEmpty ? snapshot.finalUri.path : action,
        ),
        execution: execution,
        failN: _inputValue(form, 'failN'),
        mfaState: _inputValue(form, 'mfaState'),
      );
    }
    return null;
  }

  String _inputValue(html_dom.Element form, String name) {
    final element = form.querySelector('input[name="$name"]');
    return element?.attributes['value']?.trim() ?? '';
  }

  bool _hasReachedOa(AcademicLoginHttpSnapshot snapshot) {
    return snapshot.finalUri.host == 'oa.sspu.edu.cn' &&
        !_isCasLoginPage(snapshot);
  }

  bool _isCasLoginPage(AcademicLoginHttpSnapshot snapshot) {
    return snapshot.finalUri.host == 'id.sspu.edu.cn' &&
        snapshot.finalUri.path.contains('/cas/login');
  }

  AcademicLoginValidationResult _buildResult(
    AcademicLoginValidationStatus status, {
    required String message,
    required String detail,
    Uri? finalUri,
    CampusNetworkStatus? campusNetworkStatus,
    AcademicLoginSessionSnapshot? sessionSnapshot,
  }) {
    return AcademicLoginValidationResult(
      status: status,
      message: message,
      detail: detail,
      checkedAt: DateTime.now(),
      entranceUri: entranceUri,
      finalUri: finalUri,
      campusNetworkStatus: campusNetworkStatus,
      sessionSnapshot: sessionSnapshot,
    );
  }

  AcademicLoginValidationResult _buildSuccessResult({
    required String message,
    required String detail,
    required Uri successUri,
    required CampusNetworkStatus campusNetworkStatus,
  }) {
    final sessionSnapshot = _gateway.currentSessionSnapshot(
      entranceUri: entranceUri,
      finalUri: successUri,
    );
    if (!sessionSnapshot.hasCookies) {
      return _buildResult(
        AcademicLoginValidationStatus.webFlowChanged,
        message: 'OA 登录未返回可保存的身份信息',
        detail: '已到达 OA 页面，但响应链路中未获得 Cookie，无法供后续网页登录复用。',
        finalUri: successUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    return _buildResult(
      AcademicLoginValidationStatus.success,
      message: message,
      detail: detail,
      finalUri: successUri,
      campusNetworkStatus: campusNetworkStatus,
      sessionSnapshot: sessionSnapshot,
    );
  }
}

/// Dio 版 OA 登录网关，手动维护 Cookie 和 302 跳转链路。
class DioAcademicLoginGateway implements AcademicLoginGateway {
  DioAcademicLoginGateway({Dio? dio, Uri? publicKeyUri})
    : _dio = dio ?? Dio(_baseOptions),
      publicKeyUri =
          publicKeyUri ?? Uri.parse('https://id.sspu.edu.cn/cas/jwt/publicKey');

  static final BaseOptions _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    responseType: ResponseType.plain,
    headers: const {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  );

  final Dio _dio;
  final Uri publicKeyUri;
  final _AcademicLoginCookieStore _cookieStore = _AcademicLoginCookieStore();

  @override
  Future<void> resetSession() async {
    _cookieStore.clear();
  }

  @override
  Future<AcademicLoginHttpSnapshot> openLoginPage(
    Uri entranceUri,
    Duration timeout,
  ) {
    return _sendWithRedirects(
      method: 'GET',
      uri: entranceUri,
      timeout: timeout,
    );
  }

  @override
  Future<String> fetchPublicKey(Duration timeout) async {
    final response = await _sendWithRedirects(
      method: 'GET',
      uri: publicKeyUri,
      timeout: timeout,
      accept: 'text/plain,*/*',
    );
    return response.body.trim();
  }

  @override
  Future<AcademicLoginHttpSnapshot> submitLogin({
    required Uri loginUri,
    required Map<String, String> fields,
    required Duration timeout,
  }) {
    return _sendWithRedirects(
      method: 'POST',
      uri: loginUri,
      timeout: timeout,
      body: _formEncode(fields),
      contentType: Headers.formUrlEncodedContentType,
    );
  }

  @override
  AcademicLoginSessionSnapshot currentSessionSnapshot({
    required Uri entranceUri,
    required Uri finalUri,
  }) {
    return AcademicLoginSessionSnapshot(
      cookieHeadersByHost: _cookieStore.toHeadersByHost(),
      authenticatedAt: DateTime.now(),
      entranceUri: entranceUri,
      finalUri: finalUri,
    );
  }

  Future<AcademicLoginHttpSnapshot> _sendWithRedirects({
    required String method,
    required Uri uri,
    required Duration timeout,
    String? body,
    String? contentType,
    String? accept,
  }) async {
    var currentMethod = method;
    var currentUri = uri;
    var currentBody = body;
    var currentContentType = contentType;

    for (var redirectCount = 0; redirectCount < 8; redirectCount++) {
      final headers = <String, String>{};
      final cookieHeader = _cookieStore.headerFor(currentUri);
      if (cookieHeader.isNotEmpty) headers['Cookie'] = cookieHeader;
      if (accept != null) headers['Accept'] = accept;

      final response = await _dio
          .request<String>(
            currentUri.toString(),
            data: currentBody,
            options: Options(
              method: currentMethod,
              followRedirects: false,
              validateStatus: (statusCode) => statusCode != null,
              responseType: ResponseType.plain,
              contentType: currentContentType,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              headers: headers,
            ),
          )
          .timeout(timeout);
      _cookieStore.applySetCookieHeaders(
        currentUri,
        response.headers['set-cookie'] ?? const <String>[],
      );

      final statusCode = response.statusCode;
      final location = response.headers.value('location');
      if (statusCode != null &&
          statusCode >= 300 &&
          statusCode < 400 &&
          location != null &&
          location.isNotEmpty) {
        currentUri = currentUri.resolve(location);
        if (statusCode == 303 ||
            (statusCode == 302 && currentMethod.toUpperCase() == 'POST')) {
          currentMethod = 'GET';
          currentBody = null;
          currentContentType = null;
        }
        continue;
      }

      return AcademicLoginHttpSnapshot(
        finalUri: currentUri,
        statusCode: statusCode,
        body: response.data ?? '',
      );
    }

    return AcademicLoginHttpSnapshot(
      finalUri: currentUri,
      statusCode: null,
      body: '登录跳转次数过多',
    );
  }

  String _formEncode(Map<String, String> fields) {
    return fields.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }
}

class _CasLoginForm {
  const _CasLoginForm({
    required this.actionUri,
    required this.execution,
    required this.failN,
    required this.mfaState,
  });

  final Uri actionUri;
  final String execution;
  final String failN;
  final String mfaState;

  bool get requiresCaptcha {
    final failedCount = int.tryParse(failN);
    return failedCount != null && failedCount >= 3;
  }

  bool get requiresAdditionalVerification => mfaState.isNotEmpty;

  Map<String, String> toFields({
    required String oaAccount,
    required String encryptedPassword,
  }) {
    return {
      'username': oaAccount,
      'password': '__RSA__$encryptedPassword',
      'captcha': '',
      'rememberMe': 'false',
      'currentMenu': '1',
      'failN': failN.isEmpty ? '-1' : failN,
      'mfaState': mfaState,
      'execution': execution,
      '_eventId': 'submit',
      'geolocation': '',
      'fpVisitorId': '',
    };
  }
}

class _AcademicLoginCookieStore {
  final Map<String, Map<String, String>> _cookiesByHost = {};

  void clear() {
    _cookiesByHost.clear();
  }

  void applySetCookieHeaders(Uri uri, List<String> setCookieHeaders) {
    if (setCookieHeaders.isEmpty) return;
    for (final header in setCookieHeaders) {
      final parts = header.split(';');
      final cookiePair = parts.first.trim();
      final separatorIndex = cookiePair.indexOf('=');
      if (separatorIndex <= 0) continue;
      final name = cookiePair.substring(0, separatorIndex).trim();
      final value = cookiePair.substring(separatorIndex + 1).trim();
      if (name.isEmpty) continue;
      final hostKey = _hostKeyForCookie(uri, parts.skip(1));
      final hostCookies = _cookiesByHost.putIfAbsent(hostKey, () => {});
      if (value.isEmpty) {
        hostCookies.remove(name);
        continue;
      }
      hostCookies[name] = value;
    }
  }

  String headerFor(Uri uri) {
    final normalizedHost = uri.host.toLowerCase();
    final cookiePairs = <String>[];
    for (final entry in _cookiesByHost.entries) {
      if (normalizedHost == entry.key ||
          normalizedHost.endsWith('.${entry.key}')) {
        for (final cookie in entry.value.entries) {
          cookiePairs.add('${cookie.key}=${cookie.value}');
        }
      }
    }
    return cookiePairs.join('; ');
  }

  Map<String, String> toHeadersByHost() {
    final cookieHeadersByHost = <String, String>{};
    final sortedHosts = _cookiesByHost.keys.toList()..sort();
    for (final host in sortedHosts) {
      final cookiePairs =
          _cookiesByHost[host]!.entries
              .where((entry) => entry.value.trim().isNotEmpty)
              .map((entry) => '${entry.key}=${entry.value}')
              .toList()
            ..sort();
      if (cookiePairs.isEmpty) continue;
      cookieHeadersByHost[host] = cookiePairs.join('; ');
    }
    return Map.unmodifiable(cookieHeadersByHost);
  }

  String _hostKeyForCookie(Uri uri, Iterable<String> attributes) {
    var hostKey = uri.host.toLowerCase();
    for (final attribute in attributes) {
      final separatorIndex = attribute.indexOf('=');
      if (separatorIndex <= 0) continue;
      final attributeName = attribute.substring(0, separatorIndex).trim();
      if (attributeName.toLowerCase() != 'domain') continue;
      final domain = attribute.substring(separatorIndex + 1).trim();
      final normalizedDomain = domain.toLowerCase().replaceFirst(
        RegExp(r'^\.+'),
        '',
      );
      if (normalizedDomain.isEmpty) continue;
      if (hostKey == normalizedDomain ||
          hostKey.endsWith('.$normalizedDomain')) {
        hostKey = normalizedDomain;
      }
    }
    return hostKey;
  }
}

class _RsaPkcs1Encryptor {
  static String encryptToBase64(String plainText, String publicKeyPem) {
    final publicKey = _RsaPublicKey.fromPem(publicKeyPem);
    final message = Uint8List.fromList(utf8.encode(plainText));
    final keyLength = (publicKey.modulus.bitLength + 7) ~/ 8;
    if (message.length > keyLength - 11) {
      throw StateError('OA 密码长度超过 CAS RSA 公钥可加密范围');
    }

    final block = Uint8List(keyLength);
    final random = Random.secure();
    final paddingLength = keyLength - message.length - 3;
    block[0] = 0x00;
    block[1] = 0x02;
    for (var index = 0; index < paddingLength; index++) {
      var randomByte = 0;
      while (randomByte == 0) {
        randomByte = random.nextInt(256);
      }
      block[index + 2] = randomByte;
    }
    block[paddingLength + 2] = 0x00;
    block.setRange(paddingLength + 3, keyLength, message);

    final encrypted = _bytesToBigInt(
      block,
    ).modPow(publicKey.exponent, publicKey.modulus);
    return base64Encode(_bigIntToFixedBytes(encrypted, keyLength));
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToFixedBytes(BigInt value, int length) {
    final output = Uint8List(length);
    var remaining = value;
    for (var index = length - 1; index >= 0; index--) {
      output[index] = (remaining & BigInt.from(0xff)).toInt();
      remaining = remaining >> 8;
    }
    return output;
  }
}

class _RsaPublicKey {
  const _RsaPublicKey({required this.modulus, required this.exponent});

  final BigInt modulus;
  final BigInt exponent;

  factory _RsaPublicKey.fromPem(String pem) {
    final normalized = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    final der = Uint8List.fromList(base64Decode(normalized));
    final topLevel = _DerReader(der).readConstructed(0x30);
    topLevel.readConstructed(0x30);
    final bitString = topLevel.readValue(0x03);
    if (bitString.isEmpty || bitString.first != 0x00) {
      throw const FormatException('CAS RSA 公钥 BIT STRING 格式异常');
    }

    final keySequence = _DerReader(
      Uint8List.fromList(bitString.sublist(1)),
    ).readConstructed(0x30);
    return _RsaPublicKey(
      modulus: _stripLeadingZeroAndReadInteger(keySequence.readValue(0x02)),
      exponent: _stripLeadingZeroAndReadInteger(keySequence.readValue(0x02)),
    );
  }

  static BigInt _stripLeadingZeroAndReadInteger(List<int> bytes) {
    var startIndex = 0;
    while (startIndex < bytes.length - 1 && bytes[startIndex] == 0) {
      startIndex++;
    }
    return _RsaPkcs1Encryptor._bytesToBigInt(bytes.sublist(startIndex));
  }
}

class _DerReader {
  _DerReader(this.bytes);

  final Uint8List bytes;
  int _offset = 0;

  _DerReader readConstructed(int expectedTag) {
    return _DerReader(readValue(expectedTag));
  }

  Uint8List readValue(int expectedTag) {
    if (_offset >= bytes.length || bytes[_offset] != expectedTag) {
      throw FormatException('ASN.1 标签不匹配：期望 $expectedTag');
    }
    _offset++;
    final length = _readLength();
    if (_offset + length > bytes.length) {
      throw const FormatException('ASN.1 长度超出数据范围');
    }
    final value = Uint8List.sublistView(bytes, _offset, _offset + length);
    _offset += length;
    return value;
  }

  int _readLength() {
    if (_offset >= bytes.length) {
      throw const FormatException('ASN.1 长度缺失');
    }
    final first = bytes[_offset++];
    if (first < 0x80) return first;

    final byteCount = first & 0x7f;
    if (byteCount == 0 || byteCount > 4 || _offset + byteCount > bytes.length) {
      throw const FormatException('ASN.1 长度格式异常');
    }
    var length = 0;
    for (var index = 0; index < byteCount; index++) {
      length = (length << 8) | bytes[_offset++];
    }
    return length;
  }
}
