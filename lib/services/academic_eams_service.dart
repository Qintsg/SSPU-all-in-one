/*
 * 本专科教务服务 — 复用 OA/CAS 登录态只读获取 EAMS 课表、成绩、考试和培养计划
 * @Project : SSPU-all-in-one
 * @File : academic_eams_service.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../models/academic_credentials.dart';
import '../models/academic_eams.dart';
import '../models/academic_login_validation.dart';
import '../models/campus_network_status.dart';
import 'academic_credentials_service.dart';
import 'academic_login_validation_service.dart';
import 'campus_network_status_service.dart';
import 'http_service.dart';
import 'storage_service.dart';

part 'academic_eams_gateway.dart';
part 'academic_eams_page_parser.dart';

/// 教务中心与课程表页可依赖的只读接口。
abstract class AcademicEamsClient {
  /// 读取教务摘要，尽量覆盖个人信息、课表、成绩、考试和培养计划。
  Future<AcademicEamsQueryResult> fetchOverview();

  /// 只读取当前学期课表，供独立课程表页面使用。
  Future<AcademicEamsQueryResult> fetchCourseTable();
}

/// 本专科教务系统 HTTP 响应快照。
class AcademicEamsHttpSnapshot {
  const AcademicEamsHttpSnapshot({
    required this.finalUri,
    required this.statusCode,
    required this.body,
  });

  /// 请求完成后的最终地址。
  final Uri finalUri;

  /// HTTP 状态码。
  final int? statusCode;

  /// 已按 UTF-8 / GBK 解码的页面正文。
  final String body;
}

/// 可替换的本专科教务系统网关。
abstract class AcademicEamsGateway {
  /// 重置 Cookie 会话，并注入最近一次 OA 登录得到的 Cookie。
  Future<void> resetSession(Map<String, String> cookieHeadersByHost);

  /// 打开 OA 本专科教务入口。
  Future<AcademicEamsHttpSnapshot> openEntryPage(
    Uri entranceUri,
    Duration timeout,
  );

  /// 读取任意只读页面。
  Future<AcademicEamsHttpSnapshot> fetchPage(Uri pageUri, Duration timeout);

  /// 只读提交搜索表单；仅允许查询型 GET / POST。
  Future<AcademicEamsHttpSnapshot> submitForm({
    required Uri formUri,
    required String method,
    required Map<String, String> fields,
    required Duration timeout,
  });
}

typedef AcademicEamsOaLoginRefresher =
    Future<AcademicLoginValidationResult> Function();

enum _AcademicFetchScope { overview, courseTableOnly }

enum _AcademicFeature {
  courseTable,
  gradeCurrent,
  gradeHistory,
  programPlan,
  exams,
  courseOfferingsEntry,
  freeClassroomEntry,
}

/// 本专科教务只读查询服务。
class AcademicEamsService implements AcademicEamsClient {
  AcademicEamsService({
    AcademicCredentialsService? credentialsService,
    CampusNetworkStatusService? campusNetworkStatusService,
    AcademicEamsGateway? gateway,
    AcademicEamsOaLoginRefresher? refreshOaLogin,
    Uri? entranceUri,
    Uri? homeUri,
    Uri? submenuBaseUri,
    Duration? timeout,
  }) : _credentialsService =
           credentialsService ?? AcademicCredentialsService.instance,
       _campusNetworkStatusService =
           campusNetworkStatusService ?? CampusNetworkStatusService.instance,
       _gateway = gateway ?? DioAcademicEamsGateway(),
       _refreshOaLogin =
           refreshOaLogin ??
           AcademicLoginValidationService.instance.validateSavedCredentials,
       entranceUri = entranceUri ?? defaultEntranceUri,
       homeUri = homeUri ?? defaultHomeUri,
       submenuBaseUri = submenuBaseUri ?? defaultSubmenuBaseUri,
       timeout = timeout ?? const Duration(seconds: 15);

  /// 全局单例。
  static final AcademicEamsService instance = AcademicEamsService();

  /// 本专科教务 OA 入口。
  static final Uri defaultEntranceUri = Uri.parse(
    'https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw',
  );

  /// 主页候选地址。
  static final Uri defaultHomeUri = Uri.parse(
    'https://jx.sspu.edu.cn/eams/home!index.action',
  );

  /// 子菜单读取接口。
  static final Uri defaultSubmenuBaseUri = Uri.parse(
    'https://jx.sspu.edu.cn/eams/home!submenus.action',
  );

  /// 教务自动刷新默认间隔，单位分钟。
  static const int defaultAutoRefreshIntervalMinutes = 30;

  final AcademicCredentialsService _credentialsService;
  final CampusNetworkStatusService _campusNetworkStatusService;
  final AcademicEamsGateway _gateway;
  final AcademicEamsOaLoginRefresher _refreshOaLogin;

  /// 教务 OA 入口地址。
  final Uri entranceUri;

  /// EAMS 首页候选地址。
  final Uri homeUri;

  /// 子菜单枚举接口地址。
  final Uri submenuBaseUri;

  /// 单次网络步骤超时时间。
  final Duration timeout;

  Map<_AcademicFeature, Uri>? _discoveredFeatureUris;

  /// 读取本专科教务自动刷新开关。
  Future<bool> isAutoRefreshEnabled() async {
    return StorageService.getBool(StorageKeys.academicEamsAutoRefreshEnabled);
  }

  /// 保存本专科教务自动刷新开关。
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    await StorageService.setBool(
      StorageKeys.academicEamsAutoRefreshEnabled,
      enabled,
    );
  }

  /// 读取本专科教务自动刷新间隔。
  Future<int> getAutoRefreshIntervalMinutes() async {
    final stored = await StorageService.getInt(
      StorageKeys.academicEamsAutoRefreshIntervalMinutes,
    );
    return _normalizeAutoRefreshInterval(
      stored ?? defaultAutoRefreshIntervalMinutes,
    );
  }

  /// 保存本专科教务自动刷新间隔。
  Future<void> setAutoRefreshIntervalMinutes(int minutes) async {
    await StorageService.setInt(
      StorageKeys.academicEamsAutoRefreshIntervalMinutes,
      _normalizeAutoRefreshInterval(minutes),
    );
  }

  @override
  Future<AcademicEamsQueryResult> fetchOverview() async {
    return _fetchSnapshot(_AcademicFetchScope.overview);
  }

  @override
  Future<AcademicEamsQueryResult> fetchCourseTable() async {
    return _fetchSnapshot(_AcademicFetchScope.courseTableOnly);
  }

  /// 只读查询开课列表；仅提交搜索表单，不执行选课或其它写操作。
  Future<AcademicEamsQueryResult> searchCourseOfferings(
    AcademicCourseOfferingSearchCriteria criteria,
  ) async {
    return _searchReadonlyPage(
      entryFeature: _AcademicFeature.courseOfferingsEntry,
      formParser: _parseCourseOfferingQueryForm,
      searchExecutor: (form) => _gateway.submitForm(
        formUri: form.actionUri,
        method: form.method,
        fields: form.buildCourseOfferingFields(criteria),
        timeout: timeout,
      ),
      resultBuilder: (snapshot, campusStatus) {
        final records = _parseCourseOfferings(snapshot, criteria);
        if (records == null) {
          return _buildResult(
            AcademicEamsQueryStatus.parseFailed,
            message: '未解析到开课检索结果',
            detail: '开课信息页面结构与预期不一致，未提取到课程列表。',
            finalUri: snapshot.finalUri,
            campusNetworkStatus: campusStatus,
          );
        }
        return _buildResult(
          records.records.isEmpty
              ? AcademicEamsQueryStatus.partialSuccess
              : AcademicEamsQueryStatus.success,
          message: records.records.isEmpty ? '开课检索未命中结果' : '开课检索成功',
          detail: records.records.isEmpty
              ? '只读查询已执行，但当前筛选条件下未返回课程记录。'
              : '已读取开课列表，不提供选课、退课或调课入口。',
          finalUri: snapshot.finalUri,
          campusNetworkStatus: campusStatus,
          courseOfferings: records,
        );
      },
    );
  }

  /// 只读查询空闲教室；仅提交搜索条件，不执行预约或占用操作。
  Future<AcademicEamsQueryResult> searchFreeClassrooms(
    AcademicFreeClassroomSearchCriteria criteria,
  ) async {
    return _searchReadonlyPage(
      entryFeature: _AcademicFeature.freeClassroomEntry,
      formParser: _parseFreeClassroomQueryForm,
      searchExecutor: (form) => _gateway.submitForm(
        formUri: form.actionUri,
        method: form.method,
        fields: form.buildFreeClassroomFields(criteria),
        timeout: timeout,
      ),
      resultBuilder: (snapshot, campusStatus) {
        final records = _parseFreeClassrooms(snapshot, criteria);
        if (records == null) {
          return _buildResult(
            AcademicEamsQueryStatus.parseFailed,
            message: '未解析到空闲教室结果',
            detail: '空闲教室页面结构与预期不一致，未提取到教室列表。',
            finalUri: snapshot.finalUri,
            campusNetworkStatus: campusStatus,
          );
        }
        return _buildResult(
          records.records.isEmpty
              ? AcademicEamsQueryStatus.partialSuccess
              : AcademicEamsQueryStatus.success,
          message: records.records.isEmpty ? '空闲教室查询未命中结果' : '空闲教室查询成功',
          detail: records.records.isEmpty
              ? '只读查询已执行，但当前条件下没有可展示的空闲教室。'
              : '已读取空闲教室列表，不提供预约或占用入口。',
          finalUri: snapshot.finalUri,
          campusNetworkStatus: campusStatus,
          freeClassrooms: records,
        );
      },
    );
  }

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

    final courseSnapshot = await _fetchRequiredFeature(
      feature: _AcademicFeature.courseTable,
      featureUris: featureUris,
      warnings: warnings,
      campusNetworkStatus: campusNetworkStatus,
      scope: scope,
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

  Future<AcademicEamsHttpSnapshot?> _fetchRequiredFeature({
    required _AcademicFeature feature,
    required Map<_AcademicFeature, Uri> featureUris,
    required List<String> warnings,
    required CampusNetworkStatus campusNetworkStatus,
    required _AcademicFetchScope scope,
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
        continue;
      } on TimeoutException catch (_) {
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
      final fallbackUri = homeUri.resolve(entry.value);
      if (await _verifyReadonlyPage(fallbackUri)) {
        featureUris[entry.key] = fallbackUri;
      }
    }

    _discoveredFeatureUris = Map.unmodifiable(featureUris);
    return _discoveredFeatureUris!;
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
    return minutes <= 0 ? defaultAutoRefreshIntervalMinutes : minutes;
  }
}
