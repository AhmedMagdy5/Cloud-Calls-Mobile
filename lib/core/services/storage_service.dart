import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Prefs
  static String? getString(String k) => _prefs.getString(k);
  static Future<void> setString(String k, String v) => _prefs.setString(k, v).then((_) {});
  static bool getBool(String k, {bool def = false}) => _prefs.getBool(k) ?? def;
  static Future<void> setBool(String k, bool v) => _prefs.setBool(k, v).then((_) {});
  static Future<void> remove(String k) => _prefs.remove(k).then((_) {});

  // Secure (tokens, SIP password)
  static Future<void> setSecure(String k, String v) => _secure.write(key: k, value: v);
  static Future<String?> getSecure(String k) => _secure.read(key: k);
  static Future<void> deleteSecure(String k) => _secure.delete(key: k);
  static Future<void> clearSecure() => _secure.deleteAll();
}

class StorageKeys {
  static const authToken = 'auth_token';
  static const refreshToken = 'refresh_token';
  static const sipPassword = 'sip_password';
  static const sipUsername = 'sip_username';
  static const sipServer = 'sip_server';
  static const userProfile = 'user_profile';
  static const themeMode = 'theme_mode';
  static const language = 'language';
  static const onboardingDone = 'onboarding_done';
  static const autoDialFromShare = 'auto_dial_from_share';
  static const parkingExtension = 'parking_extension';
  static const apiBaseUrl = 'api_base_url';
  static const integrationCommandsPath = 'integration_commands_path';
  static const integrationSendPath = 'integration_send_path';
  static const registrationSecret = 'registration_secret';
  static const presenceToken = 'presence_token';
}
