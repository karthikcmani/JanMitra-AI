import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String keyDarkMode = 'darkMode';
  static const String keyLanguage = 'language';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  bool get isDarkMode => _prefs.getBool(keyDarkMode) ?? false;

  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(keyDarkMode, isDark);
  }

  String get language => _prefs.getString(keyLanguage) ?? 'en';

  Future<void> setLanguage(String lang) async {
    await _prefs.setString(keyLanguage, lang);
  }
}
