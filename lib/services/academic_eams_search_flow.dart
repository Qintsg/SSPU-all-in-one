/*
 * 本专科教务只读搜索流程 — 处理开课检索与空闲教室查询
 * @Project : SSPU-all-in-one
 * @File : academic_eams_search_flow.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

extension _AcademicEamsSearchFlow on AcademicEamsService {
  Future<AcademicEamsQueryResult> _searchReadonlyPage({
    required _AcademicFeature entryFeature,
    required _AcademicReadonlyQueryForm? Function(AcademicEamsHttpSnapshot)
    formParser,
    required Future<AcademicEamsHttpSnapshot> Function(
      _AcademicReadonlyQueryForm form,
    )
    searchExecutor,
    required AcademicEamsQueryResult Function(
      AcademicEamsHttpSnapshot snapshot,
      CampusNetworkStatus campusStatus,
    )
    resultBuilder,
  }) async {
    CampusNetworkStatus? campusStatus;
    try {
      final credentialsStatus = await _credentialsService.getStatus();
      final oaAccount = credentialsStatus.oaAccount.trim();
      if (oaAccount.isEmpty) {
        return _buildResult(
          AcademicEamsQueryStatus.missingOaAccount,
          message: '请先保存学工号',
          detail: '本专科教务系统通过 OA/CAS 登录，需使用学工号作为 OA 账号。',
        );
      }

      final oaPassword = await _credentialsService.readSecret(
        AcademicCredentialSecret.oaPassword,
      );
      if (oaPassword == null || oaPassword.isEmpty) {
        return _buildResult(
          AcademicEamsQueryStatus.missingOaPassword,
          message: '请先保存 OA 账号密码',
          detail: '本专科教务查询需要在登录态失效时刷新 OA/CAS 会话。',
        );
      }

      campusStatus = await _campusNetworkStatusService.checkStatus();
      if (!campusStatus.canAccessRestrictedServices) {
        return _buildResult(
          AcademicEamsQueryStatus.campusNetworkUnavailable,
          message: '校园网 / VPN 不可用，无法访问本专科教务系统',
          detail: campusStatus.detail,
          campusNetworkStatus: campusStatus,
        );
      }

      var sessionSnapshot = await _credentialsService.readOaLoginSession();
      var entrySnapshot = await _openEntryWithSession(sessionSnapshot);
      if (_isAuthenticationRequired(entrySnapshot)) {
        final loginResult = await _refreshOaLogin();
        if (!loginResult.isSuccess) {
          return _buildResult(
            AcademicEamsQueryStatus.oaLoginRequired,
            message: 'OA 登录状态不可用，无法访问本专科教务',
            detail: loginResult.message,
            finalUri: loginResult.finalUri,
            campusNetworkStatus: campusStatus,
          );
        }
        sessionSnapshot =
            await _credentialsService.readOaLoginSession() ??
            loginResult.sessionSnapshot;
        entrySnapshot = await _openEntryWithSession(sessionSnapshot);
      }

      final homeSnapshot = await _ensureHomeSnapshot(entrySnapshot);
      if (_isAuthenticationRequired(homeSnapshot)) {
        return _buildResult(
          AcademicEamsQueryStatus.oaLoginRequired,
          message: '本专科教务登录状态不可用',
          detail: 'EAMS 入口仍返回 CAS 或教务登录页，请先在安全设置中验证 OA 登录。',
          finalUri: homeSnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }
      if (_isUnavailable(homeSnapshot)) {
        return _buildResult(
          AcademicEamsQueryStatus.systemUnavailable,
          message: '本专科教务系统页面不可用',
          detail: 'EAMS 首页返回不可用状态或错误页面。',
          finalUri: homeSnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }

      final featureUris = await _discoverFeatureUris(homeSnapshot);
      final entryUri = featureUris[entryFeature];
      if (entryUri == null) {
        return _buildResult(
          AcademicEamsQueryStatus.readOnlyEntryUnavailable,
          message: '未识别到对应只读查询入口',
          detail: '当前 EAMS 菜单中没有可验证的只读入口，无法安全执行查询。',
          finalUri: homeSnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }

      final searchEntrySnapshot = await _gateway.fetchPage(entryUri, timeout);
      if (_isAuthenticationRequired(searchEntrySnapshot)) {
        return _buildResult(
          AcademicEamsQueryStatus.oaLoginRequired,
          message: '本专科教务登录状态已失效',
          detail: '进入只读查询页时返回了教务登录页，请先重新验证 OA 登录。',
          finalUri: searchEntrySnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }
      if (_isUnavailable(searchEntrySnapshot)) {
        return _buildResult(
          AcademicEamsQueryStatus.systemUnavailable,
          message: '本专科教务查询页不可用',
          detail: '查询页返回不可用状态或错误页面。',
          finalUri: searchEntrySnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }

      final queryForm = formParser(searchEntrySnapshot);
      if (queryForm == null) {
        return _buildResult(
          AcademicEamsQueryStatus.queryFormUnavailable,
          message: '未识别到只读查询表单',
          detail: '页面可访问，但没有解析到可安全提交的只读查询字段。',
          finalUri: searchEntrySnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }

      final resultSnapshot = await searchExecutor(queryForm);
      if (_isAuthenticationRequired(resultSnapshot)) {
        return _buildResult(
          AcademicEamsQueryStatus.oaLoginRequired,
          message: '本专科教务登录状态已失效',
          detail: '只读查询提交后返回了教务登录页，请重新验证 OA 登录。',
          finalUri: resultSnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }
      if (_isUnavailable(resultSnapshot)) {
        return _buildResult(
          AcademicEamsQueryStatus.systemUnavailable,
          message: '本专科教务查询结果页不可用',
          detail: '查询结果页返回不可用状态或错误页面。',
          finalUri: resultSnapshot.finalUri,
          campusNetworkStatus: campusStatus,
        );
      }
      return resultBuilder(resultSnapshot, campusStatus);
    } on TimeoutException {
      return _buildResult(
        AcademicEamsQueryStatus.networkError,
        message: '本专科教务查询超时',
        detail: '访问 OA / EAMS 链路超时。',
        campusNetworkStatus: campusStatus,
      );
    } on DioException catch (error) {
      return _buildResult(
        AcademicEamsQueryStatus.networkError,
        message: '本专科教务查询网络失败',
        detail: HttpService.describeError(error),
        finalUri: error.requestOptions.uri,
        campusNetworkStatus: campusStatus,
      );
    } catch (error) {
      return _buildResult(
        AcademicEamsQueryStatus.unexpectedError,
        message: '本专科教务查询失败',
        detail: '未归类异常：$error',
        campusNetworkStatus: campusStatus,
      );
    }
  }
}
