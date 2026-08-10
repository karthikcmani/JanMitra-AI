import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class ApiService {
  static const String defaultBaseUrl = 'http://192.168.0.139:8000/api/v1';

  final Dio _dio;
  final SecureStorageService secureStorage;

  ApiService({String baseUrl = defaultBaseUrl, required this.secureStorage})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
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
