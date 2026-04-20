/*
 * HTTP 请求服务 — 基于 dio 的统一网络请求封装
 * 提供单例 HTTP 客户端、请求拦截器、错误处理、超时管理
 * 所有网络请求应通过此服务发起，确保统一的错误处理与日志记录
 * @Project : SSPU-all-in-one
 * @File : http_service.dart
 * @Author : Qintsg
 * @Date : 2026-04-19
 */

import 'package:dio/dio.dart';

/// HTTP 请求服务（单例）
/// 封装 dio 实例，提供统一的 GET/POST/PUT/DELETE 方法
/// 自动附加请求日志、超时处理与错误码映射
class HttpService {
  HttpService._() {
    _dio = Dio(_defaultOptions);
    _dio.interceptors.add(_LogInterceptor());
  }

  static final HttpService instance = HttpService._();

  late final Dio _dio;

  /// 默认请求配置：30 秒超时，JSON 响应
  static final BaseOptions _defaultOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    responseType: ResponseType.json,
    headers: {
      'Accept': 'application/json',
      // 模拟浏览器 UA，避免被目标站点拒绝
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  );

  /// 获取底层 Dio 实例（供高级场景使用）
  Dio get dio => _dio;

  // ==================== 便捷请求方法 ====================

  /// 发起 GET 请求
  /// [path] 完整 URL 或相对路径
  /// [queryParameters] URL 查询参数
  /// [options] 覆盖默认配置的请求选项
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// 发起 POST 请求
  /// [data] 请求体数据
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// 发起 PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// 发起 DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// 下载文件到指定路径
  /// [savePath] 本地保存路径
  /// [onReceiveProgress] 下载进度回调 (received, total)
  Future<Response> download(
    String url,
    String savePath, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    return _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 获取纯文本响应（用于网页内容获取）
  /// 返回原始 HTML/文本字符串，不做 JSON 解析
  Future<String> fetchText(
    String url, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<String>(
      url,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.plain),
      cancelToken: cancelToken,
    );
    return response.data ?? '';
  }

  // ==================== 错误处理 ====================

  /// 将 DioException 转换为用户友好的错误描述
  static String describeError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时，请检查网络后重试';
        case DioExceptionType.sendTimeout:
          return '请求发送超时，请检查网络后重试';
        case DioExceptionType.receiveTimeout:
          return '响应接收超时，请检查网络后重试';
        case DioExceptionType.connectionError:
          return '无法连接到服务器，请检查网络';
        case DioExceptionType.badCertificate:
          return '服务器证书验证失败';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          return _describeHttpStatus(statusCode);
        case DioExceptionType.cancel:
          return '请求已取消';
        case DioExceptionType.unknown:
          return '网络请求失败：${error.message ?? "未知错误"}';
      }
    }
    return '网络请求失败：$error';
  }

  /// 将 HTTP 状态码映射为中文描述
  static String _describeHttpStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误 (400)';
      case 401:
        return '认证失败，请重新登录 (401)';
      case 403:
        return '无访问权限 (403)';
      case 404:
        return '请求的资源不存在 (404)';
      case 500:
        return '服务器内部错误 (500)';
      case 502:
        return '网关错误 (502)';
      case 503:
        return '服务暂时不可用 (503)';
      default:
        return '服务器返回错误 ($statusCode)';
    }
  }
}

/// 请求日志拦截器
/// 在 debug 模式下输出请求/响应信息，方便调试
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('[HTTP] → ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('[HTTP] ← ${response.statusCode} ${response.requestOptions.uri}');
      return true;
    }());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print(
        '[HTTP] ✗ ${err.type.name} ${err.requestOptions.uri}: ${err.message}',
      );
      return true;
    }());
    handler.next(err);
  }
}
