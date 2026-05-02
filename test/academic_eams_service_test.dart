/*
 * 本专科教务服务测试 — 校验 OA 会话、只读摘要、开课检索与空闲教室查询
 * @Project : SSPU-all-in-one
 * @File : academic_eams_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sspu_all_in_one/models/academic_eams.dart';
import 'package:sspu_all_in_one/models/academic_login_validation.dart';
import 'package:sspu_all_in_one/services/academic_credentials_service.dart';
import 'package:sspu_all_in_one/services/academic_eams_service.dart';
import 'package:sspu_all_in_one/services/storage_service.dart';

import 'academic_eams_service_test_support.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    StorageService.debugUseSharedPreferencesStorageForTesting(true);
  });

  tearDown(() {
    StorageService.debugUseSharedPreferencesStorageForTesting(null);
    SharedPreferences.setMockInitialValues({});
  });

  test('本专科教务自动刷新设置默认关闭并可持久化间隔', () async {
    final service = buildAcademicEamsServiceForTest(
      gateway: FakeAcademicEamsGateway(),
      campusReachable: true,
    );

    expect(await service.isAutoRefreshEnabled(), isFalse);
    expect(
      await service.getAutoRefreshIntervalMinutes(),
      AcademicEamsService.defaultAutoRefreshIntervalMinutes,
    );

    await service.setAutoRefreshEnabled(true);
    await service.setAutoRefreshIntervalMinutes(60);

    expect(await service.isAutoRefreshEnabled(), isTrue);
    expect(await service.getAutoRefreshIntervalMinutes(), 60);
  });

  test('未保存学工号时不访问本专科教务入口', () async {
    final gateway = FakeAcademicEamsGateway();
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: true,
    );

    final result = await service.fetchOverview();

    expect(result.status, AcademicEamsQueryStatus.missingOaAccount);
    expect(gateway.openCount, 0);
  });

  test('校园网或 VPN 不可达时停止本专科教务查询', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    final gateway = FakeAcademicEamsGateway();
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: false,
    );

    final result = await service.fetchOverview();

    expect(result.status, AcademicEamsQueryStatus.campusNetworkUnavailable);
    expect(gateway.openCount, 0);
  });

  test('OA 会话失效时刷新登录态后解析教务摘要与课表', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    var refreshCount = 0;
    final gateway = FakeAcademicEamsGateway(requireAuthFirst: true);
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: true,
      refreshOaLogin: () async {
        refreshCount++;
        await AcademicCredentialsService.instance.saveOaLoginSession(
          academicEamsSessionSnapshot,
        );
        return AcademicLoginValidationResult(
          status: AcademicLoginValidationStatus.success,
          message: 'OA 登录校验通过',
          detail: '已刷新 OA 会话',
          checkedAt: DateTime(2026, 5, 2),
          entranceUri: academicEamsOaEntranceUri,
          finalUri: academicEamsOaEntranceUri,
          sessionSnapshot: academicEamsSessionSnapshot,
        );
      },
    );

    final result = await service.fetchOverview();

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(refreshCount, 1);
    expect(gateway.openCount, 2);
    expect(gateway.resetCookieHeaders.last['oa.sspu.edu.cn'], contains('OA='));
    expect(result.snapshot?.profile?.name, '张三');
    expect(result.snapshot?.courseTable?.entries.length, 1);
    expect(result.snapshot?.grades?.historyRecords.length, 1);
    expect(result.snapshot?.programCompletion?.completedCredits, 7);
    expect(result.snapshot?.exams?.records.single.location, '综合楼 A201');
    expect(result.snapshot?.hasCourseOfferingEntry, isTrue);
    expect(result.snapshot?.hasFreeClassroomEntry, isTrue);
  });

  test('独立课表读取只解析当前学期课表', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      academicEamsSessionSnapshot,
    );
    final service = buildAcademicEamsServiceForTest(
      gateway: FakeAcademicEamsGateway(),
      campusReachable: true,
    );

    final result = await service.fetchCourseTable();

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(result.snapshot?.courseTable?.entries.single.courseName, '高等数学');
    expect(result.snapshot?.grades, isNull);
    expect(result.snapshot?.programPlan, isNull);
  });

  test('开课检索会提交只读查询表单并解析列表', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      academicEamsSessionSnapshot,
    );
    final gateway = FakeAcademicEamsGateway();
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: true,
    );

    final result = await service.searchCourseOfferings(
      const AcademicCourseOfferingSearchCriteria(
        termName: '2025-2026-2',
        courseName: '高等数学',
        teacher: '张老师',
      ),
    );

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(gateway.lastSubmittedMethod, 'GET');
    expect(gateway.lastSubmittedFields?['semester'], '2025-2026-2');
    expect(gateway.lastSubmittedFields?['courseName'], '高等数学');
    expect(gateway.lastSubmittedFields?['teacherName'], '张老师');
    expect(result.courseOfferings?.records.single.locationText, '综合楼 A101');
  });

  test('未指定学期时不会把开课检索默认收窄到首个下拉选项', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      academicEamsSessionSnapshot,
    );
    final gateway = FakeAcademicEamsGateway();
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: true,
    );

    await service.searchCourseOfferings(
      const AcademicCourseOfferingSearchCriteria(courseName: '高等数学'),
    );

    expect(gateway.lastSubmittedFields?['semester'], isEmpty);
  });

  test('空闲教室查询会提交只读表单并解析结果', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      academicEamsSessionSnapshot,
    );
    final gateway = FakeAcademicEamsGateway();
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: true,
    );

    final result = await service.searchFreeClassrooms(
      const AcademicFreeClassroomSearchCriteria(
        campus: '金海',
        building: '综合楼',
        dateText: '2026-05-02',
        lessonFrom: 1,
        lessonTo: 2,
      ),
    );

    expect(result.status, AcademicEamsQueryStatus.success);
    expect(gateway.lastSubmittedFields?['campus'], '金海');
    expect(gateway.lastSubmittedFields?['building'], '综合楼');
    expect(gateway.lastSubmittedFields?['date'], '2026-05-02');
    expect(gateway.lastSubmittedFields?['startUnit'], '1');
    expect(gateway.lastSubmittedFields?['endUnit'], '2');
    expect(result.freeClassrooms?.records.single.roomName, '综合楼 A301');
  });

  test('子菜单探测的瞬时失败不会被缓存到后续查询', () async {
    await AcademicCredentialsService.instance.saveCredentials(
      oaAccount: '20260001',
      oaPassword: 'oa-pass',
    );
    await AcademicCredentialsService.instance.saveOaLoginSession(
      academicEamsSessionSnapshot,
    );
    final gateway = FakeAcademicEamsGateway(failFreeClassroomMenuOnce: true);
    final service = buildAcademicEamsServiceForTest(
      gateway: gateway,
      campusReachable: true,
    );

    final firstResult = await service.fetchOverview();
    final secondResult = await service.fetchOverview();

    expect(firstResult.snapshot?.hasFreeClassroomEntry, isFalse);
    expect(secondResult.snapshot?.hasFreeClassroomEntry, isTrue);
  });
}
