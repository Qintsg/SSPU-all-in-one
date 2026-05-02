/*
 * 本专科教务 HTTP 网关 — 手动维护 OA/CAS Cookie 与 EAMS 跳转链路
 * @Project : SSPU-all-in-one
 * @File : academic_eams_gateway.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

/// Dio 版本专科教务网关，保持只读 GET / 查询 POST 边界。
class DioAcademicEamsGateway implements AcademicEamsGateway {
  DioAcademicEamsGateway({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

  static final BaseOptions _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    responseType: ResponseType.bytes,
    headers: const {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) '
          'Gecko/20100101 Firefox/125.0',
    },
  );

  final Dio _dio;
  final _AcademicEamsCookieStore _cookieStore = _AcademicEamsCookieStore();

  @override
  Future<void> resetSession(Map<String, String> cookieHeadersByHost) async {
    _cookieStore.clear();
    _cookieStore.applyCookieHeaders(cookieHeadersByHost);
  }

  @override
  Future<AcademicEamsHttpSnapshot> openEntryPage(
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
  Future<AcademicEamsHttpSnapshot> fetchPage(Uri pageUri, Duration timeout) {
    return _sendWithRedirects(method: 'GET', uri: pageUri, timeout: timeout);
  }

  @override
  Future<AcademicEamsHttpSnapshot> submitForm({
    required Uri formUri,
    required String method,
    required Map<String, String> fields,
    required Duration timeout,
  }) {
    final normalizedMethod = method.trim().toUpperCase();
    final requestMethod = normalizedMethod == 'GET' ? 'GET' : 'POST';
    return _sendWithRedirects(
      method: requestMethod,
      uri: formUri,
      timeout: timeout,
      body: requestMethod == 'POST' ? _formEncode(fields) : null,
      queryParameters: requestMethod == 'GET' ? fields : null,
      contentType: requestMethod == 'POST'
          ? Headers.formUrlEncodedContentType
          : null,
      accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    );
  }

  Future<AcademicEamsHttpSnapshot> _sendWithRedirects({
    required String method,
    required Uri uri,
    required Duration timeout,
    String? body,
    Map<String, String>? queryParameters,
    String? contentType,
    String? accept,
  }) async {
    var currentMethod = method;
    var currentUri = queryParameters == null
        ? uri
        : uri.replace(
            queryParameters: {...uri.queryParameters, ...queryParameters},
          );
    var currentBody = body;
    var currentContentType = contentType;

    for (var redirectCount = 0; redirectCount < 8; redirectCount++) {
      final headers = <String, String>{};
      final cookieHeader = _cookieStore.headerFor(currentUri);
      if (cookieHeader.isNotEmpty) headers['Cookie'] = cookieHeader;
      if (accept != null) headers['Accept'] = accept;

      final response = await _dio
          .request<List<int>>(
            currentUri.toString(),
            data: currentBody,
            options: Options(
              method: currentMethod,
              followRedirects: false,
              validateStatus: (statusCode) => statusCode != null,
              responseType: ResponseType.bytes,
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
        currentUri = _normalizeRedirectUri(currentUri.resolve(location));
        if (statusCode == 303 ||
            (statusCode == 302 && currentMethod.toUpperCase() == 'POST')) {
          currentMethod = 'GET';
          currentBody = null;
          currentContentType = null;
        }
        continue;
      }

      return AcademicEamsHttpSnapshot(
        finalUri: currentUri,
        statusCode: statusCode,
        body: _decodePage(response.data ?? const <int>[]),
      );
    }

    return AcademicEamsHttpSnapshot(
      finalUri: currentUri,
      statusCode: null,
      body: '本专科教务系统跳转次数过多',
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

  String _decodePage(List<int> bytes) {
    final charsetProbe = latin1.decode(bytes.take(4096).toList()).toLowerCase();
    if (charsetProbe.contains('charset=gb') ||
        charsetProbe.contains('charset="gb') ||
        charsetProbe.contains("charset='gb")) {
      return gbk_bytes.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Uri _normalizeRedirectUri(Uri uri) {
    if (uri.scheme == 'http' && uri.host.toLowerCase() == 'id.sspu.edu.cn') {
      return uri.replace(scheme: 'https');
    }
    return uri;
  }
}

class _AcademicEamsCookieStore {
  final Map<String, Map<String, String>> _cookiesByHost = {};

  void clear() {
    _cookiesByHost.clear();
  }

  void applyCookieHeaders(Map<String, String> cookieHeadersByHost) {
    for (final entry in cookieHeadersByHost.entries) {
      final host = entry.key.toLowerCase().trim();
      if (host.isEmpty) continue;
      final cookies = _cookiesByHost.putIfAbsent(host, () => {});
      for (final cookiePair in entry.value.split(';')) {
        final separatorIndex = cookiePair.indexOf('=');
        if (separatorIndex <= 0) continue;
        final name = cookiePair.substring(0, separatorIndex).trim();
        final value = cookiePair.substring(separatorIndex + 1).trim();
        if (name.isNotEmpty && value.isNotEmpty) cookies[name] = value;
      }
    }
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
