/*
 * 本专科教务摘要流程 — 处理凭据校验、OA 会话刷新与概览聚合
 * @Project : SSPU-all-in-one
 * @File : academic_eams_overview_flow.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

extension _AcademicEamsOverviewFlow on AcademicEamsService {
  Future<AcademicEamsQueryResult> _fetchSnapshot(
    _AcademicFetchScope scope,
  ) async {
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

      return await _fetchWithOaSession(scope, campusStatus);
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

  Future<AcademicEamsQueryResult> _fetchWithOaSession(
    _AcademicFetchScope scope,
    CampusNetworkStatus campusNetworkStatus,
  ) async {
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
          campusNetworkStatus: campusNetworkStatus,
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
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (_isUnavailable(homeSnapshot)) {
      return _buildResult(
        AcademicEamsQueryStatus.systemUnavailable,
        message: '本专科教务系统页面不可用',
        detail: 'EAMS 首页返回不可用状态或错误页面。',
        finalUri: homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final featureUris = await _discoverFeatureUris(homeSnapshot);
    final featureSnapshots = <_AcademicFeature, AcademicEamsHttpSnapshot>{};
    final warnings = <String>[];

    final rawCourseSnapshot = await _fetchRequiredFeature(
      feature: _AcademicFeature.courseTable,
      featureUris: featureUris,
      warnings: warnings,
    );
    final courseSnapshot = await _resolveFeatureSnapshot(
      _AcademicFeature.courseTable,
      rawCourseSnapshot,
      warnings,
    );
    if (scope == _AcademicFetchScope.courseTableOnly &&
        courseSnapshot == null) {
      return _buildResult(
        AcademicEamsQueryStatus.readOnlyEntryUnavailable,
        message: '未识别到本专科教务课表入口',
        detail: warnings.isEmpty ? 'EAMS 只读菜单中没有可验证的课表入口。' : warnings.join('；'),
        finalUri: homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }
    if (courseSnapshot != null) {
      featureSnapshots[_AcademicFeature.courseTable] = courseSnapshot;
    }

    if (scope == _AcademicFetchScope.overview) {
      await _fetchOptionalFeature(
        _AcademicFeature.gradeCurrent,
        featureUris,
        featureSnapshots,
        warnings,
      );
      await _fetchOptionalFeature(
        _AcademicFeature.gradeHistory,
        featureUris,
        featureSnapshots,
        warnings,
      );
      await _fetchOptionalFeature(
        _AcademicFeature.programPlan,
        featureUris,
        featureSnapshots,
        warnings,
      );
      await _fetchOptionalFeature(
        _AcademicFeature.exams,
        featureUris,
        featureSnapshots,
        warnings,
      );
      await _fetchOptionalFeature(
        _AcademicFeature.courseOfferingsEntry,
        featureUris,
        featureSnapshots,
        warnings,
      );
      await _fetchOptionalFeature(
        _AcademicFeature.freeClassroomEntry,
        featureUris,
        featureSnapshots,
        warnings,
      );
      await _resolveOptionalFeatureSnapshots(featureSnapshots, warnings);
    }

    final allSnapshots = [homeSnapshot, ...featureSnapshots.values];
    final profile = _parseProfile(allSnapshots);
    final courseTable = courseSnapshot == null
        ? null
        : _parseCourseTable(courseSnapshot);
    final grades = _parseGrades(
      featureSnapshots[_AcademicFeature.gradeCurrent],
      featureSnapshots[_AcademicFeature.gradeHistory],
    );
    final programPlan = _parseProgramPlan(
      featureSnapshots[_AcademicFeature.programPlan],
    );
    final exams = _parseExams(featureSnapshots[_AcademicFeature.exams]);
    final courseOfferingsPreview = _parseCourseOfferings(
      featureSnapshots[_AcademicFeature.courseOfferingsEntry],
      const AcademicCourseOfferingSearchCriteria(),
    );
    final freeClassroomsPreview = _parseFreeClassrooms(
      featureSnapshots[_AcademicFeature.freeClassroomEntry],
      const AcademicFreeClassroomSearchCriteria(),
    );
    final completion = _deriveProgramCompletion(programPlan, grades);

    if (scope == _AcademicFetchScope.courseTableOnly && courseTable == null) {
      return _buildResult(
        AcademicEamsQueryStatus.parseFailed,
        message: '未解析到本专科教务课表',
        detail: '课表页面结构与预期不一致，未提取到课程、时间、地点或教师信息。',
        finalUri: courseSnapshot?.finalUri ?? homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final snapshot = AcademicEamsSnapshot(
      fetchedAt: DateTime.now(),
      sourceUri:
          featureSnapshots[_AcademicFeature.courseTable]?.finalUri ??
          homeSnapshot.finalUri,
      warnings: List.unmodifiable(warnings),
      hasCourseOfferingEntry: featureUris.containsKey(
        _AcademicFeature.courseOfferingsEntry,
      ),
      hasFreeClassroomEntry: featureUris.containsKey(
        _AcademicFeature.freeClassroomEntry,
      ),
      profile: profile,
      courseTable: courseTable,
      grades: grades,
      programPlan: programPlan,
      programCompletion: completion,
      exams: exams,
      courseOfferingsPreview: courseOfferingsPreview,
      freeClassroomsPreview: freeClassroomsPreview,
    );

    if (!snapshot.hasAnyData) {
      return _buildResult(
        AcademicEamsQueryStatus.parseFailed,
        message: '未解析到本专科教务数据',
        detail: warnings.isEmpty
            ? 'EAMS 页面可访问，但未解析到个人信息、课表、成绩、考试或培养计划等只读数据。'
            : warnings.join('；'),
        finalUri: homeSnapshot.finalUri,
        campusNetworkStatus: campusNetworkStatus,
      );
    }

    final status = warnings.isEmpty
        ? AcademicEamsQueryStatus.success
        : AcademicEamsQueryStatus.partialSuccess;
    return _buildResult(
      status,
      message: status == AcademicEamsQueryStatus.success
          ? '本专科教务只读查询成功'
          : '本专科教务部分数据已读取',
      detail: status == AcademicEamsQueryStatus.success
          ? '已读取课表、成绩、考试、培养计划等只读数据。'
          : warnings.join('；'),
      finalUri: homeSnapshot.finalUri,
      campusNetworkStatus: campusNetworkStatus,
      snapshot: snapshot,
    );
  }

  Future<AcademicEamsHttpSnapshot?> _fetchRequiredFeature({
    required _AcademicFeature feature,
    required Map<_AcademicFeature, Uri> featureUris,
    required List<String> warnings,
  }) async {
    final uri = featureUris[feature];
    if (uri == null) {
      warnings.add(_missingFeatureWarning(feature));
      return null;
    }

    final snapshot = await _gateway.fetchPage(uri, timeout);
    if (_isAuthenticationRequired(snapshot)) {
      warnings.add('${_featureLabel(feature)}返回了登录页');
      return null;
    }
    if (_isUnavailable(snapshot)) {
      warnings.add('${_featureLabel(feature)}页面不可用');
      return null;
    }
    return snapshot;
  }

  Future<void> _fetchOptionalFeature(
    _AcademicFeature feature,
    Map<_AcademicFeature, Uri> featureUris,
    Map<_AcademicFeature, AcademicEamsHttpSnapshot> featureSnapshots,
    List<String> warnings,
  ) async {
    final uri = featureUris[feature];
    if (uri == null) {
      warnings.add(_missingFeatureWarning(feature));
      return;
    }
    try {
      final snapshot = await _gateway.fetchPage(uri, timeout);
      if (_isAuthenticationRequired(snapshot)) {
        warnings.add('${_featureLabel(feature)}返回了登录页');
        return;
      }
      if (_isUnavailable(snapshot)) {
        warnings.add('${_featureLabel(feature)}页面不可用');
        return;
      }
      featureSnapshots[feature] = snapshot;
    } on TimeoutException {
      warnings.add('${_featureLabel(feature)}读取超时');
    } on DioException {
      warnings.add('${_featureLabel(feature)}读取失败');
    }
  }
}
