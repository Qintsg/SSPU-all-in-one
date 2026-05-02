/*
 * OA/CAS 登录网关 — 手动维护 Cookie 与跳转链路
 * @Project : SSPU-all-in-one
 * @File : academic_login_gateway.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'academic_login_validation_service.dart';

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
