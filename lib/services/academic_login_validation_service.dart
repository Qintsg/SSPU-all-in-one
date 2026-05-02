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

part 'academic_login_crypto.dart';
part 'academic_login_form.dart';
part 'academic_login_gateway.dart';

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
