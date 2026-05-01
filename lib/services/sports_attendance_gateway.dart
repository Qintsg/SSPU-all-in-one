/*
 * 体育部考勤 HTTP 网关 — 手动维护 Cookie 与 WebForms 跳转链路
 * @Project : SSPU-all-in-one
 * @File : sports_attendance_gateway.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'sports_attendance_service.dart';

/// Dio 版体育部查询系统网关，手动维护 Cookie 和 302 跳转链路。
class DioSportsAttendanceGateway implements SportsAttendanceGateway {
  DioSportsAttendanceGateway({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

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
  final _SportsAttendanceCookieStore _cookieStore =
      _SportsAttendanceCookieStore();

  @override
  Future<void> resetSession() async {
    _cookieStore.clear();
  }

  @override
  Future<SportsAttendanceHttpSnapshot> openLoginPage(
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
  Future<SportsAttendanceHttpSnapshot> submitLogin({
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
  Future<SportsAttendanceHttpSnapshot> fetchScorePage(
    Uri scoreUri,
    Duration timeout,
  ) {
    return _sendWithRedirects(method: 'GET', uri: scoreUri, timeout: timeout);
  }

  Future<SportsAttendanceHttpSnapshot> _sendWithRedirects({
    required String method,
    required Uri uri,
    required Duration timeout,
    String? body,
    String? contentType,
  }) async {
    var currentMethod = method;
    var currentUri = uri;
    var currentBody = body;
    var currentContentType = contentType;

    for (var redirectCount = 0; redirectCount < 6; redirectCount++) {
      final headers = <String, String>{};
      final cookieHeader = _cookieStore.headerFor(currentUri);
      if (cookieHeader.isNotEmpty) headers['Cookie'] = cookieHeader;

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

      return SportsAttendanceHttpSnapshot(
        finalUri: currentUri,
        statusCode: statusCode,
        body: _decodePage(response.data ?? const <int>[]),
      );
    }

    return SportsAttendanceHttpSnapshot(
      finalUri: currentUri,
      statusCode: null,
      body: '体育部查询系统跳转次数过多',
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
    if (charsetProbe.contains('charset=utf-8') ||
        charsetProbe.contains('charset="utf-8') ||
        charsetProbe.contains("charset='utf-8")) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (charsetProbe.contains('charset=gb') ||
        charsetProbe.contains('charset="gb') ||
        charsetProbe.contains("charset='gb")) {
      return gbk_bytes.decode(bytes);
    }

    final utf8Decoded = utf8.decode(bytes, allowMalformed: true);
    final gbkDecoded = gbk_bytes.decode(bytes);
    return _mojibakeScore(utf8Decoded) <= _mojibakeScore(gbkDecoded)
        ? utf8Decoded
        : gbkDecoded;
  }

  int _mojibakeScore(String text) {
    final mojibakeHints = ['�', '锛', '瀛', '璇', '惧', '娲', '诲', '姩'];
    return mojibakeHints.fold<int>(
      0,
      (score, hint) => score + hint.allMatches(text).length,
    );
  }
}

class _SportsAttendanceCookieStore {
  final Map<String, Map<String, String>> _cookiesByHost = {};

  void clear() {
    _cookiesByHost.clear();
  }

  void applySetCookieHeaders(Uri uri, List<String> setCookieHeaders) {
    if (setCookieHeaders.isEmpty) return;
    final hostCookies = _cookiesByHost.putIfAbsent(
      uri.host.toLowerCase(),
      () => {},
    );
    for (final header in setCookieHeaders) {
      final cookiePair = header.split(';').first.trim();
      final separatorIndex = cookiePair.indexOf('=');
      if (separatorIndex <= 0) continue;
      final name = cookiePair.substring(0, separatorIndex).trim();
      final value = cookiePair.substring(separatorIndex + 1).trim();
      if (name.isEmpty) continue;
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
}
