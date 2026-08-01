import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String keyLoggedIn = 'loggedIn';
  static const String keyLoggedInEmail = 'loggedInEmail';
  static const String keyDarkMode = 'darkMode';

  final SharedPreferences _prefs;

  SessionService(this._prefs);

  static Future<SessionService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionService(prefs);
  }

  bool get isLoggedIn => _prefs.getBool(keyLoggedIn) ?? false;

  String? get loggedInEmail => _prefs.getString(keyLoggedInEmail);

  bool get isDarkMode => _prefs.getBool(keyDarkMode) ?? false;

  Future<void> saveSession({required String email}) async {
    await _prefs.setBool(keyLoggedIn, true);
    await _prefs.setString(keyLoggedInEmail, email);
  }

  Future<void> clearSession() async {
    await _prefs.setBool(keyLoggedIn, false);
    await _prefs.remove(keyLoggedInEmail);
  }

  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(keyDarkMode, isDark);
  }
}
