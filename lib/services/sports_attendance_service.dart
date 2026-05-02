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

part 'sports_attendance_gateway.dart';
part 'sports_attendance_page_parser.dart';
part 'sports_attendance_support.dart';

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

      return await _fetchWithCredentials(
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
