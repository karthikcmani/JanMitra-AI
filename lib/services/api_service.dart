import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class ApiService {
  /// Production Render FastAPI Base URL
  static const String renderBaseUrl = 'https://janmitra-backend-twij.onrender.com/api/v1';

  /// Resolves the API Base URL in order of precedence:
  /// 1. `--dart-define=API_BASE_URL=...` supplied at runtime/build-time
  /// 2. Production Render URL (`https://janmitra-backend-twij.onrender.com/api/v1`)
  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return renderBaseUrl;
  }


  final Dio _dio;
  final SecureStorageService secureStorage;

  ApiService({String? baseUrl, required this.secureStorage})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? defaultBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('--> [DIO REQUEST] ${options.method} ${options.uri}');
          debugPrint('--> Headers: ${options.headers}');
          if (options.data != null) {
            debugPrint('--> Body: ${options.data}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('<-- [DIO RESPONSE ${response.statusCode}] ${response.requestOptions.uri}');
          debugPrint('<-- Data: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          debugPrint('<-- [DIO ERROR ${error.response?.statusCode}] ${error.requestOptions.uri}');
          debugPrint('<-- Error Data: ${error.response?.data}');
          debugPrint('<-- Error Message: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
