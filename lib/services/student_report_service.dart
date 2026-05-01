/*
 * 学工报表服务 — 通过 OA/CAS 登录态只读获取第二课堂学分
 * @Project : SSPU-all-in-one
 * @File : student_report_service.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../models/academic_credentials.dart';
import '../models/academic_login_validation.dart';
import '../models/campus_network_status.dart';
import '../models/student_report.dart';
import 'academic_credentials_service.dart';
import 'academic_login_validation_service.dart';
import 'campus_network_status_service.dart';
import 'http_service.dart';
import 'storage_service.dart';

part 'student_report_gateway.dart';
part 'student_report_page_parser.dart';

/// 教务页依赖的学工报表接口，便于 widget 测试替换。
abstract class StudentReportClient {
  /// 校验学工报表系统登录状态，不读取学分明细。
  Future<StudentReportQueryResult> validateLoginStatus();

  /// 读取第二课堂逐项得分明细。
  Future<StudentReportQueryResult> fetchSecondClassroomCredits();
}

/// 学工报表 HTTP 响应快照。
class StudentReportHttpSnapshot {
  const StudentReportHttpSnapshot({
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

/// 可替换的学工报表系统网关。
abstract class StudentReportGateway {
  /// 重置 Cookie 会话，并注入最近一次 OA/CAS 登录得到的 Cookie。
  Future<void> resetSession(Map<String, String> cookieHeadersByHost);

  /// 打开 OA 学工报表入口并跟随跳转到业务页。
  Future<StudentReportHttpSnapshot> openEntryPage(
    Uri entranceUri,
    Duration timeout,
  );

  /// 读取学工报表只读业务页面。
  Future<StudentReportHttpSnapshot> fetchPage(Uri pageUri, Duration timeout);
}

typedef StudentReportOaLoginRefresher =
    Future<AcademicLoginValidationResult> Function();

/// 学工报表第二课堂学分只读查询服务。
class StudentReportService implements StudentReportClient {
  StudentReportService({
    AcademicCredentialsService? credentialsService,
    CampusNetworkStatusService? campusNetworkStatusService,
    StudentReportGateway? gateway,
    StudentReportOaLoginRefresher? refreshOaLogin,
    Uri? entranceUri,
    Uri? homeUri,
    Duration? timeout,
  }) : _credentialsService =
           credentialsService ?? AcademicCredentialsService.instance,
       _campusNetworkStatusService =
           campusNetworkStatusService ?? CampusNetworkStatusService.instance,
       _gateway = gateway ?? DioStudentReportGateway(),
       _refreshOaLogin =
           refreshOaLogin ??
           AcademicLoginValidationService.instance.validateSavedCredentials,
       entranceUri = entranceUri ?? defaultEntranceUri,
       homeUri = homeUri ?? defaultHomeUri,
       timeout = timeout ?? const Duration(seconds: 15);

  /// 全局单例。
  static final StudentReportService instance = StudentReportService();

  /// OA 学工报表入口。
  static final Uri defaultEntranceUri = Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=xgreport',
  );

  /// 学工报表系统首页 / 查询页。
  static final Uri defaultHomeUri = Uri.parse(
    'https://xgbb.sspu.edu.cn/sharedc/core/home/index.do',
  );

  /// 学工报表默认自动刷新间隔，单位分钟。
  static const int defaultAutoRefreshIntervalMinutes = 30;

  final AcademicCredentialsService _credentialsService;
  final CampusNetworkStatusService _campusNetworkStatusService;
  final StudentReportGateway _gateway;
  final StudentReportOaLoginRefresher _refreshOaLogin;

  /// OA 学工报表入口地址。
  final Uri entranceUri;

  /// 学工报表首页地址。
  final Uri homeUri;

  /// 单次网络步骤超时时间。
  final Duration timeout;

  /// 读取学工报表自动刷新开关。
  Future<bool> isAutoRefreshEnabled() async {
    return StorageService.getBool(StorageKeys.studentReportAutoRefreshEnabled);
  }

  /// 保存学工报表自动刷新开关。
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    await StorageService.setBool(
      StorageKeys.studentReportAutoRefreshEnabled,
      enabled,
    );
  }

  /// 读取学工报表自动刷新间隔。
  Future<int> getAutoRefreshIntervalMinutes() async {
    final stored = await StorageService.getInt(
      StorageKeys.studentReportAutoRefreshIntervalMinutes,
    );
    return _normalizeAutoRefreshInterval(
      stored ?? defaultAutoRefreshIntervalMinutes,
    );
  }

  /// 保存学工报表自动刷新间隔。
  Future<void> setAutoRefreshIntervalMinutes(int minutes) async {
    await StorageService.setInt(
      StorageKeys.studentReportAutoRefreshIntervalMinutes,
      _normalizeAutoRefreshInterval(minutes),
    );
  }

  @override
  Future<StudentReportQueryResult> validateLoginStatus() async {
    return _fetchReport(requireCredits: false);
  }

  @override
  Future<StudentReportQueryResult> fetchSecondClassroomCredits() async {
    return _fetchReport(requireCredits: true);
  }

  Future<StudentReportQueryResult> _fetchReport({
    required bool requireCredits,
  }) async {
    CampusNetworkStatus? campusStatus;
    try {
      final credentialsStatus = await _credentialsService.getStatus();
      final studentId = credentialsStatus.oaAccount.trim();
      if (studentId.isEmpty) {
        return _buildResult(
          StudentReportQueryStatus.missingOaAccount,
          message: '请先保存学工号',
          detail: '学工报表系统通过 OA/CAS 登录，需使用学工号作为 OA 账号。',
        );
      }

      final oaPassword = await _credentialsService.readSecret(
        AcademicCredentialSecret.oaPassword,
      );
      if (oaPassword == null || oaPassword.isEmpty) {
        return _buildResult(
          StudentReportQueryStatus.missingOaPassword,
          message: '请先保存 OA 账号密码',
          detail: '学工报表查询需要在登录态失效时刷新 OA/CAS 会话。',
        );
      }

      campusStatus = await _campusNetworkStatusService.checkStatus();
      if (!campusStatus.canAccessRestrictedServices) {
        return _buildResult(
          StudentReportQueryStatus.campusNetworkUnavailable,
          message: '校园网 / VPN 不可用，无法访问学工报表系统',
          detail: campusStatus.detail,
          campusNetworkStatus: campusStatus,
        );
      }

      return await _fetchWithOaSession(
        requireCredits: requireCredits,
        campusNetworkStatus: campusStatus,
      );
    } on TimeoutException {
      return _buildResult(
        StudentReportQueryStatus.networkError,
        message: '学工报表查询超时',
        detail: '访问 OA / 学工报表链路超时。',
        campusNetworkStatus: campusStatus,
      );
    } on DioException catch (error) {
      return _buildResult(
        StudentReportQueryStatus.networkError,
        message: '学工报表查询网络失败',
        detail: HttpService.describeError(error),
        finalUri: error.requestOptions.uri,
        campusNetworkStatus: campusStatus,
      );
    } catch (error) {
      return _buildResult(
        StudentReportQueryStatus.unexpectedError,
        message: '学工报表查询失败',
        detail: '未归类异常：$error',
        campusNetworkStatus: campusStatus,
      );
    }
  }

  Future<StudentReportQueryResult> _fetchWithOaSession({
    required bool requireCredits,
    required CampusNetworkStatus campusNetworkStatus,
  }) async {
    var sessionSnapshot = await _credentialsService.readOaLoginSession();
    var entrySnapshot = await _openEntryWithSession(sessionSnapshot);
    if (_isAuthenticationRequired(entrySnapshot)) {
      final loginResult = await _refreshOaLogin();
      if (!loginResult.isSuccess) {
        return _buildResult(
          StudentReportQueryStatus.oaLoginRequired,
          message: 'OA 登录状态不可用，无法查询学工报表',
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
        StudentReportQueryStatus.oaLoginRequired,
        message: 'OA 登录状态不可用，无法进入学工报表系统',
        detail: '学工报表入口仍返回 CAS 或本地登录页，请先在安全设置中验证 OA 登录。',
        finalUri: entrySnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (_isUnavailable(entrySnapshot)) {
      return _buildResult(
        StudentReportQueryStatus.reportSystemUnavailable,
        message: '学工报表系统页面不可用',
        detail: '学工报表入口返回不可用状态或错误页面。',
        finalUri: entrySnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    var reportEntrySnapshot = entrySnapshot;
    final reportSystemUri = StudentReportPageNavigator.findReportSystemUri(
      entrySnapshot,
    );
    if (reportSystemUri != null &&
        reportEntrySnapshot.finalUri.host != homeUri.host) {
      reportEntrySnapshot = await _gateway.fetchPage(reportSystemUri, timeout);
    }

    final homeSnapshot = await _fetchHomePage(reportEntrySnapshot);
    if (_isAuthenticationRequired(homeSnapshot)) {
      return _buildResult(
        StudentReportQueryStatus.oaLoginRequired,
        message: '学工报表登录状态不可用',
        detail: '学工报表首页仍返回本地登录页，未获得可复用业务会话。',
        finalUri: homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (_isUnavailable(homeSnapshot)) {
      return _buildResult(
        StudentReportQueryStatus.reportSystemUnavailable,
        message: '学工报表首页不可用',
        detail: '无法打开学工报表首页。',
        finalUri: homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (!requireCredits) {
      return _buildResult(
        StudentReportQueryStatus.success,
        message: '学工报表登录校验通过',
        detail: '已通过 OA 入口进入学工报表系统，未读取或修改业务数据。',
        finalUri: homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final snapshots = <StudentReportHttpSnapshot>[homeSnapshot];
    final targetUri = StudentReportPageNavigator.findSecondClassroomUri(
      homeSnapshot,
    );
    if (targetUri != null) {
      final secondClassroomSnapshot = await _gateway.fetchPage(
        targetUri,
        timeout,
      );
      if (!_isAuthenticationRequired(secondClassroomSnapshot) &&
          !_isUnavailable(secondClassroomSnapshot)) {
        snapshots.add(secondClassroomSnapshot);
      }
    }

    final summary = StudentReportPageParser.parse(snapshots);
    if (summary == null) {
      final status = targetUri == null
          ? StudentReportQueryStatus.secondClassroomEntryUnavailable
          : StudentReportQueryStatus.parseFailed;
      return _buildResult(
        status,
        message: targetUri == null ? '未找到第二课堂学分查询入口' : '未解析到第二课堂学分',
        detail: targetUri == null
            ? '学工报表首页未出现“第二课堂学分查询”链接、按钮或可解析跳转。'
            : '第二课堂学分页面结构与预期不一致，未提取到学分类别或明细。',
        finalUri: snapshots.last.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    return _buildResult(
      StudentReportQueryStatus.success,
      message: '第二课堂学分查询成功',
      detail: '已读取第二课堂逐项得分明细，未将单项分值合并为总学分。',
      finalUri: snapshots.last.finalUri,
      campusNetworkStatus: campusNetworkStatus,
      summary: summary,
    );
  }

  Future<StudentReportHttpSnapshot> _openEntryWithSession(
    AcademicLoginSessionSnapshot? sessionSnapshot,
  ) async {
    await _gateway.resetSession(sessionSnapshot?.cookieHeadersByHost ?? {});
    return _gateway.openEntryPage(entranceUri, timeout);
  }

  Future<StudentReportHttpSnapshot> _fetchHomePage(
    StudentReportHttpSnapshot entrySnapshot,
  ) async {
    if (entrySnapshot.finalUri.host == homeUri.host &&
        entrySnapshot.body.contains('第二课堂')) {
      return entrySnapshot;
    }
    return _gateway.fetchPage(homeUri, timeout);
  }

  bool _isAuthenticationRequired(StudentReportHttpSnapshot snapshot) {
    final host = snapshot.finalUri.host.toLowerCase();
    final path = snapshot.finalUri.path.toLowerCase();
    final normalizedBody = _normalizeText(snapshot.body);
    return (host == 'id.sspu.edu.cn' && path.contains('/cas/login')) ||
        path.contains('/core/login/') ||
        normalizedBody.contains('登录 - 上海第二工业大学') ||
        normalizedBody.contains('请输入用户名') ||
        normalizedBody.contains('name="userName"') ||
        normalizedBody.contains('name="userPwd"') ||
        normalizedBody.contains('name="verifycode"') ||
        normalizedBody.contains('/sharedc/core/login/index.do') ||
        normalizedBody.contains('id="fm1"');
  }

  bool _isUnavailable(StudentReportHttpSnapshot snapshot) {
    final statusCode = snapshot.statusCode;
    if (statusCode != null && statusCode >= 400) return true;
    final document = html_parser.parse(snapshot.body);
    final titleText = _normalizeText(
      document.querySelector('title')?.text ?? '',
    );
    final visibleText = _normalizeText(document.body?.text ?? snapshot.body);
    final lowerVisibleText = visibleText.toLowerCase();
    final lowerTitleText = titleText.toLowerCase();
    return lowerTitleText.contains('forbidden') ||
        lowerTitleText.contains('error') ||
        titleText.contains('错误页面') ||
        lowerVisibleText.contains('forbidden') ||
        visibleText.contains('错误页面') ||
        visibleText.contains('系统异常') ||
        visibleText.contains('服务不可用');
  }

  String _normalizeText(String text) {
    return text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  StudentReportQueryResult _buildResult(
    StudentReportQueryStatus status, {
    required String message,
    required String detail,
    Uri? finalUri,
    CampusNetworkStatus? campusNetworkStatus,
    SecondClassroomCreditSummary? summary,
  }) {
    return StudentReportQueryResult(
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
