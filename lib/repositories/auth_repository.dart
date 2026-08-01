import '../models/user_model.dart';
import '../services/hive_service.dart';
import '../services/session_service.dart';

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

  const AuthResult({required this.status, this.errorMessage, this.user});
}

class AuthRepository {
  final SessionService _sessionService;

  AuthRepository(this._sessionService);

  Future<AuthResult> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (HiveService.userExists(cleanEmail)) {
      return const AuthResult(
        status: AuthResultStatus.duplicateEmail,
        errorMessage: 'An account with this email address already exists.',
      );
    }

    final newUser = UserModel(
      fullName: fullName.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      password: password,
      createdAt: DateTime.now(),
    );

    final saved = await HiveService.saveUser(newUser);
    if (!saved) {
      return const AuthResult(
        status: AuthResultStatus.failure,
        errorMessage: 'Failed to save user account.',
      );
    }

    return AuthResult(status: AuthResultStatus.success, user: newUser);
  }

  Future<AuthResult> loginUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    final user = HiveService.getUser(cleanEmail);
    if (user == null) {
      return const AuthResult(
        status: AuthResultStatus.emailNotRegistered,
        errorMessage: 'Email not registered. Please create an account.',
      );
    }

    if (user.password != password) {
      return const AuthResult(
        status: AuthResultStatus.incorrectPassword,
        errorMessage: 'Incorrect password. Please try again.',
      );
    }

    await _sessionService.saveSession(email: cleanEmail);
    return AuthResult(status: AuthResultStatus.success, user: user);
  }

  Future<void> logout() async {
    await _sessionService.clearSession();
  }

  UserModel? getCurrentUser() {
    final email = _sessionService.loggedInEmail;
    if (email == null) return null;
    return HiveService.getUser(email);
  }

  bool get isLoggedIn => _sessionService.isLoggedIn;
}
