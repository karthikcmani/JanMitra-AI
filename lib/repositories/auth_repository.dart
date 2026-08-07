import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

enum AuthResultStatus {
  success,
  emailNotRegistered,
  incorrectPassword,
  duplicateEmail,
  failure,
}

class AuthResult {
  final AuthResultStatus status;
  final String? errorMessage;
  final UserModel? user;
  final String? accessToken;

  const AuthResult({
    required this.status,
    this.errorMessage,
    this.user,
    this.accessToken,
  });
}

class AuthRepository {
  final ApiService apiService;
  final SecureStorageService secureStorage;

  AuthRepository({required this.apiService, required this.secureStorage});

  Future<AuthResult> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await apiService.post(
        '/auth/register',
        data: {
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone.trim(),
          'password': password,
          'role': 'citizen',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userJson);
        return AuthResult(
          status: AuthResultStatus.success,
          user: user,
        );
      } else {
        return AuthResult(
          status: AuthResultStatus.failure,
          errorMessage:
              'Registration failed. Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Registration failed. Please try again.';
      AuthResultStatus status = AuthResultStatus.failure;

      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
          if (errorMessage.toLowerCase().contains('already exists')) {
            status = AuthResultStatus.duplicateEmail;
          }
        } else if (data is String && data.isNotEmpty) {
          errorMessage = data;
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Network connection failed. Cannot reach FastAPI backend (${apiService.dio.options.baseUrl}).';
      }

      return AuthResult(
        status: status,
        errorMessage: errorMessage,
      );
    } catch (e) {
      return AuthResult(
        status: AuthResultStatus.failure,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiService.post(
        '/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String?;
        final userJson = data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userJson);

        await secureStorage.saveAccessToken(accessToken);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await secureStorage.saveRefreshToken(refreshToken);
        }

        return AuthResult(
          status: AuthResultStatus.success,
          user: user,
          accessToken: accessToken,
        );
      } else {
        return AuthResult(
          status: AuthResultStatus.failure,
          errorMessage:
              'Login failed. Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Authentication failed. Please try again.';
      AuthResultStatus status = AuthResultStatus.failure;

      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
          final lower = errorMessage.toLowerCase();
          if (lower.contains('not registered')) {
            status = AuthResultStatus.emailNotRegistered;
          } else if (lower.contains('password')) {
            status = AuthResultStatus.incorrectPassword;
          }
        } else if (data is String && data.isNotEmpty) {
          errorMessage = data;
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Network connection failed. Cannot reach FastAPI backend (${apiService.dio.options.baseUrl}).';
      }

      return AuthResult(
        status: status,
        errorMessage: errorMessage,
      );
    } catch (e) {
      return AuthResult(
        status: AuthResultStatus.failure,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final hasToken = await secureStorage.hasValidToken();
    if (!hasToken) return null;

    try {
      final response = await apiService.get('/auth/me');
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await apiService.post('/auth/logout');
    } catch (_) {
      // Ignore network errors on logout if server unreachable
    } finally {
      await secureStorage.clearAll();
    }
  }

  Future<bool> hasActiveSession() async {
    return await secureStorage.hasValidToken();
  }
}
