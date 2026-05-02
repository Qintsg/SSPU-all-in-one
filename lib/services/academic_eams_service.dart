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

part 'academic_eams_discovery.dart';
part 'academic_eams_gateway.dart';
part 'academic_eams_overview_flow.dart';
part 'academic_eams_page_parser.dart';
part 'academic_eams_page_parser_forms.dart';
part 'academic_eams_page_parser_overview.dart';
part 'academic_eams_page_parser_profile.dart';
part 'academic_eams_page_parser_tables.dart';
part 'academic_eams_search_flow.dart';

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
}
