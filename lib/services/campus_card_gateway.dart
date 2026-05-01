/*
 * 校园卡 HTTP 网关 — 手动维护 OA/CAS Cookie 与校园卡跳转链路
 * @Project : SSPU-all-in-one
 * @File : campus_card_gateway.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'campus_card_service.dart';

/// Dio 版校园卡网关，手动维护 Cookie 和 302 跳转链路。
class DioCampusCardGateway implements CampusCardGateway {
  DioCampusCardGateway({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

  static final BaseOptions _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    responseType: ResponseType.bytes,
    headers: const {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  );

  final Dio _dio;
  final _CampusCardCookieStore _cookieStore = _CampusCardCookieStore();

  @override
  Future<void> resetSession(Map<String, String> cookieHeadersByHost) async {
    _cookieStore.clear();
    _cookieStore.applyCookieHeaders(cookieHeadersByHost);
  }

  @override
  Future<CampusCardHttpSnapshot> openEntryPage(
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
  Future<CampusCardHttpSnapshot> fetchPage(Uri pageUri, Duration timeout) {
    return _sendWithRedirects(method: 'GET', uri: pageUri, timeout: timeout);
  }

  @override
  Future<CampusCardHttpSnapshot> queryTransactions({
    required Uri queryUri,
    required Map<String, String> fields,
    required Duration timeout,
  }) {
    return _sendWithRedirects(
      method: 'POST',
      uri: queryUri,
      timeout: timeout,
      body: _formEncode(fields),
      contentType: Headers.formUrlEncodedContentType,
      accept: 'text/xml,application/xml,text/html,*/*',
    );
  }

  Future<CampusCardHttpSnapshot> _sendWithRedirects({
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
        currentUri = currentUri.resolve(location);
        if (statusCode == 303 ||
            (statusCode == 302 && currentMethod.toUpperCase() == 'POST')) {
          currentMethod = 'GET';
          currentBody = null;
          currentContentType = null;
        }
        continue;
      }

      return CampusCardHttpSnapshot(
        finalUri: currentUri,
        statusCode: statusCode,
        body: _decodePage(response.data ?? const <int>[]),
      );
    }

    return CampusCardHttpSnapshot(
      finalUri: currentUri,
      statusCode: null,
      body: '校园卡系统跳转次数过多',
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
}

class _CampusCardCookieStore {
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
