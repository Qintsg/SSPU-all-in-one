/*
 * 校园网状态模型 — 描述校园网 / VPN 前置检测结果
 * @Project : SSPU-all-in-one
 * @File : campus_network_status.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

/// 校园受限服务可访问模式。
/// 当前默认探针只能确认“校园网或 VPN 可达”，后续可替换为更细粒度检测。
enum CampusNetworkAccessMode {
  /// 尚未完成检测或检测状态不可确定。
  unknown,

  /// 已识别为校园网直连。
  campus,

  /// 已识别为学校 VPN 连接。
  vpn,

  /// 可访问校园内网资源，但暂不能区分校园网直连或 VPN。
  campusOrVpn,

  /// 无法访问校园内网资源。
  unavailable,
}

/// 校园网 / VPN 前置检测结果。
/// 供 UI 展示与后续教务、校园卡、学工报表等受限功能复用。
class CampusNetworkStatus {
  const CampusNetworkStatus({
    required this.accessMode,
    required this.probeUri,
    required this.detail,
    this.checkedAt,
  });

  /// 构建初始未知状态，避免 UI 在首次检测前误报未连接。
  factory CampusNetworkStatus.unknown({required Uri probeUri}) {
    return CampusNetworkStatus(
      accessMode: CampusNetworkAccessMode.unknown,
      probeUri: probeUri,
      detail: '尚未检测校园网 / VPN 状态',
    );
  }

  /// 校园网 / VPN 访问模式。
  final CampusNetworkAccessMode accessMode;

  /// 本次检测使用的目标地址。
  final Uri probeUri;

  /// 检测完成时间；未知状态下为空。
  final DateTime? checkedAt;

  /// 面向用户和调试的简短说明。
  final String detail;

  /// 受限校园查询入口是否可以继续访问。
  bool get canAccessRestrictedServices {
    return switch (accessMode) {
      CampusNetworkAccessMode.campus ||
      CampusNetworkAccessMode.vpn ||
      CampusNetworkAccessMode.campusOrVpn => true,
      CampusNetworkAccessMode.unknown ||
      CampusNetworkAccessMode.unavailable => false,
    };
  }

  /// 顶栏徽标展示文案。
  String get label {
    return switch (accessMode) {
      CampusNetworkAccessMode.campus => '校园网',
      CampusNetworkAccessMode.vpn => '校园 VPN',
      CampusNetworkAccessMode.campusOrVpn => '校园网/VPN',
      CampusNetworkAccessMode.unavailable => '未连接校园网/VPN',
      CampusNetworkAccessMode.unknown => '校园网检测',
    };
  }

  /// 状态详情，用于 Tooltip 和后续入口拦截提示。
  String get description {
    return switch (accessMode) {
      CampusNetworkAccessMode.campus => '当前处于校园网环境，可访问受限查询服务。',
      CampusNetworkAccessMode.vpn => '当前已连接学校 VPN，可访问受限查询服务。',
      CampusNetworkAccessMode.campusOrVpn =>
        '已通过 ${probeUri.host} 验证，可访问校园网 / VPN 受限服务。',
      CampusNetworkAccessMode.unavailable =>
        '无法访问 ${probeUri.host}，教务等受限查询入口需要先连接校园网或学校 VPN。',
      CampusNetworkAccessMode.unknown => '正在等待首次校园网 / VPN 状态检测。',
    };
  }
}
