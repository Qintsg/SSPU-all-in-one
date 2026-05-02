/*
 * 本专科教务壳页跟随逻辑 — 从 EAMS 壳页继续读取真实课表、成绩和考试内容
 * @Project : SSPU-all-in-one
 * @File : academic_eams_shell_followups.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'academic_eams_service.dart';

extension _AcademicEamsShellFollowups on AcademicEamsService {
  Future<void> _resolveOptionalFeatureSnapshots(
    Map<_AcademicFeature, AcademicEamsHttpSnapshot> featureSnapshots,
    List<String> warnings,
  ) async {
    for (final feature in [
      _AcademicFeature.gradeCurrent,
      _AcademicFeature.gradeHistory,
      _AcademicFeature.exams,
      _AcademicFeature.programPlan,
    ]) {
      final resolvedSnapshot = await _resolveFeatureSnapshot(
        feature,
        featureSnapshots[feature],
        warnings,
      );
      if (resolvedSnapshot != null) {
        featureSnapshots[feature] = resolvedSnapshot;
      } else {
        featureSnapshots.remove(feature);
      }
    }
  }

  Future<AcademicEamsHttpSnapshot?> _resolveFeatureSnapshot(
    _AcademicFeature feature,
    AcademicEamsHttpSnapshot? snapshot,
    List<String> warnings,
  ) async {
    if (snapshot == null) return null;
    return switch (feature) {
      _AcademicFeature.courseTable => _resolveCourseTableSnapshot(
        snapshot,
        warnings,
      ),
      _AcademicFeature.gradeCurrent => _resolveCurrentGradeSnapshot(
        snapshot,
        warnings,
      ),
      _AcademicFeature.exams => _resolveExamSnapshot(snapshot, warnings),
      _AcademicFeature.programPlan => _resolveProgramPlanSnapshot(
        snapshot,
        warnings,
      ),
      _ => snapshot,
    };
  }

  Future<AcademicEamsHttpSnapshot> _resolveCourseTableSnapshot(
    AcademicEamsHttpSnapshot shellSnapshot,
    List<String> warnings,
  ) async {
    final actionUri = _extractRelativeActionUri(shellSnapshot, const [
      'courseTableForStd!courseTable.action',
    ]);
    if (actionUri == null) return shellSnapshot;

    final form = _parseShellForm(shellSnapshot, '#courseTableForm');
    if (form == null) {
      warnings.add('课表壳页缺少可提交表单，已保留入口页结果');
      return shellSnapshot;
    }

    final fields = Map<String, String>.from(form.defaultFields);
    final kind = (fields['setting.kind'] ?? '').trim().isEmpty
        ? 'std'
        : (fields['setting.kind'] ?? '');
    fields['setting.kind'] = kind;
    final idsValue = _extractRegexValue(
      shellSnapshot.body,
      RegExp(
        kind == 'std'
            ? r'bg\.form\.addInput\(form,"ids","([^"]+)"\)'
            : r'bg\.form\.addInput\(form,"ids","([^"]+)"\)',
      ),
    );
    if (idsValue != null && idsValue.isNotEmpty) fields['ids'] = idsValue;
    fields['startWeek'] = (fields['startWeek'] ?? '').trim().isEmpty
        ? '1'
        : (fields['startWeek'] ?? '');
    fields['semester.id'] = _resolveAcademicSemesterId(shellSnapshot.body);

    final resultSnapshot = await _gateway.submitForm(
      formUri: actionUri,
      method: form.method,
      fields: fields,
      timeout: timeout,
    );
    return resultSnapshot;
  }

  Future<AcademicEamsHttpSnapshot> _resolveCurrentGradeSnapshot(
    AcademicEamsHttpSnapshot shellSnapshot,
    List<String> warnings,
  ) async {
    final searchUri = _extractRelativeActionUri(shellSnapshot, const [
      '/eams/teach/grade/course/person!search.action',
    ]);
    if (searchUri == null) return shellSnapshot;

    try {
      return await _gateway.fetchPage(searchUri, timeout);
    } on DioException {
      warnings.add('当前成绩壳页的查询 action 读取失败，已保留入口页结果');
      return shellSnapshot;
    } on TimeoutException {
      warnings.add('当前成绩壳页的查询 action 读取超时，已保留入口页结果');
      return shellSnapshot;
    }
  }

  Future<AcademicEamsHttpSnapshot> _resolveExamSnapshot(
    AcademicEamsHttpSnapshot shellSnapshot,
    List<String> warnings,
  ) async {
    final actionUri = _extractRelativeActionUri(shellSnapshot, const [
      'stdExamTable!examTable.action',
    ]);
    if (actionUri == null) return shellSnapshot;

    final semesterId = _resolveAcademicSemesterId(shellSnapshot.body);
    final examTypeId = _extractExamTypeId(shellSnapshot.body);
    final queryUri = actionUri.replace(
      queryParameters: {
        ...actionUri.queryParameters,
        'semester.id': semesterId,
        'examType.id': examTypeId,
      },
    );

    try {
      return await _gateway.fetchPage(queryUri, timeout);
    } on DioException {
      warnings.add('考试壳页的 examTable action 读取失败，已保留入口页结果');
      return shellSnapshot;
    } on TimeoutException {
      warnings.add('考试壳页的 examTable action 读取超时，已保留入口页结果');
      return shellSnapshot;
    }
  }

  Future<AcademicEamsHttpSnapshot?> _resolveProgramPlanSnapshot(
    AcademicEamsHttpSnapshot shellSnapshot,
    List<String> warnings,
  ) async {
    if (_isUnavailable(shellSnapshot)) {
      warnings.add('培养计划页面当前无访问权限');
      return null;
    }
    return shellSnapshot;
  }

  _AcademicReadonlyQueryForm? _parseShellForm(
    AcademicEamsHttpSnapshot snapshot,
    String selector,
  ) {
    final document = html_parser.parse(snapshot.body);
    final form = document.querySelector(selector);
    if (form == null) return null;

    final defaults = <String, String>{};
    for (final input in form.querySelectorAll('input')) {
      final name = input.attributes['name']?.trim();
      if (name == null || name.isEmpty) continue;
      defaults[name] = input.attributes['value'] ?? '';
    }
    for (final select in form.querySelectorAll('select')) {
      final name = select.attributes['name']?.trim();
      if (name == null || name.isEmpty) continue;
      defaults[name] = _resolveSelectDefaultValue(select);
    }

    final action = form.attributes['action']?.trim() ?? snapshot.finalUri.path;
    final method = form.attributes['method']?.trim().toUpperCase() ?? 'POST';
    return _AcademicReadonlyQueryForm(
      actionUri: snapshot.finalUri.resolve(action),
      method: method,
      defaultFields: Map.unmodifiable(defaults),
      fieldNamesByIntent: const {},
    );
  }

  Uri? _extractRelativeActionUri(
    AcademicEamsHttpSnapshot snapshot,
    List<String> candidates,
  ) {
    for (final candidate in candidates) {
      final escapedCandidate = RegExp.escape(candidate);
      final patterns = [
        RegExp("['\"]($escapedCandidate(?:\\?[^'\"]*)?)['\"]"),
        RegExp('$escapedCandidate(?:\\?[^"\\\'\\s<>]*)?'),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(snapshot.body);
        final value = match?.group(1) ?? match?.group(0);
        final normalizedValue = value?.trim();
        if (normalizedValue == null || normalizedValue.isEmpty) continue;
        return snapshot.finalUri.resolve(normalizedValue);
      }
    }
    return null;
  }

  String _resolveAcademicSemesterId(String body) {
    final value =
        _extractRegexValue(body, RegExp(r'value:"(\d+)"')) ??
        _extractRegexValue(body, RegExp(r'semesterId=(\d+)')) ??
        _extractRegexValue(
          body,
          RegExp(r'name="semester\.id"\s+value="(\d+)"'),
        );
    return value ?? '';
  }

  String _extractExamTypeId(String body) {
    final value =
        _extractRegexValue(
          body,
          RegExp(r'<option value="(\d+)"[^>]*selected', caseSensitive: false),
        ) ??
        _extractRegexValue(
          body,
          RegExp(r'<option value="(\d+)"', caseSensitive: false),
        );
    return value ?? '1';
  }

  String? _extractRegexValue(String body, RegExp pattern) {
    final match = pattern.firstMatch(body);
    return match?.groupCount == 0 ? match?.group(0) : match?.group(1);
  }
}
