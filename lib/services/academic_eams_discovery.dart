/*
 * 本专科教务发现与分类逻辑 — 处理首页识别、只读菜单探测和结果分类
 * @Project : SSPU-all-in-one
 * @File : academic_eams_discovery.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

extension _AcademicEamsDiscovery on AcademicEamsService {
  Future<AcademicEamsHttpSnapshot> _openEntryWithSession(
    AcademicLoginSessionSnapshot? sessionSnapshot,
  ) async {
    await _gateway.resetSession(sessionSnapshot?.cookieHeadersByHost ?? {});
    return _gateway.openEntryPage(entranceUri, timeout);
  }

  Future<AcademicEamsHttpSnapshot> _ensureHomeSnapshot(
    AcademicEamsHttpSnapshot entrySnapshot,
  ) async {
    if (_isHomePage(entrySnapshot)) return entrySnapshot;

    final jumpUris = _findPossibleJumpUris(entrySnapshot);
    for (final jumpUri in jumpUris) {
      final snapshot = await _gateway.fetchPage(jumpUri, timeout);
      if (_isHomePage(snapshot) || snapshot.finalUri.host == homeUri.host) {
        return snapshot;
      }
    }

    final fallbackSnapshot = await _gateway.fetchPage(homeUri, timeout);
    if (_isHomePage(fallbackSnapshot) ||
        fallbackSnapshot.finalUri.host == homeUri.host) {
      return fallbackSnapshot;
    }
    return fallbackSnapshot;
  }

  Future<Map<_AcademicFeature, Uri>> _discoverFeatureUris(
    AcademicEamsHttpSnapshot homeSnapshot,
  ) async {
    if (_discoveredFeatureUris != null) return _discoveredFeatureUris!;

    final entries = <_AcademicReadonlyEntry>[
      ..._extractReadonlyEntries(homeSnapshot),
    ];
    var discoveryHadFailure = false;
    for (var menuId = 1; menuId <= 60; menuId++) {
      try {
        final snapshot = await _gateway.fetchPage(
          submenuBaseUri.replace(queryParameters: {'menu.id': '$menuId'}),
          timeout,
        );
        if (_isAuthenticationRequired(snapshot) || _isUnavailable(snapshot)) {
          continue;
        }
        entries.addAll(_extractReadonlyEntries(snapshot));
      } on DioException catch (_) {
        discoveryHadFailure = true;
        continue;
      } on TimeoutException catch (_) {
        discoveryHadFailure = true;
        continue;
      }
    }

    final featureUris = <_AcademicFeature, Uri>{};
    for (final feature in _AcademicFeature.values) {
      final matchedEntry = entries.firstWhere(
        (entry) => _matchesFeature(feature, entry),
        orElse: () => _AcademicReadonlyEntry.empty(),
      );
      if (!matchedEntry.isEmpty) featureUris[feature] = matchedEntry.uri;
    }

    final fallbackCandidates = <_AcademicFeature, String>{
      _AcademicFeature.courseTable: 'courseTableForStd.action',
      _AcademicFeature.gradeCurrent: 'teach/grade/course/person.action',
      _AcademicFeature.gradeHistory:
          'teach/grade/course/person!historyCourseGrade.action?projectType=MAJOR',
      _AcademicFeature.programPlan: 'teach/program/student/myPlan.action',
      _AcademicFeature.exams: 'stdExamTable.action',
      _AcademicFeature.courseOfferingsEntry: 'publicSearch.action',
    };
    for (final entry in fallbackCandidates.entries) {
      if (featureUris.containsKey(entry.key)) continue;
      if (await _verifyReadonlyPage(homeUri.resolve(entry.value))) {
        featureUris[entry.key] = homeUri.resolve(entry.value);
      }
    }

    final discoveredUris = Map<_AcademicFeature, Uri>.unmodifiable(featureUris);
    if (!discoveryHadFailure) {
      _discoveredFeatureUris = discoveredUris;
    }
    return discoveredUris;
  }

  Future<bool> _verifyReadonlyPage(Uri candidateUri) async {
    try {
      final snapshot = await _gateway.fetchPage(candidateUri, timeout);
      return !_isAuthenticationRequired(snapshot) && !_isUnavailable(snapshot);
    } on DioException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  bool _matchesFeature(_AcademicFeature feature, _AcademicReadonlyEntry entry) {
    final label = entry.label.replaceAll(RegExp(r'\s+'), '');
    final path = entry.uri.path.toLowerCase();
    return switch (feature) {
      _AcademicFeature.courseTable =>
        path.contains('coursetableforstd.action') || label.contains('课表'),
      _AcademicFeature.gradeCurrent =>
        path.contains('/teach/grade/course/person.action') &&
                !path.contains('historycoursegrade') ||
            label.contains('成绩查询'),
      _AcademicFeature.gradeHistory =>
        path.contains('historycoursegrade') || label.contains('历史成绩'),
      _AcademicFeature.programPlan =>
        path.contains('/teach/program/student/myplan.action') ||
            label.contains('培养计划'),
      _AcademicFeature.exams =>
        path.contains('stdexamtable.action') || label.contains('考试'),
      _AcademicFeature.courseOfferingsEntry =>
        path.contains('publicsearch.action') || label.contains('开课'),
      _AcademicFeature.freeClassroomEntry =>
        label.contains('空闲教室') ||
            path.contains('empty') ||
            path.contains('free') ||
            path.contains('classroom'),
    };
  }

  bool _isAuthenticationRequired(AcademicEamsHttpSnapshot snapshot) {
    final host = snapshot.finalUri.host.toLowerCase();
    final path = snapshot.finalUri.path.toLowerCase();
    final normalizedBody = _normalizeText(snapshot.body).toLowerCase();
    return (host == 'id.sspu.edu.cn' && path.contains('/cas/login')) ||
        (host == 'jx.sspu.edu.cn' && path.contains('/eams/login.action')) ||
        normalizedBody.contains('统一身份认证') ||
        normalizedBody.contains('name="username"') &&
            normalizedBody.contains('name="password"') &&
            path.contains('/login.action');
  }

  bool _isHomePage(AcademicEamsHttpSnapshot snapshot) {
    final path = snapshot.finalUri.path.toLowerCase();
    if (snapshot.finalUri.host.toLowerCase() != homeUri.host.toLowerCase()) {
      return false;
    }
    final normalizedBody = _normalizeText(snapshot.body);
    return path.contains('home!index.action') ||
        normalizedBody.contains('EAMS 3.0.0') ||
        normalizedBody.contains('欢迎使用') ||
        normalizedBody.contains('个人课表');
  }

  bool _isUnavailable(AcademicEamsHttpSnapshot snapshot) {
    final statusCode = snapshot.statusCode;
    if (statusCode != null && statusCode >= 400) return true;
    final document = html_parser.parse(snapshot.body);
    final titleText = _normalizeText(
      document.querySelector('title')?.text ?? '',
    );
    final visibleText = _normalizeText(document.body?.text ?? snapshot.body);
    final lowerTitleText = titleText.toLowerCase();
    final lowerVisibleText = visibleText.toLowerCase();
    return lowerTitleText.contains('forbidden') ||
        lowerTitleText.contains('error') ||
        titleText.contains('错误页面') ||
        visibleText.contains('系统异常') ||
        lowerVisibleText.contains('service unavailable') ||
        lowerVisibleText.contains('forbidden');
  }

  String _normalizeText(String text) {
    return text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  String _missingFeatureWarning(_AcademicFeature feature) {
    return '未识别到${_featureLabel(feature)}入口';
  }

  String _featureLabel(_AcademicFeature feature) {
    return switch (feature) {
      _AcademicFeature.courseTable => '课表',
      _AcademicFeature.gradeCurrent => '当前成绩',
      _AcademicFeature.gradeHistory => '历史成绩',
      _AcademicFeature.programPlan => '培养计划',
      _AcademicFeature.exams => '考试安排',
      _AcademicFeature.courseOfferingsEntry => '开课检索',
      _AcademicFeature.freeClassroomEntry => '空闲教室',
    };
  }

  AcademicEamsQueryResult _buildResult(
    AcademicEamsQueryStatus status, {
    required String message,
    required String detail,
    Uri? finalUri,
    CampusNetworkStatus? campusNetworkStatus,
    AcademicEamsSnapshot? snapshot,
    AcademicCourseOfferingSearchResult? courseOfferings,
    AcademicFreeClassroomSearchResult? freeClassrooms,
  }) {
    return AcademicEamsQueryResult(
      status: status,
      message: message,
      detail: detail,
      checkedAt: DateTime.now(),
      entranceUri: entranceUri,
      finalUri: finalUri,
      campusNetworkStatus: campusNetworkStatus,
      snapshot: snapshot,
      courseOfferings: courseOfferings,
      freeClassrooms: freeClassrooms,
    );
  }

  int _normalizeAutoRefreshInterval(int minutes) {
    return minutes <= 0
        ? AcademicEamsService.defaultAutoRefreshIntervalMinutes
        : minutes;
  }
}
