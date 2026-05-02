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

part 'campus_card_gateway.dart';
part 'campus_card_flow.dart';
part 'campus_card_page_parser.dart';

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
    'http://card.sspu.edu.cn/epay/myepay/index',
  );

  /// 同类 epay 系统常见交易记录页。
  static final Uri defaultTransactionIndexUri = Uri.parse(
    'http://card.sspu.edu.cn/epay/consume/index',
  );

  /// 同类 epay 系统常见交易记录查询接口。
  static final Uri defaultTransactionQueryUri = Uri.parse(
    'http://card.sspu.edu.cn/epay/consume/query',
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

      return await _fetchWithOaSession(
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
    entrySnapshot = await _resolveBusinessEntrySnapshot(entrySnapshot);

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
}
