import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import 'theme_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthRepository(apiService: apiService, secureStorage: secureStorage);
});

class AuthState {
  final UserModel? currentUser;
  final bool isLoggedIn;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.isLoggedIn = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? currentUser,
    bool? isLoggedIn,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState());

  Future<void> checkSession() async {
    final hasSession = await _authRepository.hasActiveSession();
    if (hasSession) {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        state = AuthState(isLoggedIn: true, currentUser: user);
      } else {
        state = const AuthState(isLoggedIn: false, currentUser: null);
      }
    } else {
      state = const AuthState(isLoggedIn: false, currentUser: null);
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authRepository.loginUser(
      email: email,
      password: password,
    );

    if (result.status == AuthResultStatus.success) {
      state = AuthState(
        currentUser: result.user,
        isLoggedIn: true,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
    }

    return result;
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authRepository.registerUser(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );

    state = state.copyWith(isLoading: false, errorMessage: result.errorMessage);

    return result;
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState(
      currentUser: null,
      isLoggedIn: false,
      isLoading: false,
    );
  }
}
