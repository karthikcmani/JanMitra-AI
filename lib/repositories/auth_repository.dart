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

  // Temporary In-Memory Mock Registry for Phase 1 UI Development
  static final Map<String, _MockUserEntry> _mockUsers = {
    'citizen@gov.in': _MockUserEntry(
      user: const UserModel(
        id: '1',
        fullName: 'Citizen User',
        email: 'citizen@gov.in',
        phone: '9876543210',
        role: 'citizen',
        isActive: true,
      ),
      password: 'password123',
    ),
  };

  static String? _currentMockEmail;

  AuthRepository({required this.apiService, required this.secureStorage});

  Future<AuthResult> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check duplicate email in mock storage
    if (_mockUsers.containsKey(cleanEmail)) {
      return const AuthResult(
        status: AuthResultStatus.duplicateEmail,
        errorMessage: 'An account with this email address already exists.',
      );
    }

    final newUser = UserModel(
      id: (DateTime.now().millisecondsSinceEpoch).toString(),
      fullName: fullName.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      role: 'citizen',
      isActive: true,
      createdAt: DateTime.now(),
    );

    _mockUsers[cleanEmail] = _MockUserEntry(user: newUser, password: password);

    return AuthResult(status: AuthResultStatus.success, user: newUser);
  }

  Future<AuthResult> loginUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Verify email registration
    if (!_mockUsers.containsKey(cleanEmail)) {
      return const AuthResult(
        status: AuthResultStatus.emailNotRegistered,
        errorMessage: 'Email not registered. Please create an account.',
      );
    }

    final entry = _mockUsers[cleanEmail]!;

    // Verify password
    if (entry.password != password) {
      return const AuthResult(
        status: AuthResultStatus.incorrectPassword,
        errorMessage: 'Incorrect password. Please try again.',
      );
    }

    // Save session in SecureStorage
    final mockToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
    await secureStorage.saveAccessToken(mockToken);
    _currentMockEmail = cleanEmail;

    return AuthResult(
      status: AuthResultStatus.success,
      user: entry.user,
      accessToken: mockToken,
    );
  }

  Future<UserModel?> getCurrentUser() async {
    final hasToken = await secureStorage.hasValidToken();
    if (!hasToken) return null;

    final email = _currentMockEmail ?? 'citizen@gov.in';
    if (_mockUsers.containsKey(email)) {
      return _mockUsers[email]!.user;
    }

    return const UserModel(
      id: '1',
      fullName: 'Citizen User',
      email: 'citizen@gov.in',
      phone: '9876543210',
      role: 'citizen',
      isActive: true,
    );
  }

  Future<void> logout() async {
    _currentMockEmail = null;
    await secureStorage.clearAll();
  }

  Future<bool> hasActiveSession() async {
    return await secureStorage.hasValidToken();
  }
}

class _MockUserEntry {
  final UserModel user;
  final String password;

  _MockUserEntry({required this.user, required this.password});
}
