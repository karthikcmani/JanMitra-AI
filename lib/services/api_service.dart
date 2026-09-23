import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import 'preferences_service.dart';

class ApiService {
  /// Production Render FastAPI Base URL
  static const String renderBaseUrl = 'https://janmitra-backend-twij.onrender.com/api/v1';

  /// Local Wi-Fi Base URL for physical device testing
  static const String localWifiUrl = 'http://10.197.87.105:8000/api/v1';

  /// Android Emulator Base URL
  static const String emulatorUrl = 'http://10.0.2.2:8000/api/v1';

  /// Localhost Base URL
  static const String localhostUrl = 'http://127.0.0.1:8000/api/v1';

  /// Resolves the API Base URL in order of precedence:
  /// 1. Custom URL stored in PreferencesService (if user configured one)
  /// 2. `--dart-define=API_BASE_URL=...` supplied at runtime/build-time
  /// 3. Production Render URL (`https://janmitra-backend-twij.onrender.com/api/v1`)
  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return renderBaseUrl;
  }

  final Dio _dio;
  final SecureStorageService secureStorage;
  final PreferencesService? preferencesService;

  ApiService({
    String? baseUrl,
    required this.secureStorage,
    this.preferencesService,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? preferencesService?.customApiBaseUrl ?? defaultBaseUrl,
            connectTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
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

          String customMsg = error.message ?? 'Unknown connection error';
          if (error.type == DioExceptionType.connectionTimeout) {
            customMsg =
                'Connection timed out reaching JanMitra server. The cloud service may be waking up, please retry in a moment.';
          } else if (error.type == DioExceptionType.receiveTimeout) {
            customMsg =
                'The JanMitra server is processing your request. Please check tracking or retry.';
          } else if (error.type == DioExceptionType.connectionError) {
            customMsg =
                'Unable to reach JanMitra server (${_dio.options.baseUrl}). Please verify your internet connection.';
          }

          final updatedError = error.copyWith(
            message: customMsg,
          );
          return handler.next(updatedError);
        },
      ),
    );
  }

  Dio get dio => _dio;

  String get currentBaseUrl => _dio.options.baseUrl;
  String get baseUrl => _dio.options.baseUrl;

  void updateBaseUrl(String newUrl) {
    String formattedUrl = newUrl.trim();
    if (!formattedUrl.contains('/api/v1')) {
      if (formattedUrl.endsWith('/')) {
        formattedUrl = '${formattedUrl}api/v1';
      } else {
        formattedUrl = '$formattedUrl/api/v1';
      }
    }
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }
    _dio.options.baseUrl = formattedUrl;
    preferencesService?.setCustomApiBaseUrl(formattedUrl);
    debugPrint('--> [API SERVICE] Base URL updated to: $formattedUrl');
  }

  Future<bool> testConnection([String? testUrl]) async {
    String targetUrl = (testUrl ?? _dio.options.baseUrl).trim();
    if (!targetUrl.contains('/api/v1')) {
      if (targetUrl.endsWith('/')) {
        targetUrl = '${targetUrl}api/v1';
      } else {
        targetUrl = '$targetUrl/api/v1';
      }
    }
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      targetUrl = 'http://$targetUrl';
    }
    try {
      final testDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final res = await testDio.get('$targetUrl/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

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
