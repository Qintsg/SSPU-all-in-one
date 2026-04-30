/*
 * 体育部课外活动考勤服务 — 登录体育部查询系统并只读获取考勤汇总与明细
 * @Project : SSPU-all-in-one
 * @File : sports_attendance_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-30
 */

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../models/academic_credentials.dart';
import '../models/campus_network_status.dart';
import '../models/sports_attendance.dart';
import 'academic_credentials_service.dart';
import 'campus_network_status_service.dart';
import 'http_service.dart';
import 'storage_service.dart';

/// 教务页依赖的体育部考勤读取接口，便于测试中替换实现。
abstract class SportsAttendanceClient {
  /// 登录体育部查询系统并读取课外活动考勤。
  Future<SportsAttendanceQueryResult> fetchAttendanceSummary();
}

/// 体育部查询系统 HTTP 响应快照。
class SportsAttendanceHttpSnapshot {
  const SportsAttendanceHttpSnapshot({
    required this.finalUri,
    required this.statusCode,
    required this.body,
  });

  /// 请求完成后的最终地址。
  final Uri finalUri;

  /// HTTP 状态码。
  final int? statusCode;

  /// 已按 GBK / GB2312 解码的响应正文。
  final String body;
}

/// 可替换的体育部查询系统网关。
abstract class SportsAttendanceGateway {
  /// 重置 Cookie 会话，避免不同账号状态互相污染。
  Future<void> resetSession();

  /// 打开体育部查询系统登录页。
  Future<SportsAttendanceHttpSnapshot> openLoginPage(
    Uri entranceUri,
    Duration timeout,
  );

  /// 提交学生身份账号密码登录。
  Future<SportsAttendanceHttpSnapshot> submitLogin({
    required Uri loginUri,
    required Map<String, String> fields,
    required Duration timeout,
  });

  /// 读取课外活动考勤明细页。
  Future<SportsAttendanceHttpSnapshot> fetchScorePage(
    Uri scoreUri,
    Duration timeout,
  );
}

/// 体育部课外活动考勤只读查询服务。
class SportsAttendanceService implements SportsAttendanceClient {
  SportsAttendanceService({
    AcademicCredentialsService? credentialsService,
    CampusNetworkStatusService? campusNetworkStatusService,
    SportsAttendanceGateway? gateway,
    Uri? entranceUri,
    Uri? scoreUri,
    Duration? timeout,
  }) : _credentialsService =
           credentialsService ?? AcademicCredentialsService.instance,
       _campusNetworkStatusService =
           campusNetworkStatusService ?? CampusNetworkStatusService.instance,
       _gateway = gateway ?? DioSportsAttendanceGateway(),
       entranceUri = entranceUri ?? defaultEntranceUri,
       scoreUri = scoreUri ?? defaultScoreUri,
       timeout = timeout ?? const Duration(seconds: 15);

  /// 全局单例。
  static final SportsAttendanceService instance = SportsAttendanceService();

  /// 体育部查询系统入口。
  static final Uri defaultEntranceUri = Uri.parse(
    'https://tygl.sspu.edu.cn/sportscore/',
  );

  /// 课外活动考勤明细页。
  static final Uri defaultScoreUri = Uri.parse(
    'https://tygl.sspu.edu.cn/sportscore/stScore.aspx?item=1',
  );

  /// 体育部考勤默认自动刷新间隔，单位分钟。
  static const int defaultAutoRefreshIntervalMinutes = 30;

  final AcademicCredentialsService _credentialsService;
  final CampusNetworkStatusService _campusNetworkStatusService;
  final SportsAttendanceGateway _gateway;

  /// 登录入口地址。
  final Uri entranceUri;

  /// 考勤明细页地址。
  final Uri scoreUri;

  /// 单次网络步骤超时时间。
  final Duration timeout;

  /// 读取体育部考勤自动刷新开关。
  Future<bool> isAutoRefreshEnabled() async {
    return StorageService.getBool(
      StorageKeys.sportsAttendanceAutoRefreshEnabled,
    );
  }

