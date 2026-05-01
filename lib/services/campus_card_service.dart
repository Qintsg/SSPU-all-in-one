/*
 * 校园卡余额查询服务 — 通过 OA/CAS 登录态只读获取余额、状态和交易记录
 * @Project : SSPU-all-in-one
 * @File : campus_card_service.dart
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
import '../models/academic_login_validation.dart';
import '../models/campus_card.dart';
import '../models/campus_network_status.dart';
import 'academic_credentials_service.dart';
import 'academic_login_validation_service.dart';
import 'campus_network_status_service.dart';
import 'http_service.dart';
import 'storage_service.dart';

/// 教务首页依赖的校园卡查询接口，便于 widget 测试替换。
abstract class CampusCardBalanceClient {
  /// 读取校园卡余额、卡状态和交易记录。
  Future<CampusCardQueryResult> fetchCampusCard({
    DateTime? startDate,
    DateTime? endDate,
  });
}

/// 校园卡系统 HTTP 响应快照。
class CampusCardHttpSnapshot {
  const CampusCardHttpSnapshot({
    required this.finalUri,
    required this.statusCode,
    required this.body,
  });

  /// 请求完成后的最终地址。
  final Uri finalUri;

  /// HTTP 状态码。
  final int? statusCode;

  /// 已解码响应正文。
  final String body;
}

/// 可替换的校园卡系统网关。
abstract class CampusCardGateway {
  /// 重置 Cookie 会话，并注入最近一次 OA/CAS 登录得到的 Cookie。
  Future<void> resetSession(Map<String, String> cookieHeadersByHost);

  /// 打开 OA 校园卡入口并跟随跳转到业务页。
  Future<CampusCardHttpSnapshot> openEntryPage(
    Uri entranceUri,
    Duration timeout,
  );

  /// 读取校园卡只读业务页面。
  Future<CampusCardHttpSnapshot> fetchPage(Uri pageUri, Duration timeout);

  /// 查询交易记录；只允许调用明确的交易查询接口。
  Future<CampusCardHttpSnapshot> queryTransactions({
    required Uri queryUri,
    required Map<String, String> fields,
    required Duration timeout,
  });
}

typedef CampusCardOaLoginRefresher =
    Future<AcademicLoginValidationResult> Function();

/// 校园卡余额、状态和交易记录只读查询服务。
class CampusCardService implements CampusCardBalanceClient {
  CampusCardService({
    AcademicCredentialsService? credentialsService,
    CampusNetworkStatusService? campusNetworkStatusService,
    CampusCardGateway? gateway,
    CampusCardOaLoginRefresher? refreshOaLogin,
    Uri? entranceUri,
    Uri? homeUri,
    Uri? transactionIndexUri,
    Uri? transactionQueryUri,
    Duration? timeout,
  }) : _credentialsService =
           credentialsService ?? AcademicCredentialsService.instance,
       _campusNetworkStatusService =
           campusNetworkStatusService ?? CampusNetworkStatusService.instance,
       _gateway = gateway ?? DioCampusCardGateway(),
       _refreshOaLogin =
           refreshOaLogin ??
           AcademicLoginValidationService.instance.validateSavedCredentials,
       entranceUri = entranceUri ?? defaultEntranceUri,
       homeUri = homeUri ?? defaultHomeUri,
       transactionIndexUri = transactionIndexUri ?? defaultTransactionIndexUri,
       transactionQueryUri = transactionQueryUri ?? defaultTransactionQueryUri,
       timeout = timeout ?? const Duration(seconds: 15);

  /// 全局单例。
  static final CampusCardService instance = CampusCardService();

  /// OA 校园卡入口。
  static final Uri defaultEntranceUri = Uri.parse(
    'https://oa.sspu.edu.cn//interface/Entrance.jsp?id=xykxt',
  );

  /// 同类 epay 系统常见余额页；真实页面结构以运行时解析为准。
  static final Uri defaultHomeUri = Uri.parse(
    'https://card.sspu.edu.cn/epay/myepay/index',
  );

  /// 同类 epay 系统常见交易记录页。
  static final Uri defaultTransactionIndexUri = Uri.parse(
    'https://card.sspu.edu.cn/epay/consume/index',
  );

  /// 同类 epay 系统常见交易记录查询接口。
  static final Uri defaultTransactionQueryUri = Uri.parse(
    'https://card.sspu.edu.cn/epay/consume/query',
  );

  /// 校园卡余额默认自动刷新间隔，单位分钟。
  static const int defaultAutoRefreshIntervalMinutes = 30;

  final AcademicCredentialsService _credentialsService;
  final CampusNetworkStatusService _campusNetworkStatusService;
  final CampusCardGateway _gateway;
  final CampusCardOaLoginRefresher _refreshOaLogin;

  /// OA 校园卡入口地址。
  final Uri entranceUri;

  /// 余额候选页。
  final Uri homeUri;

  /// 交易记录候选页。
  final Uri transactionIndexUri;

  /// 交易记录查询候选接口。
  final Uri transactionQueryUri;

  /// 单次网络步骤超时时间。
  final Duration timeout;

  /// 读取校园卡余额自动刷新开关。
  Future<bool> isAutoRefreshEnabled() async {
    return StorageService.getBool(StorageKeys.campusCardAutoRefreshEnabled);
  }

  /// 保存校园卡余额自动刷新开关。
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    await StorageService.setBool(
      StorageKeys.campusCardAutoRefreshEnabled,
      enabled,
    );
  }

  /// 读取校园卡余额自动刷新间隔。
  Future<int> getAutoRefreshIntervalMinutes() async {
    final stored = await StorageService.getInt(
      StorageKeys.campusCardAutoRefreshIntervalMinutes,
    );
    return _normalizeAutoRefreshInterval(
      stored ?? defaultAutoRefreshIntervalMinutes,
    );
  }

  /// 保存校园卡余额自动刷新间隔。
  Future<void> setAutoRefreshIntervalMinutes(int minutes) async {
    await StorageService.setInt(
      StorageKeys.campusCardAutoRefreshIntervalMinutes,
      _normalizeAutoRefreshInterval(minutes),
    );
  }

  @override
  Future<CampusCardQueryResult> fetchCampusCard({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    CampusNetworkStatus? campusStatus;
    try {
      final credentialsStatus = await _credentialsService.getStatus();
      final studentId = credentialsStatus.oaAccount.trim();
      if (studentId.isEmpty) {
        return _buildResult(
          CampusCardQueryStatus.missingOaAccount,
          message: '请先保存学工号',
          detail: '校园卡系统通过 OA/CAS 登录，需使用学工号作为 OA 账号。',
        );
      }

      final oaPassword = await _credentialsService.readSecret(
        AcademicCredentialSecret.oaPassword,
      );
      if (oaPassword == null || oaPassword.isEmpty) {
        return _buildResult(
          CampusCardQueryStatus.missingOaPassword,
          message: '请先保存 OA 账号密码',
          detail: '校园卡查询需要在登录态失效时刷新 OA/CAS 会话。',
        );
      }

      campusStatus = await _campusNetworkStatusService.checkStatus();
      if (!campusStatus.canAccessRestrictedServices) {
        return _buildResult(
          CampusCardQueryStatus.campusNetworkUnavailable,
          message: '校园网 / VPN 不可用，无法访问校园卡系统',
          detail: campusStatus.detail,
          campusNetworkStatus: campusStatus,
        );
      }

      return _fetchWithOaSession(
        startDate: startDate,
        endDate: endDate,
        campusNetworkStatus: campusStatus,
      );
    } on TimeoutException {
      return _buildResult(
        CampusCardQueryStatus.networkError,
        message: '校园卡查询超时',
        detail: '访问 OA / 校园卡查询链路超时。',
        campusNetworkStatus: campusStatus,
      );
    } on DioException catch (error) {
      return _buildResult(
        CampusCardQueryStatus.networkError,
        message: '校园卡查询网络失败',
        detail: HttpService.describeError(error),
        finalUri: error.requestOptions.uri,
        campusNetworkStatus: campusStatus,
      );
    } catch (error) {
      return _buildResult(
        CampusCardQueryStatus.unexpectedError,
        message: '校园卡查询失败',
        detail: '未归类异常：$error',
        campusNetworkStatus: campusStatus,
      );
    }
  }

  Future<CampusCardQueryResult> _fetchWithOaSession({
    DateTime? startDate,
    DateTime? endDate,
    required CampusNetworkStatus campusNetworkStatus,
  }) async {
    var sessionSnapshot = await _credentialsService.readOaLoginSession();
    var entrySnapshot = await _openEntryWithSession(sessionSnapshot);
    if (_isAuthenticationRequired(entrySnapshot)) {
      final loginResult = await _refreshOaLogin();
      if (!loginResult.isSuccess) {
        return _buildResult(
          CampusCardQueryStatus.oaLoginRequired,
          message: 'OA 登录状态不可用，无法查询校园卡',
          detail: loginResult.message,
          finalUri: loginResult.finalUri,
          campusNetworkStatus: campusNetworkStatus,
        );
      }
      sessionSnapshot =
          await _credentialsService.readOaLoginSession() ??
          loginResult.sessionSnapshot;
      entrySnapshot = await _openEntryWithSession(sessionSnapshot);
    }

    if (_isAuthenticationRequired(entrySnapshot)) {
      return _buildResult(
        CampusCardQueryStatus.oaLoginRequired,
        message: 'OA 登录状态不可用，无法进入校园卡系统',
        detail: '校园卡入口仍返回 CAS 登录页，请先在安全设置中验证 OA 登录。',
        finalUri: entrySnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (_isUnavailable(entrySnapshot)) {
      return _buildResult(
        CampusCardQueryStatus.cardSystemUnavailable,
        message: '校园卡系统页面不可用',
        detail: '校园卡入口返回不可用状态或错误页面。',
        finalUri: entrySnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final snapshots = <CampusCardHttpSnapshot>[entrySnapshot];
    await _appendPageIfAvailable(snapshots, homeUri);
    await _appendPageIfAvailable(snapshots, transactionIndexUri);
    final transactionIndexSnapshot = snapshots.lastWhere(
      (snapshot) => snapshot.finalUri.path.contains('/consume/'),
      orElse: () => entrySnapshot,
    );

    if (startDate != null || endDate != null) {
      final querySnapshot = await _queryTransactionsIfAvailable(
        transactionIndexSnapshot,
        startDate: startDate,
        endDate: endDate,
      );
      if (querySnapshot != null) snapshots.add(querySnapshot);
    }

    final snapshot = CampusCardPageParser.parse(snapshots);
    if (snapshot == null) {
      return _buildResult(
        CampusCardQueryStatus.parseFailed,
        message: '未解析到校园卡余额或交易记录',
        detail: '校园卡页面结构与预期不一致，未提取到余额、卡状态或交易记录。',
        finalUri: snapshots.last.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    return _buildResult(
      CampusCardQueryStatus.success,
      message: '校园卡查询成功',
      detail: '已读取校园卡余额、卡状态和交易记录。',
      finalUri: snapshots.last.finalUri,
      campusNetworkStatus: campusNetworkStatus,
      snapshot: snapshot,
    );
  }

  Future<CampusCardHttpSnapshot> _openEntryWithSession(
    AcademicLoginSessionSnapshot? sessionSnapshot,
  ) async {
    await _gateway.resetSession(sessionSnapshot?.cookieHeadersByHost ?? {});
    return _gateway.openEntryPage(entranceUri, timeout);
  }

  Future<void> _appendPageIfAvailable(
    List<CampusCardHttpSnapshot> snapshots,
    Uri pageUri,
  ) async {
    try {
      final snapshot = await _gateway.fetchPage(pageUri, timeout);
      if (_isAuthenticationRequired(snapshot) || _isUnavailable(snapshot)) {
        return;
      }
      snapshots.add(snapshot);
    } on DioException catch (_) {
      return;
    } on TimeoutException catch (_) {
      return;
    }
  }

  Future<CampusCardHttpSnapshot?> _queryTransactionsIfAvailable(
    CampusCardHttpSnapshot transactionIndexSnapshot, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final fields = _buildTransactionQueryFields(
        transactionIndexSnapshot.body,
        startDate: startDate,
        endDate: endDate,
      );
      final snapshot = await _gateway.queryTransactions(
        queryUri: transactionQueryUri,
        fields: fields,
        timeout: timeout,
      );
      if (_isAuthenticationRequired(snapshot) || _isUnavailable(snapshot)) {
        return null;
      }
      return snapshot;
    } on DioException catch (_) {
      return null;
    } on TimeoutException catch (_) {
      return null;
    }
  }

  Map<String, String> _buildTransactionQueryFields(
    String transactionIndexBody, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final csrf = _extractCsrf(transactionIndexBody);
    final fields = {
      'aaxmlrequest': 'true',
      'pageNo': '1',
      'tabNo': '0',
      'pager.offset': '0',
      'tradename': '',
      'starttime': startDate == null ? '' : _formatDate(startDate),
      'endtime': endDate == null ? '' : _formatDate(endDate),
      'timetype': '1',
      '_tradedirect': '',
    };
    if (csrf != null) fields['_csrf'] = csrf;
    return fields;
  }

  String? _extractCsrf(String body) {
    final document = html_parser.parse(body);
    final meta = document.querySelector('meta[name="_csrf"]');
    final token = meta?.attributes['content']?.trim();
    if (token != null && token.isNotEmpty) return token;
    final input = document.querySelector('input[name="_csrf"]');
    final inputToken = input?.attributes['value']?.trim();
    return inputToken == null || inputToken.isEmpty ? null : inputToken;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _isAuthenticationRequired(CampusCardHttpSnapshot snapshot) {
    final host = snapshot.finalUri.host.toLowerCase();
    final path = snapshot.finalUri.path.toLowerCase();
    final normalizedBody = _normalizeText(snapshot.body);
    return (host == 'id.sspu.edu.cn' && path.contains('/cas/login')) ||
        normalizedBody.contains('登录 - 上海第二工业大学') ||
        normalizedBody.contains('j_spring_cas_security_check') ||
        normalizedBody.contains('id="fm1"');
  }

  bool _isUnavailable(CampusCardHttpSnapshot snapshot) {
    final statusCode = snapshot.statusCode;
    if (statusCode != null && statusCode >= 400) return true;
    final normalizedBody = _normalizeText(snapshot.body);
    return normalizedBody.contains('forbidden') ||
        normalizedBody.contains('error') ||
        normalizedBody.contains('错误页面');
  }

  String _normalizeText(String text) {
    return text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  CampusCardQueryResult _buildResult(
    CampusCardQueryStatus status, {
    required String message,
    required String detail,
    Uri? finalUri,
    CampusNetworkStatus? campusNetworkStatus,
    CampusCardSnapshot? snapshot,
  }) {
    return CampusCardQueryResult(
      status: status,
      message: message,
      detail: detail,
      checkedAt: DateTime.now(),
      entranceUri: entranceUri,
      finalUri: finalUri,
      campusNetworkStatus: campusNetworkStatus,
      snapshot: snapshot,
    );
  }

  int _normalizeAutoRefreshInterval(int minutes) {
    return minutes <= 0 ? defaultAutoRefreshIntervalMinutes : minutes;
  }
}

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

/// 校园卡页面解析器；支持普通 HTML 和同类 epay 系统的 XML/CDATA 表格。
class CampusCardPageParser {
  CampusCardPageParser._();

  /// 从多个候选页面中提取余额、状态和交易记录。
  static CampusCardSnapshot? parse(List<CampusCardHttpSnapshot> snapshots) {
    double? balance;
    var status = '';
    final records = <CampusCardTransactionRecord>[];

    for (final snapshot in snapshots) {
      for (final fragment in _extractHtmlFragments(snapshot.body)) {
        final document = html_parser.parse(fragment);
        balance ??= _parseBalance(document);
        if (status.isEmpty) status = _parseStatus(document) ?? '';
        records.addAll(_parseRecords(document));
      }
    }

    final uniqueRecords = _deduplicateRecords(records);
    if (balance == null && status.isEmpty && uniqueRecords.isEmpty) return null;

    return CampusCardSnapshot(
      balance: balance,
      status: status,
      records: List.unmodifiable(uniqueRecords),
      fetchedAt: DateTime.now(),
      sourceUri: snapshots.last.finalUri,
    );
  }

  static List<String> _extractHtmlFragments(String body) {
    final fragments = <String>[body];
    final cdataPattern = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
    for (final match in cdataPattern.allMatches(body)) {
      final fragment = match.group(1);
      if (fragment != null && fragment.trim().isNotEmpty) {
        fragments.add(fragment);
      }
    }
    return fragments;
  }

  static double? _parseBalance(html_dom.Document document) {
    final tableValue = _labelValue(document, const [
      '账户余额',
      '卡余额',
      '当前余额',
      '余额',
    ]);
    final tableBalance = _parseMoney(tableValue ?? '');
    if (tableBalance != null) return tableBalance;

    final text = _cleanText(document.body?.text ?? document.outerHtml);
    final patterns = [
      RegExp(r'(?:账户余额|卡余额|当前余额|余额)[^0-9+\-]{0,16}([+\-]?\d+(?:\.\d{1,2})?)'),
      RegExp(r'([+\-]?\d+(?:\.\d{1,2})?)\s*元[^，。；;]{0,8}(?:余额|账户余额|卡余额)'),
    ];
    for (final pattern in patterns) {
      final value = _parseMoney(pattern.firstMatch(text)?.group(1) ?? '');
      if (value != null) return value;
    }
    return null;
  }

  static String? _parseStatus(html_dom.Document document) {
    final tableValue = _labelValue(document, const ['卡状态', '账户状态', '状态']);
    if (tableValue != null && tableValue.isNotEmpty) return tableValue;

    final text = _cleanText(document.body?.text ?? document.outerHtml);
    final match = RegExp(
      r'(?:卡状态|账户状态|状态)\s*[:：]?\s*([^，。；;\s]{1,12})',
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String? _labelValue(html_dom.Document document, List<String> labels) {
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .toList();
      for (var index = 0; index < cells.length; index++) {
        if (!labels.any(cells[index].contains)) continue;
        if (index + 1 < cells.length && cells[index + 1].isNotEmpty) {
          return cells[index + 1];
        }
      }
    }
    return null;
  }

  static List<CampusCardTransactionRecord> _parseRecords(
    html_dom.Document document,
  ) {
    final records = <CampusCardTransactionRecord>[];
    for (final row in document.querySelectorAll('tr')) {
      final cells = row
          .querySelectorAll('th,td')
          .map((cell) => _cleanText(cell.text))
          .where((cellText) => cellText.isNotEmpty)
          .toList();
      if (cells.length < 3) continue;

      final joinedCells = cells.join(' ');
      final occurredAt = _datePattern.firstMatch(joinedCells)?.group(0);
      if (occurredAt == null || !_hasTransactionHint(joinedCells)) continue;

      final amount = _parseRecordAmount(cells);
      if (amount == null) continue;
      records.add(
        CampusCardTransactionRecord(
          occurredAt: occurredAt,
          amount: amount,
          merchant: _parseMerchant(cells),
          type: _parseType(joinedCells),
          balanceAfter: _parseBalanceAfter(cells),
          rawCells: List.unmodifiable(cells),
        ),
      );
    }
    return records;
  }

  static bool _hasTransactionHint(String text) {
    return text.contains('消费') ||
        text.contains('充值') ||
        text.contains('补助') ||
        text.contains('圈存') ||
        text.contains('退款') ||
        text.contains('交易') ||
        text.contains('扣款') ||
        text.contains('收入') ||
        text.contains('支出');
  }

  static double? _parseRecordAmount(List<String> cells) {
    for (final cell in cells.reversed) {
      if (_datePattern.hasMatch(cell)) continue;
      final amount = _parseMoney(cell);
      if (amount != null && (cell.contains('+') || cell.contains('-'))) {
        return amount;
      }
    }
    for (final cell in cells) {
      if (_datePattern.hasMatch(cell)) continue;
      final amount = _parseMoney(cell);
      if (amount != null) return amount;
    }
    return null;
  }

  static double? _parseBalanceAfter(List<String> cells) {
    for (final cell in cells.reversed) {
      if (_datePattern.hasMatch(cell)) continue;
      if (cell.contains('+') || cell.contains('-')) continue;
      final amount = _parseMoney(cell);
      if (amount != null) return amount;
    }
    return null;
  }

  static String? _parseMerchant(List<String> cells) {
    for (final cell in cells) {
      if (_datePattern.hasMatch(cell)) continue;
      if (_parseMoney(cell) != null) continue;
      if (_parseType(cell) != null) continue;
      if (cell.contains('余额') || cell.contains('状态')) continue;
      return cell;
    }
    return null;
  }

  static String? _parseType(String text) {
    const types = ['消费', '充值', '补助', '圈存', '退款', '扣款', '收入', '支出'];
    for (final type in types) {
      if (text.contains(type)) return type;
    }
    return null;
  }

  static List<CampusCardTransactionRecord> _deduplicateRecords(
    List<CampusCardTransactionRecord> records,
  ) {
    final seen = <String>{};
    final uniqueRecords = <CampusCardTransactionRecord>[];
    for (final record in records) {
      final key =
          '${record.occurredAt}|${record.amount}|${record.rawCells.join('|')}';
      if (!seen.add(key)) continue;
      uniqueRecords.add(record);
    }
    return uniqueRecords;
  }

  static double? _parseMoney(String text) {
    final normalizedText = text.replaceAll(',', '').replaceAll('￥', '');
    final match = RegExp(
      r'([+\-]?\d+(?:\.\d{1,2})?)',
    ).firstMatch(normalizedText);
    return double.tryParse(match?.group(1) ?? '');
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
