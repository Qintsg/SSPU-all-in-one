/*
 * 校园网状态检测服务测试 — 校验可达、不可达与异常兜底语义
 * @Project : SSPU-all-in-one
 * @File : campus_network_status_service_test.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:sspu_all_in_one/models/campus_network_status.dart';
import 'package:sspu_all_in_one/services/campus_network_status_service.dart';

void main() {
  final probeUri = Uri.parse('https://tygl.sspu.edu.cn/');

  test('探针可达时返回校园网或 VPN 可用状态', () async {
    final service = CampusNetworkStatusService(
      probeUri: probeUri,
      probe: (uri, timeout) async {
        return CampusNetworkProbeResult(
          reachable: true,
          statusCode: 200,
          detail: '已访问 ${uri.host}，HTTP 200',
        );
      },
    );

    final status = await service.checkStatus();

    expect(status.accessMode, CampusNetworkAccessMode.campusOrVpn);
    expect(status.canAccessRestrictedServices, isTrue);
    expect(status.probeUri, probeUri);
    expect(status.checkedAt, isNotNull);
  });

  test('探针不可达时返回受限入口不可用状态', () async {
    final service = CampusNetworkStatusService(
      probeUri: probeUri,
      probe: (uri, timeout) async {
        return CampusNetworkProbeResult(
          reachable: false,
          detail: '访问 ${uri.host} 超时',
        );
      },
    );

    final status = await service.checkStatus();

    expect(status.accessMode, CampusNetworkAccessMode.unavailable);
    expect(status.canAccessRestrictedServices, isFalse);
    expect(status.description, contains('连接校园网或学校 VPN'));
  });

  test('探针抛出异常时返回失败说明而不是继续向外抛出', () async {
    final service = CampusNetworkStatusService(
      probeUri: probeUri,
      probe: (uri, timeout) async {
        throw StateError('probe failed');
      },
    );

    final status = await service.checkStatus();

    expect(status.accessMode, CampusNetworkAccessMode.unavailable);
    expect(status.detail, contains('probe failed'));
  });
}
