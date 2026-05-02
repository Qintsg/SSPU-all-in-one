/*
 * 本专科教务系统查询状态模型
 * @Project : SSPU-all-in-one
 * @File : query_status.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

/// 本专科教务系统通用查询状态。
enum AcademicEamsQueryStatus {
  /// 所需数据全部读取成功。
  success,

  /// 主要数据已读取成功，但存在可降级模块或入口未识别。
  partialSuccess,

  /// 未保存学工号 / OA 账号。
  missingOaAccount,

  /// 未保存 OA 密码。
  missingOaPassword,

  /// 校园网 / VPN 前置检测不可达。
  campusNetworkUnavailable,

  /// OA / CAS 登录状态不可用。
  oaLoginRequired,

  /// 本专科教务首页或业务页面不可用。
  systemUnavailable,

  /// 需要的只读入口未识别到。
  readOnlyEntryUnavailable,

  /// 只读查询表单不可识别，无法构造安全搜索参数。
  queryFormUnavailable,

  /// 页面结构无法解析为目标数据。
  parseFailed,

  /// 网络请求失败或超时。
  networkError,

  /// 未归类异常。
  unexpectedError,
}