  /// 保存体育部考勤自动刷新开关。
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    await StorageService.setBool(
      StorageKeys.sportsAttendanceAutoRefreshEnabled,
      enabled,
    );
  }

  /// 读取体育部考勤自动刷新间隔。
  Future<int> getAutoRefreshIntervalMinutes() async {
    final stored = await StorageService.getInt(
      StorageKeys.sportsAttendanceAutoRefreshIntervalMinutes,
    );
    return _normalizeAutoRefreshInterval(
      stored ?? defaultAutoRefreshIntervalMinutes,
    );
  }

  /// 保存体育部考勤自动刷新间隔。
  Future<void> setAutoRefreshIntervalMinutes(int minutes) async {
    await StorageService.setInt(
      StorageKeys.sportsAttendanceAutoRefreshIntervalMinutes,
      _normalizeAutoRefreshInterval(minutes),
    );
  }

  @override
  Future<SportsAttendanceQueryResult> fetchAttendanceSummary() async {
    CampusNetworkStatus? campusStatus;
    try {
      final credentialsStatus = await _credentialsService.getStatus();
      final studentId = credentialsStatus.oaAccount.trim();
      if (studentId.isEmpty) {
        return _buildResult(
          SportsAttendanceQueryStatus.missingStudentId,
          message: '请先保存学工号',
          detail: '体育部查询系统使用学工号作为学生身份账号。',
        );
      }

      final sportsPassword = await _credentialsService.readSecret(
        AcademicCredentialSecret.sportsQueryPassword,
      );
      if (sportsPassword == null || sportsPassword.isEmpty) {
        return _buildResult(
          SportsAttendanceQueryStatus.missingSportsPassword,
          message: '请先保存体育部查询密码',
          detail: '体育部查询系统密码与 OA 密码不同，需单独配置。',
        );
      }

      campusStatus = await _campusNetworkStatusService.checkStatus();
      if (!campusStatus.canAccessRestrictedServices) {
        return _buildResult(
          SportsAttendanceQueryStatus.campusNetworkUnavailable,
          message: '校园网 / VPN 不可用，无法访问体育部查询系统',
          detail: campusStatus.detail,
          campusNetworkStatus: campusStatus,
        );
      }

      return _fetchWithCredentials(
        studentId: studentId,
        sportsPassword: sportsPassword,
        campusNetworkStatus: campusStatus,
      );
    } on TimeoutException {
      return _buildResult(
        SportsAttendanceQueryStatus.networkError,
        message: '体育部考勤查询超时',
        detail: '访问体育部查询系统登录或考勤页面超时。',
        campusNetworkStatus: campusStatus,
      );
    } on DioException catch (error) {
      return _buildResult(
        SportsAttendanceQueryStatus.networkError,
        message: '体育部考勤查询网络失败',
        detail: HttpService.describeError(error),
        finalUri: error.requestOptions.uri,
        campusNetworkStatus: campusStatus,
      );
    } catch (error) {
      return _buildResult(
        SportsAttendanceQueryStatus.unexpectedError,
        message: '体育部考勤查询失败',
        detail: '未归类异常：$error',
        campusNetworkStatus: campusStatus,
      );
    }
  }

  Future<SportsAttendanceQueryResult> _fetchWithCredentials({
    required String studentId,
    required String sportsPassword,
    required CampusNetworkStatus campusNetworkStatus,
  }) async {
    await _gateway.resetSession();
    final loginPage = await _gateway.openLoginPage(entranceUri, timeout);
    final loginForm = _parseLoginForm(loginPage);
    if (loginForm == null) {
      return _buildResult(
        SportsAttendanceQueryStatus.loginPageUnavailable,
        message: '无法识别体育部查询系统登录页',
        detail: '登录页缺少 txtuser、txtpwd 或 ASP.NET WebForms 隐藏字段。',
        finalUri: loginPage.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final submitSnapshot = await _gateway.submitLogin(
      loginUri: loginForm.actionUri,
      fields: loginForm.toFields(
        studentId: studentId,
        sportsPassword: sportsPassword,
      ),
      timeout: timeout,
    );
    if (_isRejectedLogin(submitSnapshot)) {
      return _buildResult(
        SportsAttendanceQueryStatus.credentialsRejected,
        message: '体育部账号或密码未通过校验',
        detail: '体育部查询系统仍停留在登录页或返回登录失败提示。',
        finalUri: submitSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final scoreSnapshot = await _gateway.fetchScorePage(scoreUri, timeout);
    if (_isSessionUnavailable(scoreSnapshot)) {
      return _buildResult(
        SportsAttendanceQueryStatus.sessionUnavailable,
        message: '体育部登录状态不可用',
        detail: '登录后无法访问课外活动考勤明细页，可能是会话已失效或站点流程变化。',
        finalUri: scoreSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final summary = _SportsAttendancePageParser.parse(
      scoreSnapshot.body,
      sourceUri: scoreSnapshot.finalUri,
    );
    if (summary == null) {
      return _buildResult(
        SportsAttendanceQueryStatus.parseFailed,
        message: '未解析到体育部考勤数据',
        detail: '课外活动考勤页面结构与预期不一致，未提取到四类次数或明细记录。',
        finalUri: scoreSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    return _buildResult(
      SportsAttendanceQueryStatus.success,
      message: '体育部考勤查询成功',
      detail: '已读取课外活动考勤总次数与明细记录。',
      finalUri: scoreSnapshot.finalUri,
      campusNetworkStatus: campusNetworkStatus,
      summary: summary,
    );
  }

  _SportsLoginForm? _parseLoginForm(SportsAttendanceHttpSnapshot snapshot) {
    final document = html_parser.parse(snapshot.body);
    for (final form in document.querySelectorAll('form')) {
      final hasStudentInput =
          form.querySelector('input[name="txtuser"]') != null;
      final hasPasswordInput =
          form.querySelector('input[name="txtpwd"]') != null;
      final viewState = _inputValue(form, '__VIEWSTATE');
      if (!hasStudentInput || !hasPasswordInput || viewState.isEmpty) continue;

      final action = form.attributes['action']?.trim();
      return _SportsLoginForm(
        actionUri: snapshot.finalUri.resolve(
          action == null || action.isEmpty ? snapshot.finalUri.path : action,
        ),
        hiddenFields: _collectHiddenFields(form),
      );
    }
    return null;
  }

  Map<String, String> _collectHiddenFields(html_dom.Element form) {
    final fields = <String, String>{};
    for (final input in form.querySelectorAll('input')) {
      final name = input.attributes['name']?.trim();
      if (name == null || name.isEmpty) continue;
      final type = input.attributes['type']?.toLowerCase().trim() ?? '';
      if (type == 'hidden') fields[name] = input.attributes['value'] ?? '';
    }
    return fields;
  }

  String _inputValue(html_dom.Element form, String name) {
    final element = form.querySelector('input[name="$name"]');
    return element?.attributes['value']?.trim() ?? '';
  }

  bool _isRejectedLogin(SportsAttendanceHttpSnapshot snapshot) {
    final normalizedBody = _normalizeText(snapshot.body);
    return _parseLoginForm(snapshot) != null ||
        normalizedBody.contains('alert(') ||
        normalizedBody.contains('密码错误') ||
        normalizedBody.contains('登录失败');
  }

  bool _isSessionUnavailable(SportsAttendanceHttpSnapshot snapshot) {
    final path = snapshot.finalUri.path.toLowerCase();
    if (path.endsWith('/errpage.aspx')) return true;
    if (_parseLoginForm(snapshot) != null) return true;
    final normalizedBody = _normalizeText(snapshot.body);
    return normalizedBody.contains('请登录') || normalizedBody.contains('错误页面');
  }

  String _normalizeText(String text) {
    return text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  SportsAttendanceQueryResult _buildResult(
    SportsAttendanceQueryStatus status, {
    required String message,
    required String detail,
    Uri? finalUri,
    CampusNetworkStatus? campusNetworkStatus,
    SportsAttendanceSummary? summary,
  }) {
    return SportsAttendanceQueryResult(
      status: status,
      message: message,
      detail: detail,
      checkedAt: DateTime.now(),
      entranceUri: entranceUri,
      finalUri: finalUri,
      campusNetworkStatus: campusNetworkStatus,
      summary: summary,
    );
  }

  int _normalizeAutoRefreshInterval(int minutes) {
    return minutes <= 0 ? defaultAutoRefreshIntervalMinutes : minutes;
  }
}

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

class _SportsLoginForm {
  const _SportsLoginForm({required this.actionUri, required this.hiddenFields});

  final Uri actionUri;
  final Map<String, String> hiddenFields;

  Map<String, String> toFields({
    required String studentId,
    required String sportsPassword,
  }) {
    return {
      ...hiddenFields,
      'dlljs': 'st',
      'txtuser': studentId,
      'txtpwd': sportsPassword,
      'btnok.x': '20',
      'btnok.y': '10',
    };
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

class _SportsAttendancePageParser {
  static SportsAttendanceSummary? parse(String body, {required Uri sourceUri}) {
    final document = html_parser.parse(body);
    final normalizedPageText = _cleanText(document.body?.text ?? body);
    final records = _parseRecords(document);
    final explicitCounts = _parseExplicitCounts(normalizedPageText);
    final aggregatedCounts = _aggregateRecordCounts(records);

    final morningExerciseCount =
        explicitCounts[SportsAttendanceCategory.morningExercise] ??
        aggregatedCounts[SportsAttendanceCategory.morningExercise] ??
        0;
    final extracurricularActivityCount =
        explicitCounts[SportsAttendanceCategory.extracurricularActivity] ??
        aggregatedCounts[SportsAttendanceCategory.extracurricularActivity] ??
        0;
    final countAdjustmentCount =
        explicitCounts[SportsAttendanceCategory.countAdjustment] ??
        aggregatedCounts[SportsAttendanceCategory.countAdjustment] ??
        0;
    final sportsCorridorCount =
        explicitCounts[SportsAttendanceCategory.sportsCorridor] ??
        aggregatedCounts[SportsAttendanceCategory.sportsCorridor] ??
        0;

    final hasAnyCount =
        morningExerciseCount != 0 ||
        extracurricularActivityCount != 0 ||
        countAdjustmentCount != 0 ||
        sportsCorridorCount != 0;
    if (!hasAnyCount && records.isEmpty) return null;

    return SportsAttendanceSummary(
      morningExerciseCount: morningExerciseCount,
      extracurricularActivityCount: extracurricularActivityCount,
      countAdjustmentCount: countAdjustmentCount,
      sportsCorridorCount: sportsCorridorCount,
      records: List.unmodifiable(records),
      fetchedAt: DateTime.now(),
      sourceUri: sourceUri,
    );
  }

  static List<SportsAttendanceRecord> _parseRecords(
    html_dom.Document document,
  ) {
    final records = <SportsAttendanceRecord>[];
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .where((cellText) => cellText.isNotEmpty)
          .toList();
      if (cells.length < 2) continue;

      final joinedCells = cells.join(' ');
      if (joinedCells.length > 500 || cells.any((cell) => cell.length > 160)) {
        continue;
      }
      final category = _categoryOf(joinedCells);
      final hasDate = _datePattern.hasMatch(joinedCells);
      final hasUsefulNumber = RegExp(
        r'-?\d+\s*次(?!数|调整)',
      ).hasMatch(joinedCells);
      if (category == SportsAttendanceCategory.unknown && !hasDate) continue;
      if (!hasDate && !hasUsefulNumber) continue;

      records.add(
        SportsAttendanceRecord(
          category: category,
          count: _recordCount(cells, category),
          cells: List.unmodifiable(cells),
          occurredAt: _firstMatchText(cells, _datePattern),
          project: _firstProject(cells, category),
          location: _firstLocation(cells),
          remark: _lastRemark(cells),
        ),
      );
    }
    return records;
  }

  static Map<SportsAttendanceCategory, int> _parseExplicitCounts(String text) {
    final counts = <SportsAttendanceCategory, int>{};
    for (final category in SportsAttendanceCategory.values) {
      if (category == SportsAttendanceCategory.unknown) continue;
      final label = RegExp.escape(category.label);
      final patterns = [
        RegExp('$label(?:总次数|次数|合计|累计)[^0-9-]{0,8}(-?\\d+)\\s*次?'),
        RegExp('(?:总|合计|累计)[^，。；;]{0,8}$label[^0-9-]{0,8}(-?\\d+)\\s*次?'),
        RegExp('$label\\s*[:：]\\s*(-?\\d+)\\s*次?'),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        final parsedCount = int.tryParse(match?.group(1) ?? '');
        if (parsedCount == null) continue;
        counts[category] = parsedCount;
        break;
      }
    }
    return counts;
  }

  static Map<SportsAttendanceCategory, int> _aggregateRecordCounts(
    List<SportsAttendanceRecord> records,
  ) {
    final counts = <SportsAttendanceCategory, int>{};
    for (final record in records) {
      if (record.category == SportsAttendanceCategory.unknown) continue;
      counts[record.category] = (counts[record.category] ?? 0) + record.count;
    }
    return counts;
  }

  static SportsAttendanceCategory _categoryOf(String text) {
    if (text.contains('早操')) return SportsAttendanceCategory.morningExercise;
    if (text.contains('次数调整') || text.contains('调整')) {
      return SportsAttendanceCategory.countAdjustment;
    }
    if (text.contains('体育长廊') || text.contains('长廊')) {
      return SportsAttendanceCategory.sportsCorridor;
    }
    if (text.contains('课外活动') || text.contains('课外')) {
      return SportsAttendanceCategory.extracurricularActivity;
    }
    return SportsAttendanceCategory.unknown;
  }

  static int _recordCount(
    List<String> cells,
    SportsAttendanceCategory category,
  ) {
    final joinedCells = cells.join(' ');
    if (joinedCells.contains('无效')) return 0;
    final countWithUnit = RegExp(
      r'(-?\d+)\s*次(?!数|调整)',
    ).firstMatch(joinedCells);
    final parsedCountWithUnit = int.tryParse(countWithUnit?.group(1) ?? '');
    if (parsedCountWithUnit != null) return parsedCountWithUnit;

    if (category == SportsAttendanceCategory.countAdjustment) {
      for (final cell in cells.reversed) {
        if (_datePattern.hasMatch(cell)) continue;
        final parsedSignedCount = int.tryParse(cell.trim());
        if (parsedSignedCount != null) return parsedSignedCount;
      }
    }
    return 1;
  }

  static String? _firstMatchText(List<String> cells, RegExp pattern) {
    for (final cell in cells) {
      final match = pattern.firstMatch(cell);
      if (match != null) return match.group(0);
    }
    return null;
  }

  static String? _firstProject(
    List<String> cells,
    SportsAttendanceCategory category,
  ) {
    for (final cell in cells) {
      if (_datePattern.hasMatch(cell)) continue;
      if (RegExp(r'^-?\d+\s*次?$').hasMatch(cell)) continue;
      if (cell == category.label) continue;
      if (_looksLikeLocation(cell)) continue;
      return cell;
    }
    return category == SportsAttendanceCategory.unknown ? null : category.label;
  }

  static String? _firstLocation(List<String> cells) {
    for (final cell in cells) {
      if (_looksLikeLocation(cell)) return cell;
    }
    return null;
  }

  static String? _lastRemark(List<String> cells) {
    for (final cell in cells.reversed) {
      if (_datePattern.hasMatch(cell)) continue;
      if (RegExp(r'^-?\d+\s*次?$').hasMatch(cell)) continue;
      if (_looksLikeLocation(cell)) continue;
      return cell;
    }
    return null;
  }

  static bool _looksLikeLocation(String text) {
    return text.contains('场') ||
        text.contains('馆') ||
        text.contains('房') ||
        text.contains('长廊') ||
        text.contains('校区') ||
        text.contains('操场');
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final RegExp _datePattern = RegExp(
    r'\d{4}[-/]\d{1,2}[-/]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?',
  );
}
